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

    /**
     * Class responsible for handling user interface configuration.
     */
    public class UserInterfaceManager : Object
    {
        /**
         * Signal emitted when the application window has been fully set up
         * and mapped. Use this for module configuration that requires
         * initialized {@link FilePane} objects.
         */
        public signal void main_window_ready (MainWindow main_window);
        
        public void add_filepane_toolbar (string id,
                                          FilePaneToolbarFactory factory,
                                          PositionType where)
        {
	        var tbcfg = new FilePaneToolbarConfig ();
	        tbcfg.id = id;
	        tbcfg.factory = factory;
	        tbcfg.where = where;
	     
		 	filepane_toolbars.append (tbcfg);   
	    } 
        
	    internal class FilePaneToolbarConfig
		{
	        public string id;
	        public FilePaneToolbarFactory factory;
	        public PositionType where;
	        
	        public void add_to_pane (FilePane pane)
	        {
		        pane.install_toolbar (id, factory, where);
	        }
        }
        
        internal GLib.List<FilePaneToolbarConfig> filepane_toolbars;
        
        /**
         * File pane column configuration
         */
        internal class FilePaneColumn
        {
            internal string title;
            internal int default_width;
            internal LinkedList<FileInfoColumn> cells;
            internal FileInfoColumn sort_column;
            internal CompareFunc cmp_function;
        }

        /**
         * File list styling directive
         */
        internal class StyleDirective
        {
            internal enum Target {
                CURSOR,
                SELECTED,
                ANY
            }

            internal Target target = Target.ANY;
            internal FilePaneState pane;
            internal FileType file_type;

            internal int? weight = null;
            internal Pango.Style? style = null;
            internal Gdk.RGBA? fg = null;
            internal Gdk.RGBA? bg = null;
        }

        /**
         * Information about the nature of the style that allows
         * FilePane to only restyle the rows that need it.
         */
        internal struct AboutStyle
        {
            public bool selected_style_uses_focus;
            public bool cursor_style_uses_focus;
            public bool other_styles_use_focus;
        }

        EmperorCore m_app;
        internal LinkedList<FilePaneColumn> panel_columns { get; private set; }
        internal LinkedList<StyleDirective> style_directives { get; private set; }
        internal AboutStyle style_info { get; private set; }
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

        internal Gtk.MenuBar menu_bar { get; private set; }
        private Map<string,Gtk.Menu> m_menus;

        internal UserInterfaceManager (EmperorCore app)
                    throws ConfigurationError
        {
            m_app = app;
            create_style_context ();

            style_directives = new LinkedList<StyleDirective> ();
            style_info = AboutStyle();
            style_info.selected_style_uses_focus = false;
            style_info.cursor_style_uses_focus = false;
            style_info.other_styles_use_focus = false;

            panel_columns = new LinkedList<FilePaneColumn> ();
            command_buttons = new LinkedList<Gtk.Action> ();

            m_menus = new HashMap<string,Gtk.Menu> ();
            menu_bar = new Gtk.MenuBar ();

            m_menu_items = new HashMap<string,TreeMap<int,Gtk.MenuItem> > ();
            
            filepane_toolbars = new GLib.List<FilePaneToolbarConfig> ();
        }

        /**
         * Return the menu with the given title, creating it if it does
         * not yet exist.
         *
         * @param title Menu title. (should be translatable)
         * @param pos   Position at which the menu is inserted. Resulting \
         *              behaviour depends on which menus have already been \
         *              added.
         */
        public Gtk.Menu get_menu (string title, int pos = -1)
        {
            if (m_menus.has_key(title)) {
                return m_menus[title];
            } else {
                var title_menu_item = new Gtk.MenuItem.with_mnemonic (title);
                var menu = new Gtk.Menu ();
                title_menu_item.set_submenu (menu);
                if (pos == -1) {
                    menu_bar.append (title_menu_item);
                } else {
                    menu_bar.insert (title_menu_item, pos);
                }
                m_menus[title] = menu;
                m_menu_items[title] = new TreeMap<int,Gtk.MenuItem> ();
                title_menu_item.show ();
                return menu;
            }
        }

        private HashMap<string,TreeMap<int,Gtk.MenuItem> > m_menu_items;

        /**
         * Add a Gtk.Action to a menu
         */
        public void add_action_to_menu (string menu_title, Gtk.Action act, int pos = -1)
        {
            var menu = get_menu (menu_title);
            var item = act.create_menu_item() as Gtk.MenuItem;

            menu.append (item);
            var menu_item_map = m_menu_items[menu_title];
            while (menu_item_map.has_key(pos)) {
                pos ++;
            }
            menu_item_map[pos] = item;

            reorder_menu (menu_title);
        }

        /**
         * Ensure that all menu items are in the correct order. Called
         * automatically by add_action_to_menu.
         */
        public void reorder_menu (string menu_title)
        {
            int idx = 0;
            var menu = get_menu (menu_title);
            foreach (var e in m_menu_items[menu_title].ascending_entries) {
                menu.reorder_child (e.value, idx);
                idx ++;
            }
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
                                        _("Unexpected element: %s").printf(node->name));
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
                                        _("Unexpected element: %s").printf(node->name));
                        }
                    }
                    break;

                case "columns":
                    if (node->type == Xml.ElementType.ELEMENT_NODE) {
                        if (node->name == "column") {
                            
                            _current_column = new FilePaneColumn();

                            var title = node->get_prop("title");
                            if (title == null) {
                                var xtitle = node->get_prop("xtitle");
                                if (xtitle != null) {
                                    title = _(xtitle);
                                } else {
                                    title = "";
                                }
                            }
                            var width_s = node->get_prop("default-width");
                            if (width_s == null) {
                                width_s = "0";
                            }
                            _current_column.title = title;
                            _current_column.default_width = int.parse(width_s);
                            _current_column.cells = new LinkedList<FileInfoColumn>();
                            handle_config_xml_nodes (node);
                            panel_columns.add(_current_column);

                        } else {
                            throw new ConfigurationError.INVALID_ERROR(
                                        _("Unexpected element: %s").printf(node->name));
                        }
                    }
                    break;

                case "column":
                    if (node->type == Xml.ElementType.ELEMENT_NODE) {
                        if (node->name == "cell") {

                            var data = node->get_prop("data");
                            if (data == null) {
                                throw new ConfigurationError.INVALID_ERROR(
                                            _("Cannot have cell without data"));
                            }

                            var coldata = m_app.modules.get_column(data);
                            if (coldata == null) {
                                throw new ConfigurationError.MODULE_ERROR(
                                            _("Unknown column type: %s").printf(data));
                            }

                            var sortflag = node->get_prop("sort");
                            if (sortflag != null) {
                                if (_current_column.sort_column == null) {
                                    var sortfunc = m_app.modules.get_sort_function(sortflag);
                                    if (sortfunc == null) {
                                        throw new ConfigurationError.INVALID_ERROR(
                                               _("Illegal value for \"sort\": \"%s\"").printf(sortflag));
                                    } else {
                                        _current_column.sort_column = coldata;
                                        _current_column.cmp_function = sortfunc;
                                    }
                                } else {
                                    throw new ConfigurationError.INVALID_ERROR(
                                        _("There can be only one sorting cell per column."));
                                }
                            }

                            _current_column.cells.add(coldata);

                        } else {
                            throw new ConfigurationError.INVALID_ERROR(
                                        _("Unexpected element: %s").printf(node->name));
                        }
                    }
                    break;

                case "style":
                    if (node->type == Xml.ElementType.ELEMENT_NODE) {
                        var style = new StyleDirective();

                        // Defaults
                        style.target = StyleDirective.Target.ANY;
                        style.file_type = (FileType)(-1);

                        switch (node->name) {
                        case "cursor":
                            style.target = StyleDirective.Target.CURSOR;
                            break;
                        case "selected":
                            style.target = StyleDirective.Target.SELECTED;
                            break;
                        case "directory":
                            style.file_type = FileType.DIRECTORY;
                            break;
                        case "symlink":
                            style.file_type = FileType.SYMBOLIC_LINK;
                            break;
                        case "special":
                            style.file_type = FileType.SPECIAL;
                            break;
                        case "shortcut":
                            style.file_type = FileType.SHORTCUT;
                            break;
                        case "mountable":
                            style.file_type = FileType.MOUNTABLE;
                            break;
                        case "regular":
                            style.file_type = FileType.REGULAR;
                            break;
                        case "unknown-type":
                            style.file_type = FileType.UNKNOWN;
                            break;
                        default:
                            throw new ConfigurationError.INVALID_ERROR(
                                    _("Unexpected element: %s").printf(node->name));
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
                                    _("Illegal value for \"pane\": \"%s\"").printf(pane_str));
                        }

                        if (style.pane != FilePaneState.EITHER) {
                            if (style.target == StyleDirective.Target.CURSOR) {
                                style_info.cursor_style_uses_focus = true;
                            } else if (style.target == StyleDirective.Target.SELECTED) {
                                style_info.selected_style_uses_focus = true;
                            } else {
                                style_info.other_styles_use_focus = true;
                            }
                        }

                        style.fg = make_color(node->get_prop("fg"));
                        style.bg = make_color(node->get_prop("bg"));

                        var weight_str = node->get_prop ("weight");
                        if (weight_str == "bold") {
                            style.weight = 600;
                        } else if (weight_str == null) {
                            // pass.
                        } else {
                            throw new ConfigurationError.INVALID_ERROR(
                                    _("Illegal value for \"weight\": \"%s\"").printf(weight_str));
                        }
                        var style_str = node->get_prop ("style");
                        switch (style_str) {
                        case null:
                        case "normal":
                            style.style = Pango.Style.NORMAL;
                            break;
                        case "oblique":
                            style.style = Pango.Style.OBLIQUE;
                            break;
                        case "italic":
                            style.style = Pango.Style.ITALIC;
                            break;
                        default:
                            throw new ConfigurationError.INVALID_ERROR(
                                    _("Illegal value for \"style\": \"%s\"").printf(style));
                        }

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
                                    _("Each command button must an associated action."));
                            } else {
                                action = m_app.modules.actions.get_action (commandname);
                                if (action == null) {
                                    throw new ConfigurationError.MODULE_ERROR (
                                        _("Unknown action: %s").printf(commandname));
                                }
                            }

                            command_buttons.add (action);

                        } else {
                            throw new ConfigurationError.INVALID_ERROR(
                                        _("Unexpected element: %s").printf(node->name));
                        }
                    }
                    break;

                default:
                    throw new ConfigurationError.INVALID_ERROR(
                                _("Unexpected element: %s").printf(parent->name));

                }
            }
        }

        private StyleContext m_style_context;

        /**
         * Retrieve default colour values from theme
         */
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

            m_default_foreground = m_style_context.get_color(StateFlags.NORMAL);
            default_foreground_value = Value(typeof(Gdk.RGBA));
            default_foreground_value.set_boxed(&m_default_foreground);

            m_default_background = m_style_context.get_background_color(StateFlags.NORMAL);
            default_background_value = Value(typeof(Gdk.RGBA));
            default_background_value.set_boxed(&m_default_background);

            m_selected_foreground = m_style_context.get_color(StateFlags.SELECTED);
            m_selected_background = m_style_context.get_background_color(StateFlags.SELECTED);

            path = new WidgetPath();
            path.append_type(typeof(Button));
            path.iter_add_class(-1, STYLE_CLASS_BUTTON);
            m_style_context.set_path(path);

            m_label_foreground = m_style_context.get_color(StateFlags.NORMAL);
            m_label_background = m_style_context.get_background_color(StateFlags.NORMAL);
        }

        /**
         * Get a colour from a colour specification string. This can have the
         * format:
         *
         *  * //gtk:flags// where //flags// has the format //flag1|flag2|...// with the possible flags being:
         *    * normal
         *    * active
         *    * prelight
         *    * selected
         *    * insensitive
         *    * inconsistent
         *    * focused
         *  * A standard name (Taken from the X11 rgb.txt file).
         *  * A hex value in the form '#rgb' '#rrggbb' '#rrrgggbbb' or '#rrrrggggbbbb'
         *  * A RGB color in the form 'rgb(r,g,b)' (In this case the color will have full opacity) 
         *  * A RGBA color in the form 'rgba(r,g,b,a)' 
         */
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

