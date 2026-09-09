class_name ValleyOfAsh
extends Node3D

signal world_navigation_updated(region: StringName, position: Vector3, distance_to_spire: float)
signal spire_state_changed(state_id: StringName)

enum SpireState { DORMANT, AWAKENED, SIGNAL }

const SPAWN_POSITION := Vector3(0.0, 150.0, 650.0)
const SPIRE_POSITION := Vector3(0.0, 0.0, -650.0)
const M_ARCHITECT_DARK_STONE := preload("res://art/sacred_ash/materials/m_architect_dark_stone.tres")
const M_ARCHITECT_AGED_METAL := preload("res://art/sacred_ash/materials/m_architect_aged_metal.tres")
const M_ARCHITECT_CYAN_ACTIVE := preload("res://art/sacred_ash/materials/m_architect_cyan_active.tres")
const M_VALLEY_ASH := preload("res://art/sacred_ash/materials/m_valley_ash.tres")
const M_VALLEY_ROCK := preload("res://art/sacred_ash/materials/m_valley_rock.tres")

@export_node_path("CharacterBody3D") var flight_player_path: NodePath
@export var out_of_bounds_radius: float = 1150.0
@export var minimum_world_height: float = -100.0
@export var maximum_world_height: float = 650.0
@export var navigation_readout_enabled: bool = true

var flight_player: LunarisFlightController
var spire_state: SpireState = SpireState.DORMANT
var spire_activation_core: Node3D
var spire_signal_halo: Node3D
var spire_focus_target: Marker3D

var _terrain_material: StandardMaterial3D
var _rock_material: StandardMaterial3D
var _ruin_material: StandardMaterial3D
var _dark_ruin_material: StandardMaterial3D
var _active_material: StandardMaterial3D
var _preserved_material: StandardMaterial3D


func _ready() -> void:
  _create_materials()
  _build_world()
  flight_player = get_node_or_null(flight_player_path) as LunarisFlightController
  if flight_player == null:
    push_error("ValleyOfAsh requires a Lunaris flight player.")


func _physics_process(_delta: float) -> void:
  if flight_player == null:
    return

  var position := flight_player.global_position
  var horizontal_distance := Vector2(position.x, position.z).length()
  if (
    horizontal_distance > out_of_bounds_radius
    or position.y < minimum_world_height
    or position.y > maximum_world_height
  ):
    _reset_flight_player()
    position = flight_player.global_position

  if navigation_readout_enabled:
    world_navigation_updated.emit(
      get_region_name(position),
      position,
      Vector2(position.x - SPIRE_POSITION.x, position.z - SPIRE_POSITION.z).length()
    )


func get_region_name(position: Vector3) -> StringName:
  if position.x > 390.0 and position.z > -260.0 and position.z < 40.0:
    return &"THE SILENT CHAMBER"
  if position.z > 500.0:
    return &"STARTING CLIFF"
  if Vector2(position.x, position.z + 650.0).length() < 190.0:
    return &"THE SPIRE"
  if position.x > 190.0 and position.z < -80.0:
    return &"BROKEN PLATEAU"
  if position.x < -180.0 and position.z < 60.0:
    return &"RUIN FIELD"
  if position.x < -170.0 and position.z >= 60.0:
    return &"ASH BASIN"
  if position.x > 150.0 and position.z > 80.0:
    return &"ANCIENT GATE"
  if position.z > -480.0 and position.z < 470.0:
    return &"CENTRAL CANYON"
  return &"VALLEY EXPANSE"


func _reset_flight_player() -> void:
  flight_player.reset_flight(Transform3D(Basis.IDENTITY, SPAWN_POSITION))


func _create_materials() -> void:
  _terrain_material = M_VALLEY_ASH
  _rock_material = M_VALLEY_ROCK
  _ruin_material = M_ARCHITECT_AGED_METAL
  _dark_ruin_material = M_ARCHITECT_DARK_STONE
  _preserved_material = M_ARCHITECT_AGED_METAL
  _active_material = M_ARCHITECT_CYAN_ACTIVE


func _build_world() -> void:
  _build_terrain()
  _build_starting_cliff()
  _build_central_canyon()
  _build_ash_basin()
  _build_broken_plateau()
  _build_ruin_field()
  _build_ancient_gate()
  _build_spire()
  _build_lost_places()
  _build_story_moments()
  _build_routes()


