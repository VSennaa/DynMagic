import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from prop_style import *
clear_scene()
# Heavy lobed foot, crooked pedestal, and a wide open iron basket with claw supports.
bevel_mesh(profile('OctagonalFoot',[(0,0,0,.34,.34),(0,.09,0,.36,.36),(0,.20,0,.26,.26)],'StoneLight',8),.035)
bevel_mesh(profile('CrookedStem',[(0,.17,0,.20,.20),(-.035,.32,0,.16,.16),(.02,.67,0,.12,.12),(0,.81,0,.25,.25)],'Stone',7),.025)
profile('Collar',[(0,.34,0,.18,.18),(0,.41,0,.18,.18)],'Gold',8)
bevel_mesh(profile('OpenBowl',[(0,.74,0,.18,.18),(0,.91,0,.38,.38),(0,1.07,0,.43,.43),(0,1.12,0,.42,.42),(0,1.12,0,.34,.34),(0,.90,0,.22,.22)],'Ink',10),.018)
profile('HammeredRim',[(0,1.05,0,.435,.435),(0,1.10,0,.435,.435),(0,1.10,0,.35,.35),(0,1.05,0,.35,.35)],'Gold',10)
for i in range(5):
    a=2*math.pi*i/5
    x,z=math.cos(a),math.sin(a)
    rod('BasketRib',(.20*x,.77,.20*z),(.39*x,1.05,.39*z),.038,'Gold',5)
    bevel_mesh(profile('CrownClaw',[(.38*x,1.06,.38*z,.07,.07),(.40*x,1.26,.40*z,.035,.035),(.34*x,1.32,.34*z,.006,.006)],'Gold',5),.009)
for i in range(3):
    a=i*2.1
    rod('CharredLog',(-.22*math.cos(a),.98,-.22*math.sin(a)),(.22*math.cos(a),1.0,.22*math.sin(a)),.075,'Leather',6)
for x,z,h in [(0,0,1.62),(-.17,.04,1.4),(.16,.08,1.46)]:
    profile('FacetedFlame',[(x,.99,z,.11,.11),(x,1.15,z,.14,.12),(x+.07,h,z,.003,.003)],'Flame',6)
fit_legacy('brazier',(.86,1.62,.81791))
