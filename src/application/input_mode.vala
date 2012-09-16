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
using Gdk;

namespace Emperor.App {

    public interface InputMode : Object
    {
        public abstract bool handle_mouse_event (EventButton eb);
        public abstract bool handle_motion_event (EventMotion em);

        /**
         * Grab focus. You've deserved it.
         */
        public signal void focus ();

        /**
         * Move the cursor.
         */
        public signal void move_cursor_to (int x, int y);

        /**
         * Toggle selection at a particular position
         */
        public signal void toggle_selection_at (int x, int y);

        /**
         * Open a context menu
         */
        public signal void popup_menu_at (int x, int y);

        /**
         * Are the two places non-identical?
         *
         * Hint: use .connect_after
         */
        public signal bool is_different_file (int x1, int y1, int x2, int y2);

        /**
         * Activate a file. (double-click)
         */
        public signal void activate_file_at (int x, int y);

        /**
         * Select all files from the current cursor position to the position
         * indicated, inclusive. This is the received behaviour of shift-click
         * selection in left-click select user interfaces.
         */
        public signal void select_all_from_cursor_to (int x, int y);

        /**
         * Clear the selection
         */
        public signal void clear_selection ();
    }

    public class LeftSelectInputMode : Object, InputMode
    {
        public bool
        handle_mouse_event (EventButton eb)
        {
            var X = (int) eb.x;
            var Y = (int) eb.y;

            if (EventType.BUTTON_PRESS == eb.type) {
                switch (eb.button) {
                case 1:
                    // left click
                    if ((eb.state & ModifierType.CONTROL_MASK) != 0) {
                        // control-click
                        toggle_selection_at (X,Y);
                        move_cursor_to (X,Y);
                    } else if ((eb.state & ModifierType.SHIFT_MASK) != 0) {
                        // shift-click
                        select_all_from_cursor_to (X,Y);
                        move_cursor_to (X,Y);
                    } else {
                        // normal click
                        clear_selection ();
                        toggle_selection_at (X,Y);
                        move_cursor_to (X,Y);
                    }
                    focus ();
                    return true;
                case 3:
                    // right click
                    focus ();
                    popup_menu_at (X, Y);
                    return true;
                }
            } else if (EventType.2BUTTON_PRESS == eb.type) {
                // double click.
                activate_file_at (X, Y);
                return true;
            }

            return false;
        }

        public bool
        handle_motion_event (EventMotion em)
        {
            return false;
        }
    }

    public class RightSelectInputMode : Object, InputMode
    {

        int m_select_cache_x = -1;
        int m_select_cache_y = -1;

        Ref<bool> m_right_press_marker = null;

        public bool
        handle_mouse_event (EventButton eb)
        {
            var X = (int) eb.x;
            var Y = (int) eb.y;

            if (EventType.BUTTON_PRESS == eb.type) {
                switch (eb.button) {
                case 1:
                    // left click
                    move_cursor_to (X, Y);
                    focus ();
                    return true;
                case 3:
                    // right click
                    toggle_selection_at (X, Y);

                    // store current position for righ mouse drag selection.
                    m_select_cache_x = X;
                    m_select_cache_y = Y;

                    // This reference is changed when the button is newly pressed,
                    // set to false when it is released, and unset when one second
                    // has elapsed and the popup menu has been displayed.
                    var press_marker = new Ref<bool>(true);
                    m_right_press_marker = press_marker;
                    Timeout.add(1000, () => {
                            if (press_marker.val) {
                                // right mouse button was pressed for one second.
                                popup_menu_at (X, Y);
                            }
                            if (m_right_press_marker == press_marker) {
                                m_right_press_marker = null;
                            }
                            return false;
                        });
                    focus ();
                    return true;
                }
            } else if (EventType.2BUTTON_PRESS == eb.type) {
                // double click.
                activate_file_at (X, Y);
                return true;
            } else if (EventType.BUTTON_RELEASE == eb.type) {
                switch (eb.button) {
                case 3:
                    // right button released
                    if (null != m_right_press_marker) {
                        m_right_press_marker.val = false;
                        m_right_press_marker = null;
                    }
                    break;
                }
            }

            return false;
        }

        public bool
        handle_motion_event (EventMotion em)
        {
            var X = (int) em.x;
            var Y = (int) em.y;

            if ((em.state & ModifierType.BUTTON3_MASK) != 0) {
                // right-click drag! Cool! Do selection stuffs.
                if (m_select_cache_x >= 0 &&
                        m_select_cache_y >= 0 &&
                        is_different_file (X, Y, m_select_cache_x,
                                                 m_select_cache_y)) {
                    toggle_selection_at (X, Y);
                    m_select_cache_x = X;
                    m_select_cache_y = Y;
                    // This is now a drag, not a hold!
                    if (m_right_press_marker != null) {
                        m_right_press_marker.val = false;
                        m_right_press_marker = null;
                    }
                }
            }

            return false;
        }
    }
}
