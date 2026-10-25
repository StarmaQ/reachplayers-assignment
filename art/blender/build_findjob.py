"""
Builds the FindJob job-fair stand and its two mission pedestals, then exports one FBX for Roblox.

Run:  blender --background --python art/blender/build_findjob.py

Style: "Expo Toy"
  - an open-air job-fair stand: round platform, branded back wall, header lightbox,
    two totem screens, a reception desk
  - chunky low-poly pieces with chamfered edges, flat colors, no textures
  - white panels + charcoal frames, FindJob blue as the anchor, teal / coral / sun as accents
  - every screen is a dark panel with a Marker on it; the game draws live UI there

Everything is written in Roblox coordinates (studs, Y up, the stand faces +Z) and mapped to
Blender's Z-up space. 1 Blender unit = 1 stud.

Object names: Group_Name__palette
  Stand                 solid scenery
  Decor                 no collision
  PcPedestal, ExamPedestal   the two mission pedestals (solid)
  ExamItem              the floating item that spins above the exam pedestal
                        (the computer item is the game's own model, added by post_import.luau)
  Marker                invisible helpers: recruiter spot, screens (Screen*), computer spot (PcItemSpot)
  palette               key in PALETTE, used by art/studio/post_import.luau to color the part
"""

import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXPORT_PATH = os.path.join(ROOT, "export", "FindJob.fbx")
BLEND_PATH = os.path.join(ROOT, "blender", "FindJob.blend")
FONT_PATH = "C:/Windows/Fonts/ariblk.ttf"

# sRGB 0-255, keep in sync with art/studio/post_import.luau
PALETTE = {
    "platform": (226, 230, 238),
    "panel": (246, 247, 250),
    "frame": (45, 49, 66),
    "screenOff": (22, 26, 40),
    "blue": (47, 111, 237),
    "teal": (46, 196, 182),
    "coral": (255, 107, 107),
    "sun": (255, 201, 60),
    "carpet": (38, 72, 160),
    "leaf": (123, 211, 137),
    "leafDark": (59, 170, 92),
    "white": (255, 255, 255),
    "paper": (252, 250, 240),
    "screen": (90, 170, 255),
    "glow": (130, 220, 255),
    "red": (225, 50, 60),
    "chrome": (196, 204, 216),
    "inlay": (212, 218, 230),
    "glass": (170, 225, 255),
}

# Roblox space (x, y up, z) <-> Blender space (x, -z, y)
TO_BLENDER = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
TO_ROBLOX = TO_BLENDER.inverted()


def srgb_to_linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(key):
    mat = bpy.data.materials.get(key)
    if mat is None:
        mat = bpy.data.materials.new(key)
        color = (*(srgb_to_linear(c) for c in PALETTE[key]), 1.0)
        mat.diffuse_color = color
        bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat.node_tree else None
        if bsdf:
            bsdf.inputs["Base Color"].default_value = color
            bsdf.inputs["Roughness"].default_value = 0.55
            if key in ("screen", "glow"):
                bsdf.inputs["Emission Color"].default_value = color
                bsdf.inputs["Emission Strength"].default_value = 3.0
    return mat


# Primitives -------------------------------------------------------------------
# Each returns a description; part() turns a list of them into one mesh object.


def box(size, center, rot=(0, 0, 0), bevel=None):
    return {"kind": "box", "size": size, "center": center, "rot": rot, "bevel": bevel}


def cylinder(radius, height, center, rot=(0, 0, 0), sides=12, top_radius=None):
    return {
        "kind": "cylinder",
        "size": (radius, height, top_radius if top_radius is not None else radius),
        "center": center,
        "rot": rot,
        "sides": sides,
    }


def blob(radius, center, seed=0, squash=1.0, stretch=1.0):
    """Faceted low-poly ball (foliage)."""
    return {
        "kind": "blob",
        "size": radius,
        "center": center,
        "rot": (0, 0, 0),
        "seed": seed,
        "squash": squash,
        "stretch": stretch,
    }


def ring(radius, thickness, center, rot=(0, 0, 0), segments=24):
    return {"kind": "ring", "size": (radius, thickness), "center": center, "rot": rot, "segments": segments}


def roblox_matrix(center, rot):
    rx, ry, rz = (math.radians(a) for a in rot)
    rotation = Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(rz, 4, "Z")
    return Matrix.Translation(center) @ rotation


