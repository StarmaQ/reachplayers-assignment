"""
Draws the UI sprite kit used by the minigames and dialogue, as 9-slice PNGs.

Run:  blender --background --python art/blender/build_ui_sprites.py
Output: art/export/ui/*.png

Sprites are greyscale on purpose: the game tints them with ImageColor3, so one button
sprite gives every colored button. Shapes are drawn as anti-aliased signed distance fields.
Slice centers used in the game are listed in SLICES (keep src/shared/Config.luau in sync).
"""

import os

import bpy
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "export", "ui")

# name: (width, height, slice center left, top, right, bottom)
SLICES = {
    "button": (128, 140, 40, 40, 88, 92),
    "panel": (160, 160, 56, 56, 104, 104),
    "slot": (128, 96, 36, 36, 92, 60),
}


def grid(width, height):
    ys, xs = np.mgrid[0:height, 0:width].astype(np.float32)
    return xs + 0.5, ys + 0.5


def rounded_rect(xs, ys, left, top, right, bottom, radius):
    """Signed distance to a rounded rectangle (negative inside)."""
    cx, cy = (left + right) / 2, (top + bottom) / 2
    hx, hy = (right - left) / 2 - radius, (bottom - top) / 2 - radius
    qx = np.abs(xs - cx) - hx
    qy = np.abs(ys - cy) - hy
    outside = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2)
    inside = np.minimum(np.maximum(qx, qy), 0)
    return outside + inside - radius


def circle(xs, ys, cx, cy, radius):
    return np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2) - radius


def coverage(distance):
    """Anti-aliased fill: 1 inside, 0 outside, smooth over one pixel."""
    return np.clip(0.5 - distance, 0, 1)


def soft(distance, blur):
    """Soft falloff outside a shape, for shadows and glows."""
    return np.clip(1 - np.maximum(distance, 0) / blur, 0, 1) ** 2


class Canvas:
    def __init__(self, width, height):
        self.width, self.height = width, height
        self.rgb = np.zeros((height, width, 3), np.float32)
        self.alpha = np.zeros((height, width), np.float32)

    def paint(self, value, alpha):
        """Paint a grey value (number or array) with the given coverage, 'over' what's there."""
        value = np.broadcast_to(np.asarray(value, np.float32), alpha.shape)
        out_alpha = alpha + self.alpha * (1 - alpha)
        safe = np.maximum(out_alpha, 1e-6)
        for channel in range(3):
            self.rgb[..., channel] = (value * alpha + self.rgb[..., channel] * self.alpha * (1 - alpha)) / safe
        self.alpha = out_alpha

    def save(self, name):
        image = bpy.data.images.new(name, self.width, self.height, alpha=True)
        pixels = np.dstack([self.rgb, self.alpha])[::-1]  # Blender stores rows bottom-up
        image.pixels.foreach_set(pixels.astype(np.float32).ravel())
        image.filepath_raw = os.path.join(OUT_DIR, name + ".png")
        image.file_format = "PNG"
        image.save()


def build_button():
    """Push button: a darker lip under the face, a soft gloss on top."""
    width, height = SLICES["button"][:2]
    xs, ys = grid(width, height)
    c = Canvas(width, height)
    c.paint(0.0, soft(rounded_rect(xs, ys, 6, 14, width - 6, height - 2, 32), 6) * 0.25)
    c.paint(0.62, coverage(rounded_rect(xs, ys, 4, 12, width - 4, height - 6, 32)))
    face = rounded_rect(xs, ys, 4, 4, width - 4, height - 16, 32)
    shade = 1.0 - 0.1 * np.clip((ys - 4) / (height - 20), 0, 1)
    c.paint(shade, coverage(face))
    # Gloss on the upper half of the face
    gloss = coverage(rounded_rect(xs, ys, 14, 10, width - 14, 54, 22)) * 0.28
    c.paint(1.0, gloss * coverage(face))
    c.save("button")


def build_panel():
    """White card with a soft shadow and a hairline edge."""
    width, height = SLICES["panel"][:2]
    xs, ys = grid(width, height)
    c = Canvas(width, height)
    c.paint(0.0, soft(rounded_rect(xs, ys, 16, 22, width - 16, height - 10, 30), 14) * 0.3)
    c.paint(0.88, coverage(rounded_rect(xs, ys, 14, 14, width - 14, height - 18, 30)))
    c.paint(1.0, coverage(rounded_rect(xs, ys, 16, 16, width - 16, height - 20, 28)))
    c.save("panel")


def build_slot():
    """Inset slot: a darker top edge makes it look pressed into the surface."""
    width, height = SLICES["slot"][:2]
    xs, ys = grid(width, height)
    c = Canvas(width, height)
    shape = rounded_rect(xs, ys, 3, 3, width - 3, height - 3, 22)
    c.paint(0.55, coverage(shape))
    inner = rounded_rect(xs, ys, 3, 9, width - 3, height - 3, 22)
    c.paint(0.8, coverage(inner))
    c.save("slot")


def build_sticker():
    """Round push button for the ✓ / X stickers."""
    size = 128
    xs, ys = grid(size, size)
    c = Canvas(size, size)
    c.paint(0.0, soft(circle(xs, ys, 64, 70, 56), 6) * 0.25)
    c.paint(0.62, coverage(circle(xs, ys, 64, 68, 56)))
    face = circle(xs, ys, 64, 60, 56)
    c.paint(1.0 - 0.1 * np.clip((ys - 4) / 112, 0, 1), coverage(face))
    c.paint(1.0, coverage(circle(xs, ys, 64, 40, 34)) * 0.25 * coverage(face))
    c.save("sticker")

    ring = Canvas(size, size)
    ring_shape = np.maximum(circle(xs, ys, 64, 60, 56), -circle(xs, ys, 64, 60, 49))
    ring.paint(1.0, coverage(ring_shape))
    ring.save("sticker_ring")


def segment(xs, ys, ax, ay, bx, by):
    """Distance to the segment from (ax, ay) to (bx, by)."""
    px, py = xs - ax, ys - ay
    dx, dy = bx - ax, by - ay
    t = np.clip((px * dx + py * dy) / (dx * dx + dy * dy), 0, 1)
    return np.sqrt((px - t * dx) ** 2 + (py - t * dy) ** 2)


def build_chevron():
    """Rounded chevron pointing down: the texture of the guide beam. A beam maps the image's
    height along its length, so "down" in the image runs along the path."""
    size = 128
    xs, ys = grid(size, size)
    c = Canvas(size, size)
    stroke = np.minimum(segment(xs, ys, 22, 38, 64, 84), segment(xs, ys, 64, 84, 106, 38)) - 13
    c.paint(1.0, coverage(stroke))
    c.save("chevron")


def build_glow():
    size = 256
    xs, ys = grid(size, size)
    c = Canvas(size, size)
    c.paint(1.0, soft(circle(xs, ys, 128, 128, 8), 120))
    c.save("glow")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    build_button()
    build_panel()
    build_slot()
    build_sticker()
    build_glow()
    build_chevron()
    print("UI sprites written to", OUT_DIR)


main()
