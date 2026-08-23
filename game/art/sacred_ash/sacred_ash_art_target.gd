class_name SacredAshArtTarget
extends Node3D

const DARK_STONE := preload("res://art/sacred_ash/materials/m_architect_dark_stone.tres")
const AGED_METAL := preload("res://art/sacred_ash/materials/m_architect_aged_metal.tres")
const CYAN_ACTIVE := preload("res://art/sacred_ash/materials/m_architect_cyan_active.tres")
const VALLEY_ASH := preload("res://art/sacred_ash/materials/m_valley_ash.tres")
const VALLEY_ROCK := preload("res://art/sacred_ash/materials/m_valley_rock.tres")
const VALLEY_DUST := preload("res://art/sacred_ash/materials/m_valley_dust.tres")
const ARCHITECT_KIT := preload("res://art/sacred_ash/architect_prototype_kit.gd")

@export_category("References")
@export_node_path("WorldEnvironment") var world_environment_path: NodePath
@export_node_path("DirectionalLight3D") var sun_path: NodePath
@export_node_path("Camera3D") var gameplay_camera_path: NodePath
@export_node_path("CanvasLayer") var debug_hud_path: NodePath
@export_node_path("CanvasLayer") var discovery_ui_path: NodePath
@export_node_path("CanvasLayer") var opening_ui_path: NodePath
@export_node_path("GPUParticles3D") var speed_particles_path: NodePath

@export_category("Development")
@export var enable_debug_shortcuts: bool = true
@export var atmosphere_particles_enabled: bool = true

var art_target_camera: Camera3D
var ash_particles: GPUParticles3D
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var gameplay_camera: Camera3D
var debug_hud: CanvasLayer
var discovery_ui: CanvasLayer
var opening_ui: CanvasLayer
var speed_particles: GPUParticles3D
var cyan_visualization_enabled: bool = false
var screenshot_mode_enabled: bool = false
var cyan_active_material: StandardMaterial3D

var _canvas_layer_visibility: Dictionary = {}
var _speed_particles_were_visible: bool = true


func _ready() -> void:
  cyan_active_material = CYAN_ACTIVE.duplicate() as StandardMaterial3D
  world_environment = get_node_or_null(world_environment_path) as WorldEnvironment
  sun = get_node_or_null(sun_path) as DirectionalLight3D
  gameplay_camera = get_node_or_null(gameplay_camera_path) as Camera3D
  debug_hud = get_node_or_null(debug_hud_path) as CanvasLayer
  discovery_ui = get_node_or_null(discovery_ui_path) as CanvasLayer
  opening_ui = get_node_or_null(opening_ui_path) as CanvasLayer
  speed_particles = get_node_or_null(speed_particles_path) as GPUParticles3D
  _build_starting_cliff_art_pass()
  _build_valley_midground()
  _build_distant_horizon()
  _build_spire_art_pass()
  _build_atmosphere_particles()
  _build_art_target_camera()


func _unhandled_input(event: InputEvent) -> void:
  if not enable_debug_shortcuts:
    return
  if event.is_action_pressed(&"toggle_screenshot_mode"):
    set_screenshot_mode_enabled(not screenshot_mode_enabled)
    get_viewport().set_input_as_handled()
  elif event.is_action_pressed(&"toggle_art_target_camera"):
    set_art_target_camera_enabled(not art_target_camera.current)
    get_viewport().set_input_as_handled()
  elif event.is_action_pressed(&"toggle_sacred_ash_fog"):
    set_fog_enabled(not is_fog_enabled())
    get_viewport().set_input_as_handled()
  elif event.is_action_pressed(&"toggle_sacred_ash_particles"):
    set_particles_enabled(not ash_particles.emitting)
    get_viewport().set_input_as_handled()
  elif event.is_action_pressed(&"toggle_cyan_visualization"):
    set_cyan_visualization_enabled(not cyan_visualization_enabled)
    get_viewport().set_input_as_handled()


func set_screenshot_mode_enabled(enabled: bool) -> void:
  if screenshot_mode_enabled == enabled:
    return
  screenshot_mode_enabled = enabled
  if enabled:
    _canvas_layer_visibility.clear()
    for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
      var canvas_layer := layer as CanvasLayer
      _canvas_layer_visibility[canvas_layer] = canvas_layer.visible
      canvas_layer.visible = false
    if speed_particles != null:
      _speed_particles_were_visible = speed_particles.visible
      speed_particles.visible = false
  else:
    for layer in _canvas_layer_visibility:
      if is_instance_valid(layer):
        (layer as CanvasLayer).visible = _canvas_layer_visibility[layer]
    _canvas_layer_visibility.clear()
    if speed_particles != null:
      speed_particles.visible = _speed_particles_were_visible


func set_art_target_camera_enabled(enabled: bool) -> void:
  if art_target_camera == null or gameplay_camera == null:
    return
  if enabled:
    art_target_camera.current = true
  else:
    gameplay_camera.current = true