func _build_terrain() -> void:
  var terrain := Node3D.new()
  terrain.name = "Terrain"
  add_child(terrain)

  _add_box(terrain, "ValleyFloor", Vector3(0, -5, 0), Vector3(1700, 10, 1700), Vector3.ZERO, _terrain_material)

  var boundary_data := [
    [Vector3(-820, 90, -620), Vector3(180, 200, 420), Vector3(0, -8, 4)],
    [Vector3(-840, 120, -180), Vector3(150, 260, 470), Vector3(0, 5, -6)],
    [Vector3(-820, 95, 300), Vector3(190, 210, 430), Vector3(0, -6, 5)],
    [Vector3(-760, 120, 690), Vector3(300, 260, 220), Vector3(0, 12, 0)],
    [Vector3(820, 105, -620), Vector3(190, 230, 430), Vector3(0, 10, -5)],
    [Vector3(845, 130, -170), Vector3(150, 280, 470), Vector3(0, -5, 7)],
    [Vector3(825, 100, 310), Vector3(190, 220, 440), Vector3(0, 8, -4)],
    [Vector3(760, 120, 700), Vector3(310, 260, 220), Vector3(0, -10, 0)],
    [Vector3(-570, 110, -820), Vector3(430, 240, 170), Vector3(0, 6, 0)],
    [Vector3(-130, 95, -845), Vector3(460, 210, 145), Vector3(0, -3, 0)],
    [Vector3(380, 115, -825), Vector3(500, 250, 170), Vector3(0, 5, 0)],
  ]
  for index in range(boundary_data.size()):
    var entry: Array = boundary_data[index]
    _add_box(
      terrain,
      "BoundaryRidge%02d" % index,
      entry[0],
      entry[1],
      entry[2],
      _rock_material
    )

  var speed_markers := Node3D.new()
  speed_markers.name = "SpeedMarkers"
  terrain.add_child(speed_markers)
  for index in range(4):
    _add_cylinder(
      speed_markers,
      "RouteNeedle%02d" % index,
      Vector3(-55.0 + index * 34.0, 20.0 + index * 3.0, 500.0 - index * 70.0),
      3.0 + index * 0.5,
      40.0 + index * 6.0,
      Vector3(index * 2.0, index * -5.0, index * 3.0),
      _rock_material,
      false
    )


func _build_starting_cliff() -> void:
  var region := _add_region("StartingCliff", "secondary")
  _add_box(region, "CliffMass", Vector3(0, 67, 720), Vector3(430, 134, 280), Vector3.ZERO, _rock_material)
  _add_box(region, "LaunchShelf", Vector3(0, 138, 574), Vector3(116, 12, 74), Vector3(0, 0, -2), _terrain_material)
  _add_box(region, "BrokenRockLipWest", Vector3(-92, 132, 585), Vector3(72, 28, 55), Vector3(5, -12, 7), _rock_material)
  _add_box(region, "BrokenRockLipEast", Vector3(105, 128, 594), Vector3(64, 24, 68), Vector3(-4, 15, -6), _rock_material)

func _build_central_canyon() -> void:
  var region := _add_region("CentralCanyon", "secondary")
  region.set_meta("composition", "open monumental ruin field")
  region.set_meta("minimum_visual_corridor_width", 260.0)
  var west_buttresses := [
    [Vector3(-235, 39, 390), Vector3(78, 82, 96), Vector3(0, -11, -5)],
    [Vector3(-275, 48, 155), Vector3(92, 102, 88), Vector3(0, 13, 4)],
    [Vector3(-240, 34, -95), Vector3(68, 72, 104), Vector3(0, -7, -8)],
    [Vector3(-285, 52, -345), Vector3(86, 110, 92), Vector3(0, 16, 5)],
  ]
  var east_buttresses := [
    [Vector3(250, 43, 315), Vector3(84, 90, 92), Vector3(0, 9, 5)],
    [Vector3(290, 35, 40), Vector3(72, 74, 105), Vector3(0, -14, -6)],
    [Vector3(245, 49, -205), Vector3(94, 104, 86), Vector3(0, 8, 7)],
    [Vector3(300, 37, -430), Vector3(70, 78, 100), Vector3(0, -12, -5)],
  ]
  for index in range(west_buttresses.size()):
    var west: Array = west_buttresses[index]
    _add_box(region, "WestButtress%02d" % index, west[0], west[1], west[2], _rock_material)
  for index in range(east_buttresses.size()):
    var east: Array = east_buttresses[index]
    _add_box(region, "EastButtress%02d" % index, east[0], east[1], east[2], _rock_material)
  _add_box(region, "FallenBridgeWest", Vector3(-152, 20, 108), Vector3(105, 15, 27), Vector3(12, 10, -18), _rock_material)
  _add_box(region, "FallenBridgeEast", Vector3(175, 17, -260), Vector3(88, 14, 25), Vector3(-9, -14, 21), _rock_material)