def make_ring(bm, radius, thickness, segments, sides=6):
    """Torus lying in Blender's XY plane."""
    grid = []
    for i in range(segments):
        a = i / segments * math.tau
        row = []
        for j in range(sides):
            b = j / sides * math.tau
            r = radius + thickness * math.cos(b)
            row.append(bm.verts.new((r * math.cos(a), r * math.sin(a), thickness * math.sin(b))))
        grid.append(row)
    for i in range(segments):
        for j in range(sides):
            bm.faces.new(
                (
                    grid[i][j],
                    grid[(i + 1) % segments][j],
                    grid[(i + 1) % segments][(j + 1) % sides],
                    grid[i][(j + 1) % sides],
                )
            )
    return [v for row in grid for v in row]


def add_primitive(bm, prim):
    kind = prim["kind"]

    if kind == "box":
        verts = bmesh.ops.create_cube(bm, size=1.0)["verts"]
        sx, sy, sz = prim["size"]
        # Scale in Roblox space; the cube is symmetric so no axis swap is needed first
        local = Matrix.Diagonal((sx, sy, sz, 1.0))
    elif kind == "cylinder":
        radius, height, top = prim["size"]
        verts = bmesh.ops.create_cone(
            bm, cap_ends=True, segments=prim["sides"], radius1=radius, radius2=top, depth=height
        )["verts"]
        local = TO_ROBLOX  # Blender builds it along Z, which is Roblox's Y
    elif kind == "ring":
        radius, thickness = prim["size"]
        verts = make_ring(bm, radius, thickness, prim["segments"])
        local = TO_ROBLOX
    else:  # blob
        radius = prim["size"]
        verts = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=radius)["verts"]
        rng = random.Random(prim["seed"])
        for v in verts:
            v.co += Vector([rng.uniform(-0.12, 0.12) * radius for _ in range(3)])
            v.co.z *= prim["squash"]
            v.co.x *= prim["stretch"]
        local = TO_ROBLOX

    placed = TO_BLENDER @ roblox_matrix(prim["center"], prim["rot"]) @ local
    bmesh.ops.transform(bm, matrix=placed, verts=verts)

    if kind == "box":
        # Toy-block chamfer on every edge
        bevel = prim["bevel"]
        if bevel is None:
            bevel = (min(0.3, min(prim["size"]) * 0.22), 2)
        offset, segments = bevel if isinstance(bevel, tuple) else (bevel, 1)
        if offset > 0:
            edges = list({e for v in verts for e in v.link_edges})
            bmesh.ops.bevel(
                bm, geom=edges, offset=offset, segments=segments, profile=0.5, affect="EDGES", clamp_overlap=True
            )


def finish_object(name, mesh, palette_key):
    # Origin at the bounding box center so each MeshPart pivots sensibly
    coords = [v.co for v in mesh.vertices]
    lo = Vector((min(c.x for c in coords), min(c.y for c in coords), min(c.z for c in coords)))
    hi = Vector((max(c.x for c in coords), max(c.y for c in coords), max(c.z for c in coords)))
    center = (lo + hi) / 2
    mesh.transform(Matrix.Translation(-center))
    mesh.materials.append(material(palette_key))
    for polygon in mesh.polygons:
        polygon.use_smooth = False

    obj = bpy.data.objects.new(f"{name}__{palette_key}", mesh)
    obj.location = center
    bpy.context.collection.objects.link(obj)
    return obj


def part(name, palette_key, *prims):
    bm = bmesh.new()
    for prim in prims:
        add_primitive(bm, prim)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return finish_object(name, mesh, palette_key)


def text(name, palette_key, body, height, center, rot=(0, 0, 0), depth=0.1):
    """Extruded text, facing +Z before rot is applied."""
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

    # Font geometry lies in Blender's XY plane facing +Z; standing it up makes it face Roblox +Z
    stand_up = Matrix.Rotation(math.radians(90), 4, "X")
    mesh.transform(TO_BLENDER @ roblox_matrix(center, rot) @ TO_ROBLOX @ stand_up)
    return finish_object(name, mesh, palette_key)


def marker(name, size, center, rot=(0, 0, 0)):
    return part(f"Marker_{name}", "white", box(size, center, rot=rot, bevel=0))


# Stand ------------------------------------------------------------------------

FLOOR = 0.5  # top of the platform
PLATFORM_RADIUS = 22
WALL_Z = -8


