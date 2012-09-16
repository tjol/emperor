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
using Gee;
using Emperor.App;

namespace Emperor.Modules {

    public class MousePrefs : Object
    {
        public EmperorCore app { get; construct; }
        public Preferences prefs { get; construct; }
        public ComboBox mode_selector { get; construct; }
        public Label explanation { get; construct; }
        
        public
        MousePrefs (Preferences prefs)
            throws ConfigurationError
        {
            var mode_selector = prefs.builder.get_object ("cboSelectionMode")
                                    as ComboBox;
            var explanation = prefs.builder.get_object ("lblModeExplanation")
                                    as Label;

            Object ( app : prefs.app,
                     prefs : prefs,
                     mode_selector : mode_selector,
                     explanation : explanation );
        }

        construct {
            prefs.mouse_prefs = this;
            mode_selector.active_id = app.ui_manager.default_input_mode_type.name ();
        }

        public void
        selection_mode_changed ()
        {
            set_label_text ();
            app.config["preferences"].set_string ("input-mode",
                                                  mode_selector.active_id);

            if (mode_selector.active_id == "EmperorAppLeftSelectInputMode") {
                app.config["user-interface"]["file-pane-style"]
                    = prefs.prefs_objects.get_member ("left-select-default-style");
            } else if (mode_selector.active_id == "EmperorAppRightSelectInputMode") {
                app.config["user-interface"]["file-pane-style"]
                    = prefs.prefs_objects.get_member ("right-select-default-style");
            }
        }

        private void
        set_label_text ()
        {
            TreeIter iter;
            string explanation_text;
            mode_selector.get_active_iter (out iter);
            mode_selector.model.get (iter, 2, out explanation_text, -1);
            explanation.label = explanation_text;
        }
    }
}