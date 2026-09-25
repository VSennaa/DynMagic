import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *
clear_scene()
profile("Foot", [(0,0,0,.35,.35),(0,.14,0,.35,.35),(0,.22,0,.22,.22)], "StoneLight", 8)
profile("Stem", [(0,.18,0,.18,.18),(0,.70,0,.12,.12),(0,.79,0,.25,.25)], "Stone", 8)
profile("Bowl", [(0,.70,0,.16,.16),(0,1.0,0,.43,.43),(0,1.07,0,.43,.43),
                  (0,1.07,0,.34,.34),(0,.84,0,.12,.12)], "Gold", 10)
for x,z,h in [(0,0,1.62),(-.17,.04,1.4),(.16,.08,1.46)]:
    profile("FacetedFlame", [(x,.9,z,.11,.11),(x,1.15,z,.14,.12),
         (x+.07,h,z,.003,.003)], "Flame", 6)
export("brazier", 3000)
