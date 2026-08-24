class_name AerialCombatController
extends Node

signal combat_state_changed(previous: CombatState, current: CombatState)
signal combat_audio_requested(event_name: StringName)
signal player_damaged(amount: float)

enum CombatState { EXPLORATION, COMBAT_ENTER, COMBAT, COMBAT_EXIT }

const ENCOUNTER_CENTER := Vector3(-470.0, 82.0, 225.0)
const COMBAT_START := Vector3(-550.0, 84.0, 300.0)
const LOCK_MAX_DISTANCE := 140.0
const ATTACK_MAX_DISTANCE := 105.0
const MAX_PLAYER_HEALTH := 100.0

@export_node_path("LunarisFlightController") var flight_player_path: NodePath
@export_node_path("LunarisFlightCamera") var flight_camera_path: NodePath
@export_node_path("AshWarden") var warden_path: NodePath
@export_node_path("DiscoveryUI") var discovery_ui_path: NodePath
@export_node_path("CanvasLayer") var exploration_hud_path: NodePath
@export_node_path("TraversalCoordinator") var traversal_path: NodePath
@export var encounter_trigger_radius: float = 125.0
@export var debug_start_combat: bool = false

var state: CombatState = CombatState.EXPLORATION
var flight_player: LunarisFlightController
var flight_camera: LunarisFlightCamera
var warden: AshWarden
var discovery_ui: DiscoveryUI
var exploration_hud: CanvasLayer
var traversal: TraversalCoordinator
var combat_hud: CombatHUD

var player_health: float = MAX_PLAYER_HEALTH
var target_locked: bool = false
var relative_sector: StringName = &"REAR"
var target_distance: float = INF
var pulse_cooldown: float = 0.0
var focus_charging: bool = false
var focus_charge: float = 0.0
var evade_charges: int = 3
var evade_recharge_progress: float = 0.0
var evade_protection: float = 0.0
var state_time: float = 0.0
var encounter_completed: bool = false
var focus_visual: MeshInstance3D
var evade_visual: Node3D

var _energy_material := preload("res://art/sacred_ash/materials/m_architect_cyan_active.tres")


func _ready() -> void:
  flight_player = get_node_or_null(flight_player_path) as LunarisFlightController
  flight_camera = get_node_or_null(flight_camera_path) as LunarisFlightCamera
  warden = get_node_or_null(warden_path) as AshWarden
  discovery_ui = get_node_or_null(discovery_ui_path) as DiscoveryUI
  exploration_hud = get_node_or_null(exploration_hud_path) as CanvasLayer
  traversal = get_node_or_null(traversal_path) as TraversalCoordinator
  combat_hud = CombatHUD.new()
  combat_hud.name = "CombatHUD"
  get_parent().add_child.call_deferred(combat_hud)
  if flight_player == null or flight_camera == null or warden == null:
    push_error("AerialCombatController requires Lunaris, flight camera, and Ash Warden.")
    set_process(false)
    return
  _build_combat_effects()
  warden.attack_executed.connect(_on_warden_attack)
  warden.guard_broken.connect(func(_side): combat_audio_requested.emit(&"ARMOUR_BREAK"))
  warden.core_exposed.connect(func(): combat_audio_requested.emit(&"CORE_EXPOSURE"))
  warden.attack_telegraphed.connect(func(_attack): combat_audio_requested.emit(&"WARDEN_TELEGRAPH"))
  warden.defeated.connect(_on_warden_defeated)
  if debug_start_combat:
    start_combat_debug.call_deferred()


func _process(delta: float) -> void:
  state_time += delta
  pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
  evade_protection = maxf(0.0, evade_protection - delta)
  if focus_visual != null:
    focus_visual.visible = focus_charging
    focus_visual.scale = Vector3.ONE * lerpf(0.65, 1.55, focus_charge)
  if evade_visual != null:
    evade_visual.visible = evade_protection > 0.0
  if evade_charges < 3:
    evade_recharge_progress += delta
    if evade_recharge_progress >= 4.0:
      evade_recharge_progress -= 4.0
      evade_charges += 1

  match state:
    CombatState.EXPLORATION:
      if _can_auto_start() and flight_player.global_position.distance_to(ENCOUNTER_CENTER) <= encounter_trigger_radius:
        begin_encounter()
    CombatState.COMBAT_ENTER:
      if state_time >= 0.8:
        _set_state(CombatState.COMBAT)
    CombatState.COMBAT:
      _update_relative_space()
      if target_locked and (not is_instance_valid(warden) or target_distance > LOCK_MAX_DISTANCE):
        set_target_locked(false)
      if focus_charging:
        focus_charge = minf(1.0, focus_charge + delta / 2.25)
      warden.target_position = flight_player.global_position
      warden.advance_ai(delta, relative_sector, target_distance)
      combat_hud.update_combat(player_health, warden, focus_charge, evade_charges, target_locked, relative_sector, target_distance)
    CombatState.COMBAT_EXIT:
      if state_time >= 1.6:
        _finish_combat_exit()


