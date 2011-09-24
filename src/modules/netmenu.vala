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
using Emperor;
using Emperor.Application;
using Gee;

namespace Emperor.Modules {

    public class NetMenuModule : Object
    {
        public static void register (ModuleRegistry reg)
        {
            Gtk.Action action;

            var app = reg.application;
            var module = new NetMenuModule (app);

            app.ui_manager.get_menu (_("_Net"), 7);

            // Browse network
            action = reg.new_action ("netmenu/browse");
            action.label = _("Browse Network");
            action.icon_name = "network-workgroup";
            action.activate.connect (module.browse_network);
            app.ui_manager.add_action_to_menu (_("_Net"), action, 3);

            action = reg.new_action ("netmenu/new-connection");
            action.label = _("Connect to Server");
            action.icon_name = "gtk-connect";
            action.activate.connect (module.new_connection);
            app.ui_manager.add_action_to_menu (_("_Net"), action, 2);

            action = reg.new_action ("netmenu/server-list");
            action.label = _("Network Servers");
            action.activate.connect (module.display_server_list);
            app.ui_manager.add_action_to_menu (_("_Net"), action, 1);

            module.@ref ();
        }

        public NetMenuModule (EmperorCore app)
        {
            Object ( application : app,
                     server_list_file_path :
                            "%s/%s/%s".printf (Environment.get_user_config_dir (),
                                          Config.PACKAGE_NAME,
                                          "network_servers.xml") );
        }

        public struct SavedServer
        {
            string name;
            string uri;
            string? user;
            string? domain;
            bool anon;
        }

        public EmperorCore application { get; construct; }
        public ArrayList<SavedServer?> saved_servers { get; private set; }
        public string server_list_file_path { get; construct; }

        construct {
            // Load old saved servers.
            saved_servers = new ArrayList<SavedServer?> ();

            Xml.Doc* document = Xml.Parser.read_file (server_list_file_path);
            if (document == null) {
                return;
            }
            Xml.Node* root = document->get_root_element ();
            if (root->name == "emperor-network-server-list") {
                for (Xml.Node* node = root->children; node != null; node = node->next) {
                    if (node->type != Xml.ElementType.ELEMENT_NODE) {
                        continue;
                    }
                    if (node->name == "server") {
                        var name = node->get_prop ("name");
                        var uri = node->get_prop ("uri");
                        var user = node->get_prop ("user");
                        var domain = node->get_prop ("domain");
                        var anon_s = node->get_prop ("anon");
                        if (name == null || uri == null) {
                            // be forgiving.
                            continue;
                        }
                        bool anon = false;
                        if (anon_s == "true") {
                            anon = true;
                        }
                        var server = SavedServer () {
                                name = name, 
                                uri = uri,
                                user = user,
                                domain = domain,
                                anon = anon
                            };
                        saved_servers.add (server);
                    }
                }
            }
            delete document;
        }

        public void save_servers ()
        {
            var document = new Xml.Doc ("1.0");
            var root = document.new_node (null, "emperor-network-server-list");
            document.set_root_element (root);

            foreach (var server in saved_servers) {
                var server_node = document.new_raw_node (null, "server");
                server_node->set_prop ("name", server.name);
                server_node->set_prop ("uri", server.uri);
                if (server.domain != null) 
                    server_node->set_prop ("domain", server.domain);
                if (server.user != null) 
                    server_node->set_prop ("user", server.user);
                if (server.anon)
                    server_node->set_prop ("anon", "true");

                root->add_child (server_node);
            }

            var server_list_file = File.new_for_path (server_list_file_path);
            var server_list_dir = server_list_file.get_parent ();
            if (!server_list_dir.query_exists()) {
                try {
                    server_list_dir.make_directory_with_parents();
                } catch (Error e) {
                    stderr.printf("Failed to create directory: %s (%s)\n",
                        server_list_dir.get_parse_name(), e.message);
                }
            }
            var file_stream = FileStream.open (server_list_file_path, "w");
            if (file_stream != null) {
                document.dump_format (file_stream, true);
            } else {
                stderr.printf("Failed to open file for writing: %s\n", server_list_file_path);
            }
        }

