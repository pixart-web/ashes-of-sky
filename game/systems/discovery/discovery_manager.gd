class_name DiscoveryManager
extends Node

signal discovery_registered(data: DiscoveryData)
signal journal_changed
signal discoveries_reset
signal interaction_availability_changed(data: DiscoveryData, available: bool)
signal echo_open_requested(data: DiscoveryData)
signal discovery_audio_requested(category: DiscoveryData.Category)

var _definitions: Dictionary = {}
var _discovered_ids: Dictionary = {}
var _interaction_data: DiscoveryData
var _interaction_point: Node


func _unhandled_input(event: InputEvent) -> void:
  if event.is_action_pressed(&"reset_discoveries"):
    reset_discoveries()
    get_viewport().set_input_as_handled()
    return
  if event.is_action_pressed(&"interact") and _interaction_data != null:
    activate_current_interaction()
    get_viewport().set_input_as_handled()


func register_definition(data: DiscoveryData) -> bool:
  if data == null or not data.is_valid():
    push_warning("DiscoveryManager rejected invalid discovery data.")
    return false
  if _definitions.has(data.discovery_id):
    return _definitions[data.discovery_id] == data
  _definitions[data.discovery_id] = data
  return true


func discover_data(data: DiscoveryData) -> bool:
  if not register_definition(data):
    return false
  if _discovered_ids.has(data.discovery_id):
    return false

  _discovered_ids[data.discovery_id] = true
  discovery_registered.emit(data)
  discovery_audio_requested.emit(data.category)
  journal_changed.emit()
  return true


func discover(discovery_id: StringName) -> bool:
  return discover_data(get_definition(discovery_id))


func is_discovered(discovery_id: StringName) -> bool:
  return _discovered_ids.has(discovery_id)


func get_definition(discovery_id: StringName) -> DiscoveryData:
  return _definitions.get(discovery_id) as DiscoveryData


func get_definition_count() -> int:
  return _definitions.size()


func get_discovered_count() -> int:
  return _discovered_ids.size()


func get_discovered_entries(category_filter: int = -1) -> Array[DiscoveryData]:
  var entries: Array[DiscoveryData] = []
  for discovery_id in _discovered_ids:
    var data := get_definition(discovery_id)
    if data == null:
      continue
    if category_filter >= 0 and data.category != category_filter:
      continue
    entries.append(data)
  entries.sort_custom(func(a: DiscoveryData, b: DiscoveryData) -> bool:
    return a.display_name.naturalnocasecmp_to(b.display_name) < 0
  )
  return entries


func create_persistence_snapshot() -> Dictionary:
  var stable_ids: Array[String] = []
  for discovery_id in _discovered_ids:
    stable_ids.append(String(discovery_id))
  stable_ids.sort()
  return {"discovered_ids": stable_ids}


func restore_persistence_snapshot(snapshot: Dictionary) -> void:
  reset_discoveries()
  var stored_ids: Array = snapshot.get("discovered_ids", [])
  for stored_id in stored_ids:
    var discovery_id := StringName(stored_id)
    if _definitions.has(discovery_id):
      _discovered_ids[discovery_id] = true
  journal_changed.emit()


func reset_discoveries() -> void:
  _discovered_ids.clear()
  discoveries_reset.emit()
  journal_changed.emit()


func set_interaction_candidate(
  data: DiscoveryData,
  point: Node,
  available: bool
) -> void:
  if available:
    register_definition(data)
    _interaction_data = data
    _interaction_point = point
    interaction_availability_changed.emit(data, true)
  elif _interaction_point == point:
    interaction_availability_changed.emit(_interaction_data, false)
    _interaction_data = null
    _interaction_point = null


func activate_current_interaction() -> bool:
  if _interaction_data == null:
    return false
  discover_data(_interaction_data)
  echo_open_requested.emit(_interaction_data)
  return true
