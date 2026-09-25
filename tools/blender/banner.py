import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *
clear_scene()
box("Foot", (0,.08,0), (.65,.16,.65), "StoneLight", .05)
rod("Pole", (0,.14,0), (0,2.7,0), .055, "Leather")
rod("Crossbar", (-.62,2.5,0), (.62,2.5,0), .045, "Gold")
solidify(mesh("Pennant", [(-.51,2.45,-.015),(.51,2.45,-.015),(.48,1.35,-.08),
     (0,1.05,-.09),(-.48,1.35,-.08)], [(0,1,2,3,4)], "Lining"))
for s in [-1,1]:
    rod("Edge", (s*.50,2.44,-.02), (s*.48,1.35,-.085), .018, "Gold")
    rod("Edge", (s*.48,1.35,-.085), (0,1.05,-.095), .018, "Gold")
rune("BannerSigil", 0,1.90,-.09,1.0)
export("banner", 3000)
