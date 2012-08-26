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
using Gdk;
using Gee;

namespace Emperor.Application {

    public enum FilePaneState {
        ACTIVE,
        PASSIVE,
        EITHER
    }

    /**
     * The heart of the file manager
     */
    public class FilePane : FilePaneWithToolbars
    {
        
        EmperorCore m_app;
        string m_designation;
        public override EmperorCore application { get { return m_app; } }
        public override string designation { get { return m_designation; } }
        

        TreeView m_list;
        Label m_pane_title;
        EventBox m_pane_title_bg;
        ListStore m_data_store = null;
        TreeModelSort m_sorted_list = null;
        TreeModelFilter m_list_filter = null;
        TreePath m_cursor_path;

        FileInfoColumn[] m_store_cells;
        Type[] m_store_types;
        Map<int,TreeIterCompareFuncWrapper> m_cmp_funcs;
        

        // Indices of well-known data columns in the TreeModel
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
        
        /**
         * Constructor - initialize FilePane
         *
         * @param app   EmperorCore application object.
         * @param pane_designation Either "left" or "right" -- used for preferences
         */
        public FilePane (EmperorCore app, string pane_designation)
        {
            m_app = app;
            m_designation = pane_designation;

            this.destroy.connect (on_destroy);

            init_file_pane_mixin ();

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

            m_list.cursor_changed.connect (handle_cursor_change);

            m_list.button_press_event.connect (on_mouse_event);
            m_list.button_release_event.connect (on_mouse_event);
            m_list.key_press_event.connect (on_key_event);
            m_list.motion_notify_event.connect (on_motion_notify);

            /*
             * Create tree columns based on configuration file.
             */

            var store_cells = new LinkedList<FileInfoColumn?>();
            var store_types = new LinkedList<Type>();
            m_cmp_funcs = new HashMap<int,TreeIterCompareFuncWrapper>();
            

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

            // get the actual, visible columns from configuration.

            foreach (var col in m_app.ui_manager.panel_columns) {
                // get column
                var tvcol = new TreeViewColumn();
                tvcol.title = col.title;
                tvcol.resizable = true;

                // get width from prefs
                var pref_w_name = "%s-col-width-%d".printf(m_designation,colidx);
                var pref_w = m_app.prefs.get_int32 (pref_w_name, -1);
                if (pref_w > 0) {
                    tvcol.sizing = TreeViewColumnSizing.FIXED;
                    tvcol.fixed_width = pref_w;
                } else if (col.default_width > 0) {
                    tvcol.sizing = TreeViewColumnSizing.FIXED;
                    tvcol.fixed_width = col.default_width;
                }
                
                // Add cells within column
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
                    // only one cell per column can be sortable
                    if (cell == col.sort_column) {
                        tvcol.set_sort_column_id(idx);
                        m_cmp_funcs[idx] = new TreeIterCompareFuncWrapper(idx,
                                                    col.cmp_function,
                                                    this.compare_using_global_sort);
                    }
                    // next cell / column of data
                    idx++;
                }

                // done with column.
                m_list.append_column(tvcol);
                last_col = tvcol;
                // next visible column
                colidx ++;
            }
            
            if (last_col != null) {
                last_col.sizing = TreeViewColumnSizing.GROW_ONLY;
            }

            // finalize TreeView configuration.
            // convert lists to arrays.
            m_store_cells = store_cells.to_array();
            m_store_types = store_types.to_array();
            // Attributes: join up string that we can pass to query_info
            recreate_file_attributes_string ();

            // Add TreeView widget, within a ScrolledWindow to make it behave.
            var scrwnd = new ScrolledWindow (null, null);
            if (m_designation.has_prefix ("left")) {
                scrwnd.set_placement (CornerType.TOP_RIGHT);
            }
            scrwnd.add(m_list);
            m_list.set_search_equal_func (search_equal_func);
            m_list.search_column = COL_STYLE_SET + 1;
            m_list.enable_search = true;
            m_list.row_activated.connect ( (path, col) => {
	           activate_row (path); 
            });
            pack_start (scrwnd, true, true);
            
            // Add toolbars
            init_file_pane_toolbar_mixin ();
        }

        private void on_destroy ()
        {
            // Give modules the chance to do some clean-up work and ensure archive
            // mounts are correctly cleaned up.
            m_mnt_ref = null;
            m_mnt = null;
            notify_property ("mnt");

            // Doing the same thing for pwd and parent_dir might not be safe:
            // they're usually never null.
        }


