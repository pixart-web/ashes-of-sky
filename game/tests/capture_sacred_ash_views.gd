extends SceneTree

const OUTPUT_DIR := "res://../docs/production/aots-008/screenshots"

var _scene: Node3D
var _sequence: FirstFlightSequence
var _art_target: SacredAshArtTarget
var _lunaris: LunarisFlightController


func _initialize() -> void:
  _capture_views.call_deferred()


func _capture_views() -> void:
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
  await _capture_view_a_hero()
  await _capture_view_b_first_flight()
  await _prepare_direct_gameplay()
  await _capture_view_c_gameplay()
  await _capture_view_d_spire()
  await _capture_view_e_architect_language()
  await _capture_view_f_central_canyon()
  print("AOTS-008.2 clean screenshot views captured in %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
  quit(0)


func _capture_view_a_hero() -> void:
  _scene = _instantiate_scene(false)
  root.add_child(_scene)
  await process_frame
  await physics_frame
  _art_target = _scene.get_node("SacredAshArtTarget") as SacredAshArtTarget
  _lunaris = _scene.get_node("Lunaris") as LunarisFlightController
  _lunaris.set_player_input_enabled(false)
  _lunaris.global_position = Vector3(0, 150, 650)
  _art_target.set_screenshot_mode_enabled(true)
  _art_target.set_art_target_camera_enabled(true)
  await _settle_rendering()
  await _save_view("view_a_hero.png")
  await _remove_scene()


func _capture_view_b_first_flight() -> void:
  _scene = _instantiate_scene(true)
  _sequence = _scene.get_node("FirstFlightSequence") as FirstFlightSequence
  _sequence.timeline_speed_multiplier = 12.0
  root.add_child(_scene)
  await process_frame
  _art_target = _scene.get_node("SacredAshArtTarget") as SacredAshArtTarget
  _art_target.set_screenshot_mode_enabled(true)
  for _frame in range(300):
    await process_frame
    if _sequence.state == FirstFlightSequence.OpeningState.ESTABLISHING and _sequence.state_time >= _sequence.establishing_shot_duration * 0.76:
      break
  await _save_view("view_b_first_flight.png")
  await _remove_scene()


func _prepare_direct_gameplay() -> void:
  _scene = _instantiate_scene(false)
  root.add_child(_scene)
  await process_frame
  await physics_frame
  _art_target = _scene.get_node("SacredAshArtTarget") as SacredAshArtTarget
  _lunaris = _scene.get_node("Lunaris") as LunarisFlightController
  _art_target.set_screenshot_mode_enabled(true)


func _capture_view_c_gameplay() -> void:
  _art_target.set_art_target_camera_enabled(false)
  _lunaris.global_position = Vector3(-35, 195, 310)
  _lunaris.rotation = Vector3(0, deg_to_rad(-2.0), 0)
  _lunaris.velocity = Vector3(0, 0, -22)
  _lunaris.current_speed = 22.0
  _lunaris.set_player_input_enabled(false)
  var speed_particles := _lunaris.get_node("Presentation/SpeedParticles") as GPUParticles3D
  speed_particles.emitting = false
  for _frame in range(90):
    await process_frame
  await _save_view("view_c_gameplay.png")


func _capture_view_d_spire() -> void:
  _position_art_camera(Vector3(190, 238, -245), Vector3(0, 195, -650), 48.0)
  await _settle_rendering()
  await _save_view("view_d_spire.png")


func _capture_view_e_architect_language() -> void:
  _position_art_camera(Vector3(-8, 192, 716), Vector3(82, 184, 610), 58.0)
  await _settle_rendering()
  await _save_view("view_e_architect_language.png")


func _capture_view_f_central_canyon() -> void:
  _position_art_camera(Vector3(-20, 128, 320), Vector3(0, 82, -360), 68.0)
  await _settle_rendering()
  await _save_view("view_f_central_canyon.png")


func _instantiate_scene(play_opening: bool) -> Node3D:
  var packed := load("res://world/test/flight_test.tscn") as PackedScene
  var scene := packed.instantiate() as Node3D
  var opening := scene.get_node("FirstFlightSequence") as FirstFlightSequence
  opening.play_opening_on_start = play_opening
  return scene


func _position_art_camera(position: Vector3, target: Vector3, fov: float) -> void:
  var camera := _art_target.art_target_camera
  camera.position = position
  camera.fov = fov
  camera.look_at_from_position(position, target, Vector3.UP)
  _art_target.set_art_target_camera_enabled(true)


func _settle_rendering() -> void:
  for _frame in range(20):
    await process_frame


func _save_view(file_name: String) -> void:
  await RenderingServer.frame_post_draw
  var image := root.get_texture().get_image()
  var error := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
  if error != OK:
    push_error("Could not save %s (error %d)." % [file_name, error])
    quit(1)


func _remove_scene() -> void:
  _scene.queue_free()
  await process_frame
  await process_frame
