"""Rebuild training_dummy.glb: workshop target, 1.8 m, facing Godot -Z."""
import math
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *


def rope_loop(name, y, rx, rz, z=0, radius=.014):
    """Low-poly cord following a horizontal elliptical sack section."""
    for i in range(12):
        a, b = i * math.tau / 12, (i + 1) * math.tau / 12
        rod(name + str(i), (rx * math.cos(a), y, z + rz * math.sin(a)),
            (rx * math.cos(b), y, z + rz * math.sin(b)), radius, "Rope", 5)


clear_scene()
COLORS.update({
    "Wood": (.27, .13, .065, 1),
    "WoodEnd": (.48, .27, .12, 1),
    "Sack": (.70, .51, .28, 1),
    "Straw": (.91, .72, .34, 1),
    "Rope": (.40, .27, .13, 1),
    "TargetPaint": (.55, .13, .17, 1),
})
profile("RoundStoneBase", [(0, 0, 0, .36, .36), (0, .04, 0, .40, .40),
    (0, .15, 0, .40, .40), (0, .20, 0, .33, .33)], "StoneLight", 12)
box("WoodenPost", (0, .79, .045), (.14, 1.24, .14), "Wood", .018)
box("CrossbarArms", (0, 1.20, .025), (1.22, .115, .13), "Wood", .018)
for side in [-1, 1]:
    box("CrossbarEnd", (side * .607, 1.20, .025), (.015, .09, .10), "WoodEnd", .008)
    for i in range(3):
        box("ArmBinding", (side * (.43 + i * .027), 1.20, .025),
            (.015, .13, .145), "Rope", .006)
    rod("BaseBrace", (side * .25, .18, .04), (side * .04, .43, .04), .045, "Wood", 6)

# Broad shoulders, pinched neck and gathered hem give the sack a stuffed silhouette.
profile("StuffedTorso", [(0, .64, 0, .12, .115), (0, .73, 0, .24, .17),
    (0, .86, 0, .29, .20), (0, 1.20, 0, .30, .20),
    (0, 1.30, 0, .235, .16), (0, 1.34, 0, .095, .09)], "Sack", 12)
profile("SackHead", [(0, 1.32, 0, .085, .08), (0, 1.38, 0, .15, .13),
    (.015, 1.48, 0, .16, .135), (.01, 1.53, 0, .12, .105)], "Sack", 10)
for y, rx, rz in [(.69, .18, .147), (.715, .215, .16), (1.335, .10, .095)]:
    rope_loop("SackBinding", y, rx, rz)
box("RopeKnot", (.07, .70, -.164), (.055, .048, .045), "Rope", .01)
for side in [-1, 1]:
    rod("HangingCord", (.07, .70, -.18), (.07 + side * .045, .59, -.18), .011, "Rope", 5)
    for i in range(4):
        rod("LooseStraw", (side * (.07 + .025 * i), .70, -.03),
            (side * (.09 + .033 * i), .57 + .015 * (i % 2), -.04), .012, "Straw", 4)
    for i in range(4):
        rod("ShoulderStraw", (side * .25, 1.24, .02),
            (side * (.35 + .02 * (i % 2)), 1.22 + i * .035, .02), .012, "Straw", 4)

# Thin flat paint polygons conform to the torso front: no target board or texture.
def paint_z(x):
    return -.202 + abs(x) * .268


points = []
for radius in [.164, .142]:
    for i in range(16):
        a = i * math.tau / 16
        x = radius * math.cos(a)
        points.append((x, 1.045 + radius * math.sin(a), paint_z(x)))
mesh("PaintedTargetRing", points,
     [(i + 16, (i + 1) % 16 + 16, (i + 1) % 16, i) for i in range(16)], "TargetPaint")
for i, (a, b) in enumerate(zip([(0, -.105), (-.068, 0), (0, .105), (.068, 0)],
                              [(-.068, 0), (0, .105), (.068, 0), (0, -.105)])):
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dy)
    ox, oy = -dy / length * .009, dx / length * .009
    coords = [(a[0] + ox, a[1] + oy), (b[0] + ox, b[1] + oy),
              (b[0] - ox, b[1] - oy), (a[0] - ox, a[1] - oy)]
    mesh("PaintedRune" + str(i), [(x, 1.045 + y, paint_z(x) - .001) for x, y in coords],
         [(0, 1, 2, 3)], "TargetPaint")
for side in [-1, 1]:
    for i in range(4):
        rod("SackStitch", (side * .24, .86 + i * .075, -.11),
            (side * .27, .88 + i * .075, -.09), .007, "Rope", 4)
profile("SmallHatBrim", [(0, 1.505, 0, .235, .20), (0, 1.535, 0, .25, .215),
    (0, 1.55, 0, .175, .15)], "Cloth", 12)
profile("BentPointedHat", [(0, 1.54, 0, .165, .145), (-.025, 1.66, 0, .115, .095),
    (-.08, 1.76, .01, .05, .04), (-.145, 1.80, .01, .002, .002)], "Cloth", 10)
profile("HatBand", [(0, 1.548, 0, .164, .144), (-.008, 1.584, 0, .15, .13)], "Lining", 10)
box("HatBuckle", (0, 1.565, -.143), (.044, .035, .015), "Gold", .006)
export("training_dummy", 3000, expected_size=(1.229, 1.8, .8))