func _unhandled_input(event: InputEvent) -> void:
  if state != CombatState.COMBAT:
    return
  if event.is_action_pressed(&"target_lock"):
    set_target_locked(not target_locked)
  elif event.is_action_pressed(&"combat_pulse"):
    fire_pulse()
  elif event.is_action_pressed(&"combat_focus"):
    begin_focus()
  elif event.is_action_released(&"combat_focus"):
    release_focus()
  elif event.is_action_pressed(&"evade_left"):
    perform_evade(-1.0)
  elif event.is_action_pressed(&"evade_right"):
    perform_evade(1.0)


func begin_encounter(force: bool = false) -> bool:
  if state != CombatState.EXPLORATION:
    return false
  if not force and not _can_auto_start():
    return false
  player_health = MAX_PLAYER_HEALTH
  pulse_cooldown = 0.0
  focus_charge = 0.0
  focus_charging = false
  evade_charges = 3
  evade_recharge_progress = 0.0
  warden.reset_warden()
  warden.set_combat_active(true)
  combat_hud.visible = true
  if exploration_hud != null:
    exploration_hud.visible = false
  if discovery_ui != null:
    discovery_ui.set_exploration_input_enabled(false)
  _set_state(CombatState.COMBAT_ENTER)
  combat_audio_requested.emit(&"COMBAT_START")
  return true


func set_target_locked(enabled: bool) -> bool:
  if enabled and (state != CombatState.COMBAT or target_distance > LOCK_MAX_DISTANCE or not is_instance_valid(warden)):
    return false
  target_locked = enabled
  flight_camera.set_combat_target(warden if enabled else null)
  combat_audio_requested.emit(&"TARGET_LOCK" if enabled else &"TARGET_UNLOCK")
  return true


func fire_pulse() -> bool:
  if state != CombatState.COMBAT or not target_locked or focus_charging or pulse_cooldown > 0.0 or target_distance > ATTACK_MAX_DISTANCE:
    return false
  pulse_cooldown = 0.48
  _spawn_attack_visual(0.16, 0.14)
  warden.receive_attack(7.0, relative_sector, 0.0)
  combat_audio_requested.emit(&"PULSE")
  return true


func begin_focus() -> bool:
  if state != CombatState.COMBAT or not target_locked or pulse_cooldown > 0.0 or target_distance > ATTACK_MAX_DISTANCE:
    return false
  focus_charging = true
  focus_charge = 0.0
  focus_visual.visible = true
  combat_audio_requested.emit(&"FOCUS_CHARGE")
  return true


func charge_focus(delta: float) -> void:
  if focus_charging:
    focus_charge = minf(1.0, focus_charge + delta / 2.25)


func release_focus() -> bool:
  if not focus_charging:
    return false
  focus_charging = false
  if focus_charge < 0.35 or target_distance > ATTACK_MAX_DISTANCE:
    focus_charge = 0.0
    return false
  var damage := lerpf(14.0, 26.0, focus_charge)
  _spawn_attack_visual(0.34, 0.24)
  warden.receive_attack(damage, relative_sector, focus_charge)
  combat_audio_requested.emit(&"FOCUS_RELEASE")
  focus_charge = 0.0
  pulse_cooldown = 0.7
  return true


func cancel_focus() -> void:
  focus_charging = false
  focus_charge = 0.0
  if focus_visual != null:
    focus_visual.visible = false


func perform_evade(direction: float) -> bool:
  if state != CombatState.COMBAT or evade_charges <= 0:
    return false
  cancel_focus()
  evade_charges -= 1
  evade_protection = 0.6
  evade_visual.visible = true
  var lateral := flight_player.global_basis.x.normalized() * signf(direction)
  flight_player.velocity += lateral * 18.0
  combat_audio_requested.emit(&"EVADE")
  return true


func classify_sector(player_position: Vector3) -> StringName:
  var direction := (player_position - warden.global_position).normalized()
  var forward := -warden.global_basis.z.normalized()
  var front_dot := direction.dot(forward)
  if front_dot > 0.55:
    return &"FRONT"
  if front_dot < -0.55:
    return &"REAR"
  return &"RIGHT" if direction.dot(warden.global_basis.x.normalized()) > 0.0 else &"LEFT"


