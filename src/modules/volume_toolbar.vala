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

namespace Emperor.Modules {

    public void install_volume_toolbar (MainWindow main_window)
    {
        var left_toolbar = new VolumeToolbar (main_window.left_pane);
        var right_toolbar = new VolumeToolbar (main_window.right_pane);
        
        main_window.left_pane.pack_start (left_toolbar, false, false, 0);
        main_window.left_pane.reorder_child (left_toolbar, 0);

        main_window.right_pane.pack_start (right_toolbar, false, false, 0);
        main_window.right_pane.reorder_child (right_toolbar, 0);

        left_toolbar.show_all ();
        right_toolbar.show_all ();
    }

    public class VolumeToolbar : HBox
    {
        private FilePane m_pane;
        private Label m_mount_desc;
        private Button m_root_button;
        private Button m_up_button;

        public VolumeToolbar (FilePane pane)
        {
            m_pane = pane;

            m_mount_desc = new Label ("");
            m_root_button = new Button.with_label ("/");
            m_up_button = new Button.with_label ("..");

            m_root_button.clicked.connect (goto_root);
            m_up_button.clicked.connect (go_up);

            pack_start (m_mount_desc, true, true, 0);
            pack_end (m_up_button, false, false, 0);
            pack_end (m_root_button, false, false, 0);

            m_pane.notify["mnt"].connect (on_new_mnt);
        }

        private void on_new_mnt (ParamSpec p)
        {
            var dir = m_pane.pwd;

            string mnt_name = null;
            string mnt_type = null;
            if (m_pane.mnt != null) {
                mnt_name = m_pane.mnt.get_name ();
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

        private void goto_root ()
        {
            if (m_pane.pwd.is_native()) {
                m_pane.pwd = File.new_for_path ("/");
            } else {
                m_pane.pwd = m_pane.mnt.get_root ();
            }
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

