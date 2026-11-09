class_name ChapterOneWorld
extends Node3D

signal puzzle_progress_changed(active_count: int)
signal puzzle_solved
signal revelation_reached
signal pale_reach_entered

const SPIRE_LANDING := Vector3(15, 126, -705)
const SPIRE_DISMOUNT := Vector3(20, 123, -698)
const SPIRE_RECOVERY := Vector3(28, 123, -695)
const VAULT_POSITION := Vector3(0, 151, -845)
const REVELATION_POSITION := Vector3(0, 184, -925)
const PALE_REACH_CENTER := Vector3(0, 30, -1320)

var spire_accessible: bool = false
var puzzle_nodes_active: Array[bool] = [false, false, false]
var puzzle_complete: bool = false
var revelation_complete: bool = false
var pale_reach_revealed: bool = false
var vault_response: StringName = &"dormant"
var spire_root: Node3D
var vault_door: Node3D
var pale_root: Node3D
var signal_beacon: Node3D

var _stone: StandardMaterial3D
var _metal: StandardMaterial3D
var _pale: StandardMaterial3D
var _cyan: StandardMaterial3D
var _warm: StandardMaterial3D


func _ready() -> void:
  _create_materials()
  _build_spire_exterior()
  _build_spire_interior()
  _build_pale_reach()
  set_spire_accessible(false)
  set_pale_reach_revealed(false)


func set_spire_accessible(enabled: bool) -> void:
  spire_accessible = enabled
  if signal_beacon != null:
    signal_beacon.visible = enabled


func activate_puzzle_node(index: int) -> bool:
  if index < 0 or index >= puzzle_nodes_active.size() or puzzle_nodes_active[index]:
    return false
  puzzle_nodes_active[index] = true
  var node := get_node_or_null("SpireInterior/LightPuzzle/Resonator%02d" % index) as Node3D
  if node != null:
    node.scale = Vector3.ONE * 1.18
    node.set_meta("active", true)
  var count := puzzle_nodes_active.count(true)
  puzzle_progress_changed.emit(count)
  if count == puzzle_nodes_active.size():
    puzzle_complete = true
    vault_door.position.y += 18.0
    puzzle_solved.emit()
  return true


func apply_vault_tendency(tendency_id: StringName) -> void:
  vault_response = tendency_id
  var core := get_node_or_null("SpireInterior/ResonanceVault/VaultCore") as Node3D
  if core == null:
    return
  match tendency_id:
    &"predator": core.scale = Vector3(1.35, 0.8, 1.35)
    &"guardian": core.scale = Vector3(1.55, 1.25, 1.55)
    &"oracle": core.scale = Vector3(0.85, 1.7, 0.85)
    &"wraith": core.rotation_degrees.z = 28.0


func complete_revelation() -> bool:
  if not puzzle_complete or revelation_complete:
    return false
  revelation_complete = true
  set_pale_reach_revealed(true)
  revelation_reached.emit()
  return true


func set_pale_reach_revealed(enabled: bool) -> void:
  pale_reach_revealed = enabled
  if pale_root != null:
    pale_root.visible = enabled


func reset_chapter_world() -> void:
  puzzle_nodes_active = [false, false, false]
  puzzle_complete = false
  revelation_complete = false
  vault_response = &"dormant"
  for index in range(3):
    var node := get_node_or_null("SpireInterior/LightPuzzle/Resonator%02d" % index) as Node3D
    if node != null:
      node.scale = Vector3.ONE
      node.set_meta("active", false)
  if vault_door != null:
    vault_door.position = Vector3(0, 138, -822)
  set_spire_accessible(false)
  set_pale_reach_revealed(false)


func create_snapshot() -> Dictionary:
  return {
    "spire_accessible": spire_accessible,
    "puzzle_nodes": puzzle_nodes_active.duplicate(),
    "puzzle_complete": puzzle_complete,
    "revelation_complete": revelation_complete,
    "pale_reach_revealed": pale_reach_revealed,
    "vault_response": String(vault_response),
  }