def build_platform():
    part("Stand_Platform", "platform", cylinder(PLATFORM_RADIUS, FLOOR, (0, FLOOR / 2, 0), sides=48))
    part("Decor_PlatformInlay", "inlay", cylinder(15, 0.04, (0, FLOOR + 0.02, 0), sides=48))
    part("Decor_PlatformRim", "blue", ring(PLATFORM_RADIUS, 0.28, (0, FLOOR - 0.05, 0), segments=64))
    part("Decor_PlatformLed", "glow", ring(PLATFORM_RADIUS - 0.55, 0.09, (0, FLOOR + 0.03, 0), segments=64))
    part("Decor_Carpet", "carpet", box((20, 0.08, 9), (0, FLOOR + 0.04, 8), bevel=0.04))
    part(
        "Decor_CarpetEdge",
        "sun",
        box((20, 0.1, 0.25), (0, FLOOR + 0.05, 3.62), bevel=0),
        box((20, 0.1, 0.25), (0, FLOOR + 0.05, 12.38), bevel=0),
    )


def build_back_wall():
    part("Stand_BackWall", "panel", box((34, 13, 0.8), (0, FLOOR + 6.5, WALL_Z), bevel=(0.2, 2)))
    marker("ScreenWall", (32.4, 12.2, 0.02), (0, FLOOR + 6.5, WALL_Z + 0.42))
    part("Decor_WallCap", "frame", box((34.6, 0.5, 1.2), (0, FLOOR + 13.2, WALL_Z), bevel=(0.15, 2)))
    part("Decor_WallKick", "blue", box((34.6, 0.6, 1.2), (0, FLOOR + 0.3, WALL_Z), bevel=(0.15, 2)))
    part(
        "Stand_Pillars",
        "frame",
        box((1.4, 14.5, 1.4), (-17.6, FLOOR + 7.25, WALL_Z), bevel=(0.3, 2)),
        box((1.4, 14.5, 1.4), (17.6, FLOOR + 7.25, WALL_Z), bevel=(0.3, 2)),
    )
    part(
        "Decor_PillarLeds",
        "glow",
        box((0.16, 12.5, 0.1), (-17.6, FLOOR + 7.2, WALL_Z + 0.72), bevel=0),
        box((0.16, 12.5, 0.1), (17.6, FLOOR + 7.2, WALL_Z + 0.72), bevel=0),
    )

    # Header lightbox on two posts, with spotlights
    header_y = FLOOR + 17
    part(
        "Stand_HeaderPosts",
        "frame",
        cylinder(0.35, 3.2, (-9, FLOOR + 14.4, WALL_Z), sides=10),
        cylinder(0.35, 3.2, (9, FLOOR + 14.4, WALL_Z), sides=10),
    )
    part("Stand_Header", "frame", box((27, 5.6, 1.4), (0, header_y, WALL_Z + 0.2), bevel=(0.4, 3)))
    part("Decor_HeaderGlass", "screenOff", box((25.6, 4.4, 0.1), (0, header_y, WALL_Z + 0.92), bevel=0))
    marker("ScreenHeader", (25.4, 4.2, 0.02), (0, header_y, WALL_Z + 0.99))
    part("Decor_HeaderLed", "glow", box((26, 0.14, 0.14), (0, header_y - 2.86, WALL_Z + 0.92), bevel=0))
    for i, x in enumerate((-9, 9)):
        part(f"Decor_Spotlight{i}", "frame", cylinder(0.38, 0.9, (x, FLOOR + 15.2, WALL_Z + 0.75), rot=(-55, 0, 0), sides=10))
        part(f"Decor_SpotlightLens{i}", "glow", cylinder(0.3, 0.06, (x, FLOOR + 14.95, WALL_Z + 1.12), rot=(-55, 0, 0), sides=10))



TOTEM_TURN = 22  # degrees, mirrored in art/studio/post_import.luau (SCREEN_TURN)


