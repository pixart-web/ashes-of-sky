extends SceneTree

var _failures: Array[String] = []
var _visited_states: Array[int] = []
var _audio_events: Array[StringName] = []
var _discovery_count_at_handoff: int = -1


func _initialize() -> void:
  _run.call_deferred()


func _run() -> void:
  var packed_scene := load("res://world/test/flight_test.tscn") as PackedScene
  _assert(packed_scene != null, "The AOTS-007 opening scene loads.")
  if packed_scene == null:
    _finish()
    return

  await _test_complete_opening(packed_scene)
  await _test_skip_from_state(packed_scene, FirstFlightSequence.OpeningState.INTRO)
  await _test_skip_from_state(packed_scene, FirstFlightSequence.OpeningState.RUN)
  await _test_skip_from_state(packed_scene, FirstFlightSequence.OpeningState.FREEFALL)
  await _test_direct_development_start(packed_scene)
  _finish()


func _test_complete_opening(packed_scene: PackedScene) -> void:
  _visited_states.clear()
  _audio_events.clear()
  _discovery_count_at_handoff = -1
  var flight_test := packed_scene.instantiate()
  var sequence := flight_test.get_node("FirstFlightSequence") as FirstFlightSequence
  var manager := flight_test.get_node("DiscoveryManager") as DiscoveryManager
  var discovery_ui := flight_test.get_node("DiscoveryUI") as DiscoveryUI
  var opening_ui := flight_test.get_node("FirstFlightUI") as FirstFlightUI
  var lunaris := flight_test.get_node("Lunaris") as LunarisFlightController
  var camera_rig := flight_test.get_node("FlightCameraRig") as LunarisFlightCamera
  var debug_hud := flight_test.get_node("DebugHUD") as CanvasLayer
  sequence.timeline_speed_multiplier = 20.0
  sequence.show_timeline_debug = true
  sequence.opening_state_changed.connect(func(opening_state: FirstFlightSequence.OpeningState) -> void:
    _visited_states.append(opening_state)
  )
  sequence.audio_event_requested.connect(func(event_name: StringName) -> void:
    _audio_events.append(event_name)
  )
  sequence.player_control_granted.connect(func() -> void:
    _discovery_count_at_handoff = manager.get_discovered_count()
  )
  root.add_child(flight_test)
  await process_frame

  _assert(sequence.get_scripted_handoff_time() >= 30.0, "Default opening reaches control after at least thirty seconds.")
  _assert(sequence.get_scripted_handoff_time() <= 38.0, "Default opening hands off within the intended window.")
  _assert(sequence.state == FirstFlightSequence.OpeningState.INTRO, "The game begins in the INTRO state.")
  _assert(opening_ui.black_overlay.visible, "The game begins on black.")
  _assert(opening_ui.black_overlay.modulate.a > 0.95, "Opening black is fully opaque.")
  _assert(opening_ui.location_text.text == "E L Y N D R A", "Opening identifies Elyndra without exposition.")
  _assert("4,217 YEARS AFTER THE SILENCE" in opening_ui.era_text.text, "Opening establishes the era after the Silence.")
  _assert(not debug_hud.visible, "Debug HUD is hidden during the opening.")
  _assert(not lunaris.player_input_enabled, "Normal flight input is locked during the cinematic.")
  _assert(not manager.discovery_enabled, "Discovery registration is suppressed during the cinematic.")
  _assert(not discovery_ui.exploration_input_enabled, "Journal and interaction are locked during the cinematic.")
  discovery_ui.open_journal()
  _assert(not discovery_ui.is_journal_open(), "Journal cannot be opened during the cinematic.")
  _assert(lunaris.has_node("VisualPivot/RiderPlaceholder"), "A modular rider silhouette is mounted on Lunaris.")
  _assert(InputMap.has_action(&"skip_opening"), "Opening skip uses a semantic input action.")
  _assert(_has_physical_key(&"skip_opening", KEY_ENTER), "Enter skips the opening.")
  _assert(_has_gamepad_event(&"skip_opening"), "Opening skip has a gamepad binding.")

  var minimum_altitude := lunaris.global_position.y
  var maximum_fold_distance := 0.0
  var frames := 0
  while sequence.state != FirstFlightSequence.OpeningState.GAMEPLAY and frames < 600:
    minimum_altitude = minf(minimum_altitude, lunaris.global_position.y)
    maximum_fold_distance = maxf(
      maximum_fold_distance,
      lunaris.get_node("VisualPivot/LeftWing").rotation.distance_to(
        sequence._left_wing_base_rotation
      )
    )
    await process_frame
    frames += 1

  _assert(sequence.state == FirstFlightSequence.OpeningState.GAMEPLAY, "Complete opening reaches gameplay.")
  for expected_state in FirstFlightSequence.OpeningState.values():
    _assert(expected_state in _visited_states, "%s state is visited." % FirstFlightSequence.OpeningState.keys()[expected_state])
  _assert(minimum_altitude < sequence.opening_start_position.y - 60.0, "Freefall creates a substantial altitude drop.")
  _assert(maximum_fold_distance > 0.7, "Wings are visibly folded before deployment.")
  _assert(
    lunaris.get_node("VisualPivot/LeftWing").rotation.distance_to(sequence._left_wing_base_rotation) < 0.03,
    "Wings are fully deployed at handoff."
  )
  _assert(sequence.player_has_control, "Player control is granted without loading another scene.")
  _assert(lunaris.player_input_enabled, "Normal flight input is restored at handoff.")
  _assert(lunaris.velocity.length() >= 20.0, "Lunaris retains meaningful forward momentum.")
  _assert(camera_rig.is_processing(), "Normal chase camera processing resumes.")
  _assert(sequence.camera_handoff_snap_distance < 2.0, "Camera handoff occurs without a visible positional cut.")
  _assert(manager.discovery_enabled, "Discovery system activates at handoff.")
  _assert(discovery_ui.exploration_input_enabled, "Journal and interaction activate at handoff.")
  _assert(_discovery_count_at_handoff == 0, "Scripted movement does not register discoveries.")
  _assert(not paused, "Gameplay handoff does not leave the tree paused.")
  _assert(&"ambient_wind" in _audio_events, "Ambient wind audio hook fires.")
  _assert(&"wing_deployment" in _audio_events, "Wing deployment audio hook fires.")

  var title_wait_frames := 0
  while not opening_ui.title_reveal_started and title_wait_frames < 180:
    await process_frame
    title_wait_frames += 1
  _assert(debug_hud.visible, "Prototype HUD returns after the configured delay.")
  _assert(opening_ui.title_reveal_started, "Title reveal begins while gameplay continues.")
  _assert(&"title_reveal" in _audio_events, "Title reveal audio hook fires.")
  _assert(not paused, "Title presentation does not stop flight.")

  discovery_ui.open_journal()
  _assert(discovery_ui.is_journal_open(), "Journal works normally after handoff.")
  discovery_ui.close_journal()
  _assert(not paused, "Closing post-handoff Journal resumes flight.")

  lunaris.global_position = Vector3(1300, 100, 0)
  await _wait_for_physics_frames(3)
  _assert(
    lunaris.global_position.distance_to(ValleyOfAsh.SPAWN_POSITION) < 6.0,
    "Out-of-bounds recovery remains functional after handoff."
  )
  await _remove_scene(flight_test)


