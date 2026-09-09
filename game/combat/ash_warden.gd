class_name AshWarden
extends Node3D

signal attack_telegraphed(attack_name: StringName)
signal attack_executed(attack_name: StringName)
signal guard_broken(side: StringName)
signal core_exposed
signal defeated
signal world_state_changed(state_id: StringName)

enum AIState { TRACK, FRONTAL_TELEGRAPH, FRONTAL_ATTACK, SWEEP_TELEGRAPH, SWEEP, RECOVER, CORE_EXPOSED, DEFEATED }
enum WorldState { DORMANT, AWAKENED, DEFEATED }

const MAX_GUARD_HEALTH := 25.0
const MAX_CORE_HEALTH := 50.0

var ai_state: AIState = AIState.TRACK
var left_guard_health: float = MAX_GUARD_HEALTH
var right_guard_health: float = MAX_GUARD_HEALTH
var core_health: float = MAX_CORE_HEALTH
var combat_active: bool = false
var phase_two: bool = false
var queued_attack: StringName = &""
var state_time: float = 0.0
var target_position: Vector3
var world_state: WorldState = WorldState.AWAKENED
var spawn_position: Vector3
var impact_time: float = 0.0

var body_visual: Node3D
var left_guard_visual: Node3D
var right_guard_visual: Node3D
var core_visual: MeshInstance3D
var lance_visual: MeshInstance3D

var _stone := preload("res://art/sacred_ash/materials/m_architect_dark_stone.tres")
var _metal := preload("res://art/sacred_ash/materials/m_architect_aged_metal.tres")
var _bone := preload("res://art/lunaris/materials/m_lunaris_bone_plate.tres")
var _energy := preload("res://art/sacred_ash/materials/m_architect_cyan_active.tres")


func _ready() -> void:
  spawn_position = global_position
  _build_visual()
  reset_warden()


func _process(delta: float) -> void:
  impact_time = maxf(0.0, impact_time - delta)
  if body_visual != null:
    body_visual.scale = body_visual.scale.lerp(Vector3.ONE * (1.035 if impact_time > 0.0 else 1.0), 1.0 - exp(-14.0 * delta))
  if combat_active and ai_state != AIState.DEFEATED:
    var flat_target := Vector3(target_position.x, global_position.y, target_position.z)
    if flat_target.distance_to(global_position) > 0.1:
      var desired := global_transform.looking_at(flat_target, Vector3.UP).basis
      var speed := 1.0 - exp(-(1.25 if phase_two else 0.75) * delta)
      global_basis = Basis(global_basis.get_rotation_quaternion().slerp(desired.get_rotation_quaternion(), speed))
  if ai_state == AIState.DEFEATED:
    global_position.y = maxf(spawn_position.y - 12.0, global_position.y - 2.2 * delta)
    rotation.z = move_toward(rotation.z, deg_to_rad(18.0), delta * 0.18)


func set_world_state(next_state: WorldState, animated: bool = true) -> void:
  world_state = next_state
  match world_state:
    WorldState.DORMANT:
      reset_warden()
      combat_active = false
      body_visual.rotation_degrees = Vector3(0, 0, -11)
      left_guard_visual.position = Vector3(-4.2, -3.2, 2.4)
      right_guard_visual.position = Vector3(4.2, -3.2, 2.4)
      lance_visual.scale = Vector3.ONE * 0.78
    WorldState.AWAKENED:
      reset_warden()
      combat_active = false
      if animated:
        body_visual.rotation_degrees = Vector3(0, 0, -11)
        left_guard_visual.position = Vector3(-4.2, -3.2, 2.4)
        right_guard_visual.position = Vector3(4.2, -3.2, 2.4)
        var tween := create_tween().set_parallel(true)
        tween.tween_property(body_visual, "rotation_degrees", Vector3.ZERO, 1.7)
        tween.tween_property(left_guard_visual, "position", Vector3(-7.0, 0.0, 0.5), 1.7)
        tween.tween_property(right_guard_visual, "position", Vector3(7.0, 0.0, 0.5), 1.7)
        core_visual.visible = true
        tween.chain().tween_callback(func(): core_visual.visible = false)
    WorldState.DEFEATED:
      combat_active = false
      ai_state = AIState.DEFEATED
      left_guard_health = 0.0
      right_guard_health = 0.0
      core_health = 0.0
      left_guard_visual.visible = false
      right_guard_visual.visible = false
      core_visual.visible = true
      core_visual.scale = Vector3.ONE * 0.45
      global_position = spawn_position + Vector3.DOWN * 6.0
      rotation.z = deg_to_rad(18.0)
  world_state_changed.emit([&"dormant", &"awakened", &"defeated"][world_state])


