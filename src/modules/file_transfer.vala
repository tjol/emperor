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
using Emperor.Application;

namespace Emperor.Modules {

    public class FileTransfersModule : Object
    {
        public static void register (ModuleRegistry reg)
        {
            Gtk.Action action;

            var app = reg.application;
            var module = new FileTransfersModule (app);

            // F5: Copy.
            action = reg.new_action ("copy");
            action.label = _("Copy");
            action.set_accel_path ("<Emperor-Main>/FileTransfers/Copy");
            AccelMap.add_entry ("<Emperor-Main>/FileTransfers/Copy",
                                    Gdk.Key.F5, 0);
            action.activate.connect ( () => { module.do_transfer.begin (false); } );
            action.connect_accelerator ();
            app.ui_manager.add_action_to_menu (_("_File"), action, 60);

            // F6: Move
            action = reg.new_action ("move");
            action.label = _("Move");
            action.set_accel_path ("<Emperor-Main>/FileTransfers/Move");
            AccelMap.add_entry ("<Emperor-Main>/FileTransfers/Move",
                                    Gdk.Key.F6, 0);
            action.activate.connect ( () => { module.do_transfer.begin (true); } );
            action.connect_accelerator ();
            app.ui_manager.add_action_to_menu (_("_File"), action, 61);
        }

        public FileTransfersModule (EmperorCore app)
        {
            Object ( application : app );
        }

        public EmperorCore application { get; construct; }

