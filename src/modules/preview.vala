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
using Gtk;
using Emperor;
using Emperor.Application;

namespace Emperor.Modules {

    public class PreviewModule : Object
    {
        public static void register (ModuleRegistry reg)
        {
            var app = reg.application;
            var module = new PreviewModule (app);

            // Preview pane
            var action = new Gtk.ToggleAction ("toggle:previewpane",
                                              _("Preview Pane"),
                                              null, null);
            reg.register_action (action);
            action.set_accel_path ("<Emperor-Main>/Preview/PreviewPane");
            Gtk.AccelMap.add_entry ("<Emperor-Main>/Preview/PreviewPane",
                                    Gdk.Key.P, Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.MOD1_MASK);
            action.toggled.connect ( () => {
                    module.toggle_preview_window ();
                } );
            action.connect_accelerator ();
            app.ui_manager.add_action_to_menu (_("_View"), action, 99);
        }

        public PreviewModule (EmperorCore app)
        {
            Object ( application : app );
        }

        public EmperorCore application { get; construct; }

        public void toggle_preview_window ()
        {
            if (m_preview_wnd == null) {
                var appwnd = application.main_window;
                m_preview_wnd = new PreviewWindow (appwnd, false);
                m_preview_wnd.request_detach.connect (detach_preview);

                m_preview_wnd.update_geometry (true);
                m_preview_wnd.preview_file.begin (appwnd.active_pane.get_file_at_cursor ());
                m_preview_wnd.show_all ();

                setup_events ();
            } else {
                m_preview_wnd.destroy ();
                m_preview_wnd = null;
            }
        }

        private void detach_preview ()
        {
            var appwnd = application.main_window;
            m_preview_wnd.destroy ();
            m_preview_wnd = new PreviewWindow (appwnd, true);
            m_preview_wnd.request_attach.connect (attach_preview);
            m_preview_wnd.default_width = 400;
            m_preview_wnd.default_height = 400;
            m_preview_wnd.show_all ();
            m_preview_wnd.preview_file.begin (appwnd.active_pane.get_file_at_cursor ());
            m_preview_wnd.show_all ();
        }

        private void attach_preview ()
        {
            var appwnd = application.main_window;
            m_preview_wnd.destroy ();
            m_preview_wnd = new PreviewWindow (appwnd, false);
            m_preview_wnd.request_detach.connect (detach_preview);
            m_preview_wnd.update_geometry (true);
            m_preview_wnd.preview_file.begin (appwnd.active_pane.get_file_at_cursor ());
            m_preview_wnd.show_all ();
        }

        private bool m_events_set_up = false;
        public void setup_events ()
        {
            if (m_events_set_up) return;

            var appwnd = application.main_window;

            appwnd.add_events (Gdk.EventMask.STRUCTURE_MASK);
            appwnd.configure_event.connect ( (ev) => {
                if (m_preview_wnd == null)
                    return false;
                else {
                    m_preview_wnd.update_geometry ();
                    return false;
                }
            } );

            var pane1 = appwnd.left_pane;
            var pane2 = appwnd.right_pane;

            pane1.notify["active"].connect ( p => {
                if (m_preview_wnd != null) {
                    m_preview_wnd.preview_file.begin (appwnd.active_pane.get_file_at_cursor ());
                    m_preview_wnd.update_geometry (true);
                }
            } );

            pane1.cursor_changed.connect ( () => {
                if (pane1.active && m_preview_wnd != null) { // almost certainly true...
                    // preview it!
                    m_preview_wnd.preview_file.begin (pane1.get_file_at_cursor ());
                }
            } );

            pane2.cursor_changed.connect ( () => {
                if (pane2.active && m_preview_wnd != null) { // almost certainly true...
                    // preview it!
                    m_preview_wnd.preview_file.begin (pane2.get_file_at_cursor ());
                }
            } );

            m_events_set_up = true;
        }

