import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from prop_style import *
clear_scene()
# Keep the 3m footprint for existing cover dressing, with a strongly stepped silhouette.
box('BroadPlinth',(0,.16,0),(3,.32,3),'Stone',.13)
box('ChamferedStep',(0,.40,0),(2.70,.20,2.70),'StoneLight',.09)
bevel_mesh(profile('BatteredOctagonalShaft',[(0,.5,0,1.20,1.20),(.045,1.1,0,1.09,1.09),(-.03,2.35,.02,.95,.95)],'Stone',8),.055)
box('NeckBand',(0,2.35,0),(2.16,.18,2.16),'Gold',.06)
box('SplayedCapital',(0,2.55,0),(2.65,.26,2.65),'StoneLight',.10)
box('HeavyAbacus',(0,2.84,0),(3,.32,3),'Stone',.12)
for side in [-1,1]:
    # Corner brackets give the capital a distinct weight-bearing profile.
    for z in [-1,1]:
        bevel_mesh(profile('CapitalBracket',[(side*.83,1.98,z*.83,.14,.14),(side*1.01,2.42,z*1.01,.26,.26)],'StoneLight',4),.03)
    rune('FaceInlay',0,1.46,side*1.07,1.60)
fit_legacy('pillar',(3.0,3.0,3.0))