func _build_ash_basin() -> void:
  var region := _add_region("AshBasin", "secondary")
  _add_box(region, "BasinShelf", Vector3(-470, 4, 245), Vector3(480, 8, 470), Vector3.ZERO, _terrain_material)
  _add_cylinder(region, "DistantRibA", Vector3(-650, 42, 120), 13, 125, Vector3(0, 0, 68), _dark_ruin_material, false)
  _add_cylinder(region, "DistantRibB", Vector3(-590, 38, 50), 10, 110, Vector3(12, 0, 60), _dark_ruin_material, false)
  _add_cylinder(region, "DistantRibC", Vector3(-700, 52, 330), 16, 145, Vector3(-8, 0, 72), _dark_ruin_material, false)
  _add_box(region, "LonelyMarker", Vector3(-390, 28, 395), Vector3(14, 56, 14), Vector3(5, 0, -3), _ruin_material)


func _build_broken_plateau() -> void:
  var region := _add_region("BrokenPlateau", "secondary")
  _add_box(region, "PlateauMass", Vector3(430, 70, -315), Vector3(390, 140, 350), Vector3(0, -4, 0), _rock_material)
  _add_box(region, "UpperShelf", Vector3(390, 151, -340), Vector3(250, 24, 215), Vector3(0, 7, 0), _terrain_material)
  _add_box(region, "ClimbStepSouth", Vector3(310, 75, -110), Vector3(170, 55, 105), Vector3(0, -8, 0), _rock_material)
  _add_box(region, "ClimbStepEast", Vector3(600, 110, -190), Vector3(120, 80, 150), Vector3(0, 12, 0), _rock_material)
  for index in range(5):
    _add_cylinder(
      region,
      "PlateauPillar%02d" % index,
      Vector3(320 + index * 48, 193 + (index % 2) * 15, -390 + (index % 3) * 55),
      7,
      70 + (index % 2) * 30,
      Vector3(index * 3, index * 11, -5 + index * 2),
      _ruin_material,
      index < 3
    )
  _add_box(region, "SuspendedPlateauFragment", Vector3(525, 245, -445), Vector3(42, 18, 70), Vector3(12, -18, 8), _dark_ruin_material, false)


func _build_ruin_field() -> void:
  var region := _add_region("RuinField", "secondary")
  var positions := [
    Vector3(-520, 40, -30), Vector3(-430, 55, -75), Vector3(-330, 36, -40),
    Vector3(-590, 48, -165), Vector3(-470, 64, -190), Vector3(-350, 45, -170),
    Vector3(-620, 38, -310), Vector3(-505, 58, -335), Vector3(-385, 42, -300),
    Vector3(-280, 52, -260), Vector3(-545, 47, -450), Vector3(-400, 60, -440),
  ]
  for index in range(positions.size()):
    var position: Vector3 = positions[index]
    var height := 58.0 + float(index % 4) * 18.0
    _add_box(
      region,
      "WeavingTower%02d" % index,
      Vector3(position.x, height * 0.5, position.z),
      Vector3(18 + index % 2 * 7, height, 18 + (index + 1) % 2 * 7),
      Vector3(index % 3 * 3, index * 13, -6 + index % 4 * 4),
      _ruin_material
    )
  _add_box(region, "WeavingArchWest", Vector3(-480, 43, -250), Vector3(16, 86, 16), Vector3.ZERO, _dark_ruin_material)
  _add_box(region, "WeavingArchEast", Vector3(-405, 43, -250), Vector3(16, 86, 16), Vector3.ZERO, _dark_ruin_material)
  _add_box(region, "WeavingArchTop", Vector3(-442, 88, -250), Vector3(92, 15, 16), Vector3(0, 0, 4), _dark_ruin_material)
  _add_box(region, "SuspendedFragmentA", Vector3(-335, 115, -120), Vector3(38, 12, 55), Vector3(16, 22, 8), _dark_ruin_material, false)
  _add_box(region, "SuspendedFragmentB", Vector3(-555, 128, -375), Vector3(50, 14, 32), Vector3(-10, -15, 18), _dark_ruin_material, false)


