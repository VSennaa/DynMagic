"""Rebuild mage.glb: 1.8 m, feet at origin, face towards Godot -Z."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *

clear_scene()
for side in [-1, 1]:
    box("Boot", (side*.15, .10, -.055), (.22, .20, .36), "Leather", .045)
    profile("BootCuff", [(side*.15,.17,0,.115,.12), (side*.15,.36,0,.10,.11)], "Gold", 8)
profile("LongCloak", [(0,.25,.055,.40,.26), (0,.34,.055,.37,.25),
                      (0,.85,.02,.24,.19), (0,1.17,0,.29,.19), (0,1.28,0,.18,.15)], "Cloth", 12)
# Two broad front lapels leave a dark central opening.
for side in [-1, 1]:
    solidify(mesh("CloakLapel", [(side*.035,1.19,-.19),(side*.17,1.23,-.16),
         (side*.32,.30,-.18),(side*.08,.28,-.215)], [(0,1,2,3)], "StoneLight"))
    rod("GoldHem", (side*.08,.29,-.224), (side*.035,1.18,-.20), .014)
    rod("Sleeve", (side*.26,1.14,0), (side*.39,.88,-.01), .13, "Cloth", 10)
    rod("Cuff", (side*.39,.89,-.01), (side*.42,.80,-.035), .105, "Gold", 10)
    box("Glove", (side*.43,.73,-.045), (.145,.19,.15), "Leather", .035)
    box("Thumb", (side*.35,.745,-.10), (.065,.10,.09), "Leather", .02)
profile("Head", [(0,1.21,-.01,.10,.095),(0,1.28,-.02,.14,.13),
                 (0,1.43,-.01,.145,.135),(0,1.49,0,.11,.105)], "Skin", 10)
box("ShadowUnderHat", (0,1.40,-.132), (.245,.085,.027), "Ink", .015)
for side in [-1,1]:
    box("Eye", (side*.059,1.401,-.150), (.048,.012,.012), "StoneLight", .003)
profile("WideBrim", [(0,1.435,0,.46,.36),(0,1.47,0,.49,.38),
                      (0,1.50,0,.32,.27)], "Cloth", 16)
profile("BentPointedHat", [(0,1.485,0,.245,.225),(-.025,1.60,.015,.18,.16),
                           (-.075,1.73,.015,.09,.08),(-.17,1.80,0,.003,.003)], "Cloth", 12)
profile("HatBand", [(0,1.492,0,.246,.226),(-.007,1.54,.005,.22,.201)], "Lining", 12)
rune("HatSigil", 0,1.535,-.214,.22)
box("Belt", (0,.87,-.18), (.43,.065,.065), "Leather", .012)
box("Buckle", (0,.87,-.224), (.085,.085,.025), "Gold", .01)
rune("CloakSigil", 0,.64,.248,.55)
from mage_rig import build_rig
build_rig()
export("mage", 15000)
