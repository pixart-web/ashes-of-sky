class_name FirstFlightSequence
extends Node

signal opening_state_changed(state: OpeningState)
signal player_control_granted
signal audio_event_requested(event_name: StringName)

enum OpeningState {
  INTRO,
  ESTABLISHING,
  LUNARIS,
  HESITATION,
  RUN,
  FREEFALL,
  DEPLOY,
  RECOVERY,
  REVEAL,
  GAMEPLAY,
}

@export_category("References")
@export_node_path("LunarisFlightController") var flight_player_path: NodePath
@export_node_path("LunarisFlightCamera") var camera_rig_path: NodePath
@export_node_path("DiscoveryManager") var discovery_manager_path: NodePath
@export_node_path("DiscoveryUI") var discovery_ui_path: NodePath
@export_node_path("CanvasLayer") var debug_hud_path: NodePath
@export_node_path("FirstFlightUI") var opening_ui_path: NodePath

@export_category("Development")
@export var play_opening_on_start: bool = true
@export var show_timeline_debug: bool = false
@export_range(0.1, 100.0, 0.1) var timeline_speed_multiplier: float = 1.0

@export_category("Timeline")
@export var intro_black_duration: float = 1.2
@export var opening_text_duration: float = 8.0
@export var establishing_shot_duration: float = 5.0
@export var lunaris_shot_duration: float = 4.0
@export var hesitation_duration: float = 2.0
@export var run_duration: float = 3.0
@export var freefall_duration: float = 2.0
@export var wing_deploy_duration: float = 1.5
@export var recovery_duration: float = 3.0
@export var valley_reveal_duration: float = 3.0
@export var hud_restore_delay: float = 1.0
@export var title_delay: float = 2.5
@export var title_duration: float = 3.5

@export_category("Scripted Motion")
@export var opening_start_position := Vector3(0, 145, 675)
@export var cliff_edge_position := Vector3(0, 145, 570)
@export var freefall_gravity: float = 22.0
@export var freefall_forward_speed: float = 5.0
@export var handoff_speed: float = 24.0
@export var skip_handoff_position := Vector3(90, 60, 451)

var state: OpeningState = OpeningState.INTRO
var sequence_time: float = 0.0
var state_time: float = 0.0
var player_has_control: bool = false
var camera_handoff_snap_distance: float = 0.0

var flight_player: LunarisFlightController
var camera_rig: LunarisFlightCamera
var discovery_manager: DiscoveryManager
var discovery_ui: DiscoveryUI
var debug_hud: CanvasLayer
var opening_ui: FirstFlightUI
var left_wing: MeshInstance3D
var right_wing: MeshInstance3D

var _left_wing_base_rotation: Vector3
var _right_wing_base_rotation: Vector3
var _run_start_position: Vector3
var _freefall_start_position: Vector3
var _phase_start_velocity: Vector3
var _phase_start_rotation: Vector3
var _scripted_velocity: Vector3
var _reveal_start_camera_position: Vector3
var _title_shown: bool = false
var _hud_restored: bool = false


func _ready() -> void:
  flight_player = get_node_or_null(flight_player_path) as LunarisFlightController
  camera_rig = get_node_or_null(camera_rig_path) as LunarisFlightCamera
  discovery_manager = get_node_or_null(discovery_manager_path) as DiscoveryManager
  discovery_ui = get_node_or_null(discovery_ui_path) as DiscoveryUI
  debug_hud = get_node_or_null(debug_hud_path) as CanvasLayer
  opening_ui = get_node_or_null(opening_ui_path) as FirstFlightUI
  if not _references_are_valid():
    push_error("FirstFlightSequence is missing one or more required references.")
    set_process(false)
    set_process_unhandled_input(false)
    return

  left_wing = flight_player.get_node("VisualPivot/LeftWing") as MeshInstance3D
  right_wing = flight_player.get_node("VisualPivot/RightWing") as MeshInstance3D
  _left_wing_base_rotation = left_wing.rotation
  _right_wing_base_rotation = right_wing.rotation

  if play_opening_on_start:
    start_opening()
  else:
    start_direct_gameplay()


