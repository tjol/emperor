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

namespace Emperor {

    /**
     * Module interface type providing a column in the file listing.
     * 
     * @see ModuleRegistry.register_column
     */
    public interface FileInfoColumn : Object
    {
        /**
         * Extract the value to be displayed (and stored in the TreeModel)
         * from a GIO FileInfo object.
         */
        public abstract Value get_value (File dir, FileInfo fi);

        /**
         * The type of the values returned by get_value
         */
        public abstract Type column_type { get; }

        /**
         * The file attributes to be queried. If get_value expects an
         * attribute to be present, it should be included here.
         */
        public abstract Collection<string> file_attributes { get; }

        /**
         * Install a CellRenderer to display the data queried.
         */
        public abstract void add_to_column (TreeViewColumn column,
                                            int idx_data,
                                            int idx_fg_rgba,
                                            int idx_fg_set,
                                            int idx_bg_rgba,
                                            int idx_bg_set,
                                            int idx_weight,
                                            int idx_weight_set,
                                            int idx_style,
                                            int idx_style_set);
    }

    public abstract class TextFileInfoColumn : Object, FileInfoColumn
    {
        public abstract Value get_value (File dir, FileInfo fi);
        public abstract Type column_type { get; }
        public abstract Collection<string> file_attributes { get; }

        public virtual void add_to_column (TreeViewColumn column,
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
            var renderer = new CellRendererText();
            column.pack_start (renderer, true);
            column.add_attribute (renderer, "text", idx_data);
            column.add_attribute (renderer, "foreground-rgba", idx_fg_rgba);
            column.add_attribute (renderer, "foreground-set", idx_fg_set);
            column.add_attribute (renderer, "cell-background-rgba", idx_bg_rgba);
            column.add_attribute (renderer, "cell-background-set", idx_bg_set);
            column.add_attribute (renderer, "weight", idx_weight);
            column.add_attribute (renderer, "weight-set", idx_weight_set);
            column.add_attribute (renderer, "style", idx_style);
            column.add_attribute (renderer, "style-set", idx_style_set);
        }
    }

}


