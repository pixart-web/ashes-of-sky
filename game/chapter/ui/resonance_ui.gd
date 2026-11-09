class_name ResonanceUI
extends CanvasLayer

signal tendency_chosen(tendency: LunarisEvolution.Tendency)

var panel: PanelContainer
var title: Label
var description: Label
var buttons: Array[Button] = []


func _ready() -> void:
  layer = 24
  process_mode = Node.PROCESS_MODE_ALWAYS
  _build_ui()
  visible = false


func open_choice() -> void:
  visible = true
  get_tree().paused = true
  if not buttons.is_empty():
    buttons[0].grab_focus()


func close_choice() -> void:
  visible = false
  get_tree().paused = false


func _choose(tendency: LunarisEvolution.Tendency) -> void:
  tendency_chosen.emit(tendency)
  close_choice()


func _build_ui() -> void:
  var shade := ColorRect.new()
  shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  shade.color = Color(0.015, 0.02, 0.025, 0.88)
  add_child(shade)
  panel = PanelContainer.new()
  panel.position = Vector2(230, 115)
  panel.size = Vector2(820, 490)
  var style := StyleBoxFlat.new()
  style.bg_color = Color(0.045, 0.055, 0.06, 0.98)
  style.border_color = Color(0.22, 0.46, 0.49, 0.8)
  style.set_border_width_all(1)
  style.set_corner_radius_all(3)
  panel.add_theme_stylebox_override("panel", style)
  add_child(panel)
  var margin := MarginContainer.new()
  margin.add_theme_constant_override("margin_left", 42)
  margin.add_theme_constant_override("margin_right", 42)
  margin.add_theme_constant_override("margin_top", 32)
  margin.add_theme_constant_override("margin_bottom", 32)
  panel.add_child(margin)
  var column := VBoxContainer.new()
  column.add_theme_constant_override("separation", 14)
  margin.add_child(column)
  title = Label.new()
  title.text = "FIRST RESONANCE"
  title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  title.add_theme_font_size_override("font_size", 30)
  title.add_theme_color_override("font_color", Color(0.72, 0.9, 0.91))
  column.add_child(title)
  description = Label.new()
  description.text = "Lunaris answers the awakened world. Choose the tendency that surfaces first.\nThis is a beginning, not a permanent class."
  description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  description.add_theme_font_size_override("font_size", 17)
  column.add_child(description)
  var choices := [
    ["PREDATOR", "Momentum sharpens each Pulse.", LunarisEvolution.Tendency.PREDATOR],
    ["GUARDIAN", "Resonance steadies Lunaris under pressure.", LunarisEvolution.Tendency.GUARDIAN],
    ["ORACLE", "Focus reveals structure within chaos.", LunarisEvolution.Tendency.ORACLE],
    ["WRAITH", "Movement slips through dangerous space.", LunarisEvolution.Tendency.WRAITH],
  ]
  for choice in choices:
    var button := Button.new()
    button.text = "%s  —  %s" % [choice[0], choice[1]]
    button.custom_minimum_size = Vector2(0, 54)
    button.add_theme_font_size_override("font_size", 17)
    button.pressed.connect(_choose.bind(choice[2]))
    column.add_child(button)
    buttons.append(button)
