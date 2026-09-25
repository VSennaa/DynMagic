"""Element staff library; grip at origin, upright Y, 1.60 m total."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *


def build(element):
    clear_scene()
    palettes = {'fire': 'FF5A1F', 'frost': '6FD3FF', 'storm': 'C98BFF', 'wind': '7CF2B0'}
    h = palettes[element]
    COLORS['Element'] = tuple(((int(h[i:i+2],16)/255+.055)/1.055)**2.4 for i in (0,2,4)) + (1,)
    COLORS['WoodStaff'] = {'fire':(.045,.025,.02,1),'frost':(.65,.72,.69,1),'storm':(.045,.055,.085,1),'wind':(.42,.29,.13,1)}[element]
    profile('Shaft', [(0,-.65,0,.025,.025),(.015,-.3,0,.035,.03),(0,0,0,.032,.032),(-.025,.40,0,.04,.035),(0,.63,0,.045,.04)], 'WoodStaff', 10)
    for y in [-.12,-.06,0,.06,.12]:
        rod('GripWrap',(0,y-.012,0),(0,y+.012,0),.039,'Leather',10)
    rod('Pommel',(0,-.65,0),(0,-.60,0),.04,'Gold',10)
    rod('Collar',(0,.52,0),(0,.58,0),.06,'Gold',10)
    if element == 'fire':
        profile('Ember',[(0,.56,0,.02,.02),(.01,.70,0,.11,.075),(-.035,.84,0,.065,.04),(.015,.95,0,0,0)],'Element',7)
        for side in [-1,1]:
            profile('FlameProng',[(side*.06,.54,0,.04,.05),(side*.15,.70,0,.035,.04),(side*.11,.86,0,.025,.02),(side*.045,.92,0,0,0)],'WoodStaff',6)
    elif element == 'frost':
        for i in range(5):
            x=(i-2)*.065
            profile('IceShard',[(x,.55,0,.04,.045),(x*1.35,.73,0,.045,.04),(x*1.65,.95-abs(i-2)*.055,0,0,0)],'Element',5)
    elif element == 'storm':
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=.115,location=xyz((0,.76,0)))
        finish(bpy.context.object,'VioletOrb','Element')
        for side in [-1,1]:
            profile('Fork',[(side*.035,.54,0,.035,.035),(side*.16,.66,0,.035,.035),(side*.15,.87,0,.025,.025),(side*.1,.95,0,0,0)],'WoodStaff',6)
    else:
        for side in [-1,1]:
            profile('TwistedBranch',[(0,.40,0,.027,.027),(side*.12,.66,side*.035,.03,.025),(side*.09,.82,0,.025,.02),(0,.95,0,.012,.012)],'WoodStaff',7)
            feather=mesh('Feather',[(side*.12,.70,0),(side*.23,.60,0),(side*.20,.39,0),(side*.15,.51,0)],[(0,1,2,3)],'StoneLight')
            solidify(feather)
            rod('FeatherQuill',(side*.12,.69,-.008),(side*.20,.40,-.008),.007,'Gold',5)
            ribbon=mesh('Ribbon',[(side*.05,.57,.03),(side*.10,.55,.03),(side*.15,.32,.02),(side*.10,.30,.02),(side*.07,.43,.04)],[(0,1,2,3,4)],'Element')
            solidify(ribbon)
        profile('GreenGem',[(0,.64,0,0,0),(0,.75,0,.075,.06),(0,.86,0,0,0)],'Element',6)
    export('staff_'+element,3000)

if __name__ == '__main__':
    build(sys.argv[-1] if sys.argv[-1] in ['fire','frost','storm','wind'] else 'fire')
