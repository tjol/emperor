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
 
namespace Emperor.App {

    public class MountManager : Object
    {
        private EmperorCore m_app;

        internal MountManager (EmperorCore application)
        {
            m_app = application;
        }
        
        /**
         * Get the GIO mount object for a location. If the location is not mounted,
         * attempt to mount.
         *
         * @param pwd Location to be examined
         * @param mnt_ref Variable to save mount reference to. Keep this object around as
         *                long as the mount is used, and dispose of it when done. It's used
         *                for automatic unmounting of archives.
         * @param mnt_op MountOperation to use when mounting
         * @return True if mounted without error and Mount object writter to "mnt"
         */
        public async bool procure_mount (File pwd, out MountRef mnt_ref,
                                         UIFeedbackComponent feedback,
                                         GLib.MountOperation? mnt_op,
                                         Cancellable? cancellable=null)
        {
            bool mount_error = false;
            Mount mnt;
            MountRef parent_mountref = null;
            mnt_ref = null;

            GLib.MountOperation real_mnt_op;
            if (mnt_op == null) {
                real_mnt_op = new Gtk.MountOperation (feedback.owning_window);
            } else {
                real_mnt_op = mnt_op;
            }


            try {
                mnt = yield pwd.find_enclosing_mount_async (Priority.DEFAULT, cancellable);
            } catch (Error mnterr1) {
                mount_error = true;
                mnt = null;
            }
            if (mount_error && ! pwd.is_native()) {
                // not mounted. Can I mount this?
                bool mounted = false;

                // Is this an archive? 
                if (pwd.get_uri_scheme () == "archive") {
                    // Get the parent mount first. This may need to be mounted.
                    yield procure_mount (get_archive_file (pwd.get_uri ()), out parent_mountref, feedback,
                                         real_mnt_op, cancellable);
                }

                // create notification in case this takes a while.
                var waiter = feedback.notify_waiting_for_mount (cancellable);
                feedback.set_busy_state (true);
                try {
                    // queue notification
                    waiter.go();

                    // Mount.
                    yield pwd.mount_enclosing_volume (
                            MountMountFlags.NONE, real_mnt_op,
                            cancellable);

                    mounted = true;
                } catch (Error mnterr2) {
                    if (! cancellable.is_cancelled ()) {
                        feedback.display_error (_("Error mounting volume. (%s)").printf(mnterr2.message));
                    }
                    mounted = false;
                }
                // Finished - for better or for worse
                feedback.set_busy_state (false);
                waiter.done ();

                if (mounted) {
                    try {
                        // This should always succeed since we just created the very mount
                        // being retrieved here.
                        mnt = yield pwd.find_enclosing_mount_async ();
                    } catch (Error mnterr3) {
                        if (! cancellable.is_cancelled ()) {
                            feedback.display_error (_("Error accessing mount. (%s)").printf(
                                                mnterr3.message));
                        }
                        return false;
                    }
                } else {
                    // not mounted
                    return false;
                }

                // Special case for archives: If the operation is cancelled *after* mounting the archive,
                // unmount immediately. It's not being used, so we don't want the refernece hanging around.
                if (pwd.get_uri_scheme() == "archive") {
                    if (cancellable.is_cancelled()) {
                        try {
                            yield mnt.unmount_with_operation (MountUnmountFlags.NONE,
                                real_mnt_op);
                        } catch (Error mnterr4) {
                            // If this failed, so be it. The user shouldn't be bothered.
                            // They won't actually be surprised by a dangling mount if they cancel at this time.
                        }
                        return false;
                    }
                }
            }

            // Return a MountRef object. Ensure that only one MountRef object exists per mount at any time.
            // This way, GObject reference counting can be used to discover when a mount is no longer used.
            string? mnt_uri = null;
            if (mnt != null) {
                mnt_uri = mnt.get_root ().get_uri ();
            }

            if (s_mount_refs.has_key (mnt_uri)) {
                mnt_ref = s_mount_refs[mnt_uri];
                mnt_ref.mount = mnt;
            } else {
                mnt_ref = new MountRef (this, mnt, feedback, real_mnt_op);
                if (parent_mountref != null) {
                    mnt_ref.parent_mountref = parent_mountref;
                } else {
                    yield mnt_ref.find_parent_mountref ();
                }

                s_mount_refs[mnt_uri] = mnt_ref;
            }

            return true;
        }

