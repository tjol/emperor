/* Emperor - an orthodox file manager for the GNOME desktop
 * Copyright (C) 2011    Thomas Jollans
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;
using Gee;

namespace Emperor.Application {

    public errordomain AppManagementError {
        APPLICATION_NOT_FOUND
    }


    public class AppManager : Object
    {
        public delegate void FileHandler (GLib.List<File> objects) throws Error;

        public enum FileAction {
            VIEW,
            EDIT
        }

        private EmperorCore m_app;

        public AppManager (EmperorCore app)
            throws ConfigurationError
        {
            m_app = app;
            m_view_apps = new GLib.List<AppCfgEntry> ();
            m_edit_apps = new GLib.List<AppCfgEntry> ();

            var apps_xml_fname = m_app.get_config_file_path ("apps.xml");

            Xml.Doc* document = Xml.Parser.read_file (apps_xml_fname);
            if (document == null) {
                throw new ConfigurationError.PARSE_ERROR (apps_xml_fname);
            }

            try {
                Xml.Node* root = document->get_root_element ();
                handle_apps_xml_nodes (root);
            } finally {
                delete document;
            }
        }

        private class AppCfgEntry
        {
            internal ArrayList<string> content_types { get; private set; }
            internal FileHandler? handler { get; set; }
            internal FileAction action { get; private set; }

            internal AppCfgEntry (FileAction action)
            {
                this.action = action;
                content_types = new ArrayList<string> ();
                handler = null;
            }

            internal void use_appinfo (AppInfo appinfo)
            {
                var handlerfactory = new AppInfoHandlerFactory (appinfo);
                this.handler = handlerfactory.handle;
                /* Vala/GObject reference counting breaks down when it comes
                 * to delegates due to API compatability with C - the delegate
                 * argument (here: handlerfactory) is passed as an opaque
                 * pointer and the programmer has to take care of memory 
                 * management.                                               */
                handlerfactory.ref();
            }

            private class AppInfoHandlerFactory : Object
            {
                public AppInfo appinfo { get; construct; }

                public AppInfoHandlerFactory (AppInfo appinfo) { Object ( appinfo : appinfo ) ; }

                public void handle (GLib.List<File> files)
                {
                    appinfo.launch (files, null);
                }
            }
        }

        private GLib.List<AppCfgEntry> m_view_apps;
        private GLib.List<AppCfgEntry> m_edit_apps;

        private AppCfgEntry _current_entry;

        private void handle_apps_xml_nodes (Xml.Node* parent)
                        throws ConfigurationError
        {
            for (Xml.Node* node = parent->children; node != null; node = node->next) {
                switch (parent->name) {
                case "emperor-apps":
                    if (node->type == Xml.ElementType.ELEMENT_NODE) {
                        if (node->name == "binding") {
                            var s_action = node->get_prop ("action");
                            if (s_action == "edit") {
                                _current_entry = new AppCfgEntry (FileAction.EDIT);
                            } else if (s_action == "view") {
                                _current_entry = new AppCfgEntry (FileAction.VIEW);
                            } else {
                                throw new ConfigurationError.INVALID_ERROR (
                                    "Illegal value for binding action: %s".printf(s_action));
                            }

                            handle_apps_xml_nodes (node);

                            if (_current_entry.action == FileAction.EDIT) {
                                m_edit_apps.prepend (_current_entry);
                            } else {
                                m_view_apps.prepend (_current_entry);
                            }

                        } else {
                            throw new ConfigurationError.INVALID_ERROR (
                                        "Unexpected element: " + node->name);
                        }
                    }
                    break;

                case "binding":
                    if (node->type == Xml.ElementType.ELEMENT_NODE) {
                        if (node->name == "match") {
                            var ctype = node->get_prop ("content-type");
                            if (ctype == null) {
                                throw new ConfigurationError.INVALID_ERROR (
                                            "Empty match");
                            }
                            _current_entry.content_types.add (ctype);

                        } else if (node->name == "default-application") {
                            var for_ctype = node->get_prop ("content-type");
                            if (for_ctype == null) {
                                throw new ConfigurationError.INVALID_ERROR (
                                        "default-application requires content-type");
                            }
                            try {
                                _current_entry.handler = get_default_for_type (for_ctype);
                            } catch (Error e) {
                                stderr.printf("Warning: no default application found "
                                   +"for type: %s\n", for_ctype);
                            }

                        } else if (node->name == "desktop-application") {
                            AppInfo appinfo = null;

                            var app_name = node->get_prop ("name");
                            var desktop_file_name = node->get_prop ("filename");
                            if (app_name != null) {
                                appinfo = new DesktopAppInfo (app_name);
                            } else if (desktop_file_name != null) {
                                appinfo = new DesktopAppInfo.from_filename (desktop_file_name);
                            } else {
                                throw new ConfigurationError.INVALID_ERROR (
                                        "desktop-application without source/reference");
                            }

                            if (appinfo != null) {
                                _current_entry.use_appinfo (appinfo);
                            } else {
                                stderr.printf("Warning: Application not found.\n");
                            }

                        } else {
                            throw new ConfigurationError.INVALID_ERROR (
                                        "Unexpected element: " + node->name);
                        }
                    }
                    break;
                }
            }
        }

        public FileHandler get_default_for_type (string content_type)
            throws Error
        {
            var default_appinfo = AppInfo.get_default_for_type (content_type, false);

            return (files) => { default_appinfo.launch (files, null); } ;
        }

        public FileHandler get_default_for_file (File file)
            throws Error
        {
            var default_appinfo = file.query_default_handler ();

            return (files) => { default_appinfo.launch (files, null); } ;
        }

        public FileHandler get_specific_for_type (string content_type, FileAction action,
                                                  bool fallback_to_generic,
                                                  bool fallback_to_default)
            throws Error
        {
            
            unowned GLib.List<AppCfgEntry> relevant_apps;
            switch (action) {
            case FileAction.VIEW:
                relevant_apps = m_view_apps;
                break;
            case FileAction.EDIT: 
                relevant_apps = m_edit_apps;
                break;
            default:
                throw new AppManagementError.APPLICATION_NOT_FOUND (
                        "Major mess. This should never happen.");
            }

            FileHandler? last_glob_result = null;

            foreach (var appentry in relevant_apps) {
                foreach (string app_ctype in appentry.content_types) {
                    if (content_type == app_ctype) {
                        // exact match. Use this.
                        return appentry.handler;
                    } else if (PatternSpec.match_simple(app_ctype, content_type)) {
                        // glob match. save for later use.
                        last_glob_result = appentry.handler;
                    }
                }
            }
            
            // If this point is reached, no exact match has been found.

            if (fallback_to_generic && last_glob_result != null) {
                return last_glob_result;
            }

            // Nothing found? Try the desktop default:
            if (fallback_to_default) {
                return get_default_for_type (content_type);
            }

            throw new AppManagementError.APPLICATION_NOT_FOUND ("Not implemented.");
        }

        public FileHandler get_specific_for_file (File file, FileAction action,
                                                  bool fallback_to_generic,
                                                  bool fallback_to_default)
            throws Error
        {
            var file_info = file.query_info (FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE, 0);
            string content_type = file_info.get_content_type ();
            try {
                return get_specific_for_type (content_type, action, fallback_to_generic, false);
            } catch (Error e) {
                if (fallback_to_default) {
                    return get_default_for_file (file);
                } else {
                    throw e;
                }
            }
        }

    }

}