        public class ConnectionDialog : Dialog
        {
            public FilePane pane { get; construct; }
            public Entry connection_name { get; construct; }
            public Entry host_name { get; construct; }
            public SpinButton port_number { get; construct; }
            public ComboBoxText protocol { get; construct; }
            public Entry location { get; construct; }
            public CheckButton anon_login { get; construct; }
            public Entry domain { get; construct; }
            public Entry user_name { get; construct; }
            public Entry password { get; construct; }
            public CheckButton remember_pw { get; construct; }

            public Label label_connection_name { get; construct; }
            public Label label_host_name { get; construct; }
            public Label label_port_number { get; construct; }
            public Label label_protocol { get; construct; }
            public Label label_location { get; construct; }
            public Label label_domain { get; construct; }
            public Label label_user { get; construct; }
            public Label label_password { get; construct; }

            public Grid layout_grid { get; construct; }

            public ConnectionDialog (string title, Window? parent, FilePane pane)
            {
                Object ( title : title,
                         transient_for : parent,
                         destroy_with_parent : true,
                         modal : true,
                         pane : pane,

                         connection_name : new Entry (),
                         host_name : new Entry (),
                         port_number : new SpinButton (
                                            new Adjustment (21, 1, 0xffff, 1, 1, 0),
                                            0, 0),
                         protocol : new ComboBoxText (),
                         location : new Entry (),
                         anon_login : new CheckButton.with_label (_("Anonymous login")),
                         domain : new Entry (),
                         user_name : new Entry (),
                         password : new Entry (),
                         remember_pw : new CheckButton.with_label (_("Remember password")),

                         label_connection_name : new Label (_("Title:")),
                         label_host_name : new Label (_("Server:")),
                         label_port_number : new Label (_("Port:")),
                         label_protocol : new Label (_("Protocol:")),
                         label_location : new Label (_("Directory:")),
                         label_domain : new Label (_("Login Domain:")),
                         label_user : new Label (_("User Name:")),
                         label_password : new Label (_("Password:")),

                         layout_grid : new Grid () );
                         
            }

            construct {
                // Widget configuration.
                protocol.append ("sftp", _("SSH/SFTP"));
                protocol.append ("ftp", _("FTP"));
                protocol.append ("smb", _("Windows share (smb)"));
                protocol.append ("http", _("WebDAV (HTTP)"));
                protocol.append ("https", _("Secure WebDAV (HTTPS)"));

                password.visibility = false;

                // Build dialog.
                var box = get_content_area () as Box;
                box.add (layout_grid);

                layout_grid.attach (label_connection_name, 0, 0, 1, 1);
                layout_grid.attach (connection_name, 1, 0, 1, 1);
                layout_grid.attach (label_host_name, 0, 1, 1, 1);
                var host_port_box = new HBox(false, 0);
                host_port_box.pack_start (host_name, true, true, 0);
                host_port_box.pack_start (label_port_number, false, false, 0);
                host_port_box.pack_start (port_number, false, false, 0);
                host_port_box.hexpand = true;
                layout_grid.attach (host_port_box, 1, 1, 1, 1);
                layout_grid.attach (label_protocol, 0, 2, 1, 1);
                layout_grid.attach (protocol, 1, 2, 1, 1);
                layout_grid.attach (label_location, 0, 3, 1, 1);
                layout_grid.attach (location, 1, 3, 1, 1);
                layout_grid.attach (anon_login, 1, 4, 1, 1);
                layout_grid.attach (label_domain, 0, 5, 1, 1);
                layout_grid.attach (domain, 1, 5, 1, 1);
                layout_grid.attach (label_user, 0, 6, 1, 1);
                layout_grid.attach (user_name, 1, 6, 1, 1);
                layout_grid.attach (label_password, 0, 7, 1, 1);
                layout_grid.attach (password, 1, 7, 1, 1);
                layout_grid.attach (remember_pw, 1, 8, 1, 1);

                layout_grid.row_spacing = 2;
                layout_grid.column_spacing = 2;
                label_port_number.set_padding (5, 0);
                layout_grid.margin = 20;

                label_connection_name.set_alignment (0, 0);
                label_connection_name.set_size_request (100, 5);
                label_host_name.set_alignment (0, 0);
                label_protocol.set_alignment (0, 0);
                label_location.set_alignment (0, 0);
                label_domain.set_alignment (0, 0);
                label_user.set_alignment (0, 0);
                label_password.set_alignment (0, 0);

                connection_name.activates_default = true;
                host_name.activates_default = true;
                location.activates_default = true;
                user_name.activates_default = true;
                password.activates_default = true;
                location.text = "/";

                protocol.changed.connect (protocol_changed);
                host_name.changed.connect (update_login_sensitivity);
                anon_login.toggled.connect (update_login_sensitivity);
                password.changed.connect (update_login_sensitivity);

                response.connect (on_response);
            }