        private async void do_transfer (bool move)
        {
            var pane = application.main_window.active_pane;
            var files = pane.get_selected_files ();
            var target_pane = application.main_window.passive_pane;

            var target_path = target_pane.pwd.get_parse_name ();

            var n_files = files.length ();
            string fname = null;
            if (n_files == 0) {
                pane.display_error (_("No files selected."));
                return;
            } else if (n_files == 1) {
                fname = files.nth_data(0).get_basename();
            }

            string dialog_title;
            string dialog_text;
            string go_ahead_txt;


            get_transfer_dialog_texts (move, n_files, fname, out dialog_title,
                                       out dialog_text, out go_ahead_txt,
                                       _("calculating size…"));

            var dialog = new InputDialog (dialog_title, application.main_window);
            //dialog.add_button
            dialog.add_button (Stock.CANCEL, ResponseType.CANCEL);
            dialog.add_button (go_ahead_txt, ResponseType.OK, true);
            var text_label = dialog.add_text (dialog_text);
            dialog.add_entry ("target", target_path);
            dialog.add_input ("deref", new CheckButton.with_label (
                                _("Dereference symbolic links")));

            uint64 total_size_in_bytes = 0;
            var file_infos = new ArrayList<FileInfo>();

            dialog.decisive_response.connect ((id) => {
                    if (id == ResponseType.OK) {
                        var dest_path = dialog.get_text ("target");
                        var dest_file = File.parse_name (dest_path);
                        bool deref_symlinks = ((CheckButton)dialog["deref"]).active;
                        dialog.destroy ();
                        transfer_files.begin ((owned) files,
                                              file_infos,
                                              n_files,
                                              total_size_in_bytes,
                                              dest_file,
                                              move,
                                              deref_symlinks);
                    } else {
                        dialog.destroy ();
                    }
                    return false;
                });

            dialog.show_all ();

            foreach (var file in files) {
                try {
                    var finfo = yield file.query_info_async (
                                             FILE_ATTRIBUTE_STANDARD_SIZE + ","
                                                + FILE_ATTRIBUTE_STANDARD_TYPE + ","
                                                + FILE_ATTRIBUTE_STANDARD_SIZE,
                                             FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                    total_size_in_bytes += finfo.get_size ();
                    if (finfo.get_file_type() == FileType.DIRECTORY) {
                        int files_within;
                        total_size_in_bytes += yield get_directory_size (file,
                                                    FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                                                    out files_within);
                        n_files += files_within - 1;
                    }
                    file_infos.add (finfo);
                } catch (Error e) {
                    show_error_message_dialog (application.main_window,
                        _("Error getting size of “%s”.").printf(file.get_basename()),
                        e.message);
                }
            }

            get_transfer_dialog_texts (move, n_files, fname,
                                       out dialog_title, out dialog_text, 
                                       out go_ahead_txt,
                                       bytesize_to_string(total_size_in_bytes));
            text_label.set_text (dialog_text);
            
        }

        private async uint64 get_directory_size (File directory, FileQueryInfoFlags flags,
                                                 out int files_within)
        {
            uint64 total = 0;
            files_within = 0;

            try {
                var enumerator = yield directory.enumerate_children_async (
                                            FILE_ATTRIBUTE_STANDARD_SIZE + ","
                                                + FILE_ATTRIBUTE_STANDARD_NAME + ","
                                                + FILE_ATTRIBUTE_STANDARD_TYPE,
                                            flags);
                GLib.List<FileInfo> fileinfos;
                while ((fileinfos = yield enumerator.next_files_async (20)) != null) {
                    foreach (var finfo in fileinfos) {
                        total += finfo.get_size ();
                        if (finfo.get_file_type() == FileType.DIRECTORY) {
                            int inner_files;
                            total += yield get_directory_size (
                                            directory.get_child (finfo.get_name()),
                                            flags, out inner_files);
                            files_within += inner_files;
                        } else {
                            files_within ++;
                        }
                    }
                }
            } catch (Error e) {
                show_error_message_dialog (null,
                    _("Error fetching size of directory “%s”.").printf(directory.get_basename()),
                    e.message);
            }

            return total;
        }

        private void get_transfer_dialog_texts (bool move, uint n_files, string? fname,
                                                out string dialog_title,
                                                out string dialog_text,
                                                out string go_ahead_txt,
                                                string file_size)
        {
            if (move) {
                if (n_files == 1) {
                    dialog_title = _("Move file");
                    dialog_text = _("Move file “%s” (%s) to:").printf (
                                        fname,
                                        file_size);
                } else {
                    dialog_title = _("Move files");
                    dialog_text = _("Move %u files (%s) to:").printf (n_files, file_size);
                }
                go_ahead_txt = _("Move");
            } else { // copy
                if (n_files == 1) {
                    dialog_title = _("Copy file");
                    dialog_text = _("Copy file “%s” (%s) to:").printf (
                                        fname,
                                        file_size);
                } else {
                    dialog_title = _("Copy files");
                    dialog_text = _("Copy %u files (%s) to:").printf (n_files, file_size);
                }
                go_ahead_txt = _("Copy");
            }

        }

        private async void transfer_files (owned GLib.List<File> files, Gee.List<FileInfo> file_infos,
                                           uint total_n_files,
                                           uint64 total_size_in_bytes, File dest,
                                           bool move, bool deref_links)
        {
            application.hold ();

            var dialog = new InputDialog ( move ? _("Moving files") : _("Copying files"),
                                           application.main_window,
                                           0 ); // not modal. Do not destroy with parent.

            dialog.deletable = false;
            dialog.resizable = false;

            dialog.add_button (Stock.STOP, ResponseType.CLOSE);

            if (move) {
                if (total_n_files == 1) {
                    dialog.add_text (_("Moving file “%s” to “%s”").printf(
                        files.nth_data(0).get_basename(), dest.get_basename()));
                } else {
                    dialog.add_text (_("Moving %d files to “%s”").printf(
                        total_n_files, dest.get_basename()));
                }
            } else {
                if (total_n_files == 1) {
                    dialog.add_text (_("Copying file “%s” to “%s”").printf(
                        files.nth_data(0).get_basename(), dest.get_basename()));
                } else {
                    dialog.add_text (_("Copying %d files to “%s”").printf(
                        total_n_files, dest.get_basename()));
                }
            }

            var progress_bar = new ProgressBar ();
            dialog.pack_start (progress_bar);

            bool active = true;
            var cancellable = new Cancellable ();

            dialog.decisive_response.connect ((id) => {
                    if (id == ResponseType.CLOSE) {
                        cancellable.cancel ();
                        active = false;

                        dialog.destroy ();
                        return false;
                    } else {
                        return true;
                    }
                });

            /* Only show progress dialog after one second. If the whole transfer took less
             * than a second, showing it would be silly.
             */
            Timeout.add (1000, () => {
                    if (active) {
                        dialog.focus_on_map = false;
                        dialog.show_all ();
                    }
                    return false;
                });

            // Value used as a box.
            uint64* done_bytes_p = (uint64*) malloc ( sizeof(uint64)
                                                    + 2*sizeof(FileCopyFlags) );
            *done_bytes_p = 0;
            FileCopyFlags* copy_flags_p = (FileCopyFlags*) (done_bytes_p+1);
            FileCopyFlags* inverse_flags_p = (copy_flags_p+1);
            *copy_flags_p = ((deref_links ? 0 : FileCopyFlags.NOFOLLOW_SYMLINKS)
                             | FileCopyFlags.ALL_METADATA);
            *inverse_flags_p = 0;


            FileProgressCallback progress_cb = (cur, tot) => {
                double fraction = (*done_bytes_p + cur) / ((double) total_size_in_bytes) ;
                progress_bar.fraction = fraction;
            };


            int idx = 0;
            foreach (var file in files) {
                yield get_on_with_it (file, dest.get_child(file.get_basename()),
                                      move, done_bytes_p, copy_flags_p, inverse_flags_p,
                                      cancellable, progress_cb);
                try {
					var finfo = file_infos[idx];
	                *done_bytes_p += finfo.get_size ();
	            } catch {
		            // It doesn't really matter if this fails.
	            }
	            
                progress_cb (0, 0); // update progress bar

                if (cancellable.is_cancelled()) {
                    break;
                }

                idx++;
            }
            
            active = false;

            dialog.destroy ();
            application.release ();

            free((void*)done_bytes_p);

            var main_window = application.main_window;

            // update listings.
            yield main_window.left_pane.refresh ();
            yield main_window.right_pane.refresh ();
        }

        private string? ask_for_new_name (string old_name)
        {
            var dialog = new InputDialog (_("Change name"), application.main_window);
            dialog.add_button (Stock.CANCEL, ResponseType.CANCEL);
            dialog.add_button (Stock.OK, ResponseType.OK, true);
            dialog.add_text (_("Rename “%s” to:").printf(old_name));
            dialog.add_entry ("name", old_name, true);
            
            string new_filename = null;

            dialog.decisive_response.connect ((id) => {
                    if (id == Gtk.ResponseType.OK) {
                        new_filename = dialog.get_text("name");
                    }
                    return false;
                });

            dialog.run ();

            return new_filename;
        }

        private async void get_on_with_it (File file, File dest, bool move,
                                           uint64* done_bytes_p,
                                           FileCopyFlags* copy_flags_p, 
                                           FileCopyFlags* inverse_flags_p,
                                           Cancellable cancellable,
                                           FileProgressCallback progress_cb)
        {
            try {
                yield get_on_with_it_real (file, dest, move,
                            done_bytes_p, copy_flags_p, inverse_flags_p,
                            cancellable, progress_cb);
            } catch (Error e) {
                if (cancellable.is_cancelled()) {
                    return;
                }

                var err_msg = new MessageDialog (application.main_window,
                    DialogFlags.MODAL, MessageType.ERROR, ButtonsType.NONE,
                    move ? _("Error moving file “%s”.")
                         : _("Error copying file “%s”."),
                    file.get_parse_name());
                err_msg.secondary_text = e.message;
                err_msg.add_button (Stock.STOP, ResponseType.CLOSE);
                err_msg.add_button (_("Skip"), 2);
                err_msg.add_button (_("Retry"), 1);
                err_msg.set_default_response (1);
                
                bool retry = false;

                err_msg.response.connect ((id) => {
                        switch (id) {
                        case 1: // Retry.
                            retry = true;
                            break;
                        case ResponseType.CLOSE:
                            cancellable.cancel ();
                            break;
                        default: // Skip.
                            break;
                        }
                        err_msg.destroy ();
                    });

                err_msg.run ();

                if (retry) {
                    yield get_on_with_it (file, dest, move,
                                done_bytes_p, copy_flags_p, inverse_flags_p,
                                cancellable, progress_cb);
                }
            }
        }


        private async void get_on_with_it_real (File file, File dest, bool move,
                                                uint64* done_bytes_p,
                                                FileCopyFlags* copy_flags_p, 
                                                FileCopyFlags* inverse_flags_p,
                                                Cancellable cancellable,
                                                FileProgressCallback progress_cb)
                throws Error
        {
            string? new_name = null;

            FileQueryInfoFlags query_flags = 0;
            if ((*copy_flags_p & FileCopyFlags.NOFOLLOW_SYMLINKS) != 0) {
                query_flags |= FileQueryInfoFlags.NOFOLLOW_SYMLINKS;
            }
            var in_type = file.query_file_type (query_flags);
            var out_type = dest.query_file_type (query_flags);

            string in_fs_id, out_fs_id;
            try {
                var in_fs_info = yield file.query_filesystem_info_async (
                                        FILE_ATTRIBUTE_ID_FILESYSTEM,
                                        Priority.DEFAULT, cancellable);
                in_fs_id = in_fs_info.get_attribute_string (FILE_ATTRIBUTE_ID_FILESYSTEM);
            } catch (Error e1) {
                in_fs_id = "__in__";
            }

            try {
                var out_fs_info = yield file.query_filesystem_info_async (
                                        FILE_ATTRIBUTE_ID_FILESYSTEM,
                                        Priority.DEFAULT, cancellable);
                out_fs_id = out_fs_info.get_attribute_string (FILE_ATTRIBUTE_ID_FILESYSTEM);
            } catch (Error e2) {
                out_fs_id = "__out__";
            }

            var dest_exists = false;
            if ((dest_exists = dest.query_exists(cancellable))) {
                // Overwrite?
                if ((*inverse_flags_p & FileCopyFlags.OVERWRITE) != 0) {
                    // No, do not overwrite.
                    return;
                }

                bool do_overwrite = true;

                if (in_type == FileType.DIRECTORY && out_type == FileType.DIRECTORY
                     && (*copy_flags_p & FileCopyFlags.OVERWRITE) == 0
                     && (*inverse_flags_p & FileCopyFlags.OVERWRITE) == 0) {

                    var merge_dialog = new MessageDialog (application.main_window,
                        DialogFlags.MODAL, MessageType.WARNING, ButtonsType.NONE,
                        _("Directory “%s” exists. Merge directories?"),
                        dest.get_basename());
                    merge_dialog.add_button (Stock.STOP, ResponseType.CLOSE);
                    merge_dialog.add_button (_("Skip All"), 4);
                    merge_dialog.add_button (_("Overwrite All"), 2);
                    merge_dialog.add_button (_("Rename"), 0);
                    merge_dialog.add_button (_("Skip"), 3);
                    merge_dialog.add_button (_("Merge"), 1);
                    merge_dialog.set_default_response (0);
                    merge_dialog.response.connect ((id) => {
                            merge_dialog.destroy ();
                            switch (id) {
                            case 0: // Rename.
                                new_name = ask_for_new_name (dest.get_basename());
                                do_overwrite = false;
                                break;
                            case 1: // Merge this.
                                // Do nothing special. do_overwrite == true anyway. Proceed.
                                break;
                            case 2: // Overwrite all.
                                // Set the copy flags.
                                *copy_flags_p |= FileCopyFlags.OVERWRITE;
                                break;
                            case ResponseType.NONE:
                            case ResponseType.DELETE_EVENT:
                            case 3: // Skip.
                                // Skip this, proceed.
                                *inverse_flags_p |= FileCopyFlags.OVERWRITE;
                                do_overwrite = false;
                                break;
                            case 4: // Skip All
                                do_overwrite = false;
                                break;
                            case ResponseType.CLOSE:
                                // Abort altogether.
                                cancellable.cancel ();
                                do_overwrite = false;
                                break;
                            }
                        });
                    merge_dialog.run ();

                } else if (in_type != FileType.DIRECTORY && out_type != FileType.DIRECTORY
                     && (*copy_flags_p & FileCopyFlags.OVERWRITE) == 0
                     && (*inverse_flags_p & FileCopyFlags.OVERWRITE) == 0) {

                    var owr_dialog = new MessageDialog (application.main_window,
                        DialogFlags.MODAL, MessageType.WARNING, ButtonsType.NONE,
                        _("File “%s” exists. Overwrite file?"),
                        dest.get_basename());
                    owr_dialog.add_button (Stock.STOP, ResponseType.CLOSE);
                    owr_dialog.add_button (_("Skip All"), 4);
                    owr_dialog.add_button (_("Overwrite All"), 2);
                    owr_dialog.add_button (_("Rename"), 0);
                    owr_dialog.add_button (_("Skip"), 3);
                    owr_dialog.add_button (_("Overwrite"), 1);
                    owr_dialog.set_default_response (0);
                    owr_dialog.response.connect ((id) => {
                            owr_dialog.destroy ();
                            switch (id) {
                            case 0: // Rename.
                                new_name = ask_for_new_name (dest.get_basename());
                                do_overwrite = false;
                                break;
                            case 1: // Merge this.
                                // Do nothing special. do_overwrite == true anyway. Proceed.
                                break;
                            case 2: // Overwrite all.
                                // Set the copy flags.
                                *copy_flags_p |= FileCopyFlags.OVERWRITE;
                                break;
                            case ResponseType.NONE:
                            case ResponseType.DELETE_EVENT:
                            case 3: // Skip.
                                // Skip this, proceed.
                                *inverse_flags_p |= FileCopyFlags.OVERWRITE;
                                do_overwrite = false;
                                break;
                            case 4: // Skip All
                                do_overwrite = false;
                                break;
                            case ResponseType.CLOSE:
                                // Abort altogether.
                                cancellable.cancel ();
                                do_overwrite = false;
                                break;
                            }
                        });
                    owr_dialog.run ();

                } else if (in_type == FileType.DIRECTORY && out_type != FileType.DIRECTORY) {

                    show_error_message_dialog (application.main_window,
                           _("Cannot overwrite file with directory"),
                           _("Attempting to copy a directory to “%s”, but there is a file at that location. You may change the directory's name."));

                   new_name = ask_for_new_name (dest.get_basename());
                   do_overwrite = false;

                } else if (in_type != FileType.DIRECTORY && out_type == FileType.DIRECTORY) {

                    show_error_message_dialog (application.main_window,
                           _("Cannot overwrite directory with file"),
                           _("Attempting to copy a file to “%s”, but there is a directory at that location. You may change the file's name."));

                   new_name = ask_for_new_name (dest.get_basename());
                   do_overwrite = false;

                }

                if (!do_overwrite) {
                    if (new_name != null) {
                        yield get_on_with_it (file,
                            dest.get_parent().get_child(new_name),
                            move, done_bytes_p, copy_flags_p, inverse_flags_p,
                            cancellable, progress_cb);
                    }
                    return;
                }
            }

            // use overwrite by default here: the above code makes sure that that's intended.
            FileCopyFlags copy_flags = (*copy_flags_p & (~*inverse_flags_p)) 
                                        | FileCopyFlags.OVERWRITE;

            if (in_type == FileType.DIRECTORY) {
                if (move && !dest_exists) {
                    // Attempt moving the directory.
                    try {
                        if (file.move (dest, copy_flags, cancellable, progress_cb)) {
                            // Done for this file:
                            return;
                        }
                    } catch (Error e3) {
                        // if this fails, we simply IGNORE. It's not that important.
                    }
                }

                if (!dest_exists) {
                    dest.make_directory (cancellable);
                    try {
                        file.copy_attributes (dest, copy_flags, cancellable);
                    } catch (Error e4) {
                        // if this fails, we simply IGNORE. It's not that important.
                    }
                }

                var enumerator = yield file.enumerate_children_async (
                                            FILE_ATTRIBUTE_STANDARD_SIZE + ","
                                                + FILE_ATTRIBUTE_STANDARD_NAME,
                                            query_flags);
                GLib.List<FileInfo> fileinfos;
                while ((fileinfos = yield enumerator.next_files_async (20)) != null) {
                    foreach (var finfo in fileinfos) {
                        var child_file = file.get_child (finfo.get_name());
                        var child_dest = dest.get_child (finfo.get_name());

                        yield get_on_with_it (child_file, child_dest, move,
                                        done_bytes_p, copy_flags_p, inverse_flags_p,
                                        cancellable, progress_cb);


                        *done_bytes_p += finfo.get_size ();
                    }
                }

                if (move) {
                    // after merging (or moving file by file), delete original.
                    // It should be empty.
                    file.@delete (cancellable);
                }

            } else {
                if (move && in_fs_id == out_fs_id) {
                    // only use the move method when we're on the same file system.
                    // It works when we're not, but it might take a while, so it's
                    // better to use the async copy method below.
                    file.move (dest, copy_flags, cancellable, progress_cb);
                } else {
                    if (in_type == FileType.SYMBOLIC_LINK) {

                        /* This fact implies NOFOLLOW_SYMLINKS.
                           Some VFS (notably, GVfs SFTP and FTP) might still
                           dereference the link on copy.
                           Ergo, to be on the safe side, create the new link
                           manually. */

                        var in_info = yield file.query_info_async (
                                        FILE_ATTRIBUTE_STANDARD_SYMLINK_TARGET,
                                        FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                                        Priority.DEFAULT, cancellable);
                        var symlink_target = in_info.get_symlink_target ();
                        if (dest_exists) {
                            dest.@delete (cancellable);
                        }
                        dest.make_symbolic_link (symlink_target, cancellable);

                    } else {

                        yield file.copy_async (dest, copy_flags, Priority.DEFAULT,
                                               cancellable, progress_cb);

                        if (move) {
                            file.@delete (cancellable);
                        }

                    }
                }
            }
        }

    }

}

public void load_module (ModuleRegistry reg)
{
    Emperor.Modules.FileTransfersModule.register (reg);
}

