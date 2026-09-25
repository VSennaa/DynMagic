"""Four separately named mesh poses, camera-local origin, facing -Z."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *

clear_scene()
for pose in ["OpenPalm", "Fist", "PalmDown", "Cast"]:
    before = set(bpy.context.scene.objects)
    for side in [-1,1]:
        x = side*.26
        rod("Sleeve", (side*.36,-.34,.08), (x,-.23,-.32), .095, "Cloth", 10)
        rod("Cuff", (x,-.23,-.29), (x,-.21,-.38), .083, "Gold", 10)
        box("Palm", (x,-.20,-.445), (.135,.075,.15), "Leather", .025)
        for finger in range(4):
            fx = x + (finger-1.5)*.032
            length = [.105,.135,.125,.095][finger]
            start = (fx,-.20,-.49)
            if pose == "Fist":
                end = (fx,-.16,-.55)
            elif pose == "OpenPalm":
                end = (fx+(finger-1.5)*.016,-.09,-.52-length*.35)
            elif pose == "Cast":
                end = (fx+(finger-1.5)*.012,-.17,-.52-length)
            else:
                end = (fx,-.21,-.52-length)
            rod("Finger", start, end, .019, "Leather", 6)
            if pose == "Fist":
                rod("CurledTip", end, (fx,-.22,-.55), .019, "Leather", 6)
        rod("Thumb", (x-side*.055,-.20,-.41),
            (x-side*.105,-.18,-.49), .027, "Leather", 6)
        rune("GloveSigil", x,-.19,-.522,.13)
    parts = set(bpy.context.scene.objects) - before
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = sorted(parts, key=lambda o:o.name)[0]
    bpy.ops.object.join()
    bpy.context.object.name = pose
    # The GLB holds all poses; the Godot wrapper selects exactly one.
export("fp_arms", 15000)