func restore_snapshot(snapshot: Dictionary) -> void:
  reset_chapter_world()
  set_spire_accessible(bool(snapshot.get("spire_accessible", false)))
  var stored: Array = snapshot.get("puzzle_nodes", [])
  for index in range(mini(3, stored.size())):
    if bool(stored[index]):
      activate_puzzle_node(index)
  revelation_complete = bool(snapshot.get("revelation_complete", false))
  set_pale_reach_revealed(bool(snapshot.get("pale_reach_revealed", revelation_complete)))
  vault_response = StringName(snapshot.get("vault_response", "dormant"))


func _build_spire_exterior() -> void:
  spire_root = Node3D.new()
  spire_root.name = "SpireChapter"
  add_child(spire_root)
  _box(spire_root, "LandingPlatform", SPIRE_LANDING + Vector3(0, -4, 0), Vector3(70, 7, 48), Vector3(0, 8, 0), _stone, true)
  _box(spire_root, "SealedDirectEntrance", Vector3(0, 105, -668), Vector3(42, 90, 16), Vector3.ZERO, _metal, true)
  for index in range(5):
    var ring := _torus(spire_root, "BrokenRing%02d" % index, Vector3(0, 65 + index * 38, -680 - index * 20), 44.0 - index * 4.0, _metal)
    ring.rotation_degrees = Vector3(74 + index * 3, index * 17, index * 9)
  for index in range(4):
    _box(spire_root, "SuspendedBlade%02d" % index, Vector3(-62 + index * 42, 95 + index * 22, -730 - index * 28), Vector3(10, 92, 18), Vector3(index * 4, index * 11, -9 + index * 6), _stone, false)
  signal_beacon = _sphere(spire_root, "ApproachBeacon", Vector3(12, 176, -745), 4.5, _cyan)


func _build_spire_interior() -> void:
  var interior := Node3D.new()
  interior.name = "SpireInterior"
  add_child(interior)
  _box(interior, "OpenSanctum", Vector3(22, 119, -744), Vector3(88, 5, 92), Vector3.ZERO, _stone, true)
  for index in range(6):
    _box(interior, "AscentStep%02d" % index, Vector3(20 - index * 4, 122 + index * 4, -770 - index * 10), Vector3(36, 3, 12), Vector3.ZERO, _stone, true)
  var gallery := Node3D.new()
  gallery.name = "ArchitectGallery"
  interior.add_child(gallery)
  _box(gallery, "GalleryFloor", Vector3(0, 146, -835), Vector3(74, 4, 95), Vector3.ZERO, _stone, true)
  for index in range(7):
    _box(gallery, "MemoryBlade%02d" % index, Vector3(-28 + index * 9, 160 + (index % 2) * 3, -830), Vector3(2.2, 28 + index, 9), Vector3(0, index * 4, -5 + index), _metal, false)
  var puzzle := Node3D.new()
  puzzle.name = "LightPuzzle"
  interior.add_child(puzzle)
  for index in range(3):
    var resonator := _torus(puzzle, "Resonator%02d" % index, Vector3(-24 + index * 24, 151, -790), 6.0, _cyan)
    resonator.set_meta("puzzle_index", index)
    resonator.set_meta("active", false)
  vault_door = _box(interior, "VaultDoor", Vector3(0, 138, -822), Vector3(44, 38, 5), Vector3.ZERO, _metal, true)
  var vault := Node3D.new()
  vault.name = "ResonanceVault"
  interior.add_child(vault)
  _box(vault, "VaultFloor", VAULT_POSITION + Vector3(0, -4, 0), Vector3(62, 6, 70), Vector3.ZERO, _stone, true)
  _torus(vault, "VaultCore", VAULT_POSITION + Vector3(0, 16, -10), 12.0, _cyan)
  var revelation := Node3D.new()
  revelation.name = "RevelationChamber"
  interior.add_child(revelation)
  _box(revelation, "RevelationFloor", REVELATION_POSITION + Vector3(0, -5, 0), Vector3(80, 7, 74), Vector3.ZERO, _stone, true)
  for side in [-1.0, 1.0]:
    _box(revelation, "OpposedMotif%s" % side, REVELATION_POSITION + Vector3(side * 22, 14, -10), Vector3(5, 34, 5), Vector3(0, 0, side * 18), _warm if side < 0 else _cyan, false)


