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
using Emperor;
using Emperor.App;

namespace Emperor.Modules {

    public class BasicActionsModule : Object
    {
        public static void register (ModuleRegistry reg)
        {
            Gtk.Action action;

            var app = reg.application;
            var module = new BasicActionsModule (app);

            app.ui_manager.get_menu (_("_File"), 0);

            // F2: Rename.
            action = reg.new_action ("rename");
            action.label = _("Rename");
            action.set_accel_path ("<Emperor-Main>/BasicActions/Rename");
            Gtk.AccelMap.add_entry ("<Emperor-Main>/BasicActions/Rename",
                                    Gdk.Key.F2, 0);
            action.activate.connect ( () => { module.do_rename.begin (); } );
            action.connect_accelerator ();
            app.ui_manager.add_action_to_menu (_("_File"), action, 40);

            // F3: View.
            action = reg.new_action ("view");
            action.label = _("View");
            action.set_accel_path ("<Emperor-Main>/BasicActions/View");
            Gtk.AccelMap.add_entry ("<Emperor-Main>/BasicActions/View",
                                    Gdk.Key.F3, 0);
            action.activate.connect ( () => { module.open_files (AppManager.FileAction.VIEW); } );
            action.connect_accelerator ();
            app.ui_manager.add_action_to_menu (_("_File"), action, 20);

            // F4: Edit.
            action = reg.new_action ("edit");
            action.label = _("Edit");
            action.set_accel_path ("<Emperor-Main>/BasicActions/Edit");
            Gtk.AccelMap.add_entry ("<Emperor-Main>/BasicActions/Edit",
                                    Gdk.Key.F4, 0);
            action.activate.connect ( () => { module.open_files (AppManager.FileAction.EDIT); } );
            action.connect_accelerator ();
            app.ui_manager.add_action_to_menu (_("_File"), action, 21);

            // F7: Mkdir.
            action = reg.new_action ("mkdir");
            action.label = _("New directory");
            action.icon_name = "folder-new";
            action.set_accel_path ("<Emperor-Main>/BasicActions/Mkdir");
            Gtk.AccelMap.add_entry ("<Emperor-Main>/BasicActions/Mkdir",
                                    Gdk.Key.F7, 0);
            action.activate.connect ( () => { module.do_mkdir.begin (); } );
            action.connect_accelerator ();
            app.ui_manager.add_action_to_menu (_("_File"), action, 10);

            // F8: Delete.
            action = reg.new_action ("delete");
            action.label = _("Delete");
            action.set_accel_path ("<Emperor-Main>/BasicActions/Delete");
            Gtk.AccelMap.add_entry ("<Emperor-Main>/BasicActions/Delete",
                                    Gdk.Key.F8, 0);
            action.activate.connect ( () => { module.do_delete.begin (); } );
            action.connect_accelerator ();
            app.ui_manager.add_action_to_menu (_("_File"), action, 69);

            // Ctrl+Q: Quit.
            action = reg.new_action ("quit");
            action.stock_id = Stock.QUIT;
            action.set_accel_path ("<Emperor-Main>/BasicActions/Quit");
            Gtk.AccelMap.add_entry ("<Emperor-Main>/BasicActions/Quit",
                                    Gdk.Key.Q, Gdk.ModifierType.CONTROL_MASK);
            action.activate.connect ( () => { 
                    app.main_window.destroy ();
                } );
            action.connect_accelerator ();
            app.ui_manager.add_action_to_menu (_("_File"), action, 99);

            // Ctrl+R: Refresh
            action = reg.new_action ("refresh");
            action.label = _("Reload directories");
            action.icon_name = "view-refresh";
            action.set_accel_path ("<Emperor-Main>/BasicActions/Refresh");
            Gtk.AccelMap.add_entry ("<Emperor-Main>/BasicActions/Refresh",
                                    Gdk.Key.R, Gdk.ModifierType.CONTROL_MASK);
            action.activate.connect ( () => { 
                    app.main_window.active_pane.refresh.begin ();
                    app.main_window.passive_pane.refresh.begin ();
                } );
            app.ui_manager.add_action_to_menu (_("_View"), action, 70);
            action.connect_accelerator ();

        }

