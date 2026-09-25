## Screen transitions between menus, lobby, match and results. See docs/SDD.md section 4.3.
extends CanvasLayer

const MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"
const PLAY_LAN: String = "res://scenes/ui/play_lan.tscn"
const LOBBY: String = "res://scenes/ui/lobby_screen.tscn"
const SETTINGS: String = "res://scenes/ui/settings_screen.tscn"
const GRIMOIRE: String = "res://scenes/ui/grimoire_screen.tscn"
const TRAINING: String = "res://scenes/sandbox/training.tscn"
const MATCH: String = "res://scenes/net/net_match.tscn"
const FADE_TIME: float = 0.3

var _curtain: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 100
	_curtain = ColorRect.new()
	_curtain.color = Color(0.067, 0.086, 0.122, 0.0)
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_curtain)


## Fades to the ink colour, swaps the scene, fades back (spec 06 §4: ink-brush transition placeholder).
func go_to(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	var tween: Tween = create_tween()
	tween.tween_property(_curtain, ^"color:a", 1.0, FADE_TIME)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	var back: Tween = create_tween()
	back.tween_property(_curtain, ^"color:a", 0.0, FADE_TIME)
	await back.finished
	_busy = false
