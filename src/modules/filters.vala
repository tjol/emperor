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
using Emperor.App;

namespace Emperor.Modules {
    
    public bool filter_hidden (File f, FileInfo fi, bool currently_visible)
    {
        return currently_visible && (! fi.get_is_hidden () );
    }

    public bool filter_backup (File f, FileInfo fi, bool currently_visible)
    {
        return currently_visible && (! fi.get_is_backup () );
    }

    public void toggle_filter (MainWindow main_window, string filter,
                               owned FileFilterFunc func,
                               bool? use_filter=null)
    {
        bool flag;
        if (use_filter != null) {
            flag = use_filter;
        } else {
            flag = ! main_window.left_pane.using_filter (filter);
        }
        if (flag) {
            // switch filter on.
            main_window.left_pane.add_filter (filter, (owned) func);
            main_window.right_pane.add_filter (filter, (owned) func);
        } else {
            // switch filter off.
            main_window.left_pane.remove_filter (filter);
            main_window.right_pane.remove_filter (filter);
        }
        
        // save to prefs
        ((EmperorCore) main_window.application).prefs.set_boolean ("use-filter:"+filter, flag);
    }
}

public void load_module (ModuleRegistry reg)
{
    var app = reg.application;

    app.ui_manager.get_menu (_("_View"), 2);

    // Action: Show Hidden <Ctrl+H>
    var hidden_action = new Gtk.ToggleAction ("filters/toggle:hidden",
                                              _("Show Hidden Files"),
                                              null, null);
    reg.register_action (hidden_action);
    hidden_action.set_accel_path ("<Emperor-Main>/Filters/Toggle_Hidden");
    Gtk.AccelMap.add_entry ("<Emperor-Main>/Filters/Toggle_Hidden",
                        Gdk.Key.H, Gdk.ModifierType.CONTROL_MASK);
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

    // Read prefs (default: hide.)
    app.ui_manager.main_window_ready.connect ( (main_window) => {
            // pre-requisites.
            main_window.left_pane.add_query_attribute (FileAttribute.STANDARD_IS_HIDDEN);
            main_window.left_pane.add_query_attribute (FileAttribute.STANDARD_IS_BACKUP);
            main_window.right_pane.add_query_attribute (FileAttribute.STANDARD_IS_HIDDEN);
            main_window.right_pane.add_query_attribute (FileAttribute.STANDARD_IS_BACKUP);

            var hide_hidden = app.prefs.get_boolean ("use-filter:filters/hidden", true);
            var hide_backup = app.prefs.get_boolean ("use-filter:filters/backup", true);

            Emperor.Modules.toggle_filter (main_window,
                "filters/hidden", Emperor.Modules.filter_hidden,
                hide_hidden);
            hidden_action.active = !hide_hidden;

            Emperor.Modules.toggle_filter (main_window,
                "filters/backup", Emperor.Modules.filter_backup,
                hide_backup);
            backup_action.active = !hide_backup;
        } );
}


