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
using Emperor.App;

namespace Emperor.Modules {
    
    private Widget create_volume_toolbar (EmperorCore app, FilePane file_pane)
    {
        var tb = new VolumeToolbar (app, file_pane); 
        return (Widget) tb;
    }

    public class VolumeToolbar : HBox
    {
        private EmperorCore m_app;
        private FilePane m_pane;
        private Label m_mount_desc;
        private Button m_home_button;
        private Button m_root_button;
        private Button m_up_button;
        private Button m_vol_list_button;
        private Button m_eject_button;

        private Gtk.Menu m_volmenu;

        public VolumeToolbar (EmperorCore app, FilePane pane)
        {
            m_pane = pane;
            m_app = app;

            // set up toolbar (with buttons)
            m_mount_desc = new Label ("");
            m_root_button = new Button.with_label ("/");
            m_home_button = new Button.with_label ("~");
            m_up_button = new Button.with_label ("..");
            m_vol_list_button = new Button ();
            m_vol_list_button.image = new Image.from_file (
                            app.get_resource_file_path("downarrow.png"));
            m_eject_button = new Button ();
            m_eject_button.image = new Image.from_file (
                            app.get_resource_file_path("eject.png"));

            m_home_button.clicked.connect (go_home);
            m_root_button.clicked.connect (goto_root);
            m_up_button.clicked.connect (go_up);
            m_eject_button.clicked.connect (eject_volume);
            m_vol_list_button.clicked.connect (open_volume_list);

            pack_start (m_vol_list_button, false, false, 0);
            pack_start (m_mount_desc, true, true, 0);
            pack_end (m_up_button, false, false, 0);
            pack_end (m_root_button, false, false, 0);
            pack_end (m_home_button, false, false, 0);
            pack_end (m_eject_button, false, false, 0);

            m_pane.notify["mnt"].connect (on_new_mnt);

        }

        private void on_new_mnt (ParamSpec p)
        {
            var dir = m_pane.pwd;

            string mnt_name = null;
            string mnt_type = null;
            if (m_pane.mnt != null) {
                mnt_name = m_pane.mnt.get_name ();
                // Archives shouldn't be treated as mount points in the user interface.
                if (m_pane.mnt.can_eject() || m_pane.mnt.can_unmount() 
                    && dir.get_uri_scheme() != "archive") {
                    m_eject_button.show ();
                } else {
                    m_eject_button.hide ();
                }
            } else {
                // Look for the UNIX mount.
                try {
                    FileInfo fi = dir.query_info (FileAttribute.ID_FILESYSTEM, 0);
                    string filesystem_id = fi.get_attribute_string (FileAttribute.ID_FILESYSTEM);

                    foreach (unowned UnixMountEntry xmnt in UnixMountEntry.@get()) {
                        var mnt_point = File.new_for_path(xmnt.get_mount_path ());
                        fi = mnt_point.query_info (FileAttribute.ID_FILESYSTEM, 0);
                        var mnt_fs_id = fi.get_attribute_string (FileAttribute.ID_FILESYSTEM);
                        if (filesystem_id == mnt_fs_id) {
                            mnt_name = xmnt.get_mount_path ();
                            mnt_type = xmnt.get_fs_type ();
                            if (mnt_type != "rootfs") {
                                break;
                            }
                        }
                    }
                } catch (Error unix_err) {
                    warning (_("Error looking up UNIX mount."));
                }

                if (mnt_name == null) {
                    mnt_name = _("unknown");
                }

                // TODO: check if this mount can be user-unmounted.
                m_eject_button.hide ();
            }

            try {
                FileInfo fs_info = dir.query_filesystem_info (
                                        FileAttribute.FILESYSTEM_SIZE + "," +
                                        FileAttribute.FILESYSTEM_FREE + "," +
                                        FileAttribute.FILESYSTEM_TYPE + "," +
                                        FileAttribute.FILESYSTEM_READONLY,
                                        null);

                if (mnt_type == null) {
                    mnt_type = fs_info.get_attribute_string (FileAttribute.FILESYSTEM_TYPE);
                }

                var size = fs_info.get_attribute_uint64 (FileAttribute.FILESYSTEM_SIZE);
                var free = fs_info.get_attribute_uint64 (FileAttribute.FILESYSTEM_FREE);
                var ronly = fs_info.get_attribute_boolean (FileAttribute.FILESYSTEM_READONLY);
                var size_str = bytesize_to_string (size);
                var free_str = bytesize_to_string (free);

                if (mnt_type != null) {
                    m_mount_desc.set_markup (
                        (ronly ? _("<b>%s</b> (%s; %s of %s free; read-only)")
                              : _("<b>%s</b> (%s; %s of %s free)")).printf (
                                    _esc(mnt_name), _esc(mnt_type), free_str, size_str) );
                } else {
                    m_mount_desc.set_markup (
                        (ronly ? _("<b>%s</b> (%s of %s free; read-only)")
                              : _("<b>%s</b> (%s of %s free)")).printf (
                                    _esc(mnt_name), free_str, size_str) );
                }
            } catch (Error e) {
                m_mount_desc.set_markup ( "<b>%s</b>".printf(_esc(mnt_name)) );
            }

            m_up_button.sensitive = (m_pane.parent_dir != null);
        }

