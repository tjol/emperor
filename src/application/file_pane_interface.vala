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
 
namespace Emperor.Application {

    /**
     * Method that determines whether a file is shown in the list or not.
     * 
     * @param f     The file in question
     * @param fi    A FileInfo object describing the file, with default attributes
     * @param currently_visible \
     *              If this filter didn't exist, would the file be displayed? Return this \
     *              as default value.
     */
    public delegate bool FileFilterFunc (File f, FileInfo fi, bool currently_visible);
    
    /**
     * Method that creates a toolbar for the file pane.
     * NOTE: The type of the second argument should be IFilePane, not Object.
     * This causes some dependency issues in the generated C code, however,
     * so this delegate uses Object, and, as a workaround, another delagate
     * is defined in `user_interface_manager.vala` for public use.
     *
     * @param mwnd	Main application window.
     * @param fpane	The file pane the toolbar is associated with
     * @see UserInterfaceManager.FilePaneToolbarFactoryProper
     */
    public delegate Widget FilePaneToolbarFactory (EmperorCore app, Object fpane);
    
    /**
     * Interface providing basic user-feedback functionality: displaying and hiding
     * an error message, setting the cursor to "busy", etc.
     */
    public interface IUIFeedbackComponent : Widget {
        /**
         * The Gtk.Window that owns that this component is associated with.
         */
        public abstract Gtk.Window owning_window { get; }

        /**
         * Show error.
         *
         * @param message Error message, should be translatable.
         */
        public abstract void display_error (string message);
        /**
         * Hide the error message, if any.
         */
        public abstract void hide_error ();
        
        /**
         * Set the component to appear busy, or not. Usually, this will
         * change the mouse cursor.
         */
        public abstract void set_busy_state (bool busy);

        /**
         * Create a mount-wait notification. This is simply a wrapper around 
         * {@link new_waiting_for_mount}.
         */
        public IWaitingForMount notify_waiting_for_mount (Cancellable? cancellable=null)
        {
            return new_waiting_for_mount (owning_window, cancellable);
        }
    }
 
    public interface IFilePane : IUIFeedbackComponent {

        public IFilePane other_pane {
            get {
                if (this == application.main_window.left_pane) {
                    return application.main_window.right_pane;
                } else {
                    return application.main_window.left_pane;
                }
            }
        }
       
        public abstract EmperorCore application { get; }
        public abstract string designation { get; }
        
        /**
         * Whether or not this pane is active. Setting this property
         * will change the other pane's state accordingly.
         */
        public abstract bool active { get; set; }
        
        /**
         * Install file filter.
         *
         * @param id Unique identifier, can be used to remove filter later with {@link remove_filter}
         */
        public abstract void add_filter (string id, owned FileFilterFunc filter);
        /**
         * Remove filter added with {@link add_filter}
         *
         * @param id Identifier as passed to {@link add_filter}
         */
        public abstract bool remove_filter (string id);
        
        /**
         * Check if given filter is installed at the moment.
         *
         * @see add_filter
         * @see remove_filter
         */
        public abstract bool using_filter (string id);
        
        /**
         * Register a file attribute to be automatically queried and available in FileInfo objects
         * created in this file pane.
         */
        public abstract void add_query_attribute (string att);
        
        /**
         * Add a sort function that is applied to the files in the list, in addition to,
         * and with priority over, the sort column selected by the user.
         * Example: directories being sorted first
         *
         * @see remove_sort
         */
        public abstract void add_sort (string id, owned FileInfoCompareFunc cmp);
        /**
         * Remove a sort function installed with {@link add_sort}
         */
        public abstract bool remove_sort (string id);
        /**
         * Check if given sort function is in use.
         *
         * @see add_sort
         * @see remove_sort
         */
        public abstract bool using_sort (string id);
        
        /**
         * Add a toolbar to this FilePane.
         *
         * @param id \
         *              identifier that can be used to retrieve the toolbar
         *              using {@link get_addon_toolbar}
         * @param factory FilePaneToolbarFactory that creates the toolbar.
         * @param where   desired position of the toolbar.
         */
        public abstract void install_toolbar (string id, FilePaneToolbarFactory factory, PositionType where);

        /**
         * Get a reference to your add-on toolbar, or null if it's not installed
         */
        public abstract Widget? get_addon_toolbar (string id);
        
        /**
         * The directory currently being listed. Setting the property changes
         * directory asynchronously
         *
         * @see chdir_then_focus
         * @see chdir
         * @see mnt
         */
        public abstract File pwd { get; set; }

        /**
         * The GIO Mount object the current working directory is on.
         *
         * @see pwd
         */
        public abstract Mount mnt { get; }
        
        /**
         * Change directory and focus the file list when done.
         *
         * @see chdir
         */
        public abstract async bool chdir_then_focus (File pwd,
                                                        string? prev_name=null,
                                                        GLib.MountOperation? mnt_op=null);
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
        public abstract async bool chdir (File pwd, string? prev_name=null, GLib.MountOperation? mnt_op=null);
        
        /**
         * Change directory to the location saved in the preferences file
         */
        public async bool chdir_from_pref ()
        {
            var old_pwd_str = application.prefs.get_string (designation + "-pwd", null);
            File old_pwd;
            if (old_pwd_str != null) {
                old_pwd = File.parse_name (old_pwd_str);
            } else {
                old_pwd = File.new_for_path (".");
            }
            return yield chdir (old_pwd);
        }

        /**
         * Refreshes the information about a file
         *
         * @param file      The file to be updated
         * @param new_file  If the file has been renamed, the new location of the file.
         */
        public abstract void update_file (File file, File? new_file=null);

        /**
         * Refresh the entire directory
         */
        public abstract async void refresh ();

        /**
         * The cursor has moved.
         */
        public signal void cursor_changed ();

        /**
         * Parent of the current working directory.
         */
        public abstract File? parent_dir { get; }

        /**
         * Get a child file of the current directory by name.
         */
        public File get_child_by_name (string name)
        {
            if (name == "..") {
                return parent_dir;
            } else {
                return pwd.get_child (name);
            }
        }

        /**
         * Returns a list of currently selected files.
         */
        public abstract GLib.List<File> get_selected_files ();

        /**
         * Get the file at the cursor, if defined. (otherwise null)
         */
        public abstract File? get_file_at_cursor ();

    }
    
    /**
     * Dumb wrapper of FileFilterFunc for use in generics
     */
    protected class FileFilterFuncWrapper : Object
    {
        public FileFilterFuncWrapper (owned FileFilterFunc f) {
            m_func = (owned) f;
        }
        FileFilterFunc m_func;
        public unowned FileFilterFunc func {
            get {
                return m_func;
            }
        }
    }

    /**
     * Dumb wrapper of FileInfoCompareFunc for use in generics
     */
    protected class FileInfoCompareFuncWrapper : Object
    {
        public FileInfoCompareFuncWrapper (owned FileInfoCompareFunc f) {
            m_func = (owned) f;
        }
        FileInfoCompareFunc m_func;
        public unowned FileInfoCompareFunc func {
            get {
                return m_func;
            }
        }
    }
 
 }
 
