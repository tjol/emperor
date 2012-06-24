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

namespace Emperor.Application {

    public errordomain ConfigurationError {
        PARSE_ERROR,
        INVALID_ERROR,
        MODULE_ERROR,
        NOT_FOUND_ERROR
    }

    public class EmperorCore : Gtk.Application
    {

        public ModuleRegistry modules { get; private set; }
        public UserInterfaceManager ui_manager { get; private set; }
        public MainWindow main_window { get; private set; }
        public AppManager external_apps { get; private set; }
        public PrefsMachine prefs { get; private set; }

        private string? m_config_dir;

        public EmperorCore (string? module_location, string? config_dir)
                throws ConfigurationError
        {
            Object ( application_id : "de.jollybox.Emperor", flags : ApplicationFlags.FLAGS_NONE);

            Xml.Parser.init ();
            m_config_dir = config_dir;

            prefs = new PrefsMachine ();
            if (!prefs.load ()) {
                stderr.printf ("Failed to load preferences file.\n");
            }
            modules = new ModuleRegistry (this, module_location);
            ui_manager = new UserInterfaceManager (this);
            external_apps = new AppManager (this);

            // read the XML configuration.
            var config_fname = get_config_file_path ("config.xml");
            
            Xml.Doc* document = Xml.Parser.read_file (config_fname);
            if (document == null) {
                throw new ConfigurationError.PARSE_ERROR (config_fname);
            }

            try {
                Xml.Node* root = document->get_root_element ();
                handle_config_xml_nodes(root);
            } finally {
                delete document;
            }

            var about_action = modules.new_action ("show-about-dialog");
            about_action.set_stock_id (Gtk.Stock.ABOUT);
            about_action.activate.connect (show_about_dialog);
            ui_manager.add_action_to_menu (_("_Help"), about_action, 999);

            main_window = new MainWindow (this);

            this.activate.connect (run_program);
            this.application_quit.connect (on_quit);
        }

        ~EmperorCore ()
        {
            Xml.Parser.cleanup ();
        }

        public string get_config_file_path (string basename)
            throws ConfigurationError
        {
            string path;
            File file;

            // First, try the config dir set on the command line.
            path = "%s/%s".printf (m_config_dir, basename);
            file = File.new_for_path (path);
            if (file.query_exists() == true) {
                return path;
            }

            // Next, try the XDG data home dir
            path = "%s/%s/%s".printf (Environment.get_user_data_dir (),
                                      Config.PACKAGE_NAME,
                                      basename);
            file = File.new_for_path (path);
            if (file.query_exists() == true) {
                return path;
            }

            // Now, the XDG system data dirs.
            foreach (var datadir in Environment.get_system_data_dirs ()) {
                path = "%s/%s/%s".printf (datadir,
                                          Config.PACKAGE_NAME,
                                          basename);
                file = File.new_for_path (path);
                if (file.query_exists() == true) {
                    return path;
                }
            }

            // Finally, the autoconf-set data dir.
            path = "%s/%s".printf (Config.DATA_DIR,
                                   basename);
            file = File.new_for_path (path);
            if (file.query_exists() == true) {
                return path;
            }

            throw new ConfigurationError.NOT_FOUND_ERROR (
                _("Configuration file not found: %s").printf (basename) );
        }

        public string get_resource_file_path (string path)
        {
            var env_res_path = Environment.get_variable ("EMPEROR_RES_LOCATION");
            if (env_res_path != null) {
                return "%s/%s".printf (env_res_path, path);
            } else {
                return "%s/res/%s".printf (Config.DATA_DIR, path);
            }
        }

        private void handle_config_xml_nodes (Xml.Node* parent)
                        throws ConfigurationError
        {
            if (parent->name != "emperor-config") {
                throw new ConfigurationError.INVALID_ERROR(
                            _("Unexpected root element: %s").printf(parent->name));
            }

            for (Xml.Node* node = parent->children; node != null; node = node->next) {
                if (node->type == Xml.ElementType.ELEMENT_NODE) {
                    switch (node->name) {
                    case "modules":
                        modules.handle_config_xml_nodes (node);
                        break;
                    case "user-interface":
                        ui_manager.handle_config_xml_nodes (node);
                        break;
                    default:
                        throw new ConfigurationError.INVALID_ERROR(
                                    _("Unexpected element: %s").printf(node->name));
                    }
                }
            }
        }

        public void open_file (File file)
        {
            var file_list = new GLib.List<File> ();
            file_list.append (file);
            open_files (file_list);
        }

