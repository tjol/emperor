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

    public class UserInterfaceManager : Object
    {
        public signal void main_window_ready (MainWindow main_window);
        
        internal class FilePaneColumn
        {
            internal string title;
            internal LinkedList<FileInfoColumn> cells;
            internal FileInfoColumn sort_column;
            internal CompareFunc cmp_function;
        }

        internal class StyleDirective
        {
            internal enum Target {
                CURSOR,
                SELECTED
            }

            internal Target target;
            internal FilePaneState pane;
            internal Gdk.RGBA? fg;
            internal Gdk.RGBA? bg;
        }

        EmperorCore m_app;
        internal LinkedList<FilePaneColumn> panel_columns { get; private set; }
        internal LinkedList<StyleDirective> style_directives { get; private set; }
        internal LinkedList<Gtk.Action> command_buttons { get; private set; }

        private Gdk.RGBA m_default_foreground;
        private Gdk.RGBA m_default_background;
        private Gdk.RGBA m_selected_foreground;
        private Gdk.RGBA m_selected_background;
        private Gdk.RGBA m_label_foreground;
        private Gdk.RGBA m_label_background;

        internal Gdk.RGBA default_foreground { get { return m_default_foreground; } }
        internal Gdk.RGBA default_background { get { return m_default_background; } }
        internal Gdk.RGBA selected_foreground { get { return m_selected_foreground; } }
        internal Gdk.RGBA selected_background { get { return m_selected_background; } }
        internal Gdk.RGBA label_foreground { get { return m_label_foreground; } }
        internal Gdk.RGBA label_background { get { return m_label_background; } }

        internal Value default_foreground_value { get; private set; }
        internal Value default_background_value { get; private set; }

        internal MenuBar menu_bar { get; private set; }
        private Map<string,Menu> m_menus;

        internal UserInterfaceManager (EmperorCore app)
                    throws ConfigurationError
        {
            m_app = app;
            create_style_context ();
            style_directives = new LinkedList<StyleDirective> ();
            panel_columns = new LinkedList<FilePaneColumn> ();
            command_buttons = new LinkedList<Gtk.Action> ();

            m_menus = new HashMap<string,Menu> ();
            menu_bar = new MenuBar ();

        }

        public Menu get_menu (string title)
        {
            if (m_menus.has_key(title)) {
                return m_menus[title];
            } else {
                var title_menu_item = new MenuItem.with_mnemonic (title);
                var menu = new Menu ();
                title_menu_item.set_submenu (menu);
                menu_bar.append (title_menu_item);
                m_menus[title] = menu;
                return menu;
            }
        }

        public void add_action_to_menu (string menu_title, Gtk.Action act)
        {
            var menu = get_menu (menu_title);
            menu.append (act.create_menu_item() as MenuItem);
        }


        FilePaneColumn? _current_column = null;

        internal void handle_config_xml_nodes (Xml.Node* parent)
                        throws ConfigurationError
        {
            for (Xml.Node* node = parent->children; node != null; node = node->next) {
                switch (parent->name) {

                case "user-interface":
                    if (node->type == Xml.ElementType.ELEMENT_NODE) {
                        if (node->name == "file-pane" || node->name == "command-bar") {
                            handle_config_xml_nodes (node);
                        } else {
                            throw new ConfigurationError.INVALID_ERROR(
                                        "Unexpected element: " + node->name);
                        }
                    }
                    break;

                case "file-pane":
                    if (node->type == Xml.ElementType.ELEMENT_NODE) {
                        switch (node->name) {
                        case "columns":
                        case "style":
                            handle_config_xml_nodes (node);
                            break;
                        default:
                            throw new ConfigurationError.INVALID_ERROR(
                                        "Unexpected element: " + node->name);
                        }
                    }
                    break;

                case "columns":
                    if (node->type == Xml.ElementType.ELEMENT_NODE) {
                        if (node->name == "column") {
                            
                            _current_column = new FilePaneColumn();

                            var title = node->get_prop("title");
                            if (title == null) {
                                title = "";
                            }
                            _current_column.title = title;
                            _current_column.cells = new LinkedList<FileInfoColumn>();
                            handle_config_xml_nodes (node);
                            panel_columns.add(_current_column);

                        } else {
                            throw new ConfigurationError.INVALID_ERROR(
                                        "Unexpected element: " + node->name);
                        }
                    }
                    break;

                case "column":
                    if (node->type == Xml.ElementType.ELEMENT_NODE) {
                        if (node->name == "cell") {

                            var data = node->get_prop("data");
                            if (data == null) {
                                throw new ConfigurationError.INVALID_ERROR(
                                            "Cannot have cell without data");
                            }

                            var coldata = m_app.modules.get_column(data);
                            if (coldata == null) {
                                throw new ConfigurationError.MODULE_ERROR(
                                            "Unknown column type: " + data);
                            }

                            var sortflag = node->get_prop("sort");
                            if (sortflag != null) {
                                if (_current_column.sort_column == null) {
                                    var sortfunc = m_app.modules.get_sort_function(sortflag);
                                    if (sortfunc == null) {
                                        throw new ConfigurationError.INVALID_ERROR(
                                               "Illegal value for \"sort\": \"" + sortflag + "\"");
                                    } else {
                                        _current_column.sort_column = coldata;
                                        _current_column.cmp_function = sortfunc;
                                    }
                                } else {
                                    throw new ConfigurationError.INVALID_ERROR(
                                        "There can be only one sorting cell per column.");
                                }
                            }

                            _current_column.cells.add(coldata);

                        } else {
                            throw new ConfigurationError.INVALID_ERROR(
                                        "Unexpected element: " + node->name);
                        }
                    }
                    break;

                case "style":
                    if (node->type == Xml.ElementType.ELEMENT_NODE) {
                        var style = new StyleDirective();

                        switch (node->name) {
                        case "cursor":
                            style.target = StyleDirective.Target.CURSOR;
                            break;
                        case "selected":
                            style.target = StyleDirective.Target.SELECTED;
                            break;
                        default:
                            throw new ConfigurationError.INVALID_ERROR(
                                    "Unexpected element: " + node->name);
                        }

                        var pane_str = node->get_prop("pane");
                        switch (pane_str) {
                        case "active":
                            style.pane = FilePaneState.ACTIVE;
                            break;
                        case "inactive":
                        case "passive":
                            style.pane = FilePaneState.PASSIVE;
                            break;
                        case "either":
                        case null:
                            style.pane = FilePaneState.EITHER;
                            break;
                        default:
                            throw new ConfigurationError.INVALID_ERROR(
                                    "Illegal value for \"pane\": \"" + pane_str + "\"");
                        }
                        style.fg = make_color(node->get_prop("fg"));
                        style.bg = make_color(node->get_prop("bg"));

                        style_directives.add(style);
                    }
                    break;

                case "command-bar":
                    if (node->type == Xml.ElementType.ELEMENT_NODE) {
                        if (node->name == "command-button") {
                            var commandname = node->get_prop ("action");
                            Gtk.Action action = null;

                            if (commandname == null) {
                                throw new ConfigurationError.INVALID_ERROR (
                                    "Each command button must an associated action.");
                            } else {
                                action = m_app.modules.actions.get_action (commandname);
                                if (action == null) {
                                    throw new ConfigurationError.MODULE_ERROR (
                                        "Unknown action: " + commandname);
                                }
                            }

                            command_buttons.add (action);

                        } else {
                            throw new ConfigurationError.INVALID_ERROR(
                                        "Unexpected element: " + node->name);
                        }
                    }
                    break;

                default:
                    throw new ConfigurationError.INVALID_ERROR(
                                "Unexpected element: " + parent->name);

                }
            }
        }

        private StyleContext m_style_context;
        private void create_style_context ()
        {
            m_style_context = new StyleContext();

            var provider = CssProvider.get_default();
            m_style_context.add_provider(provider, 1);

            var path = new WidgetPath();
            path.append_type(typeof(TreeView));
            path.append_type(typeof(CellArea));
            path.append_type(typeof(Entry));
            path.iter_add_class(-1, STYLE_CLASS_ENTRY);

            m_style_context.set_path(path);

            m_style_context.get_color(StateFlags.NORMAL, m_default_foreground);
            default_foreground_value = Value(typeof(Gdk.RGBA));
            default_foreground_value.set_boxed(&m_default_foreground);

            m_style_context.get_background_color(StateFlags.NORMAL, m_default_background);
            default_background_value = Value(typeof(Gdk.RGBA));
            default_background_value.set_boxed(&m_default_background);

            m_style_context.get_color(StateFlags.SELECTED, m_selected_foreground);
            m_style_context.get_background_color(StateFlags.SELECTED, m_selected_background);

            path = new WidgetPath();
            path.append_type(typeof(Label));
            path.iter_add_class(-1, STYLE_CLASS_DEFAULT);
            m_style_context.set_path(path);

            m_style_context.get_color(StateFlags.NORMAL, m_label_foreground);
            m_style_context.get_background_color(StateFlags.NORMAL, m_label_background);
        }

        public Gdk.RGBA? make_color(string? spec)
        {
            if (spec == null) {
                return null;
            }
            if (spec.has_prefix("gtk:")) {
                string[] spec_a = spec.split(":");
                string property = spec_a[1];
                string[] flags = spec_a[2].split("|");
                StateFlags flags_i = 0;
                foreach (var flag in flags) {
                    switch (flag) {
                    case "normal":
                        flags_i |= StateFlags.NORMAL;
                        break;
                    case "active":
                        flags_i |= StateFlags.ACTIVE;
                        break;
                    case "prelight":
                        flags_i |= StateFlags.PRELIGHT;
                        break;
                    case "selected":
                        flags_i |= StateFlags.SELECTED;
                        break;
                    case "insensitive":
                        flags_i |= StateFlags.INSENSITIVE;
                        break;
                    case "inconsistent":
                        flags_i |= StateFlags.INCONSISTENT;
                        break;
                    case "focused":
                        flags_i |= StateFlags.FOCUSED;
                        break;
                    default:
                        break;
                    }
                }

                var v = Value(typeof(Gdk.RGBA));
                m_style_context.get_property(property, flags_i, /*out*/ v);
                if (v.holds(typeof(Gdk.RGBA))) {
                    return (Gdk.RGBA?)v.get_boxed();
                } else {
                    return null;
                }

            } else {
                var color = Gdk.RGBA();
                if (color.parse(spec)) {
                    return color;
                } else {
                    return null;
                }
            }
        }
    }

}

