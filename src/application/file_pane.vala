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
        string m_designation;
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
        Map<string,FileInfoCompareFuncWrapper> m_permanent_sort;

        internal static HashMap<string,int> archive_ref_counts = null;

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

        public FilePane (EmperorCore app, string pane_designation)
        {
            if (archive_ref_counts == null) {
                archive_ref_counts = new HashMap<string,int> ();
            }

            m_app = app;
            m_designation = pane_designation;
            m_filters = new HashMap<string,FileFilterFuncWrapper> ();
            m_permanent_sort = new HashMap<string,FileInfoCompareFuncWrapper> ();

            this.destroy.connect (on_destroy);

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
            var attr_list = new Pango.AttrList ();
            attr_list.insert (Pango.attr_weight_new (Pango.Weight.BOLD));
            m_pane_title.set_attributes (attr_list);
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
            m_file_attributes.add(FileAttribute.STANDARD_NAME);
            m_file_attributes.add(FileAttribute.STANDARD_TYPE);
            m_file_attributes.add(FileAttribute.STANDARD_CONTENT_TYPE);
            m_file_attributes.add(FileAttribute.STANDARD_SYMLINK_TARGET);
            m_file_attributes.add(FileAttribute.STANDARD_TARGET_URI);

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

            int colidx = 0;
            TreeViewColumn last_col = null;
            // get the actual columns from configuration.
            foreach (var col in m_app.ui_manager.panel_columns) {
                var tvcol = new TreeViewColumn();
                tvcol.title = col.title;
                tvcol.resizable = true;
                var pref_w_name = "%s-col-width-%d".printf(m_designation,colidx);
                var pref_w = m_app.prefs.get_int32 (pref_w_name, -1);
                if (pref_w > 0) {
                    tvcol.sizing = TreeViewColumnSizing.FIXED;
                    tvcol.fixed_width = pref_w;
                } else if (col.default_width > 0) {
                    tvcol.sizing = TreeViewColumnSizing.FIXED;
                    tvcol.fixed_width = col.default_width;
                }
                
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
                                                    col.cmp_function,
                                                    this.compare_using_global_sort);
                    }
                    idx++;
                }
                m_list.append_column(tvcol);
                last_col = tvcol;
                colidx ++;
            }
            
            if (last_col != null) {
                last_col.sizing = TreeViewColumnSizing.GROW_ONLY;
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
            if (m_designation.has_prefix ("left")) {
                scrwnd.set_placement (CornerType.TOP_RIGHT);
            }
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

        private void on_destroy ()
        {
            // unmount archives. Perhaps other things in modules.
            m_mnt = null;
            notify_property ("mnt");

            // Doing the same thing for pwd and parent_dir might not be safe:
            // they're usually never null.
        }


        private void check_column_sizes ()
        {
            int colidx = 0;
            TreeViewColumn last_col = null;
            foreach (var tvcol in m_list.get_columns()) {
                var pref_w_name = "%s-col-width-%d".printf(m_designation, colidx);
                m_app.prefs.set_int32 (pref_w_name, tvcol.width);
                last_col = tvcol;
                colidx ++;
            }
            last_col.sizing = TreeViewColumnSizing.GROW_ONLY;
        }

        private void fix_column_sizes ()
        {
            TreeViewColumn last_col = null;
            foreach (var tvcol in m_list.get_columns()) {
                tvcol.fixed_width = tvcol.width;
                tvcol.sizing = TreeViewColumnSizing.FIXED;
                last_col = tvcol;
            }
            last_col.sizing = TreeViewColumnSizing.GROW_ONLY;
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
            bool removed = m_filters.unset (id);
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
                // no file info => no displaying.
                return false;
            }

            var file = get_child_by_name (finfo.get_name ());

            /*
            // standard behaviour: do not display non-existant files.
            if (!file.query_exists ()) {
                return false;
            }
            */

            foreach (var wrapper in m_filters.values) {
                visible = wrapper.func (file, finfo, visible);
            }
            
            return visible;
        }

        public void add_query_attribute (string att)
        {
            m_file_attributes.add (att);

            var sb = new StringBuilder();
            bool first = true;
            foreach (string attr in m_file_attributes) {
                if (!first) sb.append_c(',');
                else first = false;

                sb.append(attr);
            }
            m_file_attributes_str = sb.str;
        }

        public void add_sort (string id, FileInfoCompareFunc cmp)
        {
            m_permanent_sort[id] = new FileInfoCompareFuncWrapper (cmp);
            if (m_sorted_list != null) {
                // refresh.
                int col;
                SortType st;
                m_sorted_list.get_sort_column_id (out col, out st);
                m_sorted_list.set_sort_column_id (col, st);
            }
        }

        public bool remove_sort (string id)
        {
            bool removed = m_permanent_sort.unset (id);
            if (removed && m_sorted_list != null) {
                // refresh.
                int col;
                SortType st;
                m_sorted_list.get_sort_column_id (out col, out st);
                m_sorted_list.set_sort_column_id (col, st);
            }
            return removed;
        }

        public bool using_sort (string id)
        {
            return m_permanent_sort.has_key (id);
        }

        private int compare_using_global_sort (TreeModel model, TreeIter it1, TreeIter it2)
        {
            Value finfo1_val, finfo2_val;
            model.get_value (it1, COL_FILEINFO, out finfo1_val);
            model.get_value (it2, COL_FILEINFO, out finfo2_val);
            var finfo1 = (FileInfo) finfo1_val.get_object ();
            var finfo2 = (FileInfo) finfo2_val.get_object ();

            int d = 0;

            foreach (var fw in m_permanent_sort.values) {
                int this_d = fw.func (finfo1, finfo2);
                if (this_d != 0) {
                    d = this_d;
                }
            }
            
            return d;
        }


        File m_pwd = null;
        File m_parent = null;
        Mount m_mnt = null;

        /**
         * The directory currently being listed. Setting the property changes
         * directory asynchronously
         */
        [CCode(notify = false)]
        public File pwd {
            get { return m_pwd; }
            set {
                chdir.begin(value, null);
            }
        }

        public async bool chdir_then_focus (File pwd, string? prev_name=null, GLib.MountOperation? mnt_op=null)
        {
            var prev_name_ = prev_name;
            if (prev_name_ == null) {
                // we care about correct focus here. Check if we're going to the parent, perchance.
                if (m_pwd.has_parent(pwd)) {
                    prev_name_ = m_pwd.get_basename ();
                }
            }

            bool success =  yield chdir (pwd, prev_name_, mnt_op);
            if (success) {
                this.active = true;
                m_list.grab_focus();
            }
            return success;
        }

        public Mount mnt {
            get { return m_mnt; }
        }

        public File parent_dir {
            get { return m_parent; }
        }

        private Cancellable m_chdir_cancellable = null;

        public async bool chdir (File pwd, string? prev_name=null, GLib.MountOperation? mnt_op=null)
        {
            var cancellable = new Cancellable ();
            if (m_chdir_cancellable != null) {
                m_chdir_cancellable.cancel ();
            }
            m_chdir_cancellable = cancellable;

            TreeIter? prev_iter = null;

            int sort_column = -1;
            SortType sort_type = 0;
            bool is_sorted = (m_sorted_list != null
                             && m_sorted_list.get_sort_column_id (out sort_column, out sort_type));

            File parent = null;
            File archive_file = null;
            Mount mnt = null;

            if (m_mnt != null) {
                m_mnt.unmounted.disconnect (on_unmounted);
            }

            if (other_pane.pwd != null && pwd.equal(other_pane.pwd)) {
                // re-use other pane's list store.
                m_data_store = other_pane.m_data_store;
                m_cursor_path = other_pane.m_cursor_path;
                mnt = other_pane.mnt;
                parent = other_pane.parent_dir;

            } else {
                if (! yield procure_mount (pwd, out mnt, mnt_op, cancellable)) {
                    if (cancellable.is_cancelled()) {
                        return true;
                    } else {
                        return false;
                    }
                }

                set_cursor_busy (true);

                // chdir-proper.
                var store = new ListStore.newv(m_store_types);

                FileEnumerator enumerator;
                try {
                    enumerator = yield pwd.enumerate_children_async (
                                                m_file_attributes_str,
                                                FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                                                Priority.DEFAULT, cancellable);
                } catch (Error err1) {
                    if (cancellable.is_cancelled()) return true;

                    display_error (_("Error reading directory: %s (%s)")
                                   .printf(pwd.get_parse_name(),
                                           err1.message));
                    return false;
                }

                TreeIter iter;

                // Add [..]
                parent = pwd.get_parent();

                if (pwd.get_uri_scheme() == "archive") {
                    var archive_uri = pwd.get_uri();
                    var spl1 = archive_uri.split ("://", 2);
                    if (spl1.length >= 2) {
                        var spl2 = spl1[1].split ("/", 2);
                        var archive_host = spl2[0];
                        var archive_file_uri_esc1 = Uri.unescape_string (archive_host, null);
                        var archive_file_uri = Uri.unescape_string (archive_file_uri_esc1, null);
                        archive_file = File.new_for_uri (archive_file_uri);
                    }
                }

                if (parent == null && archive_file != null) {
                    // archive root.
                    parent = archive_file.get_parent();
                }

                FileInfo parent_info = null;
                if (parent != null) {
                    try {
                        parent_info = yield parent.query_info_async(m_file_attributes_str,
                                                    FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                                                    Priority.DEFAULT, cancellable);
                    } catch (Error err2) {
                        if (cancellable.is_cancelled()) return true;

                        display_error (_("Error querying parent directory: %s (%s)")
                                        .printf(parent.get_parse_name(),
                                                err2.message));
                    }
                }
                if (parent_info != null) {
                    parent_info.set_display_name("..");
                    parent_info.set_name("..");
                    parent_info.set_is_hidden(false);
                    parent_info.set_attribute_boolean(FileAttribute.STANDARD_IS_BACKUP, false);

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
                        fileinfos = yield enumerator.next_files_async (20, Priority.DEFAULT,
                                                                       cancellable);
                    } catch (Error err3) {
                        if (cancellable.is_cancelled()) return true;

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
            if (cancellable.is_cancelled ()) return true;

            m_pwd = pwd;
            m_mnt = mnt;
            m_parent = parent;
            notify_property ("pwd");
            notify_property ("mnt");
            notify_property ("parent_dir");
            if (m_mnt != null) {
                m_mnt.unmounted.connect (on_unmounted);
            }

            m_list_filter = new TreeModelFilter (m_data_store, null);
            m_list_filter.set_visible_func (this.filter_list_row);
            m_sorted_list = new TreeModelSort.with_model (m_list_filter);
            m_sorted_list.sort_column_changed.connect (sort_column_changed);

            fix_column_sizes ();
            m_list.set_model(m_sorted_list);

            foreach (var e in m_cmp_funcs.entries) {
                m_sorted_list.set_sort_func(e.key, e.value.compare_treeiter);
            }
            if (is_sorted) {
                m_sorted_list.set_sort_column_id (sort_column, sort_type);
            } else {
                get_sort_from_prefs (m_sorted_list);
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
            string title;
            if (archive_file != null) {
                var rel_path = mnt.get_root().get_relative_path (pwd);
                title = "[ %s ] /%s".printf (archive_file.get_basename(), rel_path);
            } else {
                title = pwd.get_parse_name ();
            }
            m_pane_title.set_text (title);

            // save pwd to prefs
            m_app.prefs.set_string (m_designation + "-pwd", m_pwd.get_parse_name());

            restyle_complete_list ();

            set_cursor_busy (false);

            m_chdir_cancellable = null;

            return true;
        }

        public async bool chdir_from_pref ()
        {
            var old_pwd_str = m_app.prefs.get_string (m_designation + "-pwd", null);
            File old_pwd;
            if (old_pwd_str != null) {
                old_pwd = File.parse_name (old_pwd_str);
            } else {
                old_pwd = File.new_for_path (".");
            }
            return yield chdir (old_pwd);
        }

        public async bool procure_mount (File pwd, out Mount mnt,
                                         GLib.MountOperation? mnt_op,
                                         Cancellable? cancellable=null)
        {
            bool mount_error = false;
            try {
                mnt = yield pwd.find_enclosing_mount_async (Priority.DEFAULT, cancellable);
            } catch (Error mnterr1) {
                mount_error = true;
                mnt = null;
            }
            if (mount_error && ! pwd.is_native()) {
                // not mounted. Can I mount this?
                bool mounted = false;

                var waiter = new_waiting_for_mount (m_app.main_window, cancellable);
                set_cursor_busy (true);
                try {
                    waiter.go();

                    GLib.MountOperation real_mnt_op;
                    if (mnt_op == null) {
                        real_mnt_op = new Gtk.MountOperation (m_app.main_window);
                    } else {
                        real_mnt_op = mnt_op;
                    }

                    yield pwd.mount_enclosing_volume (
                            MountMountFlags.NONE, real_mnt_op,
                            cancellable);

                    mounted = true;
                } catch (Error mnterr2) {
                    if (! cancellable.is_cancelled ()) {
                        display_error (_("Error mounting volume. (%s)").printf(mnterr2.message));
                    }
                    mounted = false;
                }
                set_cursor_busy (false);
                waiter.done ();

                if (mounted) {
                    try {
                        mnt = yield pwd.find_enclosing_mount_async ();
                    } catch (Error mnterr3) {
                        if (! cancellable.is_cancelled ()) {
                            display_error (_("Error accessing mount. (%s)").printf(
                                                mnterr3.message));
                        }
                        return false;
                    }
                } else {
                    return false;
                }

                if (pwd.get_uri_scheme() == "archive") {
                    if (cancellable.is_cancelled()) {
                        mnt.unmount_with_operation (MountUnmountFlags.NONE,
                            new Gtk.MountOperation (m_app.main_window));
                        return false;
                    }

                    var archive_mount_root = mnt.get_root ();
                    var archive_ref = archive_mount_root.get_uri();
                    if (archive_ref in archive_ref_counts) {
                        archive_ref_counts[archive_ref] = archive_ref_counts[archive_ref] + 1;
                    } else {
                        archive_ref_counts[archive_ref] = 1;
                    }

                    new ArchiveMountMonitor (this, archive_mount_root,
                                    archive_ref, mnt, m_app.main_window);
                }
            }
            return true;
        }

        private class ArchiveMountMonitor : Object
        {
            string archive_uri;
            File archive_mount_root;
            FilePane pane;
            Mount mnt;
            Gtk.Window main_window;

            internal ArchiveMountMonitor (FilePane pane, File archive_mount_root,
                        string archive_uri, Mount mnt, Gtk.Window main_window)
            {
                this.archive_uri = archive_uri;
                this.archive_mount_root = archive_mount_root;
                this.pane = pane;
                this.mnt = mnt;
                this.main_window = main_window;

                pane.notify["mnt"].connect (this.on_mnt_changed);
                this.@ref();
            }

            internal void on_mnt_changed (ParamSpec p)
            {
                if (pane.mnt == null ||
                    ! pane.mnt.get_root().equal (archive_mount_root)) {

                    var refcnt = archive_ref_counts[archive_uri];
                    refcnt--;
                    archive_ref_counts[archive_uri] = refcnt;
                    if (refcnt == 0) {
                        mnt.unmount_with_operation (MountUnmountFlags.NONE,
                            new Gtk.MountOperation (main_window));
                        pane.notify["mnt"].disconnect (this.on_mnt_changed);
                        this.@unref();
                    }
                }
            }
        }

        private void set_cursor_busy (bool busy)
        {
            var gdk_wnd = get_window ();
            if (gdk_wnd == null) {
                return;
            }

            if (busy) {
                var cursor = new Cursor (CursorType.WATCH);
                gdk_wnd.set_cursor (cursor);
            } else {
                gdk_wnd.set_cursor (null);
            }
        }

        private void on_unmounted ()
        {
            chdir.begin (File.new_for_path (Environment.get_home_dir()), null);
            display_error (_("Location unmounted."));
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

        private HashSet<string> m_uris_being_updated = null;

        private async void query_and_update (TreeIter unsorted_iter, File file)
        {
            if (m_uris_being_updated == null) {
                m_uris_being_updated = new HashSet<string>();
            }
            var uri = file.get_uri();
            if (uri in m_uris_being_updated) {
                return;
            }
            m_uris_being_updated.add (uri);

            try {
                var fileinfo = yield file.query_info_async (
                        m_file_attributes_str,
                        FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                update_row (unsorted_iter, fileinfo, m_data_store);
                restyle (unsorted_iter);
            } catch (Error e) {
                display_error (_("Error fetching file information. (%s)").printf(e.message));
            }

            m_uris_being_updated.remove (uri);
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

        public void update_file (File file)
            requires (m_pwd != null)
        {
            var parent = file.get_parent ();
            if (m_pwd.equal (parent)) {
                // okay, it should be in the list.
                bool exists = file.query_exists ();
                bool file_found = false;

                m_data_store.@foreach ((model, path, iter) => {
                        Value finfo_val;
                        model.get_value (iter, COL_FILEINFO, out finfo_val);
                        var finfo = (FileInfo) finfo_val.get_object ();
                        if (finfo != null) {
                            if (finfo.get_name() == file.get_basename()) {
                                // same file.
                                if (exists) {
                                    file_found = true;
                                    query_and_update.begin (iter, file);
                                } else {
                                    finfo_val.set_object ((Object)null);
                                    ((ListStore)model).set_value (iter, COL_FILEINFO, finfo_val);
                                }
                                // break loop:
                                return true;
                            }
                        }
                        // continue:
                        return false;
                    });

                if (!file_found && exists) {
                    // add file.
                    TreeIter iter;
                    m_data_store.append (out iter);
                    query_and_update.begin (iter, file);
                }
            }
        }

        public async void refresh ()
            requires (m_pwd != null)
        {
            set_cursor_busy (true);
            try {
                var file_infos = new HashMap<string,FileInfo>();
                var pwd = m_pwd;

                // Get list of file names in this directory.
                var enumerator = yield pwd.enumerate_children_async (
                                            m_file_attributes_str,
                                            FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                GLib.List<FileInfo> child_fileinfos;
                while ((child_fileinfos = yield enumerator.next_files_async (20)) != null) {
                    foreach (var finfo in child_fileinfos) {
                        file_infos[finfo.get_name()] = finfo;
                    }
                }

                // Query all file in the list. Remove all others.
                m_data_store.@foreach ((model, path, iter) => {
                    Value finfo_val;
                    model.get_value (iter, COL_FILEINFO, out finfo_val);
                    var finfo = (FileInfo) finfo_val.get_object ();
                    if (finfo != null) {
                        var file_name = finfo.get_name ();
                        if (file_name == "..") {
                            // do not touch the parent reference.
                            return false;
                        }
                        if (!file_infos.has_key(file_name)) {
                            // file does not exist. Get rid.
                            finfo_val.set_object((Object)null);
                            ((ListStore)model).set_value (iter, COL_FILEINFO, finfo_val);
                            return false;
                        }
                        update_row (iter, file_infos[file_name], (ListStore)model);
                        // every file may appear only once.
                        file_infos.unset (file_name);
                    }
                    return false;
                } );

                // Add remaining files.
                foreach (var e in file_infos.entries) {
                    TreeIter iter;
                    m_data_store.append (out iter);
                    update_row (iter, e.@value, m_data_store);
                }

                m_list_filter.refilter ();

            } catch (Error err) {
                display_error (_("Error reading directory. (%s)")
                               .printf(err.message));
            }
            set_cursor_busy (false);

        }

        private void toplevel_iter_to_data_iter (out TreeIter data_iter,
                                                 TreeIter toplevel_iter)
        {
            TreeIter filter_iter;
            m_sorted_list.convert_iter_to_child_iter (out filter_iter, toplevel_iter);
            m_list_filter.convert_iter_to_child_iter (out data_iter, filter_iter);
        }

        private void sort_column_changed ()
        {
            int sort_column;
            SortType sort_type;

            m_sorted_list.get_sort_column_id (out sort_column, out sort_type);

            m_app.prefs.set_int32 (m_designation + "-sort-column", (int32) sort_column);
            m_app.prefs.set_string (m_designation + "-sort-type", 
                                    sort_type == SortType.ASCENDING ? "asc" : "desc");
        }

        private void get_sort_from_prefs (TreeSortable model)
        {
            int sort_column = (int) m_app.prefs.get_int32 (m_designation + "-sort-column", -1);
            string sort_type_str = m_app.prefs.get_string (m_designation + "-sort-type", null);
            if (sort_column == -1 || sort_type_str == null) {
                return;
            }

            model.set_sort_column_id (sort_column, (sort_type_str == "asc") ? SortType.ASCENDING
                                                                            : SortType.DESCENDING);

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
            if (e.window != m_list.get_bin_window()) {
                if (e.type == EventType.BUTTON_RELEASE) {
                    check_column_sizes ();
                }
                return false;
            }

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
                    this.active = true;
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

        public void edit_title ()
        {
            if (m_editing_title) return;
                    
            m_editing_title = true;
            
            var dir_text = new Entry();
            dir_text.text = m_pwd.get_parse_name ();
            
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
                    if (m_app.ui_manager.style_info.other_styles_use_focus) {
                        restyle_complete_list ();
                    } else {
                        if (m_app.ui_manager.style_info.selected_style_uses_focus) {
                            m_data_store.@foreach ((model, path, iter) => {
                                    Value selected;
                                    model.get_value (iter, COL_SELECTED, out selected);
                                    if (selected.get_boolean()) {
                                        restyle (iter, false);
                                    }
                                    return false;
                                });
                        }
                        if (m_app.ui_manager.style_info.cursor_style_uses_focus
                                && m_cursor_path != null) {
                            restyle_path(m_cursor_path, true);
                        }
                        restyle_header ();
                    }
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
            FileInfo info;
            Mount mnt;

            switch (file_info.get_file_type()) {
            case FileType.DIRECTORY:
                File dir;
                if (real_file == null) {
                    dir = get_child_by_name (file_info.get_name());
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
                var target = m_pwd.resolve_relative_path (target_s);
                if (!yield procure_mount (target, out mnt, null)) {
                    return;
                }
                try {
                    info = yield target.query_info_async (m_file_attributes_str, 0);
                } catch (Error sl_err) {
                    display_error (_("Could not resolve symbolic link: %s (%s)")
                                    .printf(target_s, sl_err.message));
                    return;
                }
                yield activate_file (info, target);
                break;
            case FileType.SHORTCUT:
                var sc_target_s = file_info.get_attribute_string (
                                        FileAttribute.STANDARD_TARGET_URI);
                var sc_target = File.new_for_uri (sc_target_s);
                if (!yield procure_mount (sc_target, out mnt, null)) {
                    return;
                }
                try {
                    info = yield sc_target.query_info_async (m_file_attributes_str, 0);
                } catch (Error sc_err) {
                    display_error (_("Error following shortcut: %s (%s)")
                                    .printf(sc_target_s, sc_err.message));
                    return;
                }
                yield activate_file (info, sc_target);
                break;
            default:
                File file;
                if (real_file == null) {
                    file = m_pwd.get_child (file_info.get_name());
                } else {
                    file = real_file;
                }
                if (file_info.get_content_type() in ARCHIVE_TYPES) {
                    // attempt to mount as archive.
                    var archive_host = Uri.escape_string (file.get_uri(), "", false);
                    // escaping percent signs need to be escaped :-/
                    var escaped_host = Uri.escape_string (archive_host, "", false);
                    var archive_file = File.new_for_uri ("archive://" + escaped_host);
                    if (yield chdir (archive_file, null)) {
                        // success!
                        return;
                    } else {
                        hide_error ();
                    }
                }
                m_app.open_file (file);
                break;
            }
        }

        public File get_child_by_name (string name)
        {
            if (name == "..") {
                return m_parent;
            } else {
                return m_pwd.get_child (name);
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
                        var file = get_child_by_name (finfo.get_name());
                        file_list.prepend (file);
                    }
                    return false;
                });

            if (file_list.length() == 0 && m_cursor_path != null) {
                // if no files are selected, use the cursor in stead.
                var cursor_finfo = get_fileinfo (m_cursor_path);
                var cursor_file = get_child_by_name (cursor_finfo.get_name());
                file_list.prepend (cursor_file);
            } else {
                file_list.reverse ();
            }
            /* The (owned) cast is necessary to tell Vala not to unref the list
             * or its contents. GLib.List is a lightweight class - it is not
             * reference counted. Ownership must be explicitly transferred. */
            return (owned) file_list;
        }

        public File? get_file_at_cursor ()
        {
            if (m_cursor_path != null) {
                var finfo = get_fileinfo (m_cursor_path);
                var file = get_child_by_name (finfo.get_name ());
                return file;
            } else {
                return null;
            }
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

            restyle_header ();
        }

        private void restyle_header ()
        {
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
            var normalweight = Value(typeof(int));
            normalweight.set_int(400);
            var normalstyle = Value(typeof(Pango.Style));
            normalstyle.set_enum(Pango.Style.NORMAL);

            Value finfo_val;
            m_data_store.get_value (unsorted_iter, COL_FILEINFO, out finfo_val);
            var finfo = (FileInfo) finfo_val.get_object();
            if (finfo == null) {
                return;
            }

            m_data_store.set_value (unsorted_iter, COL_FG_COLOR, nullcolor);
            m_data_store.set_value (unsorted_iter, COL_FG_SET, falsevalue);

            m_data_store.set_value (unsorted_iter, COL_BG_COLOR, nullcolor);
            m_data_store.set_value (unsorted_iter, COL_BG_SET, falsevalue);

            m_data_store.set_value(unsorted_iter, COL_WEIGHT, normalweight);
            m_data_store.set_value(unsorted_iter, COL_WEIGHT_SET, falsevalue);

            m_data_store.set_value(unsorted_iter, COL_STYLE, normalstyle);
            m_data_store.set_value(unsorted_iter, COL_STYLE_SET, falsevalue);

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

                var ftype = finfo.get_file_type ();
                if (style.file_type != -1 && ftype != style.file_type) {
                    continue;
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
                    m_data_store.set_value(unsorted_iter, COL_BG_SET, truevalue);
                }
                if (style.weight != null) {
                    var wghval = Value(typeof(int));
                    wghval.set_int (style.weight);
                    m_data_store.set_value(unsorted_iter, COL_WEIGHT, wghval);
                    m_data_store.set_value(unsorted_iter, COL_WEIGHT_SET, truevalue);
                }
                if (style.style != null) {
                    var styval = Value(typeof(Pango.Style));
                    styval.set_enum (style.style);
                    m_data_store.set_value(unsorted_iter, COL_STYLE, styval);
                    m_data_store.set_value(unsorted_iter, COL_STYLE_SET, truevalue);
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
            TreeIterCompareFunc m_prio_sort;

            public TreeIterCompareFuncWrapper (int column, CompareFunc cmp,
                                               TreeIterCompareFunc priosort)
            {
                m_col = column;
                m_cmp = cmp;
                m_prio_sort = priosort;
            }

            public int compare_treeiter (TreeModel model, TreeIter it_a, TreeIter it_b)
            {
                int prio_d = m_prio_sort (model, it_a, it_b);
                if (prio_d != 0) {
                    return prio_d;
                }

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

        private class FileInfoCompareFuncWrapper : Object
        {
            public FileInfoCompareFuncWrapper (FileInfoCompareFunc f) {
                this.func = f;
            }
            public FileInfoCompareFunc func { get; private set; }
        }


    }

}


