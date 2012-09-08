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

namespace Emperor.App {

    /**
     * Handles modules.
     */
    public class ModuleRegistry : Object
    {
        private HashMap<string,FileInfoColumn> m_columns;
        private HashMap<string,CompareFuncWrapper> m_cmp_funcs;
        private HashMap<string,CommandWrapper> m_commands;
        private HashMap<string,ModuleInfo> m_module_info;

        private string? m_module_location;

        public EmperorCore application { get; private set; }

        public Gtk.ActionGroup actions { get; private set; }
        public AccelGroup default_accel_group { get; private set; }

        public Set<string> loaded_modules { get; private set; }

        public string[] module_search_directories { get; private set; }

        public class ModuleInfo : Object
        {
            public string name { get; construct; }
            public string display_name { get; construct; }
            public string description { get; construct; }
            public string module { get; construct; }

            public bool is_core { get; construct; }

            public Gee.Set<string> requirements { get; construct; }
            public Gee.Set<string> load_before { get; construct; }
            public Gee.Set<string> load_after { get; construct; }

            public string module_info_file_path { get; construct; }

            internal
            ModuleInfo.from_keyfile (string name, KeyFile keys, string path)
                throws KeyFileError
            {
                bool is_core = false;
                if (keys.has_key ("Emperor Module", "IsCore")) {
                    is_core = keys.get_boolean ("Emperor Module", "IsCore");
                }

                var requirements = new Gee.HashSet<string> ();
                if (keys.has_key ("Emperor Module", "Requires")) {
                    string[] requires_a = (owned) keys.get_string_list ("Emperor Module", "Requires");
                    foreach (var requirement in requires_a) {
                        requirements.add (requirement);
                    }
                }

                var load_before = new Gee.HashSet<string> ();
                if (keys.has_key ("Emperor Module", "PleaseLoadBefore")) {
                    string[] before_a = (owned) keys.get_string_list ("Emperor Module", "PleaseLoadBefore");
                    foreach (var before_this in before_a) {
                        load_before.add (before_this);
                    }
                }

                var load_after = new Gee.HashSet<string> ();
                if (keys.has_key ("Emperor Module", "PleaseLoadAfter")) {
                    string[] after_a = (owned) keys.get_string_list ("Emperor Module", "PleaseLoadAfter");
                    foreach (var after_this in after_a) {
                        load_after.add (after_this);
                    }
                }

                Object ( name : name,
                         module : keys.get_string ("Emperor Module", "Module"),
                         display_name : keys.get_locale_string ("Emperor Module", "Name"),
                         description : keys.get_locale_string ("Emperor Module", "Description"),
                         is_core : is_core,
                         requirements : requirements,
                         load_before : load_before,
                         load_after : load_after,
                         module_info_file_path : path );
            }
        }

        public ModuleRegistry (EmperorCore app, string? module_location)
        {
            m_columns = new HashMap<string,FileInfoColumn>();
            m_cmp_funcs = new HashMap<string,CompareFuncWrapper>();
            m_commands = new HashMap<string,CommandWrapper>();
            m_module_location = module_location;
            m_module_info = new HashMap<string,ModuleInfo>();

            application = app;
            actions = new Gtk.ActionGroup ("emperor");
            default_accel_group = new AccelGroup ();
            loaded_modules = new HashSet<string> ();
            if (m_module_location != null) {
                module_search_directories = { m_module_location, Config.MODULE_DIR };
            } else {
                module_search_directories = { Config.MODULE_DIR };
            }
        }

