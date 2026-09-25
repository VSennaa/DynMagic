"""Bake procedural ink, parchment and painted courtyard into UI PNGs."""
import sys, random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
OUT=ROOT/'assets'/'ui'
OUT.mkdir(parents=True,exist_ok=True)
COLORS.update({'Paper':(.72,.56,.32,1),'PaperLight':(.87,.73,.47,1),'GoldUI':(.67,.39,.10,1),'Sky':(.075,.065,.16,1),'Rose':(.42,.19,.22,1)})

def painted(lit=False):
    for mat in bpy.data.materials:
        if not mat.use_nodes: continue
        n,l=mat.node_tree.nodes,mat.node_tree.links
        n.clear()
        out=n.new('ShaderNodeOutputMaterial')
        shader=n.new('ShaderNodeBsdfPrincipled' if lit else 'ShaderNodeEmission')
        tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=55;tex.inputs['Detail'].default_value=2
        coord=n.new('ShaderNodeTexCoord')
        stretch=n.new('ShaderNodeVectorMath');stretch.operation='MULTIPLY';stretch.inputs[1].default_value=(1,1,5)
        l.new(coord.outputs['Generated'],stretch.inputs[0]);l.new(stretch.outputs[0],tex.inputs['Vector'])
        ramp=n.new('ShaderNodeValToRGB')
        c=mat.diffuse_color
        ramp.color_ramp.elements[0].color=tuple(v*.78 for v in c[:3])+(1,)
        ramp.color_ramp.elements[1].color=tuple(min(1,v*1.08) for v in c[:3])+(1,)
        l.new(tex.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],shader.inputs['Base Color' if lit else 'Color'])
        if lit: shader.inputs['Roughness'].default_value=.95
        l.new(shader.outputs[0],out.inputs['Surface'])

