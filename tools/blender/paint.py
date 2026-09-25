"""Bake subdued painted procedural albedo to one UV atlas per asset."""
import bpy
from pathlib import Path


def bake_albedo(name, objects, root):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.025)
    bpy.ops.object.mode_set(mode='OBJECT')
    image = bpy.data.images.new(name + '_albedo', width=512, height=512)
    materials = {slot.material for obj in objects for slot in obj.material_slots}
    for mat in materials:
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        base = tuple(mat.diffuse_color)
        nodes.clear()
        out = nodes.new('ShaderNodeOutputMaterial')
        emit = nodes.new('ShaderNodeEmission')
        links.new(emit.outputs[0], out.inputs['Surface'])
        tex = nodes.new('ShaderNodeTexCoord')
        stretch = nodes.new('ShaderNodeVectorMath')
        stretch.operation = 'MULTIPLY'
        grain = mat.name.startswith(('Wood', 'Straw', 'Rope'))
        stretch.inputs[1].default_value = (32, 32, 3) if grain else (18, 4, 26)
        links.new(tex.outputs['Generated'], stretch.inputs[0])
        noise = nodes.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = 2
        noise.inputs['Detail'].default_value = 2
        links.new(stretch.outputs[0], noise.inputs['Vector'])
        ramp = nodes.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].color = tuple(c * .72 for c in base[:3]) + (1,)
        ramp.color_ramp.elements[1].color = tuple(min(1, c * 1.13) for c in base[:3]) + (1,)
        links.new(noise.outputs['Fac'], ramp.inputs[0])
        sep = nodes.new('ShaderNodeSeparateXYZ')
        links.new(tex.outputs['Generated'], sep.inputs[0])
        gradient = nodes.new('ShaderNodeMixRGB')
        gradient.blend_type = 'MULTIPLY'
        gradient.inputs[0].default_value = .12
        links.new(ramp.outputs[0], gradient.inputs[1])
        links.new(sep.outputs['Z'], gradient.inputs[2])
        bevel = nodes.new('ShaderNodeBevel')
        bevel.inputs['Radius'].default_value = .018
        bevel.samples = 4
        geometry = nodes.new('ShaderNodeNewGeometry')
        edge = nodes.new('ShaderNodeVectorMath')
        edge.operation = 'DISTANCE'
        links.new(bevel.outputs['Normal'], edge.inputs[0])
        links.new(geometry.outputs['Normal'], edge.inputs[1])
        highlight = nodes.new('ShaderNodeMixRGB')
        links.new(edge.outputs['Value'], highlight.inputs[0])
        links.new(gradient.outputs[0], highlight.inputs[1])
        highlight.inputs[2].default_value = tuple(min(1, c * 1.18) for c in base[:3]) + (1,)
        links.new(highlight.outputs[0], emit.inputs['Color'])
        target = nodes.new('ShaderNodeTexImage')
        target.image = image
        nodes.active = target
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 1
    scene.render.bake.margin = 8
    scene.render.bake.use_clear = False
    # Bake one object at a time into the shared atlas; UVs were packed together.
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.bake(type='EMIT')
        obj.select_set(False)
    folder = root / 'assets' / 'textures'
    folder.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(folder / (name + '_albedo.png'))
    image.file_format = 'PNG'
    image.save()
    for mat in materials:
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        nodes.clear()
        out = nodes.new('ShaderNodeOutputMaterial')
        shader = nodes.new('ShaderNodeBsdfPrincipled')
        shader.inputs['Roughness'].default_value = .85
        texture = nodes.new('ShaderNodeTexImage')
        texture.image = image
        links.new(texture.outputs['Color'], shader.inputs['Base Color'])
        links.new(shader.outputs[0], out.inputs['Surface'])
        mat.diffuse_color = (1, 1, 1, 1)
