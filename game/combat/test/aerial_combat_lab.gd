extends Node3D


func _ready() -> void:
  var packed := load("res://world/test/flight_test.tscn") as PackedScene
  var game := packed.instantiate()
  game.name = "CombatGame"
  (game.get_node("FirstFlightSequence") as FirstFlightSequence).play_opening_on_start = false
  add_child(game)
  (game.get_node("PrologueDirector") as PrologueDirector).start_at_warden_debug.call_deferred()
