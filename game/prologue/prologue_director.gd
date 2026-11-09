class_name PrologueDirector
extends Node

signal prologue_state_changed(previous_id: StringName, current_id: StringName)
signal world_reaction_changed(object_id: StringName, state_id: StringName)
signal prologue_audio_requested(event_name: StringName)
signal music_state_requested(state_id: StringName)
signal threads_changed(entries: Array[Dictionary])
signal presentation_requested(presentation_id: StringName)

enum State {
  FIRST_FLIGHT,
  VALLEY_AWAKENING,
  SILENT_CHAMBER_DISCOVERED,
  LAST_SIGNAL_RECOVERED,
  WARDEN_AWAKENED,
  WARDEN_DEFEATED,
  PROLOGUE_COMPLETE,
}

const STATE_IDS: Array[StringName] = [
  &"first_flight",
  &"valley_awakening",
  &"silent_chamber_discovered",
  &"last_signal_recovered",
  &"warden_awakened",
  &"warden_defeated",
  &"prologue_complete",
]
const LAST_SIGNAL_ID := &"echo_last_signal"
const SILENT_CHAMBER_ID := &"lostplace_silent_chamber"
const THREAD_ID := &"thread_last_signal"

@export_node_path("FirstFlightSequence") var first_flight_path: NodePath
@export_node_path("DiscoveryManager") var discovery_manager_path: NodePath
@export_node_path("DiscoveryUI") var discovery_ui_path: NodePath
@export_node_path("TraversalCoordinator") var traversal_path: NodePath
@export_node_path("AerialCombatController") var combat_path: NodePath
@export_node_path("AshWarden") var warden_path: NodePath
@export_node_path("SilentChamberGroundWorld") var chamber_path: NodePath
@export_node_path("ValleyOfAsh") var valley_path: NodePath
@export_node_path("LunarisFlightCamera") var camera_path: NodePath
@export_node_path("LunarisFlightController") var lunaris_path: NodePath

var state: State = State.FIRST_FLIGHT
var first_flight: FirstFlightSequence
var discovery_manager: DiscoveryManager
var discovery_ui: DiscoveryUI
var traversal: TraversalCoordinator
var combat: AerialCombatController
var warden: AshWarden
var chamber: SilentChamberGroundWorld
var valley: ValleyOfAsh
var flight_camera: LunarisFlightCamera
var lunaris: LunarisFlightController

var signal_reaction_stage: int = -1
var signal_reaction_time: float = 0.0
var signal_reaction_count: int = 0
var aftermath_stage: int = -1
var aftermath_time: float = 0.0
var title_time: float = 0.0
var title_layer: CanvasLayer


func _ready() -> void:
  first_flight = get_node_or_null(first_flight_path) as FirstFlightSequence
  discovery_manager = get_node_or_null(discovery_manager_path) as DiscoveryManager
  discovery_ui = get_node_or_null(discovery_ui_path) as DiscoveryUI
  traversal = get_node_or_null(traversal_path) as TraversalCoordinator
  combat = get_node_or_null(combat_path) as AerialCombatController
  warden = get_node_or_null(warden_path) as AshWarden
  chamber = get_node_or_null(chamber_path) as SilentChamberGroundWorld
  valley = get_node_or_null(valley_path) as ValleyOfAsh
  flight_camera = get_node_or_null(camera_path) as LunarisFlightCamera
  lunaris = get_node_or_null(lunaris_path) as LunarisFlightController
  if not _dependencies_valid():
    push_error("PrologueDirector requires the approved First Flight through Aerial Combat systems.")
    set_process(false)
    return
  _build_title_card()
  first_flight.player_control_granted.connect(_on_player_control_granted)
  discovery_manager.discovery_registered.connect(_on_discovery_registered)
  discovery_ui.echo_closed.connect(_on_echo_closed)
  traversal.traversal_state_changed.connect(_on_traversal_state_changed)
  combat.combat_state_changed.connect(_on_combat_state_changed)
  warden.defeated.connect(_on_warden_defeated)
  threads_changed.connect(discovery_ui.set_thread_entries)
  chamber.reset_prologue_reactions()
  valley.reset_prologue_reactions()
  combat.reset_for_prologue(first_flight.state == FirstFlightSequence.OpeningState.GAMEPLAY)
  combat.set_encounter_enabled(false)
  warden.set_world_state(AshWarden.WorldState.DORMANT, false)
  music_state_requested.emit(&"EXPLORATION")
  if first_flight.state == FirstFlightSequence.OpeningState.GAMEPLAY:
    _advance_to(State.VALLEY_AWAKENING)


