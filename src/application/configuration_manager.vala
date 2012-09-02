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

namespace Emperor.App {

    public class ConfigurationManager : Object
    {
        public EmperorCore application { get; construct; }
        
        private Map<string,ConfigurationSection> m_sections;

        public
        ConfigurationManager (EmperorCore app)
        {
            Object ( application : app );
        }

        construct {
            m_sections = new HashMap<string,ConfigurationSection> ();
        }

        /**
         * Load a JSON config file. This method may be called multiple times.
         */
        public void
        load_config_file (string config_file_path)
            throws ConfigurationError
        {
            var parser = new Json.Parser ();
            try {
                parser.load_from_file (config_file_path);
            } catch (Error load_err) {
                throw new ConfigurationError.PARSE_ERROR (load_err.message);
            }

            var root = parser.get_root ();
            if (root.get_node_type () != Json.NodeType.OBJECT) {
                throw new ConfigurationError.INVALID_ERROR (_("Configuration file %s invalid.").printf(config_file_path));
            }

            var root_object = root.get_object ();
            foreach (string member_name in root_object.get_members ()) {
                var member_node = root_object.get_member (member_name);
                if (member_node.get_node_type () != Json.NodeType.OBJECT) {
                    throw new ConfigurationError.INVALID_ERROR (_("Configuration file %s invalid.").printf(config_file_path));
                }

                var member_object = member_node.get_object ();
                foreach (string property_name in member_object.get_members()) {
                    var property_node = member_object.get_member (property_name);
                    set_config_property (member_name, property_name, property_node);
                }
            }
        }

        public void set_config_property (string section_name, string property_name, Json.Node data)
        {
            this.get(section_name)[property_name] = data;
        }

        public new ConfigurationSection
        get (string section_name)
        {
            if (m_sections.has_key (section_name)) {
                return m_sections[section_name];
            } else {
                var section = new ConfigurationSection ();
                m_sections[section_name] = section;
                return section;
            }
        }

        /**
         * Set the current configuration to be the baseline or default configuration.
         * {@link ConfigurationSection.reset_to_default} will use this as a reference,
         * and output configuration files will only include the changes.
         */
        public void
        set_baseline_configuration ()
        {
            foreach (var section in m_sections.values) {
                section.set_baseline_configuration ();
            }
        }

        public void
        save_changes (string path)
            throws Error
        {
            var obj = new Json.Object ();

            foreach (var e in m_sections.entries) {
                var section = e.value;
                var section_node = section.get_changes ();
                if (section_node == null) {
                    continue;
                } else {
                    obj.set_member (e.key, section_node);
                }
            }

            var node = new Json.Node (Json.NodeType.OBJECT);
            node.take_object ((owned) obj);

            var generator = new Json.Generator ();
            generator.pretty = true;
            generator.indent = 4;
            generator.root = node;
            generator.to_file (path);
        }

        public class ConfigurationSection : Object
        {
            private Map<string,Json.Node> m_cfg_props;
            private Map<string,Json.Node> m_baseline;

            construct {
                m_cfg_props = new HashMap<string,Json.Node> ();
                m_baseline = new HashMap<string,Json.Node> ();
            }

            public new Json.Node?
            get (string property_name)
            {
                if (m_cfg_props.has_key (property_name)) {
                    return m_cfg_props[property_name];    
                } else if (m_baseline.has_key (property_name)) {
                    return m_baseline[property_name];
                } else {
                    return null;
                }
                
            }

            public new void
            set (string property_name, Json.Node property_data)
            {
                m_cfg_props[property_name] = property_data;
                property_changed[property_name] (property_data); // emit signal
            }

            internal void
            set_baseline_configuration ()
            {
                foreach (var e in m_cfg_props.entries) {
                    m_baseline[e.key] = e.value;
                }
                foreach (var key in m_baseline.keys) {
                    m_cfg_props.unset (key);
                }
            }

            public void
            reset_to_default (string property_name)
            {
                if (m_baseline.has_key (property_name)) {
                    m_cfg_props.unset (property_name);
                }
            }

            internal Json.Node?
            get_changes ()
            {
                var node = new Json.Node (Json.NodeType.OBJECT);
                var obj = new Json.Object ();
                bool have_changes_flag = false;
                foreach (var e in m_cfg_props.entries) {
                    if (e.value != null) {
                        obj.set_member (e.key, e.value.copy ());
                        have_changes_flag = true;
                    }
                }
                if (have_changes_flag) {
                    node.take_object ((owned) obj);
                    return node;
                } else {
                    return null;
                }
            }

            [Signal (detailed=true)]
            public signal void property_changed (Json.Node data);


            /* *****************************************************
             * CONVENIENCE FUNCTIONS
             ******************************************************/
            
            public string?
            get_string (string property_name, string? default_value=null)
            {
                var json_node = get (property_name);
                if (json_node != null &&
                    json_node.get_value_type () == typeof(string)) {
                    return json_node.get_string ();
                } else {
                    return default_value;
                }
            }

            public int64?
            get_int (string property_name)
            {
                var json_node = get (property_name);
                if (json_node != null &&
                    json_node.get_value_type () == typeof(int64)) {
                    return json_node.get_int ();
                } else {
                    return null;
                }   
            }

            public int64
            get_int_default (string property_name, int64 default_value)
            {
                var json_node = get (property_name);
                if (json_node != null &&
                    json_node.get_value_type () == typeof(int64)) {
                    return json_node.get_int ();
                } else {
                    return default_value;
                }
            }

            public bool?
            get_boolean (string property_name)
            {
                var json_node = get (property_name);
                if (json_node != null &&
                    json_node.get_value_type () == typeof(bool)) {
                    return json_node.get_boolean ();
                } else {
                    return null;
                }   
            }

            public bool
            get_boolean_default (string property_name, bool default_value)
            {
                var json_node = get (property_name);
                if (json_node != null &&
                    json_node.get_value_type () == typeof(bool)) {
                    return json_node.get_boolean ();
                } else {
                    return default_value;
                }
            }

            public void
            set_string (string property_name, string val)
            {
                var node = new Json.Node (Json.NodeType.VALUE);
                node.set_string (val);
                set (property_name, node);
            }

            public void
            set_int (string property_name, int64 val)
            {
                var node = new Json.Node (Json.NodeType.VALUE);
                node.set_int (val);
                set (property_name, node);
            }

            public void
            set_boolean (string property_name, bool val)
            {
                var node = new Json.Node (Json.NodeType.VALUE);
                node.set_boolean (val);
                set (property_name, node);
            }
        }
    }
}
