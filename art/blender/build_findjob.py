"""
Builds the FindJob building and its props, then exports one FBX for Roblox.

Run:  blender --background --python art/blender/build_findjob.py

Everything is written in Roblox coordinates (studs, Y up, building front facing +Z)
and converted to Blender's Z-up space by to_bl(). 1 Blender unit = 1 stud.

Outputs art/blender/FindJob.blend and art/export/FindJob.fbx (uploaded with art/upload.py).

Object names matter: the Studio setup step (art/studio/post_import.luau) groups parts
by prefix (Building_, Computer_, TeacherDesk_) and colors them by name.
"""

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXPORT_PATH = os.path.join(ROOT, "export", "FindJob.fbx")
BLEND_PATH = os.path.join(ROOT, "blender", "FindJob.blend")
FONT_PATH = "C:/Windows/Fonts/ariblk.ttf"

PALETTE = {
    "wall": (0.96, 0.92, 0.87),
    "floor": (0.73, 0.54, 0.37),
    "roof": (0.23, 0.25, 0.29),
    "brand": (0.18, 0.44, 0.93),
    "accent": (1.0, 0.77, 0.0),
    "white": (1.0, 1.0, 1.0),
    "glass": (0.66, 0.85, 1.0),
    "wood": (0.55, 0.42, 0.29),
    "dark": (0.12, 0.12, 0.14),
    "screen": (0.3, 0.64, 1.0),
    "chair": (0.18, 0.23, 0.4),
    "pot": (0.75, 0.38, 0.25),
    "leaf": (0.24, 0.56, 0.25),
    "apple": (0.83, 0.18, 0.18),
    "board": (0.18, 0.36, 0.27),
}


# Roblox (x, y up, z) -> Blender (x, -z, y)
def to_bl(v):
    x, y, z = v
    return Vector((x, -z, y))


ROBLOX_TO_BLENDER = Matrix.Rotation(math.radians(90), 4, "X")


def material(key):
    mat = bpy.data.materials.get(key)
    if mat is None:
        mat = bpy.data.materials.new(key)
        color = (*PALETTE[key], 1.0)
        mat.diffuse_color = color
        bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat.node_tree else None
        if bsdf:
            bsdf.inputs["Base Color"].default_value = color
    return mat


# Primitives, all in Roblox space ------------------------------------------

def box(size, center, rot_y=0.0):
    return ("box", size, center, rot_y)


def cylinder(radius, height, center):
    return ("cylinder", (radius, height), center, 0.0)


def sphere(radius, center):
    return ("sphere", radius, center, 0.0)


def add_primitive(bm, prim):
    kind, size, center, rot_y = prim
    if kind == "box":
        verts = bmesh.ops.create_cube(bm, size=1.0)["verts"]
        sx, sy, sz = size
        scale = Matrix.Diagonal((sx, sz, sy, 1.0))
    elif kind == "cylinder":
        radius, height = size
        verts = bmesh.ops.create_cone(
            bm, cap_ends=True, segments=16, radius1=radius, radius2=radius, depth=height
        )["verts"]
        scale = Matrix.Identity(4)
    else:
        verts = bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=8, radius=size)["verts"]
        scale = Matrix.Identity(4)

    transform = Matrix.Translation(to_bl(center)) @ Matrix.Rotation(rot_y, 4, "Z") @ scale
    bmesh.ops.transform(bm, matrix=transform, verts=verts)


def finish_object(name, mesh, mat_key):
    # Move the origin to the bounding box center so each MeshPart pivots sensibly
    coords = [v.co for v in mesh.vertices]
    center = Vector(
        (
            (min(c.x for c in coords) + max(c.x for c in coords)) / 2,
            (min(c.y for c in coords) + max(c.y for c in coords)) / 2,
            (min(c.z for c in coords) + max(c.z for c in coords)) / 2,
        )
    )
    mesh.transform(Matrix.Translation(-center))
    mesh.materials.append(material(mat_key))

    obj = bpy.data.objects.new(name, mesh)
    obj.location = center
    bpy.context.collection.objects.link(obj)
    return obj


def part(name, mat_key, *prims):
    bm = bmesh.new()
    for prim in prims:
        add_primitive(bm, prim)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return finish_object(name, mesh, mat_key)


