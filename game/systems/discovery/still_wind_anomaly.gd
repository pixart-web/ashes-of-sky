class_name StillWindAnomaly
extends DiscoveryPoint


func _on_body_entered(body: Node3D) -> void:
  super(body)
  if body is LunarisFlightController:
    var presentation := body.get_node_or_null("Presentation") as LunarisFlightPresentation
    if presentation != null:
      presentation.set_environmental_calm(true)


func _on_body_exited(body: Node3D) -> void:
  super(body)
  if body is LunarisFlightController:
    var presentation := body.get_node_or_null("Presentation") as LunarisFlightPresentation
    if presentation != null:
      presentation.set_environmental_calm(false)