func set_fog_enabled(enabled: bool) -> void:
  if world_environment != null and world_environment.environment != null:
    world_environment.environment.fog_enabled = enabled


func is_fog_enabled() -> bool:
  return world_environment != null and world_environment.environment != null and world_environment.environment.fog_enabled


func set_particles_enabled(enabled: bool) -> void:
  atmosphere_particles_enabled = enabled
  if ash_particles != null:
    ash_particles.emitting = enabled


func set_cyan_visualization_enabled(enabled: bool) -> void:
  cyan_visualization_enabled = enabled
  cyan_active_material.emission_energy_multiplier = 2.4 if enabled else 0.8


func get_material_library() -> Array[StandardMaterial3D]:
  return [DARK_STONE, AGED_METAL, cyan_active_material, VALLEY_ASH, VALLEY_ROCK, VALLEY_DUST]


func get_architect_module_ids() -> Array[String]:
  var ids: Array[String] = []
  for module in find_children("*", "Node3D", true, false):
    if module.has_meta("architect_module"):
      var module_id := String(module.get_meta("architect_module"))
      if module_id not in ids:
        ids.append(module_id)
  return ids


func _build_starting_cliff_art_pass() -> void:
  var cliff := Node3D.new()
  cliff.name = "StartingCliffArtPass"
  cliff.set_meta("composition", "open asymmetrical ceremonial overlook")
  add_child(cliff)
  _add_prism(cliff, "NaturalRockFoundationWest", Vector3(-72, 139, 650), Vector3(72, 25, 74), Vector3(0, 16, 0), VALLEY_ROCK)
  _add_prism(cliff, "NaturalRockFoundationEast", Vector3(70, 137, 646), Vector3(58, 21, 68), Vector3(0, -13, 0), VALLEY_ROCK)
  _add_prism(cliff, "BrokenCeremonialFloorWest", Vector3(-32, 145, 624), Vector3(50, 4, 58), Vector3(0, -8, 1), AGED_METAL)
  _add_prism(cliff, "BrokenCeremonialFloorEast", Vector3(31, 144, 616), Vector3(34, 3, 44), Vector3(0, 14, -2), DARK_STONE)
  _place_module(cliff, ARCHITECT_KIT.monumental_arch("PartialCeremonialArch", DARK_STONE, AGED_METAL), Vector3(-103, 148, 608), Vector3.ZERO, Vector3(0.72, 0.72, 0.72))
  _place_module(cliff, ARCHITECT_KIT.vertical_blade("AsymmetricBladeWest", DARK_STONE, AGED_METAL), Vector3(-154, 145, 628), Vector3.ZERO, Vector3(0.72, 1.0, 0.72))
  _place_module(cliff, ARCHITECT_KIT.vertical_blade("AsymmetricBladeEast", DARK_STONE, AGED_METAL), Vector3(142, 145, 635), Vector3.ZERO, Vector3(0.62, 0.72, 0.62))
  _place_module(cliff, ARCHITECT_KIT.divided_halo("DividedHalo001", DARK_STONE, AGED_METAL, "broken"), Vector3(92, 184, 610), Vector3.ZERO, Vector3(0.84, 0.84, 0.84))


func _build_valley_midground() -> void:
  var midground := Node3D.new()
  midground.name = "ValleyMidgroundArtPass"
  midground.set_meta("uses_negative_space", true)
  midground.set_meta("visual_corridor_half_width", 110.0)
  add_child(midground)
  _place_module(midground, ARCHITECT_KIT.monumental_arch("MonumentalArchWest", DARK_STONE, AGED_METAL), Vector3(-235, 12, 335), Vector3(0, 10, 0), Vector3(1.05, 1.05, 1.05))
  _place_module(midground, ARCHITECT_KIT.architect_pillar("CeremonialPillarEast", DARK_STONE, AGED_METAL), Vector3(250, 1, 180), Vector3(0, -12, 0), Vector3(1.15, 1.15, 1.15))
  _place_module(midground, ARCHITECT_KIT.broken_wall("BreachedWallEast", DARK_STONE, AGED_METAL), Vector3(275, 2, -35), Vector3(0, -18, 0), Vector3(1.25, 1.25, 1.25))
  _place_module(midground, ARCHITECT_KIT.vertical_blade("CanyonBladeWest", DARK_STONE, AGED_METAL), Vector3(-285, 0, -110), Vector3(0, 9, 0), Vector3(1.1, 1.3, 1.1))
  _place_module(midground, ARCHITECT_KIT.collapsed_monument("CollapsedMonumentEast", DARK_STONE, AGED_METAL), Vector3(225, 2, -260), Vector3(0, -14, 0), Vector3(1.2, 1.2, 1.2))
  _place_module(midground, ARCHITECT_KIT.gate_module("OpenCanyonGate", DARK_STONE, AGED_METAL), Vector3(-170, 0, -405), Vector3(0, 7, 0), Vector3(1.15, 1.15, 1.15))
  _place_module(midground, ARCHITECT_KIT.divided_halo("MidgroundInactiveHalo", DARK_STONE, AGED_METAL, "broken"), Vector3(215, 80, -430), Vector3.ZERO, Vector3(1.35, 1.35, 1.35))
  _place_module(midground, ARCHITECT_KIT.divided_halo("BuriedInactiveHalo", DARK_STONE, AGED_METAL, "buried"), Vector3(-300, 20, -285), Vector3(0, 8, 0), Vector3.ONE)