func _test_skip_from_state(
  packed_scene: PackedScene,
  target_state: FirstFlightSequence.OpeningState
) -> void:
  var flight_test := packed_scene.instantiate()
  var sequence := flight_test.get_node("FirstFlightSequence") as FirstFlightSequence
  var lunaris := flight_test.get_node("Lunaris") as LunarisFlightController
  var camera_rig := flight_test.get_node("FlightCameraRig") as LunarisFlightCamera
  var manager := flight_test.get_node("DiscoveryManager") as DiscoveryManager
  var discovery_ui := flight_test.get_node("DiscoveryUI") as DiscoveryUI
  var debug_hud := flight_test.get_node("DebugHUD") as CanvasLayer
  sequence.timeline_speed_multiplier = 25.0
  root.add_child(flight_test)
  await process_frame

  if target_state != FirstFlightSequence.OpeningState.INTRO:
    var reached_state := await _wait_for_state(sequence, target_state, 400)
    _assert(reached_state, "Skip test reaches %s." % FirstFlightSequence.OpeningState.keys()[target_state])
  sequence.skip_to_gameplay()
  await process_frame

  _assert(sequence.state == FirstFlightSequence.OpeningState.GAMEPLAY, "Skip from %s reaches gameplay." % FirstFlightSequence.OpeningState.keys()[target_state])
  _assert(lunaris.global_position.distance_to(sequence.skip_handoff_position) < 2.0, "Skip uses the safe gameplay handoff position.")
  _assert(lunaris.velocity.length() >= 20.0, "Skip restores safe forward velocity.")
  _assert(lunaris.player_input_enabled, "Skip restores flight input.")
  _assert(camera_rig.is_processing(), "Skip restores chase camera processing.")
  _assert(manager.discovery_enabled, "Skip restores discovery registration.")
  _assert(discovery_ui.exploration_input_enabled, "Skip restores Journal and interaction.")
  _assert(debug_hud.visible, "Skip restores the prototype HUD immediately.")
  await _remove_scene(flight_test)