            public signal void set_default_button_sesitivity (bool sensitivity);

            public void add_buttons_connect_cancel ()
            {
                add_button (Stock.CANCEL, ResponseType.CANCEL);
                var connect_button = (Button) add_button (Stock.CONNECT, 1);
                set_default_response (1);

                set_default_button_sesitivity.connect ((s) => {
                        connect_button.sensitive = s;
                    });
            }

            private void protocol_changed ()
            {
                var uri_scheme = protocol.active_id;

                switch (uri_scheme) {
                case "sftp":
                    port_number.set_value (22);
                    port_number.set_sensitive (true);
                    anon_login.hide ();
                    label_domain.hide ();
                    domain.hide ();
                    label_user.show ();
                    user_name.show ();
                    label_password.show ();
                    password.show ();
                    remember_pw.show ();
                    break;
                case "ftp":
                    port_number.set_value (21);
                    port_number.set_sensitive (true);
                    anon_login.show ();
                    label_domain.hide ();
                    domain.hide ();
                    label_user.show ();
                    user_name.show ();
                    label_password.show ();
                    password.show ();
                    remember_pw.show ();
                    break;
                case "smb":
                    port_number.set_sensitive (false);
                    anon_login.hide ();
                    label_domain.show ();
                    domain.show ();
                    label_user.show ();
                    user_name.show ();
                    label_password.show ();
                    password.show ();
                    remember_pw.show ();
                    break;
                case "http":
                    port_number.set_value (80);
                    port_number.set_sensitive (true);
                    anon_login.hide ();
                    label_domain.hide ();
                    domain.hide ();
                    label_user.show ();
                    user_name.show ();
                    label_password.show ();
                    password.show ();
                    remember_pw.show ();
                    break;
                case "https":
                    port_number.set_value (443);
                    port_number.set_sensitive (true);
                    anon_login.hide ();
                    label_domain.hide ();
                    domain.hide ();
                    label_user.show ();
                    user_name.show ();
                    label_password.show ();
                    password.show ();
                    remember_pw.show ();
                    break;
                }

                update_login_sensitivity ();
            }

            private void update_login_sensitivity ()
            {
                if (anon_login.visible && anon_login.active) {
                    user_name.sensitive = false;
                    password.sensitive = false;
                    remember_pw.sensitive = false;
                } else {
                    user_name.sensitive = true;
                    password.sensitive = true;
                    remember_pw.sensitive = (password.text != "");
                }
                set_default_button_sesitivity (host_name.text != "");
            }

            private void on_response (int response_id)
            {
                if (response_id == 1) { // Connect.
                    var uri = get_uri ();

                    var mnt_op = new MountOperationWithDefaults (this.transient_for,
                                    (anon_login.visible && anon_login.active),
                                    (domain.visible ? domain.text : ""),
                                    (user_name.visible ? user_name.text : ""),
                                    (password.visible ? password.text : ""),
                                    (remember_pw.active ? PasswordSave.PERMANENTLY
                                                        : PasswordSave.NEVER));

                    hide ();

                    pane.chdir.begin (File.new_for_uri (uri), null, mnt_op);

                    if (connection_name.text != "") {
                        var user_nil = (user_name.visible && user_name.text != ""
                                            ? user_name.text : null);
                        var domain_nil = (domain.visible && domain.text != ""
                                            ? domain.text : null);
                        var use_anon = (anon_login.visible && anon_login.active);
                        var server_list_entry = SavedServer () {
                                name = connection_name.text,
                                uri = uri,
                                user = user_nil,
                                domain = domain_nil,
                                anon = use_anon
                            };
                        new_server (server_list_entry);
                    }

                    destroy ();

                } else if (response_id == ResponseType.CANCEL
                            || response_id == ResponseType.DELETE_EVENT) {
                    destroy ();
                }
            }
            
