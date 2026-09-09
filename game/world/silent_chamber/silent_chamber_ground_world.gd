class_name SilentChamberGroundWorld
extends Node3D

signal chamber_response_changed(responded: bool)
signal inner_door_response_changed(responded: bool)

const LANDING_POSITION := Vector3(278.0, 8.5, -68.0)
const DISMOUNT_POSITION := Vector3(283.0, 5.1, -62.0)
const ENTRANCE_POSITION := Vector3(350.0, 5.1, -68.0)
const RECOVERY_POSITION := Vector3(333.0, 5.1, -68.0)
const ECHO_POSITION := Vector3(555.0, 4.1, -68.0)
const INNER_DOOR_POSITION := Vector3(608.0, 5.0, -68.0)

var landing_zone: Area3D
var mount_zone: Area3D
var inner_door_zone: Area3D
var chamber_responded: bool = false
var inner_door_responded: bool = false
var response_lines: Node3D
var inner_door_fracture: MeshInstance3D
var dormant_door_energy: MeshInstance3D
var main_broken_halo: Node3D
var sealed_slab_visual: MeshInstance3D

var _stone := preload("res://art/sacred_ash/materials/m_architect_dark_stone.tres")
var _metal := preload("res://art/sacred_ash/materials/m_architect_aged_metal.tres")
var _ash := preload("res://art/sacred_ash/materials/m_valley_ash.tres")
var _cyan := preload("res://art/sacred_ash/materials/m_architect_cyan_active.tres")


func _ready() -> void:
  _hide_superseded_flight_markers.call_deferred()
  _build_exterior()
  _build_descent_and_antechamber()
  _build_main_chamber()
  _build_lighting()
  _build_interaction_volumes()
  _build_prologue_reactions()
  reset_prologue_reactions()


func _hide_superseded_flight_markers() -> void:
  var old_chamber := get_node_or_null("../ValleyOfAsh/LostPlaces/SilentChamber")
  if old_chamber != null:
    for node_name in ["EntranceClue00", "EntranceClue01", "EntranceClue02", "CentralMysteriousObject", "InactiveHalo"]:
      var old_visual := old_chamber.get_node_or_null(node_name) as Node3D
      if old_visual != null:
        old_visual.visible = false
  var old_echo_accent := get_node_or_null("../WorldDiscovery/Echoes/LastSignalAccent") as Node3D
  if old_echo_accent != null:
    old_echo_accent.visible = false


func _build_exterior() -> void:
  var exterior := Node3D.new()
  exterior.name = "LandingExterior"
  add_child(exterior)
  _add_box(exterior, "LandingPlatform", Vector3(278, 2.0, -68), Vector3(82, 4, 58), Vector3.ZERO, _ash, true)
  _add_box(exterior, "PlatformLipNorth", Vector3(278, 4.5, -98), Vector3(86, 5, 4), Vector3(0, 0, 2), _metal, true)
  _add_box(exterior, "PlatformLipSouth", Vector3(278, 4.5, -38), Vector3(86, 5, 4), Vector3(0, 0, -3), _metal, true)
  _add_box(exterior, "BrokenPillarNorth", Vector3(318, 15, -101), Vector3(7, 30, 8), Vector3(4, 0, -5), _stone, true)
  _add_box(exterior, "BrokenPillarSouth", Vector3(307, 11, -35), Vector3(8, 22, 7), Vector3(-6, 0, 4), _stone, true)
  _add_box(exterior, "EntranceBladeNorth", Vector3(345, 30, -89), Vector3(8, 60, 9), Vector3(0, 0, -4), _stone, true)
  _add_box(exterior, "EntranceBladeSouth", Vector3(345, 24, -47), Vector3(8, 48, 9), Vector3(0, 0, 6), _stone, true)
  _add_box(exterior, "BrokenArchNorth", Vector3(346, 55, -80), Vector3(10, 8, 24), Vector3(18, 0, 0), _metal, false)
  _add_box(exterior, "BrokenArchSouth", Vector3(346, 49, -55), Vector3(10, 8, 17), Vector3(-22, 0, 0), _metal, false)
  _add_halo(exterior, "DamagedLandingHalo", Vector3(315, 23, -68), 18.0, 2.1, [1, 2, 6], _metal)
  _add_halo(exterior, "ActiveApproachHalo", Vector3(343, 34, -68), 7.0, 0.55, [0, 1, 5, 6, 8], _cyan)


