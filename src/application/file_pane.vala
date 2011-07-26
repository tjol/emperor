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
using Gdk;
using Gee;

namespace Emperor.Application {

    public enum FilePaneState {
        ACTIVE,
        PASSIVE,
        EITHER
    }

    public class FilePane : VBox
    {
        EmperorCore m_app;
        TreeView m_list;
        Label m_pane_title;
        EventBox m_pane_title_bg;
        Label m_error_message;
        EventBox m_error_message_bg;
        ListStore m_liststore;
        TreePath m_cursor_path;
        FileInfoColumn[] m_store_cells;
        Type[] m_store_types;
        Map<int,TreeIterCompareFuncWrapper> m_cmp_funcs;
        Set<string> m_file_attributes;
        string m_file_attributes_str;

        public int COL_FILEINFO { get; private set; }
        public int COL_SELECTED { get; private set; }
        public int COL_FG_COLOR { get; private set; }
        public int COL_FG_SET { get; private set; }
        public int COL_BG_COLOR { get; private set; }
        public int COL_BG_SET { get; private set; }
        public int COL_WEIGHT { get; private set; }
        public int COL_WEIGHT_SET { get; private set; }
        public int COL_STYLE { get; private set; }
        public int COL_STYLE_SET { get; private set; }

        public FilePane (EmperorCore app)
        {
            m_app = app;

            /*
             * Create and add the title Label
             */
            m_pane_title = new Label("");
            m_pane_title.ellipsize = Pango.EllipsizeMode.START;
            m_pane_title.single_line_mode = true;
            m_pane_title.halign = Align.FILL | Align.START;
            m_pane_title.margin = 3;
            m_pane_title_bg = new EventBox();
            m_pane_title_bg.margin = 2;
            m_pane_title_bg.add(m_pane_title);
            pack_start(m_pane_title_bg, false, false);

            /*
             * Create and add the TreeView
             */
            m_list = new TreeView();
            var selector = m_list.get_selection();
            selector.set_mode(SelectionMode.NONE);

            m_list.focus_in_event.connect (on_focus_event);
            m_list.focus_out_event.connect (on_focus_event);
            m_list.cursor_changed.connect (cursor_changed);

            m_list.button_press_event.connect (on_mouse_event);
            m_list.button_release_event.connect (on_mouse_event);
            m_list.key_press_event.connect (on_key_event);
            m_list.motion_notify_event.connect (on_motion_notify);

            // get columns and do setup work.

            var store_cells = new LinkedList<FileInfoColumn?>();
            var store_types = new LinkedList<Type>();
            m_cmp_funcs = new HashMap<int,TreeIterCompareFuncWrapper>();
            m_file_attributes = new HashSet<string>();
            m_file_attributes.add(FILE_ATTRIBUTE_STANDARD_NAME);
            m_file_attributes.add(FILE_ATTRIBUTE_STANDARD_TYPE);

            //// standard columns:
            int idx = 0;

            // FileInfo
            COL_FILEINFO = idx++;
            store_types.add(typeof(FileInfo));
            store_cells.add(null);

            // selected?
            COL_SELECTED = idx++;
            store_types.add(typeof(bool));
            store_cells.add(null);

            // foreground-gdk
            COL_FG_COLOR = idx++;
            store_types.add(typeof(RGBA));
            store_cells.add(null);

            // foreground-set
            COL_FG_SET = idx++;
            store_types.add(typeof(bool));
            store_cells.add(null);

            // background-gdk
            COL_BG_COLOR = idx++;
            store_types.add(typeof(RGBA));
            store_cells.add(null);

            // background-set
            COL_BG_SET = idx++;
            store_types.add(typeof(bool));
            store_cells.add(null);

            // weight
            COL_WEIGHT = idx++;
            store_types.add(typeof(int));
            store_cells.add(null);

            // weight-set
            COL_WEIGHT_SET = idx++;
            store_types.add(typeof(bool));
            store_cells.add(null);

            // style
            COL_STYLE = idx++;
            store_types.add(typeof(Pango.Style));
            store_cells.add(null);

            // style-set
            COL_STYLE_SET = idx++;
            store_types.add(typeof(bool));
            store_cells.add(null);

            // get the actual columns from configuration.
            foreach (var col in m_app.ui_manager.panel_columns) {
                var tvcol = new TreeViewColumn();
                tvcol.title = col.title;
                foreach (var cell in col.cells) {
                    store_cells.add (cell);
                    store_types.add (cell.column_type);
                    m_file_attributes.add_all(cell.file_attributes);
                    cell.add_to_column (tvcol,
                                        idx,  // data
                                        COL_FG_COLOR, COL_FG_SET,
                                        COL_BG_COLOR, COL_BG_SET,
                                        COL_WEIGHT, COL_WEIGHT_SET,
                                        COL_STYLE, COL_STYLE_SET);
                    if (cell == col.sort_column) {
                        tvcol.set_sort_column_id(idx);
                        m_cmp_funcs[idx] = new TreeIterCompareFuncWrapper(idx, col.cmp_function);
                    }
                    idx++;
                }
                m_list.append_column(tvcol);
            }

            // finish.
            m_store_cells = store_cells.to_array();
            m_store_types = store_types.to_array();
            var sb = new StringBuilder();
            bool first = true;
            foreach (string attr in m_file_attributes) {
                if (!first) sb.append_c(',');
                else first = false;

                sb.append(attr);
            }
            m_file_attributes_str = sb.str;

            var scrwnd = new ScrolledWindow (null, null);
            scrwnd.add(m_list);
            pack_start (scrwnd, true, true);

            m_error_message = new Label ("");
            m_error_message_bg = new EventBox ();
            m_error_message.margin = 10;
            var black = RGBA();
            black.parse("#000000");
            m_error_message.override_color (0, black);
            var red = RGBA();
            red.parse("#ff8888");
            m_error_message_bg.override_background_color (0, red);
            m_error_message_bg.add(m_error_message);
            pack_start (m_error_message_bg, false, false);
        }

