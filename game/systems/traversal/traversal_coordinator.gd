class_name TraversalCoordinator
extends Node

signal traversal_state_changed(previous: TraversalState, current: TraversalState)
signal landing_audio_requested
signal lunaris_settled_audio_requested
signal footsteps_audio_ready
signal interior_ambience_audio_requested
signal inner_door_hum_audio_requested
signal mounting_audio_requested
signal takeoff_audio_requested

enum TraversalState { FLIGHT, LANDING, LANDED, DISMOUNTING, GROUND, MOUNTING, MOUNTED, TAKEOFF }

@export_node_path("LunarisFlightController") var flight_player_path: NodePath
@export_node_path("GroundPlayer") var ground_player_path: NodePath
@export_node_path("LunarisFlightCamera") var flight_camera_path: NodePath
@export_node_path("SilentChamberGroundWorld") var chamber_world_path: NodePath
@export_node_path("DiscoveryUI") var discovery_ui_path: NodePath
@export var landing_duration: float = 2.4
@export var dismount_duration: float = 1.25
@export var mounting_duration: float = 1.15
@export var takeoff_duration: float = 2.4
@export var development_start_ground: bool = false

var state: TraversalState = TraversalState.FLIGHT
var flight_player: LunarisFlightController
var ground_player: GroundPlayer
var flight_camera: LunarisFlightCamera
var chamber_world: SilentChamberGroundWorld
var discovery_ui: DiscoveryUI
var prompt_layer: CanvasLayer
var prompt_label: Label

var _state_time: float = 0.0
var _transition_start: Transform3D
var _dismount_start: Vector3


func _ready() -> void:
  flight_player = get_node_or_null(flight_player_path) as LunarisFlightController
  ground_player = get_node_or_null(ground_player_path) as GroundPlayer
  flight_camera = get_node_or_null(flight_camera_path) as LunarisFlightCamera
  chamber_world = get_node_or_null(chamber_world_path) as SilentChamberGroundWorld
  discovery_ui = get_node_or_null(discovery_ui_path) as DiscoveryUI
  _build_prompt()
  if flight_player == null or ground_player == null or flight_camera == null or chamber_world == null:
    push_error("TraversalCoordinator requires flight, ground, camera, and Silent Chamber references.")
    set_physics_process(false)
    return
  ground_player.set_player_input_enabled(false)
  if development_start_ground:
    start_ground_debug.call_deferred()


func _physics_process(delta: float) -> void:
  _state_time += delta
  match state:
    TraversalState.FLIGHT:
      _update_flight_prompt()
    TraversalState.LANDING:
      _update_landing()
    TraversalState.LANDED:
      if _state_time >= 0.3:
        _begin_dismount()
    TraversalState.DISMOUNTING:
      _update_dismount()
    TraversalState.GROUND:
      _update_ground_prompt()
      if ground_player.global_position.y < -20.0:
        recover_ground()
    TraversalState.MOUNTING:
      _update_mounting()
    TraversalState.MOUNTED:
      prompt_label.text = "TAKE OFF  [L / E]"
      prompt_label.visible = true
    TraversalState.TAKEOFF:
      _update_takeoff()


func _unhandled_input(event: InputEvent) -> void:
  if event.is_action_pressed(&"start_silent_chamber_ground"):
    start_ground_debug()
    get_viewport().set_input_as_handled()
  elif event.is_action_pressed(&"recover_ground") and state == TraversalState.GROUND:
    recover_ground()
    get_viewport().set_input_as_handled()
  elif event.is_action_pressed(&"land"):
    if state == TraversalState.FLIGHT:
      request_landing()
    elif state == TraversalState.MOUNTED:
      request_takeoff()
    get_viewport().set_input_as_handled()
  elif event.is_action_pressed(&"interact"):
    if state == TraversalState.GROUND and can_mount():
      request_mount()
      get_viewport().set_input_as_handled()
    elif state == TraversalState.MOUNTED:
      request_takeoff()
      get_viewport().set_input_as_handled()


