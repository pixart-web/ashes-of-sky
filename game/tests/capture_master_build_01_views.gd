extends SceneTree

const OUTPUT_DIR := "res://../docs/production/master-build-01/screenshots"

var game: Node3D
var director: MasterBuildDirector
var world: ChapterOneWorld
var combat: ChapterCombat
var evolution: LunarisEvolution
var resonance_ui: ResonanceUI
var frontend: GameFrontend
var discovery_ui: DiscoveryUI
var lunaris: LunarisFlightController
var ground: GroundPlayer
var camera: Camera3D


func _initialize() -> void:
  _capture_all.call_deferred()


func _capture_all() -> void:
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
  await _setup()
  director.start_at_first_resonance_debug()
  _clean_ui()
  resonance_ui.visible = true
  await _save("06_first_resonance.png")
  resonance_ui._choose(LunarisEvolution.Tendency.ORACLE)
  _clean_ui()
  _camera(Vector3(15, 145, -640), Vector3(0, 160, -760), 52)
  await _save("07_selected_evolved_lunaris.png")
  _camera(Vector3(155, 235, -430), Vector3(0, 140, -715), 48)
  await _save("08_spire_approach.png")
  _camera(Vector3(82, 235, -655), Vector3(0, 155, -760), 54)
  await _save("09_spire_exterior_navigation.png")
  director.start_at_spire_ground_debug()
  ground.visible = true
  _camera(Vector3(75, 150, -650), ChapterOneWorld.SPIRE_LANDING, 52)
  await _save("10_spire_landing.png")
  _camera(Vector3(55, 143, -727), Vector3(0, 145, -810), 54)
  await _save("11_spire_interior.png")
  _camera(Vector3(42, 177, -805), Vector3(0, 155, -850), 50)
  await _save("12_architect_gallery.png")
  _camera(Vector3(45, 170, -760), Vector3(0, 151, -790), 49)
  await _save("13_environmental_puzzle.png")
  for index in range(3): world.activate_puzzle_node(index)
  _camera(Vector3(36, 177, -815), ChapterOneWorld.VAULT_POSITION + Vector3(0, 10, 0), 48)
  await _save("14_resonance_vault.png")
  _camera(Vector3(45, 215, -880), ChapterOneWorld.REVELATION_POSITION + Vector3(0, 12, 0), 50)
  await _save("15_revelation_chamber.png")
  world.complete_revelation()
  director._advance_to(MasterBuildDirector.State.REVELATION)
  _camera(Vector3(180, 240, -960), Vector3(0, 30, -1320), 52)
  await _save("16_pale_reach_reveal.png")
  director.start_at_pale_reach_debug()
  _clean_ui()
  _camera(Vector3(105, 155, -1070), Vector3(0, 35, -1420), 55)
  await _save("17_pale_reach_flight.png")
  combat.start_skimmer_encounter(1)
  combat.skimmers.visible = true
  _camera(Vector3(-150, 125, -1080), combat.skimmers.global_position, 52)
  await _save("18_ash_skimmer_encounter.png")
  combat.reset_current_encounter()
  director.start_at_sentinel_debug()
  _clean_ui()
  combat.combat_hud.visible = true
  _camera(Vector3(90, 145, -1490), combat.sentinel.global_position, 54)
  await _save("19_sentinel_phase_i.png")
  combat.sentinel_phase = 2
  _camera(Vector3(78, 112, -1515), combat.sentinel.global_position, 50)
  await _save("20_sentinel_phase_ii.png")
  combat.sentinel_phase = 3
  (combat.sentinel.get_node("Core") as Node3D).visible = true
  _camera(Vector3(58, 98, -1518), combat.sentinel.global_position + Vector3(0, 2, -10), 47)
  await _save("21_sentinel_final_phase.png")
  director.start_after_sentinel_debug()
  _clean_ui()
  _camera(Vector3(80, 110, -1495), combat.sentinel.global_position, 50)
  await _save("22_sentinel_aftermath.png")
  _camera(Vector3(140, 80, -1460), Vector3(0, -15, -1580), 52)
  await _save("23_the_sky_below.png")
  director.chapter_title.visible = true
  await _save("24_chapter_i_complete.png")
  director.chapter_title.visible = false
  frontend.visible = true
  frontend.show_title()
  await _save("25_main_menu.png")
  frontend.resume_game()
  frontend.visible = false
  discovery_ui.visible = true
  discovery_ui.open_journal()
  await _save("26_journal.png")
  discovery_ui.close_journal()
  discovery_ui.visible = false
  resonance_ui.visible = true
  resonance_ui.open_choice()
  await _save("27_resonance_ui.png")
  resonance_ui.close_choice()
  resonance_ui.visible = false
  frontend.visible = true
  frontend.show_settings()
  await _save("28_pause_settings.png")
  print("MASTER BUILD 01 review captures saved in %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
  quit(0)


func _setup() -> void:
  game = (load("res://world/test/flight_test.tscn") as PackedScene).instantiate()
  (game.get_node("FirstFlightSequence") as FirstFlightSequence).play_opening_on_start = false
  root.add_child(game)
  await process_frame
  await physics_frame
  director = game.get_node("MasterBuildDirector") as MasterBuildDirector
  world = game.get_node("ChapterOneWorld") as ChapterOneWorld
  combat = game.get_node("ChapterCombat") as ChapterCombat
  evolution = game.get_node("LunarisEvolution") as LunarisEvolution
  resonance_ui = game.get_node("ResonanceUI") as ResonanceUI
  frontend = game.get_node("GameFrontend") as GameFrontend
  discovery_ui = game.get_node("DiscoveryUI") as DiscoveryUI
  lunaris = game.get_node("Lunaris") as LunarisFlightController
  ground = game.get_node("GroundPlayer") as GroundPlayer
  (game.get_node("SacredAshArtTarget") as SacredAshArtTarget).set_screenshot_mode_enabled(true)
  lunaris.set_physics_process(false)
  ground.set_physics_process(false)
  director.set_process(false)
  combat.set_process(false)
  camera = Camera3D.new()
  camera.name = "MasterBuildReviewCamera"
  game.add_child(camera)
  camera.current = true


func _clean_ui() -> void:
  (game.get_node("DebugHUD") as CanvasLayer).visible = false
  var traversal_prompt := game.get_node_or_null("TraversalCoordinator/TraversalPrompt") as CanvasLayer
  if traversal_prompt != null:
    traversal_prompt.visible = false
  var prologue_title := (game.get_node("PrologueDirector") as PrologueDirector).title_layer
  if prologue_title != null:
    prologue_title.visible = false
  frontend.visible = false
  frontend.hide_all()
  resonance_ui.visible = false
  discovery_ui.visible = false
  director.chapter_title.visible = false
  combat.combat_hud.visible = false
  paused = false
  camera.current = true


func _camera(position: Vector3, target: Vector3, fov: float) -> void:
  camera.fov = fov
  camera.look_at_from_position(position, target, Vector3.UP)
  camera.current = true


func _save(file_name: String) -> void:
  for _frame in range(10): await process_frame
  await RenderingServer.frame_post_draw
  var error := root.get_texture().get_image().save_png("%s/%s" % [OUTPUT_DIR, file_name])
  if error != OK:
    push_error("Could not save %s." % file_name)
    quit(1)
