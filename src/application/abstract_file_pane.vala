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
using Gee;

namespace Emperor.Application {

    /**
     * Generic superclass for IFilePane implementations that implements 
     * UI independent functionality.
     *
     * 
     */
    public abstract class AbstractFilePane : Gtk.VBox,
                                             IUIFeedbackComponent,
                                             IFilePane
    {
        /* *****************************************************
         * CONSTRUCT PROPERTIES
         ******************************************************/
        // I'd rather these were declared { get; construct; }, but this is not possible.
        // See https://bugzilla.gnome.org/show_bug.cgi?id=683160
        public Gtk.Window owning_window { get; protected construct set; }
        public EmperorCore application { get; protected construct set; }
        public string designation { get; protected construct set; }

    	/* *****************************************************
    	 * INSTANCE VARIABLES
    	 ******************************************************/
    	protected Map<string,FileFilterFuncWrapper> m_filters;
    	protected Set<string> m_file_attributes;
    	protected string m_file_attributes_str;
    	protected Map<string,FileInfoCompareFuncWrapper> m_permanent_sort;
    	protected File m_pwd;
        protected File? m_parent_dir = null;
    	protected Mount? m_mnt = null;
    	protected MountManager.MountRef? m_mnt_ref = null;

    	/*
    	 * GObject style constructor. Called automatically.
    	 */
        construct {
    		m_filters = new HashMap<string,FileFilterFuncWrapper> ();

    		m_file_attributes = new HashSet<string>();
            m_file_attributes.add(FileAttribute.STANDARD_NAME);
            m_file_attributes.add(FileAttribute.STANDARD_TYPE);
            m_file_attributes.add(FileAttribute.STANDARD_CONTENT_TYPE);
            m_file_attributes.add(FileAttribute.STANDARD_SYMLINK_TARGET);
            m_file_attributes.add(FileAttribute.STANDARD_TARGET_URI);

            m_permanent_sort = new HashMap<string,FileInfoCompareFuncWrapper> ();
    	}

    	/**
    	 * Build m_file_attributes_str
    	 */
    	protected void
    	recreate_file_attributes_string ()
    	{
    		var sb = new StringBuilder();
            bool first = true;
            foreach (string attr in m_file_attributes) {
                if (!first) sb.append_c(',');
                else first = false;

                sb.append(attr);
            }
            m_file_attributes_str = sb.str;
    	}

    	/* *****************************************************
    	 * ADDITIONAL ABSTRACT METHODS THAT MUST BE IMPLEMENTED
    	 ******************************************************/

    	/**
    	 * Re-apply list filters
    	 */
    	protected abstract void refilter_list ();


    	/**
    	 * Refresh list sorting
    	 */
    	protected abstract void refresh_sorting ();

    	/**
    	 * Provide implementation specific parts of the chdir
    	 * method.
    	 */
    	protected abstract IDirectoryLoadHelper get_directory_load_helper (File dir, string? prev_name);


    	/* *****************************************************
    	 * IMPLEMENTATION
    	 ******************************************************/

        /**
         * Install file filter.
         *
         * @param id Unique identifier, can be used to remove filter later with {@link remove_filter}
         */
        public virtual void
        add_filter (string id, owned FileFilterFunc filter)
        {
            m_filters[id] = new FileFilterFuncWrapper ((owned) filter);
            refilter_list ();
        }

        /**
         * Remove filter added with {@link add_filter}
         *
         * @param id Identifier as passed to {@link add_filter}
         */
        public virtual bool
        remove_filter (string id)
        {
            bool removed = m_filters.unset (id);
            if (removed) {
            	refilter_list ();
            }
            return removed;
        }

        /**
         * Check if given filter is installed at the moment.
         *
         * @see add_filter
         * @see remove_filter
         */
        public virtual bool
        using_filter (string id)
        {
            return m_filters.has_key (id);
        }

        /**
         * Register a file attribute to be automatically queried and available in FileInfo objects
         * created in this file pane.
         */
        public virtual void
        add_query_attribute (string att)
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

        /**
         * Add a sort function that is applied to the files in the list, in addition to,
         * and with priority over, the sort column selected by the user.
         * Example: directories being sorted first
         *
         * @see remove_sort
         */
        public virtual void
        add_sort (string id, owned FileInfoCompareFunc cmp)
        {
            m_permanent_sort[id] = new FileInfoCompareFuncWrapper ((owned) cmp);
            refresh_sorting ();
        }

        /**
         * Remove a sort function installed with {@link add_sort}
         */
        public virtual bool
        remove_sort (string id)
        {
            bool removed = m_permanent_sort.unset (id);
            if (removed) {
                refresh_sorting ();
            }
            return removed;
        }

        /**
         * Check if given sort function is in use.
         *
         * @see add_sort
         * @see remove_sort
         */
        public virtual bool
        using_sort (string id)
        {
            return m_permanent_sort.has_key (id);
        }

        /**
         * The directory currently being listed. Setting the property changes
         * directory asynchronously
         *
         * @see chdir_then_focus
         * @see chdir
         */
        [CCode(notify = false)]
        public virtual File pwd {
            get { return m_pwd; }
            set {
                chdir.begin(value, null);
            }
        }

        /**
         * The GIO Mount object the current working directory is on.
         */
        public virtual Mount mnt {
            get { return m_mnt; }
        }

        /**
         * Parent of the current working directory.
         */
        public virtual File? parent_dir {
            get { return m_parent_dir; }
        }

        /**
         * Change directory and focus the file list when done.
         *
         * @see chdir
         */
        public virtual async bool
        chdir_then_focus (File pwd, string? prev_name=null, GLib.MountOperation? mnt_op=null)
        {
            var prev_name_ = prev_name;
            if (prev_name_ == null) {
                // we care about correct focus here. Check if we're going to the parent, perchance.
                if (this.pwd.has_parent(pwd)) {
                    prev_name_ = this.pwd.get_basename ();
                }
            }

            bool success =  yield chdir (pwd, prev_name_, mnt_op);
            if (success) {
                this.active = true;
                give_focus_to_list ();
            }
            return success;
        }

    	protected Cancellable? m_chdir_cancellable = null;

        /**
         * Change directory.
         *
         * @param pwd Directory to change to
         * @param prev_name \
         *          Name of the file to place the cursor on when done.
         * @param mnt_op \ 
         *          GIO MountOperation used in case the location has to be mounted first. \
         * @return false on error, true if successful or cancelled.
         */
        public virtual async bool
        chdir (File pwd, string? prev_name=null, GLib.MountOperation? mnt_op=null)
        {
            File parent = null;
            File archive_file = null;
            MountManager.MountRef mnt_ref = null;
            Mount mnt = null;

            // If another directory is currently being changed to, cancel that operation.
            // Also, make this chdir operation cancellable in the same way.
            var cancellable = new Cancellable ();
            if (m_chdir_cancellable != null) {
                m_chdir_cancellable.cancel ();
            }
            m_chdir_cancellable = cancellable;

            // Set up the implementation specific part.
            var load_helper = get_directory_load_helper (pwd, prev_name);

            // No longer care if volume is unmounted. Will reconnect signal if still on same mount.
            if (this.mnt != null) {
                this.mnt.unmounted.disconnect (on_unmounted);
            }

            // Make sure the volume is mounted.
            if (! yield application.mount_manager.procure_mount (pwd, out mnt_ref, this, mnt_op, cancellable)) {
                return cancellable.is_cancelled ();
            }
            mnt = mnt_ref.mount;

            // We're in business. Look busy.
            set_busy_state (true);

            // Enumerate files
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

            // Add [..]
            parent = pwd.get_parent();

            // Are we in an archive?
            if (pwd.get_uri_scheme() == "archive") {
                var archive_uri = pwd.get_uri();
                archive_file = MountManager.get_archive_file (archive_uri);
            }

            // If this is the root of the archive, make [..] refer to the directory the
            // archive is in. Archives should behave just like directories where possible.
            if (parent == null && archive_file != null) {
                parent = archive_file.get_parent();
            }

            // The parent needs to be treated specially. Get all the file information
            // for it.
            FileInfo parent_info = null;
            if (parent != null) {
                try {
                    parent_info = yield parent.query_info_async(m_file_attributes_str,
                                                FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                                                Priority.DEFAULT, cancellable);
                } catch (Error err2) {
                    if (cancellable.is_cancelled()) return true;

                    // Display error detailing the problem.
                    display_error (_("Error querying parent directory: %s (%s)")
                                    .printf(parent.get_parse_name(),
                                            err2.message));
                }
            }

            if (parent_info != null) {
                // Don't use the actual file name, just call it ".."
                parent_info.set_display_name("..");
                parent_info.set_name("..");
                // Even if we're in a hidden directory, we definitely want to see [..]
                parent_info.set_is_hidden(false);
                parent_info.set_attribute_boolean(FileAttribute.STANDARD_IS_BACKUP, false);

                load_helper.add_row (parent_info);
            }

            // Add the other non special case files one by one.
            while (true) {
                // get a batch of FileInfo objects
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

                // add the batch of FileInfo objects to the list
                foreach (var file in fileinfos) {
                    load_helper.add_row (file);
                }
            }
            
            // Cancelled? Leave.
            if (cancellable.is_cancelled ()) return true;

            // Update class properties
            m_pwd = pwd;
            m_mnt_ref = mnt_ref;
            m_mnt = mnt;
            m_parent_dir = parent;

            // Hand over to implementation specific finalization
            load_helper.commit ();

            // Tie up the rest with notifications etc.

            notify_property ("pwd");
            notify_property ("mnt");
            notify_property ("parent_dir");
            // Make sure we know when our volume disappears.
            if (mnt != null) {
                mnt.unmounted.connect (on_unmounted);
            }
            
            // save pwd to prefs
            application.prefs.set_string (designation + "-pwd", pwd.get_parse_name());

            set_busy_state (false);

            m_chdir_cancellable = null;

            return true;
        }

        /**
         * Called when the current directory is unmounted (and should therefore no
         * longer be displayed because one cannot interact with it)
         */
        protected virtual void
        on_unmounted ()
        {
            chdir.begin (File.new_for_path (Environment.get_home_dir()), null);
            display_error (_("Location unmounted."));
        }

        /**
         * Activate/open a file.
         * 
         * @param file_info		A GLib.FileInfo describing the file
         * @param real_file	\
         *						The actual file in question. This is for 
         *						internal use when encountering symbolic 
         *						links.
         */
        protected virtual async void
        activate_file (FileInfo file_info, File? real_file=null)
        {
            FileInfo info;
            MountManager.MountRef mnt_ref;

            switch (file_info.get_file_type()) {
            // Enter directory
            case FileType.DIRECTORY:
                File dir;
                if (real_file == null) {
                    dir = get_child_by_name (file_info.get_name());
                } else {
                    dir = real_file;
                }

                string? old_name = null;
                if (file_info.get_name () == "..") {
                    // going up, to the parent.
                    if (pwd.get_uri_scheme () == "archive" && !pwd.has_parent (null)) {
                        // Leaving the archive. Find archive file name.
                        var archive_file = MountManager.get_archive_file (pwd.get_uri ());
                        if (archive_file != null) {
                            old_name = archive_file.get_basename ();
                        }

                    } else {
                        // Normal chdir, find directory name.
                        old_name = pwd.get_basename ();
                    }


                } else {
                    // going down to a child.
                    old_name = "..";
                }

                yield chdir(dir, old_name);

                break;

            // Dereference symbolic link, and activate target.
            case FileType.SYMBOLIC_LINK:
                var target_s = file_info.get_symlink_target ();
                var target = pwd.resolve_relative_path (target_s);
                if (!yield application.mount_manager.procure_mount (target, out mnt_ref, this, null)) {
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

            // Shortcuts are handled like symbolic links.
            case FileType.SHORTCUT:
                var sc_target_s = file_info.get_attribute_string (
                                        FileAttribute.STANDARD_TARGET_URI);
                var sc_target = File.new_for_uri (sc_target_s);
                if (!yield application.mount_manager.procure_mount (sc_target, out mnt_ref, this, null)) {
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
                    file = pwd.get_child (file_info.get_name());
                } else {
                    file = real_file;
                }

                if (file_info.get_content_type() in ARCHIVE_TYPES) {
                    //
                    // attempt to mount as archive.
                    //

                    var archive_host = Uri.escape_string (file.get_uri(), "", false);
                    // escaping percent signs need to be escaped :-/
                    var escaped_host = Uri.escape_string (archive_host, "", false);
                    var archive_file = File.new_for_uri ("archive://" + escaped_host);
                    if (yield chdir (archive_file, "..")) {
                        // success!
                        return;
                    } else {
                        // failure. Hand it over to the OS.
                        hide_error ();
                    }
                }

                // If it's not an archive, or mounting failed, tell the operating
                // system to open the file in a sensible way.
                application.open_file (file);
                break;
            }
        }

        /* *****************************************************
         * NOT IMPLEMENTED HERE
         ******************************************************/

        public abstract void display_error (string message);
        public abstract void hide_error ();
        public abstract void set_busy_state (bool busy);
        public abstract void install_toolbar (string id, FilePaneToolbarFactory factory, Gtk.PositionType where);
        public abstract Gtk.Widget? get_addon_toolbar (string id);
        public abstract void update_file (File file, File? new_file=null);
        public abstract async void refresh ();
        public abstract GLib.List<File> get_selected_files ();
        public abstract File? get_file_at_cursor ();
        public abstract bool active { get; set; }
        protected abstract void give_focus_to_list ();
    }


	public interface IDirectoryLoadHelper : Object
	{
		public abstract void add_row (FileInfo finfo);
		public abstract void commit ();
	}



}