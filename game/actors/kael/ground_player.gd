class_name GroundPlayer
extends CharacterBody3D

@export var walk_speed: float = 3.6
@export var run_speed: float = 6.5
@export var acceleration: float = 18.0
@export var deceleration: float = 22.0
@export var rotation_speed: float = 9.0
@export var gravity: float = 24.0
@export var mouse_sensitivity: float = 0.0022
@export var camera_pitch_limit: float = 55.0

var player_input_enabled: bool = false
var camera_yaw: Node3D
var camera_pitch: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var visual_pivot: Node3D


func _ready() -> void:
  collision_layer = 2
  collision_mask = 1
  floor_snap_length = 0.35
  floor_max_angle = deg_to_rad(48.0)
  _build_prototype()
  set_player_input_enabled(player_input_enabled)


func _physics_process(delta: float) -> void:
  if not player_input_enabled:
    velocity = Vector3.ZERO
    return

  if not is_on_floor():
    velocity.y -= gravity * delta
  else:
    velocity.y = -0.5

  var input := Input.get_vector(&"ground_left", &"ground_right", &"ground_forward", &"ground_back")
  var forward := -camera_yaw.global_basis.z
  forward.y = 0.0
  forward = forward.normalized()
  var right := camera_yaw.global_basis.x
  right.y = 0.0
  right = right.normalized()
  var direction := (right * input.x + forward * -input.y).normalized()
  var speed := run_speed if Input.is_action_pressed(&"ground_run") else walk_speed
  var target := direction * speed
  var response := acceleration if not direction.is_zero_approx() else deceleration
  velocity.x = move_toward(velocity.x, target.x, response * delta)
  velocity.z = move_toward(velocity.z, target.z, response * delta)

  if not direction.is_zero_approx():
    var desired_yaw := atan2(-direction.x, -direction.z)
    rotation.y = lerp_angle(rotation.y, desired_yaw, 1.0 - exp(-rotation_speed * delta))
  move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
  if not player_input_enabled:
    return
  if event is InputEventMouseMotion and Input.is_action_pressed(&"camera_look"):
    camera_yaw.rotation.y -= event.relative.x * mouse_sensitivity
    camera_pitch.rotation.x = clampf(
      camera_pitch.rotation.x - event.relative.y * mouse_sensitivity,
      -deg_to_rad(camera_pitch_limit),
      deg_to_rad(camera_pitch_limit)
    )


func set_player_input_enabled(enabled: bool) -> void:
  player_input_enabled = enabled
  visible = enabled
  set_physics_process(enabled)
  set_process_unhandled_input(enabled)
  if camera != null:
    camera.current = enabled
  if not enabled:
    velocity = Vector3.ZERO


func reset_ground(reset_position: Vector3, facing_yaw: float = -PI * 0.5) -> void:
  global_position = reset_position
  rotation = Vector3(0.0, facing_yaw, 0.0)
  velocity = Vector3.ZERO


func _build_prototype() -> void:
  if get_node_or_null("CollisionShape3D") == null:
    var collision := CollisionShape3D.new()
    collision.name = "CollisionShape3D"
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.32
    capsule.height = 1.8
    collision.shape = capsule
    collision.position.y = 0.9
    add_child(collision)

  visual_pivot = Node3D.new()
  visual_pivot.name = "VisualPivot"
  add_child(visual_pivot)
  var charcoal := _material(Color(0.055, 0.06, 0.07), 0.82)
  var warm := _material(Color(0.24, 0.16, 0.11), 0.9)
  var pale := _material(Color(0.54, 0.48, 0.37), 0.72)
  _add_capsule(visual_pivot, "Torso", Vector3(0, 1.17, 0), 0.27, 0.82, charcoal)
  _add_sphere(visual_pivot, "Head", Vector3(0, 1.72, -0.03), 0.18, pale)
  _add_limb(visual_pivot, "ArmLeft", Vector3(-0.24, 1.38, 0), Vector3(-0.34, 0.78, -0.04), 0.065, charcoal)
  _add_limb(visual_pivot, "ArmRight", Vector3(0.24, 1.38, 0), Vector3(0.34, 0.78, -0.04), 0.065, charcoal)
  _add_limb(visual_pivot, "LegLeft", Vector3(-0.13, 0.88, 0), Vector3(-0.17, 0.08, 0), 0.085, charcoal)
  _add_limb(visual_pivot, "LegRight", Vector3(0.13, 0.88, 0), Vector3(0.17, 0.08, 0), 0.085, charcoal)
  var cloak := MeshInstance3D.new()
  cloak.name = "CloakScarf"
  cloak.position = Vector3(0, 1.25, 0.17)
  var cloak_mesh := PrismMesh.new()
  cloak_mesh.size = Vector3(0.52, 0.92, 0.12)
  cloak_mesh.material = warm
  cloak.mesh = cloak_mesh
  visual_pivot.add_child(cloak)
  var clasp := MeshInstance3D.new()
  clasp.name = "BronzeClasp"
  clasp.position = Vector3(0.18, 1.47, -0.23)
  var clasp_mesh := SphereMesh.new()
  clasp_mesh.radius = 0.045
  clasp_mesh.height = 0.09
  clasp_mesh.material = pale
  clasp.mesh = clasp_mesh
  visual_pivot.add_child(clasp)

  camera_yaw = Node3D.new()
  camera_yaw.name = "CameraYaw"
  camera_yaw.position = Vector3(0, 1.45, 0)
  add_child(camera_yaw)
  camera_pitch = Node3D.new()
  camera_pitch.name = "CameraPitch"
  camera_pitch.rotation.x = deg_to_rad(-10.0)
  camera_yaw.add_child(camera_pitch)
  spring_arm = SpringArm3D.new()
  spring_arm.name = "SpringArm3D"
  spring_arm.spring_length = 4.8
  spring_arm.margin = 0.18
  spring_arm.collision_mask = 1
  camera_pitch.add_child(spring_arm)
  camera = Camera3D.new()
  camera.name = "Camera3D"
  camera.fov = 67.0
  spring_arm.add_child(camera)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
  var material := StandardMaterial3D.new()
  material.albedo_color = color
  material.roughness = roughness
  return material


func _add_capsule(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, material: Material) -> void:
  var instance := MeshInstance3D.new()
  instance.name = node_name
  instance.position = position
  var mesh := CapsuleMesh.new()
  mesh.radius = radius
  mesh.height = height
  mesh.radial_segments = 8
  mesh.rings = 3
  mesh.material = material
  instance.mesh = mesh
  parent.add_child(instance)


func _add_sphere(parent: Node3D, node_name: String, position: Vector3, radius: float, material: Material) -> void:
  var instance := MeshInstance3D.new()
  instance.name = node_name
  instance.position = position
  var mesh := SphereMesh.new()
  mesh.radius = radius
  mesh.height = radius * 2.0
  mesh.radial_segments = 8
  mesh.rings = 4
  mesh.material = material
  instance.mesh = mesh
  parent.add_child(instance)


func _add_limb(parent: Node3D, node_name: String, start: Vector3, finish: Vector3, radius: float, material: Material) -> void:
  var direction := finish - start
  var instance := MeshInstance3D.new()
  instance.name = node_name
  instance.position = (start + finish) * 0.5
  var mesh := CylinderMesh.new()
  mesh.top_radius = radius * 0.82
  mesh.bottom_radius = radius
  mesh.height = direction.length()
  mesh.radial_segments = 6
  mesh.material = material
  instance.mesh = mesh
  instance.quaternion = Quaternion(Vector3.UP, direction.normalized())
  parent.add_child(instance)
