class_name FirstFlightUI
extends CanvasLayer

@onready var black_overlay: ColorRect = $Root/BlackOverlay
@onready var location_text: Label = $Root/OpeningText/Location
@onready var era_text: Label = $Root/OpeningText/Era
@onready var title_container: VBoxContainer = $Root/Title
@onready var debug_panel: PanelContainer = $Root/TimelineDebug
@onready var debug_state: Label = $Root/TimelineDebug/Margin/Content/State
@onready var debug_time: Label = $Root/TimelineDebug/Margin/Content/Time
@onready var debug_control: Label = $Root/TimelineDebug/Margin/Content/Control

var title_reveal_started: bool = false
var _title_tween: Tween


func _ready() -> void:
  process_mode = Node.PROCESS_MODE_ALWAYS


func reset_for_opening() -> void:
  if _title_tween != null:
    _title_tween.kill()
    _title_tween = null
  title_reveal_started = false
  black_overlay.visible = true
  black_overlay.modulate.a = 1.0
  location_text.modulate.a = 0.0
  era_text.modulate.a = 0.0
  title_container.visible = false
  title_container.modulate.a = 0.0


func hide_all() -> void:
  black_overlay.visible = false
  location_text.modulate.a = 0.0
  era_text.modulate.a = 0.0
  title_container.visible = false


func set_black_alpha(alpha: float) -> void:
  black_overlay.modulate.a = clampf(alpha, 0.0, 1.0)
  black_overlay.visible = black_overlay.modulate.a > 0.001


func set_opening_text_alpha(location_alpha: float, era_alpha: float) -> void:
  location_text.modulate.a = clampf(location_alpha, 0.0, 1.0)
  era_text.modulate.a = clampf(era_alpha, 0.0, 1.0)


func play_title(hold_duration: float) -> void:
  if title_reveal_started:
    return
  title_reveal_started = true
  title_container.visible = true
  title_container.modulate.a = 0.0
  _title_tween = create_tween()
  _title_tween.tween_property(title_container, "modulate:a", 1.0, 0.8)
  _title_tween.tween_interval(maxf(hold_duration, 0.0))
  _title_tween.tween_property(title_container, "modulate:a", 0.0, 1.4)
  _title_tween.tween_callback(func() -> void:
    title_container.visible = false
    _title_tween = null
  )


func update_timeline_debug(
  enabled: bool,
  state_name: String,
  sequence_time: float,
  player_has_control: bool
) -> void:
  debug_panel.visible = enabled
  if not enabled:
    return
  debug_state.text = "OPENING STATE: %s" % state_name
  debug_time.text = "SEQUENCE TIME: %.2f" % sequence_time
  debug_control.text = "PLAYER CONTROL: %s" % ("YES" if player_has_control else "NO")
