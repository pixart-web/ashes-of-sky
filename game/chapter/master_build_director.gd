class_name MasterBuildDirector
extends Node

signal chapter_state_changed(previous_id: StringName, current_id: StringName)
signal chapter_audio_requested(event_id: StringName)
signal chapter_music_requested(state_id: StringName)
signal chapter_completed

enum State {
  PROLOGUE, FIRST_RESONANCE, SPIRE_APPROACH, SPIRE_GROUND, RESONANCE_VAULT,
  REVELATION, PALE_REACH, SKIMMER_HUNT, SENTINEL, CHAPTER_COMPLETE,
}

const STATE_IDS: Array[StringName] = [
  &"prologue", &"first_resonance", &"spire_approach", &"spire_ground",
  &"resonance_vault", &"revelation", &"pale_reach", &"skimmer_hunt",
  &"veiled_sentinel", &"chapter_complete",
]

@export_node_path("PrologueDirector") var prologue_path: NodePath
@export_node_path("LunarisEvolution") var evolution_path: NodePath
@export_node_path("ResonanceUI") var resonance_ui_path: NodePath
@export_node_path("ChapterOneWorld") var chapter_world_path: NodePath
@export_node_path("ChapterCombat") var chapter_combat_path: NodePath
@export_node_path("GameSaveSystem") var save_system_path: NodePath
@export_node_path("GameFrontend") var frontend_path: NodePath
@export_node_path("DiscoveryManager") var discovery_manager_path: NodePath
@export_node_path("DiscoveryUI") var discovery_ui_path: NodePath
@export_node_path("TraversalCoordinator") var traversal_path: NodePath
@export_node_path("LunarisFlightController") var lunaris_path: NodePath
@export_node_path("GroundPlayer") var ground_player_path: NodePath

var state: State = State.PROLOGUE
var second_resonance_detected: bool = false
var prologue: PrologueDirector
var evolution: LunarisEvolution
var resonance_ui: ResonanceUI
var chapter_world: ChapterOneWorld
var chapter_combat: ChapterCombat
var save_system: GameSaveSystem
var frontend: GameFrontend
var discovery_manager: DiscoveryManager
var discovery_ui: DiscoveryUI
var traversal: TraversalCoordinator
var lunaris: LunarisFlightController
var ground_player: GroundPlayer
var chapter_title: CanvasLayer
var chapter_title_time: float = 0.0
var _definitions: Dictionary = {}
var _chapter_definitions_registered: bool = false


func _ready() -> void:
  prologue = get_node(prologue_path) as PrologueDirector
  evolution = get_node(evolution_path) as LunarisEvolution
  resonance_ui = get_node(resonance_ui_path) as ResonanceUI
  chapter_world = get_node(chapter_world_path) as ChapterOneWorld
  chapter_combat = get_node(chapter_combat_path) as ChapterCombat
  save_system = get_node(save_system_path) as GameSaveSystem
  frontend = get_node(frontend_path) as GameFrontend
  discovery_manager = get_node(discovery_manager_path) as DiscoveryManager
  discovery_ui = get_node(discovery_ui_path) as DiscoveryUI
  traversal = get_node(traversal_path) as TraversalCoordinator
  lunaris = get_node(lunaris_path) as LunarisFlightController
  ground_player = get_node(ground_player_path) as GroundPlayer
  _build_title_card()
  traversal.register_landing_site(&"spire", ChapterOneWorld.SPIRE_LANDING, ChapterOneWorld.SPIRE_DISMOUNT, ChapterOneWorld.SPIRE_RECOVERY, Vector3(0, 0, -1))
  prologue.prologue_state_changed.connect(_on_prologue_state_changed)
  resonance_ui.tendency_chosen.connect(_on_tendency_chosen)
  traversal.traversal_state_changed.connect(_on_traversal_state_changed)
  chapter_world.puzzle_solved.connect(_on_puzzle_solved)
  chapter_combat.encounter_started.connect(_on_encounter_started)
  chapter_combat.encounter_completed.connect(_on_encounter_completed)
  chapter_combat.sentinel_defeated.connect(_on_sentinel_defeated)
  chapter_combat.player_failed.connect(_on_player_failed)
  frontend.new_journey_requested.connect(start_new_journey)
  frontend.continue_requested.connect(continue_journey)
  frontend.return_to_title_requested.connect(_autosave_current)
  chapter_combat.set_process(false)
  _update_threads()


