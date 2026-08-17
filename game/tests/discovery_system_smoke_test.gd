extends SceneTree

var _failures: Array[String] = []
var _registration_signal_count: int = 0
var _reset_signal_count: int = 0


func _initialize() -> void:
  _run.call_deferred()


func _run() -> void:
  var packed_scene := load("res://world/test/flight_test.tscn") as PackedScene
  _assert(packed_scene != null, "The AOTS-006 flight scene loads.")
  if packed_scene == null:
    _finish()
    return

  var flight_test := packed_scene.instantiate()
  var opening_sequence := flight_test.get_node("FirstFlightSequence") as FirstFlightSequence
  opening_sequence.play_opening_on_start = false
  root.add_child(flight_test)
  await _wait_for_physics_frames(5)

  var manager := flight_test.get_node("DiscoveryManager") as DiscoveryManager
  var discovery_layer := flight_test.get_node("WorldDiscovery") as ValleyDiscoveryLayer
  var discovery_ui := flight_test.get_node("DiscoveryUI") as DiscoveryUI
  var lunaris := flight_test.get_node("Lunaris") as LunarisFlightController
  _assert(manager != null, "A reusable DiscoveryManager exists.")
  _assert(discovery_layer != null, "The Valley has a separate discovery layer.")
  _assert(discovery_ui != null, "Discovery feedback and Journal UI exist.")
  _assert(lunaris != null, "The existing flight player remains present.")
  if manager == null or discovery_layer == null or discovery_ui == null or lunaris == null:
    _finish()
    return

  manager.discovery_registered.connect(_on_discovery_registered)
  manager.discoveries_reset.connect(_on_discoveries_reset)

  _assert(manager.get_definition_count() == 11, "Eleven data-driven discoveries are registered.")
  _assert(discovery_layer.get_node("Regions").get_child_count() == 4, "Four region discovery volumes exist.")
  _assert(discovery_layer.get_node("Landmarks").get_child_count() == 4, "Four landmark discovery volumes exist.")
  _assert(discovery_layer.has_node("LostPlaces/SilentChamber"), "Silent Chamber has an interior discovery volume.")
  _assert(discovery_layer.has_node("Echoes/LastSignal"), "The Last Signal interaction exists.")
  _assert(discovery_layer.has_node("Anomalies/StillWind"), "The Still Wind anomaly exists off the main route.")

  _assert(InputMap.has_action(&"open_journal"), "The Journal uses a semantic input action.")
  _assert(_has_physical_key(&"open_journal", KEY_J), "J opens the Journal.")
  _assert(_has_gamepad_event(&"open_journal"), "The Journal has a gamepad binding.")
  _assert(InputMap.has_action(&"reset_discoveries"), "A development discovery-reset action exists.")
  _assert(_has_physical_key(&"reset_discoveries", KEY_F8), "F8 resets discoveries for development testing.")

  var central_canyon := manager.get_definition(&"region_central_canyon")
  var spire := manager.get_definition(&"landmark_spire")
  var silent_chamber := manager.get_definition(&"lostplace_silent_chamber")
  var last_signal := manager.get_definition(&"echo_last_signal")
  var still_wind_data := manager.get_definition(&"anomaly_still_wind")
  _assert(central_canyon.category == DiscoveryData.Category.REGION, "Region category is stored in discovery data.")
  _assert(spire.category == DiscoveryData.Category.LANDMARK, "Landmark category is stored in discovery data.")
  _assert(silent_chamber.category == DiscoveryData.Category.LOST_PLACE, "Lost Place category is supported.")
  _assert(last_signal.category == DiscoveryData.Category.ECHO, "Echo category is supported.")
  _assert(still_wind_data.category == DiscoveryData.Category.ANOMALY, "Anomaly category is supported.")
  _assert("initiate Silence" in last_signal.recovered_text, "The Last Signal contains the approved mystery lore.")

  lunaris.reset_flight(Transform3D(Basis.IDENTITY, Vector3(-470, 75, 225)))
  await _wait_for_physics_frames(4)
  _assert(manager.is_discovered(&"region_ash_basin"), "Spatial Area3D entry automatically registers a region discovery.")
  manager.reset_discoveries()
  lunaris.reset_flight(Transform3D(Basis.IDENTITY, ValleyOfAsh.SPAWN_POSITION))
  _registration_signal_count = 0
  _reset_signal_count = 0

  _assert(manager.discover(&"region_central_canyon"), "A first discovery is registered.")
  _assert(not manager.discover(&"region_central_canyon"), "A duplicate discovery is rejected.")
  _assert(_registration_signal_count == 1, "Duplicate discovery does not repeat full presentation.")
  _assert(manager.get_discovered_count() == 1, "Journal state stores one unique discovery.")
  _assert(manager.get_discovered_entries(DiscoveryData.Category.REGION).size() == 1, "Journal can filter discovered regions.")

  var movement_before_journal := lunaris.global_position
  discovery_ui.open_journal()
  _assert(discovery_ui.is_journal_open(), "Exploration Journal opens.")
  _assert(paused, "Opening the Journal pauses gameplay.")
  _assert("CENTRAL CANYON" in discovery_ui.journal_text.text, "Journal shows discovered content.")
  _assert("THE SPIRE" not in discovery_ui.journal_text.text, "Journal hides undiscovered content.")
  await _wait_for_physics_frames(20)
  _assert(lunaris.global_position.distance_to(movement_before_journal) < 0.01, "Lunaris remains safely suspended while Journal is open.")
  discovery_ui.close_journal()
  _assert(not paused, "Closing the Journal restores gameplay.")
  await _wait_for_physics_frames(30)
  _assert(lunaris.global_position.distance_to(movement_before_journal) > 0.5, "Flight resumes after closing the Journal.")

  var snapshot := manager.create_persistence_snapshot()
  manager.reset_discoveries()
  _assert(manager.get_discovered_count() == 0, "Developer reset clears session discoveries.")
  _assert(_reset_signal_count == 1, "Discovery reset emits a development event.")
  manager.restore_persistence_snapshot(snapshot)
  _assert(manager.is_discovered(&"region_central_canyon"), "Stable IDs support save-ready restoration.")

  var echo_point := discovery_layer.get_node("Echoes/LastSignal") as DiscoveryPoint
  _assert(echo_point.requires_interaction, "Echoes require deliberate interaction.")
  _assert(not manager.activate_current_interaction(), "Echo cannot activate outside interaction range.")
  echo_point._on_body_entered(lunaris)
  await process_frame
  _assert(discovery_ui.interaction_hint.visible, "Interaction hint appears inside Echo range.")
  _assert(not manager.is_discovered(&"echo_last_signal"), "Approaching an Echo does not auto-discover it.")
  _assert(manager.activate_current_interaction(), "The semantic interaction activates the Echo.")
  _assert(manager.is_discovered(&"echo_last_signal"), "Activated Echo is registered in the Journal.")
  _assert(discovery_ui.is_echo_open(), "The Last Signal presentation opens.")
  _assert(paused, "Echo reading safely suspends flight.")
  _assert("Do not wait for us." in discovery_ui.echo_text.text, "The complete Echo text is readable.")
  discovery_ui.close_echo()
  _assert(not paused, "Closing the Echo restores gameplay.")
  _assert(discovery_ui.interaction_hint.visible, "Interaction prompt returns while still in range.")
  echo_point._on_body_exited(lunaris)
  _assert(not discovery_ui.interaction_hint.visible, "Interaction prompt clears after leaving range.")

  discovery_ui.open_journal()
  _assert("THE LAST SIGNAL" in discovery_ui.journal_text.text, "Recovered Echo appears in the Journal.")
  _assert("ARCHITECT RECORD // PARTIAL RECOVERY" in discovery_ui.journal_text.text, "Journal retains recovered Echo text.")
  discovery_ui.close_journal()

  var presentation := lunaris.get_node("Presentation") as LunarisFlightPresentation
  var still_wind := discovery_layer.get_node("Anomalies/StillWind") as StillWindAnomaly
  lunaris.current_speed = lunaris.maximum_speed
  still_wind._on_body_entered(lunaris)
  await _wait_for_process_frames(180)
  _assert(manager.is_discovered(&"anomaly_still_wind"), "The Still Wind registers as an Anomaly.")
  _assert(presentation.environmental_calm_strength > 0.9, "The Still Wind creates unnatural presentation calm.")
  _assert(presentation.particle_intensity < 0.06, "Speed particles become extremely subtle inside the anomaly.")
  still_wind._on_body_exited(lunaris)
  await _wait_for_process_frames(90)
  _assert(presentation.environmental_calm_strength < 0.1, "Flight presentation recovers after leaving the anomaly.")

  _assert(not flight_test.has_node("Minimap"), "No minimap was introduced.")
  _assert(not flight_test.has_node("ObjectiveMarker"), "No objective marker was introduced.")
  _assert(not InputMap.has_action(&"award_xp"), "No XP input or reward system was introduced.")

  _finish()


func _on_discovery_registered(_data: DiscoveryData) -> void:
  _registration_signal_count += 1


func _on_discoveries_reset() -> void:
  _reset_signal_count += 1


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


func _wait_for_physics_frames(count: int) -> void:
  for _frame in range(count):
    await physics_frame


func _wait_for_process_frames(count: int) -> void:
  for _frame in range(count):
    await process_frame


func _assert(condition: bool, message: String) -> void:
  if condition:
    print("PASS: %s" % message)
  else:
    _failures.append(message)
    push_error("FAIL: %s" % message)


func _finish() -> void:
  paused = false
  for action in [&"open_journal", &"interact", &"reset_discoveries"]:
    Input.action_release(action)
  if _failures.is_empty():
    print("AOTS-006 discovery system smoke test passed.")
    quit(0)
  else:
    print("AOTS-006 discovery system smoke test failed: %d failure(s)." % _failures.size())
    quit(1)
