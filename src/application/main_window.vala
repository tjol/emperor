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

        FilePane m_left_pane;
        FilePane m_right_pane;
        
        public MainWindow (EmperorCore app)
        {
            m_app = app;

            // add widgets.
            m_main_box = new VBox (false, 0);
            m_panes = new HPaned ();

            m_left_pane = new FilePane(m_app);
            m_right_pane = new FilePane(m_app);
            m_left_pane.pwd = File.new_for_path(".");
            m_right_pane.pwd = File.new_for_path("/");

            m_panes.pack1 (m_left_pane, true, true);
            m_panes.pack2 (m_right_pane, true, true);

            this.map_event.connect (on_paned_map);

            m_main_box.pack_start (m_panes, true, true, 0);

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
            m_right_pane.activate_pane ();
            m_left_pane.activate_pane ();
            return false;
        }

        void on_destroy ()
        {
            main_quit ();
        }

    }

}

