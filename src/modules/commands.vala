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
using Emperor;
using Emperor.Application;

namespace Emperor.Modules {

    public class CommandsModule : Object
    {
        public static void register (ModuleRegistry reg)
        {
            Gtk.Action action;

            var app = reg.application;
            var module = new CommandsModule (app);

            // F2: Rename.
            action = reg.new_action ("rename");
            action.label = _("Rename");
            action.set_accel_path ("<Emperor-Main>/Commands/Rename");
            Gtk.AccelMap.add_entry ("<Emperor-Main>/Commands/Rename",
                                    Gdk.KeySym.F2, 0);
            action.activate.connect ( () => { module.do_rename.begin (); } );
            action.connect_accelerator ();
            app.ui_manager.add_action_to_menu (_("_File"), action);

            // F3: View.
            action = reg.new_action ("view");
            action.label = _("View");
            action.set_accel_path ("<Emperor-Main>/Commands/View");
            Gtk.AccelMap.add_entry ("<Emperor-Main>/Commands/View",
                                    Gdk.KeySym.F3, 0);
            action.activate.connect ( () => { module.open_files (AppManager.FileAction.VIEW); } );
            action.connect_accelerator ();
            app.ui_manager.add_action_to_menu (_("_File"), action);

            // F4: Edit.
            action = reg.new_action ("edit");
            action.label = _("Edit");
            action.set_accel_path ("<Emperor-Main>/Commands/Edit");
            Gtk.AccelMap.add_entry ("<Emperor-Main>/Commands/Edit",
                                    Gdk.KeySym.F4, 0);
            action.activate.connect ( () => { module.open_files (AppManager.FileAction.EDIT); } );
            action.connect_accelerator ();
            app.ui_manager.add_action_to_menu (_("_File"), action);

        }

        public CommandsModule (EmperorCore app)
        {
            Object ( application : app );
        }

        public EmperorCore application { get; construct; }

        private async void do_rename ()
        {
            var pane = application.main_window.active_pane;
            var path = pane.cursor_path;
            if (path == null) {
                return;
            }
            var fileinfo = pane.get_fileinfo (path);
            if (fileinfo.get_display_name() == "..") {
                return;
            }
            var file = pane.pwd.get_child (fileinfo.get_name());

            try {
                fileinfo = yield file.query_info_async (
                                    FILE_ATTRIBUTE_STANDARD_EDIT_NAME,
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
            dialog.add_button (Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL);
            dialog.add_button (_("Rename"), Gtk.ResponseType.OK, true);
            dialog.add_text (_("Rename “%s” to:").printf(filename));
            dialog.add_entry ("name", filename, true);

            dialog.response.connect ((id) => {
                    if (id == Gtk.ResponseType.OK) {
                        var new_filename = dialog.get_text("name");
                        try {
                            file.set_display_name (new_filename);
                            pane.update_line (path, pane.pwd.get_child(new_filename));
                            return false;
                        } catch (Error err2) {
                            show_error_message_dialog (dialog.dialog,
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

        private void open_files (AppManager.FileAction how)
        {
            var pane = application.main_window.active_pane;
            var files = pane.get_selected_files ();

            if (files.length() == 0) {
                pane.display_error (_("No files selected."));
                return;
            }

            foreach (var file in files) {
                var launch = application.external_apps.get_specific_for_file (file, how,true, true);
                var flst = new GLib.List<File> ();
                flst.append (file);
                launch (flst);
            }
        }
    }
}

public void load_module (ModuleRegistry reg)
{
    Emperor.Modules.CommandsModule.register (reg);
}

