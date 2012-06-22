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
                                    Gdk.KeySym.F9, 0);
            action.activate.connect ( () => { module.do_open_term.begin (); } );
            action.connect_accelerator ();
            app.ui_manager.add_action_to_menu (_("_File"), action, 80);

            // Does Meld exist?
            if (module.meld_appinfo != null) {
                // Run Meld.
                action = reg.new_action ("runmeld");
                action.label = _("Compare directories with Meld");
                action.activate.connect ( () => { module.do_run_meld.begin (); } );
                app.ui_manager.add_action_to_menu (_("_View"), action, 80);
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

            // TODO: Use user's default terminal!
            var term_app = new DesktopAppInfo ("gnome-terminal.desktop");

            var real_cwd = Environment.get_current_dir ();
            var dir_path = pwd.get_path ();
            if (dir_path != null) {
                Environment.set_current_dir (dir_path);
            }
            if (term_app != null) {
                try {
                    term_app.launch(null, null);
                } catch {
                    pane.display_error (_("Failed to launch terminal! How very odd."));
                }
            } else {
                pane.display_error (_("Oh, bother! Gnome-Terminal is missing."));
            }

            Environment.set_current_dir (real_cwd);
        }

        public async void do_run_meld ()
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

    }
}


public void load_module (ModuleRegistry reg)
{
    Emperor.Modules.ExternalistModule.register (reg);
}


