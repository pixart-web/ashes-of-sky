class_name LunarisVisual
extends Node3D

enum WingPose {
  FOLDED,
  GLIDE,
  FULL_SPREAD,
  FLAP_TEST,
}

const ORGANIC_BODY := preload("res://art/lunaris/materials/m_lunaris_organic_body.tres")
const BONE_PLATE := preload("res://art/lunaris/materials/m_lunaris_bone_plate.tres")
const ARCHITECT_METAL := preload("res://art/lunaris/materials/m_lunaris_architect_metal.tres")
const ENERGY := preload("res://art/lunaris/materials/m_lunaris_energy.tres")
const WING_MEMBRANE := preload("res://art/lunaris/materials/m_lunaris_wing_membrane.tres")
const KAEL_MATERIAL := preload("res://art/lunaris/materials/m_kael_placeholder.tres")

var wing_left: Node3D
var wing_right: Node3D
var neck: Node3D
var head: Node3D
var tail: Node3D
var rider_mount: Node3D
var kael_placeholder: Node3D
var architect_interface: Node3D

var current_pose: WingPose = WingPose.GLIDE
var rider_visible: bool = true
var silhouette_enabled: bool = false
var _silhouette_material: StandardMaterial3D
var _wing_fold: float = 0.0
var _elapsed_time: float = 0.0
var _tail_segments: Array[Node3D] = []
var _left_sections: Array[Node3D] = []
var _right_sections: Array[Node3D] = []


func _ready() -> void:
  if get_child_count() == 0:
    _build_visual()
  set_wing_pose(WingPose.GLIDE)


func set_wing_pose(pose: WingPose) -> void:
  current_pose = pose
  match pose:
    WingPose.FOLDED:
      set_wing_fold(1.0)
    WingPose.GLIDE:
      set_wing_fold(0.0)
    WingPose.FULL_SPREAD:
      set_wing_fold(-0.22)
    WingPose.FLAP_TEST:
      set_wing_fold(0.0)


func set_wing_fold(amount: float) -> void:
  _wing_fold = clampf(amount, -0.22, 1.0)
  var normalized_fold := maxf(_wing_fold, 0.0)
  var spread := maxf(-_wing_fold / 0.22, 0.0)
  wing_left.rotation = Vector3(
    deg_to_rad(lerpf(-3.0, 22.0, normalized_fold) - spread * 2.0),
    deg_to_rad(lerpf(10.0, 64.0, normalized_fold) - spread * 10.0),
    deg_to_rad(lerpf(2.0, 34.0, normalized_fold) - spread * 2.0)
  )
  wing_right.rotation = Vector3(
    deg_to_rad(lerpf(-3.0, 22.0, normalized_fold) - spread * 2.0),
    deg_to_rad(lerpf(-10.0, -64.0, normalized_fold) + spread * 10.0),
    deg_to_rad(lerpf(-2.0, -34.0, normalized_fold) + spread * 2.0)
  )
  _apply_section_fold(_left_sections, -1.0, normalized_fold, spread)
  _apply_section_fold(_right_sections, 1.0, normalized_fold, spread)


func update_flight_reaction(
  delta: float,
  speed_normalized: float,
  yaw_input: float,
  pitch_input: float,
  acceleration_response: float,
  boost_strength: float
) -> void:
  _elapsed_time += delta
  if current_pose == WingPose.FLAP_TEST:
    var flap_fold := 0.18 + (sin(_elapsed_time * 2.3) * 0.5 + 0.5) * 0.34
    set_wing_fold(flap_fold)
  elif _wing_fold < 0.82:
    var slow_correction := lerpf(5.5, 1.5, speed_normalized)
    var glide_adjustment := sin(_elapsed_time * lerpf(1.25, 0.72, speed_normalized)) * slow_correction
    set_wing_fold(clampf(boost_strength * 0.12 - glide_adjustment / 120.0, -0.08, 0.2))
    wing_left.rotation.x += deg_to_rad(pitch_input * 5.0 + yaw_input * 7.0)
    wing_right.rotation.x += deg_to_rad(pitch_input * 5.0 - yaw_input * 7.0)

  if head != null:
    head.rotation.y = lerp_angle(head.rotation.y, deg_to_rad(-yaw_input * 8.0), _smooth(4.5, delta))
    head.rotation.x = lerp_angle(head.rotation.x, deg_to_rad(pitch_input * 3.0), _smooth(3.5, delta))
  if neck != null:
    neck.rotation.y = lerp_angle(neck.rotation.y, deg_to_rad(-yaw_input * 3.5), _smooth(3.0, delta))
  for index in range(_tail_segments.size()):
    var segment := _tail_segments[index]
    var influence := float(index + 1) / float(_tail_segments.size())
    segment.rotation.y = lerp_angle(segment.rotation.y, deg_to_rad(yaw_input * 12.0 * influence), _smooth(3.2, delta))
    segment.rotation.x = lerp_angle(segment.rotation.x, deg_to_rad(-pitch_input * 4.0 * influence), _smooth(2.8, delta))
  rotation.x = lerp_angle(rotation.x, deg_to_rad(-acceleration_response * 1.8), _smooth(3.0, delta))