func _process(delta: float) -> void:
  var sequence_delta := delta * timeline_speed_multiplier
  sequence_time += sequence_delta
  state_time += sequence_delta
  if state == OpeningState.GAMEPLAY:
    _update_gameplay()
    _update_debug()
    return

  match state:
    OpeningState.INTRO:
      _update_intro()
    OpeningState.ESTABLISHING:
      _update_establishing()
    OpeningState.LUNARIS:
      _update_lunaris_shot()
    OpeningState.HESITATION:
      _update_hesitation()
    OpeningState.RUN:
      _update_run()
    OpeningState.FREEFALL:
      _update_freefall()
    OpeningState.DEPLOY:
      _update_deploy(sequence_delta)
    OpeningState.RECOVERY:
      _update_recovery(sequence_delta)
    OpeningState.REVEAL:
      _update_reveal(sequence_delta)

  _update_debug()
  if state_time >= _state_duration(state):
    _advance_state()


func _unhandled_input(event: InputEvent) -> void:
  if state != OpeningState.GAMEPLAY and event.is_action_pressed(&"skip_opening"):
    skip_to_gameplay()
    get_viewport().set_input_as_handled()


func start_opening() -> void:
  sequence_time = 0.0
  state_time = 0.0
  player_has_control = false
  _title_shown = false
  _hud_restored = false
  flight_player.begin_scripted_flight(Transform3D(Basis.IDENTITY, opening_start_position))
  camera_rig.set_process(false)
  camera_rig.set_process_unhandled_input(false)
  discovery_manager.set_discovery_enabled(false)
  discovery_ui.set_exploration_input_enabled(false)
  debug_hud.visible = false
  opening_ui.reset_for_opening()
  _set_wing_fold(0.88)
  _set_direct_camera_pose(
    Vector3(-210, 245, 780),
    Vector3(0, 95, -300),
    58.0
  )
  _enter_state(OpeningState.INTRO)
  audio_event_requested.emit(&"ambient_wind")


func start_direct_gameplay() -> void:
  state = OpeningState.GAMEPLAY
  sequence_time = 0.0
  state_time = 0.0
  player_has_control = true
  _title_shown = true
  _hud_restored = true
  flight_player.set_player_input_enabled(true)
  camera_rig.set_process(true)
  camera_rig.set_process_unhandled_input(true)
  discovery_manager.set_discovery_enabled(true)
  discovery_ui.set_exploration_input_enabled(true)
  debug_hud.visible = true
  opening_ui.hide_all()
  _set_wing_fold(0.0)
  _update_debug()


func skip_to_gameplay() -> void:
  if state == OpeningState.GAMEPLAY:
    return
  flight_player.update_scripted_flight(
    Transform3D(Basis.IDENTITY, skip_handoff_position),
    Vector3(0, 0, -handoff_speed)
  )
  _handoff_to_gameplay(true)


func get_scripted_handoff_time() -> float:
  return (
    intro_black_duration
    + opening_text_duration
    + establishing_shot_duration
    + lunaris_shot_duration
    + hesitation_duration
    + run_duration
    + freefall_duration
    + wing_deploy_duration
    + recovery_duration
    + valley_reveal_duration
  )


func get_state_name() -> String:
  return OpeningState.keys()[state]


func _update_intro() -> void:
  opening_ui.set_black_alpha(1.0)
  if state_time < intro_black_duration:
    opening_ui.set_opening_text_alpha(0.0, 0.0)
    return
  var text_progress := clampf(
    (state_time - intro_black_duration) / maxf(opening_text_duration, 0.001),
    0.0,
    1.0
  )
  var location_alpha := _window_alpha(text_progress, 0.0, 0.12, 0.43, 0.58)
  var era_alpha := _window_alpha(text_progress, 0.38, 0.52, 0.86, 1.0)
  opening_ui.set_opening_text_alpha(location_alpha, era_alpha)


func _update_establishing() -> void:
  var progress := _state_progress(establishing_shot_duration)
  opening_ui.set_black_alpha(1.0 - smoothstep(0.0, 0.28, progress))
  opening_ui.set_opening_text_alpha(0.0, 1.0 - smoothstep(0.0, 0.18, progress))
  var camera_position := Vector3(-210, 245, 780).lerp(Vector3(170, 220, 740), _ease(progress))
  var look_target := Vector3(0, 95, -300).lerp(Vector3(0, 105, -420), progress)
  _set_direct_camera_pose(camera_position, look_target, lerpf(58.0, 62.0, progress))


