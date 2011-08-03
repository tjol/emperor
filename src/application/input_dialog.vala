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

namespace Emperor.Application {

    public class InputDialog : Object
    {
        Box m_box;
        Map<string,Widget> m_inputs;
        Widget m_focus_widget;
        Dialog m_dialog;

        public Dialog dialog {
            get {
                return m_dialog;
            }
        }

        // default flags: MODAL | DESTROY_WITH_PARENT == 0x3
        public InputDialog (string title, Window? parent, DialogFlags flags=0x3)
        {
            m_dialog = new Dialog.with_buttons (title, parent, flags);
            m_box = (Box) m_dialog.get_content_area();
            m_inputs = new HashMap<string,Widget> ();
            m_focus_widget = null;
            m_dialog.map_event.connect (on_map);
            m_dialog.response.connect ((id) => {
                    bool keep_dialog = this.response (id); 
                    if (!keep_dialog) {
                        m_dialog.destroy ();
                    }
                });

            m_dialog.default_width = 400;
            m_box.margin = 10;
        }

        public void pack_start (Widget widget, bool expand=true, bool fill=true,
                                               uint padding=0)
        {
            m_box.pack_start (widget, expand, fill, padding);
        }

        public void pack_end (Widget widget, bool expand=true, bool fill=true,
                                             uint padding=0)
        {
            m_box.pack_end (widget, expand, fill, padding);
        }

        public void add_markup (string message)
        {
            var label = new Label (null);
            label.set_markup (message);
            label.halign = Align.START;
            pack_start (label, false, true, 10);
        }

        public void add_text (string message)
        {
            var label = new Label (null);
            label.set_text (message);
            label.halign = Align.START;
            pack_start (label, false, true, 10);
        }
 
        public void add_input (string name, Widget widget, bool focus=false)
        {
            pack_start (widget, false, true, 10);
            m_inputs[name] = widget;
            if (focus) {
                m_focus_widget = widget;
            }
        }

        public void add_entry (string name, string text, bool focus=false)
        {
            var entry = new Entry ();
            entry.text = text;
            entry.activates_default = true;
            add_input (name, entry, focus);
        }

        public new Widget? get (string name)
        {
            return m_inputs[name];
        }

        public string? get_text (string name)
        {
            var widget = m_inputs[name];
            if (widget is Entry) {
                return ((Entry) widget).text;
            } else {
                return null;
            }
        }

        public void run ()
        {
            m_dialog.run ();
        }

        public unowned Widget add_button (string button_text, int response_id,
                                          bool default_action=false)
        {
            unowned Widget w = m_dialog.add_button (button_text, response_id);
            if (default_action) {
                m_dialog.set_default_response (response_id);
            }
            return w;
        }

        /**
         * Signal return value:
         * true  => keep dialog (e.g. for further input)
         * false => destroy dialog.
         */
        public signal bool response (int response_id);

        private bool on_map (Gdk.Event e)
        {
            stdout.printf("dialog mapped.\n");
            m_dialog.show_all ();
            if (m_focus_widget != null) {
                m_focus_widget.grab_focus ();
            }
            return false;
        }
    }

    public static void show_error_message_dialog (Window? parent, string msg1, string? msg2)
    {
        var errormsg = new Gtk.MessageDialog (
            parent,
            Gtk.DialogFlags.MODAL,
            Gtk.MessageType.ERROR,
            Gtk.ButtonsType.OK,
            msg1);
        if (msg2 != null) {
            errormsg.secondary_text = msg2;
        }
        errormsg.response.connect((id) => { errormsg.destroy (); });
        errormsg.run ();
    }

}

