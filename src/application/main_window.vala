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
using Gee;

namespace Emperor.Application {
    
    public class MainWindow : Window
    {
        EmperorCore m_app;

        VBox m_main_box;
        HPaned m_panes;
        HBox m_command_buttons;

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

        public FilePane passive_pane {
            get {
                return active_pane.other_pane;
            }
        }

        public MainWindow (EmperorCore app)
        {
            m_app = app;

            // add widgets.
            m_main_box = new VBox (false, 0);

            m_main_box.pack_start (app.ui_manager.menu_bar, false, false, 0);

            m_panes = new HPaned ();

            left_pane = new FilePane(m_app, "left");
            right_pane = new FilePane(m_app, "right");
            m_panes.pack1 (left_pane, true, true);
            m_panes.pack2 (right_pane, true, true);

            this.map_event.connect (on_paned_map);

            m_main_box.pack_start (m_panes, true, true, 0);

            m_command_buttons = new HBox (false, 3);
            foreach (var act in m_app.ui_manager.command_buttons) {
                AccelKey key;
                AccelMap.lookup_entry (act.get_accel_path(), out key);
                var btn = new Button.with_label ("%s %s".printf(
                        accelerator_get_label (key.accel_key, key.accel_mods),
                        act.short_label.replace("_","")));
                btn.clicked.connect (() => {
                        act.activate ();
                    });
                m_command_buttons.pack_start (btn, true, true, 0);
            }
            //m_command_buttons.halign = Align.START;
            m_command_buttons.margin = 3;

            m_main_box.pack_start (m_command_buttons, false, true, 0);

            add (m_main_box);

            set_default_size (m_app.prefs.get_int32("window-x", 900),
                              m_app.prefs.get_int32("window-y", 500));
            this.title = _("Emperor");

            destroy.connect (on_destroy);
            //key_press_event.connect (on_key_press);

            add_accel_group (m_app.modules.default_accel_group);

            // Register this window with the GtkApplication
            this.application = m_app;

            // attempt to set the icon.
            set_icon_name ("emperor-fm");

        }

        bool on_paned_map (Gdk.Event e)
        {
            // make sure the HPaned is split in the middle at the start.
            int w = m_panes.get_allocated_width ();
            m_panes.position = w / 2;
            active_pane = left_pane;

            set_directories.begin ();

            m_app.ui_manager.main_window_ready (this);

            return false;
        }

        async void set_directories ()
        {
            if (!yield left_pane.chdir_from_pref()) {
                yield left_pane.chdir(File.new_for_path("."));
            }
            if (!yield right_pane.chdir_from_pref()) {
                yield right_pane.chdir(File.new_for_path("."));
            }
        }

        void on_destroy ()
        {
            m_app.prefs.set_int32 ("window-x", get_allocated_width());
            m_app.prefs.set_int32 ("window-y", get_allocated_height());
        }

    }

}

