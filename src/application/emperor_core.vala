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

namespace Emperor.App {

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
        public MountManager mount_manager { get; private set; }
        public MainWindow main_window { get; private set; }
        public AppManager external_apps { get; private set; }
        public ConfigurationManager config { get; private set; }

        private string? m_config_dir;

        public EmperorCore (string? module_location, string? config_dir)
                throws ConfigurationError
        {
            Object ( application_id : "de.jollybox.Emperor", flags : ApplicationFlags.FLAGS_NONE );

            // Initialize the essentials
            m_config_dir = config_dir;

            config = new ConfigurationManager (this);

            // get system config file
            config.load_config_file (get_config_file_path ("config.json", false, true), true);
            // get user config file
            try {
                config.load_config_file (get_config_file_path("config.json", true, false));
            } catch (ConfigurationError user_config_err) {
                warning (_("Failed to load user configuration file."));
            }

            modules = new ModuleRegistry (this, module_location);
            ui_manager = new UserInterfaceManager (this);
            external_apps = new AppManager (this);
            mount_manager = new MountManager (this);

            modules.load_config_modules ();
            ui_manager.load_style_configuration ();
            ui_manager.load_column_configuration ();

            // Set up about dialog

            var about_action = modules.new_action ("show-about-dialog");
            about_action.set_stock_id (Gtk.Stock.ABOUT);
            about_action.activate.connect (show_about_dialog);
            ui_manager.add_action_to_menu (_("_Help"), about_action, 999);

            // Create main window 

            main_window = new MainWindow (this);

            this.activate.connect (run_program);
            this.application_quit.connect (on_quit);
        }

        /**
         * Find configuration file name. Looks in the directory supplied
         * on the command line, and in the default user and system config
         * locations.
         */
        public string get_config_file_path (string basename, bool for_user=true, bool for_system=true)
            throws ConfigurationError
        {
            string path;
            File file;

            if (for_system) {
                // First, try the config dir set on the command line.
                path = "%s/%s".printf (m_config_dir, basename);
                file = File.new_for_path (path);
                if (file.query_exists() == true) {
                    return path;
                }
            }

            if (for_user) {
                // Next, try the XDG data home dir
                path = "%s/%s/%s".printf (Environment.get_user_config_dir (),
                                          Config.PACKAGE_NAME,
                                          basename);
                file = File.new_for_path (path);
                if (file.query_exists() == true) {
                    return path;
                }
            }

            if (for_system) {
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
            }

            throw new ConfigurationError.NOT_FOUND_ERROR (
                _("Configuration file not found: %s").printf (basename) );
        }

        /**
         * Find location of a data file.
         */
        public string get_resource_file_path (string path)
        {
            var env_res_path = Environment.get_variable ("EMPEROR_RES_LOCATION");
            if (env_res_path != null) {
                return "%s/%s".printf (env_res_path, path);
            } else {
                return "%s/res/%s".printf (Config.DATA_DIR, path);
            }
        }
 
        /**
         * Refer a file to the operating system.
         *
         * @see AbstractFilePane.activate_file
         */
        public void open_file (File file)
        {
            var file_list = new GLib.List<File> ();
            file_list.append (file);
            open_files (file_list);
        }

        /**
         * Open multiple files. Assumes these are all of the same of of a
         * similar type and opens all of them with the default application
         * for the first in the list.
         */
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
            // Save the configuration file to the user's config directory.
            var cfg_dir = "%s/%s".printf (Environment.get_user_config_dir (),
                                          Config.PACKAGE_NAME);
            var cfg_path = "%s/%s".printf (cfg_dir,
                                           "config.json");

            var gio_cfg_dir = File.new_for_path (cfg_dir);
            try {
                if (!gio_cfg_dir.query_exists ()) {
                    gio_cfg_dir.make_directory_with_parents ();
                }
                config.save_changes (cfg_path);
            } catch (Error err) {
                warning (_("Error writing configuration file: %s").printf(err.message));
            }
        }

        public void show_about_dialog ()
        {
            string[] authors = {
                "<a href=\"mailto:Thomas Jollans &lt;t@jollybox.de&gt;\">Thomas Jollans</a>"
            };
            string translators = _(
                "<a href=\"mailto:Jan Drábek &lt;me@jandrabek.cz&gt;\">Jan Drábek</a> (Czech)\n<a href=\"mailto:Thomas Jollans &lt;t@jollybox.de&gt;\">Thomas Jollans</a> (German)"
                );
            string license_text =
              _("Emperor is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. \n\nThis program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details. \n\nYou should have received a copy of the GNU General Public License along with Emperor.  If not, see http://www.gnu.org/licenses/");

            string name_text = "Emperor " + Config.PACKAGE_VERSION_NAME;
            string effigy_file_name = Config.PACKAGE_VERSION_NAME + ".png";
            Gdk.Pixbuf logo;
            try {
                logo = new Gdk.Pixbuf.from_file (get_resource_file_path(effigy_file_name));
            } catch (Error load_error) {
                // Okay, so the effigy failed to load. Tough luck. Displaying nothing
                // is probably the best we can do.
                logo = null;
                warning (_("Error loading logo image: %s"), load_error.message);
            }

            Gtk.show_about_dialog (main_window,
                program_name : name_text,
                logo : logo, 
                version : Config.PACKAGE_VERSION,
                title : _("About Emperor"),
                authors : authors,
                translator_credits : translators,
                license : license_text,
                wrap_license : true,
                copyright : _("Copyright © 2011-2012 Thomas Jollans"),
                comments : _("Orthodox File Manager for GNOME") );
        }

        public static int main (string[] argv)
        {
            // Set up gettext

            Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.PROGRAMNAME_LOCALEDIR);
            Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
            Intl.textdomain (Config.GETTEXT_PACKAGE);

            // Configure command-line options

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

            // Let Gtk+ do the rest

            try {
                Gtk.init_with_args(ref argv, _("Orthodox File Manager for GNOME"),
                                   options, null);
            } catch (Error e) {
                stderr.printf (_("Error starting application: %s\n"), e.message);
                return 1;
            }

            // Initialize LibNotify

        #if HAVE_LIBNOTIFY
            if (!Notify.init("Emperor")) {
                stderr.printf (_("Error initializing notification system.\n"));
            }
        #endif

            // Set up Emperor itself

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

    /**
     * Turn a number of bytes into a human-readable file size
     */
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

    /**
     * Fancy reference class for when a pointer just won't do.
     */
    public class Ref<T>
    {
        public Ref (T initial_value) { val = initial_value; }
        public T val { get; set; }
    }


}


