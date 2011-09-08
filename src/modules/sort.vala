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
    public int cmp_filename_collation (Value a, Value b)
    {
        string str1 = null, str2 = null;

        if ((!a.holds(typeof(string))) || (str1 = a.get_string()) == null) {
            return 1;
        } else if ((!b.holds(typeof(string))) || (str2 = b.get_string()) == null) {
            return -1;
        }

        var key1 = str1.collate_key_for_filename();
        var key2 = str2.collate_key_for_filename();
        return strcmp(key1, key2);
    }

    public int cmp_datetime (Value a, Value b)
    {
        DateTime dt1 = null, dt2 = null;

        if ((!a.holds(typeof(DateTime))) || (dt1 = (DateTime) a.get_boxed()) == null) {
            return 1;
        } else if ((!b.holds(typeof(DateTime))) || (dt2 = (DateTime) b.get_boxed()) == null) {
            return -1;
        }

        return dt1.compare (dt2);
    }

    public int cmp_directories_first (FileInfo a, FileInfo b)
    {
        FileType type_a = a.get_file_type ();
        FileType type_b = b.get_file_type ();

        if (type_a == FileType.DIRECTORY && type_b != FileType.DIRECTORY) {
            return -1;
        } else if (type_a != FileType.DIRECTORY && type_b == FileType.DIRECTORY) {
            return +1;
        } else {
            return 0;
        }
    }
}

public void load_module (ModuleRegistry reg)
{
    reg.register_sort_function ("filename-collation", Emperor.Modules.cmp_filename_collation);
    reg.register_sort_function ("datetime", Emperor.Modules.cmp_datetime);

    // Action: Sort directories first
    var dir_first_act = new Gtk.ToggleAction ("sort/toggle:directories-first",
                                              _("Sort directories first"),
                                              null, null);
    reg.register_action (dir_first_act);
    dir_first_act.set_accel_path ("<Emperor-Main>/Sort/Directories_First");
    dir_first_act.toggled.connect ( () => {
            var mw = reg.application.main_window;
            bool flag = dir_first_act.active;
            if (flag) {
                mw.left_pane.add_sort ("directories-first", Emperor.Modules.cmp_directories_first);
                mw.right_pane.add_sort ("directories-first", Emperor.Modules.cmp_directories_first);
            } else {
                mw.left_pane.remove_sort ("directories-first");
                mw.right_pane.remove_sort ("directories-first");
            }
            reg.application.prefs.set_boolean ("sort/directories-first", flag);
        } );
    reg.application.ui_manager.add_action_to_menu (_("_View"), dir_first_act);

    reg.application.ui_manager.main_window_ready.connect ( (main_window) => {
        bool dir_first = reg.application.prefs.get_boolean ("sort/directories-first", true);
        dir_first_act.active = dir_first;
    } );
}

