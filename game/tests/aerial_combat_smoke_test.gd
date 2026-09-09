extends SceneTree

var _failures: Array[String] = []
var _attack_events: Array[StringName] = []


func _initialize() -> void:
  _run.call_deferred()


func _run() -> void:
  var packed := load("res://world/test/flight_test.tscn") as PackedScene
  _assert(packed != null, "The AOTS-011 combat-enabled Valley scene loads.")
  var scene := packed.instantiate()
  (scene.get_node("FirstFlightSequence") as FirstFlightSequence).play_opening_on_start = false
  root.add_child(scene)
  await process_frame
  await physics_frame

  var combat := scene.get_node("AerialCombatController") as AerialCombatController
  var warden := scene.get_node("AshWarden") as AshWarden
  var lunaris := scene.get_node("Lunaris") as LunarisFlightController
  var camera := scene.get_node("FlightCameraRig") as LunarisFlightCamera
  var discovery_ui := scene.get_node("DiscoveryUI") as DiscoveryUI
  var ground := scene.get_node("GroundPlayer") as GroundPlayer
  var debug_hud := scene.get_node("DebugHUD") as CanvasLayer
  _assert(combat != null and warden != null, "Ash Warden and lightweight combat controller exist.")
  _assert(warden.has_node("LeftGuard") and warden.has_node("RightGuard") and warden.has_node("Body/VulnerableCore"), "Warden has two readable guards and one core.")
  _assert(InputMap.has_action(&"target_lock") and InputMap.has_action(&"combat_pulse") and InputMap.has_action(&"combat_focus"), "Combat actions use semantic Input Map entries.")
  _assert(InputMap.has_action(&"evade_left") and InputMap.has_action(&"evade_right"), "Directional evade actions exist.")
  _assert(not ground.player_input_enabled, "GroundPlayer remains exploration-only during flight combat.")
  _assert(not combat.combat_hud.visible, "Combat HUD is hidden during exploration.")
  warden.set_world_state(AshWarden.WorldState.AWAKENED, false)
  combat.set_encounter_enabled(true)

  warden.global_basis = Basis.IDENTITY
  _assert(combat.classify_sector(warden.global_position + Vector3(0, 0, -60)) == &"FRONT", "FRONT sector classification follows Warden orientation.")
  _assert(combat.classify_sector(warden.global_position + Vector3(-60, 0, 0)) == &"LEFT", "LEFT sector is classified continuously.")
  _assert(combat.classify_sector(warden.global_position + Vector3(60, 0, 0)) == &"RIGHT", "RIGHT sector is classified continuously.")
  _assert(combat.classify_sector(warden.global_position + Vector3(0, 0, 60)) == &"REAR", "REAR sector is classified continuously.")

  _assert(combat.begin_encounter(true), "Combat encounter begins in-world.")
  _assert(combat.state == AerialCombatController.CombatState.COMBAT_ENTER, "Combat uses a dedicated enter state.")
  _assert(not discovery_ui.exploration_input_enabled and not debug_hud.visible, "Exploration UI yields safely during combat.")
  combat._process(0.81)
  await process_frame
  _assert(combat.state == AerialCombatController.CombatState.COMBAT, "Combat enter reaches active COMBAT.")
  _assert(combat.combat_hud.visible, "Minimal combat HUD appears only in combat.")
  _assert(lunaris.player_input_enabled, "Normal Lunaris flight remains player-controlled in combat.")

  lunaris.global_position = warden.global_position + Vector3(-55, 0, 0)
  await process_frame
  _assert(combat.set_target_locked(true), "Target lock acquires the nearby Ash Warden.")
  _assert(camera.combat_target == warden, "Target lock biases awareness without steering Lunaris.")
  _assert(combat.set_target_locked(false) and camera.combat_target == null, "Target lock can be manually released safely.")
  _assert(combat.set_target_locked(true), "Target lock can reacquire the Warden.")
  lunaris.global_position = warden.global_position + Vector3(0, 0, 150)
  combat._process(0.01)
  _assert(not combat.target_locked and camera.combat_target == null, "Target lock breaks safely beyond maximum range.")
  lunaris.global_position = warden.global_position + Vector3(-55, 0, 0)
  combat._process(0.01)
  _assert(combat.set_target_locked(true), "Target lock reacquires after returning to useful range.")
  var left_before := warden.left_guard_health
  _assert(combat.fire_pulse(), "Pulse fires while locked and in range.")
  _assert(warden.left_guard_health < left_before, "Pulse damages the correctly positioned side guard.")
  _assert(not combat.fire_pulse(), "Pulse respects its short cooldown.")

  combat.pulse_cooldown = 0.0
  _assert(combat.begin_focus(), "Focus charge begins while flight remains available.")
  combat.charge_focus(1.0)
  _assert(combat.focus_charge > 0.35, "Focus strength builds over time.")
  var evade_before := combat.evade_charges
  _assert(combat.perform_evade(-1.0), "Evade performs a lateral flight burst.")
  _assert(not combat.focus_charging and combat.focus_charge == 0.0, "Evade cancels Focus commitment.")
  _assert(combat.evade_charges == evade_before - 1 and combat.evade_protection > 0.0, "Evade consumes one charge and grants brief protection.")
  combat.evade_recharge_progress = 3.9
  combat._process(0.2)
  _assert(combat.evade_charges == evade_before, "Evade charges recharge gradually.")

  combat.pulse_cooldown = 0.0
  combat.relative_sector = &"LEFT"
  combat.target_distance = 55.0
  _assert(combat.begin_focus(), "Focus can be started again after Evade.")
  combat.charge_focus(2.3)
  var focus_guard_before := warden.left_guard_health
  _assert(combat.release_focus(), "A useful/full Focus charge releases successfully.")
  _assert(warden.left_guard_health < focus_guard_before, "Focus rewards a side break opportunity.")

  warden.reset_warden()
  warden.set_combat_active(true)
  warden.receive_attack(100.0, &"LEFT", 1.0)
  _assert(warden.left_guard_health == 0.0 and not warden.left_guard_visual.visible, "Left Guard breaks with readable visual removal.")
  warden.receive_attack(100.0, &"RIGHT", 1.0)
  _assert(warden.right_guard_health == 0.0 and warden.phase_two, "Breaking both guards exposes phase two.")
  _assert(warden.core_visual.visible, "Exposed core becomes visually readable.")
  var core_before := warden.core_health
  warden.receive_attack(10.0, &"FRONT", 1.0)
  _assert(is_equal_approx(core_before - warden.core_health, 20.0), "Full Focus receives the 2× exposed-core multiplier.")

  warden.attack_executed.connect(func(attack_name): _attack_events.append(attack_name))
  warden.reset_warden()
  warden.set_combat_active(true)
  combat.relative_sector = &"FRONT"
  combat.target_distance = 60.0
  warden.state_time = 3.7
  warden.advance_ai(0.01, &"FRONT", 60.0)
  _assert(warden.ai_state == AshWarden.AIState.FRONTAL_TELEGRAPH, "Warden Lance always enters a visible telegraph state.")
  var health_before_lance := combat.player_health
  warden.advance_ai(1.4, &"FRONT", 60.0)
  _assert(&"WARDEN_LANCE" in _attack_events and combat.player_health < health_before_lance, "Frontal telegraph resolves into a damaging lance when not avoided.")

  combat.player_health = 100.0
  combat.relative_sector = &"LEFT"
  combat.target_distance = 60.0
  warden.ai_state = AshWarden.AIState.TRACK
  warden.state_time = 3.7
  warden.advance_ai(0.01, &"FRONT", 60.0)
  warden.advance_ai(1.4, &"FRONT", 60.0)
  _assert(combat.player_health == 100.0, "Warden Lance misses after Lunaris repositions out of its frontal sector.")

  combat.player_health = 100.0
  combat.relative_sector = &"LEFT"
  warden.ai_state = AshWarden.AIState.TRACK
  warden.state_time = 3.7
  warden.advance_ai(0.01, &"LEFT", 60.0)
  _assert(warden.ai_state == AshWarden.AIState.SWEEP_TELEGRAPH, "Side camping triggers Arc Sweep telegraph.")
  warden.advance_ai(1.1, &"LEFT", 60.0)
  _assert(&"ARC_SWEEP" in _attack_events and combat.player_health < 100.0, "Arc Sweep resolves against a side position.")

  combat.player_health = 100.0
  combat.relative_sector = &"REAR"
  warden.ai_state = AshWarden.AIState.TRACK
  warden.state_time = 3.7
  warden.advance_ai(0.01, &"REAR", 60.0)
  warden.advance_ai(1.1, &"REAR", 60.0)
  _assert(&"REAR_PULSE" in _attack_events and combat.player_health < 100.0, "Rear position has a weaker defensive response.")

  combat.evade_protection = 0.6
  var protected_damage := combat.apply_player_damage(20.0)
  _assert(protected_damage < 5.0, "Evade provides limited temporary damage protection.")
  combat.evade_protection = 0.0
  combat.player_health = 5.0
  combat.apply_player_damage(20.0)
  _assert(combat.player_health == 100.0 and combat.state == AerialCombatController.CombatState.COMBAT_ENTER, "Player defeat resets the encounter safely.")
  combat._process(0.81)
  await process_frame

  combat.set_target_locked(true)
  warden.left_guard_health = 0.0
  warden.right_guard_health = 0.0
  warden.phase_two = true
  warden.core_visual.visible = true
  warden.core_health = 5.0
  warden.receive_attack(10.0, &"FRONT", 1.0)
  _assert(warden.ai_state == AshWarden.AIState.DEFEATED, "Core damage can defeat the Ash Warden.")
  _assert(combat.state == AerialCombatController.CombatState.COMBAT_EXIT, "Warden defeat begins a clean combat exit.")
  combat._process(1.61)
  await process_frame
  _assert(combat.state == AerialCombatController.CombatState.EXPLORATION, "Combat exit restores EXPLORATION.")
  _assert(not combat.combat_hud.visible and debug_hud.visible, "Combat HUD hides and exploration HUD returns.")
  _assert(discovery_ui.exploration_input_enabled and camera.combat_target == null, "Discovery and normal camera state restore after combat.")
  _assert(combat.encounter_completed, "A defeated encounter cannot immediately retrigger from proximity.")
  _assert(not scene.has_node("XP") and not scene.has_node("Loot") and not scene.has_node("SkillTree"), "No RPG progression systems were introduced.")
  _finish()



func _assert(condition: bool, message: String) -> void:
  if condition:
    print("PASS: %s" % message)
  else:
    _failures.append(message)
    push_error("FAIL: %s" % message)


func _finish() -> void:
  if _failures.is_empty():
    print("AOTS-011 aerial combat smoke test passed.")
    quit(0)
  else:
    print("AOTS-011 aerial combat smoke test failed: %d failure(s)." % _failures.size())
    quit(1)
