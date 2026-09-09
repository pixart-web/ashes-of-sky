class_name DiscoveryUI
extends CanvasLayer

signal echo_closed(data: DiscoveryData)

@export_node_path("DiscoveryManager") var discovery_manager_path: NodePath

@onready var banner: PanelContainer = $Root/Banner
@onready var banner_category: Label = $Root/Banner/Margin/Content/Category
@onready var banner_name: Label = $Root/Banner/Margin/Content/Name
@onready var interaction_hint: PanelContainer = $Root/InteractionHint
@onready var interaction_label: Label = $Root/InteractionHint/Margin/Label
@onready var journal_overlay: ColorRect = $Root/JournalOverlay
@onready var journal_text: RichTextLabel = $Root/JournalOverlay/Panel/Margin/Content/JournalText
@onready var echo_overlay: ColorRect = $Root/EchoOverlay
@onready var echo_title: Label = $Root/EchoOverlay/Panel/Margin/Content/EchoTitle
@onready var echo_text: RichTextLabel = $Root/EchoOverlay/Panel/Margin/Content/EchoText

var discovery_manager: DiscoveryManager
var _banner_queue: Array[DiscoveryData] = []
var _banner_tween: Tween
var _echo_tween: Tween
var _overlay_owns_pause: bool = false
var _pause_state_before_overlay: bool = false
var _echo_close_block_frames: int = 0
var _interaction_available: bool = false
var _interaction_data: DiscoveryData
var exploration_input_enabled: bool = true
var thread_entries: Array[Dictionary] = []
var _open_echo_data: DiscoveryData


func _ready() -> void:
  process_mode = Node.PROCESS_MODE_ALWAYS
  discovery_manager = get_node_or_null(discovery_manager_path) as DiscoveryManager
  if discovery_manager == null:
    push_error("DiscoveryUI requires a DiscoveryManager.")
    return

  discovery_manager.discovery_registered.connect(_on_discovery_registered)
  discovery_manager.interaction_availability_changed.connect(
    _on_interaction_availability_changed
  )
  discovery_manager.echo_open_requested.connect(open_echo)
  discovery_manager.discoveries_reset.connect(_on_discoveries_reset)
  discovery_manager.journal_changed.connect(_rebuild_journal)
  _rebuild_journal()


func _process(_delta: float) -> void:
  if _echo_close_block_frames > 0:
    _echo_close_block_frames -= 1


func _unhandled_input(event: InputEvent) -> void:
  if not exploration_input_enabled:
    return
  if echo_overlay.visible:
    if _echo_close_block_frames <= 0 and (
      event.is_action_pressed(&"interact")
      or event.is_action_pressed(&"ui_cancel")
    ):
      close_echo()
      get_viewport().set_input_as_handled()
    return

  if journal_overlay.visible:
    if event.is_action_pressed(&"open_journal") or event.is_action_pressed(&"ui_cancel"):
      close_journal()
      get_viewport().set_input_as_handled()
    return

  if event.is_action_pressed(&"open_journal"):
    open_journal()
    get_viewport().set_input_as_handled()


func set_exploration_input_enabled(enabled: bool) -> void:
  exploration_input_enabled = enabled
  if not exploration_input_enabled:
    interaction_hint.visible = false
    if journal_overlay.visible:
      close_journal()
    if echo_overlay.visible:
      close_echo()
  else:
    _refresh_interaction_hint()


func open_journal() -> void:
  if not exploration_input_enabled or journal_overlay.visible or echo_overlay.visible:
    return
  _rebuild_journal()
  journal_overlay.visible = true
  interaction_hint.visible = false
  _pause_for_overlay()


func close_journal() -> void:
  if not journal_overlay.visible:
    return
  journal_overlay.visible = false
  _release_overlay_pause()
  _refresh_interaction_hint()


func open_echo(data: DiscoveryData) -> void:
  if not exploration_input_enabled or data == null or journal_overlay.visible:
    return
  echo_title.text = data.display_name
  _open_echo_data = data
  echo_text.text = data.recovered_text
  echo_text.visible_ratio = 0.0
  echo_overlay.visible = true
  interaction_hint.visible = false
  _echo_close_block_frames = 3
  _pause_for_overlay()

  if _echo_tween != null:
    _echo_tween.kill()
  var reveal_duration := clampf(float(data.recovered_text.length()) / 34.0, 3.5, 10.0)
  _echo_tween = create_tween()
  _echo_tween.tween_property(echo_text, "visible_ratio", 1.0, reveal_duration)