        public BasicActionsModule (EmperorCore app)
        {
            Object ( application : app );
        }

        public EmperorCore application { get; construct; }

        private async void do_rename ()
        {
            var pane = application.main_window.active_pane;
            var file = pane.get_file_at_cursor ();
            if (file == null || file.equal(pane.parent_dir)) {
                return;
            }

            FileInfo fileinfo;
            try {
                fileinfo = yield file.query_info_async (
                                    FileAttribute.STANDARD_EDIT_NAME,
                                    FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
            } catch (Error err1) {
                show_error_message_dialog (application.main_window,
                    _("Error fetching file information."),
                    err1.message);
                return;
            }

            //stdout.printf ("rename file: %s\n", fileinfo.get_edit_name());
            var filename = fileinfo.get_edit_name ();

            var dialog = new InputDialog (_("Rename file"), application.main_window);
            dialog.add_button (Stock.CANCEL, ResponseType.CANCEL);
            dialog.add_button (_("Rename"), ResponseType.OK, true);
            dialog.add_text (_("Rename “%s” to:").printf(filename));
            dialog.add_entry ("name", filename, true);

            dialog.decisive_response.connect ((id) => {
                    if (id == ResponseType.OK) {
                        var new_filename = dialog.get_text("name");
                        try {
                            file.set_display_name (new_filename);
                            pane.update_file (file, pane.pwd.get_child(new_filename));
                            return false;
                        } catch (Error err2) {
                            show_error_message_dialog (dialog,
                                    _("Error renaming file."),
                                    err2.message);
                            return true;
                        }
                    } else {
                        return false;
                    }
                });

            dialog.run ();
        }

        private async void do_mkdir ()
        {
            var pane = application.main_window.active_pane;
            var pwd = pane.pwd;

            var dialog = new InputDialog (_("New directory"), application.main_window);
            dialog.add_button (Stock.CANCEL, ResponseType.CANCEL);
            dialog.add_button (Stock.OK, ResponseType.OK, true);
            dialog.add_text (_("Create new directory in “%s” named").printf(pwd.get_parse_name()));
            dialog.add_entry ("name", "", true);

            dialog.decisive_response.connect ((id) => {
                    if (id == ResponseType.OK) {
                        var dirname = dialog.get_text("name");
                        var dirfile = pwd.get_child(dirname);
                        try {
                            dirfile.make_directory ();
                            pane.update_file (dirfile);
                            return false;
                        } catch (Error err) {
                            show_error_message_dialog (dialog,
                                    _("Error creating directory."),
                                    err.message);
                            return true;
                        }
                    } else {
                        return false;
                    }
                });

            dialog.run ();
        }

        private async void do_delete ()
        {
            var pane = application.main_window.active_pane;
            var files = pane.get_selected_files ();

            var n_files = files.length ();
            string fname = null;
            if (n_files == 0) {
                pane.display_error (_("No files selected."));
                return;
            } else if (n_files == 1) {
                fname = files.nth_data(0).get_basename();
            }

            var confirmation_dialog = new MessageDialog (application.main_window,
                DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.YES_NO,
                (n_files == 1) ? _("Really delete “%s”?").printf(fname)
                               : _("Really delete %u files?").printf(n_files));
            confirmation_dialog.secondary_text = _("This cannot be undone.");
            confirmation_dialog.set_default_response (ResponseType.YES);

            bool do_delete = false;
            confirmation_dialog.response.connect ((id) => {
                    if (id == ResponseType.YES) {
                        do_delete = true;
                    }
                    confirmation_dialog.destroy ();
                });

            confirmation_dialog.run ();

            if (!do_delete) {
                return;
            }

            bool* recurse_always_p = (bool*) malloc (2* sizeof(bool));
            bool* truth_p = recurse_always_p + 1;
            *recurse_always_p = false;
            *truth_p = true;

            var cancellable = new Cancellable ();

            foreach (var file in files) {
                yield delete_file (file, recurse_always_p, truth_p, cancellable);
            }

            free ((void*) recurse_always_p);

            yield pane.refresh ();

        }

        private async void delete_file (File file, bool* recurse_always_p, bool* truth_p,
                                        Cancellable cancellable)
        {
            try {
                yield delete_file_real (file, recurse_always_p, truth_p, cancellable);
            } catch (Error e) {
                if (cancellable.is_cancelled()) {
                    return;
                }

                var err_msg = new MessageDialog (application.main_window,
                    DialogFlags.MODAL, MessageType.ERROR, ButtonsType.NONE,
                    _("Error deleting file “%s”."),
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
                    yield delete_file (file, recurse_always_p, truth_p, cancellable);
                }
            }
        }


        private async void delete_file_real (File file, bool* recurse_always_p, bool* truth_p,
                                             Cancellable cancellable)
            throws Error
        {
            if (cancellable.is_cancelled()) {
                return;
            }

            var ftype = file.query_file_type (FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

            if (ftype == FileType.DIRECTORY) {
                // do we always delete directories with their contents?
                if (! (*recurse_always_p)) {
                    // Check if the directory is empty
                    var enumerator = file.enumerate_children("", 0, cancellable);
                    if (enumerator.next_file(cancellable) != null) {
                        // ask.
                        var recurse_dialog = new MessageDialog (application.main_window,
                            DialogFlags.MODAL, MessageType.WARNING, ButtonsType.NONE,
                            _("Directory “%s” is not empty! Delete it and all its contents?"),
                            file.get_basename());
                        recurse_dialog.secondary_text = _("This cannot be undone.");
                        recurse_dialog.add_button (_("Always"), 1);
                        recurse_dialog.add_button (Stock.NO, ResponseType.NO);
                        recurse_dialog.add_button (Stock.YES, ResponseType.YES);
                        recurse_dialog.set_default_response (ResponseType.YES);
                        bool do_recurse = false;
                        recurse_dialog.response.connect ((id) => {
                                switch (id) {
                                case 1: // Always
                                    *recurse_always_p = true;
                                    do_recurse = true;
                                    break;
                                case ResponseType.YES:
                                    do_recurse = true;
                                    break;
                                }
                                recurse_dialog.destroy ();
                            });
                        recurse_dialog.run ();

                        if (!do_recurse) {
                            return;
                        }
                    }
                }

                // Delete everything in this directory.
                var children = yield file.enumerate_children_async (
                                        FileAttribute.STANDARD_NAME, 0,
                                        Priority.DEFAULT, cancellable);
                GLib.List<FileInfo> fileinfos;
                while ((fileinfos = yield children.next_files_async (20, Priority.DEFAULT,
                                            cancellable)) != null) {
                    foreach (var child_finfo in fileinfos) {
                        var child = file.get_child (child_finfo.get_name());
                        // Recurse fully, therefore: recurse if file is a directory.
                        yield delete_file (child, truth_p, truth_p, cancellable);
                    }
                }
            }

            // if it's a directory, it should now be empty. GERONIMO!
            file.delete (cancellable);
        }

        private void open_files (AppManager.FileAction how)
        {
            var pane = application.main_window.active_pane;
            var files = pane.get_selected_files ();

            if (files.length() == 0) {
                pane.display_error (_("No files selected."));
                return;
            }

            foreach (var file in files) {
                try {
                    var launch = application.external_apps.get_specific_for_file (
                                        file, how, true, true);
                    var flst = new GLib.List<File> ();
                    flst.append (file);
                    launch (flst);
                } catch (Error e) {
                    show_error_message_dialog (application.main_window,
                        _("Error opening file."),
                        e.message);
                }
            }
        }
    }
}

public void load_module (ModuleRegistry reg)
{
    Emperor.Modules.BasicActionsModule.register (reg);
}