func _build_ancient_gate() -> void:
  var region := _add_region("AncientGate", "secondary")
  region.set_meta("conceptual_height_m", 135)
  region.set_meta("composition", "open traversable broken gate")
  _add_box(region, "WestPier", Vector3(215, 58, 305), Vector3(25, 116, 38), Vector3(0, 4, -5), _dark_ruin_material)
  _add_box(region, "EastPier", Vector3(338, 64, 305), Vector3(28, 128, 42), Vector3(0, -5, 6), _dark_ruin_material)
  _add_box(region, "FracturedCrownWest", Vector3(238, 122, 305), Vector3(52, 17, 34), Vector3(0, 0, 15), _ruin_material, false)
  _add_box(region, "FracturedCrownEast", Vector3(319, 133, 305), Vector3(48, 17, 34), Vector3(0, 0, -18), _ruin_material, false)
  _add_box(region, "FallenGateSection", Vector3(402, 22, 350), Vector3(86, 18, 32), Vector3(8, -28, 21), _ruin_material)

func _build_spire() -> void:
  var region := _add_region("Spire", "primary")
  region.set_meta("conceptual_height_m", 360)
  region.set_meta("visible_from_spawn", true)
  region.set_meta("silhouette", "single collision core supporting art module")
  _add_cylinder(region, "DominantCollisionCore", Vector3(0, 150, -650), 34, 300, Vector3.ZERO, _dark_ruin_material)
  _add_box(region, "CollisionFoundation", Vector3(0, 26, -650), Vector3(96, 52, 88), Vector3.ZERO, _dark_ruin_material)
  spire_activation_core = _add_cylinder(region, "PrologueActivationCore", Vector3(0, 185, -650), 4.5, 170, Vector3.ZERO, _active_material, false)
  spire_signal_halo = _add_broken_ring(region, "PrologueSignalHalo", Vector3(0, 238, -650), 48, 2.2, 12, [1, 2, 7], Vector3(90, 0, 0), _active_material)
  spire_focus_target = Marker3D.new()
  spire_focus_target.name = "PrologueFocusTarget"
  spire_focus_target.position = Vector3(0, 210, -650)
  region.add_child(spire_focus_target)

func _build_lost_places() -> void:
  var lost_places := Node3D.new()
  lost_places.name = "LostPlaces"
  add_child(lost_places)

  var chamber := Node3D.new()
  chamber.name = "SilentChamber"
  chamber.set_meta("lost_place_id", "LOST PLACE #001")
  chamber.set_meta("hidden_from_main_route", true)
  lost_places.add_child(chamber)

  _add_box(chamber, "EntranceNorth", Vector3(365, 32, -120), Vector3(120, 64, 75), Vector3.ZERO, _rock_material)
  _add_box(chamber, "EntranceSouth", Vector3(365, 32, -15), Vector3(120, 64, 75), Vector3.ZERO, _rock_material)
  _add_box(chamber, "ChamberFloor", Vector3(505, -1, -68), Vector3(230, 8, 190), Vector3.ZERO, _rock_material)
  _add_box(chamber, "ChamberNorthWall", Vector3(505, 58, -165), Vector3(240, 120, 22), Vector3.ZERO, _rock_material)
  _add_box(chamber, "ChamberSouthWall", Vector3(505, 58, 30), Vector3(240, 120, 22), Vector3.ZERO, _rock_material)
  _add_box(chamber, "ChamberEastWall", Vector3(625, 58, -68), Vector3(22, 120, 215), Vector3.ZERO, _rock_material)
  _add_box(chamber, "ChamberRoof", Vector3(510, 118, -68), Vector3(250, 18, 220), Vector3(0, 0, 2), _rock_material)
  _add_box(chamber, "InnerArchNorth", Vector3(470, 38, -125), Vector3(14, 76, 14), Vector3.ZERO, _preserved_material)
  _add_box(chamber, "InnerArchSouth", Vector3(470, 38, -10), Vector3(14, 76, 14), Vector3.ZERO, _preserved_material)
  _add_box(chamber, "InnerArchSpan", Vector3(470, 78, -68), Vector3(14, 14, 130), Vector3.ZERO, _preserved_material)
  _add_cylinder(chamber, "CentralMysteriousObject", Vector3(555, 36, -68), 17, 72, Vector3.ZERO, _preserved_material)
  _add_broken_ring(chamber, "InactiveHalo", Vector3(555, 72, -68), 33, 5, 10, [1, 6], Vector3(90, 0, 0), _active_material)
  for index in range(3):
    _add_box(
      chamber,
      "EntranceClue%02d" % index,
      Vector3(270 + index * 34, 12 + index * 5, -68),
      Vector3(6, 24 + index * 10, 6),
      Vector3(0, 0, index * 4),
      _active_material,
      false
    )