func _update_lunaris_shot() -> void:
  var progress := _ease(_state_progress(lunaris_shot_duration))
  var camera_position := Vector3(170, 220, 740).lerp(
    flight_player.global_position + Vector3(22, 10, 30),
    progress
  )
  var scenic_target := Vector3(0, 105, -420)
  var lunaris_target := flight_player.global_position + Vector3(0, 0, -35)
  _set_direct_camera_pose(
    camera_position,
    scenic_target.lerp(lunaris_target, progress),
    lerpf(62.0, 66.0, progress)
  )


func _update_hesitation() -> void:
  var progress := _ease(_state_progress(hesitation_duration))
  var camera_position := (
    flight_player.global_position
    + Vector3(22, 10, 30).lerp(Vector3(11, 5, 22), progress)
  )
  var look_target := flight_player.global_position + Vector3(0, -2, -50 - progress * 35)
  _set_direct_camera_pose(camera_position, look_target, lerpf(66.0, 68.0, progress))
  _set_wing_fold(lerpf(0.88, 0.96, sin(progress * PI)))


func _update_run() -> void:
  var progress := _ease(_state_progress(run_duration))
  var position := _run_start_position.lerp(cliff_edge_position, progress)
  var velocity := (cliff_edge_position - _run_start_position) / maxf(run_duration, 0.001)
  flight_player.update_scripted_flight(
    Transform3D(Basis.from_euler(Vector3.ZERO), position),
    velocity
  )
  _set_wing_fold(1.0)
  var camera_position := position + Vector3(9, 7, 24)
  _set_direct_camera_pose(camera_position, position + Vector3(0, -1, -24), lerpf(68.0, 71.0, progress))


func _update_freefall() -> void:
  var fall_time := minf(state_time, freefall_duration)
  var position := (
    _freefall_start_position
    + Vector3.FORWARD * freefall_forward_speed * fall_time
    + Vector3.DOWN * 0.5 * freefall_gravity * fall_time * fall_time
  )
  _scripted_velocity = (
    Vector3.FORWARD * freefall_forward_speed
    + Vector3.DOWN * freefall_gravity * fall_time
  )
  var progress := _state_progress(freefall_duration)
  var rotation := Vector3(deg_to_rad(-24.0 * progress), 0, 0)
  flight_player.update_scripted_flight(
    Transform3D(Basis.from_euler(rotation), position),
    _scripted_velocity
  )
  _set_wing_fold(1.0)
  _set_direct_camera_pose(
    position + Vector3(8, 7, 17),
    position + Vector3(0, -14, -18),
    lerpf(71.0, 74.0, progress)
  )


func _update_deploy(delta: float) -> void:
  var progress := _ease(_state_progress(wing_deploy_duration))
  _scripted_velocity = _phase_start_velocity.lerp(Vector3(8, -5, -16), progress)
  var rotation := _phase_start_rotation.lerp(Vector3(deg_to_rad(-5.0), 0, 0), progress)
  var position := flight_player.global_position + _scripted_velocity * delta
  flight_player.update_scripted_flight(
    Transform3D(Basis.from_euler(rotation), position),
    _scripted_velocity
  )
  _set_wing_fold(1.0 - progress)
  _set_direct_camera_pose(
    position + Vector3(8, lerpf(7.0, 10.0, progress), lerpf(17.0, 28.0, progress)),
    position + Vector3(0, -lerpf(12.0, 1.0, progress), -lerpf(18.0, 34.0, progress)),
    lerpf(74.0, 82.0, progress)
  )


func _update_recovery(delta: float) -> void:
  var progress := _ease(_state_progress(recovery_duration))
  _scripted_velocity = _phase_start_velocity.lerp(Vector3(24, 0, -18), progress)
  var rotation := _phase_start_rotation.lerp(Vector3.ZERO, progress)
  var position := flight_player.global_position + _scripted_velocity * delta
  flight_player.update_scripted_flight(
    Transform3D(Basis.from_euler(rotation), position),
    _scripted_velocity
  )
  _set_wing_fold(0.0)
  _follow_gameplay_camera(delta, Vector3(7, 6, 8) * (1.0 - progress), lerpf(82.0, 75.0, progress), 2.2)