        /**
         * Get the MountRef for a given GIO Mount. This will only work if there
         * is a mount reference previously created by {@link procure_mount}. 
         * Use this only if you are certain that the location is currently open
         * in a file pane. Otherwise, call {@link procure_mount} instead.
         */
        public MountRef? get_reference_to_mount (Mount? mnt)
        {
            string? mnt_uri = null;
            if (mnt != null) {
                mnt_uri = mnt.get_root ().get_uri ();
            }

            if (s_mount_refs.has_key (mnt_uri)) {
                return s_mount_refs[mnt_uri];
            } else {
                return null;
            }
        }

        private static HashMap<string?, weak MountRef> s_mount_refs = null;

        class construct {
            s_mount_refs = new HashMap<string?, weak MountRef> ();
        }

        public class MountRef : Object
        {
            public Mount? mount { get; internal construct set; }
            private File? m_mnt_root;
            private MountManager m_mount_manager;
            private UIFeedbackComponent m_feedback;
            private GLib.MountOperation m_mount_operation;
            internal MountRef? parent_mountref { get; set; default = null; }

            internal MountRef (MountManager mntmgr, Mount? mnt, UIFeedbackComponent feedback,
                               GLib.MountOperation mnt_op)
            {              
                Object ( mount : mnt );
             
                m_mount_manager = mntmgr;
                m_feedback = feedback;
                m_mount_operation = mnt_op;
                if (mnt != null) {
                    m_mnt_root = mnt.get_root ();
                }

            }

            internal async void find_parent_mountref ()
            {
                if (mount == null) return;

                if (m_mnt_root.get_uri_scheme () == "archive") {
                    // Get a hold on the mount refernece to our parent.
                    var my_file = MountManager.get_archive_file (m_mnt_root.get_uri ());
                    MountRef pmr;
                    if (yield m_mount_manager.procure_mount (my_file, out pmr, m_feedback, m_mount_operation)) {
                        parent_mountref = pmr;
                    }
                }
            }

            int m_lock_count = 0;

            /**
             * Request that the mount be kept open. This is a simple counter internal to
             * Emperor. Emperor modules shouldn't unmount volumes that are considered
             * enforced, but there is no guarantee that an "enforced" mount will not be
             * removed.
             */
            public int enforce ()
            {
                m_lock_count ++;
                if (m_lock_count == 1) {
                    // now enforced, previously not.
                    notify_property ("enforced");
                }
                return m_lock_count;
            }

            /**
             * Decrease the enforce count.
             *
             * @see enforce
             */
            public int unenforce ()
            {
                m_lock_count --;
                if (m_lock_count == 0) {
                    // no longer enforced.
                    notify_property ("enforced");
                }
                return m_lock_count;
            }

            /**
             * Is this mount requested to be kept alive?
             *
             * @see enforce
             */
            public bool enforced { get { return m_lock_count != 0; } }

            ~MountRef ()
            {
                if (mount == null) return;
                
                // Is this an archive?
                if (m_mnt_root.get_uri_scheme () == "archive") {
                    mount.unmount_with_operation.begin (MountUnmountFlags.NONE, m_mount_operation);
                    var mnt_uri = m_mnt_root.get_uri ();
                    if (MountManager.s_mount_refs.has_key (mnt_uri)) {
                        MountManager.s_mount_refs.unset (mnt_uri);
                    }
                }
            }
        }

        /**
         * Helper function to find the archive file given a URI within the archive.
         */
        public static File? get_archive_file (string archive_uri)
        {
            var spl1 = archive_uri.split ("://", 2);
            if (spl1.length >= 2) {
                var spl2 = spl1[1].split ("/", 2);
                var archive_host = spl2[0];
                var archive_file_uri_esc1 = Uri.unescape_string (archive_host, null);
                var archive_file_uri = Uri.unescape_string (archive_file_uri_esc1, null);
                return File.new_for_uri (archive_file_uri);
            } else {
                return null;
            }
        }

    }
}
