class_name DiscoveryPoint
extends Area3D

@export var discovery_data: DiscoveryData
@export var requires_interaction: bool = false
@export_node_path("DiscoveryManager") var discovery_manager_path: NodePath

var discovery_manager: DiscoveryManager


func configure(
  data: DiscoveryData,
  manager: DiscoveryManager,
  interaction_required: bool = false
) -> void:
  discovery_data = data
  discovery_manager = manager
  requires_interaction = interaction_required


func _ready() -> void:
  collision_layer = 0
  collision_mask = 2
  monitoring = true
  monitorable = false

  if discovery_manager == null:
    discovery_manager = get_node_or_null(discovery_manager_path) as DiscoveryManager
  if discovery_manager == null or discovery_data == null:
    push_error("DiscoveryPoint requires discovery data and a DiscoveryManager.")
    monitoring = false
    return

  discovery_manager.register_definition(discovery_data)
  body_entered.connect(_on_body_entered)
  body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
  if discovery_manager != null and requires_interaction:
    discovery_manager.set_interaction_candidate(discovery_data, self, false)


func _on_body_entered(body: Node3D) -> void:
  if body is not LunarisFlightController:
    return
  if requires_interaction:
    discovery_manager.set_interaction_candidate(discovery_data, self, true)
  else:
    discovery_manager.discover_data(discovery_data)


func _on_body_exited(body: Node3D) -> void:
  if body is LunarisFlightController and requires_interaction:
    discovery_manager.set_interaction_candidate(discovery_data, self, false)
