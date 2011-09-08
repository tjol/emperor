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
using Gee;

namespace Emperor.Application {
    
    public class PrefsMachine : Object
    {
        private string prefs_file_path { get; set; }
        private HashMap<string,Variant> prefs { get; set; }

        public PrefsMachine ()
        {
            prefs_file_path = "%s/emperor/prefs.xml".printf(Environment.get_user_config_dir ());
            prefs = new HashMap<string,Variant> ();
        }

        public bool load ()
        {
            
            Xml.Doc* document = Xml.Parser.read_file (prefs_file_path);
            if (document == null) {
                return false;
            }

            Xml.Node* root = document->get_root_element ();
            if (root->name != "emperor-prefs") {
                return false;
            }
            for (Xml.Node *node = root->children; node != null; node = node->next) {
                if (node->type == Xml.ElementType.ELEMENT_NODE) {
                    if (node->name == "pref") {
                        var key = node->get_prop ("name");
                        if (key == null) {
                            // be forgiving.
                            continue;
                        }
                        var value_str = node->get_content();
                        try {
                            var value_v = Variant.parse (null, value_str);

                            if (value_v != null) {
                                prefs[key] = value_v;
                            }
                        } catch (Error e) {
                            // doesn't matter.
                        }
                    } else {
                        // be forgiving.
                        continue;
                    }
                }
            }

            delete document;

            return true;

        }

        public void save ()
        {
            var doc = new Xml.Doc ("1.0");

            var root = doc.new_node (null, "emperor-prefs");
            doc.set_root_element (root);

            foreach (var e in prefs.entries) {
                var val_string = e.value.print(true);

                var pref_node = doc.new_raw_node (null, "pref", val_string);
                pref_node->set_prop ("name", e.key);

                root->add_child (pref_node);
            }
            
            var prefs_file = File.new_for_path (prefs_file_path);
            var prefs_dir = prefs_file.get_parent ();
            if (!prefs_dir.query_exists()) {
                try {
                    prefs_dir.make_directory_with_parents();
                } catch (Error e) {
                    stderr.printf("Failed to create directory: %s (%s)\n",
                        prefs_dir.get_parse_name(), e.message);
                }
            }
            var file_stream = FileStream.open (prefs_file_path, "w");
            if (file_stream != null) {
                doc.dump_format (file_stream, true);
            } else {
                stderr.printf("Failed to open file for writing: %s\n", prefs_file_path);
            }
        }

        public Variant? get_variant (string name)
        {
            return prefs[name];
        }

        public int32 get_int32 (string name, int32 fallback)
        {
            var v = prefs[name];
            if (v == null || !v.is_of_type (VariantType.INT32)) {
                return fallback;
            } else {
                return v.get_int32 ();
            }
        }

        public bool get_boolean (string name, bool fallback)
        {
            var v = prefs[name];
            if (v == null || !v.is_of_type (VariantType.BOOLEAN)) {
                return fallback;
            } else {
                return v.get_boolean ();
            }
        }

        public string get_string (string name, string? fallback)
        {
            var v = prefs[name];
            if (v == null || !v.is_of_type (VariantType.STRING)) {
                return fallback;
            } else {
                return v.get_string ();
            }
        }

        public void set_variant (string name, Variant v)
        {
            prefs[name] = v;
        }

        public void set_int32 (string name, int32 i)
        {
            prefs[name] = new Variant.@int32(i);
        }

        public void set_boolean (string name, bool b)
        {
            prefs[name] = new Variant.boolean(b);
        }

        public void set_string (string name, string s)
        {
            prefs[name] = new Variant.@string(s);
        }

    }

}

