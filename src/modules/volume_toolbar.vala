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
using Gtk;
using Emperor;
using Emperor.Application;

namespace Emperor.Modules {

    public void install_volume_toolbar (MainWindow main_window)
    {
        var left_toolbar = new VolumeToolbar (main_window, main_window.left_pane);
        var right_toolbar = new VolumeToolbar (main_window, main_window.right_pane);
        
        main_window.left_pane.pack_start (left_toolbar, false, false, 0);
        main_window.left_pane.reorder_child (left_toolbar, 0);

        main_window.right_pane.pack_start (right_toolbar, false, false, 0);
        main_window.right_pane.reorder_child (right_toolbar, 0);

        left_toolbar.show_all ();
        right_toolbar.show_all ();
    }

    public class VolumeToolbar : HBox
    {
        private Window m_wnd;
        private FilePane m_pane;
        private Label m_mount_desc;
        private Button m_home_button;
        private Button m_root_button;
        private Button m_up_button;
        private Button m_vol_list_button;
        private Button m_eject_button;

        private Menu m_volmenu;

        public VolumeToolbar (Window wnd, FilePane pane)
        {
            m_wnd = wnd;
            m_pane = pane;
            var app = (EmperorCore) m_wnd.application;

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
                if (m_pane.mnt.can_eject() || m_pane.mnt.can_unmount()) {
                    m_eject_button.show ();
                } else {
                    m_eject_button.hide ();
                }
            } else {
                // Look for the UNIX mount.
                FileInfo fi = dir.query_info (FILE_ATTRIBUTE_ID_FILESYSTEM, 0);
                string filesystem_id = fi.get_attribute_string (FILE_ATTRIBUTE_ID_FILESYSTEM);

                foreach (unowned UnixMountEntry xmnt in UnixMountEntry.@get()) {
                    var mnt_point = File.new_for_path(xmnt.get_mount_path ());
                    fi = mnt_point.query_info (FILE_ATTRIBUTE_ID_FILESYSTEM, 0);
                    var mnt_fs_id = fi.get_attribute_string (FILE_ATTRIBUTE_ID_FILESYSTEM);
                    if (filesystem_id == mnt_fs_id) {
                        mnt_name = xmnt.get_mount_path ();
                        mnt_type = xmnt.get_fs_type ();
                        if (mnt_type != "rootfs") {
                            break;
                        }
                    }
                }

                if (mnt_name == null) {
                    mnt_name = _("unknown");
                }

                // TODO: check if this mount can be user-unmounted.
                m_eject_button.hide ();
            }

            try {
                FileInfo fs_info = dir.query_filesystem_info (
                                        FILE_ATTRIBUTE_FILESYSTEM_SIZE + "," +
                                        FILE_ATTRIBUTE_FILESYSTEM_FREE + "," +
                                        FILE_ATTRIBUTE_FILESYSTEM_TYPE + "," +
                                        FILE_ATTRIBUTE_FILESYSTEM_READONLY,
                                        null);

                if (mnt_type == null) {
                    mnt_type = fs_info.get_attribute_string (FILE_ATTRIBUTE_FILESYSTEM_TYPE);
                }

                var size = fs_info.get_attribute_uint64 (FILE_ATTRIBUTE_FILESYSTEM_SIZE);
                var free = fs_info.get_attribute_uint64 (FILE_ATTRIBUTE_FILESYSTEM_FREE);
                var ronly = fs_info.get_attribute_boolean (FILE_ATTRIBUTE_FILESYSTEM_READONLY);
                var size_str = bytesize_to_string (size);
                var free_str = bytesize_to_string (free);

                m_mount_desc.set_markup (
                    (ronly ? _("<b>%s</b> (%s; %s of %s free; read-only)")
                          : _("<b>%s</b> (%s; %s of %s free)")).printf (
                                _esc(mnt_name), _esc(mnt_type), free_str, size_str) );
            } catch (Error e) {
                m_mount_desc.set_markup ( "<b>%s</b>".printf(_esc(mnt_name)) );
            }

            m_up_button.sensitive = dir.has_parent (null);
        }

        private void go_up ()
        {
            var parent = m_pane.pwd.get_parent ();
            if (parent != null) {
                m_pane.chdir.begin (parent, m_pane.pwd.get_basename());
            }
        }

        private void go_home ()
        {
            m_pane.pwd = File.new_for_path (Environment.get_home_dir());
        }

        private void goto_root ()
        {
            if (m_pane.pwd.is_native()) {
                m_pane.pwd = File.new_for_path ("/");
            } else {
                m_pane.pwd = m_pane.mnt.get_root ();
            }
        }

        private void eject_volume ()
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

