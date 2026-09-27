"""Round 10 prop helpers: chipped bevels, exact legacy placement bounds."""
from common import *


def bevel_mesh(obj, width=.045):
    bpy.context.view_layer.objects.active = obj
    modifier = obj.modifiers.new('Worn chamfers', 'BEVEL')
    modifier.width = width
    modifier.segments = 1
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def fit_legacy(name, size, center_z=0):
    # Bake positions into vertices; retain a ground-centred, unscaled export root.
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    points = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
    low = Vector([min(v[i] for v in points) for i in range(3)])
    high = Vector([max(v[i] for v in points) for i in range(3)])
    target_low = xyz((-size[0]/2, 0, center_z+size[2]/2))
    target_span = Vector((size[0],size[2],size[1]))
    span = high-low
    for obj in objects:
        matrix=obj.matrix_world.copy()
        for v in obj.data.vertices:
            p=matrix @ v.co
            v.co=Vector([target_low[i]+(p[i]-low[i])*target_span[i]/span[i] for i in range(3)])
        obj.matrix_world.identity()
    export(name,3000,expected_size=size)
