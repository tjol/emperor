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

using Emperor;
using Emperor.Application;

namespace Emperor.Modules {

    private static DirectoryMonitorManager left_mon;
    private static DirectoryMonitorManager right_mon;

    public void install_dir_monitor (MainWindow main_window)
    {
        left_mon = new DirectoryMonitorManager (main_window.left_pane);
        right_mon = new DirectoryMonitorManager (main_window.right_pane);
    }

    public class DirectoryMonitorManager : Object
    {
        public IFilePane file_pane { get; construct; }
        public FileMonitor current_monitor { get; private set; default = null; }
        private Cancellable m_cancellable;

        public DirectoryMonitorManager (IFilePane fp)
        {
            Object ( file_pane : fp );
        }

        construct {
            m_cancellable = new Cancellable ();
            file_pane.notify["pwd"].connect (on_chdir);
        }

        public void on_chdir (ParamSpec p)
        {
            if (current_monitor != null) {
                // old monitor, no longer needed.
                current_monitor.changed.disconnect (on_file_changed);
                m_cancellable.cancel ();
                current_monitor = null;
            }
            try {
                m_cancellable = new Cancellable ();
                var monitor = file_pane.pwd.monitor_directory (FileMonitorFlags.NONE, m_cancellable);
                monitor.changed.connect (on_file_changed);
                current_monitor = monitor;
            } catch {
                // Failed to create monitor. May not be supported. Continue.
                message (_("Creating file monitor failed."));
            }
        }

        public void on_file_changed (File? file, File? other_file, FileMonitorEvent ev_type)
        {
            if (file == null) {
                // While the API docs state that this can't happen, it does, for some reason.
                // If the file is NULL, there's nothing for me to do here.
                stderr.printf("WARNING: File monitor passed NULL GLib.File. This shouldn't happen!\n");
                return;
            }

            file_pane.update_file (File.new_for_uri(file.get_uri()));
        }
   }

}

public void load_module (ModuleRegistry reg)
{
    reg.application.ui_manager.main_window_ready.connect (Emperor.Modules.install_dir_monitor);
}