func _update_reveal(delta: float) -> void:
  var progress := _ease(_state_progress(valley_reveal_duration))
  _scripted_velocity = _phase_start_velocity.lerp(Vector3(0, 1, -10), progress)
  var position := flight_player.global_position + _scripted_velocity * delta
  flight_player.update_scripted_flight(
    Transform3D(Basis.IDENTITY, position),
    _scripted_velocity
  )
  _set_wing_fold(0.0)
  var basis := _gameplay_camera_basis()
  var anchor := flight_player.global_position + Vector3.UP * camera_rig.base_height
  var gameplay_camera_position := anchor + basis.z.normalized() * camera_rig.base_distance
  var scenic_offset := Vector3(0, 7, 5) * sin(progress * PI)
  var camera_position := _reveal_start_camera_position.lerp(
    gameplay_camera_position + scenic_offset,
    progress
  )
  var look_target := flight_player.global_position + (-basis.z.normalized()) * camera_rig.look_ahead_distance
  _set_direct_camera_pose(
    camera_position,
    look_target,
    lerpf(75.0, camera_rig.base_fov, progress)
  )


func _update_gameplay() -> void:
  if not _hud_restored and state_time >= hud_restore_delay:
    debug_hud.visible = true
    _hud_restored = true
  if not _title_shown and state_time >= title_delay:
    opening_ui.play_title(title_duration)
    audio_event_requested.emit(&"title_reveal")
    _title_shown = true


func _advance_state() -> void:
  match state:
    OpeningState.INTRO:
      _enter_state(OpeningState.ESTABLISHING)
    OpeningState.ESTABLISHING:
      _enter_state(OpeningState.LUNARIS)
    OpeningState.LUNARIS:
      _enter_state(OpeningState.HESITATION)
    OpeningState.HESITATION:
      _enter_state(OpeningState.RUN)
    OpeningState.RUN:
      _enter_state(OpeningState.FREEFALL)
    OpeningState.FREEFALL:
      _enter_state(OpeningState.DEPLOY)
    OpeningState.DEPLOY:
      _enter_state(OpeningState.RECOVERY)
    OpeningState.RECOVERY:
      _enter_state(OpeningState.REVEAL)
    OpeningState.REVEAL:
      _handoff_to_gameplay(false)


func _enter_state(next_state: OpeningState) -> void:
  state = next_state
  state_time = 0.0
  opening_state_changed.emit(state)
  match state:
    OpeningState.ESTABLISHING:
      audio_event_requested.emit(&"distant_environmental_rumble")
    OpeningState.RUN:
      _run_start_position = flight_player.global_position
      audio_event_requested.emit(&"lunaris_movement")
    OpeningState.FREEFALL:
      _freefall_start_position = flight_player.global_position
    OpeningState.DEPLOY:
      _capture_motion_phase()
      audio_event_requested.emit(&"wing_deployment")
    OpeningState.RECOVERY:
      _capture_motion_phase()
    OpeningState.REVEAL:
      _capture_motion_phase()
      _reveal_start_camera_position = camera_rig.camera.global_position


func _capture_motion_phase() -> void:
  _phase_start_velocity = flight_player.velocity
  _phase_start_rotation = flight_player.rotation


func _handoff_to_gameplay(skipped: bool) -> void:
  if skipped:
    flight_player.update_scripted_flight(
      Transform3D(Basis.IDENTITY, skip_handoff_position),
      Vector3(0, 0, -handoff_speed)
    )
  else:
    flight_player.update_scripted_flight(
      Transform3D(Basis.IDENTITY, flight_player.global_position),
      Vector3(0, 0, -handoff_speed)
    )
  _set_wing_fold(0.0)
  var camera_position_before_handoff := camera_rig.camera.global_position
  _prepare_gameplay_camera()
  camera_handoff_snap_distance = camera_position_before_handoff.distance_to(
    camera_rig.camera.global_position
  )
  flight_player.complete_scripted_handoff(Vector3(0, 0, -handoff_speed), Vector3.ZERO)
  discovery_manager.set_discovery_enabled(true)
  discovery_ui.set_exploration_input_enabled(true)
  opening_ui.set_black_alpha(0.0)
  opening_ui.set_opening_text_alpha(0.0, 0.0)
  state = OpeningState.GAMEPLAY
  state_time = 0.0
  player_has_control = true
  opening_state_changed.emit(state)
  _hud_restored = skipped
  debug_hud.visible = skipped
  camera_rig.set_process(true)
  camera_rig.set_process_unhandled_input(true)
  player_control_granted.emit()
  audio_event_requested.emit(&"gameplay_handoff")