        internal void go_up ()
        {
            var parent = m_pane.parent_dir;
            if (parent != null) {
                m_pane.chdir_then_focus.begin (parent, m_pane.pwd.get_basename());
            }
        }

        internal void go_home ()
        {
            m_pane.chdir_then_focus.begin (File.new_for_path (Environment.get_home_dir()));
        }

        internal void goto_root ()
        {
            var pwd = m_pane.pwd;
            var mnt = m_pane.mnt;
            File chdir_to;
            // treat an archive as if it were a regular directory on its parent file system.
            if (pwd.get_uri_scheme() == "archive" && m_pane.parent_dir != null) {
                pwd = m_pane.parent_dir;
            }

            if (pwd.is_native() || mnt == null) {
                chdir_to = File.new_for_path ("/");
            } else {
                chdir_to = mnt.get_root();
            }

            m_pane.chdir_then_focus.begin (chdir_to);
        }

        internal void eject_volume ()
        {
            eject_volume_async.begin ();
        }

        private async void eject_volume_async ()
        {
            var mnt = m_pane.mnt;
            if (mnt == null) {
                return;
            }

            yield m_pane.chdir (File.new_for_path (Environment.get_home_dir()), null);

            try {
                if (mnt.can_eject ()) {
                    yield mnt.eject_with_operation (MountUnmountFlags.NONE,
                            new Gtk.MountOperation (m_app.main_window), null);
                } else if (mnt.can_unmount ()) {
                    yield mnt.unmount_with_operation (MountUnmountFlags.NONE,
                            new Gtk.MountOperation (m_app.main_window), null);
                } else {
                    m_pane.display_error (_("Cannot unmount “%s”.").printf (mnt.get_name));
                }
            } catch (Error umount_err) {
                m_pane.display_error (_("Error unmounting volume."));
                warning ("%s (%s)", _("Error unmounting volune."), umount_err.message);
            }
        }

