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
using Emperor;
using Emperor.Application;

namespace Emperor.Modules {
	
	public Widget create_quick_filter_bar (EmperorCore app, FilePane file_pane)
	{
		return new QuickFilterBar (app, file_pane);
	}
	
	public class QuickFilterBar : HBox
	{
		FilePane m_pane;
		EmperorCore m_app;
		Entry m_entry;
		
		public QuickFilterBar (EmperorCore app, FilePane pane)
		{
			m_pane = pane;
			m_app = app;
			
			// Build quick filter bar
			m_entry = new Entry ();
			m_entry.primary_icon_stock = Stock.FIND;
			m_entry.primary_icon_activatable = false;
			m_entry.secondary_icon_stock = Stock.CLOSE;
			m_entry.secondary_icon_activatable = true;
			
			m_entry.notify["text"].connect ( (p) => {
				// replaces old filter with the same function and forces re-filter.
				m_pane.add_filter ("quick-filter", filter_files);
			});
			// handle escape.
			m_entry.key_press_event.connect (handle_key_press_event);
			m_entry.icon_press.connect ( (pos, ev) => {
				// This can only be the close icon.
				close ();
			});
			m_entry.activate.connect (() => {
				m_pane.active = true;
			});
			
			m_pane.notify["pwd"].connect ((p) => {
				close ();
			});

			pack_start (m_entry, true, true, 0);

		}
		
		private bool handle_key_press_event (Gdk.EventKey ev)
		{
			switch (ev.keyval) {
				case Gdk.Key.Escape:
					close ();
					return true;
				default:
					return false;
			}
		}
		
		public void start_filter ()
		{
			show_all ();
			
			m_entry.grab_focus ();
			m_pane.add_filter ("quick-filter", filter_files);
		}
		
		public void close ()
		{
			hide ();
			m_pane.active = true;
			m_pane.remove_filter ("quick-filter");
		}
		
		public bool filter_files (File f, FileInfo fi, bool currently_visible)
		{
			return currently_visible && m_entry.text.down () in fi.get_display_name ().down ();
		}
	}
}

delegate Emperor.Modules.QuickFilterBar ReturnsQuickFilterBar ();

public void load_module (ModuleRegistry reg)
{
	var app = reg.application;
	
	app.ui_manager.add_filepane_toolbar ("quick-filter",
    									 Emperor.Modules.create_quick_filter_bar,
    									 PositionType.BOTTOM);
	// function
    ReturnsQuickFilterBar get_active_toolbar = () => {
        return (Emperor.Modules.QuickFilterBar) app.main_window.active_pane.get_addon_toolbar ("quick-filter");
    };
    
    // set up keyboard shortcut
    Gtk.Action action;

    // Alt+/ = start quick filter
    action = app.modules.new_action ("quick-filter/start-filter");
    action.label = _("Quick Filter");
    action.set_accel_path ("<Emperor-Main>/QuickFilter/StartFilter");
    Gtk.AccelMap.add_entry ("<Emperor-Main>/QuickFilter/StartFilter",
                            Gdk.Key.slash, Gdk.ModifierType.MOD1_MASK);
    action.activate.connect (() => { get_active_toolbar().start_filter(); });
    action.connect_accelerator ();
    app.ui_manager.add_action_to_menu (_("_View"), action);
}

