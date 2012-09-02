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

namespace Emperor.App {

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

        public delegate Widget FilePaneToolbarFactoryProper (EmperorCore app, FilePane fpane);
        
        public void add_filepane_toolbar (string id,
                                          owned FilePaneToolbarFactoryProper factory,
                                          PositionType where)
        {
            var tbcfg = new FilePaneToolbarConfig ();
            tbcfg.id = id;
            tbcfg.factory = (FilePaneToolbarFactory) ((owned)factory);
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
            internal bool expand;
            internal LinkedList<FileInfoColumn> cells;
            internal FileInfoColumn sort_column;
            internal unowned CompareFunc cmp_function;
            internal SortType? default_sort;
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
        internal class AboutStyle
        {
            public bool selected_style_uses_focus;
            public bool cursor_style_uses_focus;
            public bool other_styles_use_focus;
        }

        EmperorCore m_app;
        internal LinkedList<FilePaneColumn> panel_columns { get; private set; }
        internal HashMap<string,FilePaneColumn>? standard_columns { get; private set; }
        internal LinkedList<StyleDirective> style_directives { get; private set; }
        internal AboutStyle style_info { get; private set; }
        internal LinkedList<Gtk.Action> command_buttons { get; private set; }

        private Gdk.RGBA m_default_foreground;
        private Gdk.RGBA m_default_background;
        private Gdk.RGBA m_selected_foreground;
        private Gdk.RGBA m_selected_background;
        private Gdk.RGBA m_label_foreground;
        private Gdk.RGBA m_label_background;

        public Gdk.RGBA default_foreground { get { return m_default_foreground; } }
        public Gdk.RGBA default_background { get { return m_default_background; } }
        public Gdk.RGBA selected_foreground { get { return m_selected_foreground; } }
        public Gdk.RGBA selected_background { get { return m_selected_background; } }
        public Gdk.RGBA label_foreground { get { return m_label_foreground; } }
        public Gdk.RGBA label_background { get { return m_label_background; } }

        internal Value default_foreground_value { get; private set; }
        internal Value default_background_value { get; private set; }

        internal Gtk.MenuBar menu_bar { get; private set; }
        private Map<string,Gtk.Menu> m_menus;

        internal UserInterfaceManager (EmperorCore app)
                    throws ConfigurationError
        {
            m_app = app;
            create_style_context ();

            panel_columns = new LinkedList<FilePaneColumn> ();
            standard_columns = null;
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


        internal void
        load_style_configuration ()
            throws ConfigurationError
        {
            
            var style_cfg_node = m_app.config["user-interface"]["file-pane-style"];

            reconfigure_style (style_cfg_node);

            m_app.config["user-interface"].property_changed["file-pane-style"].connect (
                (style_data) => {
                    try {
                        reconfigure_style (style_data);
                    } catch (ConfigurationError style_err) {
                        warning (_("New UI configuration is invalid. Reverting."));
                        m_app.config["user-interface"].reset_to_default("file-pane-style");
                    }
                });
        }

        private void
        reconfigure_style (Json.Node style_data)
            throws ConfigurationError
        {
            var new_style_directives = new LinkedList<StyleDirective> ();
            var new_style_info = new AboutStyle();
            new_style_info.selected_style_uses_focus = false;
            new_style_info.cursor_style_uses_focus = false;
            new_style_info.other_styles_use_focus = false;

            if (style_data.get_node_type () != Json.NodeType.ARRAY) {
                throw new ConfigurationError.INVALID_ERROR (_("UI configuration is invalid."));
            }

            foreach (var style_directive_node in style_data.get_array ().get_elements ()) {
                if (style_directive_node.get_node_type () != Json.NodeType.OBJECT) {
                    throw new ConfigurationError.INVALID_ERROR (_("UI configuration is invalid."));
                }
                var style_directive_obj = style_directive_node.get_object ();

                var style = new StyleDirective ();

                // Target?
                var target_node = style_directive_obj.get_member ("target");
                style.target = StyleDirective.Target.ANY;
                if (target_node != null && target_node.get_value_type () == typeof(string)) {
                    if (target_node.get_string () == "cursor") {
                        style.target = StyleDirective.Target.CURSOR;
                    } else if (target_node.get_string () == "selected") {
                        style.target = StyleDirective.Target.SELECTED;
                    }
                }

                // File type?
                var file_type_node = style_directive_obj.get_member ("file-type");
                style.file_type = (FileType) (-1);
                if (file_type_node != null && file_type_node.get_value_type () == typeof(string)) {
                    if (file_type_node.get_string () == "directory") {
                        style.file_type = FileType.DIRECTORY;
                    } else if (file_type_node.get_string () == "symlink") {
                        style.file_type = FileType.SYMBOLIC_LINK;
                    } else if (file_type_node.get_string () == "special") {
                        style.file_type = FileType.SPECIAL;
                    } else if (file_type_node.get_string () == "shortcut") {
                        style.file_type = FileType.SHORTCUT;
                    } else if (file_type_node.get_string () == "mountable") {
                        style.file_type = FileType.MOUNTABLE;
                    } else if (file_type_node.get_string () == "regular") {
                        style.file_type = FileType.REGULAR;
                    } else if (file_type_node.get_string () == "unknown-type") {
                        style.file_type = FileType.UNKNOWN;
                    } else {
                        throw new ConfigurationError.INVALID_ERROR (_("UI configuration is invalid."));
                    }
                }

                // Pane state?
                var pane_node = style_directive_obj.get_member ("pane");
                style.pane = FilePaneState.EITHER;
                if (pane_node != null && pane_node.get_value_type () == typeof(string)) {
                    if (pane_node.get_string () == "either") {
                        style.pane = FilePaneState.EITHER;
                    } else {
                        if (pane_node.get_string () == "active") {
                            style.pane = FilePaneState.ACTIVE;
                        } else if (pane_node.get_string () == "passive") {
                            style.pane = FilePaneState.PASSIVE;
                        } else {
                            throw new ConfigurationError.INVALID_ERROR (_("UI configuration is invalid."));
                        }
                        // This style uses focus. Record this exciting news!
                        switch (style.target) {
                        case StyleDirective.Target.CURSOR:
                            new_style_info.cursor_style_uses_focus = true;
                            break;
                        case StyleDirective.Target.SELECTED:
                            new_style_info.selected_style_uses_focus = true;
                            break;
                        default:
                            new_style_info.other_styles_use_focus = true;
                            break;
                        }
                    }
                }

                // Foreground color?
                var fg_node = style_directive_obj.get_member ("color");
                if (fg_node != null && fg_node.get_value_type () == typeof(string)) {
                    style.fg = make_color (fg_node.get_string ());
                } else {
                    style.fg = null;
                }

                // Background color?
                var bg_node = style_directive_obj.get_member ("background-color");
                if (bg_node != null && bg_node.get_value_type () == typeof(string)) {
                    style.bg = make_color (bg_node.get_string ());
                } else {
                    style.bg = null;
                }

                // Font weight?
                var weight_node = style_directive_obj.get_member ("weight");
                if (weight_node != null) {
                    if (weight_node.get_value_type () == typeof(string) &&
                            weight_node.get_string () == "bold") {
                        style.weight = 600;
                    } else if (weight_node.get_value_type () == typeof(int64)) {
                        style.weight = (int) weight_node.get_int ();
                    }
                }

                // Font style?
                var font_style_node = style_directive_obj.get_member ("style");
                style.style = Pango.Style.NORMAL;
                if (font_style_node != null && font_style_node.get_value_type () == typeof(string)) {
                    if (font_style_node.get_string () == "oblique") {
                        style.style = Pango.Style.OBLIQUE;
                    } else if (font_style_node.get_string () == "italic") {
                        style.style = Pango.Style.ITALIC;
                    }
                }

                new_style_directives.add (style);
            }

            style_directives = new_style_directives;
            style_info = new_style_info;

            styles_changed ();
        }

        public signal void styles_changed ();

        /**
         * Load column-types.json into {@link standard_columns}
         */
        private void
        load_column_types ()
            throws ConfigurationError
        {
            standard_columns = new HashMap<string,FilePaneColumn> ();
            var parser = new Json.Parser ();
            var coltypes_filename = m_app.get_config_file_path ("column-types.json");
            try {
                parser.load_from_file (coltypes_filename);
            } catch (Error load_err) {
                throw new ConfigurationError.PARSE_ERROR (load_err.message);
            }

            var root_node = parser.get_root ();
            if (root_node.get_node_type () != Json.NodeType.OBJECT) {
                throw new ConfigurationError.INVALID_ERROR (_("Column type configuration is invalid!"));
            }

            var root_object = root_node.get_object ();
            foreach (string col_name in root_object.get_members ()) {
                var col_node = root_object.get_member (col_name);

                if (col_node.get_node_type () != Json.NodeType.OBJECT) {
                    throw new ConfigurationError.INVALID_ERROR (_("Column type configuration is invalid!"));
                }

                var col_object = col_node.get_object ();
                var column = read_json_column_object (col_object, true);

                standard_columns[col_name] = column;
            }
        }

        private FilePaneColumn
        read_json_column_object (Json.Object col_object, bool use_gettext)
            throws ConfigurationError
        {
            var column = new FilePaneColumn ();

            // Title
            if (col_object.has_member ("title") &&
                col_object.get_member ("title").get_value_type () == typeof(string)) {
                if (use_gettext) {
                    column.title = _(col_object.get_string_member ("title"));
                } else {
                    column.title = col_object.get_string_member ("title");
                }
            } else {
                throw new ConfigurationError.INVALID_ERROR (_("Column type configuration is invalid!"));
            }

            // Expand?
            if (col_object.has_member ("expand") &&
                    col_object.get_member ("expand").get_value_type () == typeof(bool)) {
                column.expand = col_object.get_boolean_member ("expand");
            } else {
                column.expand = false;
            }

            // Sort by default?
            column.default_sort = null;
            if (col_object.has_member ("sort-by-default") &&
                    col_object.get_member ("sort-by-default").get_value_type () == typeof(string)) {
                var sort_recommendation_string = col_object.get_string_member ("sort-by-default");
                if (sort_recommendation_string == "ascending") {
                    column.default_sort = SortType.ASCENDING;
                } else if (sort_recommendation_string == "descending") {
                    column.default_sort = SortType.DESCENDING;
                } 
            }

            // Cells.
            if (col_object.has_member ("cells") &&
                    col_object.get_member ("cells").get_node_type () == Json.NodeType.ARRAY) {

                column.cells = new LinkedList<FileInfoColumn> ();
                
                foreach (var cell_node in col_object.get_array_member ("cells").get_elements ()) {
                    if (cell_node.get_node_type () != Json.NodeType.OBJECT) {
                        throw new ConfigurationError.INVALID_ERROR (_("Column type configuration is invalid!"));        
                    }
                    var cell_object = cell_node.get_object ();
                    FileInfoColumn coldata = null;

                    if (cell_object.has_member ("data") &&
                            cell_object.get_member ("data").get_value_type () == typeof(string)) {
                        
                        coldata = m_app.modules.get_column (cell_object.get_string_member ("data"));
                        column.cells.add (coldata);

                    } else {
                        throw new ConfigurationError.INVALID_ERROR (_("Column type configuration is invalid!"));
                    }

                    if (cell_object.has_member ("sort") &&
                            cell_object.get_member ("sort").get_value_type () == typeof(string)) {             
                        var sortflag = cell_object.get_string_member ("sort");
                        unowned CompareFunc sortfunc = m_app.modules.get_sort_function (sortflag);
                        if (sortfunc == null) {
                            throw new ConfigurationError.INVALID_ERROR(
                                _("Illegal value for \"sort\": \"%s\"").printf(sortflag));
                        }
                        column.sort_column = coldata;
                        column.cmp_function = sortfunc;
                    }
                }
            } else {
                throw new ConfigurationError.INVALID_ERROR (_("Column type configuration is invalid!"));
            }

            return column;
        }

        internal void
        load_column_configuration ()
            throws ConfigurationError
        {
            if (standard_columns == null) {
                load_column_types ();
            }

            var col_cfg_node = m_app.config["user-interface"]["file-pane-columns"];

            reload_columns (col_cfg_node);

            m_app.config["user-interface"].property_changed["file-pane-columns"].connect (
                (col_config) => {
                    try {
                        reload_columns (col_config);
                    } catch (ConfigurationError style_err) {
                        warning (_("New UI configuration is invalid. Reverting."));
                        m_app.config["user-interface"].reset_to_default("file-pane-columns");
                    }
                });
        }

        private void
        reload_columns (Json.Node col_config)
            throws ConfigurationError
        {
            var new_columns = new LinkedList<FilePaneColumn> ();

            if (col_config.get_node_type () != Json.NodeType.ARRAY) {
                throw new ConfigurationError.INVALID_ERROR (_("UI configuration is invalid."));
            }

            foreach (var column_node in col_config.get_array ().get_elements ()) {
                if (column_node.get_node_type () == Json.NodeType.OBJECT) {
                    new_columns.add (read_json_column_object (column_node.get_object (), false));
                } else if (column_node.get_value_type () == typeof(string)) {
                    var col_name = column_node.get_string ();
                    if (standard_columns.has_key (col_name)) {
                        new_columns.add (standard_columns[col_name]);
                    } else {
                        throw new ConfigurationError.MODULE_ERROR (
                            _("Unknown column ID: %s").printf (col_name));
                    }
                } else {
                    throw new ConfigurationError.INVALID_ERROR (_("UI configuration is invalid."));
                }
            }

            panel_columns = new_columns;

            columns_changed ();
        }

        public signal void columns_changed ();

        private StyleContext m_style_context;
        private WidgetPath m_entry_path;
        private WidgetPath m_button_path;

        /**
         * Retrieve default colour values from theme
         */
        private void create_style_context ()
        {
            m_style_context = new StyleContext();

            var provider = CssProvider.get_default();
            m_style_context.add_provider(provider, 1);

            m_button_path = new WidgetPath();
            m_button_path.append_type(typeof(Button));
            m_button_path.iter_add_class(-1, STYLE_CLASS_BUTTON);

            m_style_context.set_path(m_button_path);

            m_label_foreground = m_style_context.get_color(StateFlags.NORMAL);
            m_label_background = m_style_context.get_background_color(StateFlags.NORMAL);

            m_entry_path = new WidgetPath();
            m_entry_path.append_type(typeof(TreeView));
            m_entry_path.append_type(typeof(CellArea));
            m_entry_path.append_type(typeof(Entry));
            m_entry_path.iter_add_class(-1, STYLE_CLASS_ENTRY);

            m_style_context.set_path(m_entry_path);

            m_default_foreground = m_style_context.get_color(StateFlags.NORMAL);
            default_foreground_value = Value(typeof(Gdk.RGBA));
            default_foreground_value.set_boxed(&m_default_foreground);

            m_default_background = m_style_context.get_background_color(StateFlags.NORMAL);
            default_background_value = Value(typeof(Gdk.RGBA));
            default_background_value.set_boxed(&m_default_background);

            m_selected_foreground = m_style_context.get_color(StateFlags.SELECTED);
            m_selected_background = m_style_context.get_background_color(StateFlags.SELECTED);
        }

        /**
         * Get a colour from a colour specification string. This can have the
         * format:
         *
         *  * //gtk:control:property:flags// where //flags// has the format //flag1|flag2|...//.
         *    The possible controls are:
         *    * entry
         *    * button
         *    The possible properties are:
         *    * color
         *    * background-color
         *    * border-color
         *    The possible flags are:
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
                string control = spec_a[1];
                string property = spec_a[2];
                string[] flags = spec_a[3].split("|");
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
                    case "backdrop":
                        flags_i |= StateFlags.BACKDROP;
                        break;
                    default:
                        break;
                    }
                }
                switch (control) {
                case "entry":
                    m_style_context.set_path (m_entry_path);
                    break;
                case "button":
                    m_style_context.set_path (m_button_path);
                    break;
                default:
                    return null;
                }
                switch (property) {
                case "color":
                    return m_style_context.get_color (flags_i);
                case "background-color":
                    return m_style_context.get_background_color (flags_i);
                case "border-color":
                    return m_style_context.get_border_color (flags_i);
                default:
                    return null;
                }
            } else {
                var color = Gdk.RGBA();
                if (m_style_context.lookup_color (spec, out color) ||
                        color.parse(spec)) {
                    return color;
                } else {
                    return null;
                }
            }
        }
    }

}