        public void open_files (List<File> file_list)
            requires (file_list.length() > 0)
        {
            var first_file = file_list.nth_data(0);
            try {
                var launch  = external_apps.get_default_for_file (first_file);
                launch (file_list);
            } catch (Error e) {
                string error_msg;
                if (file_list.length() == 1) {
                    error_msg = _("Error opening “%s”").printf(first_file.get_basename());
                } else {
                    error_msg = _("Error opening %ud files.").printf(file_list.length());
                }
                show_error_message_dialog (main_window, error_msg, e.message);
            }
        }

        public void run_program ()
        {
            main_window.show_all ();
            //Gtk.main ();
        }

        public signal void application_quit ();

        private void on_quit ()
        {
            prefs.save ();
        }

        public void show_about_dialog ()
        {
            string[] authors = {
                "<a href=\"mailto:Thomas Jollans &lt;t@jollybox.de&gt;\">Thomas Jollans</a>"
            };
            string license_text =
              _("Emperor is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. \n\nThis program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details. \n\nYou should have received a copy of the GNU General Public License along with Emperor.  If not, see http://www.gnu.org/licenses/");

            string name_text = "Emperor " + Config.PACKAGE_VERSION_NAME;
            string effigy_file_name = Config.PACKAGE_VERSION_NAME + ".png";
            var logo = new Gdk.Pixbuf.from_file (get_resource_file_path(effigy_file_name));

            Gtk.show_about_dialog (main_window,
                program_name : name_text,
                logo : logo, 
                version : Config.PACKAGE_VERSION,
                title : _("About Emperor"),
                authors : authors,
                license : license_text,
                wrap_license : true,
                copyright : _("Copyright © 2011-2012 Thomas Jollans"),
                comments : _("Orthodox File Manager for GNOME") );
        }

        public static int main (string[] argv)
        {
            Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.PROGRAMNAME_LOCALEDIR);
            Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
            Intl.textdomain (Config.GETTEXT_PACKAGE);

            string? module_location = null;
            string? config_file = null;
            void* p_module_location = & module_location;
            void* p_config_file = & config_file;

            OptionEntry[] options = {
                OptionEntry() {
                    long_name = "module-path", 
                    short_name = 0,
                    flags = 0,
                    arg = OptionArg.FILENAME,
                    arg_data = p_module_location, 
                    description = _("Location of Emperor modules"),
                    arg_description = _(".../module/directory/") },
                OptionEntry () {
                    long_name = "config",
                     short_name = 'c',
                     flags = 0,
                     arg = OptionArg.FILENAME,
                     arg_data = p_config_file,
                     description = _("Location of configuration files"),
                     arg_description = _(".../config/directory/") }
            };

            try {
                Gtk.init_with_args(ref argv, _("Orthodox File Manager for GNOME"),
                                   options, null);
            } catch (Error e) {
                stderr.printf (_("Error starting application: %s\n"), e.message);
                return 1;
            }

        #if HAVE_LIBNOTIFY
            if (!Notify.init("Emperor")) {
                stderr.printf (_("Error initializing notification system.\n"));
            }
        #endif

            EmperorCore app;
            try {
                app = new EmperorCore (module_location, config_file);
            } catch (ConfigurationError e) {
                if (e is ConfigurationError.PARSE_ERROR) {
                    stderr.printf(_("ERROR: Cannot parse file \"%s\"\n"), e.message);
                } else {
                    stderr.printf(_("ERROR: %s\n"), e.message);
                }
                return 1;
            }
            app.run(null);
            app.application_quit ();

            return 0;
        }

    }

    public static string bytesize_to_string (uint64 size_in_bytes)
    {
        if (size_in_bytes < 900) { // 0 -- 900b
            return _("%qu b").printf(size_in_bytes);
        } else if (size_in_bytes < 10240) { // 0.9K -- 10K
            return _("%s KiB").printf("%.1f".printf(size_in_bytes / 1024.0));
        } else if (size_in_bytes < 921600) { // 10K -- 900K
            return _("%s KiB").printf("%qu".printf(size_in_bytes / 1024));
        } else if (size_in_bytes < 10485760) { // 0.9M -- 10M
            return _("%s MiB").printf("%.1f".printf(size_in_bytes / 1048576.0));
        } else if (size_in_bytes < 943718400) { // 10M -- 900M
            return _("%s MiB").printf("%qu".printf(size_in_bytes / 1048576));
        } else { // 0.9G +
            return _("%.1f GiB").printf(size_in_bytes / 1073741824.0);
        }
    }

    public class Ref<T>
    {
        public Ref (T initial_value) { val = initial_value; }
        public T val { get; set; }
    }


}


