"""Single right forearm, curled glove around the origin grip; runtime poses."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *
clear_scene()
rod('RightSleeve',(.18,-.75,.38),(.035,-.055,.12),.085,'Cloth',10)
rod('RightCuff',(.04,-.065,.14),(.015,-.025,.075),.082,'Gold',10)
box('RightPalm',(.015,0,.045),(.125,.16,.065),'Leather',.015)
for i in range(4):
    y=(i-1.5)*.037
    rod('RightFinger',(.065,y,.045),(.065,y,-.035),.019,'Leather',6)
    rod('RightFingerTip',(.065,y,-.035),(-.018,y,-.048),.019,'Leather',6)
rod('RightThumb',(-.045,-.055,.045),(-.057,.023,-.02),.025,'Leather',7)
export('fp_staff_arm',3000)
