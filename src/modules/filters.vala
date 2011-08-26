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
        return currently_visible && ( ! info.get_is_hidden () );
    }

    public bool filter_backup (File f, FileInfo fi, bool currently_visible)
    {
        var info = f.query_info (FILE_ATTRIBUTE_STANDARD_IS_BACKUP,
                                 FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
        return currently_visible && ( ! info.get_is_backup () );
    }

    public void toggle_filter (MainWindow main_window, string filter,
                               FilePane.FileFilterFunc func,
                               bool? use_filter=null)
    {
        bool flag;
        if (use_filter != null) {
            flag = use_filter;
        } else {
            flag = main_window.left_pane.using_filter (filter);
        }
        if (flag) {
            // switch filter on.
            main_window.left_pane.add_filter (filter, func);
            main_window.right_pane.add_filter (filter, func);
        } else {
            // switch filter off.
            main_window.left_pane.remove_filter (filter);
            main_window.right_pane.remove_filter (filter);
        }
    }
}

public void load_module (ModuleRegistry reg)
{
    var app = reg.application;

    // Action: Show Hidden <Ctrl+H>
    var hidden_action = new Gtk.ToggleAction ("filters/toggle:hidden",
                                              _("Show Hidden Files"),
                                              null, null);
    reg.register_action (hidden_action);
    hidden_action.set_accel_path ("<Emperor-Main>/Filters/Toggle_Hidden");
    Gtk.AccelMap.add_entry ("<Emperor-Main>/Filters/Toggle_Hidden",
                        Gdk.KeySym.H, Gdk.ModifierType.CONTROL_MASK);
    hidden_action.toggled.connect ( () => {
            Emperor.Modules.toggle_filter (app.main_window,
                "filters/hidden", Emperor.Modules.filter_hidden,
                ! hidden_action.active );
        } );
    hidden_action.connect_accelerator ();
    app.ui_manager.add_action_to_menu (_("_View"), hidden_action);

    // Action: Show Backup
    var backup_action = new Gtk.ToggleAction ("filters/toggle:backup",
                                              _("Show Backup Files"),
                                              null, null);
    reg.register_action (backup_action);
    // no accelerator.
    backup_action.toggled.connect ( () => {
            Emperor.Modules.toggle_filter (app.main_window,
                "filters/backup", Emperor.Modules.filter_backup,
                ! backup_action.active );
        } );
    app.ui_manager.add_action_to_menu (_("_View"), backup_action);

    // Hide hidden and backup files by default:
    app.ui_manager.main_window_ready.connect ( (main_window) => {
            Emperor.Modules.toggle_filter (main_window,
                "filters/hidden", Emperor.Modules.filter_hidden,
                true);
            Emperor.Modules.toggle_filter (main_window,
                "filters/backup", Emperor.Modules.filter_backup,
                true);
        } );
}

