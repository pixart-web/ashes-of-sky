class_name LunarisFlightPresentation
extends Node3D

@export_category("References")
@export_node_path("LunarisFlightController") var flight_controller_path: NodePath
@export_node_path("Node3D") var visual_pivot_path: NodePath
@export_node_path("MeshInstance3D") var left_wing_path: NodePath
@export_node_path("MeshInstance3D") var right_wing_path: NodePath
@export_node_path("GPUParticles3D") var speed_particles_path: NodePath
@export_node_path("GPUParticles3D") var boost_trail_particles_path: NodePath
@export_node_path("AudioStreamPlayer3D") var wind_player_path: NodePath

@export_category("Speed Particles")
@export_range(0.0, 1.0, 0.01) var speed_particle_min_ratio: float = 0.08
@export_range(0.0, 1.0, 0.01) var speed_particle_max_ratio: float = 1.0
@export var speed_particle_min_speed_scale: float = 0.65
@export var speed_particle_max_speed_scale: float = 2.4
@export var particle_smoothing: float = 5.0

@export_category("Wind")
@export var wind_min_volume: float = -36.0
@export var wind_max_volume: float = -3.0
@export var wind_min_pitch: float = 0.75
@export var wind_max_pitch: float = 1.25
@export var wind_smoothing: float = 3.5

@export_category("Environmental Influence")
@export var calm_response: float = 4.0
@export_range(0.0, 0.1, 0.005) var calm_particle_ratio: float = 0.015

@export_category("Wing Response")
@export var wing_turn_response: float = 10.0
@export var wing_pitch_response: float = 7.0
@export var wing_boost_compression: float = 8.0
@export var wing_smoothing: float = 7.0

@export_category("Body Motion")
@export var body_bob_amount: float = 0.08
@export var body_bob_speed: float = 1.1
@export var body_pitch_lean: float = 2.5
@export var body_acceleration_lean: float = 2.0
@export var body_motion_smoothing: float = 5.0

@export_category("Boost Presentation")
@export var boost_trail_strength: float = 1.0
@export var boost_response: float = 7.0
@export var boost_pulse_amount: float = 0.012
@export var boost_pulse_speed: float = 2.2

var speed_normalized: float = 0.0
var particle_intensity: float = 0.0
var wind_intensity: float = 0.0
var current_boost_strength: float = 0.0
var environmental_calm_strength: float = 0.0

var flight_controller: LunarisFlightController
var visual_pivot: Node3D
var left_wing: MeshInstance3D
var right_wing: MeshInstance3D
var speed_particles: GPUParticles3D
var boost_trail_particles: GPUParticles3D
var wind_player: AudioStreamPlayer3D

var _visual_base_position: Vector3
var _visual_base_scale: Vector3
var _left_wing_base_rotation: Vector3
var _right_wing_base_rotation: Vector3
var _elapsed_time: float = 0.0
var _previous_speed_normalized: float = 0.0
var _acceleration_response: float = 0.0
var _environmental_calm_target: float = 0.0


func _ready() -> void:
  flight_controller = get_node_or_null(flight_controller_path) as LunarisFlightController
  visual_pivot = get_node_or_null(visual_pivot_path) as Node3D
  left_wing = get_node_or_null(left_wing_path) as MeshInstance3D
  right_wing = get_node_or_null(right_wing_path) as MeshInstance3D
  speed_particles = get_node_or_null(speed_particles_path) as GPUParticles3D
  boost_trail_particles = get_node_or_null(boost_trail_particles_path) as GPUParticles3D
  wind_player = get_node_or_null(wind_player_path) as AudioStreamPlayer3D

  if not _references_are_valid():
    push_error("LunarisFlightPresentation is missing one or more required scene references.")
    set_process(false)
    return

  _visual_base_position = visual_pivot.position
  _visual_base_scale = visual_pivot.scale
  _left_wing_base_rotation = left_wing.rotation
  _right_wing_base_rotation = right_wing.rotation
  speed_normalized = _calculate_speed_normalized()
  _previous_speed_normalized = speed_normalized
  speed_particles.emitting = true
  boost_trail_particles.emitting = false

  if wind_player.stream != null:
    wind_player.play()


func _process(delta: float) -> void:
  if flight_controller == null:
    return

  _elapsed_time += delta
  _update_presentation_values(delta)
  _update_particles()
  _update_wings(delta)
  _update_body_motion(delta)
  _update_wind()


