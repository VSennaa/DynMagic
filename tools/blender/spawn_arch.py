import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from prop_style import *
clear_scene()
# Stepped, slightly leaning piers carry a real segmented arch, rather than a lintel.
for side in [-1,1]:
    x=side*3.83
    box('SplayedFoot',(x,.18,0),(.84,.36,1.02),'StoneLight',.10)
    box('FootCollar',(x,.43,0),(.71,.19,.92),'Stone',.055)
    for i in range(4):
        y=.55+i*.74
        block=box('HandCutPier',(x+side*.025*math.sin(i),y+.35,0),(.63+(i%2)*.05,.70,.81),'Stone' if i%2 else 'StoneLight',.075)
    box('Shoulder',(x,3.59,0),(.84,.24,1.0),'StoneLight',.065)
    rune('PierInlay',x,2.0,-.438,1.3)
# Voussoirs form an elliptical arch; open negative space remains 7m at the spring.
for i in range(11):
    a=i*math.pi/11+.009; b=(i+1)*math.pi/11-.009
    points=[]
    for z in [-.45,.45]:
        points += [(4.23*math.cos(t),3.6+1.35*math.sin(t),z) for t in [a,b]]
        points += [(3.5*math.cos(t),3.6+.79*math.sin(t),z) for t in [b,a]]
    bevel_mesh(mesh('ArchWedge',points,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'StoneLight' if i%3 else 'Stone'),.04)
# Oversized shield keystone creates a readable central silhouette and a deep front face.
pts=[(-.40,4.97,-.56),(.40,4.97,-.56),(.29,4.48,-.63),(0,4.25,-.63),(-.29,4.48,-.63)]
solidify(mesh('ShieldKeystone',pts,[tuple(range(5))],'Stone'),.15)
rune('GateSigil',0,4.63,-.69,.72)
fit_legacy('spawn_arch',(8.5,5.0,1.15875),-.079375)
