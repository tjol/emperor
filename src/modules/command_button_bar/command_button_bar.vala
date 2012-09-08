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
using Gtk;
using Emperor.App;

namespace Emperor.Modules {
    internal void
    on_main_window_ready (MainWindow mwnd)
    {
        var cmd_bar = new CommandBar ((EmperorCore) mwnd.application, mwnd);
        cmd_bar.add_to_main_window ();
    }

    internal class CommandBar : HBox
    {
        public EmperorCore application { get; construct; }
        public MainWindow main_window { get; construct; }

        public
        CommandBar (EmperorCore app, MainWindow mwnd)
        {
            Object ( homogeneous : false,
                     spacing : 3,
                     margin: 3,
                     application : app,
                     main_window : mwnd );
        }

        construct {
            add_buttons_from_config (application.config["command-button-bar"]["buttons"]);
            application.config["command-button-bar"].property_changed["buttons"] += add_buttons_from_config;
        }

        private void
        add_buttons_from_config (Json.Node cfg)
        {
            if (cfg.get_node_type () != Json.NodeType.ARRAY) {
                warning (_("Command button bar configuration invalid."));
                return;
            }

            // remove old buttons, if there are any.
            foreach (var child in get_children ()) {
                child.destroy ();
            }

            foreach (var btn_node in cfg.get_array ().get_elements ()) {
                if (btn_node.get_value_type () != typeof(string)) {
                    warning (_("Command button bar configuration invalid."));
                    continue;
                }
                var btn_name = btn_node.get_string ();

                var action = application.modules.actions.get_action (btn_name);
                if (action == null) {
                    warning (_("Unknown action: %s").printf(btn_name));
                    continue;
                }

                AccelKey key;
                AccelMap.lookup_entry (action.get_accel_path(), out key);
                var btn = new Button.with_label ("%s %s".printf(
                        accelerator_get_label (key.accel_key, key.accel_mods),
                        action.short_label.replace("_","")));
                btn.clicked.connect (() => {
                        action.activate ();
                    });
                pack_start (btn, true, true, 0);
                btn.show_all ();
            }
        }

        public void
        add_to_main_window ()
        {
            main_window.main_vbox.pack_end (this, false, true, 0);
            show_all ();
        }
    }
}

public void load_module (ModuleRegistry reg)
{
    reg.application.ui_manager.main_window_ready.connect (Emperor.Modules.on_main_window_ready);
}

