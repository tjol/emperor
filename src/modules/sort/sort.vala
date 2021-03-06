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
using Emperor.App;

namespace Emperor.Modules {

    public int cmp_text (Value a, Value b)
    {
        string str1 = null, str2 = null;

        if ((!a.holds(typeof(string))) || (str1 = a.get_string()) == null) {
            return 1;
        } else if ((!b.holds(typeof(string))) || (str2 = b.get_string()) == null) {
            return -1;
        }

        return strcmp (str1, str2);
    }

    public int cmp_unicode (Value a, Value b)
    {
        string str1 = null, str2 = null;

        if ((!a.holds(typeof(string))) || (str1 = a.get_string()) == null) {
            return 1;
        } else if ((!b.holds(typeof(string))) || (str2 = b.get_string()) == null) {
            return -1;
        }

        return str1.collate (str2);
    }

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

    public int cmp_uint64 (Value a, Value b)
    {
        uint64 u1, u2;

        if (!a.holds(typeof(uint64))) {
            return 1;
        } else if (!b.holds(typeof(uint64))) {
            return -1;
        }

        u1 = a.get_uint64();
        u2 = b.get_uint64();

        if (u1 == u2) {
            return 0;
        } else if (u1 < u2) {
            return 1;
        } else {
            return -1;
        }
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
            if (a.get_display_name() == "..") {
                return -1;
            } else if (b.get_display_name() == "..") {
                return 1;
            }
            return 0;
        }
    }
}

public void load_module (ModuleRegistry reg)
{
    reg.register_sort_function ("text", Emperor.Modules.cmp_text);
    reg.register_sort_function ("unicode", Emperor.Modules.cmp_unicode);
    reg.register_sort_function ("filename-collation", Emperor.Modules.cmp_filename_collation);
    reg.register_sort_function ("datetime", Emperor.Modules.cmp_datetime);
    reg.register_sort_function ("size", Emperor.Modules.cmp_uint64);
    reg.register_sort_function ("uint64", Emperor.Modules.cmp_uint64);

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
            reg.application.config["preferences"].set_boolean ("sort/directories-first", flag);
        } );
    reg.application.ui_manager.add_action_to_menu (_("_View"), dir_first_act);

    reg.application.ui_manager.main_window_ready.connect ( (main_window) => {
        bool dir_first = reg.application.config["preferences"]
                .get_boolean_default ("sort/directories-first", true);
        dir_first_act.active = dir_first;
    } );
}