def text(name, mat_key, body, height, center, depth=0.15):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = body
    curve.size = height
    curve.extrude = depth
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    if os.path.exists(FONT_PATH):
        curve.font = bpy.data.fonts.load(FONT_PATH, check_existing=True)

    temp = bpy.data.objects.new(name + "_temp", curve)
    bpy.context.collection.objects.link(temp)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(temp.evaluated_get(depsgraph))
    bpy.data.objects.remove(temp)

    mesh.transform(Matrix.Translation(to_bl(center)) @ ROBLOX_TO_BLENDER)
    return finish_object(name, mesh, mat_key)


# Scene ---------------------------------------------------------------------

def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)


FLOOR_TOP = 0.4
WALL_H = 12.0
WALL_MID = FLOOR_TOP + WALL_H / 2
WALL_TOP = FLOOR_TOP + WALL_H


def build_shell():
    part("Building_Floor", "floor", box((28, FLOOR_TOP, 22), (0, FLOOR_TOP / 2, 0)))

    part("Building_WallBack", "wall", box((28, WALL_H, 1), (0, WALL_MID, -10.5)))
    part("Building_WallLeft", "wall", box((1, WALL_H, 20), (-13.5, WALL_MID, 0)))
    part("Building_WallRight", "wall", box((1, WALL_H, 20), (13.5, WALL_MID, 0)))

    # Front wall: doorway in the middle, one window on each side
    door_w, door_h = 8, 9
    win_bottom, win_top = 4.0, 8.5
    for side, sx in (("Left", -1), ("Right", 1)):
        part(
            f"Building_WallFront{side}",
            "wall",
            box((3, WALL_H, 1), (sx * 12.5, WALL_MID, 10.5)),  # outer pillar
            box((3, WALL_H, 1), (sx * 5.5, WALL_MID, 10.5)),  # pillar next to the door
            box((4, win_bottom - FLOOR_TOP, 1), (sx * 9, (FLOOR_TOP + win_bottom) / 2, 10.5)),
            box((4, WALL_TOP - win_top, 1), (sx * 9, (win_top + WALL_TOP) / 2, 10.5)),
        )
        part(
            f"Building_Window{side}",
            "glass",
            box((4, win_top - win_bottom, 0.2), (sx * 9, (win_bottom + win_top) / 2, 10.5)),
        )

    top_of_door = FLOOR_TOP + door_h
    part(
        "Building_WallFrontTop",
        "wall",
        box((door_w, WALL_TOP - top_of_door, 1), (0, (top_of_door + WALL_TOP) / 2, 10.5)),
    )
    part(
        "Building_DoorTrim",
        "accent",
        box((0.6, door_h, 1.4), (-door_w / 2 - 0.3, FLOOR_TOP + door_h / 2, 10.5)),
        box((0.6, door_h, 1.4), (door_w / 2 + 0.3, FLOOR_TOP + door_h / 2, 10.5)),
        box((door_w + 1.2, 0.6, 1.4), (0, top_of_door + 0.3, 10.5)),
    )

    part("Building_Roof", "roof", box((30, 0.8, 24), (0, WALL_TOP + 0.4, 0)))
    part("Building_RoofTrim", "brand", box((30.2, 1.0, 0.4), (0, WALL_TOP + 0.4, 12.1)))
    part("Building_Awning", "brand", box((11, 0.4, 3), (0, top_of_door + 1.4, 12.3), 0.0))

    # Sign on the roof
    sign_y = WALL_TOP + 3.6
    part(
        "Building_SignPosts",
        "roof",
        box((0.6, 3.0, 0.6), (-6, WALL_TOP + 1.9, 9.4)),
        box((0.6, 3.0, 0.6), (6, WALL_TOP + 1.9, 9.4)),
    )
    part("Building_SignBoard", "brand", box((18, 4.4, 0.6), (0, sign_y, 10.0)))
    text("Building_SignText", "white", "FindJob", 3.0, (0, sign_y, 10.45), depth=0.15)

    # Little welcome kiosk next to the door, where the recruiter stands
    part(
        "Building_Kiosk",
        "brand",
        box((3, 3.4, 1.6), (-8, 1.7, 14)),
    )
    part("Building_KioskTop", "white", box((3.4, 0.3, 2.0), (-8, 3.55, 14)))


