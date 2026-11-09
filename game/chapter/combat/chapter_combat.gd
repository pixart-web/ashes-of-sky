class_name ChapterCombat
extends Node3D

signal encounter_started(encounter_id: StringName)
signal encounter_completed(encounter_id: StringName)
signal sentinel_phase_changed(phase: int)
signal sentinel_defeated
signal player_failed
signal combat_audio_requested(event_id: StringName)

enum Encounter { NONE, SKIMMER_ONE, SKIMMER_TWO, SENTINEL }

@export_node_path("LunarisFlightController") var flight_player_path: NodePath
@export_node_path("LunarisEvolution") var evolution_path: NodePath

var encounter: Encounter = Encounter.NONE
var skimmer_encounters_completed: int = 0
var sentinel_phase: int = 0
var sentinel_health: float = 360.0
var restraint_health: Array[float] = [70.0, 70.0, 70.0]
var sentinel_defeated_state: bool = false
var invulnerable: bool = false
var player_health: float = 100.0
var flight_player: LunarisFlightController
var evolution: LunarisEvolution
var skimmers: Node3D
var sentinel: Node3D
var combat_hud: CanvasLayer
var combat_label: Label
var _state_time: float = 0.0
var _attack_cooldown: float = 0.0
var _telegraphing: bool = false


func _ready() -> void:
  flight_player = get_node_or_null(flight_player_path) as LunarisFlightController
  evolution = get_node_or_null(evolution_path) as LunarisEvolution
  _build_enemies()
  _build_hud()
  reset_chapter_combat()


func _process(delta: float) -> void:
  _state_time += delta
  _attack_cooldown = maxf(0.0, _attack_cooldown - delta)
  if encounter == Encounter.NONE:
    _check_proximity_encounters()
    return
  if encounter in [Encounter.SKIMMER_ONE, Encounter.SKIMMER_TWO]:
    _animate_skimmers(delta)
  elif encounter == Encounter.SENTINEL:
    _advance_sentinel_pattern()
  _update_hud()


func _unhandled_input(event: InputEvent) -> void:
  if encounter == Encounter.NONE:
    return
  if event.is_action_pressed(&"combat_pulse"):
    attack(18.0, false)
  elif event.is_action_released(&"combat_focus"):
    attack(30.0, true)


func start_skimmer_encounter(index: int) -> bool:
  if encounter != Encounter.NONE or index < 1 or index > 2 or skimmer_encounters_completed >= index:
    return false
  encounter = Encounter.SKIMMER_ONE if index == 1 else Encounter.SKIMMER_TWO
  _state_time = 0.0
  skimmers.visible = true
  combat_hud.visible = true
  encounter_started.emit(&"ash_skimmer_%d" % index)
  combat_audio_requested.emit(&"SKIMMER_APPROACH")
  return true


func start_sentinel_encounter() -> bool:
  if encounter != Encounter.NONE or sentinel_defeated_state:
    return false
  encounter = Encounter.SENTINEL
  sentinel_phase = 1
  sentinel_health = 360.0
  restraint_health = [70.0, 70.0, 70.0]
  player_health = 100.0
  sentinel.visible = true
  combat_hud.visible = true
  _state_time = 0.0
  sentinel_phase_changed.emit(1)
  encounter_started.emit(&"veiled_sentinel")
  combat_audio_requested.emit(&"SENTINEL_AWAKENING")
  return true


func attack(base_damage: float, focused: bool) -> float:
  if encounter == Encounter.NONE or _attack_cooldown > 0.0:
    return 0.0
  var modifiers := evolution.get_gameplay_modifiers() if evolution != null else {"pulse_power": 1.0, "focus_rate": 1.0}
  var damage := base_damage * float(modifiers.get("pulse_power", 1.0))
  if focused:
    damage *= float(modifiers.get("focus_rate", 1.0))
  _attack_cooldown = 0.28 if not focused else 0.65
  combat_audio_requested.emit(&"FOCUS_IMPACT" if focused else &"PULSE_IMPACT")
  if encounter in [Encounter.SKIMMER_ONE, Encounter.SKIMMER_TWO]:
    var health := float(skimmers.get_meta("health", 90.0)) - damage
    skimmers.set_meta("health", health)
    if health <= 0.0:
      _finish_skimmer()
    return damage
  if sentinel_phase == 1:
    if _state_time < 2.2:
      return 0.0
    sentinel_phase = 2
    sentinel_phase_changed.emit(2)
    combat_audio_requested.emit(&"RESTRAINTS_ENGAGED")
    return damage
  if sentinel_phase == 2:
    var index := _next_restraint_index()
    if index >= 0:
      restraint_health[index] = maxf(0.0, restraint_health[index] - damage)
      var restraint := sentinel.get_node("Restraints/Restraint%02d" % index) as Node3D
      restraint.scale = Vector3.ONE * maxf(0.35, restraint_health[index] / 70.0)
    if restraint_health.all(func(value): return value <= 0.0):
      sentinel_phase = 3
      sentinel_phase_changed.emit(3)
      combat_audio_requested.emit(&"RESONANCE_CORE_EXPOSED")
      (sentinel.get_node("Core") as Node3D).visible = true
    return damage
  sentinel_health = maxf(0.0, sentinel_health - damage)
  if sentinel_health <= 0.0:
    _defeat_sentinel()
  return damage