func set_combat_active(enabled: bool) -> void:
  combat_active = enabled
  state_time = 0.0


func advance_ai(delta: float, sector: StringName, distance: float) -> void:
  if not combat_active or ai_state == AIState.DEFEATED:
    return
  state_time += delta
  match ai_state:
    AIState.TRACK, AIState.CORE_EXPOSED:
      var delay := 2.4 if phase_two else 3.6
      if state_time >= delay and distance <= 135.0:
        if sector == &"FRONT":
          _begin_telegraph(&"WARDEN_LANCE")
        elif sector == &"REAR":
          _begin_telegraph(&"REAR_PULSE")
        else:
          _begin_telegraph(&"ARC_SWEEP")
    AIState.FRONTAL_TELEGRAPH:
      _set_charge_visual(clampf(state_time / 1.35, 0.0, 1.0))
      if state_time >= 1.35:
        ai_state = AIState.FRONTAL_ATTACK
        state_time = 0.0
        attack_executed.emit(queued_attack)
    AIState.FRONTAL_ATTACK:
      if state_time >= 0.25:
        _begin_recovery()
    AIState.SWEEP_TELEGRAPH:
      _set_charge_visual(clampf(state_time / 1.05, 0.0, 1.0))
      if state_time >= 1.05:
        ai_state = AIState.SWEEP
        state_time = 0.0
        attack_executed.emit(queued_attack)
    AIState.SWEEP:
      rotation.y += delta * (1.4 if phase_two else 1.0)
      if state_time >= 0.55:
        _begin_recovery()
    AIState.RECOVER:
      _set_charge_visual(0.0)
      if state_time >= (0.75 if phase_two else 1.05):
        ai_state = AIState.CORE_EXPOSED if phase_two else AIState.TRACK
        state_time = 0.0


func receive_attack(base_damage: float, sector: StringName, focus_ratio: float = 0.0) -> float:
  if ai_state == AIState.DEFEATED or not combat_active:
    return 0.0
  impact_time = 0.14
  var damage := base_damage
  if sector in [&"LEFT", &"RIGHT"]:
    damage *= lerpf(1.25, 1.5, focus_ratio)
  elif sector == &"REAR":
    damage *= 0.7

  var applied := 0.0
  if phase_two:
    if focus_ratio >= 0.95:
      damage *= 2.0
    applied = minf(core_health, damage)
    core_health -= applied
    if core_health <= 0.0:
      _defeat()
    return applied

  if sector == &"LEFT" and left_guard_health > 0.0:
    applied = _damage_guard(&"LEFT", damage)
  elif sector == &"RIGHT" and right_guard_health > 0.0:
    applied = _damage_guard(&"RIGHT", damage)
  elif left_guard_health > 0.0:
    applied = _damage_guard(&"LEFT", damage)
  elif right_guard_health > 0.0:
    applied = _damage_guard(&"RIGHT", damage)
  _check_core_exposure()
  return applied


func reset_warden() -> void:
  left_guard_health = MAX_GUARD_HEALTH
  right_guard_health = MAX_GUARD_HEALTH
  core_health = MAX_CORE_HEALTH
  phase_two = false
  ai_state = AIState.TRACK
  queued_attack = &""
  state_time = 0.0
  global_position = spawn_position
  rotation = Vector3.ZERO
  body_visual.rotation = Vector3.ZERO
  left_guard_visual.position = Vector3(-7.0, 0.0, 0.5)
  right_guard_visual.position = Vector3(7.0, 0.0, 0.5)
  left_guard_visual.visible = true
  right_guard_visual.visible = true
  core_visual.visible = false
  _set_charge_visual(0.0)


func get_total_health() -> float:
  return left_guard_health + right_guard_health + core_health


func _damage_guard(side: StringName, damage: float) -> float:
  var current := left_guard_health if side == &"LEFT" else right_guard_health
  var applied := minf(current, damage)
  current -= applied
  if side == &"LEFT":
    left_guard_health = current
    if current <= 0.0:
      left_guard_visual.visible = false
      guard_broken.emit(&"LEFT")
  else:
    right_guard_health = current
    if current <= 0.0:
      right_guard_visual.visible = false
      guard_broken.emit(&"RIGHT")
  return applied


func _check_core_exposure() -> void:
  if phase_two or left_guard_health > 0.0 or right_guard_health > 0.0:
    return
  phase_two = true
  core_visual.visible = true
  ai_state = AIState.CORE_EXPOSED
  state_time = 0.0
  core_exposed.emit()


