import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *
clear_scene()
profile("PedestalFoot", [(0,0,0,.43,.43),(0,.12,0,.43,.43),(0,.20,0,.32,.32)], "StoneLight", 8)
profile("Pedestal", [(0,.17,0,.28,.28),(0,.45,0,.24,.24)], "Stone", 8)
profile("PedestalCrown", [(0,.43,0,.25,.25),(0,.53,0,.36,.36)], "Gold", 8)
profile("Crystal", [(0,.82,0,.005,.005),(0,1.12,0,.29,.24),
                     (.025,1.49,0,.24,.20),(.04,1.88,0,.001,.001)], "Crystal", 6)
rune("PedestalSigil", 0,.33,-.262,.27)
export("arcane_core", 3000)