func set_rider_visible(visible: bool) -> void:
  rider_visible = visible
  if kael_placeholder != null:
    kael_placeholder.visible = visible


func set_silhouette_enabled(enabled: bool) -> void:
  silhouette_enabled = enabled
  if _silhouette_material == null:
    _silhouette_material = StandardMaterial3D.new()
    _silhouette_material.resource_name = "M_Lunaris_SilhouetteDebug"
    _silhouette_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _silhouette_material.albedo_color = Color(0.006, 0.007, 0.009, 1)
  for child in find_children("*", "MeshInstance3D", true, false):
    (child as MeshInstance3D).material_override = _silhouette_material if enabled else null


func get_material_library() -> Array[StandardMaterial3D]:
  return [ORGANIC_BODY, BONE_PLATE, ARCHITECT_METAL, ENERGY, WING_MEMBRANE, KAEL_MATERIAL]


func get_wingspan() -> float:
  return 11.8


func get_body_length_without_filaments() -> float:
  return 6.4


func _build_visual() -> void:
  set_meta("visual_prototype", "LUNARIS_CHARACTER_ART_TARGET_001")
  set_meta("collision_decoupled", true)
  _build_body()
  _build_neck_and_head()
  wing_left = _build_wing("WingLeft", -1.0)
  wing_right = _build_wing("WingRight", 1.0)
  _build_tail()
  _build_legs()
  _build_architect_interface()
  _build_rider_mount()


func _build_body() -> void:
  var body := Node3D.new()
  body.name = "Body"
  add_child(body)
  _add_capsule(body, "OrganicCore", Vector3(0, -0.03, 0.16), 0.43, 3.65, Vector3(90, 0, 0), ORGANIC_BODY, Vector3(1.0, 0.92, 0.92))
  _add_capsule(body, "AerodynamicShoulders", Vector3(0, 0.05, -0.52), 0.48, 2.35, Vector3(90, 0, 0), ORGANIC_BODY, Vector3(1.55, 0.9, 0.92))
  _add_tapered(body, "ChestTransition", Vector3(0, 0.04, -1.42), 0.29, 0.46, 1.18, Vector3(90, 0, 0), ORGANIC_BODY, 10)
  _add_tapered(body, "AbdomenTaper", Vector3(0, -0.05, 1.42), 0.24, 0.42, 1.5, Vector3(90, 0, 0), ORGANIC_BODY, 10)
  _add_capsule(body, "ShoulderMuscleLeft", Vector3(-0.63, 0.07, -0.5), 0.23, 1.2, Vector3(0, 0, 90), ORGANIC_BODY, Vector3(1.0, 0.82, 0.9))
  _add_capsule(body, "ShoulderMuscleRight", Vector3(0.63, 0.07, -0.5), 0.23, 1.2, Vector3(0, 0, 90), ORGANIC_BODY, Vector3(1.0, 0.82, 0.9))
  _add_prism(body, "DorsalPlateFrontLeft", Vector3(-0.25, 0.55, -0.72), Vector3(0.46, 0.12, 0.56), Vector3(0, 4, -3), BONE_PLATE)
  _add_prism(body, "DorsalPlateFrontRight", Vector3(0.25, 0.55, -0.72), Vector3(0.46, 0.12, 0.56), Vector3(0, -4, 3), BONE_PLATE)
  _add_prism(body, "DorsalPlateMid", Vector3(0, 0.48, 0.02), Vector3(0.72, 0.12, 0.55), Vector3.ZERO, BONE_PLATE)
  _add_prism(body, "DorsalPlateRear", Vector3(0, 0.36, 0.72), Vector3(0.52, 0.1, 0.42), Vector3.ZERO, BONE_PLATE)
  _add_tapered(body, "VentralKeel", Vector3(0, -0.44, 0.15), 0.12, 0.24, 1.7, Vector3(90, 0, 0), ARCHITECT_METAL, 5)

