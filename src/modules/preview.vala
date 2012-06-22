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
using Emperor;
using Emperor.Application;

namespace Emperor.Modules {

    public class PreviewModule : Object
    {
        public static void register (ModuleRegistry reg)
        {
            var app = reg.application;
            var module = new PreviewModule (app);

            // Preview pane
            var action = new Gtk.ToggleAction ("toggle:previewpane",
                                              _("Preview Pane"),
                                              null, null);
            reg.register_action (action);
            action.set_accel_path ("<Emperor-Main>/Preview/PreviewPane");
            Gtk.AccelMap.add_entry ("<Emperor-Main>/Preview/PreviewPane",
                                    Gdk.KeySym.P, Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.MOD1_MASK);
            action.toggled.connect ( () => {
                    module.toggle_preview_window ();
                } );
            action.connect_accelerator ();
            app.ui_manager.add_action_to_menu (_("_View"), action, 99);
        }

        public PreviewModule (EmperorCore app)
        {
            Object ( application : app );
        }

        public EmperorCore application { get; construct; }

        public void toggle_preview_window ()
        {
            if (m_preview_wnd == null) {
                var appwnd = application.main_window;
                m_preview_wnd = new PreviewWindow (appwnd);

                m_preview_wnd.update_geometry ();

                setup_events ();
            } else {
                m_preview_wnd.destroy ();
                m_preview_wnd = null;
            }
        }

        private bool m_events_set_up = false;
        public void setup_events ()
        {
            var appwnd = application.main_window;

            appwnd.add_events (Gdk.EventMask.STRUCTURE_MASK);
            appwnd.configure_event.connect ( (ev) => {
                if (m_preview_wnd == null)
                    return false;
                else {
                    m_preview_wnd.update_geometry ();
                    return false;
                }
            } );

            appwnd.active_pane.notify["active"].connect ( p => {
                if (m_preview_wnd != null) {
                    m_preview_wnd.update_geometry ();
                }
            } );

            m_events_set_up = true;
        }

        public class PreviewWindow : Gtk.Window
        {
            public PreviewWindow (MainWindow parent)
            {
                Object ( app_window : parent,
                         transient_for : parent,
                         decorated : false,
                         skip_pager_hint : true,
                         skip_taskbar_hint : true,
                         accept_focus : false,
                         focus_on_map: false,
                         type : WindowType.POPUP );
            }

            public MainWindow app_window { get; construct; }

            public void update_geometry ()
            {
                var pane = app_window.active_pane;
                bool is_left = (pane == app_window.left_pane);
                int width = pane.get_allocated_width () / 2;
                int height = (int) (pane.get_allocated_height () * 0.8);

                int posx;
                int posy;
                app_window.get_position (out posx, out posy);
                Allocation alloc;
                pane.get_allocation (out alloc);
                posy += (app_window.get_allocated_height() / 2) - (height / 2) + 32;

                if (is_left) {
                    posx -= width;
                } else {
                    posx += app_window.get_allocated_width ();
                }

                default_width = width;
                default_height = height;
                show_all ();
                move (posx, posy);

                set_keep_below (true);
            }
        }

        private PreviewWindow? m_preview_wnd;

    }

}

public void load_module (ModuleRegistry reg)
{
    Emperor.Modules.PreviewModule.register (reg);
}


