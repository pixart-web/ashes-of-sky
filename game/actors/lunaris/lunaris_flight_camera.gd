class_name LunarisFlightCamera
extends Node3D

@export_category("Target")
@export_node_path("LunarisFlightController") var target_path: NodePath

@export_category("Composition")
@export var base_distance: float = 12.0
@export var base_height: float = 3.5
@export var speed_distance_multiplier: float = 2.0
@export var boost_distance_bonus: float = 2.5

@export_category("Following")
@export var follow_smoothing: float = 5.0
@export var rotation_smoothing: float = 4.0
@export var distance_smoothing: float = 5.0
@export var collision_return_speed: float = 8.0

@export_category("Look Ahead")
@export var look_ahead_distance: float = 16.0
@export var look_ahead_strength: float = 3.0
@export_range(0.0, 1.0, 0.01) var pitch_follow_strength: float = 0.45
@export_range(0.0, 0.5, 0.01) var camera_bank_influence: float = 0.15

@export_category("Field of View")
@export var minimum_fov: float = 68.0
@export var base_fov: float = 70.0
@export var maximum_fov: float = 78.0
@export var boost_fov: float = 86.0
@export var fov_smoothing: float = 4.5

@export_category("Manual Look")
@export var manual_look_speed: float = 95.0
@export var mouse_sensitivity: float = 0.12
@export var invert_y: bool = false
@export_range(0.0, 1.0) var shake_strength: float = 0.7
@export var manual_pitch_limit: float = 35.0
@export var manual_recenter_delay: float = 1.5
@export var manual_recenter_speed: float = 90.0

@onready var collision_probe: SpringArm3D = $CollisionProbe
@onready var camera: Camera3D = $Camera3D

var flight_target: LunarisFlightController
var current_distance: float = 0.0
var target_distance: float = 0.0
var target_fov: float = 0.0
var camera_mode: StringName = &"CHASE"
var target_bank: float = 0.0
var manual_yaw_offset: float = 0.0
var manual_pitch_offset: float = 0.0
var combat_target: Node3D
var combat_framing_strength: float = 0.18
var story_target: Node3D
var story_framing_strength: float = 0.0
var story_target_time: float = 0.0

var _manual_idle_time: float = 0.0
var _combat_impulse := Vector3.ZERO


func _ready() -> void:
  flight_target = get_node_or_null(target_path) as LunarisFlightController
  if flight_target == null:
    push_error("LunarisFlightCamera requires a LunarisFlightController target.")
    set_process(false)
    set_process_unhandled_input(false)
    return

  current_distance = base_distance
  target_distance = base_distance
  target_fov = base_fov
  global_position = _target_anchor_position()
  global_basis = _desired_camera_basis()
  collision_probe.add_excluded_object(flight_target.get_rid())
  collision_probe.spring_length = target_distance
  camera.position = Vector3(0.0, 0.0, current_distance) + _combat_impulse
  camera.fov = base_fov


func add_combat_impulse(strength: float) -> void:
  _combat_impulse += Vector3(strength * 0.65, strength * 0.35, 0.0)


func set_story_target(target: Node3D, duration: float, strength: float = 0.1) -> void:
  story_target = target
  story_target_time = maxf(0.0, duration)
  story_framing_strength = clampf(strength, 0.0, 0.2)


func clear_story_target() -> void:
  story_target = null
  story_target_time = 0.0
  story_framing_strength = 0.0


func set_combat_target(target: Node3D) -> void:
  combat_target = target


func _process(delta: float) -> void:
  if flight_target == null:
    return

  _update_manual_look(delta)
  _update_follow(delta)
  _update_distance_and_collision(delta)
  _update_fov(delta)
  _combat_impulse = _combat_impulse.lerp(Vector3.ZERO, 1.0 - exp(-11.0 * delta))
  if story_target_time > 0.0:
    story_target_time = maxf(0.0, story_target_time - delta)
    if story_target_time <= 0.0:
      clear_story_target()


func _unhandled_input(event: InputEvent) -> void:
  if not Input.is_action_pressed(&"camera_look"):
    return
  if event is not InputEventMouseMotion:
    return

  manual_yaw_offset -= deg_to_rad(event.relative.x * mouse_sensitivity)
  manual_pitch_offset = clampf(
    manual_pitch_offset - deg_to_rad(event.relative.y * mouse_sensitivity * (-1.0 if invert_y else 1.0)),
    -deg_to_rad(manual_pitch_limit),
    deg_to_rad(manual_pitch_limit)
  )
  manual_yaw_offset = wrapf(manual_yaw_offset, -PI, PI)
  _manual_idle_time = 0.0


func _update_manual_look(delta: float) -> void:
  var stick_input := Input.get_vector(
    &"camera_look_left",
    &"camera_look_right",
    &"camera_look_up",
    &"camera_look_down"
  )
  var has_manual_input := stick_input.length_squared() > 0.01

  if has_manual_input:
    manual_yaw_offset = wrapf(
      manual_yaw_offset + deg_to_rad(manual_look_speed) * stick_input.x * delta,
      -PI,
      PI
    )
    manual_pitch_offset = clampf(
      manual_pitch_offset + deg_to_rad(manual_look_speed) * stick_input.y * delta,
      -deg_to_rad(manual_pitch_limit),
      deg_to_rad(manual_pitch_limit)
    )
    _manual_idle_time = 0.0
  else:
    _manual_idle_time += delta

  if Input.is_action_just_pressed(&"camera_recenter"):
    _manual_idle_time = manual_recenter_delay

  if _manual_idle_time >= manual_recenter_delay:
    var recenter_step := deg_to_rad(manual_recenter_speed) * delta
    manual_yaw_offset = move_toward(manual_yaw_offset, 0.0, recenter_step)
    manual_pitch_offset = move_toward(manual_pitch_offset, 0.0, recenter_step)