func _test_direct_development_start(packed_scene: PackedScene) -> void:
  var flight_test := packed_scene.instantiate()
  var sequence := flight_test.get_node("FirstFlightSequence") as FirstFlightSequence
  sequence.play_opening_on_start = false
  var lunaris := flight_test.get_node("Lunaris") as LunarisFlightController
  var manager := flight_test.get_node("DiscoveryManager") as DiscoveryManager
  var discovery_ui := flight_test.get_node("DiscoveryUI") as DiscoveryUI
  var debug_hud := flight_test.get_node("DebugHUD") as CanvasLayer
  var opening_ui := flight_test.get_node("FirstFlightUI") as FirstFlightUI
  root.add_child(flight_test)
  await _wait_for_physics_frames(4)

  _assert(sequence.state == FirstFlightSequence.OpeningState.GAMEPLAY, "Development fast start enters gameplay directly.")
  _assert(sequence.player_has_control, "Development fast start preserves player control.")
  _assert(lunaris.player_input_enabled, "Development fast start keeps flight input enabled.")
  _assert(manager.discovery_enabled, "Development fast start keeps discovery enabled.")
  _assert(discovery_ui.exploration_input_enabled, "Development fast start keeps Journal enabled.")
  _assert(debug_hud.visible, "Development fast start keeps prototype HUD visible.")
  _assert(not opening_ui.black_overlay.visible, "Development fast start has no opening black screen.")
  _assert(not opening_ui.title_reveal_started, "Development fast start does not replay the title.")
  await _remove_scene(flight_test)


func _wait_for_state(
  sequence: FirstFlightSequence,
  target_state: FirstFlightSequence.OpeningState,
  maximum_frames: int
) -> bool:
  for _frame in range(maximum_frames):
    if sequence.state == target_state:
      return true
    await process_frame
  return false


func _remove_scene(scene: Node) -> void:
  paused = false
  scene.queue_free()
  await process_frame
  await process_frame


func _has_physical_key(action: StringName, physical_keycode: int) -> bool:
  for input_event in InputMap.action_get_events(action):
    if input_event is InputEventKey and input_event.physical_keycode == physical_keycode:
      return true
  return false


func _has_gamepad_event(action: StringName) -> bool:
  for input_event in InputMap.action_get_events(action):
    if input_event is InputEventJoypadButton or input_event is InputEventJoypadMotion:
      return true
  return false


func _wait_for_process_frames(count: int) -> void:
  for _frame in range(count):
    await process_frame


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
  paused = false
  Input.action_release(&"skip_opening")
  if _failures.is_empty():
    print("AOTS-007 First Flight sequence smoke test passed.")
    quit(0)
  else:
    print("AOTS-007 First Flight sequence smoke test failed: %d failure(s)." % _failures.size())
    quit(1)