        public class PreviewWindow : Gtk.Window
        {
            public PreviewWindow (MainWindow parent, bool detached)
            {
                Object ( app_window : parent,
                         transient_for : parent,
                         is_detached : detached,
                         decorated : detached,
                         skip_pager_hint : !detached,
                         skip_taskbar_hint : !detached,
                         accept_focus : detached,
                         focus_on_map: false,
                         title : _("Preview"),
                         type : WindowType.TOPLEVEL,
                         content_box : new VBox (false, 2),
                         detach_button : new Button () );

                this.child = content_box;

                var detach_icon = new Image.from_stock (Stock.GO_UP, IconSize.SMALL_TOOLBAR);
                detach_button.image = detach_icon;
                detach_button.clicked.connect (() => {
                    request_detach ();
                });
                detach_button.halign = Gtk.Align.END;
                detach_button.expand = false;

                if (detached) {
                    add_events (Gdk.EventMask.STRUCTURE_MASK);
                    window_state_event.connect ( (ev) => {
                        if ((ev.changed_mask & Gdk.WindowState.ICONIFIED) != 0) {
                            request_attach ();
                        }
                        return true;
                    });
                    configure_event.connect ( (ev) => {
                        // refresh on resize.
                        preview_file.begin (parent.active_pane.get_file_at_cursor ());
                        return false;
                    });
                    delete_event.connect ( (ev) => {
                        request_attach ();
                        return true;
                    });
                } else {
                    content_box.pack_start (detach_button, false, false);
                    set_type_hint (Gdk.WindowTypeHint.TOOLTIP);
                    gravity = Gdk.Gravity.STATIC;
                }

            }

            public MainWindow app_window { get; construct; }
            public VBox content_box { get; construct; }
            public Button detach_button { get; construct; }
            public bool is_detached { get; construct; }

            public signal void request_detach ();
            public signal void request_attach ();

            public void update_geometry (bool okay_to_reposition_parent=false)
            {
                if (is_detached) return;

                var pane = app_window.active_pane;
                bool is_left = (pane == app_window.left_pane);
                int width = pane.get_allocated_width () / 2;
                int height = (int) (pane.get_allocated_height () * 0.8);

                int mwposx;
                int mwposy;
                int posx;
                int posy;
                app_window.get_position (out mwposx, out mwposy);
                Allocation alloc;
                pane.get_allocation (out alloc);
                posy = mwposy + (app_window.get_allocated_height() / 2) - (height / 2) + 32;

                int refx;
                int mwwidth = app_window.get_allocated_width ();
                if (is_left) {
                    refx = mwposx;
                    posx = mwposx - width;
                    detach_button.halign = Gtk.Align.END;
                } else {
                    posx = refx = mwposx + mwwidth;
                    detach_button.halign = Gtk.Align.START;
                }

                if (okay_to_reposition_parent) {
                    var screen = app_window.screen;
                    Gdk.Rectangle screenrect;
                    if (Gtk.MAJOR_VERSION == 3 && Gtk.MINOR_VERSION >= 4) {
                        screenrect = screen.get_monitor_workarea (screen.get_monitor_at_point (refx, mwposy));
                    } else {
                        screen.get_monitor_geometry (screen.get_monitor_at_point (refx, mwposy), out screenrect);
                    }

                    int dx;
                    if (is_left) {
                        dx = posx - screenrect.x;
                        if (dx < 0) {
                            // left edge of window is out-of-bounds.
                            if (   (mwposx + mwwidth) > (screenrect.x + screenrect.width) // beyond edge already
                                || (mwposx + mwwidth - dx) <= (screenrect.x + screenrect.width) ) { // space to the right 
                                // move main window to the right.
                                app_window.move (mwposx - dx, mwposy);
                            } else {
                                // window in screen now, but would be moved off screen if not resized.
                                // ergo, resize!
                                int new_width = screenrect.width - width;
                                app_window.resize (new_width, app_window.get_allocated_height ());
                                app_window.move (screenrect.x + width, mwposy);
                            }
                        } // else: it's okay.
                    } else { // right
                        dx = (screenrect.x + screenrect.width) - (posx + width);
                        if (dx < 0) {
                            // right edge of window is out-of-bounds.
                            if (   mwposx < screenrect.x             // beyond edge already
                                || (mwposx + dx) >= screenrect.x ) { // space to the left
                                // move main window to the left
                                app_window.move (mwposx + dx, mwposy);
                            } else {
                                // window in screen now, but would be moved off screen if not resized.
                                // ergo, resize!
                                int new_width = screenrect.width - width;
                                app_window.resize (new_width, app_window.get_allocated_height ());
                                app_window.move (screenrect.x, mwposy);
                            }
                        } // else: it's okay.
                    }
                }

                default_width = width;
                default_height = height;
                //show_all ();
                move (posx, posy);
            }

