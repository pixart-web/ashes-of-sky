class_name LunarisFlightController
extends CharacterBody3D

signal telemetry_updated(speed: float, altitude: float, flight_state: StringName)

@export_category("Speed")
@export var minimum_speed: float = 8.0
@export var cruise_speed: float = 18.0
@export var maximum_speed: float = 32.0
@export var boost_speed: float = 48.0
@export var acceleration: float = 10.0
@export var deceleration: float = 12.0
@export var boost_acceleration: float = 22.0
@export var momentum_response: float = 24.0

@export_category("Steering")
@export var yaw_speed: float = 70.0
@export var pitch_speed: float = 50.0
@export var maximum_pitch: float = 50.0
@export var maximum_bank: float = 30.0
@export var rotation_smoothing: float = 180.0
@export var bank_smoothing: float = 120.0
@export_range(0.5, 1.0, 0.01) var high_speed_turn_factor: float = 0.72
@export_range(1.0, 1.5, 0.01) var low_speed_turn_factor: float = 1.12

@onready var visual_pivot: Node3D = $VisualPivot

var current_speed: float = cruise_speed
var flight_state: StringName = &"CRUISE"

var _pitch: float = 0.0
var _yaw: float = 0.0
var _pitch_rate: float = 0.0
var _yaw_rate: float = 0.0
var _yaw_input: float = 0.0


func _ready() -> void:
  motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
  current_speed = clampf(current_speed, minimum_speed, boost_speed)
  _pitch = rotation.x
  _yaw = rotation.y


func _physics_process(delta: float) -> void:
  _update_speed(delta)
  _update_steering(delta)
  _update_velocity(delta)
  move_and_slide()
  _update_visual_bank(delta)

  telemetry_updated.emit(velocity.length(), global_position.y, flight_state)


func reset_flight(reset_transform: Transform3D) -> void:
  global_transform = reset_transform
  velocity = Vector3.ZERO
  current_speed = cruise_speed
  flight_state = &"CRUISE"
  _pitch = rotation.x
  _yaw = rotation.y
  _pitch_rate = 0.0
  _yaw_rate = 0.0
  _yaw_input = 0.0
  if visual_pivot != null:
    visual_pivot.rotation.z = 0.0


func _update_speed(delta: float) -> void:
  var target_speed := cruise_speed
  var change_rate := acceleration

  if Input.is_action_pressed(&"flight_boost"):
    target_speed = boost_speed
    change_rate = boost_acceleration
    flight_state = &"BOOST"
  elif Input.is_action_pressed(&"flight_decelerate"):
    target_speed = minimum_speed
    change_rate = deceleration
    flight_state = &"DECELERATING"
  elif Input.is_action_pressed(&"flight_accelerate"):
    target_speed = maximum_speed
    change_rate = acceleration
    flight_state = &"ACCELERATING"
  elif current_speed > cruise_speed + 0.1:
    change_rate = deceleration
    flight_state = &"DECELERATING"
  elif current_speed < cruise_speed - 0.1:
    flight_state = &"ACCELERATING"
  else:
    flight_state = &"CRUISE"

  current_speed = move_toward(current_speed, target_speed, change_rate * delta)
  current_speed = clampf(current_speed, minimum_speed, boost_speed)


func _update_steering(delta: float) -> void:
  _yaw_input = Input.get_axis(&"flight_yaw_right", &"flight_yaw_left")
  var pitch_input := Input.get_axis(&"flight_pitch_down", &"flight_pitch_up")
  var speed_ratio := clampf(
    inverse_lerp(minimum_speed, boost_speed, current_speed),
    0.0,
    1.0
  )
  var turn_factor := lerpf(low_speed_turn_factor, high_speed_turn_factor, speed_ratio)
  var target_yaw_rate := deg_to_rad(yaw_speed) * _yaw_input * turn_factor
  var target_pitch_rate := deg_to_rad(pitch_speed) * pitch_input
  var angular_acceleration := deg_to_rad(rotation_smoothing) * delta

  _yaw_rate = move_toward(_yaw_rate, target_yaw_rate, angular_acceleration)
  _pitch_rate = move_toward(_pitch_rate, target_pitch_rate, angular_acceleration)
  _yaw += _yaw_rate * delta
  _pitch = clampf(
    _pitch + _pitch_rate * delta,
    -deg_to_rad(maximum_pitch),
    deg_to_rad(maximum_pitch)
  )
  rotation = Vector3(_pitch, _yaw, 0.0)


func _update_velocity(delta: float) -> void:
  var forward := -global_transform.basis.z.normalized()
  var desired_velocity := forward * current_speed
  velocity = velocity.move_toward(desired_velocity, momentum_response * delta)


func _update_visual_bank(delta: float) -> void:
  if visual_pivot == null:
    return

  var target_bank := deg_to_rad(maximum_bank) * _yaw_input
  visual_pivot.rotation.z = move_toward(
    visual_pivot.rotation.z,
    target_bank,
    deg_to_rad(bank_smoothing) * delta
  )
