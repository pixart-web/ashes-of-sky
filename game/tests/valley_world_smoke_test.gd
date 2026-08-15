extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
  _run.call_deferred()


func _run() -> void:
  var packed_scene := load("res://world/test/flight_test.tscn") as PackedScene
  _assert(packed_scene != null, "The Valley of Ash flight scene loads.")
  if packed_scene == null:
    _finish()
    return

  var flight_test := packed_scene.instantiate()
  root.add_child(flight_test)
  await _wait_for_physics_frames(5)

  var valley := flight_test.get_node("ValleyOfAsh") as ValleyOfAsh
  var lunaris := flight_test.get_node("Lunaris") as LunarisFlightController
  _assert(valley != null, "The modular ValleyOfAsh world is present.")
  _assert(lunaris != null, "The existing flight controller remains present.")
  if valley == null or lunaris == null:
    _finish()
    return

  var required_regions := [
    "Terrain", "StartingCliff", "CentralCanyon", "AshBasin", "BrokenPlateau",
    "RuinField", "AncientGate", "Spire", "LostPlaces", "Atmosphere",
  ]
  for region_name in required_regions:
    _assert(valley.has_node(region_name), "%s region exists." % region_name)

  var spire := valley.get_node("Spire")
  _assert(spire.get_meta("landmark_level") == "primary", "The Spire is the primary landmark.")
  _assert(spire.get_meta("conceptual_height_m") >= 250, "The Spire meets the intended monumental scale.")
  _assert(spire.get_meta("visible_from_spawn"), "The Spire is composed to be visible from spawn.")

  var gate := valley.get_node("AncientGate")
  _assert(gate.get_meta("conceptual_height_m") > 100, "The Ancient Gate provides a giant scale reference.")
  _assert(valley.get_node("CentralCanyon").get_child_count() >= 15, "The canyon has walls, bridges, exits, and embedded ruins.")
  _assert(valley.get_node("RuinField").get_child_count() >= 15, "The Ruin Field supports weaving flight.")

  var routes := valley.get_node("ExplorationRoutes")
  _assert(routes.has_node("SafeRoute"), "A safe open route exists.")
  _assert(routes.has_node("FastRoute"), "A fast canyon route exists.")
  _assert(routes.has_node("DiscoveryRoute"), "A discovery route exists.")
  _assert(routes.get_node("FastRoute").get_child_count() >= 5, "The fast route traverses several canyon beats.")

  var chamber := valley.get_node("LostPlaces/SilentChamber")
  _assert(chamber.get_meta("lost_place_id") == "LOST PLACE #001", "The Silent Chamber is Lost Place #001.")
  _assert(chamber.get_meta("hidden_from_main_route"), "The Silent Chamber is hidden from the main route.")
  _assert(chamber.has_node("CentralMysteriousObject"), "The Silent Chamber has a central mysterious object.")
  _assert(chamber.has_node("EntranceClue00"), "An environmental clue suggests the hidden entrance.")

  var stories := valley.get_node("EnvironmentalStorytelling")
  _assert(stories.get_child_count() == 3, "Three environmental storytelling compositions exist.")
  _assert(stories.has_node("CrashedColossus"), "The cliff contains an embedded colossal wreck.")
  _assert(stories.has_node("ConvergenceRuins"), "Several ruins lean toward a common point.")
  _assert(stories.has_node("UnbrokenMonolith"), "A preserved structure contrasts with destroyed terrain.")

  _assert(
    lunaris.global_position.distance_to(ValleyOfAsh.SPAWN_POSITION) < 3.0,
    "Lunaris starts at the launch cliff vista."
  )
  _assert(lunaris.global_basis.z.is_equal_approx(Vector3.BACK), "Lunaris initially faces toward the valley and Spire.")
  _assert(valley.get_region_name(lunaris.global_position) == &"STARTING CLIFF", "Spawn reports the Starting Cliff region.")
  _assert(not valley.has_node("ObjectiveMarker"), "No objective marker was introduced.")

  var original_collision_shape := lunaris.get_node("CollisionShape3D") as CollisionShape3D
  _assert(original_collision_shape != null, "Existing Lunaris collision remains intact.")
  _assert(lunaris.has_node("Presentation"), "Existing flight presentation remains intact.")
  _assert(flight_test.has_node("FlightCameraRig"), "Existing chase camera remains intact.")

  var world_nodes := valley.find_children("*", "", true, false)
  var collision_bodies := valley.find_children("*", "StaticBody3D", true, false)
  _assert(world_nodes.size() < 500, "World node count remains within the prototype budget.")
  _assert(collision_bodies.size() < 100, "World collision-body count remains conservative.")
  print("WORLD_BUDGET nodes=%d static_bodies=%d" % [world_nodes.size(), collision_bodies.size()])

  lunaris.global_position = Vector3(1300, 100, 0)
  await _wait_for_physics_frames(2)
  _assert(lunaris.global_position.distance_to(ValleyOfAsh.SPAWN_POSITION) < 5.0, "Extreme out-of-bounds travel resets to the cliff.")

  var hud := flight_test.get_node("DebugHUD/Panel/Margin/Telemetry")
  _assert(hud.has_node("RegionValue"), "Optional debug HUD includes the current region.")
  _assert(hud.has_node("PositionValue"), "Optional debug HUD includes world position.")
  _assert(hud.has_node("SpireDistanceValue"), "Optional debug HUD includes distance to the Spire.")

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
  if _failures.is_empty():
    print("AOTS-005 Valley of Ash world smoke test passed.")
    quit(0)
  else:
    print("AOTS-005 Valley of Ash world smoke test failed: %d failure(s)." % _failures.size())
    quit(1)