func _process(delta: float) -> void:
  advance_timeline(delta)
  if title_time > 0.0:
    title_time = maxf(0.0, title_time - delta)
    title_layer.visible = title_time > 0.0


func advance_timeline(delta: float) -> void:
  if signal_reaction_stage >= 0 and signal_reaction_stage < 3:
    signal_reaction_time += delta
    if signal_reaction_stage == 0 and signal_reaction_time >= 0.8:
      chamber.set_chamber_responded(true)
      signal_reaction_stage = 1
      world_reaction_changed.emit(&"silent_chamber", &"responded")
      prologue_audio_requested.emit(&"LAST_SIGNAL_AFTERMATH")
    if signal_reaction_stage == 1 and signal_reaction_time >= 2.2:
      chamber.set_inner_door_responded(true)
      signal_reaction_stage = 2
      world_reaction_changed.emit(&"inner_door", &"responded")
      prologue_audio_requested.emit(&"INNER_DOOR_RESPONSE")
    if signal_reaction_stage == 2 and signal_reaction_time >= 4.2:
      _awaken_valley()
  if aftermath_stage >= 0 and aftermath_stage < 2:
    aftermath_time += delta
    if aftermath_stage == 0 and aftermath_time >= 0.9:
      valley.set_spire_state(ValleyOfAsh.SpireState.SIGNAL, true)
      aftermath_stage = 1
      world_reaction_changed.emit(&"spire", &"signal")
      prologue_audio_requested.emit(&"SPIRE_PULSE")
      _focus_camera_on_spire(3.2)
    if aftermath_stage == 1 and aftermath_time >= 3.0:
      aftermath_stage = 2
      _advance_to(State.PROLOGUE_COMPLETE)
      music_state_requested.emit(&"EXPLORATION")
      prologue_audio_requested.emit(&"PROLOGUE_COMPLETION")
      presentation_requested.emit(&"chapter_i_the_ashen_signal")
      _show_title_card()


func get_state_id() -> StringName:
  return STATE_IDS[state]


func get_thread_entries() -> Array[Dictionary]:
  var entries: Array[Dictionary] = []
  if state < State.LAST_SIGNAL_RECOVERED:
    return entries
  var text := "The recovered signal disturbed something beyond the chamber."
  if state >= State.WARDEN_AWAKENED:
    text = "Something ancient has awakened in the valley."
  if state >= State.WARDEN_DEFEATED:
    text = "The guardian answered the signal. The Spire remains active."
  entries.append({"thread_id": THREAD_ID, "title": "THE LAST SIGNAL", "text": text})
  return entries


func create_persistence_snapshot() -> Dictionary:
  return {
    "version": 1,
    "state_id": String(get_state_id()),
    "signal_reaction_stage": signal_reaction_stage,
    "signal_reaction_count": signal_reaction_count,
    "aftermath_stage": aftermath_stage,
    "chamber_responded": chamber.chamber_responded,
    "inner_door_responded": chamber.inner_door_responded,
    "spire_state": int(valley.spire_state),
    "warden_state": int(warden.world_state),
    "discoveries": discovery_manager.create_persistence_snapshot(),
  }