        public ModuleInfo
        get_module_info (string module_name)
            throws ConfigurationError
        {
            if (m_module_info.has_key (module_name)) {
                return m_module_info[module_name];
            } else {
                string path;
                var kf = new KeyFile ();
                
                ModuleInfo mi;
                try {
                    kf.load_from_dirs ("%s.module".printf(module_name),
                                       module_search_directories,
                                       out path,
                                       KeyFileFlags.NONE);
                    mi = new ModuleInfo.from_keyfile (module_name, kf, path);
                } catch (KeyFileError kferr) {
                    if (kferr is KeyFileError.NOT_FOUND) {
                        throw new ConfigurationError.MODULE_ERROR (
                                        _("Module “%s” not found.")
                                                .printf(module_name));
                    } else {
                        throw new ConfigurationError.MODULE_ERROR (kferr.message);
                    }
                } catch (FileError ferr) {
                    throw new ConfigurationError.MODULE_ERROR (ferr.message);
                }

                m_module_info[module_name] = mi;
                return mi;
            }
        }

        /**
         * Register a FileInfoColumn. It can then be used in the UI
         * configuration.
         */
        public void register_column (string name, FileInfoColumn col)
        {
            m_columns[name] = col;
        }

        /**
         * Get a FileInfoColumn previously set with {@link register_column}
         */
        public FileInfoColumn? get_column (string name)
        {
            if (m_columns.has_key(name)) {
                return m_columns[name];
            } else {
                return null;
            }
        }

        /**
         * Register a sorting function. It can then be used in the UI
         * configuration.
         */
        public void register_sort_function (string name, owned CompareFunc func)
        {
            m_cmp_funcs[name] = new CompareFuncWrapper((owned) func);
        }

        /**
         * Get a sorting function registered with {@link register_sort_function}
         */
        public unowned CompareFunc? get_sort_function (string name)
        {
            if (m_cmp_funcs.has_key(name)) {
                return m_cmp_funcs[name].func;
            } else {
                return null;
            }
        }

        /**
         * Register a Command. This is currently useless.
         */
        public void register_command (string name, owned Command command)
        {
            m_commands[name] = new CommandWrapper ((owned) command);
        }

        /**
         * Get a command registered with {@link register_command}.
         */
        public unowned Command? get_command (string name)
        {
            if (m_commands.has_key(name)) {
                return m_commands[name].func;
            } else {
                return null;
            }
        }

        /**
         * Create, register, and return, a new Gtk Action object.
         */
        public Gtk.Action new_action (string name)
        {
            var action = new Gtk.Action (name, null, null, null);
            register_action (action);
            return action;
        }

        /**
         * Register an existing Gtk.Action.
         */
        public void register_action (Gtk.Action action)
        {
            action.set_accel_group (default_accel_group);
            actions.add_action (action);
        }

        internal void
        load_config_modules ()
            throws ConfigurationError
        {
            var modules_cfg_node = application.config["core"]["modules"];
            if (modules_cfg_node.get_node_type () != Json.NodeType.ARRAY) {
                throw new ConfigurationError.INVALID_ERROR (_("Module configuration is invalid."));
            }

            var module_list = new Gee.LinkedList<string> ();

            foreach (var module_node in modules_cfg_node.get_array ().get_elements ()) {
                if (module_node.get_value_type () != typeof(string)) {
                    throw new ConfigurationError.INVALID_ERROR (_("Module configuration is invalid."));       
                }
                module_list.add (module_node.get_string ());
            }

            load_modules (module_list);
        }