def build_totem(name, x, z, turn, balloon_colors):
    """Tall standing screen like an expo totem, turned to face the visitors."""
    base_y = FLOOR + 0.3
    a = math.radians(turn)

    def at(local_x, local_y, local_z):
        # Rotate a point of the totem around its own center by `turn` degrees
        return (x + local_x * math.cos(a) + local_z * math.sin(a), local_y, z - local_x * math.sin(a) + local_z * math.cos(a))

    rot = (0, turn, 0)
    part(
        f"Stand_{name}",
        "frame",
        box((6.2, 0.6, 2.6), at(0, base_y, 0), rot=rot, bevel=(0.2, 2)),
        box((5.6, 12.6, 1.2), at(0, base_y + 6.6, 0), rot=rot, bevel=(0.3, 2)),
        cylinder(0.8, 5.8, at(0, base_y + 13.1, 0), rot=(0, turn, 90), sides=14),
    )
    part(f"Decor_{name}Glass", "screenOff", box((4.8, 11.2, 0.1), at(0, base_y + 6.6, 0.62), rot=rot, bevel=0))
    marker(f"Screen{name}", (4.6, 11, 0.02), at(0, base_y + 6.6, 0.69), rot=rot)
    part(
        f"Decor_{name}Leds",
        "glow",
        box((0.12, 11.6, 0.1), at(-2.62, base_y + 6.6, 0.64), rot=rot, bevel=0),
        box((0.12, 11.6, 0.1), at(2.62, base_y + 6.6, 0.64), rot=rot, bevel=0),
    )
    part(f"Decor_{name}Badge", "sun", cylinder(0.55, 0.12, at(0, base_y + 13.1, 0.82), rot=(90, turn, 0), sides=16))
    part(f"Decor_{name}Foot", "blue", box((6.4, 0.2, 2.8), at(0, base_y - 0.32, 0), rot=rot, bevel=(0.08, 1)))

    # A little bunch of balloons tied to the end of the cap
    knot = Vector(at(-2.9, base_y + 13.1, 0))
    for i, (offset, color) in enumerate(zip(((-0.6, 3.4, 0.4), (0.6, 4.2, -0.3), (-1.2, 4.8, -0.2)), balloon_colors)):
        lx, ly, lz = offset
        balloon = knot + Vector((lx * math.cos(a) + lz * math.sin(a), ly, -lx * math.sin(a) + lz * math.cos(a)))
        part(f"Decor_{name}Balloon{i}", color, blob(0.85, tuple(balloon), seed=i + len(name), squash=1.2))
        # String from the knot to the bottom of the balloon
        bottom = balloon - Vector((0, 1.0, 0))
        direction = bottom - knot
        length = direction.length
        direction.normalize()
        pitch = math.degrees(math.acos(max(-1, min(1, direction.y))))
        yaw = math.degrees(math.atan2(direction.x, direction.z))
        part(f"Decor_{name}String{i}", "frame", cylinder(0.03, length, tuple((knot + bottom) / 2), rot=(pitch, yaw, 0), sides=4))


def build_desk():
    z = 1
    part("Stand_Desk", "frame", box((14, 4, 3), (0, FLOOR + 2, z), bevel=(0.3, 3)))
    part("Stand_DeskTop", "panel", box((14.8, 0.45, 3.8), (0, FLOOR + 4.2, z - 0.1), bevel=(0.15, 2)))
    part("Decor_DeskKick", "blue", box((14.2, 0.5, 3.2), (0, FLOOR + 0.25, z), bevel=(0.1, 2)))
    part(
        "Decor_DeskCaps",
        "blue",
        box((0.7, 4.1, 3.2), (-7.1, FLOOR + 2, z), bevel=(0.2, 2)),
        box((0.7, 4.1, 3.2), (7.1, FLOOR + 2, z), bevel=(0.2, 2)),
    )
    part("Decor_DeskGlass", "screenOff", box((12.2, 2.9, 0.1), (0, FLOOR + 2.1, z + 1.52), bevel=0))
    marker("ScreenDesk", (12, 2.7, 0.02), (0, FLOOR + 2.1, z + 1.59))
    part("Decor_DeskLed", "glow", box((14, 0.12, 0.12), (0, FLOOR + 3.92, z + 1.62), bevel=0))

    # Small monitor on the desk, like the reference's product screen
    top = FLOOR + 4.42
    part(
        "Stand_DeskMonitor",
        "frame",
        box((3.6, 2.4, 0.3), (4.4, top + 2.0, z - 0.4), bevel=(0.1, 2)),
        box((0.3, 0.9, 0.25), (4.4, top + 0.45, z - 0.5), bevel=0),
        box((1.4, 0.12, 0.9), (4.4, top + 0.06, z - 0.5), bevel=0.04),
    )
    marker("ScreenMonitor", (3.2, 2.0, 0.02), (4.4, top + 2.0, z - 0.23))

    # Things on the desk: brochures, a pen cup, a little table sign
    part("Decor_Brochures", "coral", box((1.4, 0.16, 1.9), (-4.6, top + 0.08, z - 0.2), rot=(0, 12, 0), bevel=0.03))
    part("Decor_Brochures2", "teal", box((1.4, 0.16, 1.9), (-4.4, top + 0.24, z - 0.25), rot=(0, -6, 0), bevel=0.03))
    part("Decor_PenCup", "frame", cylinder(0.32, 0.8, (-2.4, top + 0.4, z - 0.6), sides=12))
    part(
        "Decor_Pens",
        "sun",
        cylinder(0.05, 1.1, (-2.45, top + 0.95, z - 0.6), rot=(0, 0, 8), sides=6),
        cylinder(0.05, 1.1, (-2.32, top + 0.95, z - 0.55), rot=(8, 0, -6), sides=6),
    )
    tilt = -18  # leaning back
    normal = Vector((0, math.sin(math.radians(-tilt)), math.cos(math.radians(tilt))))
    sign_center = Vector((0.6, top + 0.5, z + 0.8))
    part("Decor_TableSign", "blue", box((2.6, 1.0, 0.08), tuple(sign_center), rot=(tilt, 0, 0), bevel=0.03))
    text("Decor_TableSignText", "white", "FindJob", 0.42, tuple(sign_center + normal * 0.06), rot=(tilt, 0, 0), depth=0.02)

    # Maya greets visitors on the grass at the front-right, where they walk up
    marker("RecruiterSpot", (2, 0.2, 2), (15, 0.1, z + 23))