func _prepare_gameplay_camera() -> void:
  var basis := _gameplay_camera_basis()
  var anchor := flight_player.global_position + Vector3.UP * camera_rig.base_height
  camera_rig.global_position = anchor
  camera_rig.global_basis = basis
  camera_rig.current_distance = camera_rig.base_distance
  camera_rig.target_distance = camera_rig.base_distance
  camera_rig.target_fov = camera_rig.base_fov
  camera_rig.collision_probe.spring_length = camera_rig.base_distance
  camera_rig.camera.position = Vector3(0, 0, camera_rig.base_distance)
  camera_rig.camera.fov = camera_rig.base_fov


func _follow_gameplay_camera(
  delta: float,
  extra_world_offset: Vector3,
  fov: float,
  smoothing: float
) -> void:
  var basis := _gameplay_camera_basis()
  var anchor := flight_player.global_position + Vector3.UP * camera_rig.base_height
  var target_camera_position := (
    anchor
    + basis.z.normalized() * camera_rig.base_distance
    + extra_world_offset
  )
  var current_camera_position := camera_rig.camera.global_position
  var weight := 1.0 - exp(-smoothing * delta)
  var camera_position := current_camera_position.lerp(target_camera_position, weight)
  var look_target := flight_player.global_position + (-basis.z.normalized()) * camera_rig.look_ahead_distance
  _set_direct_camera_pose(camera_position, look_target, fov)


func _gameplay_camera_basis() -> Basis:
  var anchor := flight_player.global_position + Vector3.UP * camera_rig.base_height
  var forward := -flight_player.global_basis.z.normalized()
  var look_target := flight_player.global_position + forward * camera_rig.look_ahead_distance
  return Transform3D(Basis.IDENTITY, anchor).looking_at(look_target, Vector3.UP).basis


func _set_direct_camera_pose(
  camera_position: Vector3,
  look_target: Vector3,
  fov: float
) -> void:
  camera_rig.global_position = camera_position
  camera_rig.global_basis = Transform3D(Basis.IDENTITY, camera_position).looking_at(
    look_target,
    Vector3.UP
  ).basis
  camera_rig.camera.position = Vector3.ZERO
  camera_rig.camera.fov = fov


func _set_wing_fold(amount: float) -> void:
  var fold := clampf(amount, 0.0, 1.0)
  left_wing.rotation = _left_wing_base_rotation + Vector3(
    deg_to_rad(24.0),
    deg_to_rad(62.0),
    deg_to_rad(48.0)
  ) * fold
  right_wing.rotation = _right_wing_base_rotation + Vector3(
    deg_to_rad(24.0),
    deg_to_rad(-62.0),
    deg_to_rad(-48.0)
  ) * fold


func _state_duration(current_state: OpeningState) -> float:
  match current_state:
    OpeningState.INTRO:
      return intro_black_duration + opening_text_duration
    OpeningState.ESTABLISHING:
      return establishing_shot_duration
    OpeningState.LUNARIS:
      return lunaris_shot_duration
    OpeningState.HESITATION:
      return hesitation_duration
    OpeningState.RUN:
      return run_duration
    OpeningState.FREEFALL:
      return freefall_duration
    OpeningState.DEPLOY:
      return wing_deploy_duration
    OpeningState.RECOVERY:
      return recovery_duration
    OpeningState.REVEAL:
      return valley_reveal_duration
  return INF


func _state_progress(duration: float) -> float:
  return clampf(state_time / maxf(duration, 0.001), 0.0, 1.0)


func _ease(value: float) -> float:
  return smoothstep(0.0, 1.0, value)


func _window_alpha(
  value: float,
  fade_in_start: float,
  fade_in_end: float,
  fade_out_start: float,
  fade_out_end: float
) -> float:
  var fade_in := smoothstep(fade_in_start, fade_in_end, value)
  var fade_out := 1.0 - smoothstep(fade_out_start, fade_out_end, value)
  return minf(fade_in, fade_out)


func _update_debug() -> void:
  opening_ui.update_timeline_debug(
    show_timeline_debug,
    get_state_name(),
    sequence_time,
    player_has_control
  )


func _references_are_valid() -> bool:
  return (
    flight_player != null
    and camera_rig != null
    and discovery_manager != null
    and discovery_ui != null
    and debug_hud != null
    and opening_ui != null
  )
