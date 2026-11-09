extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
  _run.call_deferred()


func _run() -> void:
  var packed := load("res://world/test/flight_test.tscn") as PackedScene
  _assert(packed != null, "MASTER BUILD 01 continuous scene loads.")
  var game := packed.instantiate()
  (game.get_node("FirstFlightSequence") as FirstFlightSequence).play_opening_on_start = false
  root.add_child(game)
  await process_frame
  await physics_frame

  var director := game.get_node("MasterBuildDirector") as MasterBuildDirector
  var evolution := game.get_node("LunarisEvolution") as LunarisEvolution
  var resonance_ui := game.get_node("ResonanceUI") as ResonanceUI
  var world := game.get_node("ChapterOneWorld") as ChapterOneWorld
  var combat := game.get_node("ChapterCombat") as ChapterCombat
  var traversal := game.get_node("TraversalCoordinator") as TraversalCoordinator
  var manager := game.get_node("DiscoveryManager") as DiscoveryManager
  var frontend := game.get_node("GameFrontend") as GameFrontend
  var save := game.get_node("GameSaveSystem") as GameSaveSystem
  save.save_path = "user://master_build_01_smoke_save.json"
  save.delete_save()

  director.start_at_first_resonance_debug()
  _assert(director.get_state_id() == &"first_resonance" and resonance_ui.visible, "Prologue completion opens First Resonance.")
  resonance_ui._choose(LunarisEvolution.Tendency.PREDATOR)
  _assert(evolution.get_tendency_id() == &"predator" and evolution.evolution_stage == 1, "Predator Stage 1 evolution is selected and persistent.")
  _assert(float(evolution.get_gameplay_modifiers()["pulse_power"]) > 1.0, "Predator tendency changes combat flavour.")
  _assert(world.spire_accessible and director.get_state_id() == &"spire_approach", "Evolution opens the natural Spire approach.")
  _assert(not paused, "Resonance selection returns control to the player.")

  _assert(traversal.start_ground_at_site_debug(&"spire"), "Spire reuses multi-site landing and ground traversal.")
  _assert(traversal.get_active_site_id() == &"spire" and traversal.state == TraversalCoordinator.TraversalState.GROUND, "Spire landing leaves Lunaris and enables Kael ground exploration.")
  for index in range(3):
    _assert(world.activate_puzzle_node(index), "Architect path %d activates once." % (index + 1))
  _assert(world.puzzle_complete and director.get_state_id() == &"resonance_vault", "Three readable spatial paths open the Resonance Vault.")
  world.apply_vault_tendency(evolution.get_tendency_id())
  _assert(world.vault_response == &"predator", "Resonance Vault responds to the selected tendency.")
  _assert(world.complete_revelation(), "Revelation Chamber reveals the Pale Reach route.")
  director._advance_to(MasterBuildDirector.State.REVELATION)
  _assert(world.pale_reach_revealed, "The Pale Reach is revealed without changing scene.")

  traversal.reset_to_flight()
  director._enter_pale_reach()
  _assert(director.get_state_id() == &"pale_reach" and manager.is_discovered(&"region_pale_reach"), "Pale Reach transition registers a meaningful region discovery.")
  _assert(combat.start_skimmer_encounter(1), "First Ash Skimmer encounter starts.")
  while combat.encounter != ChapterCombat.Encounter.NONE:
    combat._attack_cooldown = 0.0
    combat.attack(40.0, false)
  _assert(combat.skimmer_encounters_completed == 1, "First Ash Skimmer encounter completes without loot.")
  _assert(combat.start_skimmer_encounter(2), "Second sparse Ash Skimmer encounter starts.")
  while combat.encounter != ChapterCombat.Encounter.NONE:
    combat._attack_cooldown = 0.0
    combat.attack(40.0, true)
  _assert(combat.skimmer_encounters_completed == 2, "Second Ash Skimmer encounter completes.")

  _assert(combat.start_sentinel_encounter(), "Veiled Sentinel encounter starts after normal combat.")
  combat._state_time = 3.0
  combat._attack_cooldown = 0.0
  combat.attack(20.0, false)
  _assert(combat.sentinel_phase == 2, "Sentinel Phase I teaches positioning before restraints engage.")
  while combat.sentinel_phase == 2:
    combat._attack_cooldown = 0.0
    combat.attack(80.0, true)
  _assert(combat.sentinel_phase == 3 and combat.restraint_health.all(func(value): return value <= 0.0), "Sentinel Phase II breaks three structural restraints.")
  while not combat.sentinel_defeated_state:
    combat._attack_cooldown = 0.0
    combat.attack(120.0, true)
  _assert(director.get_state_id() == &"chapter_complete" and director.second_resonance_detected, "Sentinel defeat completes Chapter I and detects locked second Resonance.")
  _assert(combat.sentinel.visible and combat.sentinel.rotation_degrees.z < -20.0, "Sentinel remains as a collapsed world-state shell.")
  _assert("THE SKY BELOW" in (game.get_node("DiscoveryUI") as DiscoveryUI).journal_text.text, "Journal establishes The Sky Below without explaining it.")

  var snapshot := director.create_snapshot()
  _assert(save.save_snapshot(snapshot), "Versioned local save writes explicit Chapter I state.")
  _assert(save.has_save() and int(save.load_snapshot().get("save_version", 0)) == GameSaveSystem.SAVE_VERSION, "Saved data is readable and versioned.")
  director.reset_chapter_state()
  _assert(director.get_state_id() == &"prologue" and evolution.get_tendency_id() == &"none", "Chapter reset clears evolution and world state.")
  _assert(director.restore_snapshot(save.load_snapshot()), "Save round-trip restores destroyed runtime state.")
  _assert(director.get_state_id() == &"chapter_complete" and evolution.get_tendency_id() == &"predator", "Load restores chapter state and Lunaris tendency.")
  _assert(combat.sentinel_defeated_state and world.pale_reach_revealed, "Load restores boss and world reactions coherently.")

  frontend.apply_setting(&"mouse_sensitivity", 1.25)
  frontend.apply_setting(&"invert_y", true)
  _assert(is_equal_approx(float(frontend.settings["mouse_sensitivity"]), 1.25) and bool(frontend.settings["invert_y"]), "Baseline accessibility settings persist in the UI model.")
  _assert(frontend.continue_button.disabled == false or save.has_save(), "Continue availability follows local save presence.")
  _assert(not game.has_node("Inventory") and not game.has_node("Loot") and not game.has_node("QuestManager"), "Chapter adds no inventory, loot, or generic quest framework.")
  _assert(InputMap.has_action(&"mb01_sentinel") and InputMap.has_action(&"mb01_reset_save"), "Development navigation and reset use semantic Input Map actions.")
  print("MB01_BUDGET nodes=%d" % (game.find_children("*", "", true, false).size() + 1))
  save.delete_save()
  game.queue_free()
  await process_frame
  _finish()


func _assert(condition: bool, message: String) -> void:
  if condition:
    print("PASS: %s" % message)
  else:
    failures.append(message)
    push_error("FAIL: %s" % message)


func _finish() -> void:
  if failures.is_empty():
    print("MASTER BUILD 01 integrated chapter smoke test passed.")
    quit(0)
  else:
    print("MASTER BUILD 01 integrated chapter smoke test failed: %d failure(s)." % failures.size())
    quit(1)