func _begin_telegraph(attack_name: StringName) -> void:
  queued_attack = attack_name
  state_time = 0.0
  ai_state = AIState.FRONTAL_TELEGRAPH if attack_name == &"WARDEN_LANCE" else AIState.SWEEP_TELEGRAPH
  attack_telegraphed.emit(attack_name)


func _begin_recovery() -> void:
  ai_state = AIState.RECOVER
  state_time = 0.0


func _defeat() -> void:
  world_state = WorldState.DEFEATED
  core_health = 0.0
  combat_active = false
  ai_state = AIState.DEFEATED
  state_time = 0.0
  _set_charge_visual(0.0)
  world_state_changed.emit(&"defeated")
  defeated.emit()


func _set_charge_visual(strength: float) -> void:
  lance_visual.scale = Vector3.ONE * lerpf(1.0, 1.85, strength)
  if not phase_two:
    core_visual.visible = strength > 0.05
    core_visual.scale = Vector3.ONE * lerpf(0.45, 0.85, strength)


func _build_visual() -> void:
  body_visual = Node3D.new()
  body_visual.name = "Body"
  add_child(body_visual)
  _capsule(body_visual, "HeavyCore", Vector3.ZERO, 5.0, 14.0, Vector3(90, 0, 0), _stone, Vector3(1.2, 1.0, 0.85))
  _box(body_visual, "DorsalBlade", Vector3(0, 4.2, 1.2), Vector3(2.2, 7.5, 8.0), Vector3(-15, 0, 0), _metal)
  _box(body_visual, "VentralKeel", Vector3(0, -4.1, 1.5), Vector3(1.8, 6.5, 7.0), Vector3(16, 0, 0), _metal)
  lance_visual = _box(body_visual, "FrontalLance", Vector3(0, 0, -10.0), Vector3(2.0, 2.0, 12.0), Vector3.ZERO, _bone)
  for side in [-1.0, 1.0]:
    var outer := Node3D.new()
    outer.name = "LeftGuard" if side < 0 else "RightGuard"
    outer.position = Vector3(side * 7.0, 0, 0.5)
    add_child(outer)
    _box(outer, "OuterPlate", Vector3.ZERO, Vector3(5.5, 8.0, 11.0), Vector3(0, side * 8, side * 7), _bone)
    _box(outer, "SweepBlade", Vector3(side * 4.0, 0, 2.0), Vector3(7.0, 1.2, 9.0), Vector3(0, side * -18, side * 4), _metal)
    if side < 0:
      left_guard_visual = outer
    else:
      right_guard_visual = outer
  core_visual = _sphere(body_visual, "VulnerableCore", Vector3(0, 0, -5.2), 2.1, _energy)
  for side in [-1.0, 1.0]:
    _box(body_visual, "RearFin%s" % ("Left" if side < 0 else "Right"), Vector3(side * 3.5, 0, 7.0), Vector3(5.0, 0.8, 7.5), Vector3(0, side * 14, side * 8), _metal)


func _box(parent: Node3D, node_name: String, position_value: Vector3, size: Vector3, rotation_value: Vector3, material: Material) -> MeshInstance3D:
  var instance := MeshInstance3D.new()
  instance.name = node_name
  instance.position = position_value
  instance.rotation_degrees = rotation_value
  var mesh := BoxMesh.new()
  mesh.size = size
  mesh.material = material
  instance.mesh = mesh
  parent.add_child(instance)
  return instance


func _capsule(parent: Node3D, node_name: String, position_value: Vector3, radius: float, height: float, rotation_value: Vector3, material: Material, scale_value: Vector3) -> MeshInstance3D:
  var instance := MeshInstance3D.new()
  instance.name = node_name
  instance.position = position_value
  instance.rotation_degrees = rotation_value
  instance.scale = scale_value
  var mesh := CapsuleMesh.new()
  mesh.radius = radius
  mesh.height = height
  mesh.radial_segments = 10
  mesh.rings = 4
  mesh.material = material
  instance.mesh = mesh
  parent.add_child(instance)
  return instance


func _sphere(parent: Node3D, node_name: String, position_value: Vector3, radius: float, material: Material) -> MeshInstance3D:
  var instance := MeshInstance3D.new()
  instance.name = node_name
  instance.position = position_value
  var mesh := SphereMesh.new()
  mesh.radius = radius
  mesh.height = radius * 2.0
  mesh.radial_segments = 10
  mesh.rings = 5
  mesh.material = material
  instance.mesh = mesh
  parent.add_child(instance)
  return instance
