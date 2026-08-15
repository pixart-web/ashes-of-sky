extends VBoxContainer

@export_node_path("CharacterBody3D") var flight_controller_path: NodePath
@export_node_path("Node") var world_path: NodePath
@export var show_world_navigation: bool = true

@onready var speed_value: Label = $SpeedValue
@onready var altitude_value: Label = $AltitudeValue
@onready var state_value: Label = $StateValue
@onready var fps_value: Label = $FPSValue
@onready var region_value: Label = $RegionValue
@onready var position_value: Label = $PositionValue
@onready var spire_distance_value: Label = $SpireDistanceValue


func _ready() -> void:
  var flight_controller := get_node_or_null(flight_controller_path)
  if flight_controller != null and flight_controller.has_signal(&"telemetry_updated"):
    flight_controller.connect(&"telemetry_updated", _on_telemetry_updated)

  var world := get_node_or_null(world_path)
  if world != null and world.has_signal(&"world_navigation_updated"):
    world.connect(&"world_navigation_updated", _on_world_navigation_updated)

  region_value.visible = show_world_navigation
  position_value.visible = show_world_navigation
  spire_distance_value.visible = show_world_navigation


func _process(_delta: float) -> void:
  fps_value.text = "FPS: %d" % Engine.get_frames_per_second()


func _on_telemetry_updated(
  speed: float,
  altitude: float,
  flight_state: StringName
) -> void:
  speed_value.text = "SPEED: %.1f m/s" % speed
  altitude_value.text = "ALTITUDE: %.1f m" % altitude
  state_value.text = "FLIGHT STATE: %s" % flight_state


func _on_world_navigation_updated(
  region: StringName,
  world_position: Vector3,
  distance_to_spire: float
) -> void:
  if not show_world_navigation:
    return
  region_value.text = "REGION: %s" % region
  position_value.text = "POSITION: %.0f / %.0f / %.0f" % [
    world_position.x,
    world_position.y,
    world_position.z,
  ]
  spire_distance_value.text = "DISTANCE TO SPIRE: %.0f m" % distance_to_spire
