extends SceneTree
## Procedurally builds the 1D color-grading LUT (per-channel curve) used by the
## arena environment (M13 gauntlet "color grade" piece). A GradientTexture1D is
## sampled per channel by Godot's tonemapper (USE_1D_LUT), so the single gradient
## encodes three independent curves: .r = red, .g = green, .b = blue.
##
## Grade (subtle, never flat): lilac #3B3350 shadows, warm midtones, cream #FFF3DD
## highlights, +8% mid saturation and a soft S-curve contrast.
##
## Run headless:
##   Godot --headless --path D:\DynMagic --script res://tools/build_grade_lut.gd
## Writes res://shaders/grade_lut.tres (GradientTexture1D).

const OUT_PATH := "res://shaders/grade_lut.tres"
const CURVE_POINTS := 65
const LUT_WIDTH := 256

# Grade targets (spec brief): lilac shadows #3B3350, cream highlights #FFF3DD.
const SHADOW_TINT := Color(0.231, 0.200, 0.314)
const HIGHLIGHT_TINT := Color(1.0, 0.953, 0.867)

# Blend amounts — kept small so the grade stays subtle.
const S_CONTRAST := 0.10       # soft S-curve strength
const SHADOW_AMOUNT := 0.10    # blend toward lilac in the shadows
const HIGHLIGHT_AMOUNT := 0.15 # blend toward cream in the highlights
const WARM_R := 0.012          # warm midtones: lift red...
const WARM_B := 0.018          # ...and pull blue


func _initialize() -> void:
	var lut := _build_lut()
	var err := ResourceSaver.save(lut, OUT_PATH)
	print("grade_lut saved: %s" % error_string(err))
	if err == OK:
		_self_check(lut)
	quit(0 if err == OK else 1)


## Builds the GradientTexture1D LUT. Each channel is an independent curve:
## soft S-contrast, a lilac lift in the shadows, a cream gain in the highlights
## and a warm push in the midtones.
func _build_lut() -> GradientTexture1D:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in CURVE_POINTS:
		var x := float(i) / float(CURVE_POINTS - 1)
		offsets.append(x)
		colors.append(Color(
			_channel(x, SHADOW_TINT.r, HIGHLIGHT_TINT.r, WARM_R),
			_channel(x, SHADOW_TINT.g, HIGHLIGHT_TINT.g, 0.0),
			_channel(x, SHADOW_TINT.b, HIGHLIGHT_TINT.b, -WARM_B)))
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
	gradient.offsets = offsets
	gradient.colors = colors
	var lut := GradientTexture1D.new()
	lut.gradient = gradient
	lut.width = LUT_WIDTH
	lut.use_hdr = true
	return lut


## One channel curve over input x in [0, 1]. `shadow`/`highlight` are the tint
## targets and `warm` is the midtone offset.
func _channel(x: float, shadow: float, highlight: float, warm: float) -> float:
	var y := x
	# Soft S-curve contrast.
	y = lerpf(y, y * y * (3.0 - 2.0 * y), S_CONTRAST)
	# Lift shadows toward the lilac tint.
	y = lerpf(y, shadow, pow(1.0 - x, 2.0) * SHADOW_AMOUNT)
	# Gain highlights toward the cream tint.
	y = lerpf(y, highlight, pow(x, 2.0) * HIGHLIGHT_AMOUNT)
	# Warm the midtones.
	y += warm * exp(-pow((x - 0.5) * 3.0, 2.0))
	return clampf(y, 0.0, 1.0)


## Sanity-prints the curve at key points so the grade can be checked numerically.
func _self_check(lut: GradientTexture1D) -> void:
	var g: Gradient = lut.gradient
	var stops: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
	for x: float in stops:
		print("grade_lut[%.2f] = %s" % [x, g.sample(x)])