            if (mnt.can_eject ()) {
                yield mnt.eject_with_operation (MountUnmountFlags.NONE,
                        new Gtk.MountOperation (m_wnd), null);
            } else if (mnt.can_unmount ()) {
                yield mnt.unmount_with_operation (MountUnmountFlags.NONE,
                        new Gtk.MountOperation (m_wnd), null);
            } else {
                m_pane.display_error (_("Cannot unmount “%s”.").printf (mnt.get_name));
            }
        }

        private void open_volume_list ()
        {
            bool first;
            var vm = VolumeMonitor.get ();
            var volmenu = new Menu ();
            ImageMenuItem menuitem;
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
            menuitem.activate.connect (
                new VolumeMenuClickHandler (this,
                        home, null).on_click );

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
                    var bm_finfo = bmark.query_info (FILE_ATTRIBUTE_STANDARD_TYPE + "," +
                                                     FILE_ATTRIBUTE_STANDARD_ICON + "," +
                                                     FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME,
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
                        bm_icon = Icon.new_for_string ("folder-remote");
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
                var click_handler = new VolumeMenuClickHandler (this,
                                            bmark, null);
                menuitem.activate.connect ( click_handler.on_click );
                menuitem.button_press_event.connect ( click_handler.bm_right_click );

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
                if (first) {
                    volmenu.append (new SeparatorMenuItem ());
                    first = false;
                }

                menuitem = new ImageMenuItem ();
                menuitem.set_label (mnt.get_name ());
                menuitem.set_image (new Image.from_gicon (
                    mnt.get_icon (), IconSize.MENU));
                menuitem.set_always_show_image (true);

                menuitem.activate.connect (
                    new VolumeMenuClickHandler (this,
                        mnt.get_root(), null).on_click );

                volmenu.append (menuitem);

                var root_path = mnt.get_root().get_path();
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

                    menuitem.activate.connect (
                        new VolumeMenuClickHandler (this,
                            (vol_mnt == null) ? null : vol_mnt.get_root(),
                            vol).on_click );

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

                menuitem.activate.connect (
                    new VolumeMenuClickHandler (this,
                        File.new_for_path(path), null).on_click );
                
                volmenu.append (menuitem);

                listed_mounts.add (path);
            }

            volmenu.show_all();
            volmenu.popup (null, null, position_volume_menu, 0, get_current_event_time());
            // Need to keep a reference to the menu around of it won't
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
                    try {
                        var bmark = File.new_for_uri (line.strip ());
                        list.add (bmark);
                    } catch (Error e) {
                        continue;
                    }
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
            private Menu? m_context_menu;

            public VolumeMenuClickHandler (VolumeToolbar parent, File? path, Volume? volume)
            {
                m_parent = parent;
                m_wnd = parent.m_wnd;
                m_pane = parent.m_pane;
                m_path = path;
                m_volume = volume;
                this.@ref();
            }

            public void on_click ()
            {
                if (m_path != null) {
                    m_pane.pwd = m_path;
                } else if (m_volume != null) {
                    do_mount.begin ();
                }
            }

            private async void do_mount ()
            {
                if (yield m_volume.mount (MountMountFlags.NONE,
                            new Gtk.MountOperation (m_wnd), null)) {
                    var mnt = m_volume.get_mount ();
                    if (mnt != null) {
                        m_pane.pwd = mnt.get_root ();
                        return;
                    }
                }
                m_pane.display_error (_("Error mounting volume."));
            }

            public bool bm_right_click (Gdk.EventButton bevent)
            {
                if (bevent.type != Gdk.EventType.BUTTON_PRESS
                    || bevent.button != 3) {
                    return false;
                }

                MenuItem menuitem;

                m_context_menu = new Menu ();

                menuitem = new MenuItem.with_label (_("Open"));
                menuitem.activate.connect (on_click);
                m_context_menu.append (menuitem);
                menuitem = new MenuItem.with_label (_("Delete bookmark"));
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

        private void position_volume_menu (Menu menu, out int x, out int y, out bool push_in)
        {
            int origin_x, origin_y;
            var gdkwnd = m_vol_list_button.get_window();
            gdkwnd.get_origin (out origin_x, out origin_y);

            Allocation alloc;
            m_vol_list_button.get_allocation (out alloc);

            x = origin_x + alloc.x;
            y = origin_y + alloc.y + alloc.height;
        }


    }

    private string _esc (string s)
    {
        return s.replace ("&", "&amp")
                .replace ("<", "&lt;")
                .replace (">", "&gt;");
    }

}

public void load_module (ModuleRegistry reg)
{
    reg.application.ui_manager.main_window_ready.connect (Emperor.Modules.install_volume_toolbar);
}

