class_name ValleyDiscoveryLayer
extends Node3D

const REGION_CENTRAL_CANYON: DiscoveryData = preload("res://systems/discovery/data/region_central_canyon.tres")
const REGION_ASH_BASIN: DiscoveryData = preload("res://systems/discovery/data/region_ash_basin.tres")
const REGION_BROKEN_PLATEAU: DiscoveryData = preload("res://systems/discovery/data/region_broken_plateau.tres")
const REGION_RUIN_FIELD: DiscoveryData = preload("res://systems/discovery/data/region_ruin_field.tres")
const LANDMARK_SPIRE: DiscoveryData = preload("res://systems/discovery/data/landmark_spire.tres")
const LANDMARK_ANCIENT_GATE: DiscoveryData = preload("res://systems/discovery/data/landmark_ancient_gate.tres")
const LANDMARK_CRASHED_COLOSSUS: DiscoveryData = preload("res://systems/discovery/data/landmark_crashed_colossus.tres")
const LANDMARK_UNBROKEN_MONOLITH: DiscoveryData = preload("res://systems/discovery/data/landmark_unbroken_monolith.tres")
const LOSTPLACE_SILENT_CHAMBER: DiscoveryData = preload("res://systems/discovery/data/lostplace_silent_chamber.tres")
const ECHO_LAST_SIGNAL: DiscoveryData = preload("res://systems/discovery/data/echo_last_signal.tres")
const ANOMALY_STILL_WIND: DiscoveryData = preload("res://systems/discovery/data/anomaly_still_wind.tres")

@export_node_path("DiscoveryManager") var discovery_manager_path: NodePath

var discovery_manager: DiscoveryManager


func _ready() -> void:
  discovery_manager = get_node_or_null(discovery_manager_path) as DiscoveryManager
  if discovery_manager == null:
    push_error("ValleyDiscoveryLayer requires a DiscoveryManager.")
    return

  var regions := _add_group("Regions")
  var landmarks := _add_group("Landmarks")
  var lost_places := _add_group("LostPlaces")
  var echoes := _add_group("Echoes")
  var anomalies := _add_group("Anomalies")

  _add_point(regions, "CentralCanyon", REGION_CENTRAL_CANYON, Vector3(95, 80, 0), _box_shape(Vector3(350, 220, 900)))
  _add_point(regions, "AshBasin", REGION_ASH_BASIN, Vector3(-470, 75, 225), _box_shape(Vector3(440, 190, 430)))
  _add_point(regions, "BrokenPlateau", REGION_BROKEN_PLATEAU, Vector3(430, 170, -315), _box_shape(Vector3(410, 300, 370)))
  _add_point(regions, "RuinField", REGION_RUIN_FIELD, Vector3(-450, 95, -270), _box_shape(Vector3(520, 230, 470)))

  _add_point(landmarks, "Spire", LANDMARK_SPIRE, Vector3(0, 175, -650), _sphere_shape(175))
  _add_point(landmarks, "AncientGate", LANDMARK_ANCIENT_GATE, Vector3(273, 78, 305), _sphere_shape(125))
  _add_point(landmarks, "CrashedColossus", LANDMARK_CRASHED_COLOSSUS, Vector3(-665, 105, -405), _sphere_shape(135))
  _add_point(landmarks, "UnbrokenMonolith", LANDMARK_UNBROKEN_MONOLITH, Vector3(590, 210, -465), _sphere_shape(90))

  _add_point(
    lost_places,
    "SilentChamber",
    LOSTPLACE_SILENT_CHAMBER,
    Vector3(535, 52, -68),
    _box_shape(Vector3(190, 115, 145))
  )
  _add_point(
    echoes,
    "LastSignal",
    ECHO_LAST_SIGNAL,
    Vector3(555, 11, -68),
    _sphere_shape(14),
    true
  )
  _add_echo_accent(echoes)
  _add_still_wind(anomalies)


func _add_group(group_name: String) -> Node3D:
  var group := Node3D.new()
  group.name = group_name
  add_child(group)
  return group


func _add_point(
  parent: Node3D,
  point_name: String,
  data: DiscoveryData,
  world_position: Vector3,
  shape: Shape3D,
  requires_interaction: bool = false
) -> DiscoveryPoint:
  var point := DiscoveryPoint.new()
  point.name = point_name
  point.position = world_position
  point.configure(data, discovery_manager, requires_interaction)
  var collision_shape := CollisionShape3D.new()
  collision_shape.name = "DiscoveryVolume"
  collision_shape.shape = shape
  point.add_child(collision_shape)
  parent.add_child(point)
  return point


func _add_echo_accent(parent: Node3D) -> void:
  var accent := MeshInstance3D.new()
  accent.name = "LastSignalAccent"
  accent.position = Vector3(555, 76, -68)
  var mesh := SphereMesh.new()
  mesh.radius = 4.5
  mesh.height = 9.0
  var material := _make_active_material(Color(0.08, 0.68, 0.78), 3.0)
  mesh.material = material
  accent.mesh = mesh
  parent.add_child(accent)


func _add_still_wind(parent: Node3D) -> void:
  var anomaly := StillWindAnomaly.new()
  anomaly.name = "StillWind"
  anomaly.position = Vector3(-585, 78, 535)
  anomaly.configure(ANOMALY_STILL_WIND, discovery_manager)
  var collision_shape := CollisionShape3D.new()
  collision_shape.name = "DiscoveryVolume"
  collision_shape.shape = _sphere_shape(72)
  anomaly.add_child(collision_shape)

  var fragment_material := _make_active_material(Color(0.20, 0.48, 0.52), 1.1)
  var fragment_data := [
    [Vector3(-28, 8, -12), Vector3(12, 4, 8), Vector3(12, 25, 8)],
    [Vector3(22, 24, -18), Vector3(8, 13, 5), Vector3(-20, 8, 35)],
    [Vector3(7, -12, 30), Vector3(18, 5, 7), Vector3(8, -32, -12)],
    [Vector3(-12, 35, 20), Vector3(6, 18, 6), Vector3(25, 12, -18)],
    [Vector3(34, -4, 12), Vector3(9, 7, 16), Vector3(-8, 40, 22)],
  ]
  for index in range(fragment_data.size()):
    var entry: Array = fragment_data[index]
    var fragment := MeshInstance3D.new()
    fragment.name = "SuspendedFragment%02d" % index
    fragment.position = entry[0]
    fragment.rotation_degrees = entry[2]
    var mesh := BoxMesh.new()
    mesh.size = entry[1]
    mesh.material = fragment_material
    fragment.mesh = mesh
    anomaly.add_child(fragment)
  parent.add_child(anomaly)


func _box_shape(size: Vector3) -> BoxShape3D:
  var shape := BoxShape3D.new()
  shape.size = size
  return shape


func _sphere_shape(radius: float) -> SphereShape3D:
  var shape := SphereShape3D.new()
  shape.radius = radius
  return shape


func _make_active_material(color: Color, energy: float) -> StandardMaterial3D:
  var material := StandardMaterial3D.new()
  material.albedo_color = color
  material.roughness = 0.48
  material.metallic = 0.18
  material.emission_enabled = true
  material.emission = color
  material.emission_energy_multiplier = energy
  return material
