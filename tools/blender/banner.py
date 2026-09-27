import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from prop_style import *
clear_scene()
box('CarvedFoot',(0,.09,0),(.65,.18,.65),'Stone',.07)
box('FootCap',(0,.21,0),(.43,.12,.43),'StoneLight',.04)
rod('ThickMast',(0,.26,0),(0,2.54,0),.072,'Leather',7)
for y in [.35,1.05,2.35]:
    profile('MastBindings',[(0,y,0,.09,.09),(0,y+.08,0,.09,.09)],'Gold',8)
rod('Yard',(-.56,2.45,0),(.56,2.45,0),.068,'Leather',7)
for side in [-1,1]:
    profile('YardEnd',[(side*.565,2.40,0,.055,.055),(side*.565,2.51,0,.07,.07)],'Gold',6)
profile('SpearFinial',[(0,2.52,0,.045,.045),(0,2.60,0,.11,.06),(0,2.70,0,.005,.005)],'Gold',4)
# A tessellated, wind-bellied swallowtail; broad scallops read from arena distance.
cols=8;rows=6;points=[]
for row in range(rows):
    t=row/(rows-1)
    for col in range(cols+1):
        u=col/cols; x=(u-.5)*1.02
        bottom=1.06+.24*(1-abs(2*u-1))
        y=2.40*(1-t)+bottom*t
        z=-.045-.10*math.sin(u*math.pi*3+t*.7)*math.sin(t*math.pi*.8)-.025*t
        points.append((x,y,z))
faces=[]
for row in range(rows-1):
    for col in range(cols):
        a=row*(cols+1)+col;faces.append((a,a+1,a+cols+2,a+cols+1))
solidify(mesh('BillowingSwallowtail',points,faces,'Lining'),.012)
# Wide applied hem follows the actual cloth; no straight rods over floating fabric.
for col in range(cols):
    a=points[(rows-1)*(cols+1)+col];b=points[(rows-1)*(cols+1)+col+1]
    rod('HeavyHem',a,b,.027,'Gold',5)
for side in [0,cols]:
    for row in range(rows-1):
        rod('SideHem',points[row*(cols+1)+side],points[(row+1)*(cols+1)+side],.022,'Gold',5)
# Flattened raised appliqué, offset ahead of the deepest fold.
rune('BannerSigil',0,1.94,-.19,.80)
for side in [-1,1]:
    rod('HangingLoop',(side*.35,2.48,-.01),(side*.35,2.33,-.05),.035,'Gold',6)
fit_legacy('banner',(1.24,2.7,.65))
