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
        public delegate bool FileFilterFunc (File f, FileInfo fi, bool currently_visible);

        EmperorCore m_app;
        TreeView m_list;
        Label m_pane_title;
        EventBox m_pane_title_bg;
        Label m_error_message;
        EventBox m_error_message_bg;
        ListStore m_data_store = null;
        TreeModelSort m_sorted_list = null;
        TreeModelFilter m_list_filter = null;
        TreePath m_cursor_path;
        FileInfoColumn[] m_store_cells;
        Type[] m_store_types;
        Map<int,TreeIterCompareFuncWrapper> m_cmp_funcs;
        Set<string> m_file_attributes;
        string m_file_attributes_str;
        Map<string,FileFilterFuncWrapper> m_filters;

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
            m_filters = new HashMap<string,FileFilterFuncWrapper> ();

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
            m_pane_title_bg.add (m_pane_title);
            m_pane_title_bg.button_press_event.connect (on_title_click);
            pack_start(m_pane_title_bg, false, false);

            /*
             * Create and add the TreeView
             */
            m_list = new TreeView();
            var selector = m_list.get_selection();
            selector.set_mode(SelectionMode.NONE);

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
                        m_cmp_funcs[idx] = new TreeIterCompareFuncWrapper(idx,
                                                    col.cmp_function);
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
            m_error_message.wrap = true;
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

        public void add_filter (string id, FileFilterFunc filter)
        {
            m_filters[id] = new FileFilterFuncWrapper (filter);
            if (m_list_filter != null) {
                m_list_filter.refilter ();
            }
        }

        public bool remove_filter (string id)
        {
            bool removed = m_filters.remove (id);
            if (removed && m_list_filter != null) {
                m_list_filter.refilter ();
            }
            return removed;
        }

        public bool using_filter (string id)
        {
            return m_filters.has_key (id);
        }

        private bool filter_list_row (TreeModel model, TreeIter iter)
        {
            bool visible = true;

            Value finfo_val;
            model.get_value (iter, COL_FILEINFO, out finfo_val);
            var finfo = finfo_val.get_object () as FileInfo;

            if (finfo == null || m_pwd == null) {
                return true;
            }

            var file = m_pwd.resolve_relative_path (finfo.get_name ());

            foreach (var wrapper in m_filters.values) {
                visible = wrapper.func (file, finfo, visible);
            }
            
            return visible;
        }

        File m_pwd = null;

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

        public async void chdir (File pwd, string? prev_name=null)
        {
            TreeIter? prev_iter = null;

            int sort_column = -1;
            SortType sort_type = 0;
            bool is_sorted = (m_sorted_list != null
                             && m_sorted_list.get_sort_column_id (out sort_column, out sort_type));

            if (other_pane.pwd != null && pwd.equal(other_pane.pwd)) {
                // re-use other pane's list store.
                m_data_store = other_pane.m_data_store;
                m_cursor_path = other_pane.m_cursor_path;

            } else {
                // chdir-proper.
                var store = new ListStore.newv(m_store_types);

                FileEnumerator enumerator;
                try {
                    enumerator = yield pwd.enumerate_children_async (
                                                m_file_attributes_str,
                                                FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                } catch (Error err1) {
                    display_error (_("Error reading directory: %s (%s)")
                                   .printf(pwd.get_parse_name(),
                                           err1.message));
                    return;
                }

                TreeIter iter;

                // Add [..]
                var parent = pwd.get_parent();
                FileInfo parent_info = null;
                if (parent != null) {
                    try {
                        parent_info = yield parent.query_info_async(m_file_attributes_str,
                                                    FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                    } catch (Error err2) {
                        display_error (_("Error querying parent directory: %s (%s)")
                                        .printf(parent.get_parse_name(),
                                                err2.message));
                    }
                }
                if (parent_info != null) {
                    parent_info.set_display_name("..");
                    parent_info.set_name("..");

                    store.append (out iter);

                    update_row (iter, parent_info, store, pwd);

                    if (prev_name == "..") {
                        prev_iter = iter;
                    }
                }

                // Add the rest.
                while (true) {
                    GLib.List<FileInfo> fileinfos;
                    try {
                        fileinfos = yield enumerator.next_files_async(20);
                    } catch (Error err3) {
                        display_error (_("Error querying some files. (%s)")
                                        .printf(err3.message));
                        continue;
                    }
                    if (fileinfos == null) break;

                    foreach (var file in fileinfos) {
                        store.append (out iter);

                        update_row (iter, file, store, pwd);

                        if (prev_name == file.get_name()) {
                            prev_iter = iter;
                        }
                    }
                }

                m_data_store = store;
                m_cursor_path = null;

            }
            m_pwd = pwd;
            m_list_filter = new TreeModelFilter (m_data_store, null);
            m_list_filter.set_visible_func (this.filter_list_row);
            m_sorted_list = new TreeModelSort.with_model (m_list_filter);

            m_list.set_model(m_sorted_list);

            foreach (var e in m_cmp_funcs.entries) {
                m_sorted_list.set_sort_func(e.key, e.value.compare_treeiter);
            }
            if (is_sorted) {
                m_sorted_list.set_sort_column_id (sort_column, sort_type);
            }
            if (prev_iter != null) {
                TreeIter sort_prev_iter;
                TreeIter filter_prev_iter;
                m_list_filter.convert_child_iter_to_iter (out filter_prev_iter, prev_iter);
                m_sorted_list.convert_child_iter_to_iter (out sort_prev_iter, filter_prev_iter);
                var curs = m_sorted_list.get_path (sort_prev_iter);
                m_list.set_cursor (curs, null, false);
            }

            // set title.
            string title = pwd.get_parse_name ();
            /* TODO: once archive support is implemented, special-case their
             *       URI here and create a nice path/uri without archive://
             */
            m_pane_title.set_markup("<b>%s</b>".printf(title));

            restyle_complete_list ();
        }

        private void update_row (TreeIter iter, FileInfo file,
                                 ListStore store, File? pwd=null)
        {
            if (pwd == null) {
                pwd = m_pwd;
            }

            var idx = 0;

            var file_value = Value(typeof(FileInfo));
            file_value.set_object(file);
            store.set_value(iter, COL_FILEINFO, file_value); 

            foreach (var col in m_store_cells) {
                if (col != null) {
                    store.set_value(iter, idx, col.get_value(pwd, file));
                }
                idx++;
            }
        }

        private async void query_and_update (TreeIter unsorted_iter, File file)
        {
            try {
                var fileinfo = yield file.query_info_async (
                        m_file_attributes_str,
                        FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                update_row (unsorted_iter, fileinfo, m_data_store);
            } catch (Error e) {
                display_error (_("Error fetching file information. (%s)").printf(e.message));
            }
        }

        public TreePath cursor_path {
            get {
                return m_cursor_path;
            }
        }

        public FileInfo get_fileinfo (TreePath path)
        {
            Value finfo_val;
            TreeIter iter;
            m_sorted_list.get_iter (out iter, path);
            m_sorted_list.get_value (iter, COL_FILEINFO, out finfo_val);
            return (FileInfo) finfo_val.get_object ();
        }

        public void update_line (TreePath path, File file)
        {
            TreeIter iter;
            TreeIter data_iter;
            m_sorted_list.get_iter (out iter, path);
            toplevel_iter_to_data_iter (out data_iter, iter);
            query_and_update.begin (data_iter, file);
        }

        private void toplevel_iter_to_data_iter (out TreeIter data_iter,
                                                 TreeIter toplevel_iter)
        {
            TreeIter filter_iter;
            m_sorted_list.convert_iter_to_child_iter (out filter_iter, toplevel_iter);
            m_list_filter.convert_iter_to_child_iter (out data_iter, filter_iter);
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
                    if (path != null) {
                        m_list.set_cursor (path, null, false);
                    }
                    this.active = true;
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
        
        private bool m_editing_title = false;
        private bool on_title_click (EventButton e)
        {
            if (e.type == EventType.BUTTON_PRESS) {
                switch (e.button) {
                case 1:
                    // left-click!
                    edit_title ();
                    break;
                }
            }
            
            return false;
        }

        private void edit_title ()
        {
            if (m_editing_title) return;
                    
            m_editing_title = true;
            
            var dir_text = new Entry();
            dir_text.text = m_pane_title.get_text ();
            
            dir_text.focus_out_event.connect ((e) => {
                    // Remove the Entry, switch back to plain title.
                    if (m_editing_title) {
                        m_pane_title_bg.remove (dir_text);
                        m_pane_title_bg.add (m_pane_title);
                        m_pane_title_bg.show_all ();
                        m_editing_title = false;
                    }
                    return true;
                });
                
            dir_text.key_press_event.connect ((e) => {
                    if (e.keyval == 0xff1b) { // Escape
                        //end_edit ();
                        this.active = true;
                        return true;
                    }
                    return false;
                });
                
            dir_text.activate.connect (() => {
                    // Try to chdir to the new location
                    string dirpath = dir_text.text;
                    var f = File.parse_name (dirpath);
                    chdir.begin (f, null);
                    this.active = true;
                });
            
            m_pane_title_bg.remove (m_pane_title);
            m_pane_title_bg.add (dir_text);
            dir_text.show ();
            dir_text.grab_focus ();
        }


        private bool m_active = false;
        /**
         * Whether or not this pane is active. Setting this property
         * will change the other pane's state accordingly.
         */
        public bool active {
            get { return m_active; }
            set {
                if (m_active != value) {
                    m_active = value;
                    //hide_error ();
                    restyle_complete_list ();
                    other_pane.active = !m_active;
                }
                if (m_active && !m_list.has_focus) {
                    m_list.grab_focus ();
                }
            }
        }

        private FilePane m_other_pane = null;
        public FilePane other_pane {
            get {
                if (m_other_pane == null) {
                    if (this == m_app.main_window.left_pane) {
                        m_other_pane = m_app.main_window.right_pane;
                    } else {
                        m_other_pane = m_app.main_window.left_pane;
                    }
                }
                return m_other_pane;
            }
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
                case KeySym.Tab:
                    // activate other panel.
                    active = false;
                    return true;
                case KeySym.space:
                    if (m_cursor_path != null) {
                        toggle_selected (m_cursor_path);
                    }
                    return true;
                case KeySym.Return:
                    if (m_cursor_path != null) {
                        activate_row (m_cursor_path);
                    }
                    return true;
                case KeySym.Menu:
                    if (m_cursor_path != null) {
                        popup_menu_for (m_cursor_path);
                    }
                    return true;
                case KeySym.l:
                case KeySym.L:
                    if ((e.state & ModifierType.CONTROL_MASK) != 0) {
                        // C-L => edit location.
                        edit_title ();
                    }
                    return true;
                }
            }
            return false;
        }

        private void popup_menu_for (TreePath path)
        {
            // TODO: popup menu!
            stdout.printf("popup!\n");
        }

        public void activate_row (TreePath path)
        {
            // get the FileInfo:
            TreeIter? iter = null;
            m_sorted_list.get_iter (out iter, path);
            if (iter != null) {
                Value file_info_val;
                m_sorted_list.get_value (iter, COL_FILEINFO, out file_info_val);
                FileInfo file_info = (FileInfo) file_info_val.get_object ();

                activate_file.begin (file_info, null);
            }
        }

        private async void activate_file (FileInfo file_info, File? real_file)
        {
            switch (file_info.get_file_type()) {
            case FileType.DIRECTORY:
                File dir;
                if (real_file == null) {
                    dir = m_pwd.resolve_relative_path (file_info.get_name());
                } else {
                    dir = real_file;
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
                    display_error (_("Could not resolve symbolic link: %s")
                                    .printf(target_s));
                    return;
                }
                yield activate_file (info, target);
                break;
            default:
                File file;
                if (real_file == null) {
                    file = m_pwd.get_child (file_info.get_name());
                } else {
                    file = real_file;
                }
                m_app.open_file (file);
                break;
            }
        }

        private void toggle_selected (TreePath path)
        {
            TreeIter? iter;
            m_sorted_list.get_iter (out iter, path);
            if (iter != null) {
                TreeIter data_iter;
                toplevel_iter_to_data_iter (out data_iter, iter);
                Value selected;
                m_data_store.get_value (data_iter, COL_SELECTED, out selected);
                selected.set_boolean (!selected.get_boolean());
                m_data_store.set_value (data_iter, COL_SELECTED, selected);
                restyle (data_iter, m_cursor_path != null && m_cursor_path.compare(path) == 0);
            }
        }

        public GLib.List<File> get_selected_files ()
        {
            var file_list = new GLib.List<File> ();

            m_sorted_list.@foreach ((model, path, iter) => {
                    Value selected;
                    model.get_value (iter, COL_SELECTED, out selected);
                    if (selected.get_boolean()) {
                        Value finfo_val;
                        model.get_value (iter, COL_FILEINFO, out finfo_val);
                        assert ( finfo_val.holds (typeof(FileInfo)) );
                        var finfo = finfo_val.get_object () as FileInfo;
                        var file = m_pwd.resolve_relative_path (finfo.get_name());
                        file_list.prepend (file);
                    }
                    return false;
                });

            if (file_list.length() == 0 && m_cursor_path != null) {
                // if no files are selected, use the cursor in stead.
                var cursor_finfo = get_fileinfo (m_cursor_path);
                var cursor_file = m_pwd.resolve_relative_path (cursor_finfo.get_name());
                file_list.prepend (cursor_file);
            } else {
                file_list.reverse ();
            }
            /* The (owned) cast is necessary to tell Vala not to unref the list
             * or its contents. GLib.List is a lightweight class - it is not
             * reference counted. Ownership must be explicitly transferred. */
            return (owned) file_list;
        }

        private void restyle_complete_list ()
        {

            TreeIter iter = TreeIter();
            if (m_data_store == null || !m_data_store.get_iter_first(out iter)) {
                return;
            }

            do {
                restyle (iter, false);
            } while (m_data_store.iter_next(ref iter));

            if (m_cursor_path != null) {
                restyle_path (m_cursor_path, true);
            }

            // restyle the header
            if (m_active) {
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

        private void restyle_path (TreePath path, bool cursor=false)
        {
            if (path != null) {
                TreeIter? iter;
                m_sorted_list.get_iter (out iter, path);
                if (iter != null) {
                    TreeIter data_iter;
                    toplevel_iter_to_data_iter (out data_iter, iter);
                    restyle (data_iter, cursor);
                }
            }
        }

        private void restyle (TreeIter unsorted_iter, bool cursor=false)
        {
            var falsevalue = Value(typeof(bool));
            falsevalue.set_boolean(false);
            var truevalue = Value(typeof(bool));
            truevalue.set_boolean(true);
            var nullcolor = Value(typeof(RGBA));
            nullcolor.set_boxed(null);

            m_data_store.set_value (unsorted_iter, COL_FG_COLOR, nullcolor);
            m_data_store.set_value (unsorted_iter, COL_FG_SET, falsevalue);

            m_data_store.set_value (unsorted_iter, COL_BG_COLOR, nullcolor);
            m_data_store.set_value (unsorted_iter, COL_BG_SET, falsevalue);

            //m_data_store.set_value(unsorted_iter, COL_WEIGHT_SET, falsevalue);
            //m_data_store.set_value(unsorted_iter, COL_STYLE_SET, falsevalue);

            foreach (var style in m_app.ui_manager.style_directives) {
                if (style.pane == FilePaneState.ACTIVE && !m_active) {
                    continue;
                } else if (style.pane == FilePaneState.PASSIVE && m_active) {
                    continue;
                }

                if (style.target == UserInterfaceManager.StyleDirective.Target.CURSOR &&
                    !cursor) {
                    continue;
                } else if (style.target == UserInterfaceManager.StyleDirective.Target.SELECTED) {
                    Value selected;
                    m_data_store.get_value(unsorted_iter, COL_SELECTED, out selected);
                    if (!selected.get_boolean()) {
                        continue;
                    }
                }

                // If this point is reached, the style directive applies.

                if (style.fg != null) {
                    var fgcolor = Value(typeof(RGBA));
                    fgcolor.set_boxed((void*)style.fg);
                    m_data_store.set_value(unsorted_iter, COL_FG_COLOR, fgcolor);
                    m_data_store.set_value(unsorted_iter, COL_FG_SET, truevalue);
                }
                if (style.bg != null) {
                    var bgcolor = Value(typeof(RGBA));
                    bgcolor.set_boxed((void*)style.bg);
                    m_data_store.set_value(unsorted_iter, COL_BG_COLOR, bgcolor);
                    m_data_store.set_value(unsorted_iter, COL_BG_SET, falsevalue);
                    m_data_store.set_value(unsorted_iter, COL_BG_SET, truevalue);
                }
            }
        }

        public override void show_all ()
        {
            base.show_all ();
            hide_error ();
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

        private class FileFilterFuncWrapper : Object
        {
            public FileFilterFuncWrapper (FileFilterFunc f) {
                this.func = f;
            }
            public FileFilterFunc func { get; private set; }
        }

    }

}


