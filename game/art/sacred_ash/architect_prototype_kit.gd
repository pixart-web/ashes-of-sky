class_name ArchitectPrototypeKit
extends RefCounted


static func monumental_arch(node_name: String, dark: Material, metal: Material) -> Node3D:
  var root := _module(node_name, "ARCH_01_MONUMENTAL_ARCH")
  _add_tapered(root, "WestTaperedPier", Vector3(-34, 42, 0), 11, 16, 84, dark, Vector3(0, 0, -4))
  _add_tapered(root, "EastTaperedPier", Vector3(34, 36, 0), 10, 15, 72, dark, Vector3(0, 0, 5))
  _add_arc(root, "FracturedCrown", Vector3(0, 42, 0), 35, 6, 9, [0, 1, 7], metal)
  _add_prism(root, "CrownShard", Vector3(18, 73, 0), Vector3(24, 11, 13), Vector3(0, 0, 24), dark)
  root.set_meta("negative_space", "tall recessed traversable opening")
  return root


static func vertical_blade(node_name: String, dark: Material, channel: Material, active: bool = false) -> Node3D:
  var root := _module(node_name, "ARCH_02_VERTICAL_BLADE")
  _add_prism(root, "SteppedFoundation", Vector3(0, 5, 0), Vector3(28, 10, 24), Vector3.ZERO, dark)
  _add_tapered(root, "TaperedBody", Vector3(0, 55, 0), 7, 13, 100, dark)
  _add_prism(root, "SplitCrown", Vector3(-3, 108, 0), Vector3(15, 18, 16), Vector3(0, 0, -12), dark)
  _add_box(root, "RecessedChannel", Vector3(0, 57, -7.1), Vector3(1.2, 58, 0.55), Vector3.ZERO, channel)
  root.set_meta("energy_state", "inactive_or_dormant" if not active else "active")
  return root


static func broken_wall(node_name: String, dark: Material, metal: Material) -> Node3D:
  var root := _module(node_name, "ARCH_03_BROKEN_WALL")
  _add_prism(root, "WestFracturedMass", Vector3(-32, 25, 0), Vector3(34, 50, 16), Vector3(0, 0, -7), dark)
  _add_prism(root, "EastFracturedMass", Vector3(34, 18, 2), Vector3(25, 36, 14), Vector3(0, 4, 11), dark)
  _add_prism(root, "UpperFloatingEdge", Vector3(8, 55, 0), Vector3(38, 11, 14), Vector3(0, 0, 15), metal)
  _add_prism(root, "BuriedShard", Vector3(-2, 7, 8), Vector3(19, 22, 18), Vector3(24, -8, 68), metal)
  root.set_meta("negative_space", "irregular central breach")
  return root


static func divided_halo(node_name: String, dark: Material, metal: Material, variant: String = "broken") -> Node3D:
  var root := _module(node_name, "ARCH_04_DIVIDED_HALO")
  var missing: Array = [1, 2, 8, 9] if variant == "broken" else []
  if variant == "buried":
    missing = [0, 1, 2, 3, 8, 9]
    root.rotation_degrees.z = -14
  _add_ring(root, "HaloSegments", 31, 4.5, 14, missing, metal)
  _add_tapered(root, "DividingBlade", Vector3(0, 0, 0), 3.5, 6, 75, dark)
  root.set_meta("architect_motif", "THE DIVIDED HALO")
  root.set_meta("motif_state", variant)
  return root


static func architect_pillar(node_name: String, dark: Material, metal: Material) -> Node3D:
  var root := _module(node_name, "ARCH_05_ARCHITECT_PILLAR")
  _add_prism(root, "WideFoundation", Vector3(0, 5, 0), Vector3(30, 10, 26), Vector3.ZERO, dark)
  _add_prism(root, "SteppedPlinth", Vector3(0, 13, 0), Vector3(21, 8, 20), Vector3.ZERO, metal)
  _add_tapered(root, "CeremonialBody", Vector3(0, 54, 0), 5, 9, 78, dark)
  _add_prism(root, "ForkedCrownLeft", Vector3(-6, 97, 0), Vector3(9, 18, 13), Vector3(0, 0, -15), metal)
  _add_prism(root, "ForkedCrownRight", Vector3(6, 94, 0), Vector3(8, 14, 12), Vector3(0, 0, 18), dark)
  return root


static func collapsed_monument(node_name: String, dark: Material, metal: Material) -> Node3D:
  var root := _module(node_name, "ARCH_06_COLLAPSED_MONUMENT")
  var fallen := Node3D.new()
  fallen.name = "DiagonalMonument"
  fallen.rotation_degrees = Vector3(8, -18, 63)
  root.add_child(fallen)
  _add_tapered(fallen, "FallenCore", Vector3(0, 42, 0), 8, 14, 88, dark)
  _add_prism(fallen, "ShatteredCrown", Vector3(0, 91, 0), Vector3(24, 18, 22), Vector3(4, 0, 13), metal)
  _add_arc(root, "BuriedHaloFragment", Vector3(14, 12, 5), 27, 4, 10, [0, 1, 2, 3, 7], metal)
  root.set_meta("silhouette", "partially buried diagonal ruin")
  return root


