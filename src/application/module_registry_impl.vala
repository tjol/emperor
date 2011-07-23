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

    public class ModuleRegistryImpl : Object, ModuleRegistry
    {
        private HashMap<string,FileInfoColumn> m_columns;
        private HashMap<string,CompareFuncWrapper> m_cmp_funcs;

        public ModuleRegistryImpl ()
        {
            m_columns = new HashMap<string,FileInfoColumn>();
            m_cmp_funcs = new HashMap<string,CompareFuncWrapper>();
        }

        public void register_column (string name, FileInfoColumn col)
        {
            m_columns[name] = col;
        }

        public FileInfoColumn? get_column (string name)
        {
            if (m_columns.has_key(name)) {
                return m_columns[name];
            } else {
                return null;
            }
        }

        public void register_sort_function (string name, CompareFunc func)
        {
            m_cmp_funcs[name] = new CompareFuncWrapper(func);
        }

        public CompareFunc? get_sort_function (string name)
        {
            if (m_cmp_funcs.has_key(name)) {
                return m_cmp_funcs[name].func;
            } else {
                return null;
            }
        }

        internal void handle_config_xml_nodes (Xml.Node* parent)
                        throws ConfigurationError
        {
            for (Xml.Node* node = parent->children; node != null; node = node->next) {
                switch (parent->name) {
                case "modules":
                    if (node->type == Xml.ElementType.ELEMENT_NODE) {
                        if (node->name == "load") {
                            var module_name = node->get_prop("name");
                            load_module (module_name);
                        }
                    }
                    break;
                default:
                    throw new ConfigurationError.INVALID_ERROR(
                                "Unexpected element: " + parent->name);
                }
            }
        }

        public delegate void LoadFunction (ModuleRegistry reg); 

        private void load_module (string name)
                    throws ConfigurationError
        {
            var filename = Module.build_path ("modules/", name);
            var module = Module.open (filename, ModuleFlags.BIND_LAZY);
            if (module == null) {
                throw new ConfigurationError.MODULE_ERROR (Module.error());
            }

            void* loadp;
            if (module.symbol("load_module", out loadp)) {
                var load = (LoadFunction) loadp;
                load (this);
                // I could store the Module object, but this is so much easier.
                module.make_resident ();
            } else {
                throw new ConfigurationError.MODULE_ERROR (Module.error());
            }
        }

        internal class CompareFuncWrapper : Object {
            public CompareFuncWrapper (CompareFunc f) {
                this.func = f;
            }
            public CompareFunc func { get; private set; }
        }

    }

}