func _update_presentation_values(delta: float) -> void:
  environmental_calm_strength = lerpf(
    environmental_calm_strength,
    _environmental_calm_target,
    _smoothing_weight(calm_response, delta)
  )
  speed_normalized = _calculate_speed_normalized()
  var boost_target := 1.0 if flight_controller.flight_state == &"BOOST" else 0.0
  current_boost_strength = lerpf(
    current_boost_strength,
    boost_target,
    _smoothing_weight(boost_response, delta)
  )

  var target_particle_intensity := lerpf(
    speed_particle_min_ratio,
    speed_particle_max_ratio,
    pow(speed_normalized, 1.35)
  )
  target_particle_intensity = maxf(
    target_particle_intensity,
    current_boost_strength * speed_particle_max_ratio
  )
  target_particle_intensity = lerpf(
    target_particle_intensity,
    calm_particle_ratio,
    environmental_calm_strength
  )
  particle_intensity = lerpf(
    particle_intensity,
    target_particle_intensity,
    _smoothing_weight(particle_smoothing, delta)
  )

  var target_wind_intensity := clampf(
    speed_normalized + current_boost_strength * 0.15,
    0.0,
    1.0
  )
  target_wind_intensity *= 1.0 - environmental_calm_strength
  wind_intensity = lerpf(
    wind_intensity,
    target_wind_intensity,
    _smoothing_weight(wind_smoothing, delta)
  )

  var speed_change := (speed_normalized - _previous_speed_normalized) / maxf(delta, 0.0001)
  _acceleration_response = lerpf(
    _acceleration_response,
    clampf(speed_change, -1.0, 1.0),
    _smoothing_weight(body_motion_smoothing, delta)
  )
  _previous_speed_normalized = speed_normalized


func _update_particles() -> void:
  speed_particles.amount_ratio = clampf(particle_intensity, 0.0, 1.0)
  var particle_speed_scale := lerpf(
    speed_particle_min_speed_scale,
    speed_particle_max_speed_scale,
    speed_normalized
  )
  speed_particles.speed_scale = lerpf(
    particle_speed_scale,
    speed_particle_min_speed_scale * 0.25,
    environmental_calm_strength
  )

  var trail_amount := clampf(
    current_boost_strength * boost_trail_strength,
    0.0,
    1.0
  )
  boost_trail_particles.amount_ratio = trail_amount
  boost_trail_particles.emitting = trail_amount > 0.01


func _update_wings(delta: float) -> void:
  var yaw_input := Input.get_axis(&"flight_yaw_right", &"flight_yaw_left")
  var pitch_input := Input.get_axis(&"flight_pitch_down", &"flight_pitch_up")
  var response_strength := lerpf(0.65, 1.0, speed_normalized)
  var left_target := _left_wing_base_rotation
  var right_target := _right_wing_base_rotation

  left_target.x += deg_to_rad(
    (pitch_input * wing_pitch_response + yaw_input * wing_turn_response) * response_strength
  )
  right_target.x += deg_to_rad(
    (pitch_input * wing_pitch_response - yaw_input * wing_turn_response) * response_strength
  )
  left_target.z += deg_to_rad(wing_boost_compression) * current_boost_strength
  right_target.z -= deg_to_rad(wing_boost_compression) * current_boost_strength

  var weight := _smoothing_weight(wing_smoothing, delta)
  left_wing.rotation = _lerp_rotation(left_wing.rotation, left_target, weight)
  right_wing.rotation = _lerp_rotation(right_wing.rotation, right_target, weight)


func _update_body_motion(delta: float) -> void:
  var bob_scale := lerpf(1.0, 0.55, speed_normalized)
  var bob_offset := sin(_elapsed_time * TAU * body_bob_speed) * body_bob_amount * bob_scale
  var target_position := _visual_base_position + Vector3.UP * bob_offset
  visual_pivot.position = visual_pivot.position.lerp(
    target_position,
    _smoothing_weight(body_motion_smoothing, delta)
  )

  var pitch_input := Input.get_axis(&"flight_pitch_down", &"flight_pitch_up")
  var target_pitch := deg_to_rad(
    pitch_input * body_pitch_lean - _acceleration_response * body_acceleration_lean
  )
  visual_pivot.rotation.x = lerp_angle(
    visual_pivot.rotation.x,
    target_pitch,
    _smoothing_weight(body_motion_smoothing, delta)
  )

  var pulse := (
    sin(_elapsed_time * TAU * boost_pulse_speed)
    * boost_pulse_amount
    * current_boost_strength
  )
  visual_pivot.scale = _visual_base_scale * (1.0 + pulse)


func _update_wind() -> void:
  wind_player.volume_db = lerpf(wind_min_volume, wind_max_volume, wind_intensity)
  wind_player.pitch_scale = lerpf(wind_min_pitch, wind_max_pitch, wind_intensity)


func set_environmental_calm(active: bool) -> void:
  _environmental_calm_target = 1.0 if active else 0.0


func _calculate_speed_normalized() -> float:
  return clampf(
    inverse_lerp(
      flight_controller.minimum_speed,
      flight_controller.boost_speed,
      flight_controller.current_speed
    ),
    0.0,
    1.0
  )


func _references_are_valid() -> bool:
  return (
    flight_controller != null
    and visual_pivot != null
    and left_wing != null
    and right_wing != null
    and speed_particles != null
    and boost_trail_particles != null
    and wind_player != null
  )


func _lerp_rotation(from: Vector3, to: Vector3, weight: float) -> Vector3:
  return Vector3(
    lerp_angle(from.x, to.x, weight),
    lerp_angle(from.y, to.y, weight),
    lerp_angle(from.z, to.z, weight)
  )


func _smoothing_weight(smoothing: float, delta: float) -> float:
  return 1.0 - exp(-maxf(smoothing, 0.0) * delta)
