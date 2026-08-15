extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
  _run.call_deferred()


func _run() -> void:
  var packed_scene := load("res://world/test/flight_test.tscn") as PackedScene
  _assert(packed_scene != null, "The flight test scene loads for camera testing.")
  if packed_scene == null:
    _finish()
    return

  var flight_test := packed_scene.instantiate()
  root.add_child(flight_test)
  await _wait_for_process_frames(4)

  var lunaris := flight_test.get_node("Lunaris") as LunarisFlightController
  var camera_rig := flight_test.get_node("FlightCameraRig") as LunarisFlightCamera
  _assert(lunaris != null, "The existing Lunaris flight controller remains present.")
  _assert(camera_rig != null, "The scene contains the dedicated flight camera rig.")
  if lunaris == null or camera_rig == null:
    _finish()
    return

  var camera := camera_rig.get_node("Camera3D") as Camera3D
  _assert(camera_rig.flight_target == lunaris, "The camera targets Lunaris.")
  _assert(camera_rig.get_parent() == flight_test, "The camera rig does not rigidly inherit Lunaris.")
  _assert(camera.current, "The dedicated chase camera is active.")
  _assert(_has_mouse_event(&"camera_look"), "Mouse look has a mouse binding.")
  _assert(_has_joy_axis(&"camera_look_left", JOY_AXIS_RIGHT_X), "Right stick X looks left.")
  _assert(_has_joy_axis(&"camera_look_right", JOY_AXIS_RIGHT_X), "Right stick X looks right.")
  _assert(_has_joy_axis(&"camera_look_up", JOY_AXIS_RIGHT_Y), "Right stick Y looks up.")
  _assert(_has_joy_axis(&"camera_look_down", JOY_AXIS_RIGHT_Y), "Right stick Y looks down.")
  _assert(_has_physical_key(&"camera_recenter", KEY_C), "C is bound to camera recenter.")
  _assert(_has_joy_button(&"camera_recenter", JOY_BUTTON_RIGHT_STICK), "R3 recenters the camera.")

  lunaris.global_position += Vector3(20.0, 0.0, 0.0)
  await process_frame
  var follow_anchor := lunaris.global_position + Vector3.UP * camera_rig.base_height
  var initial_follow_error := camera_rig.global_position.distance_to(follow_anchor)
  _assert(initial_follow_error > 0.5, "Position following has visible lag.")
  await _wait_for_process_frames(120)
  follow_anchor = lunaris.global_position + Vector3.UP * camera_rig.base_height
  _assert(
    camera_rig.global_position.distance_to(follow_anchor) < initial_follow_error,
    "The camera smoothly catches up to Lunaris."
  )

  lunaris._yaw_rate = 0.0
  lunaris._yaw += deg_to_rad(90.0)
  lunaris.rotation = Vector3(lunaris._pitch, lunaris._yaw, 0.0)
  await process_frame
  var desired_rotation := camera_rig._desired_camera_basis().get_rotation_quaternion()
  var initial_rotation_error := camera_rig.global_basis.get_rotation_quaternion().angle_to(
    desired_rotation
  )
  _assert(initial_rotation_error > 0.05, "Turns produce camera rotation lag.")
  await _wait_for_process_frames(120)
  desired_rotation = camera_rig._desired_camera_basis().get_rotation_quaternion()
  _assert(
    camera_rig.global_basis.get_rotation_quaternion().angle_to(desired_rotation)
      < initial_rotation_error,
    "Camera rotation recentres smoothly after a turn."
  )

  var neutral_look_forward := -camera_rig._desired_camera_basis().z.normalized()
  Input.action_press(&"flight_yaw_left")
  var anticipated_look_forward := -camera_rig._desired_camera_basis().z.normalized()
  Input.action_release(&"flight_yaw_left")
  _assert(
    neutral_look_forward.angle_to(anticipated_look_forward) > 0.01,
    "Yaw intent influences camera look-ahead framing."
  )

  Input.action_press(&"flight_yaw_left")
  await _wait_for_process_frames(30)
  Input.action_release(&"flight_yaw_left")
  var visual_bank := lunaris.visual_pivot.rotation.z
  _assert(absf(camera_rig.target_bank) > 0.01, "Turning gives the camera subtle roll influence.")
  _assert(
    absf(camera_rig.target_bank) <= absf(visual_bank) * 0.2,
    "Camera inherits no more than twenty percent of visual banking."
  )
  await _wait_for_process_frames(30)

  Input.action_press(&"flight_decelerate")
  lunaris.current_speed = lunaris.minimum_speed
  await _wait_for_process_frames(60)
  var low_speed_fov := camera.fov
  var low_speed_distance := camera_rig.target_distance
  Input.action_press(&"flight_boost")
  await _wait_for_process_frames(90)
  var boosted_fov := camera.fov
  var boosted_distance := camera_rig.target_distance
  _assert(boosted_fov > low_speed_fov + 5.0, "Boost noticeably increases FOV.")
  _assert(boosted_distance > low_speed_distance + 2.0, "Boost moves the camera backward.")
  Input.action_release(&"flight_boost")
  await _wait_for_process_frames(180)
  _assert(camera.fov < boosted_fov, "FOV returns smoothly after boost.")
  _assert(camera_rig.target_distance < boosted_distance, "Camera distance returns after boost.")
  Input.action_release(&"flight_decelerate")

  lunaris._yaw_rate = 0.0
  var flight_yaw_before_manual_look := lunaris.rotation.y
  Input.action_press(&"camera_look_right")
  await _wait_for_process_frames(30)
  Input.action_release(&"camera_look_right")
  var manual_offset := absf(camera_rig.manual_yaw_offset)
  _assert(manual_offset > 0.1, "Right stick input rotates the camera manually.")
  _assert(
    absf(lunaris.rotation.y - flight_yaw_before_manual_look) < 0.02,
    "Manual camera look does not change flight direction."
  )
  await _wait_for_process_frames(180)
  _assert(absf(camera_rig.manual_yaw_offset) < 0.02, "Manual look recentres after its delay.")

  Input.action_press(&"camera_look_left")
  await _wait_for_process_frames(20)
  Input.action_release(&"camera_look_left")
  var offset_before_recenter := absf(camera_rig.manual_yaw_offset)
  Input.action_press(&"camera_recenter")
  await process_frame
  Input.action_release(&"camera_recenter")
  await _wait_for_process_frames(30)
  _assert(
    absf(camera_rig.manual_yaw_offset) < offset_before_recenter,
    "Recenter input smoothly returns the camera without snapping."
  )

  await _wait_for_process_frames(90)
  var obstacle := StaticBody3D.new()
  var obstacle_shape := CollisionShape3D.new()
  var box_shape := BoxShape3D.new()
  box_shape.size = Vector3(20.0, 20.0, 1.0)
  obstacle_shape.shape = box_shape
  obstacle.add_child(obstacle_shape)
  flight_test.add_child(obstacle)
  obstacle.global_transform = Transform3D(
    camera_rig.global_basis,
    camera_rig.global_position + camera_rig.global_basis.z.normalized() * 4.0
  )
  await _wait_for_physics_frames(20)
  var obstructed_distance := camera_rig.current_distance
  _assert(
    obstructed_distance < camera_rig.target_distance - 1.0,
    "Camera collision moves the camera closer to Lunaris."
  )
  obstacle.queue_free()
  await _wait_for_physics_frames(2)
  await _wait_for_process_frames(120)
  _assert(
    camera_rig.current_distance > obstructed_distance + 1.0,
    "Camera distance recovers smoothly after an obstacle clears."
  )

  _finish()