func apply_player_damage(amount: float) -> float:
  if invulnerable or encounter == Encounter.NONE:
    return 0.0
  var guard := 1.0
  if evolution != null:
    guard = float(evolution.get_gameplay_modifiers().get("guard", 1.0))
  var applied := amount / guard
  player_health = maxf(0.0, player_health - applied)
  if player_health <= 0.0:
    player_failed.emit()
    reset_current_encounter()
  return applied


func reset_current_encounter() -> void:
  var previous := encounter
  encounter = Encounter.NONE
  player_health = 100.0
  combat_hud.visible = false
  skimmers.visible = false
  if previous == Encounter.SENTINEL and not sentinel_defeated_state:
    sentinel.visible = true
    sentinel_phase = 0


func reset_chapter_combat() -> void:
  encounter = Encounter.NONE
  skimmer_encounters_completed = 0
  sentinel_phase = 0
  sentinel_health = 360.0
  restraint_health = [70.0, 70.0, 70.0]
  sentinel_defeated_state = false
  player_health = 100.0
  if skimmers != null:
    skimmers.visible = false
    skimmers.set_meta("health", 90.0)
  if sentinel != null:
    sentinel.visible = false
    sentinel.position = Vector3(0, 52, -1590)
    sentinel.rotation_degrees.z = 0.0
    (sentinel.get_node("Core") as Node3D).visible = false
  if combat_hud != null:
    combat_hud.visible = false


func create_snapshot() -> Dictionary:
  return {
    "skimmer_encounters_completed": skimmer_encounters_completed,
    "sentinel_defeated": sentinel_defeated_state,
    "sentinel_phase": sentinel_phase,
  }


func restore_snapshot(snapshot: Dictionary) -> void:
  reset_chapter_combat()
  skimmer_encounters_completed = int(snapshot.get("skimmer_encounters_completed", 0))
  sentinel_defeated_state = bool(snapshot.get("sentinel_defeated", false))
  sentinel_phase = int(snapshot.get("sentinel_phase", 0))
  if sentinel_defeated_state:
    sentinel.visible = true
    sentinel.rotation_degrees.z = -32.0
    sentinel.position.y = -8.0


func _check_proximity_encounters() -> void:
  if flight_player == null:
    return
  var position := flight_player.global_position
  if skimmer_encounters_completed == 0 and position.distance_to(Vector3(-230, 90, -1160)) < 130.0:
    start_skimmer_encounter(1)
  elif skimmer_encounters_completed == 1 and position.distance_to(Vector3(270, 110, -1390)) < 130.0:
    start_skimmer_encounter(2)
  elif skimmer_encounters_completed >= 2 and position.distance_to(Vector3(0, 100, -1580)) < 165.0:
    start_sentinel_encounter()


func _animate_skimmers(delta: float) -> void:
  skimmers.rotation.y += delta * 1.4
  if _state_time > 2.0 and fmod(_state_time, 3.2) < delta:
    combat_audio_requested.emit(&"SKIMMER_PASS")
    apply_player_damage(8.0)


func _advance_sentinel_pattern() -> void:
  sentinel.rotation.y += 0.0018 * float(sentinel_phase)
  if _state_time > 2.5 and fmod(_state_time, 4.5 - sentinel_phase * 0.45) < 0.02:
    _telegraphing = true
    combat_audio_requested.emit(&"SENTINEL_TELEGRAPH")
  if _telegraphing and fmod(_state_time, 4.5 - sentinel_phase * 0.45) > 0.9:
    _telegraphing = false
    apply_player_damage(10.0 + sentinel_phase * 4.0)


func _next_restraint_index() -> int:
  for index in range(restraint_health.size()):
    if restraint_health[index] > 0.0:
      return index
  return -1


func _finish_skimmer() -> void:
  var completed_id := &"ash_skimmer_1" if encounter == Encounter.SKIMMER_ONE else &"ash_skimmer_2"
  skimmer_encounters_completed = maxi(skimmer_encounters_completed, 1 if encounter == Encounter.SKIMMER_ONE else 2)
  encounter = Encounter.NONE
  skimmers.visible = false
  skimmers.set_meta("health", 90.0)
  combat_hud.visible = false
  encounter_completed.emit(completed_id)


