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

namespace Emperor.Modules {
    public int cmp_filename_collation(Value a, Value b)
    {
        if (!a.holds(typeof(string)))
            return 1;
        else if (!b.holds(typeof(string)))
            return -1;

        var key1 = a.get_string().collate_key_for_filename();
        var key2 = b.get_string().collate_key_for_filename();
        return strcmp(key1, key2);
    }
}

public void load_module (ModuleRegistry reg)
{
    reg.register_sort_function ("filename-collation", Emperor.Modules.cmp_filename_collation);
}