            public async void preview_file (File? f)
            {
                if (f == null) {
                    return;
                }

                try {
                    var finfo = yield f.query_info_async (FileAttribute.STANDARD_CONTENT_TYPE + "," + 
                                                          FileAttribute.STANDARD_ICON + "," +
                                                          FileAttribute.PREVIEW_ICON,
                                                          FileQueryInfoFlags.NONE);
                    // Step 1: check the content-type and see if we know how to preview.
                    var ctype = finfo.get_content_type ();
                    if (ctype in IMAGE_TYPES) {
                        show_image.begin (f);
                        return;
                    }

                    // Step 2: check if there's a preview icon.
                    Icon? icon;
                    icon = (Icon) finfo.get_attribute_object (FileAttribute.PREVIEW_ICON);
                    if (icon != null) {
                        show_icon (icon);
                        return;
                    }

                    // Step 3: Use the normal icon
                    icon = finfo.get_icon ();
                    if (icon != null) {
                        show_icon (icon);
                        return;
                    }
                } catch {
                    // Do I care that this failed? Not really.
                }
            }

            public int available_height {
                get {
                    if (is_detached) {
                        return get_allocated_height ();
                    } else {
                        return get_allocated_height () - 2 - detach_button.get_allocated_height ();
                    }
                }
            }

            public int available_width {
                get {
                    return get_allocated_width ();
                }
            }

            private void show_icon (Icon icon)
            {
                var img = new Image.from_gicon (icon, IconSize.DIALOG);
                img.pixel_size = int.min (available_height, available_width);
                set_child_in_scrolledwindow (img);
            }

            private async void show_image (File f)
            {
                try {
                    var in_stream = f.read ();
                    var pixbuf = yield new Gdk.Pixbuf.from_stream_async (in_stream, null);
                    
                    if (pixbuf.width > available_width || pixbuf.height > available_height) {
                        // scale.
                        var ratio_pb = (double)pixbuf.width / (double)pixbuf.height;
                        var ratio_wnd = (double)available_width / (double)available_height;
                        if (ratio_pb <= ratio_wnd) {
                            pixbuf = pixbuf.scale_simple ((int)(ratio_pb * available_height), available_height,
                                                          Gdk.InterpType.HYPER);
                        } else {
                            pixbuf = pixbuf.scale_simple (available_width, (int)(available_width / ratio_pb),
                                                          Gdk.InterpType.HYPER);
                        }
                    }
                    var img = new Image.from_pixbuf (pixbuf);
                    set_child_in_scrolledwindow (img);
                } catch {
                    // Do I care that this failed? Not really.
                }
            }

            private Widget? m_child = null;
            private void set_child (Widget new_child)
            {
                if (m_child != null) {
                    content_box.remove (m_child);
                }
                content_box.pack_start (new_child, true, true);
                m_child = new_child;
                new_child.show_all ();
            }

            private void set_child_in_scrolledwindow (Widget new_child)
            {
                var sw = new ScrolledWindow (null, null);
                sw.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
                sw.set_shadow_type (ShadowType.NONE);
                var vp = new Viewport (null, null);
                vp.set_shadow_type (ShadowType.NONE);
                vp.child = new_child;
                sw.child = vp;
                set_child (sw);
            }
        }

        private PreviewWindow? m_preview_wnd;

    }

}

public void load_module (ModuleRegistry reg)
{
    Emperor.Modules.PreviewModule.register (reg);
}

// Extracted from EOG's desktop entry.
public const string[] IMAGE_TYPES = {
    "image/bmp",
    "image/gif",
    "image/jpeg",
    "image/jpg",
    "image/pjpeg",
    "image/png",
    "image/tiff",
    "image/x-bmp",
    "image/x-gray",
    "image/x-icb",
    "image/x-ico",
    "image/x-png",
    "image/x-portable-anymap",
    "image/x-portable-bitmap",
    "image/x-portable-graymap",
    "image/x-portable-pixmap",
    "image/x-xbitmap",
    "image/x-xpixmap",
    "image/x-pcx",
    "image/svg+xml",
    "image/svg+xml-compressed",
    "image/vnd.wap.wbmp"
};