func restore_persistence_snapshot(snapshot: Dictionary) -> bool:
  var stored_id := StringName(snapshot.get("state_id", ""))
  var restored_index := STATE_IDS.find(stored_id)
  if restored_index < 0:
    return false
  reset_prologue_state(false)
  discovery_manager.restore_persistence_snapshot(snapshot.get("discoveries", {}))
  state = restored_index as State
  signal_reaction_stage = int(snapshot.get("signal_reaction_stage", -1))
  signal_reaction_count = int(snapshot.get("signal_reaction_count", 0))
  aftermath_stage = int(snapshot.get("aftermath_stage", -1))
  chamber.set_chamber_responded(bool(snapshot.get("chamber_responded", false)))
  chamber.set_inner_door_responded(bool(snapshot.get("inner_door_responded", false)))
  valley.set_spire_state(int(snapshot.get("spire_state", ValleyOfAsh.SpireState.DORMANT)) as ValleyOfAsh.SpireState, false)
  warden.set_world_state(int(snapshot.get("warden_state", AshWarden.WorldState.DORMANT)) as AshWarden.WorldState, false)
  combat.set_encounter_enabled(state >= State.WARDEN_AWAKENED and state < State.WARDEN_DEFEATED)
  combat.encounter_completed = state >= State.WARDEN_DEFEATED
  _update_threads()
  return true


func reset_prologue_state(reset_discoveries: bool = true) -> void:
  var previous := get_state_id()
  state = State.FIRST_FLIGHT
  signal_reaction_stage = -1
  signal_reaction_time = 0.0
  signal_reaction_count = 0
  aftermath_stage = -1
  aftermath_time = 0.0
  title_time = 0.0
  if title_layer != null:
    title_layer.visible = false
  chamber.reset_prologue_reactions()
  valley.reset_prologue_reactions()
  combat.reset_for_prologue()
  combat.set_encounter_enabled(false)
  warden.set_world_state(AshWarden.WorldState.DORMANT, false)
  flight_camera.clear_story_target()
  if reset_discoveries:
    discovery_manager.reset_discoveries()
  _update_threads()
  prologue_state_changed.emit(previous, get_state_id())


func start_after_first_flight_debug() -> void:
  reset_prologue_state(true)
  _ensure_direct_gameplay()
  _advance_to(State.VALLEY_AWAKENING)


func start_at_silent_chamber_debug() -> void:
  start_after_first_flight_debug()
  traversal.start_ground_debug()
  discovery_manager.discover(SILENT_CHAMBER_ID)
  _advance_to(State.SILENT_CHAMBER_DISCOVERED)


func start_after_last_signal_debug() -> void:
  start_at_silent_chamber_debug()
  discovery_manager.discover(LAST_SIGNAL_ID)
  _advance_to(State.LAST_SIGNAL_RECOVERED)
  chamber.set_chamber_responded(true)
  chamber.set_inner_door_responded(true)
  _awaken_valley()


func start_at_warden_debug() -> void:
  start_after_last_signal_debug()
  traversal.reset_to_flight()
  combat.start_combat_debug()


func start_after_warden_debug() -> void:
  start_after_last_signal_debug()
  traversal.reset_to_flight()
  combat.reset_for_prologue()
  combat.encounter_completed = true
  combat.set_encounter_enabled(false)
  warden.set_world_state(AshWarden.WorldState.DEFEATED, false)
  valley.set_spire_state(ValleyOfAsh.SpireState.SIGNAL, false)
  _advance_to(State.WARDEN_DEFEATED)
  aftermath_stage = 2
  _advance_to(State.PROLOGUE_COMPLETE)


func _unhandled_input(event: InputEvent) -> void:
  if event.is_action_pressed(&"prologue_reset"):
    reset_prologue_state(true)
  elif event.is_action_pressed(&"prologue_after_first_flight"):
    start_after_first_flight_debug()
  elif event.is_action_pressed(&"prologue_at_silent_chamber"):
    start_at_silent_chamber_debug()
  elif event.is_action_pressed(&"prologue_after_last_signal"):
    start_after_last_signal_debug()
  elif event.is_action_pressed(&"prologue_at_warden"):
    start_at_warden_debug()
  elif event.is_action_pressed(&"prologue_after_warden"):
    start_after_warden_debug()
  else:
    return
  get_viewport().set_input_as_handled()


func _on_player_control_granted() -> void:
  _advance_to(State.VALLEY_AWAKENING)
  music_state_requested.emit(&"EXPLORATION")


func _on_discovery_registered(data: DiscoveryData) -> void:
  if data.discovery_id == SILENT_CHAMBER_ID:
    _advance_to(State.SILENT_CHAMBER_DISCOVERED)
    music_state_requested.emit(&"SILENT_CHAMBER")
  elif data.discovery_id == LAST_SIGNAL_ID:
    _advance_to(State.LAST_SIGNAL_RECOVERED)
    _update_threads()


