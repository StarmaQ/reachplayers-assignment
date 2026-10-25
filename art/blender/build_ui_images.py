"""
Renders the clipboard UI image from a simple 3D model,
top-down with a transparent background.

Run:  blender --background --python art/blender/build_ui_images.py
Output: art/export/Clipboard.png
"""

import os

import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXPORT_DIR = os.path.join(ROOT, "export")


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)


def material(name, color):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    return mat


def rounded_slab(name, width, height, thickness, radius, z, color):
    """Plane with rounded corners, given some thickness. Sizes in Blender units."""
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, z))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (width, height, 1)
    bpy.ops.object.transform_apply(scale=True)

    bevel = obj.modifiers.new("Round", "BEVEL")
    bevel.affect = "VERTICES"
    bevel.width = radius
    bevel.segments = 10
    solid = obj.modifiers.new("Thickness", "SOLIDIFY")
    solid.thickness = thickness

    obj.data.materials.append(material(name, color))
    return obj


def flat_box(name, width, height, z, color, x=0.0, y=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (width, height, 0.01)
    obj.data.materials.append(material(name, color))
    return obj


def render(filename, width, height, ortho_scale):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "MATERIAL"
    scene.view_settings.view_transform = "Standard"
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.resolution_x = width
    scene.render.resolution_y = height

    cam_data = bpy.data.cameras.new("Camera")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ortho_scale
    cam = bpy.data.objects.new("Camera", cam_data)
    cam.location = (0, 0, 10)
    bpy.context.scene.collection.objects.link(cam)
    scene.camera = cam

    scene.render.filepath = os.path.join(EXPORT_DIR, filename)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


def build_clipboard():
    clear_scene()
    rounded_slab("BoardShadow", 7.6, 10.2, 0.05, 0.45, -0.3, (0.3, 0.2, 0.12))
    bpy.context.active_object.location.y = -0.12
    rounded_slab("Board", 7.6, 10.2, 0.25, 0.45, 0, (0.62, 0.42, 0.24))
    rounded_slab("PaperShadow", 6.8, 8.9, 0.02, 0.08, 0.28, (0.45, 0.3, 0.17))
    bpy.context.active_object.location.xy = (0.06, -0.3)
    rounded_slab("Paper", 6.8, 8.9, 0.05, 0.08, 0.3, (0.98, 0.97, 0.94))
    bpy.context.active_object.location.y = -0.2
    rounded_slab("ClipShadow", 3.0, 1.3, 0.02, 0.3, 0.4, (0.35, 0.33, 0.32))
    bpy.context.active_object.location.xy = (0.05, 4.5)
    rounded_slab("Clip", 3.0, 1.3, 0.2, 0.3, 0.45, (0.78, 0.8, 0.84))
    bpy.context.active_object.location.y = 4.6
    rounded_slab("ClipHole", 1.0, 0.45, 0.05, 0.2, 0.7, (0.4, 0.42, 0.46))
    bpy.context.active_object.location.y = 4.75
    render("Clipboard.png", 768, 1024, 10.6)


build_clipboard()
