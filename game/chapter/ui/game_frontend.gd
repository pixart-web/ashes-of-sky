class_name GameFrontend
extends CanvasLayer

signal new_journey_requested
signal continue_requested
signal return_to_title_requested

@export_node_path("GameSaveSystem") var save_system_path: NodePath
@export var show_menu_on_start: bool = true

var save_system: GameSaveSystem
var title_screen: Control
var pause_screen: Control
var settings_screen: Control
var continue_button: Button
var overwrite_confirmation: ConfirmationDialog
var settings: Dictionary = {
  "master_volume": 1.0, "music_volume": 0.8, "effects_volume": 0.9,
  "mouse_sensitivity": 1.0, "invert_y": false, "camera_shake": 0.7,
  "subtitles": true, "fullscreen": false,
}


func _ready() -> void:
  layer = 30
  process_mode = Node.PROCESS_MODE_ALWAYS
  save_system = get_node_or_null(save_system_path) as GameSaveSystem
  _build_title()
  _build_pause()
  _build_settings()
  if show_menu_on_start and DisplayServer.get_name() != "headless":
    show_title()
  else:
    hide_all()


func _unhandled_input(event: InputEvent) -> void:
  if event.is_action_pressed(&"pause") and not title_screen.visible and not settings_screen.visible:
    if pause_screen.visible:
      resume_game()
    else:
      show_pause()
    get_viewport().set_input_as_handled()


func show_title() -> void:
  hide_all()
  title_screen.visible = true
  continue_button.disabled = save_system == null or not save_system.has_save()
  get_tree().paused = true


func show_pause() -> void:
  hide_all()
  pause_screen.visible = true
  get_tree().paused = true


func show_settings() -> void:
  title_screen.visible = false
  pause_screen.visible = false
  settings_screen.visible = true
  get_tree().paused = true


func resume_game() -> void:
  hide_all()
  get_tree().paused = false


func hide_all() -> void:
  title_screen.visible = false if title_screen != null else false
  pause_screen.visible = false if pause_screen != null else false
  settings_screen.visible = false if settings_screen != null else false


func apply_setting(setting_id: StringName, value: Variant) -> void:
  if not settings.has(setting_id):
    return
  settings[setting_id] = value
  match setting_id:
    &"master_volume": AudioServer.set_bus_volume_db(0, linear_to_db(float(value)))
    &"fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(value) else DisplayServer.WINDOW_MODE_WINDOWED)


func create_settings_snapshot() -> Dictionary:
  return settings.duplicate(true)


func restore_settings_snapshot(snapshot: Dictionary) -> void:
  for key in settings:
    if snapshot.has(key):
      apply_setting(key, snapshot[key])


func _request_new_journey() -> void:
  if save_system != null and save_system.has_save():
    overwrite_confirmation.popup_centered()
    return
  _confirm_new_journey()


func _confirm_new_journey() -> void:
  resume_game()
  new_journey_requested.emit()


func _request_continue() -> void:
  resume_game()
  continue_requested.emit()


func _return_to_title() -> void:
  return_to_title_requested.emit()
  show_title()


func _build_title() -> void:
  title_screen = _base_screen("TitleScreen")
  var column := _center_column(title_screen, Vector2(370, 145), Vector2(540, 430))
  var title := Label.new()
  title.text = "ASHES OF THE SKY"
  title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  title.add_theme_font_size_override("font_size", 38)
  title.add_theme_color_override("font_color", Color(0.72, 0.9, 0.91))
  column.add_child(title)
  var subtitle := Label.new()
  subtitle.text = "ELYNDRA  •  AFTER THE SILENCE"
  subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  subtitle.add_theme_font_size_override("font_size", 14)
  column.add_child(subtitle)
  continue_button = _button("CONTINUE", _request_continue)
  column.add_child(continue_button)
  column.add_child(_button("NEW JOURNEY", _request_new_journey))
  column.add_child(_button("SETTINGS", show_settings))
  column.add_child(_button("QUIT", func(): get_tree().quit()))
  overwrite_confirmation = ConfirmationDialog.new()
  overwrite_confirmation.dialog_text = "Begin a new journey and overwrite current progress?"
  overwrite_confirmation.confirmed.connect(_confirm_new_journey)
  title_screen.add_child(overwrite_confirmation)


func _build_pause() -> void:
  pause_screen = _base_screen("PauseScreen")
  var column := _center_column(pause_screen, Vector2(440, 160), Vector2(400, 390))
  var title := Label.new()
  title.text = "PAUSED"
  title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  title.add_theme_font_size_override("font_size", 30)
  column.add_child(title)
  column.add_child(_button("RESUME", resume_game))
  column.add_child(_button("JOURNAL", func(): resume_game(); Input.action_press(&"open_journal"); Input.action_release(&"open_journal")))
  column.add_child(_button("SETTINGS", show_settings))
  column.add_child(_button("RETURN TO TITLE", _return_to_title))


func _build_settings() -> void:
  settings_screen = _base_screen("SettingsScreen")
  var column := _center_column(settings_screen, Vector2(340, 72), Vector2(600, 575))
  var title := Label.new()
  title.text = "SETTINGS"
  title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  title.add_theme_font_size_override("font_size", 28)
  column.add_child(title)
  for data in [["MASTER VOLUME", &"master_volume"], ["MUSIC VOLUME", &"music_volume"], ["EFFECTS VOLUME", &"effects_volume"], ["MOUSE SENSITIVITY", &"mouse_sensitivity"], ["CAMERA SHAKE", &"camera_shake"]]:
    var row := HBoxContainer.new()
    var label := Label.new()
    label.text = data[0]
    label.custom_minimum_size.x = 230
    row.add_child(label)
    var slider := HSlider.new()
    slider.min_value = 0.0
    slider.max_value = 1.5 if data[1] == &"mouse_sensitivity" else 1.0
    slider.step = 0.05
    slider.value = float(settings[data[1]])
    slider.custom_minimum_size.x = 280
    slider.value_changed.connect(func(value): apply_setting(data[1], value))
    row.add_child(slider)
    column.add_child(row)
  for data in [["INVERT Y", &"invert_y"], ["SUBTITLES", &"subtitles"], ["FULLSCREEN", &"fullscreen"]]:
    var toggle := CheckButton.new()
    toggle.text = data[0]
    toggle.button_pressed = bool(settings[data[1]])
    toggle.toggled.connect(func(value): apply_setting(data[1], value))
    column.add_child(toggle)
  column.add_child(_button("BACK", show_pause))


func _base_screen(node_name: String) -> Control:
  var screen := Control.new()
  screen.name = node_name
  screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  var shade := ColorRect.new()
  shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  shade.color = Color(0.012, 0.017, 0.02, 0.94)
  screen.add_child(shade)
  add_child(screen)
  return screen


func _center_column(parent: Control, position: Vector2, size: Vector2) -> VBoxContainer:
  var column := VBoxContainer.new()
  column.position = position
  column.size = size
  column.add_theme_constant_override("separation", 18)
  parent.add_child(column)
  return column


func _button(text_value: String, callback: Callable) -> Button:
  var button := Button.new()
  button.text = text_value
  button.custom_minimum_size.y = 48
  button.add_theme_font_size_override("font_size", 18)
  button.pressed.connect(callback)
  return button