        /**
         * Saves column widths to preferences.
         */
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

        /**
         * Make columns fixed-width so that they aren't resized to fit new content.
         */
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

        /**
         * Reapply list filters
         */
        protected override void
        refilter_list ()
        {
            if (m_list_filter != null) {
                m_list_filter.refilter ();
            }
        }

        /**
         * "TreeModelFilterVisibleFunc" that applies Emperor filters
         */
        private bool filter_list_row (TreeModel model, TreeIter iter)
        {
            bool visible = true;

            // Retrieve FileInfo
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
        
        /**
         * TreeViewSearchEqualFunc for the built-int quick search feature.
         *
         * This ignores the column number, and simply checks if the file name starts
         * with the query string
         */
        private bool search_equal_func (TreeModel model, int column, string query, TreeIter iter)
        {
	        Value finfo_val;
	        
	        model.get_value (iter, COL_FILEINFO, out finfo_val);
	        
	        FileInfo finfo = (FileInfo) finfo_val.get_object ();
	        
	        // Returns FALSE on match, because it's a bit weird like that.
	        return ! (finfo != null
	        		 && finfo.get_display_name ().down ().has_prefix (query.down ()));
        }

        /**
         * Refresh list sorting
         */
        protected override void
        refresh_sorting ()
        {
            if (m_sorted_list != null) {
                // refresh.
                int col;
                SortType st;
                m_sorted_list.get_sort_column_id (out col, out st);

                // reverse sort first.
                m_sorted_list.set_sort_column_id (col, st == SortType.ASCENDING ?
                                                                SortType.DESCENDING
                                                              : SortType.ASCENDING  );
                // now sort correctly again. This is the way to refresh sorting,
                // apparently.
                m_sorted_list.set_sort_column_id (col, st);
            }
        }

        /**
         * Apply permanent sort functions installed with {@link add_sort}
         */
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


        /**
         * Grab focus
         */
        protected override void
        give_focus_to_list ()
        {
            m_list.grab_focus ();
        }

        /**
         * Provide implementation specific parts of the chdir
         * method.
         */
        protected override IDirectoryLoadHelper
        get_directory_load_helper (File dir, string? prev_name)
        {
            return new DirectoryLoadHelper (this, dir, prev_name);
        }


        private class DirectoryLoadHelper : Object,
                                            IDirectoryLoadHelper
        {
            public FilePane fp { get; construct; }
            public File directory { get; construct; }
            public string? prev_name { get; construct; }

            int sort_column = -1;
            SortType sort_type = 0;
            bool is_sorted;

            TreeIter? prev_iter = null;
            ListStore store;

            public DirectoryLoadHelper (FilePane pane, File dir, string? prev_name)
            {
                Object ( fp : pane,
                         directory : dir,
                         prev_name : prev_name );
            }

            construct {
                // save sorting state.
                is_sorted = fp.m_sorted_list != null && 
                            fp.m_sorted_list.get_sort_column_id (out sort_column, out sort_type);
                

                // Create a new list and fill it with file information.
                store = new ListStore.newv(fp.m_store_types);
            }

            public void
            add_row (FileInfo finfo)
            {
                TreeIter iter;
                store.append (out iter);
                fp.update_row (iter, finfo, store, directory);

                if (prev_name == finfo.get_name ()) {
                    prev_iter = iter;
                }
            }

            public void
            commit ()
            {
                // We're done. Install.
                fp.m_data_store = store;
                fp.m_cursor_path = null;

                // Filter and sort the list, and display it in the TreeView.
                fp.m_list_filter = new TreeModelFilter (fp.m_data_store, null);
                fp.m_list_filter.set_visible_func (fp.filter_list_row);
                fp.m_sorted_list = new TreeModelSort.with_model (fp.m_list_filter);
                fp.m_sorted_list.sort_column_changed.connect (fp.sort_column_changed);

                fp.fix_column_sizes ();
                fp.m_list.set_model(fp.m_sorted_list);

                // Configure the TreeModelSort for our columns
                foreach (var e in fp.m_cmp_funcs.entries) {
                    fp.m_sorted_list.set_sort_func(e.key, e.value.compare_treeiter);
                }
                // Re-enable the sorting, as saved above.
                if (is_sorted) {
                    fp.m_sorted_list.set_sort_column_id (sort_column, sort_type);
                } else {
                    fp.get_sort_from_prefs (fp.m_sorted_list);
                }

                // Move the cursor to the right spot.
                if (prev_iter != null) {
                    TreeIter sort_prev_iter;
                    TreeIter filter_prev_iter;
                    fp.m_list_filter.convert_child_iter_to_iter (out filter_prev_iter, prev_iter);
                    fp.m_sorted_list.convert_child_iter_to_iter (out sort_prev_iter, filter_prev_iter);
                    var curs = fp.m_sorted_list.get_path (sort_prev_iter);
                    fp.m_list.set_cursor (curs, null, false);
                }

                // set title.
                string title;
                // Are we in an archive?
                if (directory.get_uri_scheme() == "archive") {
                    var archive_uri = directory.get_uri();
                    var archive_file = MountManager.get_archive_file (archive_uri);
                    var rel_path = fp.mnt.get_root().get_relative_path (directory);
                    title = "[ %s ] /%s".printf (archive_file.get_basename(), rel_path);
                } else {
                    title = directory.get_parse_name ();
                }
                fp.m_pane_title.set_text (title);

                fp.restyle_complete_list ();
            }

        }

         
        /**
         * Extract data from a FileInfo object into a row in the file list
         */
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

        /**
         * Get file info and display.
         */
        private async void query_and_update (TreeIter unsorted_iter, File file)
        {
            // Make sure that files are only queried once at a time.
            if (m_uris_being_updated == null) {
                m_uris_being_updated = new HashSet<string>();
            }
            var uri = file.get_uri();
            if (uri in m_uris_being_updated) {
                return;
            }
            m_uris_being_updated.add (uri);

            // Query & Update
            try {
                var fileinfo = yield file.query_info_async (
                        m_file_attributes_str,
                        FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                update_row (unsorted_iter, fileinfo, m_data_store);
                restyle (unsorted_iter);
            } catch (Error e) {
                display_error (_("Error fetching file information. (%s)").printf(e.message));
            }

            // Done.
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

        /**
         * Refreshes the information about a file
         *
         * @param file      The file to be updated
         * @param new_file  If the file has been renamed, the new location of the file.
         */
        public override void
        update_file (File file, File? new_file=null)
            requires (m_pwd != null)
        {
            if (new_file == null) {
                new_file = file;
            }

            // Is the file in the current directory?
            var parent = file.get_parent ();
            if (m_pwd.equal (parent)) {
                // okay, it should be in the list.
                bool exists = new_file.query_exists ();
                bool file_found = false;

                m_data_store.@foreach ((model, path, iter) => {
                        Value finfo_val;
                        model.get_value (iter, COL_FILEINFO, out finfo_val);
                        var finfo = (FileInfo) finfo_val.get_object ();
                        if (finfo != null) {
                            if (finfo.get_name() == file.get_basename()) {
                                // same file.
                                if (exists) {
                                    // file exists; update info
                                    file_found = true;
                                    query_and_update.begin (iter, new_file);
                                } else {
                                    // file no longer exists; delete/hide record
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
                    query_and_update.begin (iter, new_file);
                }
            }
        }

        /**
         * Refresh the entire directory
         */
        public override async void
        refresh ()
            requires (m_pwd != null)
        {
            set_busy_state (true);
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
            set_busy_state (false);

        }

        private void toplevel_iter_to_data_iter (out TreeIter data_iter,
                                                 TreeIter toplevel_iter)
        {
            TreeIter filter_iter;
            m_sorted_list.convert_iter_to_child_iter (out filter_iter, toplevel_iter);
            m_list_filter.convert_iter_to_child_iter (out data_iter, filter_iter);
        }

        /**
         * Change how the list is sorted when the user requests it.
         */
        private void sort_column_changed ()
        {
            int sort_column;
            SortType sort_type;

            m_sorted_list.get_sort_column_id (out sort_column, out sort_type);

            m_app.prefs.set_int32 (m_designation + "-sort-column", (int32) sort_column);
            m_app.prefs.set_string (m_designation + "-sort-type", 
                                    sort_type == SortType.ASCENDING ? "asc" : "desc");
        }

        /**
         * Set sort column from preferences file
         */
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

        /**
         * Routine housekeeping tasks when the cursor moves. Emits {@link cursor_changed} signal
         * when done.
         */
        private void handle_cursor_change ()
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

            cursor_changed ();
        }
    
        private TreePath m_select_cache = null;

        private Ref<bool> _right_button_pressed_marker = null;

        /**
         * Button press or release within the TreeView area
         */
        private bool on_mouse_event (EventButton e)
        {
            // Was the click in the header?
            if (e.window != m_list.get_bin_window()) {
                if (e.type == EventType.BUTTON_RELEASE) {
                    // The columns may have been resized. Save this.
                    check_column_sizes ();
                }
                return false;
            }

            // The click was in the actual list area. Find out on which item.
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

                        // This reference is changed when the button is newly pressed,
                        // set to false when it is released, and unset when one second
                        // has elapsed and the popup menu has been displayed.
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
                // double click.
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
            // ignore clicks on title when it is already being edited.
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
                    if (e.keyval == Key.Escape) { // Escape
                        // This moves the focus to the list, and focus_out_event 
                        // is called (see above)
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
            
            // display Entry
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
        public override bool active {
            get { return m_active; }
            set {
                if (m_active != value) {
                    m_active = value;

                    // Restyle the list items where the style depends on the focus.
                    if (m_app.ui_manager.style_info.other_styles_use_focus) {
                        // Every item's style is focus-dependent.
                        // NB: This kind of styling is possible, but it should be avoided
                        //     since switching panels takes much longer this way.
                        restyle_complete_list ();
                    } else {
                        if (m_app.ui_manager.style_info.selected_style_uses_focus) {
                            // restyle selected items
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
                            // restyle cursor item
                            restyle_path(m_cursor_path, true);
                        }

                        // The header style always depends on focus
                        restyle_header ();
                    }
                    
                    // Ensure everything makes sense.
                    other_pane.active = !m_active;
                }
                if (m_active) {
                    // Active pane has focus.
                    m_list.grab_focus ();
                }
            }
        }

        /**
         * Mouse is being moved. Enabled right-button-drag selecting.
         */
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
                case Key.Tab:
                    // activate other panel.
                    active = false;
                    return true;
                case Key.space:
                    if (m_cursor_path != null) {
                        toggle_selected (m_cursor_path);
                    }
                    return true;
                case Key.Return:
                    if (m_cursor_path != null) {
                        activate_row (m_cursor_path);
                    }
                    return true;
                case Key.Menu:
                    if (m_cursor_path != null) {
                        popup_menu_for (m_cursor_path);
                    }
                    return true;
                }
            }
            return false;
        }

        /**
         * Open popup menu (not yet implemented)
         */
        private void popup_menu_for (TreePath path)
        {
            // TODO: popup menu!
        }

        /**
         * Activate row - double-click or return key; open file.
         */
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

        /**
         * Returns a list of currently selected files.
         */
        public override GLib.List<File>
        get_selected_files ()
        {
            var file_list = new GLib.List<File> ();

            // go through entire list to find selected items.
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

        public override File?
        get_file_at_cursor ()
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

            // If there is nothing there, give up.
            TreeIter iter = TreeIter();
            if (m_data_store == null || !m_data_store.get_iter_first(out iter)) {
                return;
            }

            // Go through entire list.
            do {
                restyle (iter, false);
            } while (m_data_store.iter_next(ref iter));

            // Handle cursor specially: restyle() doesn't recognize the cursor.
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
            // Dummy GLib.Value objects
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

            // Get file info
            Value finfo_val;
            m_data_store.get_value (unsorted_iter, COL_FILEINFO, out finfo_val);
            var finfo = (FileInfo) finfo_val.get_object();
            if (finfo == null) {
                return;
            }

            // Reset the style

            m_data_store.set_value (unsorted_iter, COL_FG_COLOR, nullcolor);
            m_data_store.set_value (unsorted_iter, COL_FG_SET, falsevalue);

            m_data_store.set_value (unsorted_iter, COL_BG_COLOR, nullcolor);
            m_data_store.set_value (unsorted_iter, COL_BG_SET, falsevalue);

            m_data_store.set_value(unsorted_iter, COL_WEIGHT, normalweight);
            m_data_store.set_value(unsorted_iter, COL_WEIGHT_SET, falsevalue);

            m_data_store.set_value(unsorted_iter, COL_STYLE, normalstyle);
            m_data_store.set_value(unsorted_iter, COL_STYLE_SET, falsevalue);

            // Apply the style rules one by one.

            foreach (var style in m_app.ui_manager.style_directives) {

                // Does this rule apply? If not, continue;

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

        public override void
        show_all ()
        {
            base.show_all ();
            hide_error ();
        }


        /**
         * Wraps an Emperor CompareFunc (for a column to produce a
         * TreeIterCompareFunc that also sorts based on the global sort functions.
         */
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

        
    }

}