            public string get_uri ()
            {
                var path = location.text;
                if (! path.has_prefix("/") ) {
                    path = "/" + path;
                }
                string scheme = protocol.active_id;
                uint port = (uint) port_number.@value;
                bool port_is_standard = 
                    (scheme == "sftp" && port == 22) ||
                    (scheme == "ftp" && port == 21) ||
                    (scheme == "smb") ||
                    (scheme == "http" && port == 80) ||
                    (scheme == "https" && port == 443);

                var host = host_name.text;
                if (scheme == "sftp" && user_name.text != ""
                    && user_name.text != Environment.get_user_name()) {
                    host = "%s@%s".printf (user_name.text, host);
                }
                    
                string uri;
                if (port_is_standard) {
                    uri = "%s://%s%s".printf (scheme, host, path);
                } else {
                    uri = "%s://%s:%u%s".printf (scheme, host, port, path);
                }

                return uri;
            }

            public signal void new_server (SavedServer server);

            public override void show ()
            {
                layout_grid.show_all ();

                protocol.set_active_id ("ftp");
                anon_login.active = true;

                base.show ();

                host_name.grab_focus ();
            }
        }

        public class MountOperationWithDefaults : GLib.MountOperation
        {
            public Gtk.MountOperation chained_mnt_op { get; construct; }

            private bool m_returned_password;

            public MountOperationWithDefaults (Window? parent_window,
                        bool anonymous, string? domain, string? username, string? password, 
                        PasswordSave pw_save)
            {
                Object ( chained_mnt_op : new Gtk.MountOperation (parent_window),
                         domain : domain != null ? domain : "",
                         anonymous : anonymous,
                         username : username != null ? username : "",
                         password : password != null ? password : "",
                         password_save : pw_save );
            }
            
            construct {
                m_returned_password = false;

                chained_mnt_op.bind_property ("anonymous", this, "anonymous", 0);
                chained_mnt_op.bind_property ("choice", this, "choice", 0);
                chained_mnt_op.bind_property ("domain", this, "domain", 0);
                chained_mnt_op.bind_property ("password", this, "password", 0);
                chained_mnt_op.bind_property ("password-save", this, "password-save", 0);
                chained_mnt_op.bind_property ("username", this, "username", 0);

                aborted.connect (() => { 
                        Signal.stop_emission_by_name (this, "aborted");
                        chained_mnt_op.aborted();
                    });
                ask_question.connect ((m,c) => {
                        Signal.stop_emission_by_name (this, "ask-question");
                        chained_mnt_op.ask_question (m,c);
                    });
                show_processes.connect ((m,p,c) => {
                        Signal.stop_emission_by_name (this, "show-processes");
                        chained_mnt_op.show_processes (m,p,c);
                    });
                chained_mnt_op.reply.connect ((r) => { reply (r); });


                ask_password.connect (on_ask_password);
            }

            private void on_ask_password (string message, string default_user,
                                          string default_domain, AskPasswordFlags flags)
            {
                if ((!m_returned_password) && (anonymous || username != "")) {
                    m_returned_password = true;
                    // all the properties should already be set. Go.
                    reply (MountOperationResult.HANDLED);
                } else {
                    chained_mnt_op.ask_password (message, username, domain, flags);
                }
                Signal.stop_emission_by_name (this, "ask-password");
            }
        }

        public class ServerListWindow : Window
        {
            public FilePane file_pane { get; construct; }
            public ArrayList<SavedServer?> saved_servers { get; construct; }

            public TreeView server_tree { get; private set; }
            public ListStore server_list_store { get; private set; }

            public signal void save_servers ();

            public ServerListWindow (Window? parent, FilePane pane,
                                     ArrayList<SavedServer?> saved_servers)
            {
                Object ( transient_for : parent,
                         file_pane : pane,
                         title : _("Network Servers"),
                         saved_servers : saved_servers );
            }

