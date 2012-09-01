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

using Notify;

namespace Emperor.App {

    internal class WaitingForMountNotify : Object, WaitingForMount
    {
        Gtk.Window m_wnd;
        Cancellable m_cancellable;
        Notification m_notification;
        bool m_done;

        internal WaitingForMountNotify (Gtk.Window wnd, Cancellable? cancellable=null)
        {
            m_wnd = wnd;
            m_notification = null;
            m_done = false;
            m_cancellable = cancellable;
        }

        private bool show_notification ()
        {
            if (m_done || m_cancellable.is_cancelled()) {
                return false;
            }
            m_notification = new Notification (_("Mounting"),
                                _("Please wait while the location is being mounted."),
                                "emperor-fm");
            m_notification.add_action ("cancel", _("Cancel"), (n,a) => {
                    m_cancellable.cancel ();
                    try {
                        m_notification.close ();
                    } catch (Error notification_error) {
                        warning (_("Error closing notification: %s"), notification_error.message);
                    }
                    m_notification = null;
                });
            try {
                m_notification.show ();
            } catch (Error notification_error) {
                warning (_("Error showing notification: %s"), notification_error.message);
            }
            return false;
        }

        internal Cancellable go ()
        {
            if (m_cancellable == null) {
                m_cancellable = new Cancellable ();
            }
            Timeout.add (1000, show_notification);
            return m_cancellable;
        }

        internal void done ()
        {
            m_done = true;
            if (m_notification != null) {
                try {
                    m_notification.close ();
                } catch (Error notification_error) {
                    warning (_("Error closing notification: %s"), notification_error.message);
                }
                m_notification = null;
            }
        }
    }

}


