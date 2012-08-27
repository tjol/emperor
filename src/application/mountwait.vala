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

namespace Emperor.Application {

    public interface IWaitingForMount : Object {
        public abstract Cancellable go ();
        public abstract void done ();
    }

#if HAVE_LIBNOTIFY
    public IWaitingForMount
    new_waiting_for_mount (Gtk.Window wnd, Cancellable? cancellable=null)
    {
        // Do we want to use libnotify for this?
        if (Notify.is_initted ()) {
            unowned GLib.List<string> caps = (GLib.List<string>) Notify.get_server_caps();
            bool has_actions = false;
            foreach (string cap in caps) {
                if (cap == "actions") {
                    has_actions = true;
                    break;
                }
            }
            if (has_actions) {
                // Server supports actions.
                // Thankfully, notify-OSD doesn't list its (crappy) support.
                return new WaitingForMountNotify (wnd, cancellable);
            }
        }

        // fall-back.
        return new WaitingForMountDialog (wnd, cancellable);
    }
#else
    public WaitingForMountIface
    new_waiting_for_mount (Gtk.Window wnd, Cancellable? cancellable=null)
    {
        return new WaitingForMountDialog (wnd, cancellable);
    }
#endif

}
