extends SceneTree

const OUTPUT_DIR := "res://../docs/production/aots-011/screenshots"

var scene: Node3D
var lunaris: LunarisFlightController
var warden: AshWarden
var combat: AerialCombatController
var camera: Camera3D


func _initialize() -> void:
  _capture_all.call_deferred()


func _capture_all() -> void:
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
  await _setup()
  await _view_a_entry()
  await _view_b_lock()
  await _view_c_telegraph()
  await _view_d_side_attack()
  await _view_e_focus()
  await _view_f_guard_break()
  await _view_g_core_exposed()
  await _view_h_evade()
  await _view_i_defeat()
  print("AOTS-011 clean screenshot views captured in %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
  quit(0)


func _setup() -> void:
  scene = (load("res://world/test/flight_test.tscn") as PackedScene).instantiate()
  (scene.get_node("FirstFlightSequence") as FirstFlightSequence).play_opening_on_start = false
  root.add_child(scene)
  await process_frame
  await physics_frame
  lunaris = scene.get_node("Lunaris") as LunarisFlightController
  warden = scene.get_node("AshWarden") as AshWarden
  combat = scene.get_node("AerialCombatController") as AerialCombatController
  (scene.get_node("SacredAshArtTarget") as SacredAshArtTarget).set_screenshot_mode_enabled(true)
  combat.begin_encounter(true)
  combat._process(0.81)
  combat.combat_hud.visible = true
  combat.set_process(false)
  lunaris.set_player_input_enabled(false)
  lunaris.set_physics_process(false)
  warden.set_process(false)
  camera = Camera3D.new()
  camera.name = "CombatReviewCamera"
  scene.add_child(camera)
  camera.current = true


func _prepare(player_position: Vector3, yaw: float = 0.0) -> void:
  warden.reset_warden()
  warden.set_combat_active(true)
  lunaris.global_position = player_position
  lunaris.global_basis = Basis(Vector3.UP, yaw)
  lunaris.velocity = Vector3.ZERO
  combat.state = AerialCombatController.CombatState.COMBAT
  combat.relative_sector = combat.classify_sector(player_position)
  combat.target_distance = player_position.distance_to(warden.global_position)
  combat.player_health = 100.0
  combat.focus_charging = false
  combat.focus_charge = 0.0
  combat.evade_charges = 3
  combat.evade_protection = 0.0
  combat.focus_visual.visible = false
  combat.evade_visual.visible = false
  combat.combat_hud.update_combat(100.0, warden, 0.0, 3, combat.target_locked, combat.relative_sector, combat.target_distance)


func _view_a_entry() -> void:
  _prepare(warden.global_position + Vector3(0, 7, 92), 0.0)
  combat.set_target_locked(false)
  combat.combat_hud.visible = false
  _position_camera(warden.global_position + Vector3(38, 24, 116), warden.global_position + Vector3(0, 2, 8), 54.0)
  await _save("view_a_combat_entry.png")
  combat.combat_hud.visible = true


func _view_b_lock() -> void:
  _prepare(warden.global_position + Vector3(0, 5, 62), 0.0)
  combat.set_target_locked(true)
  combat.combat_hud.update_combat(100.0, warden, 0.0, 3, true, combat.relative_sector, combat.target_distance)
  _position_camera(warden.global_position + Vector3(32, 18, 87), warden.global_position + Vector3(0, 1, 0), 51.0)
  await _save("view_b_target_lock.png")


func _view_c_telegraph() -> void:
  _prepare(warden.global_position + Vector3(0, 2, -66), PI)
  combat.set_target_locked(true)
  warden._begin_telegraph(&"WARDEN_LANCE")
  warden.advance_ai(1.0, &"FRONT", 66.0)
  combat.combat_hud.update_combat(100.0, warden, 0.0, 3, true, &"FRONT", 66.0)
  _position_camera(warden.global_position + Vector3(34, 17, -91), warden.global_position + Vector3(0, 0, -7), 50.0)
  await _save("view_c_warden_telegraph.png")


func _view_d_side_attack() -> void:
  _prepare(warden.global_position + Vector3(-58, 4, 0), -PI * 0.5)
  combat.set_target_locked(true)
  combat.fire_pulse()
  combat.combat_hud.update_combat(100.0, warden, 0.0, 3, true, &"LEFT", 58.0)
  _position_camera(warden.global_position + Vector3(-83, 19, 31), warden.global_position + Vector3(-4, 1, 0), 52.0)
  await _save("view_d_side_position.png", 2)


func _view_e_focus() -> void:
  _prepare(warden.global_position + Vector3(58, 5, 0), PI * 0.5)
  combat.set_target_locked(true)
  combat.begin_focus()
  combat.charge_focus(2.25)
  combat.focus_visual.scale = Vector3.ONE * 1.55
  combat.combat_hud.update_combat(100.0, warden, 1.0, 3, true, &"RIGHT", 58.0)
  _position_camera(warden.global_position + Vector3(83, 18, 31), warden.global_position + Vector3(3, 1, 0), 50.0)
  await _save("view_e_full_focus.png")


func _view_f_guard_break() -> void:
  _prepare(warden.global_position + Vector3(-54, 3, 0), -PI * 0.5)
  combat.set_target_locked(true)
  warden.receive_attack(100.0, &"LEFT", 1.0)
  combat.combat_hud.update_combat(100.0, warden, 0.0, 3, true, &"LEFT", 54.0)
  _position_camera(warden.global_position + Vector3(-76, 17, 34), warden.global_position, 48.0)
  await _save("view_f_guard_break.png")


func _view_g_core_exposed() -> void:
  _prepare(warden.global_position + Vector3(0, 3, -58), PI)
  combat.set_target_locked(true)
  warden.receive_attack(100.0, &"LEFT", 1.0)
  warden.receive_attack(100.0, &"RIGHT", 1.0)
  combat.combat_hud.update_combat(100.0, warden, 0.0, 3, true, &"FRONT", 58.0)
  _position_camera(warden.global_position + Vector3(29, 15, -73), warden.global_position + Vector3(0, 0, -3), 46.0)
  await _save("view_g_core_exposed.png")


func _view_h_evade() -> void:
  _prepare(warden.global_position + Vector3(0, 1, -62), PI)
  combat.set_target_locked(true)
  warden._begin_telegraph(&"WARDEN_LANCE")
  warden.advance_ai(0.9, &"FRONT", 62.0)
  combat.perform_evade(1.0)
  combat.combat_hud.update_combat(100.0, warden, 0.0, 2, true, &"FRONT", 62.0)
  _position_camera(warden.global_position + Vector3(35, 17, -88), warden.global_position + Vector3(0, 0, -5), 53.0)
  await _save("view_h_evade.png")


func _view_i_defeat() -> void:
  _prepare(warden.global_position + Vector3(0, 5, 66), 0.0)
  warden.receive_attack(100.0, &"LEFT", 1.0)
  warden.receive_attack(100.0, &"RIGHT", 1.0)
  warden.core_health = 8.0
  warden.receive_attack(10.0, &"FRONT", 1.0)
  warden.position.y -= 4.0
  warden.rotation.z = deg_to_rad(18.0)
  combat.combat_hud.visible = false
  _position_camera(warden.global_position + Vector3(36, 20, 82), warden.global_position, 50.0)
  await _save("view_i_defeat.png")


func _position_camera(position: Vector3, target: Vector3, fov: float) -> void:
  camera.fov = fov
  camera.look_at_from_position(position, target, Vector3.UP)


func _save(file_name: String, settle_frames: int = 12) -> void:
  for _frame in range(settle_frames):
    await process_frame
  await RenderingServer.frame_post_draw
  var image := root.get_texture().get_image()
  var error := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
  if error != OK:
    push_error("Could not save %s (error %d)." % [file_name, error])
    quit(1)