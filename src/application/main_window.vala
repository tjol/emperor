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
using Gtk;

namespace Emperor.Application {
    
    public class MainWindow : Window
    {
        EmperorCore m_app;

        VBox m_main_box;
        HPaned m_panes;
        HButtonBox m_command_buttons;

        public FilePane left_pane { get; private set; }
        public FilePane right_pane { get; private set; }

        public FilePane active_pane {
            get { 
                if (left_pane.active) {
                    return left_pane;
                } else {
                    return right_pane;
                }
            }
            set {
                value.active = true;
            }
        }

        public MainWindow (EmperorCore app)
        {
            m_app = app;

            // add widgets.
            m_main_box = new VBox (false, 0);
            m_panes = new HPaned ();

            left_pane = new FilePane(m_app);
            right_pane = new FilePane(m_app);
            left_pane.pwd = File.new_for_path(".");
            right_pane.pwd = File.new_for_path("/");

            m_panes.pack1 (left_pane, true, true);
            m_panes.pack2 (right_pane, true, true);

            this.map_event.connect (on_paned_map);

            m_main_box.pack_start (m_panes, true, true, 0);

            m_command_buttons = new HButtonBox ();
            foreach (var cmd in m_app.ui_manager.command_buttons) {
                var btn = new Button.with_label ("%s %s".printf(cmd.keystring, cmd.title));
                btn.clicked.connect (() => {
                        cmd.cmd (new string[0]);
                    });
                m_command_buttons.pack_start (btn, false, false);
            }
            m_command_buttons.halign = Align.START;
            m_command_buttons.margin = 3;
            m_command_buttons.spacing = 3;

            m_main_box.pack_start (m_command_buttons, false, false, 0);

            add (m_main_box);

            set_default_size (900, 500);
            this.title = "Emperor";

            destroy.connect (on_destroy);
        }

        bool on_paned_map (Gdk.Event e)
        {
            // make sure the HPaned is split in the middle at the start.
            int w = m_panes.get_allocated_width ();
            m_panes.position = w / 2;
            active_pane = right_pane;
            active_pane = left_pane;
            return false;
        }

        void on_destroy ()
        {
            main_quit ();
        }

    }

}