func _build_neck_and_head() -> void:
  neck = Node3D.new()
  neck.name = "Neck"
  neck.position = Vector3(0, 0.16, -1.28)
  add_child(neck)
  var neck_data := [
    [Vector3(0, 0.05, -0.2), 0.37, 0.43, 0.84, Vector3(82, 0, 0)],
    [Vector3(0, 0.17, -0.67), 0.33, 0.38, 0.8, Vector3(79, 0, 0)],
    [Vector3(0, 0.31, -1.1), 0.28, 0.34, 0.74, Vector3(76, 0, 0)],
    [Vector3(0, 0.45, -1.5), 0.23, 0.29, 0.66, Vector3(73, 0, 0)],
  ]
  for index in range(neck_data.size()):
    var entry: Array = neck_data[index]
    _add_tapered(neck, "Segment%02d" % (index + 1), entry[0], entry[1], entry[2], entry[3], entry[4], ORGANIC_BODY, 9)
    if index % 2 == 0:
      _add_prism(neck, "NeckPlate%02d" % (index + 1), entry[0] + Vector3(0, 0.22, 0.03), Vector3(0.28 - index * 0.025, 0.07, 0.3), Vector3(-3, 0, 0), BONE_PLATE)

  head = Node3D.new()
  head.name = "Head"
  head.position = Vector3(0, 0.58, -1.88)
  neck.add_child(head)
  _add_capsule(head, "PredatoryCranium", Vector3(0, 0, -0.2), 0.27, 1.02, Vector3(90, 0, 0), ORGANIC_BODY, Vector3(0.92, 1.0, 0.76))
  _add_tapered(head, "ElongatedSnout", Vector3(0, -0.07, -0.88), 0.18, 0.08, 1.08, Vector3(90, 0, 0), ORGANIC_BODY, 8)
  _add_tapered(head, "JawTaper", Vector3(0, -0.16, -0.69), 0.14, 0.07, 0.76, Vector3(90, 0, 0), ORGANIC_BODY, 7)
  _add_prism(head, "BrowPlateLeft", Vector3(-0.14, 0.17, -0.4), Vector3(0.22, 0.075, 0.54), Vector3(-5, 6, -4), BONE_PLATE)
  _add_prism(head, "BrowPlateRight", Vector3(0.14, 0.17, -0.4), Vector3(0.22, 0.075, 0.54), Vector3(-5, -6, 4), BONE_PLATE)
  _add_prism(head, "CrestLeft", Vector3(-0.15, 0.13, 0.24), Vector3(0.065, 0.075, 0.62), Vector3(-13, 8, 10), BONE_PLATE)
  _add_prism(head, "CrestRight", Vector3(0.15, 0.13, 0.24), Vector3(0.065, 0.075, 0.62), Vector3(-13, -8, -10), BONE_PLATE)
  _add_sphere(head, "EyeLeft", Vector3(-0.205, 0.015, -0.52), 0.045, ENERGY)
  _add_sphere(head, "EyeRight", Vector3(0.205, 0.015, -0.52), 0.045, ENERGY)

