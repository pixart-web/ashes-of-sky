extends SceneTree

var failures: Array[String] = []
var audio_events: Array[StringName] = []
var music_states: Array[StringName] = []


func _initialize() -> void:
  _run.call_deferred()


func _run() -> void:
  var packed := load("res://world/test/flight_test.tscn") as PackedScene
  _assert(packed != null, "The continuous AOTS-012 Prologue scene loads.")
  var game := packed.instantiate()
  (game.get_node("FirstFlightSequence") as FirstFlightSequence).play_opening_on_start = false
  root.add_child(game)
  await process_frame
  await physics_frame

  var director := game.get_node("PrologueDirector") as PrologueDirector
  var manager := game.get_node("DiscoveryManager") as DiscoveryManager
  var ui := game.get_node("DiscoveryUI") as DiscoveryUI
  var chamber := game.get_node("SilentChamberGroundWorld") as SilentChamberGroundWorld
  var valley := game.get_node("ValleyOfAsh") as ValleyOfAsh
  var warden := game.get_node("AshWarden") as AshWarden
  var combat := game.get_node("AerialCombatController") as AerialCombatController
  var traversal := game.get_node("TraversalCoordinator") as TraversalCoordinator
  var lunaris := game.get_node("Lunaris") as LunarisFlightController
  director.set_process(false)
  director.prologue_audio_requested.connect(func(event): audio_events.append(event))
  director.music_state_requested.connect(func(state): music_states.append(state))

  _assert(director.get_state_id() == &"valley_awakening", "Direct First Flight handoff enters VALLEY_AWAKENING.")
  _assert(director.STATE_IDS.size() == 7 and director.STATE_IDS[0] == &"first_flight", "Prologue progression uses seven stable state IDs.")
  _assert(warden.world_state == AshWarden.WorldState.DORMANT and not combat.encounter_enabled, "Warden is a dormant monument before The Last Signal.")
  _assert(warden.left_guard_visual.position.y < -3.0 and warden.body_visual.rotation_degrees.z < -10.0, "Dormant Warden reads as collapsed Architect structure.")
  _assert(not combat.begin_encounter(true), "Dormant Warden cannot start combat even when entered.")
  _assert(director.get_thread_entries().is_empty(), "Unresolved Threads are hidden before The Last Signal.")
  _assert(chamber.has_node("LandingExterior/ActiveApproachHalo"), "Silent Chamber has restrained diegetic approach guidance.")

  _assert(manager.discover(&"lostplace_silent_chamber"), "Silent Chamber discovery registers normally.")
  _assert(director.get_state_id() == &"silent_chamber_discovered", "Silent Chamber discovery advances the Prologue.")
  _assert(manager.discover(&"echo_last_signal"), "The Last Signal registers with its existing stable ID.")
  _assert(director.get_state_id() == &"last_signal_recovered", "The Last Signal advances narrative state.")
  _assert(not manager.discover(&"echo_last_signal"), "Duplicate Echo discovery is rejected by the existing system.")
  _assert(director.signal_reaction_count == 0, "World reaction waits until the Echo presentation closes.")

  var echo_data := manager.get_definition(&"echo_last_signal")
  ui.open_echo(echo_data)
  _assert(ui.is_echo_open() and paused, "Existing Echo presentation remains in use.")
  ui.close_echo()
  _assert(not paused and director.signal_reaction_count == 1, "Closing The Last Signal starts one reaction sequence.")
  ui.close_echo()
  _assert(director.signal_reaction_count == 1, "Closing an already closed Echo cannot duplicate progression.")

  director.advance_timeline(0.81)
  _assert(chamber.chamber_responded and chamber.response_lines.visible, "Silent Chamber responds after a paced delay.")
  director.advance_timeline(1.4)
  _assert(chamber.inner_door_responded and chamber.inner_door_fracture.visible, "Inner Door answers with a thin cyan fracture.")
  _assert(chamber.get_node("MainChamberGroundPass/InnerDoor").get_meta("inaccessible"), "Inner Door remains sealed after responding.")
  director.advance_timeline(2.0)
  _assert(valley.spire_state == ValleyOfAsh.SpireState.AWAKENED and valley.spire_activation_core.visible, "Spire awakening becomes visible across the Valley.")
  _assert(warden.world_state == AshWarden.WorldState.AWAKENED and combat.encounter_enabled, "The Last Signal awakens Warden and enables its encounter.")
  _assert(director.get_state_id() == &"warden_awakened", "The paced world reaction reaches WARDEN_AWAKENED.")
  _assert(director.signal_reaction_count == 1, "The Last Signal world reaction remains single-shot.")
  _assert("Something ancient has awakened" in ui.journal_text.text, "Journal THREADS reflects the awakened mystery.")

  traversal.reset_to_flight()
  lunaris.reset_flight(Transform3D(Basis(Vector3.UP, -0.75), AerialCombatController.COMBAT_START))
  _assert(combat.begin_encounter(true), "Awakened Warden encounter starts in the existing Valley scene.")
  combat._process(0.81)
  _assert(combat.state == AerialCombatController.CombatState.COMBAT, "AOTS-011 combat reaches its active state unchanged.")
  warden.receive_attack(100.0, &"LEFT", 1.0)
  warden.receive_attack(100.0, &"RIGHT", 1.0)
  warden.core_health = 5.0
  warden.receive_attack(10.0, &"FRONT", 1.0)
  _assert(director.get_state_id() == &"warden_defeated", "Warden defeat advances narrative state without rewards.")
  _assert(warden.is_inside_tree() and warden.world_state == AshWarden.WorldState.DEFEATED, "Defeated Warden remains as a physical shell.")
  combat._process(1.61)
  _assert(combat.state == AerialCombatController.CombatState.EXPLORATION, "Combat exit restores free flight before aftermath.")
  director.advance_timeline(0.91)
  _assert(valley.spire_state == ValleyOfAsh.SpireState.SIGNAL and valley.spire_signal_halo.visible, "Spire emits the restrained aftermath signal.")
  director.advance_timeline(2.1)
  _assert(director.get_state_id() == &"prologue_complete", "Aftermath reaches PROLOGUE_COMPLETE without ending play.")
  _assert(lunaris.player_input_enabled and director.title_layer.visible, "Chapter presentation leaves Lunaris under player control.")
  _assert("The guardian answered the signal" in ui.journal_text.text, "THREADS records the aftermath and active Spire.")
  var expected_audio: Array[StringName] = [
    &"LAST_SIGNAL_AFTERMATH", &"INNER_DOOR_RESPONSE", &"SPIRE_AWAKENING",
    &"WARDEN_AWAKENING", &"DISTANT_WARDEN_CALL", &"WARDEN_DEFEAT_AFTERMATH",
    &"SPIRE_PULSE", &"PROLOGUE_COMPLETION",
  ]
  _assert(expected_audio.all(func(event): return event in audio_events), "All eight Prologue audio hooks fire.")
  var expected_music: Array[StringName] = [
    &"SILENT_CHAMBER", &"SIGNAL_REACTION", &"WARDEN", &"AFTERMATH", &"EXPLORATION",
  ]
  _assert(expected_music.all(func(music_state): return music_state in music_states), "All five conceptual music states are requested.")

  var snapshot := director.create_persistence_snapshot()
  _assert(snapshot.get("state_id") == "prologue_complete" and snapshot.has("discoveries"), "Prologue exposes a snapshot-friendly session dictionary.")
  director.reset_prologue_state(true)
  _assert(director.get_state_id() == &"first_flight", "Development reset restores FIRST_FLIGHT.")
  _assert(not chamber.chamber_responded and not chamber.inner_door_responded, "Development reset restores Chamber and Inner Door.")
  _assert(valley.spire_state == ValleyOfAsh.SpireState.DORMANT and warden.world_state == AshWarden.WorldState.DORMANT, "Development reset restores dormant Spire and Warden.")
  _assert(not combat.encounter_enabled and director.get_thread_entries().is_empty(), "Development reset clears encounter and Thread state.")
  _assert(not manager.is_discovered(&"echo_last_signal"), "Development reset restores Last Signal progression.")
  _assert(director.restore_persistence_snapshot(snapshot), "A valid Prologue snapshot restores successfully.")
  _assert(director.get_state_id() == &"prologue_complete" and manager.is_discovered(&"echo_last_signal"), "Snapshot restore recovers narrative and discovery state.")
  _assert(valley.spire_state == ValleyOfAsh.SpireState.SIGNAL and warden.world_state == AshWarden.WorldState.DEFEATED, "Snapshot restore reapplies persistent world reactions.")

  director.start_after_first_flight_debug()
  _assert(director.get_state_id() == &"valley_awakening", "Shortcut START AFTER FIRST FLIGHT works.")
  director.start_at_silent_chamber_debug()
  _assert(director.get_state_id() == &"silent_chamber_discovered" and traversal.state == TraversalCoordinator.TraversalState.GROUND, "Shortcut START AT SILENT CHAMBER works.")
  director.start_after_last_signal_debug()
  _assert(director.get_state_id() == &"warden_awakened" and chamber.inner_door_responded, "Shortcut START AFTER LAST SIGNAL works.")
  director.start_at_warden_debug()
  _assert(combat.state == AerialCombatController.CombatState.COMBAT_ENTER, "Shortcut START AT WARDEN works.")
  director.start_after_warden_debug()
  _assert(director.get_state_id() == &"prologue_complete" and warden.world_state == AshWarden.WorldState.DEFEATED, "Shortcut START AFTER WARDEN works.")
  _assert(InputMap.has_action(&"prologue_reset") and InputMap.has_action(&"prologue_after_warden"), "Development shortcuts use semantic Input Map actions.")
  _assert(not game.has_node("QuestManager") and not game.has_node("XP") and not game.has_node("Loot"), "No quest or RPG progression framework was introduced.")
  print("AOTS-012 PROLOGUE_BUDGET scene_nodes=%d" % (game.find_children("*", "", true, false).size() + 1))
  _finish()


func _assert(condition: bool, message: String) -> void:
  if condition:
    print("PASS: %s" % message)
  else:
    failures.append(message)
    push_error("FAIL: %s" % message)


func _finish() -> void:
  if failures.is_empty():
    print("AOTS-012 Prologue gameplay loop smoke test passed.")
    quit(0)
  else:
    print("AOTS-012 Prologue gameplay loop smoke test failed: %d failure(s)." % failures.size())
    quit(1)
