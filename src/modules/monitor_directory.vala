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
        public FilePane file_pane { get; construct; }
        public FileMonitor current_monitor { get; private set; default = null; }

        public DirectoryMonitorManager (FilePane fp)
        {
            Object ( file_pane : fp );
        }

        construct {
            file_pane.notify["pwd"].connect (on_chdir);
        }

        public void on_chdir (ParamSpec p)
        {
            if (current_monitor != null) {
                // old monitor, no longer needed.
                current_monitor.cancel ();
                current_monitor = null;
            }
            try {
                var monitor = file_pane.pwd.monitor_directory (0, null);
                monitor.changed.connect (on_file_changed);
                current_monitor = monitor;
            } catch {
                // Failed to create monitor. May not be supported. Continue.
            }
        }

        public void on_file_changed (File file, File? other_file, FileMonitorEvent ev_type)
        {
            file_pane.update_file (file);
        }
   }

}

public void load_module (ModuleRegistry reg)
{
    reg.application.ui_manager.main_window_ready.connect (Emperor.Modules.install_dir_monitor);
}

