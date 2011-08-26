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
using Emperor;
using Emperor.Application;

namespace Emperor.Modules {
    
    public bool filter_hidden (File f, FileInfo fi, bool currently_visible)
    {
        var info = f.query_info (FILE_ATTRIBUTE_STANDARD_IS_HIDDEN,
                                 FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
        return ! info.get_is_hidden ();
    }

    public void toggle_filter (MainWindow main_window, string filter,
                               FilePane.FileFilterFunc func)
    {
        if (main_window.left_pane.using_filter (filter)) {
            // switch filter off.
            main_window.left_pane.remove_filter (filter);
            main_window.right_pane.remove_filter (filter);
        } else {
            // switch filter on.
            main_window.left_pane.add_filter (filter, func);
            main_window.right_pane.add_filter (filter, func);
        }
    }
}

public void load_module (ModuleRegistry reg)
{
    var app = reg.application;

    Gtk.Action action;

    // Action: Show Hidden <Ctrl+H>
    action = reg.new_action ("filters/toggle:hidden");
    action.label = "Show Hidden Files";
    action.set_accel_path ("<Emperor-Main>/Filters/Toggle_Hidden");
    Gtk.AccelMap.add_entry ("<Emperor-Main>/Filters/Toggle_Hidden",
                        Gdk.KeySym.H, Gdk.ModifierType.CONTROL_MASK);
    action.activate.connect ( () => {
            Emperor.Modules.toggle_filter (app.main_window,
                "filters/hidden", Emperor.Modules.filter_hidden);
        } );
    action.connect_accelerator ();
    app.ui_manager.add_action_to_menu ("_View", action);


    // Hide hidden files by default:
    app.ui_manager.main_window_ready.connect ( (main_window) => {
            Emperor.Modules.toggle_filter (main_window,
                "filters/hidden", Emperor.Modules.filter_hidden);
        } );
}


