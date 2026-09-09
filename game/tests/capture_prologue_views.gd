extends SceneTree

const OUTPUT_DIR := "res://../docs/production/aots-012/screenshots"

var game: Node3D
var director: PrologueDirector
var valley: ValleyOfAsh
var chamber: SilentChamberGroundWorld
var warden: AshWarden
var combat: AerialCombatController
var traversal: TraversalCoordinator
var lunaris: LunarisFlightController
var ground: GroundPlayer
var camera: Camera3D


func _initialize() -> void:
  _capture_all.call_deferred()


func _capture_all() -> void:
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
  await _setup()
  await _view_a()
  await _view_b()
  await _view_c()
  await _view_d()
  await _view_e()
  await _view_f()
  await _view_g()
  await _view_h()
  await _view_i()
  await _view_j()
  await _view_k()
  await _view_l()
  print("AOTS-012 clean review captures saved in %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
  quit(0)


func _setup() -> void:
  game = (load("res://world/test/flight_test.tscn") as PackedScene).instantiate()
  (game.get_node("FirstFlightSequence") as FirstFlightSequence).play_opening_on_start = false
  root.add_child(game)
  await process_frame
  await physics_frame
  director = game.get_node("PrologueDirector") as PrologueDirector
  valley = game.get_node("ValleyOfAsh") as ValleyOfAsh
  chamber = game.get_node("SilentChamberGroundWorld") as SilentChamberGroundWorld
  warden = game.get_node("AshWarden") as AshWarden
  combat = game.get_node("AerialCombatController") as AerialCombatController
  traversal = game.get_node("TraversalCoordinator") as TraversalCoordinator
  lunaris = game.get_node("Lunaris") as LunarisFlightController
  ground = game.get_node("GroundPlayer") as GroundPlayer
  director.set_process(false)
  lunaris.set_physics_process(false)
  ground.set_physics_process(false)
  warden.set_process(false)
  (game.get_node("SacredAshArtTarget") as SacredAshArtTarget).set_screenshot_mode_enabled(true)
  camera = Camera3D.new()
  camera.name = "PrologueReviewCamera"
  game.add_child(camera)
  camera.current = true


func _clean() -> void:
  camera.current = true
  combat.combat_hud.visible = false
  director.title_layer.visible = false
  combat.set_target_locked(false)


func _view_a() -> void:
  director.start_after_first_flight_debug()
  _clean()
  lunaris.global_position = Vector3(0, 150, 470)
  lunaris.global_basis = Basis.IDENTITY
  _position_camera(Vector3(34, 165, 505), Vector3(0, 120, -300), 55.0)
  await _save("view_a_first_flight_free_valley.png")


func _view_b() -> void:
  director.start_after_first_flight_debug()
  _clean()
  lunaris.global_position = Vector3(225, 26, -68)
  lunaris.global_basis = Basis(Vector3.UP, -PI * 0.5)
  _position_camera(Vector3(206, 35, -113), Vector3(337, 23, -68), 52.0)
  await _save("view_b_silent_chamber_approach.png")


func _view_c() -> void:
  director.start_at_silent_chamber_debug()
  _clean()
  ground.visible = true
  ground.global_position = Vector3(388, 3.2, -68)
  _position_camera(Vector3(366, 11, -91), Vector3(425, 6, -68), 56.0)
  await _save("view_c_ground_descent.png")


func _view_d() -> void:
  director.start_at_silent_chamber_debug()
  _clean()
  ground.visible = true
  ground.global_position = Vector3(530, 4.1, -68)
  _position_camera(Vector3(519, 10, -91), Vector3(555, 11, -68), 48.0)
  await _save("view_d_last_signal.png")


func _view_e() -> void:
  director.start_after_last_signal_debug()
  _clean()
  ground.visible = true
  ground.global_position = Vector3(576, 4.1, -68)
  _position_camera(Vector3(564, 12, -96), SilentChamberGroundWorld.INNER_DOOR_POSITION + Vector3(0, 24, 0), 47.0)
  await _save("view_e_inner_door_response.png")


func _view_f() -> void:
  director.start_after_last_signal_debug()
  valley.set_spire_state(ValleyOfAsh.SpireState.AWAKENED, false)
  _clean()
  _position_camera(Vector3(175, 235, -395), Vector3(0, 178, -650), 48.0)
  await _save("view_f_awakened_spire.png")


func _view_g() -> void:
  director.start_after_first_flight_debug()
  warden.set_world_state(AshWarden.WorldState.DORMANT, false)
  _clean()
  _position_camera(warden.global_position + Vector3(38, 24, 74), warden.global_position + Vector3(0, -2, 0), 47.0)
  await _save("view_g_dormant_warden.png")


func _view_h() -> void:
  director.start_after_last_signal_debug()
  warden.set_world_state(AshWarden.WorldState.AWAKENED, false)
  _clean()
  _position_camera(warden.global_position + Vector3(40, 23, 76), warden.global_position, 47.0)
  await _save("view_h_warden_awakened.png")


func _view_i() -> void:
  director.start_at_warden_debug()
  combat._process(0.81)
  lunaris.global_position = warden.global_position + Vector3(-56, 4, 0)
  lunaris.global_basis = Basis(Vector3.UP, -PI * 0.5)
  combat._process(0.01)
  combat.set_target_locked(true)
  combat.combat_hud.visible = true
  combat.combat_hud.update_combat(100.0, warden, 0.55, 3, true, &"LEFT", 56.0)
  _position_camera(warden.global_position + Vector3(-82, 22, 35), warden.global_position, 52.0)
  await _save("view_i_warden_combat.png")
  combat.combat_hud.visible = false


func _view_j() -> void:
  director.start_after_warden_debug()
  _clean()
  _position_camera(warden.global_position + Vector3(39, 21, 72), warden.global_position + Vector3(0, 2, 0), 47.0)
  await _save("view_j_warden_remains.png")


func _view_k() -> void:
  director.start_after_warden_debug()
  valley.set_spire_state(ValleyOfAsh.SpireState.SIGNAL, false)
  _clean()
  _position_camera(Vector3(168, 238, -390), Vector3(0, 205, -650), 47.0)
  await _save("view_k_spire_aftermath_signal.png")


func _view_l() -> void:
  director.start_after_warden_debug()
  _clean()
  lunaris.global_position = Vector3(-35, 145, -330)
  lunaris.global_basis = Basis.IDENTITY
  director.title_layer.visible = true
  _position_camera(Vector3(10, 160, -285), Vector3(0, 145, -650), 54.0)
  await _save("view_l_prologue_complete_free_flight.png")


func _position_camera(position: Vector3, target: Vector3, fov: float) -> void:
  camera.fov = fov
  camera.look_at_from_position(position, target, Vector3.UP)


func _save(file_name: String) -> void:
  for _frame in range(14):
    await process_frame
  await RenderingServer.frame_post_draw
  var image := root.get_texture().get_image()
  var error := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
  if error != OK:
    push_error("Could not save %s (error %d)." % [file_name, error])
    quit(1)