func _process(delta: float) -> void:
  if chapter_title_time > 0.0:
    chapter_title_time = maxf(0.0, chapter_title_time - delta)
    chapter_title.visible = chapter_title_time > 0.0
  if state >= State.SPIRE_APPROACH and state < State.REVELATION and traversal.state == TraversalCoordinator.TraversalState.GROUND and traversal.get_active_site_id() == &"spire":
    _update_spire_ground_discoveries()
  if state >= State.REVELATION and state < State.CHAPTER_COMPLETE and traversal.state == TraversalCoordinator.TraversalState.FLIGHT:
    if lunaris.global_position.z < -1010.0:
      _enter_pale_reach()


func _unhandled_input(event: InputEvent) -> void:
  if event.is_action_pressed(&"interact") and traversal.state == TraversalCoordinator.TraversalState.GROUND and traversal.get_active_site_id() == &"spire":
    if _try_spire_interaction():
      get_viewport().set_input_as_handled()
  elif event.is_action_pressed(&"mb01_first_resonance"):
    start_at_first_resonance_debug()
  elif event.is_action_pressed(&"mb01_spire_exterior"):
    start_at_spire_exterior_debug()
  elif event.is_action_pressed(&"mb01_spire_ground"):
    start_at_spire_ground_debug()
  elif event.is_action_pressed(&"mb01_vault"):
    start_at_vault_debug()
  elif event.is_action_pressed(&"mb01_pale_reach"):
    start_at_pale_reach_debug()
  elif event.is_action_pressed(&"mb01_sentinel"):
    start_at_sentinel_debug()
  elif event.is_action_pressed(&"mb01_chapter_complete"):
    start_after_sentinel_debug()
  elif event.is_action_pressed(&"mb01_reset_chapter"):
    reset_chapter_state()
  elif event.is_action_pressed(&"mb01_reset_save"):
    save_system.delete_save()
  else:
    return
  get_viewport().set_input_as_handled()


func get_state_id() -> StringName:
  return STATE_IDS[state]


func start_new_journey() -> void:
  save_system.delete_save()
  prologue.reset_prologue_state(true)
  reset_chapter_state()
  prologue.first_flight.start_opening()


func continue_journey() -> bool:
  var snapshot := save_system.load_snapshot()
  if snapshot.is_empty():
    return false
  return restore_snapshot(snapshot)


func create_snapshot() -> Dictionary:
  return {
    "chapter_state": String(get_state_id()),
    "prologue": prologue.create_persistence_snapshot(),
    "evolution": evolution.create_snapshot(),
    "chapter_world": chapter_world.create_snapshot(),
    "chapter_combat": chapter_combat.create_snapshot(),
    "discoveries": discovery_manager.create_persistence_snapshot(),
    "second_resonance_detected": second_resonance_detected,
    "threads": get_thread_entries(),
    "settings": frontend.create_settings_snapshot(),
  }


func restore_snapshot(snapshot: Dictionary) -> bool:
  var restored_state := STATE_IDS.find(StringName(snapshot.get("chapter_state", "")))
  if restored_state < 0:
    return false
  _ensure_chapter_definitions()
  prologue.restore_persistence_snapshot(snapshot.get("prologue", {}))
  evolution.restore_snapshot(snapshot.get("evolution", {}))
  chapter_world.restore_snapshot(snapshot.get("chapter_world", {}))
  chapter_combat.restore_snapshot(snapshot.get("chapter_combat", {}))
  discovery_manager.restore_persistence_snapshot(snapshot.get("discoveries", {}))
  frontend.restore_settings_snapshot(snapshot.get("settings", {}))
  state = restored_state as State
  second_resonance_detected = bool(snapshot.get("second_resonance_detected", false))
  chapter_combat.set_process(state >= State.PALE_REACH and state < State.CHAPTER_COMPLETE)
  lunaris.reset_flight(Transform3D(Basis.IDENTITY, save_system.last_safe_position))
  prologue.first_flight.start_direct_gameplay()
  traversal.reset_to_flight()
  _update_threads()
  return true


