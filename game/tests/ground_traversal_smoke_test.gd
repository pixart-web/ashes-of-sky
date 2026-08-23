extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
  _run.call_deferred()


func _run() -> void:
  var packed := load("res://world/test/flight_test.tscn") as PackedScene
  _assert(packed != null, "The AOTS-010 hybrid traversal scene loads.")
  var scene := packed.instantiate()
  var opening := scene.get_node("FirstFlightSequence") as FirstFlightSequence
  opening.play_opening_on_start = false
  root.add_child(scene)
  await process_frame
  await physics_frame

  var traversal := scene.get_node("TraversalCoordinator") as TraversalCoordinator
  var lunaris := scene.get_node("Lunaris") as LunarisFlightController
  var ground := scene.get_node("GroundPlayer") as GroundPlayer
  var chamber := scene.get_node("SilentChamberGroundWorld") as SilentChamberGroundWorld
  var manager := scene.get_node("DiscoveryManager") as DiscoveryManager
  var ui := scene.get_node("DiscoveryUI") as DiscoveryUI
  var echo := scene.get_node("WorldDiscovery/Echoes/LastSignal") as DiscoveryPoint
  _assert(traversal != null, "A dedicated high-level traversal coordinator exists.")
  _assert(ground != null and ground.has_node("VisualPivot/CloakScarf"), "Reusable Kael prototype has a readable human silhouette.")
  _assert(ground.has_node("CameraYaw/CameraPitch/SpringArm3D/Camera3D"), "Ground camera uses a collision-aware SpringArm3D.")
  _assert(chamber.has_node("LandingExterior/LandingPlatform"), "Silent Chamber has a deliberate landing platform.")
  _assert(chamber.has_node("GroundRoute/DescendingStep00") and chamber.has_node("GroundRoute/InactiveAnteroomHalo"), "The route includes descent and antechamber beats.")
  _assert(chamber.has_node("MainChamberGroundPass/InnerDoor/SealedSlab"), "The inaccessible Inner Door exists.")
  _assert(chamber.get_node("MainChamberGroundPass/InnerDoor").get_meta("inaccessible"), "The Inner Door is explicitly sealed.")
  _assert(InputMap.has_action(&"land") and InputMap.has_action(&"ground_run"), "Landing and ground running use semantic actions.")
  _assert(InputMap.has_action(&"start_silent_chamber_ground"), "A development direct-ground action exists.")

  lunaris.reset_flight(Transform3D(Basis.IDENTITY, Vector3.ZERO))
  lunaris.set_player_input_enabled(true)
  _assert(not traversal.request_landing(), "Landing requests outside the safe volume are rejected.")

  traversal.landing_duration = 0.04
  traversal.dismount_duration = 0.04
  traversal.mounting_duration = 0.04
  traversal.takeoff_duration = 0.04
  var approach := Transform3D(Basis(Vector3.UP, -PI * 0.5), SilentChamberGroundWorld.LANDING_POSITION + Vector3(0, 12, 0))
  lunaris.reset_flight(approach)
  lunaris.current_speed = 17.0
  lunaris.set_player_input_enabled(true)
  _assert(traversal.is_landing_valid(), "Landing becomes available only when speed, height, volume, and orientation are safe.")
  _assert(traversal.request_landing(), "A valid landing request begins the transition.")
  _assert(not lunaris.player_input_enabled and not ground.player_input_enabled, "Neither avatar owns uncontrolled input during landing.")
  await _wait_for_state(traversal, TraversalCoordinator.TraversalState.GROUND, 120)
  _assert(traversal.state == TraversalCoordinator.TraversalState.GROUND, "LANDING → LANDED → DISMOUNTING reaches GROUND.")
  _assert(ground.player_input_enabled and not lunaris.player_input_enabled, "Only Kael owns movement during GROUND.")
  _assert((lunaris.get_node("VisualPivot/LunarisVisual") as LunarisVisual).current_pose == LunarisVisual.WingPose.FOLDED, "Lunaris waits with relaxed folded wings.")

  var before_journal := ground.global_position
  ui.open_journal()
  _assert(ui.is_journal_open() and paused, "Journal opens and safely pauses ground exploration.")
  ground.velocity = Vector3(6, 0, 0)
  await process_frame
  _assert(ground.global_position.distance_to(before_journal) < 0.01, "Kael remains still while the Journal is open.")
  ui.close_journal()
  _assert(not paused and ground.player_input_enabled, "Closing Journal restores the ground state.")

  echo._on_body_entered(ground)
  _assert(manager.activate_current_interaction(), "Kael can activate The Last Signal on foot.")
  _assert(manager.is_discovered(&"echo_last_signal"), "The existing Echo discovery ID is preserved.")
  _assert(ui.is_echo_open(), "Existing Echo presentation is reused on foot.")
  ui.close_echo()
  echo._on_body_exited(ground)

  ground.reset_ground(SilentChamberGroundWorld.DISMOUNT_POSITION)
  _assert(traversal.can_mount(), "MOUNT is available only beside landed Lunaris.")
  _assert(traversal.request_mount(), "Mount transition begins from ground exploration.")
  _assert(not ground.player_input_enabled and not lunaris.player_input_enabled, "Neither avatar owns movement during mounting.")
  await _wait_for_state(traversal, TraversalCoordinator.TraversalState.MOUNTED, 60)
  _assert(traversal.request_takeoff(), "Mounted player can request takeoff.")
  await _wait_for_state(traversal, TraversalCoordinator.TraversalState.FLIGHT, 60)
  _assert(traversal.state == TraversalCoordinator.TraversalState.FLIGHT, "TAKEOFF returns to FLIGHT.")
  _assert(lunaris.player_input_enabled and not ground.player_input_enabled, "Only Lunaris owns movement after takeoff.")
  _assert(lunaris.velocity.length() >= lunaris.minimum_speed, "Takeoff restores safe forward flight velocity.")

  traversal.start_ground_debug()
  _assert(traversal.state == TraversalCoordinator.TraversalState.GROUND, "Development shortcut starts directly at Silent Chamber ground.")
  ground.global_position = Vector3(0, -40, 0)
  traversal.recover_ground()
  _assert(ground.global_position.is_equal_approx(SilentChamberGroundWorld.RECOVERY_POSITION), "Ground recovery returns Kael to the chamber entrance.")
  _assert(not scene.has_node("Combat") and not scene.has_node("Inventory") and not scene.has_node("QuestManager"), "No combat, inventory, or quest framework was introduced.")
  _finish()


func _wait_for_state(traversal: TraversalCoordinator, target: TraversalCoordinator.TraversalState, max_frames: int) -> void:
  for _frame in range(max_frames):
    await physics_frame
    if traversal.state == target:
      return


func _assert(condition: bool, message: String) -> void:
  if condition:
    print("PASS: %s" % message)
  else:
    _failures.append(message)
    push_error("FAIL: %s" % message)


func _finish() -> void:
  if _failures.is_empty():
    print("AOTS-010 ground traversal smoke test passed.")
    quit(0)
  else:
    print("AOTS-010 ground traversal smoke test failed: %d failure(s)." % _failures.size())
    quit(1)