func apply_player_damage(amount: float) -> float:
  if state != CombatState.COMBAT:
    return 0.0
  var applied := amount * (0.15 if evade_protection > 0.0 else 1.0)
  player_health = maxf(0.0, player_health - applied)
  flight_camera.add_combat_impulse(clampf(applied / 24.0, 0.2, 1.0))
  player_damaged.emit(applied)
  if player_health <= 0.0:
    reset_encounter()
  return applied


func reset_encounter() -> void:
  player_health = MAX_PLAYER_HEALTH
  cancel_focus()
  evade_charges = 3
  evade_recharge_progress = 0.0
  target_locked = false
  flight_camera.set_combat_target(null)
  warden.reset_warden()
  warden.set_combat_active(true)
  flight_player.reset_flight(Transform3D(Basis(Vector3.UP, -0.75), COMBAT_START))
  flight_player.set_player_input_enabled(true)
  _set_state(CombatState.COMBAT_ENTER)


func start_combat_debug() -> void:
  flight_player.reset_flight(Transform3D(Basis(Vector3.UP, -0.75), COMBAT_START))
  flight_player.set_player_input_enabled(true)
  begin_encounter(true)


func _can_auto_start() -> bool:
  return not encounter_completed and flight_player.player_input_enabled and (traversal == null or traversal.state == TraversalCoordinator.TraversalState.FLIGHT)


func _update_relative_space() -> void:
  target_distance = flight_player.global_position.distance_to(warden.global_position)
  relative_sector = classify_sector(flight_player.global_position)


func _on_warden_attack(attack_name: StringName) -> void:
  combat_audio_requested.emit(&"WARDEN_ATTACK")
  var hit := false
  var damage := 0.0
  if attack_name == &"WARDEN_LANCE":
    hit = relative_sector == &"FRONT" and target_distance <= 125.0
    damage = 30.0
  elif attack_name == &"ARC_SWEEP":
    hit = relative_sector in [&"LEFT", &"RIGHT"] and target_distance <= 95.0
    damage = 21.0
  else:
    hit = relative_sector == &"REAR" and target_distance <= 80.0
    damage = 13.0
  if hit:
    apply_player_damage(damage)


func _on_warden_defeated() -> void:
  encounter_completed = true
  set_target_locked(false)
  combat_audio_requested.emit(&"VICTORY")
  _set_state(CombatState.COMBAT_EXIT)


func _finish_combat_exit() -> void:
  warden.set_combat_active(false)
  combat_hud.visible = false
  if exploration_hud != null:
    exploration_hud.visible = true
  if discovery_ui != null:
    discovery_ui.set_exploration_input_enabled(true)
  _set_state(CombatState.EXPLORATION)


func _set_state(next_state: CombatState) -> void:
  var previous := state
  state = next_state
  state_time = 0.0
  combat_state_changed.emit(previous, state)


func _build_combat_effects() -> void:
  focus_visual = MeshInstance3D.new()
  focus_visual.name = "FocusCharge"
  focus_visual.position = Vector3(0.0, 0.2, -4.5)
  var focus_mesh := SphereMesh.new()
  focus_mesh.radius = 0.85
  focus_mesh.height = 1.7
  focus_mesh.radial_segments = 12
  focus_mesh.rings = 6
  focus_mesh.material = _energy_material
  focus_visual.mesh = focus_mesh
  focus_visual.visible = false
  flight_player.add_child(focus_visual)

  evade_visual = Node3D.new()
  evade_visual.name = "EvadeTrails"
  evade_visual.visible = false
  flight_player.add_child(evade_visual)
  for side in [-1.0, 1.0]:
    var trail := MeshInstance3D.new()
    trail.position = Vector3(side * 1.8, -0.15, 3.2)
    var trail_mesh := BoxMesh.new()
    trail_mesh.size = Vector3(0.18, 0.18, 7.5)
    trail_mesh.material = _energy_material
    trail.mesh = trail_mesh
    evade_visual.add_child(trail)

func _spawn_attack_visual(width: float, duration: float) -> void:
  var beam := MeshInstance3D.new()
  beam.name = "CombatEnergyTrace"
  var distance := flight_player.global_position.distance_to(warden.global_position)
  var mesh := BoxMesh.new()
  mesh.size = Vector3(width, width, distance)
  mesh.material = _energy_material
  beam.mesh = mesh
  get_parent().add_child(beam)
  beam.global_position = flight_player.global_position.lerp(warden.global_position, 0.5)
  beam.look_at(warden.global_position, Vector3.UP)
  var tween := beam.create_tween()
  tween.tween_property(beam, "scale", Vector3(0.15, 0.15, 1.0), duration)
  tween.tween_callback(beam.queue_free)