func reset_chapter_state() -> void:
  var previous := get_state_id()
  state = State.PROLOGUE
  second_resonance_detected = false
  evolution.reset_evolution()
  chapter_world.reset_chapter_world()
  chapter_combat.reset_chapter_combat()
  chapter_combat.set_process(false)
  resonance_ui.close_choice()
  chapter_title.visible = false
  _update_threads()
  chapter_state_changed.emit(previous, get_state_id())


func get_thread_entries() -> Array[Dictionary]:
  var entries := prologue.get_thread_entries()
  if state >= State.FIRST_RESONANCE:
    entries.append({"thread_id": &"thread_spire", "title": "THE AWAKENED SPIRE", "text": "The Resonance opened a path through the Spire's broken rings."})
  if state >= State.REVELATION:
    entries.append({"thread_id": &"thread_containment", "title": "THE CONTAINMENT", "text": "The Silence followed an intentional containment. Its purpose remains hidden."})
  if state >= State.PALE_REACH:
    entries.append({"thread_id": &"thread_sky_below", "title": "THE SKY BELOW", "text": "A phrase repeated beneath the Pale Reach. Something beyond the cloud layer answered."})
  if state == State.CHAPTER_COMPLETE:
    entries.append({"thread_id": &"thread_second_resonance", "title": "A SECOND CAPACITY", "text": "Another Resonance is detectable within Lunaris, but remains locked."})
  return entries


func start_at_first_resonance_debug() -> void:
  prologue.start_after_warden_debug()
  _begin_first_resonance()


func start_at_spire_exterior_debug() -> void:
  start_at_first_resonance_debug()
  resonance_ui._choose(LunarisEvolution.Tendency.ORACLE)
  lunaris.reset_flight(Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), ChapterOneWorld.SPIRE_LANDING + Vector3(0, 24, 42)))


func start_at_spire_ground_debug() -> void:
  start_at_spire_exterior_debug()
  traversal.start_ground_at_site_debug(&"spire")
  _advance_to(State.SPIRE_GROUND)


func start_at_vault_debug() -> void:
  start_at_spire_ground_debug()
  for index in range(3):
    chapter_world.activate_puzzle_node(index)
  ground_player.reset_ground(ChapterOneWorld.VAULT_POSITION)


func start_at_pale_reach_debug() -> void:
  start_at_vault_debug()
  chapter_world.complete_revelation()
  traversal.reset_to_flight()
  lunaris.reset_flight(Transform3D(Basis.IDENTITY, ChapterOneWorld.PALE_REACH_CENTER + Vector3(0, 90, 220)))
  _enter_pale_reach()


func start_at_sentinel_debug() -> void:
  start_at_pale_reach_debug()
  chapter_combat.skimmer_encounters_completed = 2
  lunaris.reset_flight(Transform3D(Basis.IDENTITY, Vector3(0, 100, -1510)))
  chapter_combat.start_sentinel_encounter()
  _advance_to(State.SENTINEL)


func start_after_sentinel_debug() -> void:
  start_at_sentinel_debug()
  chapter_combat.sentinel_phase = 3
  chapter_combat.sentinel_health = 1.0
  chapter_combat.attack(10.0, false)


func _on_prologue_state_changed(_previous: StringName, current: StringName) -> void:
  if current == &"prologue_complete" and state == State.PROLOGUE:
    _begin_first_resonance()


func _begin_first_resonance() -> void:
  _ensure_chapter_definitions()
  _advance_to(State.FIRST_RESONANCE)
  resonance_ui.open_choice()
  chapter_audio_requested.emit(&"FIRST_RESONANCE")
  chapter_music_requested.emit(&"RESONANCE")