func _build_story_moments() -> void:
  var stories := Node3D.new()
  stories.name = "EnvironmentalStorytelling"
  add_child(stories)

  var crash := Node3D.new()
  crash.name = "CrashedColossus"
  crash.set_meta("story_moment", "A")
  stories.add_child(crash)
  _add_cylinder(crash, "EmbeddedHull", Vector3(-700, 95, -420), 32, 260, Vector3(12, 0, 62), _dark_ruin_material, false)
  _add_box(crash, "ShatteredFin", Vector3(-640, 130, -390), Vector3(115, 14, 65), Vector3(24, -18, 38), _ruin_material, false)
  _add_box(crash, "ImpactShard", Vector3(-600, 30, -350), Vector3(42, 70, 30), Vector3(18, 20, 28), _dark_ruin_material, false)

  var convergence := Node3D.new()
  convergence.name = "ConvergenceRuins"
  convergence.set_meta("story_moment", "B")
  stories.add_child(convergence)
  var convergence_positions := [
    Vector3(-555, 0, 255), Vector3(-505, 0, 305), Vector3(-445, 0, 330),
    Vector3(-390, 0, 285), Vector3(-430, 0, 210),
  ]
  for index in range(convergence_positions.size()):
    var position: Vector3 = convergence_positions[index]
    var to_center := Vector3(-465, 35, 270) - position
    _add_cylinder(
      convergence,
      "LeaningRuin%02d" % index,
      position + Vector3.UP * 35,
      7,
      78,
      Vector3(to_center.z * 0.09, index * 17, -to_center.x * 0.09),
      _ruin_material,
      false
    )

  var preserved := Node3D.new()
  preserved.name = "UnbrokenMonolith"
  preserved.set_meta("story_moment", "C")
  stories.add_child(preserved)
  _add_cylinder(preserved, "PreservedCore", Vector3(590, 205, -465), 16, 105, Vector3.ZERO, _preserved_material)
  _add_broken_ring(preserved, "PreservedHalo", Vector3(590, 232, -465), 38, 6, 12, [], Vector3(90, 0, 0), _active_material)
  for index in range(5):
    _add_box(
      preserved,
      "DestroyedTerrain%02d" % index,
      Vector3(535 + index * 28, 165 + index % 2 * 8, -510 + index % 3 * 42),
      Vector3(42, 18, 55),
      Vector3(index * 9, index * 16, index * 7),
      _rock_material,
      false
    )


func _build_routes() -> void:
  var routes := Node3D.new()
  routes.name = "ExplorationRoutes"
  add_child(routes)
  _add_route(
    routes,
    "SafeRoute",
    [SPAWN_POSITION, Vector3(-220, 90, 350), Vector3(-380, 55, 80), Vector3(-180, 80, -320), Vector3(0, 130, -560)]
  )
  _add_route(
    routes,
    "FastRoute",
    [SPAWN_POSITION, Vector3(100, 70, 390), Vector3(140, 45, 170), Vector3(80, 42, -100), Vector3(10, 55, -430)]
  )
  _add_route(
    routes,
    "DiscoveryRoute",
    [Vector3(120, 50, 80), Vector3(250, 35, -65), Vector3(335, 30, -68), Vector3(500, 35, -68)]
  )


func _add_region(region_name: String, landmark_level: String) -> Node3D:
  var region := Node3D.new()
  region.name = region_name
  region.set_meta("landmark_level", landmark_level)
  add_child(region)
  return region


func _add_route(parent: Node3D, route_name: String, points: Array[Vector3]) -> void:
  var route := Node3D.new()
  route.name = route_name
  route.set_meta("route_type", route_name.trim_suffix("Route").to_upper())
  parent.add_child(route)
  for index in range(points.size()):
    var marker := Marker3D.new()
    marker.name = "Point%02d" % index
    marker.position = points[index]
    route.add_child(marker)


