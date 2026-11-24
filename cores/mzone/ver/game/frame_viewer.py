#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
import argparse
import os
import math
import sys

import gi

gi.require_version("Gdk", "3.0")
gi.require_version("Gtk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import Gdk, GdkPixbuf, GLib, Gtk


class ImageWatcher:
    def __init__(self, paths, interval_ms, zoom, hbase, vbase, coord_space, rotation="auto"):
        self.selected_paths = list(paths) if len(paths) > 1 else None
        self.path = paths[0]
        self.directory = os.path.dirname(self.path) or "."
        self.rotation = rotation
        self.files = []
        self.index = 0
        self.interval_ms = interval_ms
        self.zoom = max(0.25, min(32.0, zoom))
        self.hbase = hbase
        self.vbase = vbase
        self.coord_space = coord_space
        self.mtime = None
        self.base_pixbuf = None
        self.drag_button = None
        self.drag_x = 0.0
        self.drag_y = 0.0
        self.drag_h = 0.0
        self.drag_v = 0.0
        self.maximized = False
        self.ctrl_down = False
        self.coord_text = "x=- y=-"
        self.coremod = self.read_coremod()
        self.scaled_width = 0
        self.scaled_height = 0
        self.scaled_pixbuf = None
        self.scroll_generation = 0

        self.window = Gtk.Window(title="frame_viewer")
        self.window.set_default_size(900, 700)
        self.window.add_events(Gdk.EventMask.SCROLL_MASK | Gdk.EventMask.SMOOTH_SCROLL_MASK)
        self.window.connect("destroy", Gtk.main_quit)
        self.window.connect("key-press-event", self.on_key_press)
        self.window.connect("key-release-event", self.on_key_release)
        self.window.connect("window-state-event", self.on_window_state)

        self.header = Gtk.HeaderBar()
        self.header.set_show_close_button(True)
        self.header.set_title("frame_viewer")

        self.min_button = Gtk.Button(label="_")
        self.min_button.set_tooltip_text("Minimize")
        self.min_button.connect("clicked", self.on_minimize)

        self.max_button = Gtk.Button(label="[]")
        self.max_button.set_tooltip_text("Maximize")
        self.max_button.connect("clicked", self.on_maximize)

        self.header.pack_end(self.max_button)
        self.header.pack_end(self.min_button)
        self.window.set_titlebar(self.header)

        self.image = Gtk.DrawingArea()
        self.image.connect("draw", self.on_draw)
        self.event_box = Gtk.EventBox()
        self.event_box.set_halign(Gtk.Align.START)
        self.event_box.set_valign(Gtk.Align.START)
        self.event_box.add_events(
            Gdk.EventMask.SCROLL_MASK
            | Gdk.EventMask.SMOOTH_SCROLL_MASK
            | Gdk.EventMask.BUTTON_PRESS_MASK
            | Gdk.EventMask.BUTTON_RELEASE_MASK
            | Gdk.EventMask.POINTER_MOTION_MASK
        )
        self.event_box.connect("scroll-event", self.on_scroll)
        self.event_box.connect("button-press-event", self.on_button_press)
        self.event_box.connect("button-release-event", self.on_button_release)
        self.event_box.connect("motion-notify-event", self.on_motion)
        self.event_box.add(self.image)

        self.scrolled = Gtk.ScrolledWindow()
        self.scrolled.add_events(Gdk.EventMask.SCROLL_MASK | Gdk.EventMask.SMOOTH_SCROLL_MASK)
        self.viewport = Gtk.Viewport()
        self.viewport.set_halign(Gtk.Align.START)
        self.viewport.set_valign(Gtk.Align.START)
        self.viewport.add(self.event_box)
        self.scrolled.add(self.viewport)
        self.window.add(self.scrolled)
        self.window.show_all()

        self.refresh_file_list()
        self.reload(force=True)
        GLib.timeout_add(self.interval_ms, self.poll)

    def poll(self):
        self.refresh_file_list()
        self.reload(force=False)
        return True

    def refresh_file_list(self):
        if self.selected_paths is not None:
            self.files = self.selected_paths.copy()
            self.index = self.files.index(self.path)
            return
        try:
            names = os.listdir(self.directory)
        except OSError:
            return

        files = [
            os.path.join(self.directory, name)
            for name in names
            if name.lower().endswith((".jpg", ".jpeg", ".png"))
        ]
        files.sort()
        if not files:
            # Forget files that disappeared so recreated frame files count as
            # new when a simulator repopulates the directory.
            self.files = []
            return

        previous = {os.path.abspath(name) for name in self.files}
        new_files = [name for name in files if os.path.abspath(name) not in previous]
        current = os.path.abspath(self.path)
        self.files = files

        # After initial startup, follow newly created simulation frames. This
        # makes the viewer advance from frame_00000.png through the last frame
        # as the frames directory is populated.
        if previous and new_files:
            self.path = new_files[-1]
            self.index = self.files.index(self.path)
            self.mtime = None
            return

        for i, name in enumerate(files):
            if os.path.abspath(name) == current:
                self.index = i
                break
        else:
            # Keep polling an explicitly selected path if it temporarily
            # disappears. Do not silently switch to an older frame.
            self.index = min(self.index, len(files) - 1)

    def stat_mtime(self):
        try:
            st = os.stat(self.path)
            return (st.st_mtime_ns, st.st_size)
        except FileNotFoundError:
            return None

    def read_coremod(self):
        # Find the simulation metadata beside the image or in its parents.
        directory = os.path.abspath(self.directory)
        while True:
            try:
                with open(os.path.join(directory, "core.mod"), "rb") as f:
                    data = f.read(1)
                return data[0] if data else 0
            except OSError:
                parent = os.path.dirname(directory)
                if parent == directory:
                    return 0
                directory = parent

    def image_rotation(self):
        if self.rotation != "auto":
            return self.rotation
        # --norotate dumps remain landscape despite vertical core metadata.
        if not self.coremod & 1 or self.base_pixbuf.get_width() >= self.base_pixbuf.get_height():
            return "none"
        return "ccw" if self.coremod & 4 else "cw"

    def reload(self, force):
        mtime = self.stat_mtime()
        if mtime is None:
            return
        if not force and mtime == self.mtime:
            return
        try:
            pixbuf = GdkPixbuf.Pixbuf.new_from_file(self.path)
        except GLib.Error:
            return

        self.mtime = mtime
        self.base_pixbuf = pixbuf
        self.update_image()

    def update_title(self):
        if self.base_pixbuf is None:
            return

        width = max(1, int(round(self.base_pixbuf.get_width() * self.zoom)))
        height = max(1, int(round(self.base_pixbuf.get_height() * self.zoom)))
        title = (
            f"{os.path.basename(self.path)}  {self.index + 1}/{len(self.files)}  "
            f"zoom={self.zoom:.2f}x  {width}x{height}  {self.coord_text}"
        )
        self.window.set_title(title)
        self.header.set_title(title)

    def update_coords(self, x, y):
        if self.base_pixbuf is None:
            return

        px = x
        py = y

        img_x = math.floor(px / self.zoom)
        img_y = math.floor(py / self.zoom)
        if (
            0 <= img_x < self.base_pixbuf.get_width()
            and 0 <= img_y < self.base_pixbuf.get_height()
        ):
            raw_x, raw_y = self.raw_coords(img_x, img_y)
            hdump = (raw_x + self.hbase) % 384
            vdump = (raw_y + self.vbase) % 264
            self.coord_text = (
                f"img x={img_x} y={img_y}  {self.coord_space} raw x={raw_x} y={raw_y}  "
                f"hdump={hdump} vdump={vdump}"
            )
        else:
            self.coord_text = "x=- y=-"
        self.update_title()

    def raw_coords(self, img_x, img_y):
        rotation = self.image_rotation()
        if rotation == "cw":
            return img_y, self.base_pixbuf.get_width() - 1 - img_x
        if rotation == "ccw":
            return self.base_pixbuf.get_height() - 1 - img_y, img_x
        return img_x, img_y

    def update_image(self, scroll_to=None):
        if self.base_pixbuf is None:
            return

        hadj = self.scrolled.get_hadjustment()
        vadj = self.scrolled.get_vadjustment()
        old_x, old_y = scroll_to if scroll_to is not None else (hadj.get_value(), vadj.get_value())

        width = max(1, int(round(self.base_pixbuf.get_width() * self.zoom)))
        height = max(1, int(round(self.base_pixbuf.get_height() * self.zoom)))
        self.scaled_width = width
        self.scaled_height = height
        interp = GdkPixbuf.InterpType.NEAREST
        self.scaled_pixbuf = self.base_pixbuf.scale_simple(width, height, interp)
        self.image.set_size_request(width, height)
        self.event_box.set_size_request(width, height)
        self.image.queue_draw()

        self.update_title()

        self.scroll_generation += 1
        GLib.idle_add(self.restore_scroll, self.scroll_generation, old_x, old_y)

    def on_draw(self, _widget, cr):
        if self.scaled_pixbuf is None:
            return False
        Gdk.cairo_set_source_pixbuf(cr, self.scaled_pixbuf, 0, 0)
        cr.paint()
        return False

    def restore_scroll(self, generation, x, y):
        if generation != self.scroll_generation:
            return False
        hadj = self.scrolled.get_hadjustment()
        vadj = self.scrolled.get_vadjustment()
        self.set_scroll(hadj, x)
        self.set_scroll(vadj, y)
        return False

    def set_scroll(self, adjustment, value):
        upper = max(0, adjustment.get_upper() - adjustment.get_page_size())
        adjustment.set_value(max(0, min(value, upper)))

    def set_zoom(self, zoom):
        self.zoom = max(0.25, min(32.0, zoom))
        self.update_image()

    def set_zoom_at(self, zoom, x, y):
        self.set_zoom_at_point(zoom, x, y)

    def set_zoom_at_point(self, zoom, content_x, content_y):
        old_zoom = self.zoom
        new_zoom = max(0.25, min(32.0, zoom))
        if new_zoom == old_zoom:
            return

        hadj = self.scrolled.get_hadjustment()
        vadj = self.scrolled.get_vadjustment()
        view_x = content_x - hadj.get_value()
        view_y = content_y - vadj.get_value()
        img_x = content_x / old_zoom
        img_y = content_y / old_zoom

        self.zoom = new_zoom
        self.update_image((img_x * new_zoom - view_x, img_y * new_zoom - view_y))

    def step_file(self, delta):
        self.refresh_file_list()
        if not self.files:
            return
        self.index = (self.index + delta) % len(self.files)
        self.path = self.files[self.index]
        self.mtime = None
        self.reload(force=True)

    def on_key_press(self, _window, event):
        key = Gdk.keyval_name(event.keyval)
        if key in ("Control_L", "Control_R"):
            self.ctrl_down = True
            return False
        if key in ("q", "Q", "Escape"):
            Gtk.main_quit()
        elif key in ("Left", "KP_Left"):
            self.step_file(-1)
        elif key in ("Right", "KP_Right"):
            self.step_file(1)
        elif key in ("plus", "KP_Add", "equal"):
            self.set_zoom(self.zoom * 1.25)
        elif key in ("minus", "KP_Subtract", "underscore"):
            self.set_zoom(self.zoom / 1.25)
        elif key in ("0", "KP_0"):
            self.set_zoom(1.0)
        elif key in ("r", "R"):
            self.reload(force=True)

    def on_key_release(self, _window, event):
        key = Gdk.keyval_name(event.keyval)
        if key in ("Control_L", "Control_R"):
            self.ctrl_down = False
        return False

    def on_scroll(self, _widget, event):
        if not (self.ctrl_down or event.state & Gdk.ModifierType.CONTROL_MASK):
            return False

        if event.direction == Gdk.ScrollDirection.UP:
            factor = 1.25
        elif event.direction == Gdk.ScrollDirection.DOWN:
            factor = 1 / 1.25
        elif event.direction == Gdk.ScrollDirection.SMOOTH:
            deltas = event.get_scroll_deltas()
            if len(deltas) == 3:
                _ok, _dx, dy = deltas
            else:
                _dx, dy = deltas
            factor = 1.25 ** (-dy)
        else:
            return False

        self.set_zoom_at_point(self.zoom * factor, event.x, event.y)
        return True

    def on_button_press(self, widget, event):
        if event.button not in (2, 3):
            return False

        self.drag_button = event.button
        self.drag_x = event.x_root
        self.drag_y = event.y_root
        self.drag_h = self.scrolled.get_hadjustment().get_value()
        self.drag_v = self.scrolled.get_vadjustment().get_value()
        widget.grab_focus()
        return True

    def on_button_release(self, _widget, event):
        if event.button == self.drag_button:
            self.drag_button = None
            return True
        return False

    def on_motion(self, _widget, event):
        self.update_coords(event.x, event.y)
        if self.drag_button is None:
            return False

        hadj = self.scrolled.get_hadjustment()
        vadj = self.scrolled.get_vadjustment()
        self.set_scroll(hadj, self.drag_h - (event.x_root - self.drag_x))
        self.set_scroll(vadj, self.drag_v - (event.y_root - self.drag_y))
        return True

    def on_minimize(self, _button):
        self.window.iconify()

    def on_maximize(self, _button):
        if self.maximized:
            self.window.unmaximize()
        else:
            self.window.maximize()

    def on_window_state(self, _window, event):
        self.maximized = bool(event.new_window_state & Gdk.WindowState.MAXIMIZED)
        self.max_button.set_label("<>" if self.maximized else "[]")
        self.max_button.set_tooltip_text("Restore" if self.maximized else "Maximize")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Auto-reloading image viewer that preserves zoom and pan."
    )
    parser.add_argument(
        "path",
        nargs="*",
        default=["frames/frame_00004.png"],
        help="image file(s) to watch, default: frames/frame_00004.png",
    )
    parser.add_argument("--interval", type=float, default=0.25, help="poll interval in seconds")
    parser.add_argument("--zoom", type=float, default=3.0, help="initial zoom (clamped to 0.25–32)")
    parser.add_argument(
        "--rotation", choices=("auto", "none", "cw", "ccw"), default="auto",
        help="image rotation relative to raw video; auto uses core.mod and image dimensions",
    )
    parser.add_argument(
        "--coord-space",
        choices=("final", "raw"),
        default="final",
        help="coordinate labels to show: final RGB/FST output or raw active image coordinates",
    )
    parser.add_argument("--hbase", type=int, default=None, help="raw active x to hdump offset")
    parser.add_argument("--vbase", type=int, default=16, help="raw active y to vdump offset")
    args = parser.parse_args()

    if not math.isfinite(args.zoom) or not math.isfinite(args.interval):
        parser.error("zoom and interval must be finite numbers")
    paths = args.path or ["frames/frame_00004.png"]
    hbase = args.hbase
    if hbase is None:
        hbase = 0
    ImageWatcher(
        paths,
        max(50, int(args.interval * 1000)),
        args.zoom,
        hbase,
        args.vbase,
        args.coord_space,
        args.rotation,
    )
    Gtk.main()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