static func gate_module(node_name: String, dark: Material, metal: Material) -> Node3D:
  var root := _module(node_name, "ARCH_07_GATE_MODULE")
  var west := vertical_blade("WestGateBlade", dark, metal)
  west.position = Vector3(-47, 0, 0)
  west.scale = Vector3(0.85, 1.18, 0.85)
  root.add_child(west)
  var east := vertical_blade("EastGateBlade", dark, metal)
  east.position = Vector3(47, 0, 0)
  east.scale = Vector3(0.82, 0.96, 0.82)
  root.add_child(east)
  _add_arc(root, "OpenGateCrown", Vector3(0, 70, 0), 49, 6, 12, [0, 1, 2, 9], metal)
  root.set_meta("negative_space", "large fly-through opening")
  return root


static func spire_module(node_name: String, dark: Material, metal: Material, cyan: Material) -> Node3D:
  var root := _module(node_name, "ARCH_08_SPIRE_MODULE")
  _add_tapered(root, "DominantVerticalCore", Vector3(0, 150, 0), 17, 34, 300, dark)
  _add_prism(root, "WestFracturedMass", Vector3(-55, 116, 1), Vector3(34, 150, 40), Vector3(0, -7, 13), metal)
  _add_prism(root, "EastFracturedMass", Vector3(48, 173, -2), Vector3(28, 112, 35), Vector3(0, 8, -16), dark)
  _add_prism(root, "LowerFracturedMass", Vector3(43, 64, 8), Vector3(45, 54, 42), Vector3(10, -12, 22), metal)
  var iconic_halo := _add_ring(root, "IconicBrokenHalo", 92, 9, 24, [1, 2, 3, 14, 15, 21], metal)
  iconic_halo.position = Vector3(0, 165, 0)
  _add_box(root, "SmallCyanCore", Vector3(0, 167, -18.2), Vector3(1.4, 92, 0.65), Vector3.ZERO, cyan)
  root.set_meta("silhouette", "one core one halo three fractured masses")
  return root


static func _module(node_name: String, module_id: String) -> Node3D:
  var root := Node3D.new()
  root.name = node_name
  root.set_meta("architect_module", module_id)
  return root


static func _add_tapered(parent: Node3D, node_name: String, position: Vector3, top_radius: float, bottom_radius: float, height: float, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
  var mesh := CylinderMesh.new()
  mesh.top_radius = top_radius
  mesh.bottom_radius = bottom_radius
  mesh.height = height
  mesh.radial_segments = 5
  mesh.rings = 1
  mesh.material = material
  return _mesh(parent, node_name, position, rotation_value, mesh)


static func _add_prism(parent: Node3D, node_name: String, position: Vector3, size: Vector3, rotation_value: Vector3, material: Material) -> MeshInstance3D:
  var mesh := PrismMesh.new()
  mesh.size = size
  mesh.left_to_right = 0.28
  mesh.material = material
  return _mesh(parent, node_name, position, rotation_value, mesh)


static func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, rotation_value: Vector3, material: Material) -> MeshInstance3D:
  var mesh := BoxMesh.new()
  mesh.size = size
  mesh.material = material
  return _mesh(parent, node_name, position, rotation_value, mesh)


static func _add_arc(parent: Node3D, node_name: String, center: Vector3, radius: float, thickness: float, segment_count: int, missing: Array, material: Material) -> Node3D:
  var arc := Node3D.new()
  arc.name = node_name
  arc.position = center
  parent.add_child(arc)
  var segment_size := Vector3(PI * radius / float(segment_count) * 0.9, thickness, thickness * 1.5)
  for index in range(segment_count):
    if index in missing:
      continue
    var angle := PI * float(index) / float(segment_count - 1)
    _add_box(arc, "Segment%02d" % index, Vector3(cos(angle) * radius, sin(angle) * radius, 0), segment_size, Vector3(0, 0, rad_to_deg(angle) - 90), material)
  return arc


static func _add_ring(parent: Node3D, node_name: String, radius: float, thickness: float, segment_count: int, missing: Array, material: Material) -> Node3D:
  var ring := Node3D.new()
  ring.name = node_name
  parent.add_child(ring)
  var segment_size := Vector3(TAU * radius / float(segment_count) * 0.88, thickness, thickness)
  for index in range(segment_count):
    if index in missing:
      continue
    var angle := TAU * float(index) / float(segment_count)
    _add_box(ring, "Segment%02d" % index, Vector3(cos(angle) * radius, sin(angle) * radius, 0), segment_size, Vector3(0, 0, rad_to_deg(angle) + 90), material)
  return ring


static func _mesh(parent: Node3D, node_name: String, position: Vector3, rotation_value: Vector3, mesh: Mesh) -> MeshInstance3D:
  var instance := MeshInstance3D.new()
  instance.name = node_name
  instance.position = position
  instance.rotation_degrees = rotation_value
  instance.mesh = mesh
  parent.add_child(instance)
  return instance