func _build_wing(node_name: String, side: float) -> Node3D:
  var wing := Node3D.new()
  wing.name = node_name
  wing.position = Vector3(side * 0.62, 0.18, -0.48)
  add_child(wing)
  var sections: Array[Node3D] = []
  var lengths := [1.5, 1.55, 1.35, 1.0]
  var sweep := [0.16, 0.26, 0.38, 0.54]
  var trailing := [0.92, 1.2, 1.3, 0.9]
  var names := ["WingRoot", "UpperWing", "ForeWing", "OuterWing"]
  var parent := wing
  for index in range(lengths.size()):
    var section := Node3D.new()
    section.name = names[index]
    if index > 0:
      section.position = Vector3(side * lengths[index - 1] * 0.94, 0, sweep[index - 1] * 0.86)
    parent.add_child(section)
    sections.append(section)
    var endpoint := Vector3(side * lengths[index], 0, sweep[index])
    _add_bone_between(section, "StructuralSpar", Vector3.ZERO, endpoint, 0.105 - index * 0.016, ARCHITECT_METAL)
    var trailing_inner := Vector3(-side * 0.08, -0.035, trailing[index] * 0.5)
    var trailing_outer := endpoint + Vector3(-side * 0.08, -0.04, trailing[index])
    _add_bone_between(section, "SupportFinger", endpoint * 0.58, trailing_outer, 0.06 - index * 0.007, BONE_PLATE)
    if index < 3:
      _add_membrane(section, "Membrane", PackedVector3Array([trailing_inner, Vector3.ZERO, endpoint, trailing_outer]), WING_MEMBRANE)
    parent = section
  if side < 0.0:
    _left_sections = sections
  else:
    _right_sections = sections
  return wing

func _build_tail() -> void:
  tail = Node3D.new()
  tail.name = "Tail"
  tail.position = Vector3(0, -0.02, 1.0)
  add_child(tail)
  _add_tapered(tail, "TailRootTransition", Vector3(0, 0, 0.38), 0.34, 0.46, 0.92, Vector3(90, 0, 0), ORGANIC_BODY, 9)
  var lengths := [0.78, 0.72, 0.65, 0.58]
  var radii := [0.35, 0.3, 0.25, 0.19]
  var parent := tail
  for index in range(lengths.size()):
    var segment := Node3D.new()
    segment.name = "Segment%02d" % (index + 1)
    if index > 0:
      segment.position = Vector3(0, 0, lengths[index - 1] - 0.13)
    parent.add_child(segment)
    _tail_segments.append(segment)
    _add_tapered(segment, "OrganicSegment", Vector3(0, 0, lengths[index] * 0.48), radii[index] * 0.84, radii[index], lengths[index] + 0.16, Vector3(90, 0, 0), ORGANIC_BODY, 9)
    if index in [0, 2]:
      _add_prism(segment, "DorsalTailPlate", Vector3(0, radii[index] * 0.72, lengths[index] * 0.43), Vector3(radii[index] * 1.05, 0.065, lengths[index] * 0.3), Vector3.ZERO, BONE_PLATE)
    parent = segment
  var stabilizers := Node3D.new()
  stabilizers.name = "Stabilizers"
  stabilizers.position = Vector3(0, 0, lengths[-1] - 0.08)
  parent.add_child(stabilizers)
  _add_bone_between(stabilizers, "CentralFilament", Vector3.ZERO, Vector3(0, 0.04, 1.75), 0.035, ARCHITECT_METAL)
  _add_bone_between(stabilizers, "LeftFilament", Vector3.ZERO, Vector3(-0.52, 0.06, 1.48), 0.032, BONE_PLATE)
  _add_bone_between(stabilizers, "RightFilament", Vector3.ZERO, Vector3(0.52, 0.06, 1.48), 0.032, BONE_PLATE)
  _add_membrane(stabilizers, "LeftStabilizer", PackedVector3Array([Vector3(0, 0, 0.18), Vector3(-0.52, 0.06, 1.48), Vector3(-0.06, 0.02, 1.08)]), WING_MEMBRANE)
  _add_membrane(stabilizers, "RightStabilizer", PackedVector3Array([Vector3(0, 0, 0.18), Vector3(0.06, 0.02, 1.08), Vector3(0.52, 0.06, 1.48)]), WING_MEMBRANE)