def render(name,w,h,span=2,lit=False,camera_pos=None,target=(0,0,0)):
    painted(lit)
    scene=bpy.context.scene
    bpy.ops.object.camera_add(location=xyz(camera_pos or (0,0,-10)))
    cam=bpy.context.object
    cam.rotation_euler=(xyz(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    if not lit: cam.data.type='ORTHO';cam.data.ortho_scale=span
    else: cam.data.lens=25
    scene.camera=cam
    scene.render.engine='CYCLES';scene.cycles.samples=16 if lit else 1
    scene.render.resolution_x=w;scene.render.resolution_y=h;scene.render.resolution_percentage=100
    scene.render.film_transparent=not lit
    scene.view_settings.view_transform='Standard'
    scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
    scene.render.filepath=str(OUT/(name+'.png'))
    bpy.ops.render.render(write_still=True)

def stroke(a,b,width=.008,color='GoldUI',depth=-.035):
    rod('InkStroke',(a[0],a[1],depth),(b[0],b[1],depth),width,color,6)

def border(x,y,color='GoldUI'):
    for a,b in [((-x,-y),(x,-y)),((x,-y),(x,y)),((x,y),(-x,y)),((-x,y),(-x,-y))]: stroke(a,b,.007,color)

def corner(sx,sy,x=.88,y=.88,k=1):
    for d in [0,.045*k]:
        stroke((sx*(x-.22*k),sy*(y-d)),(sx*(x-d),sy*(y-d)))
        stroke((sx*(x-d),sy*(y-d)),(sx*(x-d),sy*(y-.22*k)))
    cx,cy=sx*(x-.08*k),sy*(y-.08*k)
    for a,b in [((cx-.035*k,cy),(cx,cy+.05*k)),((cx,cy+.05*k),(cx+.035*k,cy)),((cx+.035*k,cy),(cx,cy-.05*k)),((cx,cy-.05*k),(cx-.035*k,cy))]:stroke(a,b,.005)

clear_scene()
box('Parchment',(0,0,0),(1.98,1.98,.02),'Paper',.045)
box('WritingField',(0,0,-.014),(1.83,1.83,.008),'PaperLight',.035)
border(.935,.935,'Ink');border(.91,.91)
for sx in [-1,1]:
 for sy in [-1,1]:corner(sx,sy,.95,.95,.28)
render('parchment_panel',512,512)
for state in ['normal','hover','pressed','disabled']:
 clear_scene()
 face={'normal':'Ink','hover':'Cloth','pressed':'Leather','disabled':'Stone'}[state]
 box('Frame',(0,0,0),(1.99,.49,.02),'GoldUI' if state!='disabled' else 'StoneLight',.035)
 box('ButtonFace',(0,0,-.02),(1.95,.45,.015),face,.025)
 border(.955,.205,'GoldUI' if state!='disabled' else 'Ink')
 for sx in [-1,1]:
  stroke((sx*.90,-.055),(sx*.85,0),.008);stroke((sx*.85,0),(sx*.90,.055),.008)
 render('button_'+state,512,128)
for label,sx,sy in [('tl',1,1),('tr',-1,1),('bl',1,-1),('br',-1,-1)]:
 clear_scene();corner(sx,sy,.80,.80,k=4)
 stroke((sx*.80,sy*.80),(-sx*.70,sy*.80),.012)
 stroke((sx*.80,sy*.80),(sx*.80,-sy*.70),.012)
 for d in [.1,.25,.40]:
  stroke((sx*(.8-d),sy*.8),(sx*(.76-d),sy*.70),.01)
  stroke((sx*.8,sy*(.8-d)),(sx*.70,sy*(.76-d)),.01)
 render('rune_corner_'+label,128,128)
clear_scene()
mesh('Banner',[(-.97,.22,0),(.97,.22,0),(.89,0,0),(.97,-.22,0),(0,-.18,0),(-.97,-.22,0),(-.89,0,0)],[tuple(range(7))],'Ink')
for sy in [-1,1]:stroke((-.84,sy*.15),(.84,sy*.15),.007)
for sx in [-1,1]:
 stroke((sx*.77,-.09),(sx*.84,0),.009);stroke((sx*.84,0),(sx*.77,.09),.009)
render('title_banner',1024,256)
# Perspective courtyard: clear center for menu typography, warm lit sides.
clear_scene();random.seed(6)
box('Courtyard',(0,-.22,5),(24,.4,32),'Stone',.04)
for row in range(12):
 for col in range(-5,6):
  box('Paving',(col*1.7+(row%2)*.85,-.01,row*1.65-4),(1.64,.045,1.58),'StoneLight' if (row+col)%4 else 'Stone',.02)
for side in [-1,1]:
 box('ArcadeWall',(side*8,3,8),(1,6,25),'Stone',.04)
 for z in range(-2,20,4):
  box('Column',(side*6.5,2.3,z),(.65,4.6,.7),'StoneLight',.07)
  box('Capital',(side*6.5,4.55,z),(1.1,.35,1),'Gold',.04)
  # Gothic arch between columns, extruded in X.
  pts=[(side*6.5,4.5,z),(side*6.5,5.5,z+2),(side*6.5,4.5,z+4)]
  for a,b in zip(pts,pts[1:]):rod('Arch',a,b,.25,'StoneLight',8)
  if z%8==6:
   box('HangingBanner',(side*6.05,3,z),(.06,2.5,.9),'Lining',.01)
 for z in [0,8,16]:
  rod('LanternPost',(side*5.6,0,z),(side*5.6,1.7,z),.11,'Ink',8)
  profile('Lantern',[(side*5.6,1.65,z,.23,.23),(side*5.6,2.05,z,.16,.16),(side*5.6,2.15,z,0,0)],'Flame',6)
  bpy.ops.object.light_add(type='POINT',location=xyz((side*5.6,2.2,z)));bpy.context.object.data.energy=100;bpy.context.object.data.color=(1,.38,.1)
for x in [-7,-3,3,7]:
 box('Tower',(x,4.3,21),(2.7,8.6,2.4),'Stone',.1)
 profile('Roof',[(x,8.6,21,2,1.8),(x,11.7,21,0,0)],'Cloth',6)
box('FarWall',(0,2.5,23),(20,5,1),'Stone',.03)
for x in [-2,0,2]:
 box('Steps',(0,.10+x*.015,14+x*.5),(5-abs(x)*.3,.2,1),'StoneLight',.03)
profile('ArcanePlinth',[(0,0,16,1,1),(0,.6,16,.7,.7)],'StoneLight',8)
profile('FloatingRune',[(0,1.3,16,0,0),(0,2.2,16,.55,.55),(0,3.2,16,0,0)],'Crystal',6)
scene=bpy.context.scene
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.17,.11,.28,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
bpy.ops.object.light_add(type='AREA',location=xyz((-4,12,5)));bpy.context.object.data.energy=2200;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=14
bpy.context.object.rotation_euler=(xyz((0,0,9))-bpy.context.object.location).to_track_quat('-Z','Y').to_euler()
render('menu_backdrop',1920,1080,lit=True,camera_pos=(0,3,-9),target=(0,3.2,12))