def chair(name, x, z, facing_back):
    back_z = z + (1.1 if facing_back else -1.1)
    part(
        name,
        "chair",
        box((2.4, 0.4, 2.4), (x, 2.4, z)),
        box((2.4, 2.6, 0.4), (x, 3.9, back_z)),
        box((0.4, 1.6, 0.4), (x, 1.4, z)),
        box((2.0, 0.3, 0.4), (x, 0.55, z)),
        box((0.4, 0.3, 2.0), (x, 0.55, z)),
    )


def build_computer_corner():
    x, z = -9, -8
    top_y = FLOOR_TOP + 3.4
    legs = [box((0.4, 3.2, 0.4), (x + dx, FLOOR_TOP + 1.6, z + dz)) for dx in (-3.2, 3.2) for dz in (-1.3, 1.3)]
    part("Computer_Desk", "wood", box((7, 0.4, 3.2), (x, top_y, z)), *legs)

    screen_y = top_y + 2.2
    part(
        "Computer_Monitor",
        "dark",
        box((4, 2.6, 0.3), (x, screen_y, z - 0.9)),
        box((0.4, 1.2, 0.3), (x, top_y + 0.8, z - 1.0)),
        box((1.6, 0.2, 1.0), (x, top_y + 0.3, z - 1.0)),
    )
    part("Computer_Screen", "screen", box((3.6, 2.2, 0.05), (x, screen_y, z - 0.73)))
    part(
        "Computer_Keyboard",
        "dark",
        box((2.8, 0.2, 0.9), (x, top_y + 0.3, z + 0.4)),
        box((0.4, 0.2, 0.6), (x + 2.0, top_y + 0.3, z + 0.4)),
    )
    chair("Computer_Chair", x, z + 3.0, facing_back=True)

    part("Building_PlantPot", "pot", cylinder(0.8, 1.4, (-12, FLOOR_TOP + 0.7, -9)))
    part("Building_PlantLeaves", "leaf", sphere(1.3, (-12, FLOOR_TOP + 2.5, -9)))


def build_teacher_corner():
    x, z = 9, -4.5
    top_y = FLOOR_TOP + 3.4
    part(
        "TeacherDesk_Desk",
        "wood",
        box((7, 0.4, 3.2), (x, top_y, z)),
        box((7, 3.0, 0.3), (x, FLOOR_TOP + 1.7, z + 1.45)),  # front panel facing the room
        box((0.4, 3.2, 3.2), (x - 3.3, FLOOR_TOP + 1.6, z)),
        box((0.4, 3.2, 3.2), (x + 3.3, FLOOR_TOP + 1.6, z)),
    )
    part(
        "TeacherDesk_Papers",
        "white",
        box((1.6, 0.5, 2.1), (x - 1.2, top_y + 0.45, z)),
        box((1.6, 0.3, 2.1), (x + 0.9, top_y + 0.35, z - 0.1), math.radians(8)),
    )
    part("TeacherDesk_Apple", "apple", sphere(0.4, (x + 2.6, top_y + 0.6, z + 0.5)))
    part("TeacherDesk_Pencil", "accent", box((0.15, 0.15, 1.4), (x + 0.2, top_y + 0.28, z + 0.9), math.radians(70)))
    chair("TeacherDesk_Chair", x, z - 3.0, facing_back=False)

    board_y = FLOOR_TOP + 7.2
    part("Building_ChalkboardFrame", "wood", box((10, 5.6, 0.3), (x, board_y, -9.85)))
    part("Building_Chalkboard", "board", box((9.2, 4.8, 0.1), (x, board_y, -9.65)))
    text("Building_ChalkText", "white", "2 + 2 = 4", 0.9, (x, board_y + 0.8, -9.57), depth=0.02)
    text("Building_ChalkText2", "white", "A B C", 0.9, (x, board_y - 0.8, -9.57), depth=0.02)


def main():
    clear_scene()
    build_shell()
    build_computer_corner()
    build_teacher_corner()

    os.makedirs(os.path.dirname(EXPORT_PATH), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)

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
    print(f"Exported {len(bpy.data.objects)} objects to {EXPORT_PATH}")


main()