        internal void open_volume_list ()
        {
            bool first;
            var vm = VolumeMonitor.get ();
            var volmenu = new Gtk.Menu ();
            ImageMenuItem menuitem;
            VolumeMenuClickHandler click_handler;
            var pwd = m_pane.pwd;

            var listed_mounts = new HashSet<string>();

            // Home directory.
            var home = File.new_for_path (Environment.get_home_dir());
            listed_mounts.add (home.get_path());
            menuitem = new ImageMenuItem ();
            menuitem.set_label (_("Home"));
            menuitem.set_image (new Image.from_icon_name (
                "user-home", IconSize.MENU));
            menuitem.set_always_show_image (true);
            
            click_handler = new VolumeMenuClickHandler (this,
                                        home, null);
            menuitem.activate.connect (click_handler.on_click);
            menuitem.destroy.connect (click_handler.unref);

            volmenu.append (menuitem);

            bool pwd_is_bookmark = false;

            foreach (var bmark in get_bookmarks ()) {
                string bm_name = null;
                Icon bm_icon = null;

                if (bmark.equal (home)) {
                    continue;
                }
                if (bmark.equal (pwd)) {
                    pwd_is_bookmark = true;
                }
                try {
                    var bm_finfo = bmark.query_info (FileAttribute.STANDARD_TYPE + "," +
                                                     FileAttribute.STANDARD_ICON + "," +
                                                     FileAttribute.STANDARD_DISPLAY_NAME,
                                                     FileQueryInfoFlags.NONE, null);
                    if (bm_finfo.get_file_type() == FileType.DIRECTORY) {
                        bm_name = bm_finfo.get_display_name ();
                        bm_icon = bm_finfo.get_icon ();
                    }
                } catch (Error e) {
                    if (bmark.is_native()) {
                        continue;
                    } else {
                        try {
                            var bm_mount = bmark.find_enclosing_mount (null);
                            if (bm_mount != null) {
                                // it's mounted, yet query failed => skip.
                                continue;
                            }
                        } catch (Error e) {
                            // fine!
                        }
                        // not mounted. Display, on a whim.
                        // get domain/port
                        var uri = bmark.get_uri ();
                        var spl1 = uri.split ("://", 2);
                        if (spl1.length < 2) continue;
                        var spl2 = spl1[1].split ("/", 2);
                        var domain_name = spl2[0];
                        bm_name = _("%s on %s").printf (bmark.get_basename(), domain_name);
                        try {
                            bm_icon = Icon.new_for_string ("folder-remote");
                        } catch {
                            warning ("Error loading remote folder icon. Is Gtk installed correctly?");
                        }
                    }
                }
                if (bm_name == null || bm_icon == null) {
                    continue;
                }

                if (bmark.is_native ()) {
                    listed_mounts.add (bmark.get_path());
                }
                menuitem = new ImageMenuItem ();
                menuitem.set_label (bm_name);
                menuitem.set_image (new Image.from_gicon (bm_icon, IconSize.MENU));
                menuitem.set_always_show_image (true);
                
                click_handler = new VolumeMenuClickHandler (this,
                                            bmark, null);
                menuitem.activate.connect ( click_handler.on_click );
                menuitem.button_press_event.connect ( click_handler.bm_right_click );
                menuitem.destroy.connect (click_handler.unref);
                
                volmenu.append (menuitem);

            }

            if (!pwd_is_bookmark && !pwd.equal(home)) {
                menuitem = new ImageMenuItem ();
                menuitem.set_label (_("Add %s to bookmarks").printf(pwd.get_basename()));
                menuitem.set_image (new Image.from_icon_name ("bookmark-new", IconSize.MENU));
                menuitem.set_always_show_image (true);
                menuitem.activate.connect ( () => {
                        add_to_bookmarks (pwd);
                    });

                volmenu.append (menuitem);
            }

            first = true;

            foreach (var mnt in vm.get_mounts ()) {
                // Don't display archive mounts. (special case)
                var root = mnt.get_root ();
                if (root.get_uri_scheme() == "archive") {
                    continue;
                }

                if (first) {
                    volmenu.append (new SeparatorMenuItem ());
                    first = false;
                }

                menuitem = new ImageMenuItem ();
                menuitem.set_label (mnt.get_name ());
                menuitem.set_image (new Image.from_gicon (
                    mnt.get_icon (), IconSize.MENU));
                menuitem.set_always_show_image (true);

                click_handler = new VolumeMenuClickHandler (this,
                                                mnt.get_root(), null);
                menuitem.activate.connect (click_handler.on_click);
                menuitem.destroy.connect (click_handler.unref);

                volmenu.append (menuitem);

                var root_path = root.get_path();
                if (root_path != null) {
                    listed_mounts.add (root_path);
                }
            }

            first = true;

            foreach (var vol in vm.get_volumes ()) {
                if (first) {
                    volmenu.append (new SeparatorMenuItem ());
                    first = false;
                }

                var vol_mnt = vol.get_mount ();
                if (vol_mnt == null) {
                    // Not mounted => not yet listed.
                    menuitem = new ImageMenuItem ();
                    menuitem.set_label (vol.get_name ());
                    menuitem.set_image (new Image.from_gicon (
                        vol.get_icon (), IconSize.MENU));
                    menuitem.set_always_show_image (true);
                    if (!vol.can_mount()) {
                        menuitem.sensitive = false;
                    }

                    click_handler = new VolumeMenuClickHandler (this,
                                (vol_mnt == null) ? null : vol_mnt.get_root(),
                                vol);
                    menuitem.activate.connect (click_handler.on_click);
                    menuitem.destroy.connect (click_handler.unref);

                    volmenu.append (menuitem);
                }
            }

            first = true;
            foreach (unowned UnixMountEntry xmnt in UnixMountEntry.@get()) {
                var path = xmnt.get_mount_path ();
                if (path in listed_mounts
                 || path.has_prefix ("/dev")
                 || path.has_prefix ("/proc")
                 || path.has_prefix ("/sys")
                 || xmnt.get_fs_type() == "fuse.gvfs-fuse-daemon"
                 || xmnt.get_fs_type() == "tmpfs") {
                    continue;
                }
                if (first) {
                    volmenu.append (new SeparatorMenuItem ());
                    first = false;
                }

                menuitem = new ImageMenuItem ();
                menuitem.set_label (path);
                menuitem.set_image (new Image.from_icon_name ("folder", IconSize.MENU));
                menuitem.set_always_show_image (true);

                click_handler = new VolumeMenuClickHandler (this,
                                            File.new_for_path(path), null);
                menuitem.activate.connect (click_handler.on_click);
                menuitem.destroy.connect (click_handler.unref);
                
                volmenu.append (menuitem);

                listed_mounts.add (path);
            }

            volmenu.show_all();
            volmenu.popup (null, null, position_volume_menu, 0, get_current_event_time());
            // Need to keep a reference to the menu around or it won't
            // be shown.
            m_volmenu = volmenu;
        }