func _on_tendency_chosen(tendency: LunarisEvolution.Tendency) -> void:
  if evolution.tendency == LunarisEvolution.Tendency.NONE:
    evolution.select_tendency(tendency)
  chapter_world.set_spire_accessible(true)
  chapter_world.apply_vault_tendency(evolution.get_tendency_id())
  _advance_to(State.SPIRE_APPROACH)
  chapter_audio_requested.emit(&"EVOLUTION_STAGE_ONE")
  chapter_music_requested.emit(&"SPIRE_APPROACH")
  _autosave_current()


func _on_traversal_state_changed(_previous: TraversalCoordinator.TraversalState, current: TraversalCoordinator.TraversalState) -> void:
  if current == TraversalCoordinator.TraversalState.GROUND and traversal.get_active_site_id() == &"spire":
    _advance_to(State.SPIRE_GROUND)
    _discover(&"lostplace_open_sanctum")
    chapter_music_requested.emit(&"SPIRE_INTERIOR")
  elif current == TraversalCoordinator.TraversalState.FLIGHT and state >= State.REVELATION:
    chapter_audio_requested.emit(&"SPIRE_ROUTE_OPEN")


func _update_spire_ground_discoveries() -> void:
  var position := ground_player.global_position
  if position.distance_to(Vector3(0, 146, -835)) < 28.0:
    _discover(&"landmark_architect_gallery")
  if position.distance_to(ChapterOneWorld.VAULT_POSITION) < 26.0 and chapter_world.puzzle_complete:
    _discover(&"anomaly_resonance_vault")


func _try_spire_interaction() -> bool:
  var position := ground_player.global_position
  for index in range(3):
    var target := Vector3(-24 + index * 24, 151, -790)
    if position.distance_to(target) < 11.0:
      return chapter_world.activate_puzzle_node(index)
  if position.distance_to(Vector3(-22, 160, -835)) < 12.0:
    return _recover_echo(&"echo_divided_voice")
  if position.distance_to(ChapterOneWorld.VAULT_POSITION) < 15.0 and chapter_world.puzzle_complete:
    _discover(&"anomaly_resonance_vault")
    return true
  if position.distance_to(ChapterOneWorld.REVELATION_POSITION) < 18.0 and chapter_world.puzzle_complete:
    _recover_echo(&"echo_containment_event")
    if chapter_world.complete_revelation():
      _advance_to(State.REVELATION)
      chapter_audio_requested.emit(&"PALE_REACH_REVEAL")
      _autosave_current()
    return true
  return false


func _on_puzzle_solved() -> void:
  _advance_to(State.RESONANCE_VAULT)
  chapter_audio_requested.emit(&"VAULT_OPEN")
  _autosave_current()


func _enter_pale_reach() -> void:
  if state < State.PALE_REACH:
    _advance_to(State.PALE_REACH)
    _discover(&"region_pale_reach")
    chapter_combat.set_process(true)
    chapter_music_requested.emit(&"PALE_REACH")
    _autosave_current()


func _on_encounter_started(encounter_id: StringName) -> void:
  if encounter_id == &"veiled_sentinel":
    _advance_to(State.SENTINEL)
    _discover(&"landmark_veiled_sentinel")
    chapter_music_requested.emit(&"SENTINEL")
  else:
    _advance_to(State.SKIMMER_HUNT)


func _on_encounter_completed(_encounter_id: StringName) -> void:
  _autosave_current()


func _on_sentinel_defeated() -> void:
  second_resonance_detected = true
  _advance_to(State.CHAPTER_COMPLETE)
  chapter_combat.set_process(false)
  chapter_title_time = 8.0
  chapter_title.visible = true
  chapter_audio_requested.emit(&"SKY_BELOW_RESPONSE")
  chapter_music_requested.emit(&"CHAPTER_AFTERMATH")
  _update_threads()
  _autosave_current()
  chapter_completed.emit()


