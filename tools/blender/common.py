"""Procedural asset helpers. Public coordinates are Godot X/Y-up/-Z-forward, metres."""
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
COLORS = {
    "Stone": (0.53, 0.49, 0.60, 1),
    "StoneLight": (0.76, 0.72, 0.66, 1),
    "Ink": (0.055, 0.07, 0.12, 1),
    "Cloth": (0.18, 0.25, 0.36, 1),
    "Lining": (0.38, 0.19, 0.30, 1),
    "Gold": (0.88, 0.62, 0.25, 1),
    "Leather": (0.22, 0.14, 0.12, 1),
    "Skin": (0.71, 0.47, 0.32, 1),
    "Crystal": (0.61, 0.38, 0.91, 1),
    "Flame": (1.0, 0.36, 0.08, 1),
}


def xyz(p):
    return Vector((p[0], -p[2], p[1]))


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0


def material(name):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = COLORS[name]
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = COLORS[name]
        shader.inputs["Roughness"].default_value = 0.85
    return mat


def finish(obj, name, color, bevel=0):
    obj.name = name
    obj.data.materials.append(material(color))
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Chunky bevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def box(name, pos, size, color="Stone", bevel=0.03):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(pos))
    obj = bpy.context.object
    obj.scale = (size[0], size[2], size[1])
    return finish(obj, name, color, bevel)


def mesh(name, points, faces, color):
    data = bpy.data.meshes.new(name)
    data.from_pydata([xyz(p) for p in points], [], faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material(color))
    return obj


def profile(name, rings, color, sides=12):
    """Closed faceted elliptical loft: rings are (x, y, z, radius_x, radius_z)."""
    points = []
    for x, y, z, rx, rz in rings:
        for i in range(sides):
            a = 2 * math.pi * i / sides
            points.append((x + rx * math.cos(a), y, z + rz * math.sin(a)))
    faces = [tuple(reversed(range(sides)))]
    for j in range(len(rings) - 1):
        for i in range(sides):
            k = j * sides + i
            nxt = j * sides + (i + 1) % sides
            faces.append((k, nxt, nxt + sides, k + sides))
    faces.append(tuple(range((len(rings) - 1) * sides, len(rings) * sides)))
    return mesh(name, points, faces, color)


def solidify(obj, thickness=.006):
    bpy.context.view_layer.objects.active = obj
    modifier = obj.modifiers.new("Cloth thickness", "SOLIDIFY")
    modifier.thickness = thickness
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def rod(name, a, b, radius, color="Gold", sides=8):
    start, end = xyz(a), xyz(b)
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius, radius2=radius * 0.85,
                                    depth=(end - start).length, location=(start + end) / 2)
    obj = bpy.context.object
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = (end - start).to_track_quat("Z", "Y")
    return finish(obj, name, color)


def rune(name, x, y, z, scale=1, color="Gold", engraved_in=None):
    """Angular diamond with a central stem; optional real boolean recesses."""
    path = [(0, -.25), (-.18, 0), (0, .25), (.18, 0), (0, -.25)]
    segments = list(zip(path, path[1:])) + [((0, -.34), (0, .34))]
    for i, (a, b) in enumerate(segments):
        obj = rod(name + str(i), (x + a[0]*scale, y + a[1]*scale, z),
                  (x + b[0]*scale, y + b[1]*scale, z), .025*scale, color, 4)
        if engraved_in is not None:
            bpy.context.view_layer.objects.active = engraved_in
            mod = engraved_in.modifiers.new("Rune recess", "BOOLEAN")
            mod.operation = "DIFFERENCE"
            mod.object = obj
            bpy.ops.object.modifier_apply(modifier=mod.name)
            bpy.data.objects.remove(obj, do_unlink=True)


def cover(name, size):
    x, y, z = size
    box("Footing", (0, .09, 0), (x, .18, z), "StoneLight", .045)
    body = box("CarvedStone", (0, y/2, 0), (x-.10, y-.22, z-.10), "Stone", .045)
    box("Capstone", (0, y-.09, 0), (x, .18, z), "StoneLight", .045)
    count = 3 if x > 4 else 1
    for i in range(count):
        px = (i-(count-1)/2) * 1.25
        for side in [-1, 1]:
            rune("IncisedRune", px, y/2, side*(z/2-.05), min(1, y*.85), engraved_in=body)
    export(name, 3000, expected_size=size)


def export(name, budget, expected_size=None):
    bpy.ops.object.select_all(action="DESELECT")
    objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    triangles = 0
    vertices = []
    for obj in objects:
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        vertices.extend(obj.matrix_world @ v.co for v in obj.data.vertices)
    low = [min(v[i] for v in vertices) for i in range(3)]
    high = [max(v[i] for v in vertices) for i in range(3)]
    size = [high[0]-low[0], high[2]-low[2], high[1]-low[1]]
    assert triangles <= budget, (name, triangles, budget)
    if expected_size:
        assert all(abs(a-b) < .001 for a,b in zip(size, expected_size)), (size, expected_size)
    from paint import bake_albedo
    bake_albedo(name, objects, ROOT)
    output = ROOT / "assets" / "models"
    output.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(output / (name + ".glb")), export_format="GLB",
                              export_yup=True, use_selection=False, export_cameras=False,
                              export_lights=False, export_animations=True,
                              export_animation_mode="ACTIONS", export_nla_strips=True)
    report = {"asset": name, "triangles": triangles, "budget": budget,
              "size_xyz_m": [round(v, 5) for v in size], "mesh_objects": len(objects)}
    (output / (name + ".json")).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("ASSET_REPORT " + json.dumps(report))
    if "--preview" in sys.argv:
        preview(name, low, high)


def preview(name, low, high):
    scene = bpy.context.scene
    if name == "fp_arms":
        # Preview poses side by side, after exporting their shared camera origin.
        for index, pose in enumerate(["OpenPalm", "Fist", "PalmDown", "Cast"]):
            bpy.data.objects[pose].location.x += (index - 1.5) * 1.1
        bpy.context.view_layer.update()
        points = [o.matrix_world @ v.co for o in scene.objects if o.type == "MESH" for v in o.data.vertices]
        low = [min(v[i] for v in points) for i in range(3)]
        high = [max(v[i] for v in points) for i in range(3)]
    center = Vector([(a+b)/2 for a,b in zip(low, high)])
    extent = max(b-a for a,b in zip(low, high))
    bpy.ops.object.camera_add(location=center + Vector((1.25, 2, 1))*extent)
    camera = bpy.context.object
    camera.rotation_euler = (center-camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = extent*1.5
    scene.camera = camera
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.world.color = (.25, .25, .25)
    bpy.ops.object.light_add(type="AREA", location=center+Vector((0, 2, 4))*extent)
    bpy.context.object.data.energy = 350*extent*extent
    bpy.context.object.data.shape = "DISK"
    bpy.context.object.data.size = extent*3
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    out = ROOT / "build" / "assets"
    out.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(out / (name+".png"))
    bpy.ops.render.render(write_still=True)
