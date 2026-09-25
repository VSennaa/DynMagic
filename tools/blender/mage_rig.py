"""Small deform rig and five baked actions; coordinates use common.xyz."""
import bpy
import math
from mathutils import Matrix
from common import xyz


def build_rig():
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    data = bpy.data.armatures.new('MageSkeleton')
    rig = bpy.data.objects.new('MageRig', data)
    bpy.context.collection.objects.link(rig)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    definitions = [('root', (0,0,0), (0,.2,0), None),
                   ('spine', (0,.85,0), (0,1.25,0), 'root'),
                   ('head', (0,1.25,0), (0,1.65,0), 'spine')]
    for side, sign in [('L', -1), ('R', 1)]:
        definitions += [('arm_'+side, (sign*.26,1.14,0), (sign*.43,.73,-.045), 'spine'),
                        ('leg_'+side, (sign*.15,.50,0), (sign*.15,.10,0), 'root')]
    definitions += [('hand_R', (.43,.73,-.045), (.43,.83,-.045), 'arm_R')]
    for name, head, tail, parent in definitions:
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = xyz(head), xyz(tail)
        if parent:
            bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    for obj in meshes:
        center = sum((obj.matrix_world @ v.co for v in obj.data.vertices), xyz((0,0,0))) / len(obj.data.vertices)
        side = 'L' if center.x < 0 else 'R'
        name = obj.name.split('.')[0]
        if name in ['Sleeve', 'Cuff', 'Glove', 'Thumb']:
            bone = 'hand_R' if side == 'R' and name in ['Glove', 'Thumb'] else 'arm_'+side
        elif name in ['Boot', 'BootCuff']:
            bone = 'leg_'+side
        elif center.z > 1.25:
            bone = 'head'
        else:
            bone = 'spine'
        if name in ['LongCloak', 'CloakLapel', 'GoldHem', 'CloakSigil']:
            lower = obj.vertex_groups.new(name='root')
            upper = obj.vertex_groups.new(name='spine')
            for vertex in obj.data.vertices:
                height = (obj.matrix_world @ vertex.co).z
                weight = max(0, min(1, (height-.30)/.80))
                lower.add([vertex.index], 1-weight, 'REPLACE')
                upper.add([vertex.index], weight, 'REPLACE')
        else:
            obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
        mod = obj.modifiers.new('Mage deformation', 'ARMATURE')
        mod.object = rig
        obj.parent = rig
    scene = bpy.context.scene
    scene.render.fps = 30
    rig.animation_data_create()
    for action_name, duration in [('idle', 60), ('walk', 30), ('cast', 18), ('dash', 12), ('death', 30)]:
        action = bpy.data.actions.new(action_name)
        rig.animation_data.action = action
        for frame in range(1, duration+2):
            t = (frame-1)/duration
            wave = math.sin(t*math.tau)
            for bone in rig.pose.bones:
                bone.rotation_mode = 'XYZ'
                bone.rotation_euler = (0,0,0)
                bone.location = (0,0,0)
            if action_name == 'idle':
                rig.pose.bones['spine'].rotation_euler.x = wave*.025
                rig.pose.bones['head'].rotation_euler.y = wave*.02
            elif action_name == 'walk':
                for side, sign in [('L',1), ('R',-1)]:
                    rig.pose.bones['leg_'+side].rotation_euler.x = wave*.34*sign
                    rig.pose.bones['arm_'+side].rotation_euler.x = -wave*(.10 if side == 'R' else .30)*sign
                rig.pose.bones['root'].location.y = abs(wave)*.025
            elif action_name == 'cast':
                pulse = math.sin(math.pi*t)**.5
                rig.pose.bones['arm_R'].rotation_euler.x = 1.30*pulse
                rig.pose.bones['arm_L'].rotation_euler.x = .25*pulse
                rig.pose.bones['spine'].rotation_euler.x = -.10*pulse
            elif action_name == 'dash':
                rig.pose.bones['spine'].rotation_euler.x = -.30*math.sin(math.pi*t)
                for side in ['L','R']:
                    rig.pose.bones['arm_'+side].rotation_euler.x = -.65*math.sin(math.pi*t)
            elif action_name == 'death':
                ease = t*t*(3-2*t)
                rig.pose.bones['root'].rotation_euler.x = math.pi*.48*ease
                rig.pose.bones['root'].location.y = .09*ease
            if action_name == 'cast':
                # Arm lifts forward; counter-rotate the wrist so the staff head
                # also points forward (-Z in Godot), never behind the hat.
                bpy.context.view_layer.update()
                rest = rig.data.bones['hand_R'].matrix_local
                base = rig.pose.bones['arm_R'].matrix @ rig.data.bones['arm_R'].matrix_local.inverted() @ rest
                desired = Matrix.Rotation(-1.30*pulse, 4, 'X') @ rest
                rig.pose.bones['hand_R'].rotation_euler = (base.to_quaternion().inverted() @ desired.to_quaternion()).to_euler('XYZ')
            for bone in rig.pose.bones:
                bone.keyframe_insert('rotation_euler', frame=frame, group=bone.name)
                bone.keyframe_insert('location', frame=frame, group=bone.name)
        action.use_fake_user = True
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.rotation_euler = (0,0,0)
        bone.location = (0,0,0)
    scene.frame_set(1)
    bpy.context.view_layer.update()