func _on_player_failed() -> void:
  lunaris.reset_flight(Transform3D(Basis.IDENTITY, save_system.last_safe_position))


func _advance_to(next_state: State) -> bool:
  if next_state <= state:
    return false
  var previous := get_state_id()
  state = next_state
  chapter_state_changed.emit(previous, get_state_id())
  _update_threads()
  return true


func _discover(discovery_id: StringName) -> bool:
  var result := discovery_manager.discover(discovery_id)
  if result:
    _autosave_current()
  return result


func _recover_echo(discovery_id: StringName) -> bool:
  if not _discover(discovery_id):
    return false
  discovery_ui.open_echo(discovery_manager.get_definition(discovery_id))
  return true


func _autosave_current() -> void:
  if save_system == null or lunaris == null:
    return
  save_system.autosave(create_snapshot(), _get_safe_position())


func _get_safe_position() -> Vector3:
  if traversal.state == TraversalCoordinator.TraversalState.FLIGHT:
    return lunaris.global_position
  if traversal.get_active_site_id() == &"spire":
    return ChapterOneWorld.SPIRE_LANDING + Vector3(0, 20, 35)
  return ValleyOfAsh.SPAWN_POSITION


func _update_threads() -> void:
  discovery_ui.set_thread_entries(get_thread_entries())


func _register_discoveries() -> void:
  _definition(&"lostplace_open_sanctum", "THE OPEN SANCTUM", DiscoveryData.Category.LOST_PLACE, "A wind-exposed threshold suspended inside the Spire.", "The Spire was built to be crossed by air and on foot.")
  _definition(&"landmark_architect_gallery", "THE ARCHITECT GALLERY", DiscoveryData.Category.LANDMARK, "Opposed forms alter the same ancient structure.", "Two hands shaped this place. They did not agree.")
  _definition(&"echo_divided_voice", "A DIVIDED VOICE", DiscoveryData.Category.ECHO, "A contradictory fragment survives in the gallery.", "Hold the seal. Break the seal. Both commands bear the same final mark.")
  _definition(&"anomaly_resonance_vault", "RESONANCE VAULT", DiscoveryData.Category.ANOMALY, "The chamber answers Lunaris differently after the first Resonance.", "The structure recognizes tendency, but not allegiance.")
  _definition(&"echo_containment_event", "THE CONTAINMENT", DiscoveryData.Category.ECHO, "A final record precedes the Silence.", "We did not end the sky. We closed it. Below us, it is still listening.")
  _definition(&"region_pale_reach", "THE PALE REACH", DiscoveryData.Category.REGION, "A cool mineral expanse beyond the Valley.", "Wind exposes buried Architect forms across a pale shelf.")
  _definition(&"landmark_veiled_sentinel", "THE VEILED SENTINEL", DiscoveryData.Category.LANDMARK, "A guardian integrated beneath the Reach.", "Its restraints predate the Silence. Its attention rests on Lunaris.")


func _ensure_chapter_definitions() -> void:
  if _chapter_definitions_registered:
    return
  _chapter_definitions_registered = true
  _register_discoveries()


func _definition(id: StringName, title: String, category: DiscoveryData.Category, description: String, recovered: String) -> void:
  var data := DiscoveryData.new()
  data.discovery_id = id
  data.display_name = title
  data.category = category
  data.short_description = description
  data.recovered_text = recovered
  _definitions[id] = data
  discovery_manager.register_definition(data)


func _build_title_card() -> void:
  chapter_title = CanvasLayer.new()
  chapter_title.name = "ChapterCompletePresentation"
  chapter_title.layer = 20
  chapter_title.visible = false
  add_child(chapter_title)
  var label := Label.new()
  label.position = Vector2(390, 118)
  label.size = Vector2(500, 150)
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  label.text = "THE SKY BELOW\n\nCHAPTER I COMPLETE"
  label.add_theme_font_size_override("font_size", 28)
  label.add_theme_color_override("font_color", Color(0.72, 0.9, 0.91))
  chapter_title.add_child(label)
