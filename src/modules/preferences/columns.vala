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
using Gee;
using Emperor.App;

namespace Emperor.Modules {

    public class ColumnPrefs : Object
    {
        public EmperorCore app { get; construct; }
        public Preferences prefs { get; construct; }
        public TreeView column_list_view { get; construct; }
        public ListStore column_list { get; construct; }
        public Json.Parser col_types_parser { get; construct; }

        int m_count = 0;
        
        public
        ColumnPrefs (Preferences prefs)
            throws ConfigurationError
        {
            var col_list = prefs.builder.get_object ("lstColumns") as ListStore;
            var col_view = prefs.builder.get_object ("columnList") as TreeView;

            Json.Parser parser;
            try {
                parser = new Json.Parser ();
                var coltypes_filename = prefs.app.get_config_file_path ("column-types.json");
                parser.load_from_file (coltypes_filename);
            } catch (Error e) {
                throw new ConfigurationError.PARSE_ERROR (e.message);
            }

            Object ( app : prefs.app,
                     prefs : prefs,
                     column_list : col_list,
                     column_list_view : col_view,
                     col_types_parser : parser );
        }

        construct {
            // get all columns and add them to the ListStore
            var added_columns = new HashMap<string,TreeIter?> ();

            var col_cfg_node = app.config["user-interface"]["file-pane-columns"];

            foreach (var node in col_cfg_node.get_array ().get_elements ()) {
                if (node.get_value_type () == typeof (string)) {
                    var name = node.get_string ();
                    TreeIter iter;
                    column_list.append (out iter);
                    column_list.set (iter, 0, true, // active
                                           1, name, // name
                                           -1);
                    added_columns[name] = iter;
                    m_count ++;
                }
            }

            var col_types_object = col_types_parser.get_root ().get_object ();

            foreach (var col_name in col_types_object.get_members ()) {
                var col_def = col_types_object.get_object_member (col_name);
                TreeIter iter;
                if (added_columns.has_key (col_name)) {
                    iter = added_columns[col_name];
                } else {
                    column_list.append (out iter);
                    column_list.set (iter, 0, false,    // inactive
                                           1, col_name, // name
                                           -1);
                    m_count ++;
                }
                column_list.set (iter, 2, _(col_def.get_string_member ("title")),
                                       3, _(col_def.get_string_member ("description")),
                                       -1);
            }

            prefs.apply.connect (apply);
        }

        public void
        move_column_up ()
        {
            TreeModel model;
            TreeIter iter;
            column_list_view.get_selection ().get_selected (out model, out iter);

            assert (model == column_list);

            TreeIter prev = iter;
            if (column_list.iter_previous (ref prev)) {
                column_list.swap (iter, prev);
            }
        }

        public void
        move_column_down ()
        {
            TreeModel model;
            TreeIter iter;
            column_list_view.get_selection ().get_selected (out model, out iter);

            assert (model == column_list);

            TreeIter next = iter;
            if (column_list.iter_next (ref next)) {
                column_list.swap (iter, next);
            }
        }

        public void
        column_active_toggled (CellRendererToggle cellrenderer, string path_string)
        {
            TreeIter iter;
            column_list.get_iter_from_string (out iter, path_string);

            bool active;
            column_list.get (iter, 0, out active, -1);
            active = !active;
            column_list.set (iter, 0, active, -1);
        }

        public void
        apply ()
        {
            var array = new Json.Array ();

            TreeIter iter;
            if (!column_list.get_iter_first (out iter)) {
                return;
            }

            do {
                bool active;
                string name;
                column_list.get (iter, 0, out active,
                                       1, out name,
                                       -1);
                if (active) {
                    array.add_string_element (name);
                }
            } while (column_list.iter_next (ref iter));

            var json_node = new Json.Node (Json.NodeType.ARRAY);
            json_node.set_array (array);
            app.config["user-interface"]["file-pane-columns"] = json_node;
        }
    }
}