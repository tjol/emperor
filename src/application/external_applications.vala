/* Emperor - an orthodox file manager for the GNOME desktop
 * Copyright (C) 2012    Thomas Jollans
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

namespace Emperor.App {

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

            load_apps_from_config ();
        }

        private class AppCfgEntry
        {
            internal ArrayList<string> content_types { get; private set; }
            private FileHandler? m_handler;
            internal unowned FileHandler? handler {
                get {
                    return m_handler;
                }
            }
            internal void
            set_handler (owned FileHandler? new_handler)
            {
                m_handler = (owned) new_handler;
            }
            internal FileAction action { get; private set; }

            internal AppCfgEntry (FileAction action)
            {
                this.action = action;
                content_types = new ArrayList<string> ();
                m_handler = null;
            }

            internal void use_appinfo (AppInfo appinfo)
            {
                var handlerfactory = new AppInfoHandlerFactory (appinfo);
                m_handler = handlerfactory.handle;
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
                    throws Error
                {
                    appinfo.launch (files, null);
                }
            }
        }

        private GLib.List<AppCfgEntry> m_view_apps;
        private GLib.List<AppCfgEntry> m_edit_apps;

        internal void
        load_apps_from_config ()
            throws ConfigurationError
        {
            var edit_apps_node = m_app.config["apps"]["edit"];
            if (edit_apps_node == null) {
                m_edit_apps = new GLib.List<AppCfgEntry> ();
            } else if (edit_apps_node.get_node_type () == Json.NodeType.ARRAY) {
                m_edit_apps = load_apps_from_json_array (edit_apps_node.get_array (),
                                                         FileAction.EDIT);
            } else {
                throw new ConfigurationError.INVALID_ERROR (_("Default application configuration invalid."));
            }

            var view_apps_node = m_app.config["apps"]["view"];
            if (view_apps_node == null) {
                m_view_apps = new GLib.List<AppCfgEntry> ();
            } else if (view_apps_node.get_node_type () == Json.NodeType.ARRAY) {
                m_view_apps = load_apps_from_json_array (edit_apps_node.get_array (),
                                                         FileAction.VIEW);
            } else {
                throw new ConfigurationError.INVALID_ERROR (_("Default application configuration invalid."));
            }
        }

        private GLib.List<AppCfgEntry>
        load_apps_from_json_array (Json.Array apps_json, FileAction action)
            throws ConfigurationError
        {
            var result_list = new GLib.List<AppCfgEntry> ();

            foreach (var app_node in apps_json.get_elements ()) {
                if (app_node.get_node_type () != Json.NodeType.OBJECT) {
                    throw new ConfigurationError.INVALID_ERROR (_("Default application configuration invalid."));
                }

                result_list.prepend (load_app_from_json_object (app_node.get_object (),
                                                                action));
            }

            return result_list;
        }

        private AppCfgEntry
        load_app_from_json_object (Json.Object app_obj, FileAction action)
            throws ConfigurationError
        {
            var appcfg = new AppCfgEntry (action);

            // get the content types.
            var types_node = app_obj.get_member ("content-types");
            if (types_node == null || types_node.get_node_type () != Json.NodeType.ARRAY) {
                throw new ConfigurationError.INVALID_ERROR (_("Default application configuration invalid."));
            }
            foreach (var type_node in types_node.get_array ().get_elements ()) {
                if (type_node.get_value_type () != typeof (string)) {
                    throw new ConfigurationError.INVALID_ERROR (_("Default application configuration invalid."));
                }
                appcfg.content_types.add (type_node.get_string ());
            }

            // What to do?
            if (app_obj.has_member ("launch-default-for-type")) {
                var ref_type_node = app_obj.get_member ("launch-default-for-type");
                if (ref_type_node.get_value_type () != typeof(string)) {
                    throw new ConfigurationError.INVALID_ERROR (_("Default application configuration invalid."));
                }
                try {
                    appcfg.set_handler(get_default_for_type (ref_type_node.get_string ()));
                } catch (Error e) {
                    stderr.printf(_("Warning: no default application found for type: %s\n"),
                                  ref_type_node.get_string ());
                }
            } else if (app_obj.has_member ("launch-desktop-application")) {
                var appname_node = app_obj.get_member ("launch-desktop-application");
                if (appname_node.get_value_type () != typeof(string)) {
                    throw new ConfigurationError.INVALID_ERROR (_("Default application configuration invalid."));
                }
                var appinfo = new DesktopAppInfo (appname_node.get_string ());
                if (appinfo == null) {
                    stderr.printf(_("Warning: Application not found.\n"));
                } else {
                    appcfg.use_appinfo (appinfo);
                }
            } else {
                throw new ConfigurationError.INVALID_ERROR (_("Default application configuration invalid."));
            }

            return appcfg;
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

        public FileHandler
        get_specific_for_type (string content_type, FileAction action,
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

            unowned FileHandler? last_glob_result = null;

            foreach (var appentry in relevant_apps) {
                foreach (string app_ctype in appentry.content_types) {
                    if (content_type == app_ctype) {
                        // exact match. Use this.
                        return (files) => { appentry.handler (files); };
                    } else if (PatternSpec.match_simple(app_ctype, content_type)) {
                        // glob match. save for later use.
                        last_glob_result = appentry.handler;
                    }
                }
            }
            
            // If this point is reached, no exact match has been found.

            if (fallback_to_generic && last_glob_result != null) {
                return (files) => { last_glob_result (files); };
            }

            // Nothing found? Try the desktop default:
            if (fallback_to_default) {
                return get_default_for_type (content_type);
            }

            throw new AppManagementError.APPLICATION_NOT_FOUND (_("No suitable application found."));
        }

        public FileHandler get_specific_for_file (File file, FileAction action,
                                                  bool fallback_to_generic,
                                                  bool fallback_to_default)
            throws Error
        {
            var file_info = file.query_info (FileAttribute.STANDARD_CONTENT_TYPE, 0);
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