        private Collection<File> get_bookmarks ()
        {
            var list = new ArrayList<File> ();
            var bookmarks_file = File.parse_name ("~/.gtk-bookmarks");

            try {
                var stream = new DataInputStream (bookmarks_file.read ());
                string line;
                size_t len;
                while ((line = stream.read_line (out len, null)) != null) {
                    var bmark = File.new_for_uri (line.strip ());
                    list.add (bmark);
                }
            } catch (Error e) {
                // ignore. be forgiving.
            }

            return list;

        }

        private void add_to_bookmarks (File new_bm)
        {
            var bookmarks_file = File.parse_name ("~/.gtk-bookmarks");
            try {
                var file_stream = bookmarks_file.append_to (0, null);
                var stream = new DataOutputStream (file_stream);
                stream.put_string (new_bm.get_uri());
                stream.put_string ("\n");
                file_stream.close ();
            } catch (Error e) {
                m_pane.display_error (_("Error writing to bookmarks file."));
            }
        }

        private void remove_from_bookmarks (File ex_bm)
        {
            var old_bookmarks = get_bookmarks ();
            var bookmarks_file = File.parse_name ("~/.gtk-bookmarks");
            try {
                var io_stream = bookmarks_file.replace_readwrite (null, false, 0, null);
                var stream = new DataOutputStream (io_stream.output_stream);
                foreach (var bm in old_bookmarks) {
                    if (!ex_bm.equal(bm)) {
                        stream.put_string (bm.get_uri());
                        stream.put_string ("\n");
                    }
                }
                io_stream.close ();
            } catch (Error e) {
                m_pane.display_error (_("Error writing to bookmarks file."));
            }

            m_volmenu.popdown ();
        }

        private class VolumeMenuClickHandler : Object
        {
            private VolumeToolbar m_parent;
            private Window m_wnd;
            private FilePane m_pane;
            private File? m_path;
            private Volume? m_volume;
            private Gtk.Menu? m_context_menu;

            public VolumeMenuClickHandler (VolumeToolbar parent, File? path, Volume? volume)
            {
                m_parent = parent;
                m_wnd = parent.m_app.main_window;
                m_pane = parent.m_pane;
                m_path = path;
                m_volume = volume;
                /* All uses of this class should arrange for unref to be called at
                  an appropriate time. */
                this.@ref();
            }

            public void on_click ()
            {
                if (m_path != null) {
                    m_pane.chdir_then_focus.begin (m_path);
                } else if (m_volume != null) {
                    do_mount.begin ();
                }
            }

            private async void do_mount ()
            {
                try {
                    if (yield m_volume.mount (MountMountFlags.NONE,
                                new Gtk.MountOperation (m_wnd), null)) {
                        var mnt = m_volume.get_mount ();
                        if (mnt != null) {
                            m_pane.chdir_then_focus.begin (mnt.get_root ());
                            return;
                        }
                    }
                } catch {
                    // Error displayed below anyway.
                }
                m_pane.display_error (_("Error mounting volume."));
            }