func _has_mouse_event(action: StringName) -> bool:
  for input_event in InputMap.action_get_events(action):
    if input_event is InputEventMouseButton:
      return true
  return false


func _has_joy_axis(action: StringName, axis: JoyAxis) -> bool:
  for input_event in InputMap.action_get_events(action):
    if input_event is InputEventJoypadMotion and input_event.axis == axis:
      return true
  return false


func _has_physical_key(action: StringName, physical_keycode: int) -> bool:
  for input_event in InputMap.action_get_events(action):
    if input_event is InputEventKey and input_event.physical_keycode == physical_keycode:
      return true
  return false


func _has_joy_button(action: StringName, button: JoyButton) -> bool:
  for input_event in InputMap.action_get_events(action):
    if input_event is InputEventJoypadButton and input_event.button_index == button:
      return true
  return false


func _wait_for_process_frames(count: int) -> void:
  for _frame in range(count):
    await physics_frame


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
    &"flight_yaw_left",
    &"flight_boost",
    &"flight_decelerate",
    &"camera_look_left",
    &"camera_look_right",
    &"camera_recenter",
  ]:
    Input.action_release(action)

  if _failures.is_empty():
    print("AOTS-003 flight camera smoke test passed.")
    quit(0)
  else:
    print("AOTS-003 flight camera smoke test failed: %d failure(s)." % _failures.size())
    quit(1)
