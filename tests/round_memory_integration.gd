extends Node3D

var failures: int = 0

func verify(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _ready() -> void:
	Net.dedicated = true  # Avoid presentation in this authority-side integration test.
	var core: ArcaneCore = ArcaneCore.create()
	add_child(core)
	var players: Dictionary = {}
	for id: int in [1, 2, 3]:
		var player: Player = preload("res://scenes/player/player.tscn").instantiate() as Player
		player.name = str(id)
		player.is_local = false
		add_child(player)
		player.set_physics_process(false)
		player.stats.set_physics_process(false)
		player.position = Vector3(0.2 * id, 0, 0)
		players[id] = player
	var teams: Dictionary = {1: 0, 2: 1, 3: 0}
	core.set_stage(false, false)
	core.host_tick(10.0, players, teams)
	verify(core.progress_ratio(1) == 0.0 and not core.get_node("Ring").visible, "inactive pedestal cannot capture")
	core.set_stage(true, false)
	verify(core.get_node("Ring").visible, "announcement exposes the ring before capture")
	core.set_stage(true, true)
	core.host_tick(1.0, players, teams)
	verify(core.contested and core.progress_ratio(1) == 0.0, "enemies contest by team")
	players[2].position = Vector3(5, 0, 0)
	core.host_tick(1.0, players, teams)
	verify(not core.contested and core.progress[1] == 1.0 and core.progress[3] == 1.0, "allies do not contest or accelerate capture")
	players[1].stats.add_shield(10.0, 10.0)
	players[1].stats.take_damage(5.0)
	players[1].stats.add_shield(20.0, 10.0)
	core.host_tick(0.1, players, teams)
	verify(core.progress[1] == 0.0, "damage resets even when healing/shield gain masks the HP decrease")
	players[3].position.y = 1.5
	core.host_tick(1.5, players, teams)
	verify(is_equal_approx(core.progress[3], 0.6), "players upstairs cannot capture; leaving decays after grace")
	var p: Player = players[1]
	p.grant_overcharge()
	p.stats.mana = 0.0
	p.composer.press_precast()
	p.composer.press_slot(0)
	p.composer.press_slot(0)
	verify(p.composer.stored == null, "free cast cannot create an unfunded reservation")
	p.stats.mana = 100.0
	p.composer.press_precast()
	p.composer.press_slot(0)
	p.composer.press_slot(0)
	verify(p.composer.stored != null, "funded G stores during overcharge")
	if p.composer.stored != null:
		var base: float = p.composer.stored.mana_cost
		verify(p.reserved_mana() == base, "base cost stays held during overcharge")
		p.composer.press_precast()
		verify(p.reserved_mana() == 0.0 and p.stats.mana == 100.0 and p.overcharge_casts == 2, "G releases reservation and consumes one free cast atomically")
	p.reset_round()
	p.grant_overcharge()
	var aimed_spell: ResolvedSpell = SpellDB.resolve(&"fire", &"area", &"burst")
	verify(not aimed_spell.is_quick(), "fixture is a confirmed spell")
	p.composer.stored = aimed_spell
	p.composer.press_precast()
	verify(p.composer.state == SpellComposer.State.AIMING and p.reserved_mana() == aimed_spell.mana_cost, "G holds base reservation throughout aiming")
	p.overcharge_time = 0.0  # Expiry during aiming must be priced at the actual shot.
	p.stats.mana = aimed_spell.mana_cost
	p.composer.press_cast()
	verify(p.composer.state == SpellComposer.State.CASTING and p.reserved_mana() == 0.0 and p.stats.mana == 0.0, "expiry during aim charges exactly once without double-counting reserve")
	p.reset_round()
	p.composer.stored = aimed_spell
	p.composer.press_precast()
	p.composer.press_cancel()
	verify(p.composer.stored == null and p.reserved_mana() == 0.0 and p.stats.mana == 100.0, "cancelling stored aim releases without spending")
	# Load the network scene's script too: unit-only checks do not parse every UI branch.
	verify(load("res://scenes/net/net_match.gd") != null, "network integration script compiles")
	var network_scene: Node3D = preload("res://scenes/net/net_match.tscn").instantiate() as Node3D
	add_child(network_scene)
	network_scene.set_physics_process(false)
	MatchState.view = {"phase": MatchFsm.Phase.DRAFT, "round": 1, "arena": &"B", "north": 1}
	network_scene._on_match_changed()
	verify(network_scene.get_node("Arena/Layout").spaces is PatioSpaces, "rotation loads Patio geometry, not only its label")
	verify(network_scene._team_spawn(1, 0).origin.z < 0, "host starts on replicated north side")
	MatchState.view = {"phase": MatchFsm.Phase.DRAFT, "round": 2, "arena": &"B", "north": 77}
	network_scene._on_match_changed()
	verify(network_scene._team_spawn(1, 0).origin.z > 0 and network_scene._team_spawn(77, 1).origin.z < 0, "duel rematch actually swaps spawn transforms")
	MatchState.view = {"phase": MatchFsm.Phase.DRAFT, "round": 3, "arena": &"C", "north": 2, "teams": {1: 0, 2: 1, 3: 0, 4: 1}}
	network_scene._on_match_changed()
	verify(network_scene.get_node("Arena/Layout").spaces is SpineSpaces, "rotation loads Spine geometry")
	verify(network_scene._team_spawn(3, 0).origin.z > 0 and network_scene._team_spawn(4, 1).origin.z < 0, "teammates inherit the replicated swapped side")
	MatchState.view = {"phase": MatchFsm.Phase.COMBAT, "round": 3, "combat_act": &"convergence", "overtime_setting": &"collapse"}
	network_scene._on_match_changed()
	verify(network_scene._collapse.warning_only and network_scene._collapse.radius() == 5.0, "convergence previews the unsafe routes without damage")
	MatchState.view = {"phase": MatchFsm.Phase.OVERTIME, "round": 3, "overtime_rule": &"collapse", "time_left": 25.0}
	network_scene._on_match_changed()
	verify(not network_scene._collapse.warning_only and network_scene._collapse.radius() == 2.0, "host clock drives final collapse radius")
	MatchState.view = {"phase": MatchFsm.Phase.DRAFT, "round": 4, "arena": &"A", "north": 1}
	network_scene._on_match_changed()
	Lobby.mode = &"5v5"
	MatchState.view = {"phase": MatchFsm.Phase.COMBAT, "round": 4, "core_spawned": true}
	network_scene._on_match_changed()
	verify(network_scene._core == null and network_scene._control != null, "Control has exactly its capture point and no Overcharge core")
	print("ROUND_MEMORY_INTEGRATION: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
