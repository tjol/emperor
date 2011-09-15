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
using Emperor.Application;

namespace Emperor.Modules {

    public class NetMenuModule : Object
    {
        public static void register (ModuleRegistry reg)
        {
            Gtk.Action action;

            var app = reg.application;
            var module = new NetMenuModule (app);

            app.ui_manager.get_menu (_("_Net"), 7);

            // Browse network
            action = reg.new_action ("netmenu/browse");
            action.label = _("Browse Network");
            action.icon_name = "network-workgroup";
            action.activate.connect (module.browse_network);
            app.ui_manager.add_action_to_menu (_("_Net"), action, 1);

            module.@ref ();
        }

        public NetMenuModule (EmperorCore app)
        {
            Object ( application : app );
        }

        public EmperorCore application { get; construct; }

        public void browse_network ()
        {
            application.main_window.active_pane.pwd = File.new_for_uri ("network:///");
        }

    }
}

public void load_module (ModuleRegistry reg)
{
    Emperor.Modules.NetMenuModule.register (reg);
}