func _on_echo_closed(data: DiscoveryData) -> void:
  if data == null or data.discovery_id != LAST_SIGNAL_ID or signal_reaction_count > 0:
    return
  signal_reaction_count = 1
  signal_reaction_stage = 0
  signal_reaction_time = 0.0
  music_state_requested.emit(&"SIGNAL_REACTION")


func _on_traversal_state_changed(previous: TraversalCoordinator.TraversalState, current: TraversalCoordinator.TraversalState) -> void:
  if previous == TraversalCoordinator.TraversalState.TAKEOFF and current == TraversalCoordinator.TraversalState.FLIGHT and state >= State.WARDEN_AWAKENED:
    _focus_camera_on_spire(3.2)


func _on_warden_defeated() -> void:
  _advance_to(State.WARDEN_DEFEATED)
  _update_threads()
  music_state_requested.emit(&"AFTERMATH")
  prologue_audio_requested.emit(&"WARDEN_DEFEAT_AFTERMATH")


func _on_combat_state_changed(_previous: AerialCombatController.CombatState, current: AerialCombatController.CombatState) -> void:
  if current == AerialCombatController.CombatState.COMBAT:
    music_state_requested.emit(&"WARDEN")
  elif current == AerialCombatController.CombatState.EXPLORATION and state == State.WARDEN_DEFEATED and aftermath_stage < 0:
    aftermath_stage = 0
    aftermath_time = 0.0


func _awaken_valley() -> void:
  if state >= State.WARDEN_AWAKENED:
    signal_reaction_stage = 3
    return
  valley.set_spire_state(ValleyOfAsh.SpireState.AWAKENED, true)
  warden.set_world_state(AshWarden.WorldState.AWAKENED, true)
  combat.set_encounter_enabled(true)
  signal_reaction_stage = 3
  _advance_to(State.WARDEN_AWAKENED)
  world_reaction_changed.emit(&"spire", &"awakened")
  world_reaction_changed.emit(&"ash_warden", &"awakened")
  prologue_audio_requested.emit(&"SPIRE_AWAKENING")
  prologue_audio_requested.emit(&"WARDEN_AWAKENING")
  prologue_audio_requested.emit(&"DISTANT_WARDEN_CALL")
  _react_lunaris()
  _update_threads()


func _advance_to(next_state: State) -> bool:
  if next_state <= state:
    return false
  var previous := get_state_id()
  state = next_state
  prologue_state_changed.emit(previous, get_state_id())
  _update_threads()
  return true


func _update_threads() -> void:
  threads_changed.emit(get_thread_entries())


func _focus_camera_on_spire(duration: float) -> void:
  flight_camera.set_story_target(valley.get_spire_focus_target(), duration, 0.1)


func _react_lunaris() -> void:
  var interface := lunaris.get_node_or_null("VisualPivot/LunarisVisual/ArchitectInterface") as Node3D
  if interface == null:
    return
  var tween := interface.create_tween()
  tween.tween_property(interface, "scale", Vector3.ONE * 1.08, 0.35)
  tween.tween_property(interface, "scale", Vector3.ONE, 0.7)


func _ensure_direct_gameplay() -> void:
  first_flight.start_direct_gameplay()
  traversal.reset_to_flight()


func _dependencies_valid() -> bool:
  return first_flight != null and discovery_manager != null and discovery_ui != null and traversal != null and combat != null and warden != null and chamber != null and valley != null and flight_camera != null and lunaris != null


func _build_title_card() -> void:
  title_layer = CanvasLayer.new()
  title_layer.name = "PrologueTitleCard"
  title_layer.layer = 8
  title_layer.visible = false
  get_parent().add_child.call_deferred(title_layer)
  var label := Label.new()
  label.set_anchors_preset(Control.PRESET_CENTER_TOP)
  label.position = Vector2(-180, 72)
  label.size = Vector2(360, 90)
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  label.text = "PROLOGUE COMPLETE\nTHE ASHEN SIGNAL"
  label.add_theme_font_size_override("font_size", 24)
  title_layer.add_child(label)


func _show_title_card() -> void:
  title_time = 5.0
  title_layer.visible = true