func is_landing_valid() -> bool:
  if state != TraversalState.FLIGHT or not flight_player.player_input_enabled:
    return false
  var offset := flight_player.global_position - SilentChamberGroundWorld.LANDING_POSITION
  var in_volume := absf(offset.x) <= 45.0 and absf(offset.z) <= 34.0 and offset.y >= 0.0 and offset.y <= 42.0
  var forward := -flight_player.global_basis.z.normalized()
  var safe_orientation := forward.dot(Vector3.RIGHT) >= 0.35 and absf(forward.y) <= 0.55
  return in_volume and flight_player.current_speed <= 18.0 and safe_orientation


func request_landing() -> bool:
  if not is_landing_valid():
    return false
  _transition_start = flight_player.global_transform
  flight_player.set_player_input_enabled(false)
  flight_player.velocity = Vector3.ZERO
  _set_state(TraversalState.LANDING)
  landing_audio_requested.emit()
  return true


func can_mount() -> bool:
  return state == TraversalState.GROUND and ground_player.global_position.distance_to(SilentChamberGroundWorld.DISMOUNT_POSITION) <= 7.0


func request_mount() -> bool:
  if not can_mount():
    return false
  ground_player.set_player_input_enabled(false)
  _dismount_start = ground_player.global_position
  _set_state(TraversalState.MOUNTING)
  mounting_audio_requested.emit()
  return true


func request_takeoff() -> bool:
  if state != TraversalState.MOUNTED:
    return false
  _transition_start = flight_player.global_transform
  _set_state(TraversalState.TAKEOFF)
  if flight_player.has_node("VisualPivot/LunarisVisual"):
    (flight_player.get_node("VisualPivot/LunarisVisual") as LunarisVisual).set_wing_pose(LunarisVisual.WingPose.FULL_SPREAD)
  takeoff_audio_requested.emit()
  return true


func start_ground_debug() -> void:
  if flight_player == null or ground_player == null:
    return
  flight_player.reset_flight(Transform3D(Basis(Vector3.UP, -PI * 0.5), SilentChamberGroundWorld.LANDING_POSITION))
  flight_player.set_player_input_enabled(false)
  flight_player.flight_state = &"LANDED"
  if flight_player.has_node("VisualPivot/LunarisVisual"):
    var visual := flight_player.get_node("VisualPivot/LunarisVisual") as LunarisVisual
    visual.set_wing_pose(LunarisVisual.WingPose.FOLDED)
    visual.set_rider_visible(false)
  ground_player.reset_ground(SilentChamberGroundWorld.RECOVERY_POSITION)
  ground_player.set_player_input_enabled(true)
  flight_camera.set_process(false)
  ground_player.camera.current = true
  _set_state(TraversalState.GROUND)
  interior_ambience_audio_requested.emit()
  footsteps_audio_ready.emit()


func recover_ground() -> void:
  if state == TraversalState.GROUND:
    ground_player.reset_ground(SilentChamberGroundWorld.RECOVERY_POSITION)


func _update_flight_prompt() -> void:
  prompt_label.text = "LAND  [L]"
  prompt_label.visible = is_landing_valid()


func _update_landing() -> void:
  var ratio := clampf(_state_time / maxf(landing_duration, 0.01), 0.0, 1.0)
  var eased := ratio * ratio * (3.0 - 2.0 * ratio)
  var target := Transform3D(Basis(Vector3.UP, -PI * 0.5), SilentChamberGroundWorld.LANDING_POSITION)
  flight_player.global_position = _transition_start.origin.lerp(target.origin, eased)
  flight_player.global_basis = Basis(_transition_start.basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), eased))
  if ratio >= 1.0:
    flight_player.flight_state = &"LANDED"
    if flight_player.has_node("VisualPivot/LunarisVisual"):
      (flight_player.get_node("VisualPivot/LunarisVisual") as LunarisVisual).set_wing_pose(LunarisVisual.WingPose.FOLDED)
    lunaris_settled_audio_requested.emit()
    _set_state(TraversalState.LANDED)


func _begin_dismount() -> void:
  _dismount_start = flight_player.global_position + Vector3(0, 1.4, 0)
  ground_player.reset_ground(_dismount_start)
  ground_player.visible = true
  if flight_player.has_node("VisualPivot/LunarisVisual"):
    (flight_player.get_node("VisualPivot/LunarisVisual") as LunarisVisual).set_rider_visible(false)
  flight_camera.set_process(false)
  ground_player.camera.current = true
  _set_state(TraversalState.DISMOUNTING)


