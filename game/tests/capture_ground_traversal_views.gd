extends SceneTree

const OUTPUT_DIR := "res://../docs/production/aots-010/screenshots"

var _scene: Node3D
var _traversal: TraversalCoordinator
var _lunaris: LunarisFlightController
var _ground: GroundPlayer
var _camera: Camera3D


func _initialize() -> void:
  _capture_all.call_deferred()


func _capture_all() -> void:
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
  await _setup()
  await _capture_landing_approach()
  await _capture_ground_view("view_b_landed.png", Vector3(286, 5.1, -60), Vector3(252, 12, -91), Vector3(284, 7, -68), 47.0)
  await _capture_ground_view("view_c_entrance.png", Vector3(326, 5.1, -68), Vector3(308, 8.2, -68), Vector3(365, 18, -68), 61.0)
  await _capture_ground_view("view_d_descent.png", Vector3(375, 5.1, -68), Vector3(360, 8.5, -70), Vector3(425, 7, -68), 64.0)
  await _capture_ground_view("view_e_main_chamber.png", Vector3(485, 4.1, -68), Vector3(463, 15, -112), Vector3(555, 25, -68), 62.0)
  await _capture_ground_view("view_f_last_signal.png", Vector3(535, 4.1, -68), Vector3(523, 8.5, -87), Vector3(555, 11, -68), 53.0)
  await _capture_ground_view("view_g_inner_door.png", Vector3(579, 4.1, -68), Vector3(568, 8.5, -91), Vector3(616, 25, -68), 58.0)
  await _capture_ground_view("view_h_return.png", Vector3(340, 5.1, -68), Vector3(352, 9, -68), Vector3(282, 7, -68), 52.0)
  await _capture_takeoff()
  print("AOTS-010 clean screenshot views captured in %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
  quit(0)


func _setup() -> void:
  var packed := load("res://world/test/flight_test.tscn") as PackedScene
  _scene = packed.instantiate() as Node3D
  (_scene.get_node("FirstFlightSequence") as FirstFlightSequence).play_opening_on_start = false
  root.add_child(_scene)
  await process_frame
  await physics_frame
  _traversal = _scene.get_node("TraversalCoordinator") as TraversalCoordinator
  _lunaris = _scene.get_node("Lunaris") as LunarisFlightController
  _ground = _scene.get_node("GroundPlayer") as GroundPlayer
  (_scene.get_node("SacredAshArtTarget") as SacredAshArtTarget).set_screenshot_mode_enabled(true)
  _camera = Camera3D.new()
  _camera.name = "GroundReviewCamera"
  _scene.add_child(_camera)
  _camera.current = true


func _capture_landing_approach() -> void:
  _ground.set_player_input_enabled(false)
  _lunaris.reset_flight(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(235, 23, -68)))
  _lunaris.current_speed = 16.0
  (_lunaris.get_node("VisualPivot/LunarisVisual") as LunarisVisual).set_wing_pose(LunarisVisual.WingPose.GLIDE)
  _position_camera(Vector3(214, 21, -98), Vector3(270, 10, -68), 49.0)
  await _save("view_a_landing_approach.png")


func _capture_ground_view(file_name: String, player_position: Vector3, camera_position: Vector3, target: Vector3, fov: float) -> void:
  _traversal.start_ground_debug()
  _ground.reset_ground(player_position)
  _camera.current = true
  _position_camera(camera_position, target, fov)
  await _save(file_name)


func _capture_takeoff() -> void:
  _traversal.start_ground_debug()
  _ground.reset_ground(SilentChamberGroundWorld.DISMOUNT_POSITION)
  _traversal.mounting_duration = 0.05
  _traversal.takeoff_duration = 1.8
  _traversal.request_mount()
  for _frame in range(30):
    await physics_frame
    if _traversal.state == TraversalCoordinator.TraversalState.MOUNTED:
      break
  _traversal.request_takeoff()
  for _frame in range(42):
    await physics_frame
  _camera.current = true
  _position_camera(Vector3(250, 18, -96), Vector3(295, 14, -68), 49.0)
  await _save("view_i_takeoff.png")


func _position_camera(position: Vector3, target: Vector3, fov: float) -> void:
  _camera.fov = fov
  _camera.look_at_from_position(position, target, Vector3.UP)


func _save(file_name: String) -> void:
  for _frame in range(16):
    await process_frame
  await RenderingServer.frame_post_draw
  var image := root.get_texture().get_image()
  var error := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
  if error != OK:
    push_error("Could not save %s (error %d)." % [file_name, error])
    quit(1)