func close_echo() -> void:
  if not echo_overlay.visible:
    return
  if _echo_tween != null:
    _echo_tween.kill()
    _echo_tween = null
  echo_text.visible_ratio = 1.0
  echo_overlay.visible = false
  _release_overlay_pause()
  _refresh_interaction_hint()
  var closed_data := _open_echo_data
  _open_echo_data = null
  echo_closed.emit(closed_data)


func set_thread_entries(entries: Array[Dictionary]) -> void:
  thread_entries = entries.duplicate(true)
  _rebuild_journal()


func is_journal_open() -> bool:
  return journal_overlay.visible


func is_echo_open() -> bool:
  return echo_overlay.visible


func _on_discovery_registered(data: DiscoveryData) -> void:
  if data.category == DiscoveryData.Category.ECHO:
    return
  _banner_queue.append(data)
  if not banner.visible:
    _show_next_banner()


func _show_next_banner() -> void:
  if _banner_queue.is_empty():
    banner.visible = false
    return

  var data := _banner_queue.pop_front() as DiscoveryData
  banner_category.text = data.presentation_label()
  banner_name.text = data.display_name
  banner.visible = true
  banner.modulate.a = 0.0
  var hold_duration := 3.6 if data.category in [
    DiscoveryData.Category.LOST_PLACE,
    DiscoveryData.Category.ANOMALY,
  ] else 2.7

  if _banner_tween != null:
    _banner_tween.kill()
  _banner_tween = create_tween()
  _banner_tween.tween_property(banner, "modulate:a", 1.0, 0.25)
  _banner_tween.tween_interval(hold_duration)
  _banner_tween.tween_property(banner, "modulate:a", 0.0, 0.55)
  _banner_tween.tween_callback(_on_banner_finished)


func _on_banner_finished() -> void:
  banner.visible = false
  _banner_tween = null
  _show_next_banner()


func _on_interaction_availability_changed(
  data: DiscoveryData,
  available: bool
) -> void:
  _interaction_available = available
  _interaction_data = data if available else null
  _refresh_interaction_hint()


func _refresh_interaction_hint() -> void:
  interaction_hint.visible = (
    _interaction_available
    and _interaction_data != null
    and not journal_overlay.visible
    and not echo_overlay.visible
  )
  if interaction_hint.visible:
    interaction_label.text = "INTERACT  //  %s" % _interaction_data.display_name


func _rebuild_journal() -> void:
  if discovery_manager == null:
    return
  var sections: Array[String] = []
  for category in DiscoveryData.Category.values():
    var entries := discovery_manager.get_discovered_entries(category)
    if entries.is_empty():
      continue
    sections.append("[color=#75c9d1][font_size=22]%s[/font_size][/color]" % entries[0].category_title())
    for data in entries:
      var entry := "[font_size=19][b]%s[/b][/font_size]\n%s" % [
        data.display_name,
        data.short_description,
      ]
      if data.category == DiscoveryData.Category.ECHO and not data.recovered_text.is_empty():
        entry += "\n\n[color=#9bb7ba]%s[/color]" % data.recovered_text
      sections.append(entry)
  if not thread_entries.is_empty():
    sections.append("[color=#75c9d1][font_size=22]THREADS[/font_size][/color]")
    for thread in thread_entries:
      sections.append("[font_size=19][b]%s[/b][/font_size]\n%s" % [thread.get("title", "UNKNOWN THREAD"), thread.get("text", "")])

  if sections.is_empty():
    journal_text.text = "[color=#829092]No discoveries recorded.[/color]"
  else:
    journal_text.text = "\n\n".join(sections)


func _on_discoveries_reset() -> void:
  _banner_queue.clear()
  if _banner_tween != null:
    _banner_tween.kill()
    _banner_tween = null
  banner.visible = false
  _rebuild_journal()


func _pause_for_overlay() -> void:
  if _overlay_owns_pause:
    return
  _pause_state_before_overlay = get_tree().paused
  get_tree().paused = true
  _overlay_owns_pause = true


func _release_overlay_pause() -> void:
  if not _overlay_owns_pause:
    return
  get_tree().paused = _pause_state_before_overlay
  _overlay_owns_pause = false
