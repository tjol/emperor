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
using Gdk;
using Pango;
using Emperor;
using Emperor.App;

namespace Emperor.Modules {
    
    private Widget create_title_bar (EmperorCore app, FilePane file_pane)
    {
        var tb = new FilePaneTitlebar (app, file_pane); 
        return (Widget) tb;
    }

    public class FilePaneTitlebar : EventBox
    {
        public EmperorCore application { get; construct; }
        public FilePane pane { get; construct; }
        public Label title_label { get; construct; }

        public FilePaneTitlebar (EmperorCore app, FilePane file_pane)
        {
            Object ( application : app,
                     pane : file_pane,
                     title_label : new Label ("") );
        }

        construct {
            title_label.ellipsize = EllipsizeMode.START;
            title_label.single_line_mode = true;
            title_label.halign = Align.FILL | Align.START;
            title_label.margin = 3;
            var attr_list = new AttrList ();
            attr_list.insert (attr_weight_new (Weight.BOLD));
            title_label.set_attributes (attr_list);

            this.margin = 2;
            this.add (title_label);

            this.button_press_event.connect (on_click);
            pane.notify["pwd"].connect (on_pwd_change);
            pane.notify["active"].connect (on_active_state_change);
        }

        private bool m_editing = false;

        private bool
        on_click (EventButton e)
        {
            if (e.type == EventType.BUTTON_PRESS) {
                switch (e.button) {
                case 1:
                    // left-click!
                    edit_title ();
                    break;
                }
            }
            
            return false;
        }

        public void
        edit_title ()
        {
            // ignore clicks on title when it is already being edited.
            if (m_editing) return;
                    
            m_editing = true;
            
            var dir_text = new Entry();
            dir_text.text = pane.pwd.get_parse_name ();
            
            dir_text.focus_out_event.connect ((e) => {
                    // Remove the Entry, switch back to plain title.
                    if (m_editing) {
                        this.remove (dir_text);
                        this.add (title_label);
                        this.show_all ();
                        m_editing = false;
                    }
                    return true;
                });
                
            dir_text.key_press_event.connect ((e) => {
                    if (e.keyval == Key.Escape) { // Escape
                        // This moves the focus to the list, and focus_out_event 
                        // is called (see above)
                        pane.active = true;
                        return true;
                    }
                    return false;
                });
                
            dir_text.activate.connect (() => {
                    // Try to chdir to the new location
                    string dirpath = dir_text.text;
                    var f = File.parse_name (dirpath);
                    pane.pwd = f;
                    pane.active = true;
                });
            
            // display Entry
            this.remove (title_label);
            this.add (dir_text);
            dir_text.show ();
            dir_text.grab_focus ();
        }

        private void
        on_active_state_change (ParamSpec ps)
        {
            // restyle title bar
            if (pane.active) {
                title_label.override_color(StateFlags.NORMAL,
                            application.ui_manager.selected_foreground);
                this.override_background_color(StateFlags.NORMAL,
                            application.ui_manager.selected_background);
            } else {
                title_label.override_color(StateFlags.NORMAL,
                            application.ui_manager.label_foreground);
                this.override_background_color(StateFlags.NORMAL,
                            application.ui_manager.label_background);
            }
        }

        private void
        on_pwd_change (ParamSpec ps)
        {
            // set title.
            string title;
            // Are we in an archive?
            if (pane.pwd.get_uri_scheme() == "archive") {
                var archive_uri = pane.pwd.get_uri();
                var archive_file = MountManager.get_archive_file (archive_uri);
                var rel_path = pane.mnt.get_root().get_relative_path (pane.pwd);
                title = "[ %s ] /%s".printf (archive_file.get_basename(), rel_path);
            } else {
                title = pane.pwd.get_parse_name ();
            }
            title_label.set_text (title);
        }

    }

}


public void load_module (ModuleRegistry reg)
{
    var app = reg.application;
    app.ui_manager.add_filepane_toolbar ("titlebar",
                                         Emperor.Modules.create_title_bar,
                                         PositionType.TOP);


       // Ctrl+L: Change directory
    var action = reg.new_action ("chdir");
    action.label = _("Change Directory");
    action.set_accel_path ("<Emperor-Main>/TitleBar/Chdir");
    Gtk.AccelMap.add_entry ("<Emperor-Main>/TitleBar/Chdir",
                            Gdk.Key.L, Gdk.ModifierType.CONTROL_MASK);
    action.activate.connect ( () => { 
            // Get the toolbar instance
            var toolbar = (Emperor.Modules.FilePaneTitlebar)
                app.main_window.active_pane.get_addon_toolbar ("titlebar");

            toolbar.edit_title ();
        } );
    action.connect_accelerator ();
 
}