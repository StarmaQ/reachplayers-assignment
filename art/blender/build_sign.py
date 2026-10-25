"""
Builds the big FindJob letters that stand on the grass next to the stand (a photo spot),
then exports them as one FBX for Roblox.

Run:  blender --background --python art/blender/build_sign.py [-- --preview]
       (--preview also renders art/export/FindJobSign_preview.png)

Each letter is two meshes: the colored letter with rounded edges, and a thicker white shell
behind it that shows as an outline, like toy sticker letters. The letters are separate so the
game can make them hop one after the other (src/client/Stand.luau).

Roblox coordinates (studs, Y up, letters face +Z, standing on y = 0), mapped to Blender's Z-up.
Object names: Letter<index>_<Front|Back>__<palette>, palette keys as in build_findjob.py.
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXPORT_PATH = os.path.join(ROOT, "export", "FindJobSign.fbx")
FONT_PATH = os.path.join(ROOT, "fonts", "Fredoka-Bold.ttf")

WORD = "FindJob"
SIZE = 4.6  # font size, capitals end up about 3.3 studs tall
GAP = 0.25  # between the outlines of two letters
# One toy color per letter, the brand blue leading each word
COLORS = ["blue", "coral", "sun", "teal", "blue", "coral", "sun"]
# A little playful tilt per letter (degrees, around the facing axis)
TILTS = [-4, 3, -2, 4, -3, 2, -4]

PALETTE = {
    "blue": (47, 111, 237),
    "teal": (46, 196, 182),
    "coral": (255, 107, 107),
    "sun": (255, 201, 60),
    "white": (255, 255, 255),
}

# Roblox space (x, y up, z) <-> Blender space (x, -z, y)
TO_BLENDER = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def srgb_to_linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(key):
    mat = bpy.data.materials.get(key)
    if mat is None:
        mat = bpy.data.materials.new(key)
        mat.diffuse_color = (*(srgb_to_linear(c) for c in PALETTE[key]), 1.0)
    return mat


def glyph(char, extrude, bevel, offset):
    """Mesh of one character in Roblox space: standing on y = 0, centered on x, facing +Z,
    its depth centered on z = 0."""
    curve = bpy.data.curves.new(char, "FONT")
    curve.body = char
    curve.size = SIZE
    curve.extrude = extrude
    curve.bevel_depth = bevel
    curve.bevel_resolution = 1
    curve.offset = offset
    curve.resolution_u = 3  # round enough to read as Fredoka, still light
    curve.font = bpy.data.fonts.load(FONT_PATH, check_existing=True)

    temp = bpy.data.objects.new(char + "_temp", curve)
    bpy.context.collection.objects.link(temp)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(temp.evaluated_get(depsgraph))
    bpy.data.objects.remove(temp)
    bpy.data.curves.remove(curve)

    # Font geometry lies in Blender's XY plane facing +Z: in Roblox terms that's already
    # x across, y up, z towards the viewer
    return mesh


def bounds(mesh):
    xs = [v.co.x for v in mesh.vertices]
    ys = [v.co.y for v in mesh.vertices]
    return min(xs), max(xs), min(ys), max(ys)


def place(mesh, matrix, name, palette_key):
    """Moves a glyph mesh (font space = Roblox space) into Blender space, origin at its center."""
    mesh.transform(TO_BLENDER @ matrix)
    coords = [v.co for v in mesh.vertices]
    lo = Vector((min(c.x for c in coords), min(c.y for c in coords), min(c.z for c in coords)))
    hi = Vector((max(c.x for c in coords), max(c.y for c in coords), max(c.z for c in coords)))
    center = (lo + hi) / 2
    mesh.transform(Matrix.Translation(-center))
    mesh.materials.append(material(palette_key))
    for polygon in mesh.polygons:
        polygon.use_smooth = False  # flat facets, like the rest of the stand
    obj = bpy.data.objects.new(f"{name}__{palette_key}", mesh)
    obj.location = center
    bpy.context.collection.objects.link(obj)
    return obj


def build():
    letters = []
    for char in WORD:
        front = glyph(char, extrude=0.42, bevel=0.09, offset=0.0)
        back = glyph(char, extrude=0.3, bevel=0.08, offset=0.18)
        letters.append((char, front, back))

    # Lay the letters out by the width of their outlines; the word is centered on x = 0
    widths = []
    for _, _, back in letters:
        x0, x1, _, _ = bounds(back)
        widths.append(x1 - x0)
    total = sum(widths) + GAP * (len(widths) - 1)
    # Every letter sits on the ground: shift by the lowest outline point (the "J" dips below)
    baseline = min(bounds(back)[2] for _, _, back in letters)

    cursor = -total / 2
    for index, (char, front, back) in enumerate(letters):
        x0, x1, _, _ = bounds(back)
        middle = (x0 + x1) / 2
        x = cursor + widths[index] / 2
        tilt = math.radians(TILTS[index])
        # Pivot the tilt around the letter's foot so it still touches the ground
        to_slot = Matrix.Translation((x, 0, 0)) @ Matrix.Rotation(tilt, 4, "Z") @ Matrix.Translation((-middle, -baseline, 0))
        place(front, Matrix.Translation((0, 0, 0.32)) @ to_slot, f"Letter{index + 1}_Front", COLORS[index])
        place(back, Matrix.Translation((0, 0, -0.12)) @ to_slot, f"Letter{index + 1}_Back", "white")
        cursor += widths[index] + GAP


def main():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    build()

    os.makedirs(os.path.dirname(EXPORT_PATH), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(
        filepath=EXPORT_PATH,
        use_selection=True,
        object_types={"MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_scale_options="FBX_SCALE_UNITS",
        mesh_smooth_type="FACE",
    )
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    triangles = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
    print(f"Exported {len(meshes)} objects, {triangles} triangles to {EXPORT_PATH}")
    if "--preview" in sys.argv:
        render_preview()


def render_preview():
    """Quick look at the letters from the front-left, like a player walking up."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.render.resolution_x, scene.render.resolution_y = 1200, 600
    scene.render.filepath = os.path.join(ROOT, "export", "FindJobSign_preview.png")
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    bpy.context.collection.objects.link(camera)
    scene.camera = camera
    # Roblox (x, y, z) -> Blender (x, -z, y)
    camera.location = Vector((-9, -22, 5))
    direction = Vector((0, 0, 1.6)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = 45
    bpy.ops.render.render(write_still=True)


main()
