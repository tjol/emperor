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
using Emperor;

namespace Emperor.Modules {
    
    public class FilenameColumn : TextFileInfoColumn
    {
        LinkedList<string> m_attrs;

        public FilenameColumn ()
        {
            m_attrs = new LinkedList<string>();
            m_attrs.add(FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME);
        }

        public override Value get_value (FileInfo fi)
        {
            var v = Value(typeof(string));
            v.set_string(fi.get_display_name());
            return v;
        }

        public override Type column_type { get { return typeof(string); } }
        
        public override Collection<string> file_attributes { get { return m_attrs; } }

    }

    public class IconColumn : Object, FileInfoColumn
    {
        LinkedList<string> m_attrs;

        public IconColumn ()
        {
            m_attrs = new LinkedList<string>();
            m_attrs.add(FILE_ATTRIBUTE_STANDARD_ICON);
        }

        public Value get_value (FileInfo fi)
        {
            var v = Value(typeof(Icon));
            var icon = fi.get_icon();
            v.set_object(icon);
            return v;
        }

        public Type column_type { get { return typeof(Icon); } }

        public Collection<string> file_attributes { get { return m_attrs; } }

        public void add_to_column (TreeViewColumn column,
                                   int idx_data,
                                   int idx_fg_rgba,
                                   int idx_fg_set,
                                   int idx_bg_rgba,
                                   int idx_bg_set,
                                   int idx_weight,
                                   int idx_weight_set,
                                   int idx_style,
                                   int idx_style_set)
        {
            var renderer = new CellRendererPixbuf ();
            column.pack_start (renderer, false);
            column.add_attribute (renderer, "gicon", idx_data);
            column.add_attribute (renderer, "cell-background-rgba", idx_bg_rgba);
            column.add_attribute (renderer, "cell-background-set", idx_bg_set);
        }

    }

}

public void load_module (ModuleRegistry reg)
{
    reg.register_column("icon", new Emperor.Modules.IconColumn());
    reg.register_column("filename", new Emperor.Modules.FilenameColumn());
}