func _build_distant_horizon() -> void:
  var horizon := Node3D.new()
  horizon.name = "DistantHorizonSilhouettes"
  horizon.set_meta("sparse_composition", true)
  add_child(horizon)
  _add_prism(horizon, "WestErodedRidge", Vector3(-560, 158, -870), Vector3(280, 190, 120), Vector3(0, 7, 0), VALLEY_ROCK)
  _add_prism(horizon, "WestAshMountain", Vector3(-300, 145, -880), Vector3(210, 165, 105), Vector3(0, -5, 0), VALLEY_ROCK)
  _add_prism(horizon, "EastAshMountain", Vector3(330, 150, -878), Vector3(245, 176, 110), Vector3(0, 8, 0), VALLEY_ROCK)
  _add_prism(horizon, "EastErodedRidge", Vector3(610, 162, -868), Vector3(260, 200, 125), Vector3(0, -7, 0), VALLEY_ROCK)


func _build_spire_art_pass() -> void:
  var spire := Node3D.new()
  spire.name = "SpireSacredAshArtPass"
  spire.set_meta("conceptual_height_m", 360)
  spire.set_meta("cyan_usage", "restrained_single_beacon")
  spire.set_meta("silhouette", "one dominant core one iconic halo three fractured masses")
  add_child(spire)
  _place_module(spire, ARCHITECT_KIT.spire_module("ArchitectSpireModule", DARK_STONE, AGED_METAL, cyan_active_material), Vector3(0, 20, -650), Vector3.ZERO, Vector3(1.08, 1.08, 1.08))


func _build_atmosphere_particles() -> void:
  ash_particles = GPUParticles3D.new()
  ash_particles.name = "StartingCliffAshParticles"
  ash_particles.position = Vector3(0, 178, 625)
  ash_particles.amount = 28
  ash_particles.lifetime = 15.0
  ash_particles.preprocess = 15.0
  ash_particles.randomness = 0.9
  ash_particles.visibility_aabb = AABB(Vector3(-150, -70, -130), Vector3(300, 140, 260))
  ash_particles.emitting = atmosphere_particles_enabled
  var process_material := ParticleProcessMaterial.new()
  process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
  process_material.emission_box_extents = Vector3(120, 42, 95)
  process_material.direction = Vector3(-0.75, 0.08, -0.42)
  process_material.spread = 36.0
  process_material.gravity = Vector3(0, -0.006, 0)
  process_material.initial_velocity_min = 0.08
  process_material.initial_velocity_max = 0.24
  process_material.scale_min = 0.35
  process_material.scale_max = 0.8
  ash_particles.process_material = process_material
  var particle_material := StandardMaterial3D.new()
  particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
  particle_material.albedo_color = Color(0.32, 0.3, 0.29, 0.11)
  var particle_mesh := QuadMesh.new()
  particle_mesh.size = Vector2(0.045, 0.045)
  particle_mesh.material = particle_material
  ash_particles.draw_pass_1 = particle_mesh
  add_child(ash_particles)


func _build_art_target_camera() -> void:
  art_target_camera = Camera3D.new()
  art_target_camera.name = "SacredAshArtTargetCamera"
  art_target_camera.position = Vector3(-12, 162, 690)
  art_target_camera.fov = 60.0
  art_target_camera.current = false
  art_target_camera.set_meta("development_only", true)
  art_target_camera.set_meta("composition", "Lunaris open valley Spire sky")
  art_target_camera.look_at_from_position(art_target_camera.position, Vector3(0, 115, -505), Vector3.UP)
  add_child(art_target_camera)


func _place_module(parent: Node3D, module: Node3D, position: Vector3, rotation_value: Vector3, scale_value: Vector3) -> void:
  module.position = position
  module.rotation_degrees = rotation_value
  module.scale = scale_value
  parent.add_child(module)


func _add_prism(parent: Node3D, node_name: String, position: Vector3, size: Vector3, rotation_value: Vector3, material: Material) -> MeshInstance3D:
  var instance := MeshInstance3D.new()
  instance.name = node_name
  instance.position = position
  instance.rotation_degrees = rotation_value
  var mesh := PrismMesh.new()
  mesh.size = size
  mesh.left_to_right = 0.3
  mesh.material = material
  instance.mesh = mesh
  parent.add_child(instance)
  return instance