func _update_follow(delta: float) -> void:
  var position_weight := _smoothing_weight(follow_smoothing, delta)
  global_position = global_position.lerp(_target_anchor_position(), position_weight)

  var current_rotation := global_basis.get_rotation_quaternion()
  var desired_rotation := _desired_camera_basis().get_rotation_quaternion()
  var rotation_weight := _smoothing_weight(rotation_smoothing, delta)
  global_basis = Basis(current_rotation.slerp(desired_rotation, rotation_weight))


func _update_distance_and_collision(delta: float) -> void:
  target_distance = _speed_based_distance()
  collision_probe.spring_length = target_distance

  var hit_distance := collision_probe.get_hit_length()
  var has_collision := hit_distance < target_distance - 0.05
  if has_collision:
    current_distance = minf(current_distance, hit_distance)
    camera_mode = &"COLLISION"
  else:
    var distance_weight := _smoothing_weight(distance_smoothing, delta)
    var smoothed_distance := lerpf(current_distance, target_distance, distance_weight)
    current_distance = move_toward(
      current_distance,
      smoothed_distance,
      collision_return_speed * delta
    )
    camera_mode = _desired_camera_mode()

  camera.position = Vector3(0.0, 0.0, current_distance) + _combat_impulse


func _update_fov(delta: float) -> void:
  target_fov = _speed_based_fov()
  camera.fov = lerpf(camera.fov, target_fov, _smoothing_weight(fov_smoothing, delta))


func _target_anchor_position() -> Vector3:
  return flight_target.global_position + Vector3.UP * base_height


func _desired_camera_basis() -> Basis:
  var target_forward := -flight_target.global_basis.z.normalized()
  var flat_forward := Vector3(target_forward.x, 0.0, target_forward.z).normalized()
  var anticipated_forward := flat_forward.lerp(
    target_forward,
    pitch_follow_strength
  ).normalized()
  var yaw_input := Input.get_axis(&"flight_yaw_right", &"flight_yaw_left")
  var pitch_input := Input.get_axis(&"flight_pitch_down", &"flight_pitch_up")
  var target_right := flight_target.global_basis.x.normalized()
  var look_target := (
    flight_target.global_position
    + anticipated_forward * look_ahead_distance
    - target_right * yaw_input * look_ahead_strength
    + Vector3.UP * pitch_input * look_ahead_strength
  )
  if is_instance_valid(combat_target):
    var enemy_direction := combat_target.global_position - look_target
    look_target += enemy_direction * combat_framing_strength
  elif is_instance_valid(story_target) and story_target_time > 0.0:
    var story_direction := story_target.global_position - look_target
    look_target += story_direction * story_framing_strength
  var desired_basis := Transform3D(Basis.IDENTITY, global_position).looking_at(
    look_target,
    Vector3.UP
  ).basis

  desired_basis = desired_basis.rotated(Vector3.UP, manual_yaw_offset)
  desired_basis = desired_basis.rotated(desired_basis.x.normalized(), manual_pitch_offset)

  var visual_bank := flight_target.visual_pivot.rotation.z
  target_bank = visual_bank * camera_bank_influence
  return desired_basis.rotated(-desired_basis.z.normalized(), target_bank)


func _speed_based_distance() -> float:
  var normal_ratio := clampf(
    inverse_lerp(flight_target.minimum_speed, flight_target.maximum_speed, flight_target.current_speed),
    0.0,
    1.0
  )
  var boost_ratio := clampf(
    inverse_lerp(flight_target.maximum_speed, flight_target.boost_speed, flight_target.current_speed),
    0.0,
    1.0
  )
  return (
    base_distance
    + normal_ratio * speed_distance_multiplier
    + boost_ratio * boost_distance_bonus
  )


func _speed_based_fov() -> float:
  var speed := flight_target.current_speed
  if speed <= flight_target.cruise_speed:
    return lerpf(
      minimum_fov,
      base_fov,
      clampf(inverse_lerp(flight_target.minimum_speed, flight_target.cruise_speed, speed), 0.0, 1.0)
    )
  if speed <= flight_target.maximum_speed:
    return lerpf(
      base_fov,
      maximum_fov,
      inverse_lerp(flight_target.cruise_speed, flight_target.maximum_speed, speed)
    )
  return lerpf(
    maximum_fov,
    boost_fov,
    clampf(inverse_lerp(flight_target.maximum_speed, flight_target.boost_speed, speed), 0.0, 1.0)
  )


func _desired_camera_mode() -> StringName:
  if absf(manual_yaw_offset) > 0.01 or absf(manual_pitch_offset) > 0.01:
    return &"MANUAL"
  if flight_target.flight_state == &"BOOST":
    return &"BOOST"
  return &"CHASE"


func _smoothing_weight(smoothing: float, delta: float) -> float:
  return 1.0 - exp(-maxf(smoothing, 0.0) * delta)
