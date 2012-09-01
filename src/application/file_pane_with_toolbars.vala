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
using Gee;
using Gtk;
using Gdk;

namespace Emperor.App {

    /**
     * Abstract class providing standard toolbar layout for file panes.
     * Implements UIFeedbackComponent.
     */
    public abstract class FilePaneWithToolbars : AbstractFilePane
    {
    	/* *****************************************************
    	 * INSTANCE VARIABLES
    	 ******************************************************/
    	protected Map<string,Widget> m_addon_toolbars;
    	protected Label m_error_message;
    	protected Widget m_error_message_bg;

        /* *****************************************************
         * SETUP CODE
         ******************************************************/
    	
        construct {
			// Add widget for displaying error messages.
            m_error_message = new Label ("");
            var error_message_bg = new EventBox ();
            m_error_message_bg = error_message_bg;
            m_error_message.margin = 10;
            m_error_message.wrap = true;
            var black = RGBA();
            black.parse("#000000");
            m_error_message.override_color (0, black);
            var red = RGBA();
            red.parse("#ff8888");
            error_message_bg.override_background_color (0, red);
            error_message_bg.add(m_error_message);
            pack_start (m_error_message_bg, false, false);

    		// install add-on toolbars previously registered.
            m_addon_toolbars = new Gee.HashMap<string,Widget> ();
        }
        
        /*
         * Initialization method. Call this from your
         * constructor.
         */
        protected void
        add_file_pane_toolbars ()
        {
            foreach (var tbcfg in application.ui_manager.filepane_toolbars) {
	            tbcfg.add_to_pane (this);
            }
    	}

    	/* *****************************************************
    	 * IMPLEMENTATION
    	 ******************************************************/

        /**
         * Add a toolbar to this FilePane.
         *
         * @param id \
         *				identifier that can be used to retrieve the toolbar
         *              using {@link get_addon_toolbar}
         * @param factory FilePaneToolbarFactory that creates the toolbar.
         * @param where   desired position of the toolbar.
         */
        public override void
        install_toolbar (string id, FilePaneToolbarFactory factory, PositionType where)
        {
	        var toolbar = factory (application, this);
	        
	        switch (where) {
		        case PositionType.TOP:
		        case PositionType.LEFT: // left not supported yet. This is silly.
		        	pack_start (toolbar, false, false, 0);
		        	reorder_child (toolbar, 0);
		        	break;
		        case PositionType.BOTTOM:
		        case PositionType.RIGHT:
		        	pack_end (toolbar, false, false, 0);
		        	break;
	        }
	        
	        m_addon_toolbars[id] = toolbar;
        }
        
        /**
         * Get a reference to your add-on toolbar, or null if it's not installed
         */
        public override Widget?
        get_addon_toolbar (string id)
        {
	        return m_addon_toolbars[id];
        }

        /**
         * Set the component to appear busy, or not. Here, this will
         * change the mouse cursor.
         */        
        public override void
        set_busy_state (bool busy)
        {
            var gdk_wnd = get_window ();
            if (gdk_wnd == null) {
                return;
            }

            if (busy) {
                var cursor = new Cursor (CursorType.WATCH);
                gdk_wnd.set_cursor (cursor);
            } else {
                gdk_wnd.set_cursor (null);
            }
        }


        /**
         * Show error underneath list.
         *
         * @param message Error message, should be translatable.
         */
        public override void
        display_error (string message)
        {
            m_error_message.set_text(message);
            m_error_message_bg.visible = true;
        }

        /**
         * Hide the error message, if any.
         */
        public override void
        hide_error ()
        {
            m_error_message_bg.visible = false;
        }

    }

}