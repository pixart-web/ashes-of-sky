class_name CombatHUD
extends CanvasLayer

var root_panel: PanelContainer
var status_label: Label
var player_bar: ProgressBar
var warden_bar: ProgressBar
var left_guard_bar: ProgressBar
var right_guard_bar: ProgressBar
var focus_bar: ProgressBar
var evade_label: Label
var lock_label: Label


func _ready() -> void:
  layer = 7
  _build()
  visible = false


func update_combat(player_health: float, warden: AshWarden, focus: float, evade_charges: int, locked: bool, sector: StringName, distance: float) -> void:
  player_bar.value = player_health
  warden_bar.value = warden.get_total_health()
  left_guard_bar.value = warden.left_guard_health
  right_guard_bar.value = warden.right_guard_health
  focus_bar.value = focus * 100.0
  evade_label.text = "EVADE  %s" % "◆".repeat(evade_charges)
  lock_label.text = "◇ TARGET LOCK" if locked else "TARGET UNLOCKED"
  status_label.text = "%s  //  %.0f m" % [sector, distance]


func _build() -> void:
  root_panel = PanelContainer.new()
  root_panel.name = "CombatPanel"
  root_panel.position = Vector2(22, 430)
  root_panel.size = Vector2(330, 260)
  add_child(root_panel)
  var margin := MarginContainer.new()
  margin.add_theme_constant_override("margin_left", 14)
  margin.add_theme_constant_override("margin_right", 14)
  margin.add_theme_constant_override("margin_top", 10)
  margin.add_theme_constant_override("margin_bottom", 10)
  root_panel.add_child(margin)
  var content := VBoxContainer.new()
  margin.add_child(content)
  var title := Label.new()
  title.text = "ASH WARDEN"
  title.add_theme_font_size_override("font_size", 20)
  content.add_child(title)
  status_label = Label.new()
  content.add_child(status_label)
  player_bar = _bar(content, "LUNARIS HP", 100.0)
  warden_bar = _bar(content, "WARDEN HP", 100.0)
  left_guard_bar = _bar(content, "LEFT GUARD", 25.0)
  right_guard_bar = _bar(content, "RIGHT GUARD", 25.0)
  focus_bar = _bar(content, "FOCUS", 100.0)
  evade_label = Label.new()
  content.add_child(evade_label)
  lock_label = Label.new()
  content.add_child(lock_label)


func _bar(parent: VBoxContainer, label_text: String, maximum: float) -> ProgressBar:
  var label := Label.new()
  label.text = label_text
  parent.add_child(label)
  var bar := ProgressBar.new()
  bar.max_value = maximum
  bar.value = maximum
  bar.show_percentage = false
  bar.custom_minimum_size = Vector2(280, 10)
  parent.add_child(bar)
  return bar
