extends SceneTree

const OUTPUT_DIR := "res://../docs/production/aots-009/screenshots"

var _scene: Node3D
var _lunaris: LunarisFlightController
var _visual: LunarisVisual
var _art_target: SacredAshArtTarget


func _initialize() -> void:
  _capture_all.call_deferred()


func _capture_all() -> void:
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
  await _capture_lab_view("view_a_side.png", &"SIDE", LunarisVisual.WingPose.GLIDE)
  await _capture_lab_view("view_b_front.png", &"FRONT", LunarisVisual.WingPose.FULL_SPREAD)
  await _capture_lab_view("view_c_top.png", &"TOP", LunarisVisual.WingPose.FULL_SPREAD)
  await _capture_lab_view("view_d_three_quarter.png", &"THREE_QUARTER", LunarisVisual.WingPose.GLIDE)
  await _capture_rider_scale()
  await _capture_gameplay()
  await _capture_first_flight_deployment()
  await _capture_sacred_ash_flight()
  await _capture_silhouette("view_i_silhouette_side.png", &"SIDE", LunarisVisual.WingPose.GLIDE)
  await _capture_silhouette("view_j_silhouette_top.png", &"TOP", LunarisVisual.WingPose.FULL_SPREAD)
  print("AOTS-009.1 corrected anatomy and silhouette views captured in %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
  quit(0)


func _capture_lab_view(file_name: String, view_name: StringName, pose: LunarisVisual.WingPose) -> void:
  var lab_scene := load("res://art/lunaris/lunaris_visual_lab.tscn") as PackedScene
  var lab := lab_scene.instantiate()
  root.add_child(lab)
  await process_frame
  lab.call(&"set_pose", pose)
  lab.call(&"set_view", view_name)
  await _settle_rendering(18)
  await _save_view(file_name)
  lab.queue_free()
  await process_frame


func _capture_silhouette(file_name: String, view_name: StringName, pose: LunarisVisual.WingPose) -> void:
  var lab_scene := load("res://art/lunaris/lunaris_visual_lab.tscn") as PackedScene
  var lab := lab_scene.instantiate()
  root.add_child(lab)
  await process_frame
  lab.call(&"set_pose", pose)
  lab.call(&"set_view", view_name)
  lab.call(&"set_silhouette_enabled", true)
  var camera := lab.get_node("Camera3D") as Camera3D
  if view_name == &"SIDE":
    camera.look_at_from_position(Vector3(9.3, 1.7, 0.65), Vector3(0, 0.08, 0.65), Vector3.UP)
    camera.fov = 43.0
  elif view_name == &"TOP":
    camera.look_at_from_position(Vector3(0, 20.0, 0.4), Vector3(0, 0, 0.35), Vector3.FORWARD)
    camera.fov = 48.0
  await _settle_rendering(18)
  await _save_view(file_name)
  lab.queue_free()
  await process_frame


func _capture_rider_scale() -> void:
  var lab_scene := load("res://art/lunaris/lunaris_visual_lab.tscn") as PackedScene
  var lab := lab_scene.instantiate()
  root.add_child(lab)
  await process_frame
  lab.call(&"set_pose", LunarisVisual.WingPose.GLIDE)
  var camera := lab.get_node("Camera3D") as Camera3D
  var position := Vector3(4.9, 2.8, -5.2)
  camera.fov = 34.0
  camera.look_at_from_position(position, Vector3(0, 0.55, -0.05), Vector3.UP)
  await _settle_rendering(18)
  await _save_view("view_e_rider_scale.png")
  lab.queue_free()
  await process_frame


func _capture_gameplay() -> void:
  _scene = _instantiate_flight_scene(false)
  root.add_child(_scene)
  await process_frame
  await physics_frame
  _prepare_clean_flight()
  _lunaris.global_position = Vector3(-25, 205, 330)
  _lunaris.rotation = Vector3(0, deg_to_rad(-2.0), 0)
  _lunaris.velocity = Vector3(0, 0, -22)
  _lunaris.current_speed = 22.0
  _lunaris.set_player_input_enabled(false)
  _visual.set_wing_pose(LunarisVisual.WingPose.GLIDE)
  _art_target.set_art_target_camera_enabled(false)
  await _settle_rendering(100)
  await _save_view("view_f_gameplay.png")
  await _remove_scene()


func _capture_first_flight_deployment() -> void:
  _scene = _instantiate_flight_scene(true)
  var sequence := _scene.get_node("FirstFlightSequence") as FirstFlightSequence
  sequence.timeline_speed_multiplier = 12.0
  root.add_child(_scene)
  await process_frame
  _art_target = _scene.get_node("SacredAshArtTarget") as SacredAshArtTarget
  _art_target.set_screenshot_mode_enabled(true)
  for _frame in range(720):
    await process_frame
    if sequence.state == FirstFlightSequence.OpeningState.RECOVERY and sequence.state_time >= sequence.recovery_duration * 0.78:
      break
  await RenderingServer.frame_post_draw
  await _save_view("view_g_first_flight.png")
  await _remove_scene()


func _capture_sacred_ash_flight() -> void:
  _scene = _instantiate_flight_scene(false)
  root.add_child(_scene)
  await process_frame
  await physics_frame
  _prepare_clean_flight()
  _lunaris.global_position = Vector3(-72, 138, 115)
  _lunaris.rotation = Vector3(0, deg_to_rad(-4.0), 0)
  _lunaris.velocity = Vector3(0, 0, -24)
  _lunaris.current_speed = 24.0
  _lunaris.set_player_input_enabled(false)
  _visual.set_wing_pose(LunarisVisual.WingPose.GLIDE)
  var camera := _art_target.art_target_camera
  var camera_position := Vector3(-64, 144, 140)
  camera.fov = 53.0
  camera.look_at_from_position(camera_position, Vector3(-18, 122, -360), Vector3.UP)
  _art_target.set_art_target_camera_enabled(true)
  await _settle_rendering(24)
  await _save_view("view_h_sacred_ash.png")
  await _remove_scene()


func _instantiate_flight_scene(play_opening: bool) -> Node3D:
  var packed := load("res://world/test/flight_test.tscn") as PackedScene
  var scene := packed.instantiate() as Node3D
  var opening := scene.get_node("FirstFlightSequence") as FirstFlightSequence
  opening.play_opening_on_start = play_opening
  return scene


func _prepare_clean_flight() -> void:
  _lunaris = _scene.get_node("Lunaris") as LunarisFlightController
  _visual = _lunaris.get_node("VisualPivot/LunarisVisual") as LunarisVisual
  _art_target = _scene.get_node("SacredAshArtTarget") as SacredAshArtTarget
  _art_target.set_screenshot_mode_enabled(true)
  var presentation := _lunaris.get_node("Presentation") as LunarisFlightPresentation
  presentation.speed_particles.emitting = false
  presentation.boost_trail_particles.emitting = false


func _settle_rendering(frame_count: int) -> void:
  for _frame in range(frame_count):
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