func _build_legs() -> void:
  var legs := Node3D.new()
  legs.name = "Legs"
  add_child(legs)
  for side in [-1.0, 1.0]:
    var leg := Node3D.new()
    leg.name = "LegLeft" if side < 0.0 else "LegRight"
    leg.position = Vector3(side * 0.42, -0.34, 0.52)
    leg.rotation_degrees.x = 14.0
    legs.add_child(leg)
    _add_bone_between(leg, "Upper", Vector3.ZERO, Vector3(side * 0.1, -0.25, 0.2), 0.065, ORGANIC_BODY)
    _add_bone_between(leg, "Lower", Vector3(side * 0.1, -0.25, 0.2), Vector3(side * 0.07, -0.4, 0.02), 0.045, BONE_PLATE)
    _add_bone_between(leg, "RearClaw", Vector3(side * 0.07, -0.4, 0.02), Vector3(side * 0.07, -0.41, 0.2), 0.02, ARCHITECT_METAL)

func _build_architect_interface() -> void:
  architect_interface = Node3D.new()
  architect_interface.name = "ArchitectInterface"
  architect_interface.position = Vector3(0, 0.48, -0.08)
  architect_interface.set_meta("motif", "SUBTLE_DIVIDED_HALO")
  add_child(architect_interface)
  for side in [-1.0, 1.0]:
    for index in range(3):
      var angle := deg_to_rad(42.0 + index * 31.0)
      var segment_position := Vector3(side * cos(angle) * 0.52, sin(angle) * 0.24, 0)
      _add_box(architect_interface, ("Left" if side < 0 else "Right") + "HaloSegment%02d" % index, segment_position, Vector3(0.12, 0.045, 0.075), Vector3(0, 0, side * (-48.0 + index * 22.0)), ARCHITECT_METAL)
  _add_box(architect_interface, "InterruptedEnergyChannel", Vector3(0, 0.16, -0.03), Vector3(0.055, 0.28, 0.055), Vector3.ZERO, ENERGY)
  _add_box(architect_interface, "WingRootEnergyLeft", Vector3(-0.67, -0.2, -0.38), Vector3(0.12, 0.055, 0.055), Vector3.ZERO, ENERGY)
  _add_box(architect_interface, "WingRootEnergyRight", Vector3(0.67, -0.2, -0.38), Vector3(0.12, 0.055, 0.055), Vector3.ZERO, ENERGY)

func _build_rider_mount() -> void:
  rider_mount = Node3D.new()
  rider_mount.name = "RiderMount"
  rider_mount.position = Vector3(0, 0.45, -0.08)
  add_child(rider_mount)
  _add_prism(rider_mount, "MountCradle", Vector3(0, 0, 0), Vector3(0.58, 0.1, 0.7), Vector3.ZERO, ARCHITECT_METAL)
  _add_box(rider_mount, "InterfaceLeft", Vector3(-0.29, 0.11, -0.08), Vector3(0.05, 0.22, 0.38), Vector3(12, 0, -10), ARCHITECT_METAL)
  _add_box(rider_mount, "InterfaceRight", Vector3(0.29, 0.11, -0.08), Vector3(0.05, 0.22, 0.38), Vector3(12, 0, 10), ARCHITECT_METAL)
  kael_placeholder = Node3D.new()
  kael_placeholder.name = "KaelPlaceholder"
  kael_placeholder.position = Vector3(0, -0.01, -0.03)
  kael_placeholder.rotation_degrees.x = -28.0
  rider_mount.add_child(kael_placeholder)
  _add_capsule(kael_placeholder, "Torso", Vector3(0, 0.34, 0), 0.16, 0.64, Vector3.ZERO, KAEL_MATERIAL)
  _add_sphere(kael_placeholder, "Head", Vector3(0, 0.76, -0.08), 0.16, KAEL_MATERIAL)
  _add_bone_between(kael_placeholder, "LegLeft", Vector3(-0.09, 0.22, 0.02), Vector3(-0.28, -0.08, 0.25), 0.045, KAEL_MATERIAL)
  _add_bone_between(kael_placeholder, "LegRight", Vector3(0.09, 0.22, 0.02), Vector3(0.28, -0.08, 0.25), 0.045, KAEL_MATERIAL)
  _add_bone_between(kael_placeholder, "ArmLeft", Vector3(-0.1, 0.49, -0.04), Vector3(-0.27, 0.2, -0.32), 0.035, KAEL_MATERIAL)
  _add_bone_between(kael_placeholder, "ArmRight", Vector3(0.1, 0.49, -0.04), Vector3(0.27, 0.2, -0.32), 0.035, KAEL_MATERIAL)