func _update_dismount() -> void:
  var ratio := clampf(_state_time / maxf(dismount_duration, 0.01), 0.0, 1.0)
  ground_player.global_position = _dismount_start.lerp(SilentChamberGroundWorld.DISMOUNT_POSITION, ratio)
  if ratio >= 1.0:
    ground_player.set_player_input_enabled(true)
    _set_state(TraversalState.GROUND)
    footsteps_audio_ready.emit()
    interior_ambience_audio_requested.emit()


func _update_ground_prompt() -> void:
  prompt_label.text = "MOUNT  [E]"
  prompt_label.visible = can_mount()
  if ground_player.global_position.distance_to(SilentChamberGroundWorld.INNER_DOOR_POSITION) < 16.0:
    inner_door_hum_audio_requested.emit()


func _update_mounting() -> void:
  var ratio := clampf(_state_time / maxf(mounting_duration, 0.01), 0.0, 1.0)
  ground_player.global_position = _dismount_start.lerp(flight_player.global_position + Vector3(0, 1.2, 0), ratio)
  if ratio >= 1.0:
    ground_player.visible = false
    if flight_player.has_node("VisualPivot/LunarisVisual"):
      (flight_player.get_node("VisualPivot/LunarisVisual") as LunarisVisual).set_rider_visible(true)
    _set_state(TraversalState.MOUNTED)


func _update_takeoff() -> void:
  var ratio := clampf(_state_time / maxf(takeoff_duration, 0.01), 0.0, 1.0)
  var forward := Vector3.RIGHT
  flight_player.global_position = _transition_start.origin + forward * (ratio * 18.0) + Vector3.UP * (ratio * ratio * 14.0)
  if ratio >= 1.0:
    ground_player.camera.current = false
    flight_camera.set_process(true)
    flight_camera.camera.current = true
    flight_player.complete_scripted_handoff((forward + Vector3.UP * 0.18).normalized() * flight_player.cruise_speed, Vector3(0, -PI * 0.5, 0))
    if flight_player.has_node("VisualPivot/LunarisVisual"):
      (flight_player.get_node("VisualPivot/LunarisVisual") as LunarisVisual).set_wing_pose(LunarisVisual.WingPose.GLIDE)
    _set_state(TraversalState.FLIGHT)


func _set_state(next_state: TraversalState) -> void:
  var previous := state
  state = next_state
  _state_time = 0.0
  prompt_label.visible = false
  traversal_state_changed.emit(previous, state)


func _build_prompt() -> void:
  prompt_layer = CanvasLayer.new()
  prompt_layer.name = "TraversalPrompt"
  prompt_layer.layer = 8
  add_child(prompt_layer)
  prompt_label = Label.new()
  prompt_label.name = "Prompt"
  prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  prompt_label.position = Vector2(490, 625)
  prompt_label.size = Vector2(300, 42)
  prompt_label.add_theme_font_size_override("font_size", 20)
  prompt_label.add_theme_color_override("font_color", Color(0.84, 0.82, 0.72))
  prompt_label.visible = false
  prompt_layer.add_child(prompt_label)


func reset_to_flight() -> void:
  if flight_player == null or ground_player == null or flight_camera == null:
    return
  ground_player.set_player_input_enabled(false)
  ground_player.visible = false
  flight_player.visible = true
  flight_player.set_player_input_enabled(true)
  flight_player.flight_state = &"CRUISE"
  if flight_player.has_node("VisualPivot/LunarisVisual"):
    var visual := flight_player.get_node("VisualPivot/LunarisVisual") as LunarisVisual
    visual.set_rider_visible(true)
    visual.set_wing_pose(LunarisVisual.WingPose.GLIDE)
  flight_camera.set_process(true)
  flight_camera.set_process_unhandled_input(true)
  flight_camera.camera.current = true
  if discovery_ui != null:
    discovery_ui.set_exploration_input_enabled(true)
  prompt_label.visible = false
  _set_state(TraversalState.FLIGHT)