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
using Emperor;
using Emperor.Application;

namespace Emperor.Modules {

    public class ExternalistModule : Object
    {
        public static void register (ModuleRegistry reg)
        {
            var app = reg.application;
            var module = new ExternalistModule (app);

            Gtk.Action action;

            // Ensure menu exists.
            app.ui_manager.get_menu (_("_File"), 0);
            app.ui_manager.get_menu (_("_View"), 2);

            // F9: Open Terminal.
            action = reg.new_action ("openterm");
            action.label = _("Open Terminal");
            action.set_accel_path ("<Emperor-Main>/BasicActions/OpenTerm");
            Gtk.AccelMap.add_entry ("<Emperor-Main>/BasicActions/OpenTerm",
                                    Gdk.Key.F9, 0);
            action.activate.connect ( () => { module.do_open_term.begin (); } );
            action.connect_accelerator ();
            app.ui_manager.add_action_to_menu (_("_File"), action, 80);

            // Does Meld exist?
            if (module.meld_appinfo != null) {
                // Meld Directories.
                action = reg.new_action ("melddirs");
                action.label = _("Compare directories with Meld");
                action.activate.connect ( () => { module.do_run_meld_dirs.begin (); } );
                app.ui_manager.add_action_to_menu (_("_View"), action, 80);

                // Meld Files.
                action = reg.new_action ("meldfiles");
                action.label = _("Compare files with Meld");
                action.activate.connect ( () => { module.do_run_meld_files.begin (); } );
                app.ui_manager.add_action_to_menu (_("_View"), action, 81);
            }
        }

        public ExternalistModule (EmperorCore app)
        {
            Object ( application : app,
                     meld_appinfo : new DesktopAppInfo ("meld.desktop") );
        }

        public EmperorCore application { get; construct; }

        public AppInfo? meld_appinfo { get; construct; }

        public async void do_open_term ()
        {
            var pane = application.main_window.active_pane;
            var pwd = pane.pwd;

            var dir_path = pwd.get_path ();
            if (dir_path == null) {
                dir_path = Environment.get_current_dir ();
            }

            // find terminal to use.
            // check GSettings system:
            var term_settings = new GLib.Settings ("org.gnome.desktop.default-applications.terminal");
            var preferred_term = term_settings.get_string ("exec");
            var argv = new string[1];

            Pid pid;
            try {
                argv[0] = preferred_term;
                Process.spawn_async (dir_path, argv, null, SpawnFlags.SEARCH_PATH, null, out pid);
            } catch {
                try {
                    argv[0] = "xterm";
                    Process.spawn_async (dir_path, argv, null, SpawnFlags.SEARCH_PATH, null, out pid);
                } catch {
                    pane.display_error (_("Failed to launch xterm! How very odd."));
                }
            }
        }

        public async void do_run_meld_dirs ()
        {
            var pane1 = application.main_window.active_pane;
            var pane2 = application.main_window.passive_pane;

            var dirs = new GLib.List<File> ();
            dirs.append (pane1.pwd);
            dirs.append (pane2.pwd);

            try {
                meld_appinfo.launch (dirs, null);
            } catch (Error err) {
                show_error_message_dialog (application.main_window,
                    _("Failed to launch Meld! What a mess."), err.message);
            }
        }

        public async void do_run_meld_files ()
        {
            var pane1 = application.main_window.active_pane;
            var pane2 = application.main_window.passive_pane;

            var files = new GLib.List<File> ();
            GLib.List<File> selected;
            // get selected file in active pane:
            var cursor_file = pane1.get_file_at_cursor ();
            if (cursor_file == null) {
                selected = pane1.get_selected_files ();
                if (selected.length () == 0) {
                    return;
                }
                cursor_file = selected.nth_data (0);
            }
            files.append (cursor_file);
            // passive pane:
            selected = pane2.get_selected_files ();
            if (selected.length () == 0) {
                return;
            }
            files.append (selected.nth_data (0));

            try {
                meld_appinfo.launch (files, null);
            } catch (Error err) {
                show_error_message_dialog (application.main_window,
                    _("Failed to launch Meld! What a mess."), err.message);
            }
        }

    }
}


public void load_module (ModuleRegistry reg)
{
    Emperor.Modules.ExternalistModule.register (reg);
}