func _apply_section_fold(sections: Array[Node3D], side: float, fold: float, spread: float) -> void:
  for index in range(sections.size()):
    var section := sections[index]
    if index == 0:
      section.rotation = Vector3.ZERO
      continue
    var progressive := float(index) / 3.0
    section.rotation = Vector3(
      deg_to_rad(fold * (5.0 + progressive * 8.0)),
      deg_to_rad(side * fold * (12.0 + progressive * 19.0) - side * spread * 4.0),
      deg_to_rad(-side * fold * progressive * 7.0)
    )


func _add_capsule(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, rotation_value: Vector3, material: Material, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
  var mesh := CapsuleMesh.new()
  mesh.radius = radius
  mesh.height = height
  mesh.radial_segments = 10
  mesh.rings = 4
  mesh.material = material
  return _mesh(parent, node_name, position, rotation_value, mesh, scale_value)


func _add_tapered(parent: Node3D, node_name: String, position: Vector3, top_radius: float, bottom_radius: float, height: float, rotation_value: Vector3, material: Material, sides: int) -> MeshInstance3D:
  var mesh := CylinderMesh.new()
  mesh.top_radius = top_radius
  mesh.bottom_radius = bottom_radius
  mesh.height = height
  mesh.radial_segments = sides
  mesh.rings = 1
  mesh.material = material
  return _mesh(parent, node_name, position, rotation_value, mesh)


func _add_prism(parent: Node3D, node_name: String, position: Vector3, size: Vector3, rotation_value: Vector3, material: Material) -> MeshInstance3D:
  var mesh := PrismMesh.new()
  mesh.size = size
  mesh.left_to_right = 0.28
  mesh.material = material
  return _mesh(parent, node_name, position, rotation_value, mesh)


func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, rotation_value: Vector3, material: Material) -> MeshInstance3D:
  var mesh := BoxMesh.new()
  mesh.size = size
  mesh.material = material
  return _mesh(parent, node_name, position, rotation_value, mesh)


func _add_sphere(parent: Node3D, node_name: String, position: Vector3, radius: float, material: Material) -> MeshInstance3D:
  var mesh := SphereMesh.new()
  mesh.radius = radius
  mesh.height = radius * 2.0
  mesh.radial_segments = 8
  mesh.rings = 4
  mesh.material = material
  return _mesh(parent, node_name, position, Vector3.ZERO, mesh)


func _add_bone_between(parent: Node3D, node_name: String, start: Vector3, end: Vector3, radius: float, material: Material) -> MeshInstance3D:
  var direction := end - start
  var mesh := CylinderMesh.new()
  mesh.top_radius = radius * 0.72
  mesh.bottom_radius = radius
  mesh.height = direction.length()
  mesh.radial_segments = 6
  mesh.rings = 1
  mesh.material = material
  var instance := _mesh(parent, node_name, (start + end) * 0.5, Vector3.ZERO, mesh)
  instance.quaternion = Quaternion(Vector3.UP, direction.normalized())
  return instance


func _add_membrane(parent: Node3D, node_name: String, points: PackedVector3Array, material: Material) -> MeshInstance3D:
  var surface := SurfaceTool.new()
  surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  if points.size() == 3:
    for vertex_index in [0, 1, 2]:
      surface.set_normal(Vector3.UP)
      surface.add_vertex(points[vertex_index])
  else:
    for vertex_index in [0, 1, 2, 0, 2, 3]:
      surface.set_normal(Vector3.UP)
      surface.add_vertex(points[vertex_index])
  var mesh := surface.commit()
  mesh.surface_set_material(0, material)
  return _mesh(parent, node_name, Vector3.ZERO, Vector3.ZERO, mesh)


func _mesh(parent: Node3D, node_name: String, position: Vector3, rotation_value: Vector3, mesh: Mesh, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
  var instance := MeshInstance3D.new()
  instance.name = node_name
  instance.position = position
  instance.rotation_degrees = rotation_value
  instance.scale = scale_value
  instance.mesh = mesh
  parent.add_child(instance)
  return instance


func _smooth(response: float, delta: float) -> float:
  return 1.0 - exp(-response * delta)