        public void display_error (string message)
        {
            m_error_message.set_text(message);
            m_error_message_bg.visible = true;
        }

        public void hide_error ()
        {
            m_error_message_bg.visible = false;
        }

        File m_pwd;

        /**
         * The directory currently being listed. Setting the property changes
         * directory asynchronously
         */
        public File pwd {
            get { return m_pwd; }
            set {
                chdir.begin(value, null);
            }
        }

        private async void chdir (File pwd, string? prev_name)
        {
            int idx;
            Value file_value;

            int sort_column = -1;
            SortType sort_type = 0;
            bool is_sorted = (m_liststore != null
                             && m_liststore.get_sort_column_id (out sort_column, out sort_type));

            var store = new ListStore.newv(m_store_types);
            foreach (var e in m_cmp_funcs.entries) {
                store.set_sort_func(e.key, e.value.compare_treeiter);
            }

            FileEnumerator enumerator;
            try {
                enumerator = yield pwd.enumerate_children_async (
                                            m_file_attributes_str,
                                            FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
            } catch {
                display_error ("Error reading directory: %s".printf(pwd.get_parse_name()));
                return;
            }

            TreeIter iter;
            TreeIter? prev_iter = null;

            // Add [..]
            var parent = pwd.get_parent();
            FileInfo parent_info = null;
            if (parent != null) {
                try {
                    parent_info = yield parent.query_info_async(m_file_attributes_str,
                                                FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                } catch {
                    display_error ("Error querying parent directory: %s".printf(
                                        parent.get_parse_name()));
                }
            }
            if (parent_info != null) {
                parent_info.set_display_name("..");
                parent_info.set_name("..");

                store.append(out iter);
                idx = 0;

                file_value = Value(typeof(FileInfo));
                file_value.set_object(parent_info);
                store.set_value(iter, COL_FILEINFO, file_value); 

                foreach (var col_ in m_store_cells) {
                    if (col_ != null) {
                        store.set_value(iter, idx, col_.get_value(parent_info));
                    }
                    idx++;
                }

                if (prev_name == "..") {
                    prev_iter = iter;
                }
            }

            // Add the rest.
            while (true) {
                GLib.List<FileInfo> fileinfos;
                try {
                    fileinfos = yield enumerator.next_files_async(20);
                } catch {
                    display_error ("Error querying some files.");
                    continue;
                }
                if (fileinfos == null) break;

                foreach (var file in fileinfos) {
                    store.append(out iter);
                    idx = 0;

                    file_value = Value(typeof(FileInfo));
                    file_value.set_object(file);
                    store.set_value(iter, COL_FILEINFO, file_value); 

                    foreach (var col in m_store_cells) {
                        if (col != null) {
                            store.set_value(iter, idx, col.get_value(file));
                        }
                        idx++;
                    }

                    if (prev_name == file.get_name()) {
                        prev_iter = iter;
                    }
                }
            }

            m_liststore = store;
            m_cursor_path = null;
            m_list.set_model(store);
            m_pwd = pwd;

            if (is_sorted) {
                m_liststore.set_sort_column_id (sort_column, sort_type);
            }
            if (prev_iter != null) {
                var curs = m_liststore.get_path (prev_iter);
                m_list.set_cursor (curs, null, false);
            }

            // set title.
            string title = pwd.get_parse_name ();
            /* TODO: once archive support is implemented, special-case their
             *       URI here and create a nice path/uri without archive://
             */
            m_pane_title.set_markup("<b>%s</b>".printf(title));

        }

        private void cursor_changed ()
        {
            TreePath new_cursor_path = null;

            m_list.get_cursor (out new_cursor_path, null);

            if (m_cursor_path != null) {
                restyle_path(m_cursor_path, false);
            }

            if (new_cursor_path != null) {
                restyle_path (new_cursor_path, true);
            }
            m_cursor_path = new_cursor_path;
        }
    
        private TreePath m_select_cache = null;

        private Ref<bool> _right_button_pressed_marker = null;

        private bool on_mouse_event (EventButton e)
        {
            TreePath path = null;
            if (! m_list.get_path_at_pos((int)e.x, (int)e.y, out path, null, null, null)) {
                path = null;
            }

            if (e.type == EventType.BUTTON_PRESS) {
                hide_error ();
                switch (e.button) {
                case 1:
                    // left-click
                    m_list.set_cursor (path, null, false);
                    m_list.grab_focus ();
                    return true;
                case 3:
                    // right-click
                    if (path != null) {
                        toggle_selected (path);
                        m_select_cache = path;

                        var press_marker = new Ref<bool>(true);
                        _right_button_pressed_marker = press_marker;
                        Timeout.add(1000, () => {
                                if (press_marker.val) {
                                    // right mouse button was pressed for one second.
                                    popup_menu_for (path);
                                }
                                if (_right_button_pressed_marker == press_marker) {
                                    _right_button_pressed_marker = null;
                                }
                                return false;
                            });
                    }
                    return true;
                }
            } else if (e.type == EventType.2BUTTON_PRESS) {
                activate_row(path);
                return true;
            } else if (e.type == EventType.BUTTON_RELEASE) {
                switch (e.button) {
                case 3:
                    // right-click released
                    if (_right_button_pressed_marker != null) {
                        _right_button_pressed_marker.val = false;
                        _right_button_pressed_marker = null;
                    }
                    break;
                }
            }

            return false;
        }

        /**
         * Attempt to grab focus.
         */
        public void activate_pane ()
        {
            hide_error ();
            m_list.grab_focus ();
        }

        private bool on_motion_notify (EventMotion e)
        {
            if ((e.state & ModifierType.BUTTON3_MASK) != 0) {
                // right-click drag. (de)select.
                TreePath path;
                if (m_list.get_path_at_pos((int)e.x, (int)e.y, out path, null, null, null)) {
                    if (m_select_cache == null || path.compare(m_select_cache) != 0) {
                        toggle_selected (path);
                        m_select_cache = path;
                    }
                }
            }
            return false;
        }

        private bool on_key_event (EventKey e)
        {
            if (e.type == EventType.KEY_PRESS) {
                hide_error ();
                switch (e.keyval) {
                case 0x0020: // GDK_KEY_space
                    if (m_cursor_path != null) {
                        toggle_selected (m_cursor_path);
                    }
                    return true;
                case 0xff0d: // GDK_KEY_Return
                    if (m_cursor_path != null) {
                        activate_row (m_cursor_path);
                    }
                    return true;
                case 0xff67: // GDK_KEY_Menu
                    if (m_cursor_path != null) {
                        popup_menu_for (m_cursor_path);
                    }
                    return true;
                }
            }
            return false;
        }

        private void popup_menu_for (TreePath path)
        {
            stdout.printf("popup!\n");
        }

        private void activate_row (TreePath path)
        {
            // get the FileInfo:
            TreeIter? iter = null;
            m_liststore.get_iter (out iter, path);
            if (iter != null) {
                Value file_info_val;
                m_liststore.get_value (iter, COL_FILEINFO, out file_info_val);
                FileInfo file_info = (FileInfo) file_info_val.get_object ();

                activate_file.begin (file_info, null);
            }
        }

        private async void activate_file (FileInfo file_info, File? file)
        {
            switch (file_info.get_file_type()) {
            case FileType.DIRECTORY:
                File dir;
                if (file == null) {
                    dir = m_pwd.resolve_relative_path (file_info.get_name());
                } else {
                    dir = file;
                }
                var old_name = file_info.get_name() == ".." 
                                    ? m_pwd.get_basename ()
                                    : "..";
                yield chdir(dir, old_name);

                break;
            case FileType.SYMBOLIC_LINK:
                var target_s = file_info.get_symlink_target ();
                var target = m_pwd.resolve_relative_path(target_s);
                FileInfo info;
                try {
                    info = yield target.query_info_async (m_file_attributes_str, 0);
                } catch {
                    display_error ("Could not resolve symbolic link: %s"
                                    .printf(target_s));
                    return;
                }
                yield activate_file (info, target);
                break;
            }
        }

        private void toggle_selected (TreePath path)
        {
            TreeIter? iter;
            m_liststore.get_iter (out iter, path);
            if (iter != null) {
                Value selected;
                m_liststore.get_value (iter, COL_SELECTED, out selected);
                selected.set_boolean (!selected.get_boolean());
                m_liststore.set_value (iter, COL_SELECTED, selected);
                restyle (iter, m_cursor_path != null && m_cursor_path.compare(path) == 0);
            }
        }

        private bool on_focus_event (EventFocus e)
        {
            // focus has changed. Restyle every line.
            restyle_complete_list ();
            return false;
        }

        private void restyle_complete_list ()
        {

            bool active = m_list.has_focus;

            TreeIter iter = TreeIter();
            if (m_liststore == null || !m_liststore.get_iter_first(out iter)) {
                return;
            }

            do {
                restyle (iter, false, active);
            } while (m_liststore.iter_next(ref iter));

            if (m_cursor_path != null) {
                restyle_path (m_cursor_path, true, active);
            }

            // restyle the header
            if (active) {
                m_pane_title.override_color(StateFlags.NORMAL,
                            m_app.ui_manager.selected_foreground);
                m_pane_title_bg.override_background_color(StateFlags.NORMAL,
                            m_app.ui_manager.selected_background);
            } else {
                m_pane_title.override_color(StateFlags.NORMAL,
                            m_app.ui_manager.label_foreground);
                m_pane_title_bg.override_background_color(StateFlags.NORMAL,
                            m_app.ui_manager.label_background);
            }
        }

        private void restyle_path (TreePath path, bool cursor=false, bool? focus=null)
        {
            if (path != null) {
                TreeIter? iter;
                m_liststore.get_iter (out iter, path);
                if (iter != null) {
                    restyle (iter, cursor, focus);
                }
            }
        }

        private void restyle (TreeIter iter, bool cursor=false, bool? focus=null)
        {
            bool active;
            if (focus == null) {
                active = m_list.has_focus;
            } else {
                active = focus;
            }
            var falsevalue = Value(typeof(bool));
            falsevalue.set_boolean(false);
            var truevalue = Value(typeof(bool));
            truevalue.set_boolean(true);
            var nullcolor = Value(typeof(RGBA));
            nullcolor.set_boxed(null);

            m_liststore.set_value (iter, COL_FG_COLOR, nullcolor);
            m_liststore.set_value (iter, COL_FG_SET, falsevalue);

            m_liststore.set_value (iter, COL_BG_COLOR, nullcolor);
            m_liststore.set_value (iter, COL_BG_SET, falsevalue);

            //m_liststore.set_value(iter, COL_WEIGHT_SET, falsevalue);
            //m_liststore.set_value(iter, COL_STYLE_SET, falsevalue);

            foreach (var style in m_app.ui_manager.style_directives) {
                if (style.pane == FilePaneState.ACTIVE && !active) {
                    continue;
                } else if (style.pane == FilePaneState.PASSIVE && active) {
                    continue;
                }

                if (style.target == UserInterfaceManager.StyleDirective.Target.CURSOR &&
                    !cursor) {
                    continue;
                } else if (style.target == UserInterfaceManager.StyleDirective.Target.SELECTED) {
                    Value selected;
                    m_liststore.get_value(iter, COL_SELECTED, out selected);
                    if (!selected.get_boolean()) {
                        continue;
                    }
                }

                // If this point is reached, the style directive applies.

                if (style.fg != null) {
                    var fgcolor = Value(typeof(RGBA));
                    fgcolor.set_boxed((void*)style.fg);
                    m_liststore.set_value(iter, COL_FG_COLOR, fgcolor);
                    m_liststore.set_value(iter, COL_FG_SET, truevalue);
                }
                if (style.bg != null) {
                    var bgcolor = Value(typeof(RGBA));
                    bgcolor.set_boxed((void*)style.bg);
                    m_liststore.set_value(iter, COL_BG_COLOR, bgcolor);
                    m_liststore.set_value(iter, COL_BG_SET, falsevalue);
                    m_liststore.set_value(iter, COL_BG_SET, truevalue);
                }
            }
        }


        private class TreeIterCompareFuncWrapper : Object
        {
            int m_col;
            CompareFunc m_cmp;

            public TreeIterCompareFuncWrapper (int column, CompareFunc cmp)
            {
                m_col = column;
                m_cmp = cmp;
            }

            public int compare_treeiter (TreeModel model, TreeIter it_a, TreeIter it_b)
            {
                Value a, b;
                model.get_value(it_a, m_col, out a);
                model.get_value(it_b, m_col, out b);
                return m_cmp(a, b);
            }
        }

        private class Ref<T>
        {
            public Ref (T initial_value) { val = initial_value; }
            public T val { get; set; }
        }

    }

}