func _build_descent_and_antechamber() -> void:
  var route := Node3D.new()
  route.name = "GroundRoute"
  add_child(route)
  for index in range(5):
    _add_box(route, "DescendingStep%02d" % index, Vector3(374 + index * 12, 3.5 - index * 0.55, -68), Vector3(13, 1.2, 24), Vector3.ZERO, _stone, true)
  _add_box(route, "PassageNorth", Vector3(402, 14, -84), Vector3(72, 28, 7), Vector3.ZERO, _stone, true)
  _add_box(route, "PassageSouth", Vector3(402, 14, -52), Vector3(72, 28, 7), Vector3.ZERO, _stone, true)
  _add_box(route, "PassageRoof", Vector3(402, 27, -68), Vector3(72, 5, 39), Vector3.ZERO, _stone, true)
  _add_box(route, "AnteroomFloor", Vector3(448, -0.4, -68), Vector3(52, 2, 76), Vector3.ZERO, _stone, true)
  _add_box(route, "ReliefNorth", Vector3(446, 13, -101), Vector3(28, 22, 3), Vector3(0, 0, -4), _metal, false)
  _add_box(route, "ReliefSouth", Vector3(454, 10, -35), Vector3(22, 16, 3), Vector3(0, 0, 5), _metal, false)
  _add_halo(route, "InactiveAnteroomHalo", Vector3(463, 14, -68), 10.0, 1.3, [0, 4, 5], _metal)


func _build_main_chamber() -> void:
  var chamber := Node3D.new()
  chamber.name = "MainChamberGroundPass"
  add_child(chamber)
  _add_box(chamber, "ProcessionalFloor", Vector3(525, 3.2, -68), Vector3(150, 1.4, 42), Vector3.ZERO, _stone, true)
  for side in [-1.0, 1.0]:
    for index in range(3):
      _add_box(chamber, ("North" if side < 0 else "South") + "Blade%02d" % index, Vector3(490 + index * 37, 25 + index * 5, -68 + side * 53), Vector3(8, 50 + index * 10, 8), Vector3(0, index * 5, side * (3 + index * 2)), _metal, true)
  _add_halo(chamber, "MainBrokenHalo", Vector3(555, 45, -68), 27.0, 2.7, [1, 5, 6], _metal)
  _add_box(chamber, "EchoPlinth", Vector3(555, 5.0, -68), Vector3(10, 8, 10), Vector3.ZERO, _metal, true)
  _add_box(chamber, "EchoCore", Vector3(555, 11.0, -68), Vector3(2.4, 8, 2.4), Vector3.ZERO, _cyan, false)

  var door := Node3D.new()
  door.name = "InnerDoor"
  door.set_meta("inaccessible", true)
  door.set_meta("observation", "UNKNOWN ARCHITECT STRUCTURE")
  chamber.add_child(door)
  _add_box(door, "SealedSlab", INNER_DOOR_POSITION + Vector3(8, 25, 0), Vector3(7, 50, 62), Vector3.ZERO, _stone, true)
  _add_box(door, "NorthFrame", INNER_DOOR_POSITION + Vector3(4, 28, -35), Vector3(13, 56, 9), Vector3(0, 0, -3), _metal, true)
  _add_box(door, "SouthFrame", INNER_DOOR_POSITION + Vector3(4, 28, 35), Vector3(13, 56, 9), Vector3(0, 0, 3), _metal, true)
  _add_box(door, "Crown", INNER_DOOR_POSITION + Vector3(4, 56, 0), Vector3(13, 9, 78), Vector3.ZERO, _metal, true)
  _add_halo(door, "IncompleteDividedHalo", INNER_DOOR_POSITION + Vector3(0, 29, 0), 19.0, 2.0, [0, 3, 7], _metal)
  _add_box(door, "DormantEnergy", INNER_DOOR_POSITION + Vector3(-0.1, 29, 0), Vector3(0.4, 28, 0.7), Vector3.ZERO, _cyan, false)


func _build_lighting() -> void:
  var lighting := Node3D.new()
  lighting.name = "InteriorLighting"
  add_child(lighting)
  var entrance_light := OmniLight3D.new()
  entrance_light.name = "EntranceBounce"
  entrance_light.position = Vector3(405, 15, -68)
  entrance_light.light_color = Color(0.64, 0.56, 0.46)
  entrance_light.light_energy = 1.1
  entrance_light.omni_range = 58.0
  entrance_light.shadow_enabled = false
  lighting.add_child(entrance_light)
  var chamber_light := OmniLight3D.new()
  chamber_light.name = "MainChamberCoolLight"
  chamber_light.position = Vector3(555, 28, -68)
  chamber_light.light_color = Color(0.29, 0.43, 0.48)
  chamber_light.light_energy = 1.35
  chamber_light.omni_range = 76.0
  chamber_light.shadow_enabled = false
  lighting.add_child(chamber_light)


