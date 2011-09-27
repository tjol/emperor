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

using Gdk;
using Gtk;

namespace Emperor.Application {

    internal class WaitingForMount : Object
    {
        Gtk.Window m_wnd;
        Cancellable m_cancellable;
        InputDialog m_dialog;
        bool m_done;

        internal WaitingForMount (Gtk.Window wnd, Cancellable? cancellable=null)
        {
            m_wnd = wnd;
            m_dialog = null;
            m_done = false;
            m_cancellable = cancellable;
        }

        private bool show_dialog ()
        {
            if (m_done || m_cancellable.is_cancelled()) {
                return false;
            }
            m_dialog = new InputDialog (_("Mounting"), m_wnd);
            m_dialog.deletable = false;
            m_dialog.resizable = false;
            m_dialog.add_button (Stock.CANCEL, ResponseType.CANCEL);
            m_dialog.add_text ("Please wait while the location is being mounted.");
            m_dialog.decisive_response.connect ((id) => {
                    if (id == ResponseType.CANCEL) {
                        m_cancellable.cancel ();
                        m_dialog.destroy ();
                        m_dialog = null;
                        return false;
                    }
                    return true;
                });
            m_dialog.show ();
            var cursor = new Cursor (CursorType.WATCH);
            m_dialog.get_window().set_cursor (cursor);
            return false;
        }

        internal Cancellable go ()
        {
            if (m_cancellable == null) {
                m_cancellable = new Cancellable ();
            }
            Timeout.add (1000, show_dialog);
            return m_cancellable;
        }

        internal void done ()
        {
            m_done = true;
            if (m_dialog != null) {
                m_dialog.destroy ();
                m_dialog = null;
            }
        }
    }

}