            construct {
                server_tree = new TreeView ();
                server_tree.headers_visible = false;

                server_list_store = new ListStore (4, typeof(string),
                                                      typeof(SavedServer),
                                                      typeof(int),
                                                      typeof(string));
                // Fill the ListStore with the contents of saved_servers
                int idx = 0;
                foreach (var server in saved_servers) {
                    add_server_to_liststore (server, idx);
                    idx ++;
                }
                
                var main_hbox = new HBox (false, 0);
                add (main_hbox);

                server_tree.set_model (server_list_store);

                var col = new TreeViewColumn ();
                var icon_renderer = new CellRendererPixbuf ();
                var name_renderer = new CellRendererText ();
                col.pack_start (icon_renderer, false);
                col.pack_start (name_renderer, true);
                col.set_attributes (icon_renderer, "icon-name", 3);
                col.set_attributes (name_renderer, "text", 0);

                server_tree.append_column (col);
                server_tree.row_activated.connect (server_row_activated);
                main_hbox.pack_start (server_tree, true, true, 2);

                var buttons = new VBox (false, 2);
                var connect_button = new Button.from_stock (Stock.CONNECT);
                var new_button = new Button.with_mnemonic (_("_New Connection"));
                var edit_button = new Button.from_stock (Stock.EDIT);
                var delete_button = new Button.from_stock (Stock.DELETE);
                var cancel_button = new Button.from_stock (Stock.CANCEL);

                connect_button.clicked.connect (connect_to_selected);
                new_button.clicked.connect (new_connection);
                edit_button.clicked.connect (edit_server);
                delete_button.clicked.connect (delete_selected_server);
                cancel_button.clicked.connect (() => { destroy (); });

                buttons.pack_start (connect_button, false, false, 2);
                buttons.pack_start (new_button, false, false, 2);
                buttons.pack_start (edit_button, false, false, 2);
                buttons.pack_start (delete_button, false, false, 2);
                buttons.pack_end (cancel_button, false, false, 2);

                main_hbox.pack_start (buttons, false, false, 2);

                set_default_size (500, 300);
                key_press_event.connect ((e) => {
                        if (e.keyval == Gdk.KeySym.Escape) {
                            destroy ();
                            return true;
                        }
                        return false;
                    });
            }

            private SavedServer? get_selected_server ()
            {
                TreePath path;

                server_tree.get_cursor (out path, null);
                return get_server_at_path (path);
            }

            private SavedServer? get_server_at_path (TreePath path)
            {
                TreeIter iter;
                Value saved_server_value;

                server_list_store.get_iter (out iter, path);
                server_list_store.get_value (iter, 1, out saved_server_value);

                return (SavedServer?) saved_server_value.get_boxed();
            }

            public void connect_to_selected ()
            {
                connect_to (get_selected_server());
            }

            public void connect_to (SavedServer server)
            {
                var mnt_op = new MountOperationWithDefaults (this.transient_for,
                                    server.anon,
                                    server.domain,
                                    server.name,
                                    "",
                                    PasswordSave.NEVER);

                file_pane.chdir.begin (File.new_for_uri (server.uri), null, mnt_op);

                destroy ();
            }
            
            private void server_row_activated (TreePath path, TreeViewColumn col)
            {
                connect_to (get_server_at_path (path));
            }

            public void new_connection ()
            {
                var dialog = new ConnectionDialog (_("New Connection"), this,
                                                   file_pane);

                var connect_button = (Button) dialog.add_button (Stock.CONNECT, 3);
                dialog.add_button (Stock.CANCEL, ResponseType.CANCEL);
                var save_button = (Button) dialog.add_button (Stock.SAVE, 2);
                dialog.set_default_response (2);

                dialog.set_default_button_sesitivity.connect ((s) => {
                        save_button.sensitive = s;
                        connect_button.sensitive = s;
                    });

                dialog.new_server.connect (add_server);

                var this_window = this;

                dialog.response.connect ((id) => {
                        if (id == 2) { // Save
                            connection_dialog_save (dialog, null);
                        } else if (id == 3) { // Connect.
                            // Handle connect as usual, but take the server list
                            // out of the equasion first.
                            dialog.transient_for = this_window.transient_for;
                            this_window.destroy ();
                            dialog.response (1);
                        }
                    });
                dialog.run ();
            }

