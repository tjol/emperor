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
        MODULE_ERROR
    }

    public class EmperorCore : Object
    {

        public ModuleRegistry modules { get; private set; }
        public UserInterfaceManager ui_manager { get; private set; }
        public MainWindow main_window { get; private set; }

        public EmperorCore (string? module_location, string? config_fname)
                throws ConfigurationError
        {
            modules = new ModuleRegistry (this, module_location);

            ui_manager = new UserInterfaceManager (this);

            // read the XML configuration.
            if (config_fname == null) {
                config_fname = "config.xml";
            }
            
            Xml.Parser.init ();
            Xml.Doc* document = Xml.Parser.read_file (config_fname);
            if (document == null) {
                throw new ConfigurationError.PARSE_ERROR (config_fname);
            }

            try {
                Xml.Node* root = document->get_root_element ();
                handle_config_xml_nodes(root);
            } finally {
                delete document;
                Xml.Parser.cleanup ();
            }

            main_window = new MainWindow (this);
            main_window.show_all ();
        }

        private void handle_config_xml_nodes (Xml.Node* parent)
                        throws ConfigurationError
        {
            if (parent->name != "emperor-config") {
                throw new ConfigurationError.INVALID_ERROR(
                            "Unexpected root element: " + parent->name);
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
                                    "Unexpected element: " + node->name);
                    }
                }
            }
        }

        public void main_loop ()
        {
            Gtk.main ();
        }

        public static int main (string[] argv)
        {
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
                    description = "Location of Emperor modules",
                    arg_description = "Location of Emperor modules" },
                OptionEntry () {
                    long_name = "config",
                     short_name = 'c',
                     flags = 0,
                     arg = OptionArg.FILENAME,
                     arg_data = p_config_file,
                     description = "Configuration file",
                     arg_description = "XML file to read configuration from" }
            };

            Gtk.init_with_args(ref argv, "Orthodox file manager for GNOME",
                               options, null);

            EmperorCore app;
            try {
                app = new EmperorCore (module_location, config_file);
            } catch (ConfigurationError e) {
                if (e is ConfigurationError.PARSE_ERROR) {
                    stderr.printf("ERROR: Cannot parse file \"%s\"\n", e.message);
                } else {
                    stderr.printf("ERROR: %s\n", e.message);
                }
                return 1;
            }
            app.main_loop ();

            return 0;
        }

    }

}


