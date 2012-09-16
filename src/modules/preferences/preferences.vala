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
using Gtk;
using Gee;
using Emperor.App;

namespace Emperor.Modules {

    // Use the annotation for pretty signal handler names
    [CCode (cprefix = "prefs_")]
    public class Preferences : Object
    {
        public EmperorCore app { get; construct; }
        public Gtk.Builder builder { get; construct; }
        public Window dialog_window { get; construct; }
        public Json.Object prefs_objects { get; construct; }

        public ColumnPrefs column_prefs { get; private set; }
        public MousePrefs mouse_prefs { get; internal set; }

        public
        Preferences (EmperorCore app)
            throws Error
        {
            var builder = new Gtk.Builder ();
            builder.add_from_file (app.get_resource_file_path ("prefs_dialog.ui"));
            var dialog_window = builder.get_object ("configDialog") as Window;

            var parser = new Json.Parser ();
            var objects_filename = app.get_resource_file_path ("prefs_objects.json");
            parser.load_from_file (objects_filename);
            var root = parser.get_root ();

            Object ( app : app,
                     builder : builder,
                     dialog_window : dialog_window,
                     prefs_objects : root.get_object () );
        }

        construct {
            builder.connect_signals (this);
            dialog_window.application = app;
            dialog_window.transient_for = app.main_window;

            try {
                column_prefs = new ColumnPrefs (this);
                mouse_prefs = new MousePrefs (this);
            } catch (ConfigurationError cerr) {
                error (_("Error loading preferences dialog."));
            }
        }

        [CCode (cname = "load_module")]
        public static void
        load_module (ModuleRegistry reg)
        {
            var app = reg.application;

            app.ui_manager.get_menu (_("_Tools"), 4);

            var prefs_action = reg.new_action ("preferences");
            prefs_action.label = _("_Preferences");
            app.ui_manager.add_action_to_menu (_("_Tools"), prefs_action, 90);

            prefs_action.activate.connect ( () => {
                    // Create preferences dialog
                    try {
                        var prefs = new Preferences (app);
                        prefs.show_preferences_dialog ();
                    } catch (Error err) {
                        error (_("Error loading preferences dialog."));
                    }
                });
        }

        public void
        show_preferences_dialog ()
        {
            dialog_window.show_all ();
            this.@ref ();
        }

        [CCode (instance_pos = -1)]
        public void
        close_dialog (Button source)
        {
            apply ();
            dialog_window.destroy ();
        }

        public signal void apply ();

        [CCode (instance_pos = -1)]
        public void
        on_configDialog_destroy ()
        {
            this.unref ();
        }

        [CCode (instance_pos = -1)]
        public void
        move_column_up (Button source)
        {
            column_prefs.move_column_up ();
        }

        [CCode (instance_pos = -1)]
        public void
        move_column_down (Button source)
        {
            column_prefs.move_column_down ();
        }

        [CCode (instance_pos = -1)]
        public void
        column_active_toggled (CellRendererToggle cellrenderer, string path)
        {
            column_prefs.column_active_toggled (cellrenderer, path);
        }

        [CCode (instance_pos = -1)]
        public void
        selection_mode_changed (ComboBox source)
        {
            mouse_prefs.selection_mode_changed ();
        }

    }

}
