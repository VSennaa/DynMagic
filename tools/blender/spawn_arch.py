import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *
clear_scene()
for s in [-1,1]:
    box("Foot", (s*3.85,.15,0), (.7,.3,1), "StoneLight", .06)
    column = box("Pier", (s*3.85,2.3,0), (.65,4.3,.85), "Stone", .06)
    rune("PierRune", s*3.85,2.5,-.425,1.2, engraved_in=column)
    box("Capital", (s*3.85,4.4,0), (.8,.3,1), "StoneLight", .06)
box("Lintel", (0,4.68,0), (8.4,.42,1), "StoneLight", .07)
for s in [-1,1]:
    rod("ArchBrace", (s*3.55,3.8,0), (s*2.8,4.48,0), .19, "Stone", 4)
box("Keystone", (0,4.65,-.54), (.75,.70,.18), "Stone", .04)
rune("GateSigil", 0,4.65,-.64,.75)
export("spawn_arch", 3000)