def build_brochure_rack(x, z, turn):
    rot = (0, turn, 0)
    part(
        "Stand_BrochureRack",
        "chrome",
        box((1.8, 0.2, 1.2), (x, FLOOR + 0.1, z), rot=rot, bevel=0.05),
        box((0.14, 5.2, 0.14), (x - 0.8, FLOOR + 2.6, z - 0.3), rot=rot, bevel=0),
        box((0.14, 5.2, 0.14), (x + 0.8, FLOOR + 2.6, z - 0.3), rot=rot, bevel=0),
    )
    for i, color in enumerate(("coral", "teal", "sun")):
        y = FLOOR + 1.6 + i * 1.3
        part(f"Decor_RackShelf{i}", "chrome", box((1.7, 0.08, 0.5), (x, y, z), rot=(-25, turn, 0), bevel=0))
        part(f"Decor_RackBrochure{i}", color, box((1.4, 1.1, 0.08), (x, y + 0.45, z - 0.1), rot=(-20, turn, 0), bevel=0.02))


def plant(name, x, z, seed):
    part(f"Stand_{name}Pot", "panel", cylinder(1.4, 2.2, (x, FLOOR + 1.1, z), sides=14, top_radius=1.7))
    part(f"Decor_{name}PotRim", "frame", cylinder(1.75, 0.18, (x, FLOOR + 2.25, z), sides=14))
    part(
        f"Decor_{name}Leaves",
        "leaf",
        blob(1.9, (x, FLOOR + 4.0, z), seed=seed, squash=1.2),
        blob(1.4, (x - 1.2, FLOOR + 5.6, z + 0.3), seed=seed + 1, stretch=0.7),
        blob(1.3, (x + 1.1, FLOOR + 6.0, z - 0.2), seed=seed + 2, stretch=0.7),
    )
    part(f"Decor_{name}LeavesDark", "leafDark", blob(1.2, (x + 0.3, FLOOR + 7.2, z), seed=seed + 3, squash=1.3))


def pedestal(group, x, z, accent, label):
    """Stepped round pedestal with a chrome band, a glowing top and a label plate."""
    part(
        f"{group}_Base",
        "frame",
        cylinder(2.3, 0.45, (x, FLOOR + 0.45, z), sides=24),
        cylinder(1.5, 3.4, (x, FLOOR + 2.3, z), sides=24),
    )
    part(f"Decor_{group}Step", "chrome", cylinder(2.6, 0.22, (x, FLOOR + 0.11, z), sides=24))
    part(f"Decor_{group}Band", "chrome", cylinder(1.56, 0.22, (x, FLOOR + 3.4, z), sides=24))
    part(f"{group}_Top", accent, cylinder(2.0, 0.5, (x, FLOOR + 4.25, z), sides=24))
    part(f"Decor_{group}Glow", "glow", ring(2.0, 0.12, (x, FLOOR + 4.52, z), segments=32))
    part(f"Decor_{group}Disc", "glow", cylinder(1.6, 0.04, (x, FLOOR + 4.52, z), sides=24))
    part(f"Decor_{group}Plate", accent, box((2.8, 0.9, 0.3), (x, FLOOR + 2.6, z + 1.5), bevel=(0.1, 2)))
    text(f"Decor_{group}Label", "white", label, 0.42, (x, FLOOR + 2.6, z + 1.7), depth=0.05)