func _add_box(
  parent: Node3D,
  node_name: String,
  position: Vector3,
  size: Vector3,
  rotation_degrees_value: Vector3,
  material: Material,
  collision: bool = true
) -> Node3D:
  var container: Node3D
  if collision:
    var body := StaticBody3D.new()
    body.collision_layer = 1
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    shape_node.shape = shape
    body.add_child(shape_node)
    container = body
  else:
    container = Node3D.new()

  container.name = node_name
  container.position = position
  container.rotation_degrees = rotation_degrees_value
  parent.add_child(container)

  var mesh_instance := MeshInstance3D.new()
  mesh_instance.name = "Mesh"
  var mesh: PrimitiveMesh
  if material == _rock_material:
    var rock_mesh := PrismMesh.new()
    rock_mesh.size = size
    rock_mesh.left_to_right = 0.3
    mesh = rock_mesh
  else:
    var box_mesh := BoxMesh.new()
    box_mesh.size = size
    mesh = box_mesh
  mesh.material = material
  mesh_instance.mesh = mesh
  container.add_child(mesh_instance)
  return container


func _add_cylinder(
  parent: Node3D,
  node_name: String,
  position: Vector3,
  radius: float,
  height: float,
  rotation_degrees_value: Vector3,
  material: Material,
  collision: bool = true
) -> Node3D:
  var container: Node3D
  if collision:
    var body := StaticBody3D.new()
    body.collision_layer = 1
    var shape_node := CollisionShape3D.new()
    var shape := CylinderShape3D.new()
    shape.radius = radius
    shape.height = height
    shape_node.shape = shape
    body.add_child(shape_node)
    container = body
  else:
    container = Node3D.new()

  container.name = node_name
  container.position = position
  container.rotation_degrees = rotation_degrees_value
  parent.add_child(container)

  var mesh_instance := MeshInstance3D.new()
  mesh_instance.name = "Mesh"
  var mesh := CylinderMesh.new()
  mesh.top_radius = radius * 0.72
  mesh.bottom_radius = radius
  mesh.height = height
  mesh.radial_segments = 12
  mesh.rings = 1
  mesh.material = material
  mesh_instance.mesh = mesh
  container.add_child(mesh_instance)
  return container


func _add_broken_ring(
  parent: Node3D,
  node_name: String,
  center: Vector3,
  radius: float,
  thickness: float,
  segment_count: int,
  missing_segments: Array,
  rotation_degrees_value: Vector3,
  material: Material
) -> Node3D:
  var ring := Node3D.new()
  ring.name = node_name
  ring.position = center
  ring.rotation_degrees = rotation_degrees_value
  parent.add_child(ring)
  var arc_length := TAU * radius / float(segment_count) * 0.82
  for index in range(segment_count):
    if index in missing_segments:
      continue
    var angle := TAU * float(index) / float(segment_count)
    _add_box(
      ring,
      "Segment%02d" % index,
      Vector3(cos(angle) * radius, 0, sin(angle) * radius),
      Vector3(arc_length, thickness, thickness),
      Vector3(0, -rad_to_deg(angle) + 90.0, 0),
      material,
      false
    )
  return ring


func set_spire_state(next_state: SpireState, animated: bool = true) -> void:
  spire_state = next_state
  spire_activation_core.visible = spire_state >= SpireState.AWAKENED
  spire_signal_halo.visible = spire_state == SpireState.SIGNAL
  if animated and spire_activation_core.visible:
    var core_tween := spire_activation_core.create_tween()
    core_tween.tween_property(spire_activation_core, "scale:y", 1.0, 1.4).from(0.12)
  if animated and spire_signal_halo.visible:
    var halo_tween := spire_signal_halo.create_tween()
    halo_tween.set_parallel(true)
    halo_tween.tween_property(spire_signal_halo, "rotation_degrees:y", spire_signal_halo.rotation_degrees.y + 14.0, 2.2)
    halo_tween.tween_property(spire_signal_halo, "scale", Vector3.ONE * 1.12, 0.8)
    halo_tween.chain().tween_property(spire_signal_halo, "scale", Vector3.ONE, 1.4)
  spire_state_changed.emit([&"dormant", &"awakened", &"signal"][spire_state])


func reset_prologue_reactions() -> void:
  spire_state = SpireState.DORMANT
  if spire_activation_core == null:
    return
  spire_activation_core.visible = false
  spire_activation_core.scale = Vector3.ONE
  spire_signal_halo.visible = false
  spire_signal_halo.scale = Vector3.ONE
  spire_signal_halo.rotation_degrees = Vector3(90, 0, 0)


func get_spire_focus_target() -> Node3D:
  return spire_focus_target