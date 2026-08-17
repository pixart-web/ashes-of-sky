extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
  _run.call_deferred()


func _run() -> void:
  var packed_scene := load("res://world/test/flight_test.tscn") as PackedScene
  _assert(packed_scene != null, "The flight test scene loads.")
  if packed_scene == null:
    _finish()
    return

  var flight_test := packed_scene.instantiate()
  var opening_sequence := flight_test.get_node("FirstFlightSequence") as FirstFlightSequence
  opening_sequence.play_opening_on_start = false
  root.add_child(flight_test)
  await _wait_for_physics_frames(2)

  var lunaris := flight_test.get_node("Lunaris") as LunarisFlightController
  _assert(lunaris != null, "The scene contains the Lunaris flight controller.")
  if lunaris == null:
    _finish()
    return

  _assert(_has_physical_key(&"flight_accelerate", KEY_W), "W is bound to accelerate.")
  _assert(_has_physical_key(&"flight_decelerate", KEY_S), "S is bound to decelerate.")
  _assert(_has_physical_key(&"flight_yaw_left", KEY_A), "A is bound to yaw left.")
  _assert(_has_physical_key(&"flight_yaw_right", KEY_D), "D is bound to yaw right.")
  _assert(_has_physical_key(&"flight_pitch_up", KEY_UP), "Up is bound to pitch up.")
  _assert(_has_physical_key(&"flight_pitch_down", KEY_DOWN), "Down is bound to pitch down.")
  _assert(_has_physical_key(&"flight_boost", KEY_SHIFT), "Shift is bound to boost.")
  var gamepad_actions: Array[StringName] = [
    &"flight_accelerate",
    &"flight_decelerate",
    &"flight_yaw_left",
    &"flight_yaw_right",
    &"flight_pitch_up",
    &"flight_pitch_down",
    &"flight_boost",
  ]
  _assert(_all_actions_have_gamepad_events(gamepad_actions), "Flight actions have gamepad bindings.")

  var initial_position := lunaris.global_position
  await _wait_for_physics_frames(12)
  _assert(
    lunaris.global_position.distance_to(initial_position) > 0.5,
    "Lunaris continuously moves forward without input."
  )
  _assert(lunaris.current_speed >= lunaris.minimum_speed, "Minimum flight speed is enforced.")

  Input.action_press(&"flight_accelerate")
  await _wait_for_physics_frames(60)
  Input.action_release(&"flight_accelerate")
  var accelerated_speed := lunaris.current_speed
  _assert(accelerated_speed > lunaris.cruise_speed + 5.0, "Accelerate raises flight speed.")

  Input.action_press(&"flight_boost")
  await _wait_for_physics_frames(60)
  Input.action_release(&"flight_boost")
  var boosted_speed := lunaris.current_speed
  _assert(boosted_speed > lunaris.maximum_speed, "Boost exceeds normal maximum speed.")
  await _wait_for_physics_frames(30)
  _assert(lunaris.current_speed < boosted_speed, "Speed falls naturally after boost release.")

  Input.action_press(&"flight_decelerate")
  await _wait_for_physics_frames(180)
  Input.action_release(&"flight_decelerate")
  _assert(
    is_equal_approx(lunaris.current_speed, lunaris.minimum_speed),
    "Deceleration reaches, but never crosses, minimum speed."
  )

  var visual_pivot := lunaris.get_node("VisualPivot") as Node3D
  var left_wing := visual_pivot.get_node("LeftWing") as MeshInstance3D
  var right_wing := visual_pivot.get_node("RightWing") as MeshInstance3D
  _assert(lunaris.visual_pivot == visual_pivot, "Controller references the visual banking pivot.")
  Input.action_press(&"flight_yaw_left")
  var yaw_before := lunaris.rotation.y
  await _wait_for_physics_frames(30)
  Input.action_release(&"flight_yaw_left")
  var low_speed_yaw_delta := absf(lunaris.rotation.y - yaw_before)
  _assert(low_speed_yaw_delta > 0.1, "Yaw input turns Lunaris.")
  _assert(
    left_wing.global_position.y < right_wing.global_position.y,
    "A left turn lowers the left wing."
  )
  await _wait_for_physics_frames(30)
  _assert(absf(visual_pivot.rotation.z) < 0.02, "Banking returns smoothly to neutral.")

  lunaris.current_speed = lunaris.boost_speed
  lunaris._yaw_rate = 0.0
  Input.action_press(&"flight_yaw_left")
  var high_speed_yaw_before := lunaris.rotation.y
  await _wait_for_physics_frames(30)
  Input.action_release(&"flight_yaw_left")
  var high_speed_yaw_delta := absf(lunaris.rotation.y - high_speed_yaw_before)
  _assert(
    high_speed_yaw_delta < low_speed_yaw_delta,
    "High-speed yaw is wider than low-speed yaw."
  )
  await _wait_for_physics_frames(30)

  var altitude_before := lunaris.global_position.y
  Input.action_press(&"flight_pitch_up")
  await _wait_for_physics_frames(60)
  Input.action_release(&"flight_pitch_up")
  _assert(lunaris.global_position.y > altitude_before + 0.5, "Pitching up produces a climb.")
  Input.action_press(&"flight_pitch_down")
  await _wait_for_physics_frames(120)
  var descent_reference := lunaris.global_position.y
  await _wait_for_physics_frames(60)
  Input.action_release(&"flight_pitch_down")
  _assert(lunaris.rotation.x < -0.2, "Pitch-down input points Lunaris downward.")
  _assert(lunaris.global_position.y < descent_reference, "Pitching down produces a descent.")

  var ground_test_transform := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.6, 0.0))
  _assert(
    lunaris.test_move(ground_test_transform, Vector3.DOWN * 1.0),
    "The Lunaris body detects the ground collision."
  )

  lunaris.global_position = Vector3(0.0, 4.0, 0.0)
  lunaris.velocity = Vector3.ZERO
  lunaris._pitch = -deg_to_rad(lunaris.maximum_pitch)
  lunaris._pitch_rate = 0.0
  lunaris._yaw = 0.0
  lunaris.rotation = Vector3(lunaris._pitch, 0.0, 0.0)
  lunaris.current_speed = lunaris.minimum_speed
  await _wait_for_physics_frames(90)
  _assert(lunaris.global_position.y > 0.0, "move_and_slide prevents flight through the ground.")

  var speed_label := flight_test.get_node(
    "DebugHUD/Panel/Margin/Telemetry/SpeedValue"
  ) as Label
  var altitude_label := flight_test.get_node(
    "DebugHUD/Panel/Margin/Telemetry/AltitudeValue"
  ) as Label
  var state_label := flight_test.get_node(
    "DebugHUD/Panel/Margin/Telemetry/StateValue"
  ) as Label
  _assert("m/s" in speed_label.text, "HUD displays live speed.")
  _assert(" m" in altitude_label.text, "HUD displays live altitude.")
  _assert("BOOTSTRAP" not in state_label.text, "HUD displays a derived flight state.")

  _finish()


func _has_physical_key(action: StringName, physical_keycode: int) -> bool:
  for input_event in InputMap.action_get_events(action):
    if input_event is InputEventKey and input_event.physical_keycode == physical_keycode:
      return true
  return false


func _all_actions_have_gamepad_events(actions: Array[StringName]) -> bool:
  for action in actions:
    var found_gamepad_event := false
    for input_event in InputMap.action_get_events(action):
      if input_event is InputEventJoypadMotion or input_event is InputEventJoypadButton:
        found_gamepad_event = true
        break
    if not found_gamepad_event:
      return false
  return true


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
    print("AOTS-002 flight controller smoke test passed.")
    quit(0)
  else:
    print("AOTS-002 flight controller smoke test failed: %d failure(s)." % _failures.size())
    quit(1)
