class_name LunarisEvolution
extends Node

signal tendency_selected(tendency_id: StringName)
signal evolution_changed(stage: int, tendency_id: StringName)

enum Tendency { NONE, PREDATOR, GUARDIAN, ORACLE, WRAITH }

const TENDENCY_IDS: Array[StringName] = [&"none", &"predator", &"guardian", &"oracle", &"wraith"]

@export_node_path("LunarisVisual") var visual_path: NodePath
@export_node_path("LunarisFlightController") var flight_player_path: NodePath

var tendency: Tendency = Tendency.NONE
var evolution_stage: int = 0
var predator_affinity: float = 0.0
var guardian_affinity: float = 0.0
var oracle_affinity: float = 0.0
var wraith_affinity: float = 0.0
var visual: LunarisVisual
var flight_player: LunarisFlightController
var evolution_marks: Node3D


func _ready() -> void:
  visual = get_node_or_null(visual_path) as LunarisVisual
  flight_player = get_node_or_null(flight_player_path) as LunarisFlightController
  _ensure_visual_marks()
  _apply_visual()


func select_tendency(next_tendency: Tendency) -> bool:
  if next_tendency == Tendency.NONE or tendency != Tendency.NONE:
    return false
  tendency = next_tendency
  evolution_stage = 1
  match tendency:
    Tendency.PREDATOR: predator_affinity = 1.0
    Tendency.GUARDIAN: guardian_affinity = 1.0
    Tendency.ORACLE: oracle_affinity = 1.0
    Tendency.WRAITH: wraith_affinity = 1.0
  _apply_visual()
  tendency_selected.emit(get_tendency_id())
  evolution_changed.emit(evolution_stage, get_tendency_id())
  return true


func get_tendency_id() -> StringName:
  return TENDENCY_IDS[tendency]


func get_gameplay_modifiers() -> Dictionary:
  match tendency:
    Tendency.PREDATOR: return {"pulse_power": 1.25, "guard": 1.0, "focus_rate": 1.0, "mobility": 1.05}
    Tendency.GUARDIAN: return {"pulse_power": 1.0, "guard": 1.35, "focus_rate": 1.0, "mobility": 0.98}
    Tendency.ORACLE: return {"pulse_power": 1.0, "guard": 1.0, "focus_rate": 1.35, "mobility": 1.0}
    Tendency.WRAITH: return {"pulse_power": 0.95, "guard": 1.0, "focus_rate": 1.08, "mobility": 1.3}
  return {"pulse_power": 1.0, "guard": 1.0, "focus_rate": 1.0, "mobility": 1.0}


func create_snapshot() -> Dictionary:
  return {
    "tendency": String(get_tendency_id()), "evolution_stage": evolution_stage,
    "predator_affinity": predator_affinity, "guardian_affinity": guardian_affinity,
    "oracle_affinity": oracle_affinity, "wraith_affinity": wraith_affinity,
  }


func restore_snapshot(snapshot: Dictionary) -> bool:
  var index := TENDENCY_IDS.find(StringName(snapshot.get("tendency", "none")))
  if index < 0:
    return false
  tendency = index as Tendency
  evolution_stage = clampi(int(snapshot.get("evolution_stage", 0)), 0, 1)
  predator_affinity = float(snapshot.get("predator_affinity", 0.0))
  guardian_affinity = float(snapshot.get("guardian_affinity", 0.0))
  oracle_affinity = float(snapshot.get("oracle_affinity", 0.0))
  wraith_affinity = float(snapshot.get("wraith_affinity", 0.0))
  _apply_visual()
  evolution_changed.emit(evolution_stage, get_tendency_id())
  return true


func reset_evolution() -> void:
  tendency = Tendency.NONE
  evolution_stage = 0
  predator_affinity = 0.0
  guardian_affinity = 0.0
  oracle_affinity = 0.0
  wraith_affinity = 0.0
  _apply_visual()


func _ensure_visual_marks() -> void:
  if visual == null:
    return
  evolution_marks = visual.get_node_or_null("EvolutionMarks") as Node3D
  if evolution_marks != null:
    return
  evolution_marks = Node3D.new()
  evolution_marks.name = "EvolutionMarks"
  visual.add_child(evolution_marks)
  for side in [-1.0, 1.0]:
    var mark := MeshInstance3D.new()
    mark.position = Vector3(side * 0.48, 0.57, -0.35)
    var mesh := PrismMesh.new()
    mesh.size = Vector3(0.18, 0.035, 0.75)
    mesh.material = _evolution_material(Color(0.25, 0.72, 0.78))
    mark.mesh = mesh
    evolution_marks.add_child(mark)


func _apply_visual() -> void:
  if flight_player != null:
    flight_player.maximum_speed = 32.0
    flight_player.boost_speed = 48.0
    flight_player.yaw_speed = 70.0
    flight_player.pitch_speed = 50.0
    flight_player.momentum_response = 24.0
    match tendency:
      Tendency.PREDATOR:
        flight_player.maximum_speed = 34.0
        flight_player.boost_speed = 50.0
      Tendency.GUARDIAN:
        flight_player.momentum_response = 30.0
      Tendency.WRAITH:
        flight_player.yaw_speed = 88.0
        flight_player.pitch_speed = 62.0
  if evolution_marks == null:
    return
  evolution_marks.visible = evolution_stage > 0
  var colors := [Color(0.25, 0.72, 0.78), Color(0.9, 0.29, 0.17), Color(0.37, 0.8, 0.66), Color(0.45, 0.76, 0.95), Color(0.66, 0.48, 0.9)]
  for child in evolution_marks.get_children():
    var mesh_instance := child as MeshInstance3D
    if mesh_instance != null and mesh_instance.mesh != null:
      mesh_instance.mesh.material = _evolution_material(colors[tendency])
  match tendency:
    Tendency.PREDATOR: evolution_marks.scale = Vector3(1.25, 1.0, 1.15)
    Tendency.GUARDIAN: evolution_marks.scale = Vector3(1.45, 1.15, 0.9)
    Tendency.ORACLE: evolution_marks.scale = Vector3(0.9, 1.35, 1.2)
    Tendency.WRAITH: evolution_marks.scale = Vector3(0.75, 0.8, 1.5)
    _: evolution_marks.scale = Vector3.ONE


func _evolution_material(color: Color) -> StandardMaterial3D:
  var material := StandardMaterial3D.new()
  material.albedo_color = Color(color.r * 0.35, color.g * 0.35, color.b * 0.35, 1.0)
  material.emission_enabled = true
  material.emission = color
  material.emission_energy_multiplier = 1.8
  material.roughness = 0.38
  return material
