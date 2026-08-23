class_name LunarisVisualLab
extends Node3D

@onready var model_pivot: Node3D = $ModelPivot
@onready var lunaris_visual: LunarisVisual = $ModelPivot/LunarisVisual
@onready var camera: Camera3D = $Camera3D
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var floor: MeshInstance3D = $Floor
@onready var plinth: MeshInstance3D = $Plinth

var auto_rotate_enabled: bool = false
var rotation_speed: float = 12.0


func _ready() -> void:
  set_view(&"THREE_QUARTER")
  set_pose(LunarisVisual.WingPose.GLIDE)


func _process(delta: float) -> void:
  if auto_rotate_enabled:
    model_pivot.rotation.y += deg_to_rad(rotation_speed) * delta
  if lunaris_visual.current_pose == LunarisVisual.WingPose.FLAP_TEST:
    lunaris_visual.update_flight_reaction(delta, 0.45, 0.0, 0.0, 0.0, 0.0)


func _unhandled_input(event: InputEvent) -> void:
  if not event is InputEventKey or not event.pressed or event.echo:
    return
  match event.physical_keycode:
    KEY_1:
      set_view(&"SIDE")
    KEY_2:
      set_view(&"FRONT")
    KEY_3:
      set_view(&"TOP")
    KEY_4:
      set_view(&"REAR")
    KEY_5:
      set_view(&"THREE_QUARTER")
    KEY_Z:
      set_pose(LunarisVisual.WingPose.FOLDED)
    KEY_X:
      set_pose(LunarisVisual.WingPose.GLIDE)
    KEY_C:
      set_pose(LunarisVisual.WingPose.FULL_SPREAD)
    KEY_V:
      set_pose(LunarisVisual.WingPose.FLAP_TEST)
    KEY_R:
      lunaris_visual.set_rider_visible(not lunaris_visual.rider_visible)
    KEY_B:
      set_silhouette_enabled(not lunaris_visual.silhouette_enabled)
    KEY_SPACE:
      auto_rotate_enabled = not auto_rotate_enabled


func set_pose(pose: LunarisVisual.WingPose) -> void:
  lunaris_visual.set_wing_pose(pose)


func set_silhouette_enabled(enabled: bool) -> void:
  lunaris_visual.set_silhouette_enabled(enabled)
  floor.visible = not enabled
  plinth.visible = not enabled
  if enabled:
    world_environment.environment.background_color = Color(0.72, 0.74, 0.76)
    world_environment.environment.ambient_light_color = Color(1.0, 1.0, 1.0)
    world_environment.environment.ambient_light_energy = 1.0
  else:
    world_environment.environment.background_color = Color(0.018, 0.022, 0.03)
    world_environment.environment.ambient_light_color = Color(0.29, 0.34, 0.42)
    world_environment.environment.ambient_light_energy = 0.88


func set_view(view_name: StringName) -> void:
  model_pivot.rotation = Vector3.ZERO
  match view_name:
    &"SIDE":
      _position_camera(Vector3(11.5, 2.1, 0.8), Vector3(0, 0.1, 0.8), Vector3.UP, 45.0)
    &"FRONT":
      _position_camera(Vector3(0, 3.0, -11.8), Vector3(0, 0.0, 0.2), Vector3.UP, 46.0)
    &"TOP":
      _position_camera(Vector3(0, 11.5, 0.4), Vector3(0, 0, 0.35), Vector3.FORWARD, 43.0)
    &"REAR":
      _position_camera(Vector3(0, 1.2, 10.8), Vector3(0, 0.05, 0.5), Vector3.UP, 44.0)
    _:
      _position_camera(Vector3(7.2, 3.3, -7.4), Vector3(0, 0.15, 0.35), Vector3.UP, 40.0)


func _position_camera(position: Vector3, target: Vector3, up: Vector3, fov: float) -> void:
  camera.position = position
  camera.fov = fov
  camera.look_at_from_position(position, target, up)