def build_pedestals():
    # Programmer: the computer model from the game goes here (art/studio/post_import.luau)
    x, z = -9, 12
    pedestal("PcPedestal", x, z, "blue", "PROGRAMMER")
    marker("PcItemSpot", (0.4, 0.4, 0.4), (x, FLOOR + 6.4, z))

    # Teacher: a stack of exams leaning towards the visitor, with a big pen on top
    x, z = 9, 12
    pedestal("ExamPedestal", x, z, "coral", "TEACHER")
    tilt = 60
    a = math.radians(tilt)
    normal = Vector((0, math.cos(a), math.sin(a)))  # paper face, pointing up and at the visitor
    up_page = Vector((0, math.sin(a), -math.cos(a)))  # towards the top edge of the page
    right = Vector((1, 0, 0))
    center = Vector((x, FLOOR + 7.1, z))

    def on_page(across, up, lift=0.0):
        return tuple(center + right * across + up_page * up + normal * lift)

    part(
        "ExamItem_Papers",
        "paper",
        *[box((2.8, 0.1, 3.6), on_page(0.08 * (i - 1), 0, 0.11 * i - 0.22), rot=(tilt, 5 - 5 * i, 0), bevel=0.03) for i in range(3)],
    )
    text("ExamItem_Grade", "red", "A+", 1.0, on_page(0.5, 1.0, 0.08), rot=(tilt - 90, 0, 0), depth=0.04)
    part(
        "ExamItem_Lines",
        "blue",
        *[box((1.9, 0.04, 0.14), on_page(-0.2, -0.2 - i * 0.5, 0.06), rot=(tilt, 0, 0), bevel=0) for i in range(3)],
    )

    # Pen lying diagonally across the page
    pen_dir = (right * math.cos(math.radians(40)) + up_page * math.sin(math.radians(40))).normalized()
    pen_center = Vector(on_page(0.4, -0.4, 0.35))

    def along(distance):
        return tuple(pen_center + pen_dir * distance)

    # Cylinders are built along Y; tilt then turn them so Y points along the pen
    pitch = math.degrees(math.asin(max(-1, min(1, pen_dir.y))))
    yaw = math.degrees(math.atan2(pen_dir.x, pen_dir.z))
    pen_rot = (90 - pitch, yaw, 0)  # cylinder's Y axis -> pen_dir
    part("ExamItem_Pen", "blue", cylinder(0.24, 3.0, along(0), rot=pen_rot, sides=8))
    part("ExamItem_PenCap", "sun", cylinder(0.28, 0.6, along(1.6), rot=pen_rot, sides=8))
    part(
        "ExamItem_PenTip",
        "frame",
        cylinder(0.24, 0.55, along(-1.77), rot=(pen_rot[0] + 180, pen_rot[1], 0), sides=8, top_radius=0.02),
    )


def build_stand():
    build_platform()
    build_back_wall()
    build_totem("TotemLeft", -15, 1, TOTEM_TURN, ("coral", "sun", "teal"))
    build_totem("TotemRight", 15, 1, -TOTEM_TURN, ("teal", "coral", "sun"))
    build_desk()
    build_brochure_rack(12.2, 7, -30)
    # The big FindJob letters on the grass are their own model: art/blender/build_sign.py
    plant("PlantLeft", -12.5, -5.5, seed=3)
    plant("PlantRight", 12.5, -5.5, seed=9)
    build_pedestals()


# Export -----------------------------------------------------------------------


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    for curve in list(bpy.data.curves):
        bpy.data.curves.remove(curve)


def main():
    clear_scene()
    build_stand()

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
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    triangles = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
    print(f"Exported {len(meshes)} objects, {triangles} triangles to {EXPORT_PATH}")


main()
