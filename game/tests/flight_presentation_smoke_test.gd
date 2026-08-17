extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
  _run.call_deferred()


func _run() -> void:
  var packed_scene := load("res://world/test/flight_test.tscn") as PackedScene
  _assert(packed_scene != null, "The flight test scene loads for presentation testing.")
  if packed_scene == null:
    _finish()
    return

  var flight_test := packed_scene.instantiate()
  var opening_sequence := flight_test.get_node("FirstFlightSequence") as FirstFlightSequence
  opening_sequence.play_opening_on_start = false
  root.add_child(flight_test)
  await _wait_for_physics_frames(4)

  var lunaris := flight_test.get_node("Lunaris") as LunarisFlightController
  var presentation := flight_test.get_node(
    "Lunaris/Presentation"
  ) as LunarisFlightPresentation
  _assert(lunaris != null, "The AOTS-002 flight controller remains present.")
  _assert(presentation != null, "Lunaris has a dedicated presentation controller.")
  if lunaris == null or presentation == null:
    _finish()
    return

  var visual_pivot := lunaris.get_node("VisualPivot") as Node3D
  var left_wing := visual_pivot.get_node("LeftWing") as MeshInstance3D
  var right_wing := visual_pivot.get_node("RightWing") as MeshInstance3D
  var collision_shape := lunaris.get_node("CollisionShape3D") as CollisionShape3D
  var speed_particles := presentation.get_node("SpeedParticles") as GPUParticles3D
  var boost_trail := presentation.get_node("BoostTrailParticles") as GPUParticles3D
  var wind_player := lunaris.get_node("Audio/WindPlayer") as AudioStreamPlayer3D

  _assert(presentation.flight_controller == lunaris, "Presentation reads the existing controller.")
  _assert(presentation.get_parent() == lunaris, "Presentation is separate from movement logic.")
  _assert(speed_particles.amount == 96, "Speed particle budget remains lightweight.")
  _assert(boost_trail.amount == 36, "Boost trail particle budget remains lightweight.")
  _assert(wind_player.stream == null, "Wind channel uses no unapproved external audio asset.")
  _assert(
    flight_test.get_node("ValleyOfAsh/Terrain/SpeedMarkers").get_child_count() == 4,
    "Environment has four speed-reference markers."
  )

  Input.action_press(&"flight_decelerate")
  lunaris.current_speed = lunaris.minimum_speed
  await _wait_for_physics_frames(60)
  var minimum_particle_intensity := presentation.particle_intensity
  var minimum_wind_intensity := presentation.wind_intensity
  var minimum_particle_speed := speed_particles.speed_scale
  _assert(presentation.speed_normalized < 0.01, "Minimum speed normalizes to zero.")
  _assert(minimum_particle_intensity < 0.2, "Minimum speed particles remain subtle.")
  _assert(not boost_trail.emitting, "Boost trail is disabled outside boost.")

  Input.action_release(&"flight_decelerate")
  lunaris.current_speed = lunaris.cruise_speed
  await _wait_for_physics_frames(90)
  var cruise_particle_intensity := presentation.particle_intensity
  _assert(
    cruise_particle_intensity > minimum_particle_intensity,
    "Cruise increases particle feedback over minimum speed."
  )
  _assert(presentation.wind_intensity > minimum_wind_intensity, "Cruise increases wind intensity.")

  Input.action_press(&"flight_accelerate")
  lunaris.current_speed = lunaris.maximum_speed
  await _wait_for_physics_frames(90)
  var maximum_particle_intensity := presentation.particle_intensity
  var maximum_wind_intensity := presentation.wind_intensity
  _assert(maximum_particle_intensity > cruise_particle_intensity, "Maximum speed is visually denser than cruise.")
  _assert(speed_particles.speed_scale > minimum_particle_speed, "Particles move faster at high speed.")
  Input.action_release(&"flight_accelerate")

  var left_wing_before_boost := left_wing.rotation
  var right_wing_before_boost := right_wing.rotation
  Input.action_press(&"flight_boost")
  Input.action_press(&"flight_yaw_left")
  Input.action_press(&"flight_pitch_up")
  await _wait_for_physics_frames(90)
  _assert(presentation.speed_normalized > 0.99, "Boost speed normalizes to one.")
  _assert(presentation.particle_intensity > maximum_particle_intensity, "Boost produces strongest particle feedback.")
  _assert(presentation.wind_intensity >= maximum_wind_intensity, "Boost produces strongest wind intensity.")
  _assert(boost_trail.emitting, "Boost enables the organic trail.")
  _assert(boost_trail.amount_ratio > 0.8, "Boost trail reaches a clearly visible intensity.")
  _assert(left_wing.rotation.distance_to(left_wing_before_boost) > 0.05, "Left wing reacts during turning boost.")
  _assert(right_wing.rotation.distance_to(right_wing_before_boost) > 0.05, "Right wing reacts during turning boost.")
  _assert(absf(visual_pivot.rotation.x) > 0.01, "Body visually leans with pitch/acceleration.")
  var minimum_bob_height := visual_pivot.position.y
  var maximum_bob_height := visual_pivot.position.y
  for _sample in range(30):
    await physics_frame
    minimum_bob_height = minf(minimum_bob_height, visual_pivot.position.y)
    maximum_bob_height = maxf(maximum_bob_height, visual_pivot.position.y)
  _assert(maximum_bob_height - minimum_bob_height > 0.005, "Body has subtle procedural bobbing.")
  _assert(collision_shape.position.is_zero_approx(), "Presentation does not move the collision shape.")
  _assert(collision_shape.scale.is_equal_approx(Vector3.ONE), "Presentation does not scale collision geometry.")

  Input.action_release(&"flight_yaw_left")
  Input.action_release(&"flight_pitch_up")
  Input.action_release(&"flight_boost")
  await _wait_for_physics_frames(180)
  _assert(not boost_trail.emitting, "Boost trail switches off smoothly after boost.")
  _assert(presentation.current_boost_strength < 0.01, "Boost presentation returns to neutral.")
  _assert(left_wing.rotation.distance_to(presentation._left_wing_base_rotation) < 0.02, "Left wing returns smoothly to neutral.")
  _assert(right_wing.rotation.distance_to(presentation._right_wing_base_rotation) < 0.02, "Right wing returns smoothly to neutral.")

  for _transition in range(3):
    Input.action_press(&"flight_boost")
    await _wait_for_physics_frames(30)
    _assert(presentation.current_boost_strength > 0.8, "Repeated boost transition activates presentation.")
    Input.action_release(&"flight_boost")
    await _wait_for_physics_frames(45)
    _assert(presentation.current_boost_strength < 0.1, "Repeated boost transition settles cleanly.")

  Input.action_press(&"flight_boost")
  await _wait_for_physics_frames(300)
  _assert(presentation.speed_normalized > 0.99, "Long boost presentation remains stable.")
  _assert(speed_particles.amount_ratio <= 1.0, "Particle intensity remains within its safe range.")
  _assert(wind_player.volume_db <= presentation.wind_max_volume, "Wind volume remains clamped to its tuning range.")
  Input.action_release(&"flight_boost")

  _finish()


func _wait_for_physics_frames(count: int) -> void:
  for _frame in range(count):
    await physics_frame


func _assert(condition: bool, message: String) -> void:
  if condition:
    print("PASS: %s" % message)
  else:
    _failures.append(message)
    push_error("FAIL: %s" % message)


func _finish() -> void:
  for action in [
    &"flight_accelerate",
    &"flight_decelerate",
    &"flight_boost",
    &"flight_yaw_left",
    &"flight_pitch_up",
  ]:
    Input.action_release(action)

  if _failures.is_empty():
    print("AOTS-004 flight presentation smoke test passed.")
    quit(0)
  else:
    print("AOTS-004 flight presentation smoke test failed: %d failure(s)." % _failures.size())
    quit(1)