        internal void
        load_modules (Iterable<string> modules)
            throws ConfigurationError
        {
            var mod_indices = new HashMap<string,int> ();
            var modlst = new LinkedList<string> ();
            int i = 0;
            foreach (var m in modules) {
                modlst.add (m);
                mod_indices[m] = i;
                ++ i;
            }

            // Now rearrange the list of modules to conform to the dependencies
            // and requested order.
            bool changed_something = false;
            int remaining_passes = 3;
            do {
                changed_something = false;
                var new_list = new LinkedList<string> ();
                new_list.add_all (modlst);
                i = 0;
                foreach (var modname in modlst) {
                    var modinfo = get_module_info (modname);
                    
                    foreach (var requirement in modinfo.requirements) {
                        if (! mod_indices.has_key (requirement)) {
                            // Add it!
                            move_item_to (requirement, i, new_list.size, new_list, mod_indices);
                            changed_something = true;
                            remaining_passes = 3;
                        } else if (mod_indices[requirement] > i) {
                            move_item_to (requirement, i, mod_indices[requirement], new_list, mod_indices);
                            changed_something = true;
                        }
                    }

                    foreach (var before_this in modinfo.load_before) {
                        if (mod_indices.has_key (before_this)) {
                            if (mod_indices[before_this] < i) {
                                move_item_to (modname, mod_indices[before_this], i, new_list, mod_indices);
                                changed_something = true;
                            }
                        }
                    }

                    foreach (var after_this in modinfo.load_after) {
                        if (mod_indices.has_key (after_this)) {
                            if (mod_indices[after_this] > i) {
                                move_item_to (modname, mod_indices[after_this]+1, i, new_list, mod_indices);
                                changed_something = true;
                            }
                        }
                    }

                    ++ i;
                }
                modlst = new_list;
                -- remaining_passes;
            } while (changed_something && remaining_passes > 0);

            // okay - GO
            foreach (var module_to_be_loaded in modlst) {
                load_module (module_to_be_loaded);
            }
        }

        private void
        move_item_to<T> (T item, int idx, int oldidx, Gee.List<T> lst, Map<T,int> indexmap)
        {
            lst.remove (item);
            lst.insert (idx, item);
            foreach (var other_item in lst) {
                if (indexmap[other_item] >= idx && indexmap[other_item] < oldidx) {
                    indexmap[other_item] = indexmap[other_item] + 1;
                } else if (indexmap[other_item] > oldidx && indexmap[other_item] <= idx) {
                    indexmap[other_item] = indexmap[other_item] - 1;
                }
            }
            indexmap[item] = idx;
        }

        /**
         * Signature of the public function "load_module" every module
         * must expose.
         */
        public delegate void LoadFunction (ModuleRegistry reg); 

        /**
         * Load a module.
         *
         * @param name Name of the module file as installed in the module \
         *              directory. Need not include '.so' suffix.
         */
        private void
        load_module (string name)
            throws ConfigurationError
        {
            var minfo = get_module_info (name);
            // Consider this loaded from now on instead of properly dealing with dependency cycles.
            loaded_modules.add (name);
            foreach (var requirement in minfo.requirements) {
                if (!(requirement in loaded_modules)) {
                    load_module (requirement);
                }
            }

            string filename;
            if (m_module_location != null) {
                filename = Module.build_path (m_module_location, name);
            } else {
                filename = Module.build_path (Config.MODULE_DIR, name);
            }
            var module = Module.open (filename, ModuleFlags.BIND_LAZY);
            if (module == null) {
                throw new ConfigurationError.MODULE_ERROR (Module.error());
            }

            void* loadp;
            if (module.symbol("load_module", out loadp)) {
                unowned LoadFunction load = (LoadFunction) loadp;
                load (this);
                // I could store the Module object, but this is so much easier.
                module.make_resident ();
            } else {
                throw new ConfigurationError.MODULE_ERROR (Module.error());
            }
        }

        /**
         * Utility class needed because Vala does not yet fully support using
         * delegates as generic type parametres.
         */
        internal class CompareFuncWrapper : Object
        {
            public CompareFuncWrapper (owned CompareFunc f) {
                m_func = (owned) f;
            }
            CompareFunc m_func;
            public unowned CompareFunc func {
                get {
                    return m_func;
                }
            }
        }

        /**
         * Utility class needed because Vala does not yet fully support using
         * delegates as generic type parametres.
         */
        internal class CommandWrapper : Object
        {
            public CommandWrapper (owned Command f) {
                m_func = (owned) f;
            }
            Command m_func;
            public unowned Command func {
                get {
                    return m_func;
                }
            }
        }


    }

}