func _build_interaction_volumes() -> void:
  landing_zone = _area("LandingZone", Vector3(278, 20, -68), Vector3(90, 42, 68))
  mount_zone = _area("MountZone", DISMOUNT_POSITION, Vector3(13, 6, 13))
  inner_door_zone = _area("InnerDoorObservation", INNER_DOOR_POSITION, Vector3(15, 10, 30))


func _area(node_name: String, position: Vector3, size: Vector3) -> Area3D:
  var area := Area3D.new()
  area.name = node_name
  area.position = position
  area.collision_layer = 0
  area.collision_mask = 2
  var collision := CollisionShape3D.new()
  collision.name = "Volume"
  var shape := BoxShape3D.new()
  shape.size = size
  collision.shape = shape
  area.add_child(collision)
  add_child(area)
  return area


func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, rotation_value: Vector3, material: Material, collision_enabled: bool) -> void:
  var mesh_instance := MeshInstance3D.new()
  mesh_instance.name = node_name
  mesh_instance.position = position
  mesh_instance.rotation_degrees = rotation_value
  var mesh := BoxMesh.new()
  mesh.size = size
  mesh.material = material
  mesh_instance.mesh = mesh
  parent.add_child(mesh_instance)
  if collision_enabled:
    var body := StaticBody3D.new()
    body.name = "%sCollision" % node_name
    body.position = position
    body.rotation_degrees = rotation_value
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    shape_node.shape = shape
    body.add_child(shape_node)
    parent.add_child(body)


func _add_halo(parent: Node3D, node_name: String, center: Vector3, radius: float, thickness: float, gaps: Array, material: Material) -> void:
  var halo := Node3D.new()
  halo.name = node_name
  parent.add_child(halo)
  for index in range(10):
    if index in gaps:
      continue
    var angle := TAU * float(index) / 10.0
    var segment := MeshInstance3D.new()
    segment.name = "Segment%02d" % index
    segment.position = center + Vector3(0, sin(angle) * radius, cos(angle) * radius)
    segment.rotation_degrees.x = rad_to_deg(-angle)
    var mesh := BoxMesh.new()
    mesh.size = Vector3(thickness, radius * 0.66, thickness)
    mesh.material = material
    segment.mesh = mesh
    halo.add_child(segment)


func set_chamber_responded(responded: bool) -> void:
  if chamber_responded == responded and response_lines.visible == responded:
    return
  chamber_responded = responded
  response_lines.visible = responded
  main_broken_halo.rotation_degrees.x = 4.0 if responded else 0.0
  if responded:
    var tween := main_broken_halo.create_tween()
    tween.tween_property(main_broken_halo, "rotation_degrees:x", 4.0, 1.2).from(-3.0)
  chamber_response_changed.emit(responded)


func set_inner_door_responded(responded: bool) -> void:
  if inner_door_responded == responded and inner_door_fracture.visible == responded:
    return
  inner_door_responded = responded
  inner_door_fracture.visible = responded
  dormant_door_energy.visible = responded
  sealed_slab_visual.position.x = INNER_DOOR_POSITION.x + 8.45 if responded else INNER_DOOR_POSITION.x + 8.0
  inner_door_response_changed.emit(responded)


func reset_prologue_reactions() -> void:
  chamber_responded = false
  inner_door_responded = false
  if response_lines == null:
    return
  response_lines.visible = false
  inner_door_fracture.visible = false
  dormant_door_energy.visible = false
  main_broken_halo.rotation_degrees.x = 0.0
  sealed_slab_visual.position.x = INNER_DOOR_POSITION.x + 8.0


func _build_prologue_reactions() -> void:
  response_lines = Node3D.new()
  response_lines.name = "ArchitectResponseLines"
  add_child(response_lines)
  for index in range(5):
    _add_box(
      response_lines,
      "ResponseLine%02d" % index,
      Vector3(486.0 + index * 22.0, 4.05, -68.0 + (-1.0 if index % 2 == 0 else 1.0) * 13.0),
      Vector3(16.0, 0.12, 0.38),
      Vector3.ZERO,
      _cyan,
      false
    )
  var door := get_node("MainChamberGroundPass/InnerDoor") as Node3D
  _add_box(door, "InnerDoorFracture", INNER_DOOR_POSITION + Vector3(-0.35, 29, 0), Vector3(0.22, 31, 0.3), Vector3.ZERO, _cyan, false)
  inner_door_fracture = door.get_node("InnerDoorFracture") as MeshInstance3D
  dormant_door_energy = door.get_node("DormantEnergy") as MeshInstance3D
  sealed_slab_visual = door.get_node("SealedSlab") as MeshInstance3D
  main_broken_halo = get_node("MainChamberGroundPass/MainBrokenHalo") as Node3D