func _defeat_sentinel() -> void:
  sentinel_defeated_state = true
  encounter = Encounter.NONE
  combat_hud.visible = false
  sentinel.rotation_degrees.z = -32.0
  sentinel.position.y -= 8.0
  (sentinel.get_node("Core") as Node3D).visible = false
  combat_audio_requested.emit(&"SENTINEL_RECOGNITION")
  encounter_completed.emit(&"veiled_sentinel")
  sentinel_defeated.emit()


func _build_enemies() -> void:
  var metal := _material(Color(0.12, 0.13, 0.14), Color(0.0, 0.0, 0.0))
  var energy := _material(Color(0.08, 0.35, 0.42), Color(0.18, 0.82, 0.9))
  skimmers = Node3D.new()
  skimmers.name = "AshSkimmers"
  skimmers.position = Vector3(-230, 90, -1160)
  add_child(skimmers)
  for index in range(3):
    var body := Node3D.new()
    body.name = "Skimmer%02d" % index
    body.position = Vector3(index * 16, index * 5, index * -12)
    skimmers.add_child(body)
    _mesh_box(body, "Body", Vector3.ZERO, Vector3(8, 1.4, 3), metal)
    _mesh_box(body, "WingLeft", Vector3(-5, 0, 0), Vector3(7, 0.25, 2.2), metal)
    _mesh_box(body, "WingRight", Vector3(5, 0, 0), Vector3(7, 0.25, 2.2), metal)
    _mesh_sphere(body, "Eye", Vector3(0, 0, -2), 0.5, energy)
  skimmers.set_meta("health", 90.0)
  sentinel = Node3D.new()
  sentinel.name = "VeiledSentinel"
  sentinel.position = Vector3(0, 52, -1590)
  add_child(sentinel)
  _mesh_box(sentinel, "Body", Vector3.ZERO, Vector3(42, 16, 28), metal)
  _mesh_box(sentinel, "Veil", Vector3(0, 8, -8), Vector3(58, 3, 22), metal)
  _mesh_sphere(sentinel, "Core", Vector3(0, 2, -17), 5.0, energy).visible = false
  var restraints := Node3D.new()
  restraints.name = "Restraints"
  sentinel.add_child(restraints)
  for index in range(3):
    var angle := TAU * float(index) / 3.0
    var node := Node3D.new()
    node.name = "Restraint%02d" % index
    node.position = Vector3(cos(angle) * 25, sin(angle) * 13, 2)
    restraints.add_child(node)
    _mesh_box(node, "StructuralLock", Vector3.ZERO, Vector3(9, 9, 9), metal)
    _mesh_box(node, "InterruptedChannel", Vector3(0, 0, -5), Vector3(1.1, 7, 1.1), energy)


func _build_hud() -> void:
  combat_hud = CanvasLayer.new()
  combat_hud.name = "ChapterCombatHUD"
  combat_hud.layer = 12
  add_child(combat_hud)
  combat_label = Label.new()
  combat_label.position = Vector2(430, 620)
  combat_label.size = Vector2(420, 60)
  combat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  combat_label.add_theme_font_size_override("font_size", 18)
  combat_label.add_theme_color_override("font_color", Color(0.72, 0.9, 0.91))
  combat_hud.add_child(combat_label)


func _update_hud() -> void:
  if encounter in [Encounter.SKIMMER_ONE, Encounter.SKIMMER_TWO]:
    combat_label.text = "ASH SKIMMER  •  %d%%" % maxi(0, int(float(skimmers.get_meta("health", 0.0)) / 90.0 * 100.0))
  elif encounter == Encounter.SENTINEL:
    var detail := "POSITIONING" if sentinel_phase == 1 else ("RESTRAINTS %d/3" % restraint_health.count(0.0) if sentinel_phase == 2 else "RESONANCE CORE")
    combat_label.text = "VEILED SENTINEL  •  %s" % detail


func _material(albedo: Color, emission: Color) -> StandardMaterial3D:
  var material := StandardMaterial3D.new()
  material.albedo_color = albedo
  material.roughness = 0.7
  if emission != Color.BLACK:
    material.emission_enabled = true
    material.emission = emission
    material.emission_energy_multiplier = 1.6
  return material


func _mesh_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
  var instance := MeshInstance3D.new()
  instance.name = node_name
  instance.position = position
  var mesh := BoxMesh.new()
  mesh.size = size
  mesh.material = material
  instance.mesh = mesh
  parent.add_child(instance)
  return instance


func _mesh_sphere(parent: Node3D, node_name: String, position: Vector3, radius: float, material: Material) -> MeshInstance3D:
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