func _build_pale_reach() -> void:
  pale_root = Node3D.new()
  pale_root.name = "PaleReach"
  add_child(pale_root)
  _box(pale_root, "MineralShelf", PALE_REACH_CENTER + Vector3(0, -18, 0), Vector3(920, 28, 700), Vector3(0, 2, 0), _pale, true)
  for index in range(14):
    var x := -380.0 + float((index * 137) % 760)
    var z := -1050.0 - float((index * 89) % 500)
    _box(pale_root, "WindBlade%02d" % index, Vector3(x, 20 + (index % 4) * 15, z), Vector3(12 + index % 3 * 4, 65 + index % 5 * 15, 22), Vector3(index * 3, index * 13, -12 + index % 4 * 7), _metal, false)
  for index in range(5):
    _torus(pale_root, "BuriedForm%02d" % index, Vector3(-300 + index * 145, 10, -1180 - (index % 2) * 150), 24 + index * 3, _stone).rotation_degrees.x = 78
  _sphere(pale_root, "SkyBelowSignal", Vector3(0, -15, -1580), 13, _cyan)


func _create_materials() -> void:
  _stone = _material(Color(0.075, 0.085, 0.095), 0.9)
  _metal = _material(Color(0.22, 0.24, 0.23), 0.7)
  _pale = _material(Color(0.48, 0.49, 0.46), 0.95)
  _cyan = _material(Color(0.12, 0.55, 0.62), 0.38, Color(0.18, 0.82, 0.9))
  _warm = _material(Color(0.38, 0.18, 0.1), 0.7, Color(0.65, 0.18, 0.08))


func _material(color: Color, roughness: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
  var material := StandardMaterial3D.new()
  material.albedo_color = color
  material.roughness = roughness
  if emission != Color.BLACK:
    material.emission_enabled = true
    material.emission = emission
    material.emission_energy_multiplier = 1.25
  return material


func _box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, rotation_value: Vector3, material: Material, collision: bool) -> Node3D:
  var body: Node3D = StaticBody3D.new() if collision else Node3D.new()
  body.name = node_name
  body.position = position
  body.rotation_degrees = rotation_value
  parent.add_child(body)
  var instance := MeshInstance3D.new()
  var mesh := BoxMesh.new()
  mesh.size = size
  mesh.material = material
  instance.mesh = mesh
  body.add_child(instance)
  if collision:
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    shape_node.shape = shape
    body.add_child(shape_node)
  return body


func _sphere(parent: Node3D, node_name: String, position: Vector3, radius: float, material: Material) -> MeshInstance3D:
  var instance := MeshInstance3D.new()
  instance.name = node_name
  instance.position = position
  var mesh := SphereMesh.new()
  mesh.radius = radius
  mesh.height = radius * 2.0
  mesh.radial_segments = 12
  mesh.rings = 6
  mesh.material = material
  instance.mesh = mesh
  parent.add_child(instance)
  return instance


func _torus(parent: Node3D, node_name: String, position: Vector3, radius: float, material: Material) -> MeshInstance3D:
  var instance := MeshInstance3D.new()
  instance.name = node_name
  instance.position = position
  var mesh := TorusMesh.new()
  mesh.inner_radius = radius - 1.2
  mesh.outer_radius = radius
  mesh.rings = 24
  mesh.ring_segments = 8
  mesh.material = material
  instance.mesh = mesh
  parent.add_child(instance)
  return instance
