class_name GameSaveSystem
extends Node

signal save_completed(path: String)
signal load_completed
signal save_failed(reason: String)

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://ashes_of_the_sky_save.json"

@export var save_path: String = DEFAULT_SAVE_PATH
var last_safe_position: Vector3 = ValleyOfAsh.SPAWN_POSITION
var autosave_count: int = 0


func save_snapshot(snapshot: Dictionary) -> bool:
  var payload := snapshot.duplicate(true)
  payload["save_version"] = SAVE_VERSION
  payload["saved_at_unix"] = int(Time.get_unix_time_from_system())
  payload["safe_player_position"] = [last_safe_position.x, last_safe_position.y, last_safe_position.z]
  var json := JSON.stringify(payload, "  ")
  var temporary_path := save_path + ".tmp"
  var file := FileAccess.open(temporary_path, FileAccess.WRITE)
  if file == null:
    save_failed.emit("Could not open temporary save file.")
    return false
  file.store_string(json)
  file.close()
  if FileAccess.file_exists(save_path):
    DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
  var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(save_path))
  if error != OK:
    save_failed.emit("Could not finalize save file.")
    return false
  save_completed.emit(save_path)
  return true


func autosave(snapshot: Dictionary, safe_position: Vector3) -> bool:
  last_safe_position = safe_position
  var success := save_snapshot(snapshot)
  if success:
    autosave_count += 1
  return success


func load_snapshot() -> Dictionary:
  if not has_save():
    return {}
  var file := FileAccess.open(save_path, FileAccess.READ)
  if file == null:
    save_failed.emit("Could not open save file.")
    return {}
  var parsed = JSON.parse_string(file.get_as_text())
  file.close()
  if not parsed is Dictionary:
    save_failed.emit("Save data is not a dictionary.")
    return {}
  var snapshot: Dictionary = parsed
  if int(snapshot.get("save_version", -1)) != SAVE_VERSION:
    save_failed.emit("Unsupported save version.")
    return {}
  var stored_position: Array = snapshot.get("safe_player_position", [])
  if stored_position.size() == 3:
    last_safe_position = Vector3(float(stored_position[0]), float(stored_position[1]), float(stored_position[2]))
  load_completed.emit()
  return snapshot


func has_save() -> bool:
  return FileAccess.file_exists(save_path)


func delete_save() -> bool:
  if not has_save():
    return true
  return DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path)) == OK


func validate_save() -> bool:
  return not load_snapshot().is_empty()