            public bool bm_right_click (Gdk.EventButton bevent)
            {
                if (bevent.type != Gdk.EventType.BUTTON_PRESS
                    || bevent.button != 3) {
                    return false;
                }

                Gtk.MenuItem menuitem;

                m_context_menu = new Gtk.Menu ();

                menuitem = new Gtk.MenuItem.with_label (_("Open"));
                menuitem.activate.connect (on_click);
                menuitem.destroy.connect (unref);
                m_context_menu.append (menuitem);
                menuitem = new Gtk.MenuItem.with_label (_("Delete bookmark"));
                menuitem.activate.connect (remove_from_bookmarks);
                m_context_menu.append (menuitem);

                m_context_menu.show_all();
                m_context_menu.popup (null, null, null, 3, bevent.time);

                return true;
            }

            private void remove_from_bookmarks ()
            {
                m_parent.remove_from_bookmarks (m_path);
            }
        }

        private void position_volume_menu (Gtk.Menu menu, out int x, out int y, out bool push_in)
        {
            int origin_x, origin_y;
            var gdkwnd = m_vol_list_button.get_window();
            gdkwnd.get_origin (out origin_x, out origin_y);

            Allocation alloc;
            m_vol_list_button.get_allocation (out alloc);

            x = origin_x + alloc.x;
            y = origin_y + alloc.y + alloc.height;
            
            push_in = false;
        }


    }

    private string _esc (string s)
    {
        return s.replace ("&", "&amp")
                .replace ("<", "&lt;")
                .replace (">", "&gt;");
    }

}

delegate Emperor.Modules.VolumeToolbar ReturnsToolbar ();


public void load_module (ModuleRegistry reg)
{
    var app = reg.application;
    app.ui_manager.add_filepane_toolbar ("volumes",
                                         Emperor.Modules.create_volume_toolbar,
                                         PositionType.TOP);
    
    // function
    ReturnsToolbar get_active_toolbar = () => {
        return (Emperor.Modules.VolumeToolbar)
            reg.application.main_window.active_pane.get_addon_toolbar ("volumes");
    };

    // set up keyboard shortcuts
    Gtk.Action action;

    app.ui_manager.get_menu (_("_Go"), 3);

    // Alt-Home = go home. As in Krusader.
    action = app.modules.new_action ("volumes/go-home");
    action.label = _("Home");
    action.set_accel_path ("<Emperor-Main>/Volumes/GoHome");
    Gtk.AccelMap.add_entry ("<Emperor-Main>/Volumes/GoHome",
                            Gdk.Key.Home, Gdk.ModifierType.MOD1_MASK);
    action.activate.connect (() => { get_active_toolbar().go_home(); });
    action.connect_accelerator ();
    app.ui_manager.add_action_to_menu (_("_Go"), action);

    // Ctrl+PgUp = go up. As in Krusader, Total Cmd, Gnome Cmd.
    action = app.modules.new_action ("volumes/go-up");
    action.label = _("Go to parent");
    action.set_accel_path ("<Emperor-Main>/Volumes/GoUp");
    Gtk.AccelMap.add_entry ("<Emperor-Main>/Volumes/GoUp",
                            Gdk.Key.Page_Up, Gdk.ModifierType.CONTROL_MASK);
    action.activate.connect (() => { get_active_toolbar().go_up(); });
    action.connect_accelerator ();
    app.ui_manager.add_action_to_menu (_("_Go"), action);

    // Ctrl+Backsp = go to root. As in Krusader. 
    action = app.modules.new_action ("volumes/goto-root");
    action.label = _("Go to root");
    action.set_accel_path ("<Emperor-Main>/Volumes/GotoRoot");
    Gtk.AccelMap.add_entry ("<Emperor-Main>/Volumes/GotoRoot",
                            Gdk.Key.BackSpace, Gdk.ModifierType.CONTROL_MASK);
    action.activate.connect (() => { get_active_toolbar().goto_root(); });
    action.connect_accelerator ();
    app.ui_manager.add_action_to_menu (_("_Go"), action);

    // Ctrl+M = open volume list. As in Krusader (vulgo media list)
    action = app.modules.new_action ("volumes/open-list");
    action.label = _("Open volume list");
    action.set_accel_path ("<Emperor-Main>/Volumes/OpenList");
    Gtk.AccelMap.add_entry ("<Emperor-Main>/Volumes/OpenList",
                            Gdk.Key.M, Gdk.ModifierType.CONTROL_MASK);
    action.activate.connect (() => { get_active_toolbar().open_volume_list(); });
    action.connect_accelerator ();
    app.ui_manager.add_action_to_menu (_("_View"), action);
}