            public void edit_server ()
            {
                TreePath path;

                server_tree.get_cursor (out path, null);

                var dialog = new ConnectionDialog (_("Edit Server"), this,
                                                   file_pane);

                var connect_button = (Button) dialog.add_button (Stock.CONNECT, 3);
                dialog.add_button (Stock.CANCEL, ResponseType.CANCEL);
                var save_button = (Button) dialog.add_button (Stock.SAVE, 2);
                dialog.set_default_response (2);

                dialog.set_default_button_sesitivity.connect ((s) => {
                        save_button.sensitive = s;
                        connect_button.sensitive = s;
                    });

                dialog.new_server.connect ((server) => {
                        change_server (server, path);
                    });

                var this_window = this;

                dialog.response.connect ((id) => {
                        if (id == 2) { // Save
                            connection_dialog_save (dialog, path);
                        } else if (id == 3) { // Connect.
                            // Handle connect as usual, but take the server list
                            // out of the equasion first.
                            dialog.transient_for = this_window.transient_for;
                            this_window.destroy ();
                            dialog.response (1);
                        }
                    });

                var old_server = get_server_at_path (path);
                dialog.connection_name.text = old_server.name;
                dialog.anon_login.active = old_server.anon;
                dialog.user_name.text = old_server.user;
                // disect URI.
                var uri_parts_1 = old_server.uri.split ("://", 2);
                dialog.protocol.active_id = uri_parts_1[0]; // scheme.
                var uri_parts_2 = uri_parts_1[1].split ("/", 2);
                if (uri_parts_2.length == 2) {
                    dialog.location.text = uri_parts_2[1];
                }
                var host_parts_1 = uri_parts_2[0].split("@", 2);
                string host;
                if (host_parts_1.length == 2) {
                    dialog.user_name.text = host_parts_1[0];
                    host = host_parts_1[1];
                } else {
                    host = host_parts_1[0];
                }
                var host_parts_2 = host.split(":", 1);
                dialog.host_name.text = host_parts_2[0];
                if (host_parts_2.length == 2) {
                    int port = int.parse(host_parts_2[1]);
                    dialog.port_number.@value = port;
                }

                dialog.run ();
            }

            internal void connection_dialog_save (ConnectionDialog dialog, TreePath? server_path)
            {
                if (dialog.connection_name.text != "") {
                    var user_nil = (dialog.user_name.visible 
                                    && dialog.user_name.text != ""
                                        ? dialog.user_name.text : null);
                    var domain_nil = (dialog.domain.visible 
                                    && dialog.domain.text != ""
                                        ? dialog.domain.text : null);
                    var use_anon = (dialog.anon_login.visible
                                        && dialog.anon_login.active);
                    var server_list_entry = SavedServer () {
                            name = dialog.connection_name.text,
                            uri = dialog.get_uri(),
                            user = user_nil,
                            domain = domain_nil,
                            anon = use_anon
                        };
                    if (server_path == null) {
                        add_server (server_list_entry);
                    } else {
                        change_server (server_list_entry, server_path);
                    }
                    dialog.destroy ();
                } else {
                    show_error_message_dialog (dialog,
                        _("Please enter a connection title."), null);
                }
            }

            public void add_server (SavedServer server)
            {
                saved_servers.add (server);
                add_server_to_liststore (server, saved_servers.size-1);
                save_servers ();
            }

            public void change_server (SavedServer server, TreePath server_path)
            {
                TreeIter iter;
                server_list_store.get_iter (out iter, server_path);
                Value idx_val;
                server_list_store.get_value (iter, 2, out idx_val);
                int idx = idx_val.get_int();
                server_list_store.@set (iter, 0, server.name,
                                              1, server);
                saved_servers[idx] = server;
                save_servers ();
            }

            private void add_server_to_liststore (SavedServer server, int idx)
            {
                TreeIter iter;
                server_list_store.append (out iter);
                server_list_store.@set (iter, 0, server.name,
                                              1, server,
                                              2, idx,
                                              3, "folder-remote", -1);
            }

            public void delete_selected_server ()
            {
                TreePath path;
                TreeIter iter;
                Value idx_val;

                server_tree.get_cursor (out path, null);
                server_list_store.get_iter (out iter, path);
                server_list_store.get_value (iter, 2, out idx_val);

                int idx = idx_val.get_int ();
                server_list_store.remove (iter);
                saved_servers.remove_at (idx);
                save_servers ();
            }
        }

        public void new_connection ()
        {
            var dialog = new ConnectionDialog (_("Connect to Server"), application.main_window,
                                               application.main_window.active_pane);
            dialog.add_buttons_connect_cancel ();
            dialog.new_server.connect (add_server);
            dialog.run ();
        }

        public void display_server_list ()
        {
            var list_wnd = new ServerListWindow (application.main_window,
                                                 application.main_window.active_pane,
                                                 saved_servers);
            list_wnd.save_servers.connect (save_servers);
            list_wnd.show_all ();
        }

        private void add_server (SavedServer server)
        {
            saved_servers.add (server);
            save_servers ();
        }

        public void browse_network ()
        {
            application.main_window.active_pane.pwd = File.new_for_uri ("network:///");
        }

    }
}

public void load_module (ModuleRegistry reg)
{
    Emperor.Modules.NetMenuModule.register (reg);
}

