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
            var app = reg.application;
            var module = new CommandsModule (app);

            /* Increase the reference count:
               Passing a delegate to a method loses all reference information.
               The CommandsModule would otherwise be deallocated. */
            module.@ref ();
            reg.register_command ("rename", module.rename);
        }

        public CommandsModule (EmperorCore app)
        {
            Object ( application : app );
        }

        public EmperorCore application { get; construct; }

        public void rename (string[] args)
        {
            do_rename.begin ();
        }

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
                    "Error fetching file information.",
                    err1.message);
                return;
            }

            //stdout.printf ("rename file: %s\n", fileinfo.get_edit_name());
            var filename = fileinfo.get_edit_name ();

            var dialog = new InputDialog ("Rename file", application.main_window);
            dialog.add_button (Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL);
            dialog.add_button ("Rename", Gtk.ResponseType.OK, true);
            dialog.add_text ("Rename “%s” to:".printf(filename));
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
                                    "Error renaming file.",
                                    err2.message);
                            return true;
                        }
                    } else {
                        return false;
                    }
                });

            dialog.run ();
        }
    }
}

public void load_module (ModuleRegistry reg)
{
    Emperor.Modules.CommandsModule.register (reg);
}

