extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
  _run.call_deferred()


func _run() -> void:
  var visual_scene := load("res://art/lunaris/lunaris_visual.tscn") as PackedScene
  _assert(visual_scene != null, "The reusable Lunaris visual scene loads.")
  if visual_scene == null:
    _finish()
    return
  var visual := visual_scene.instantiate() as LunarisVisual
  root.add_child(visual)
  await process_frame

  _assert(visual.get_meta("visual_prototype") == "LUNARIS_CHARACTER_ART_TARGET_001", "The approved character art target identifies the prototype.")
  _assert(visual.get_meta("collision_decoupled"), "Visual anatomy remains decoupled from gameplay collision.")
  for required_node in ["Body", "Neck", "WingLeft", "WingRight", "Tail", "Legs", "ArchitectInterface", "RiderMount"]:
    _assert(visual.has_node(required_node), "%s exists in the modular hierarchy." % required_node)

  _assert(visual.get_body_length_without_filaments() >= 5.5 and visual.get_body_length_without_filaments() <= 6.5, "Conceptual body length remains within target range.")
  _assert(visual.get_wingspan() >= 10.0 and visual.get_wingspan() <= 13.0, "Conceptual wingspan remains within target range.")
  _assert(visual.has_node("Body/ChestTransition") and visual.has_node("Body/AbdomenTaper"), "The torso uses overlapping transitions instead of a central spherical mass.")
  _assert(visual.has_node("Body/ShoulderMuscleLeft") and visual.has_node("Body/ShoulderMuscleRight"), "Organic shoulder masses bridge the torso into both wing roots.")
  _assert(visual.has_node("Neck/Segment01") and visual.has_node("Neck/Segment04"), "The neck uses four overlapping animation-ready segments.")
  _assert(visual.has_node("Neck/Head/PredatoryCranium"), "The head has a dedicated narrow cranium.")
  _assert(visual.has_node("Neck/Head/ElongatedSnout"), "The head has an elongated predatory snout.")
  _assert(visual.has_node("Neck/Head/CrestLeft") and visual.has_node("Neck/Head/CrestRight"), "Cranial structures sweep backward without giant horns.")
  _assert(visual.has_node("Neck/Head/EyeLeft") and visual.has_node("Neck/Head/EyeRight"), "Small cyan eyes provide restrained energy accents.")

  for side in ["WingLeft", "WingRight"]:
    var wing := visual.get_node(side)
    for section_name in ["WingRoot", "WingRoot/UpperWing", "WingRoot/UpperWing/ForeWing", "WingRoot/UpperWing/ForeWing/OuterWing"]:
      _assert(wing.has_node(section_name), "%s contains articulated %s." % [side, section_name.get_file()])
    var membranes := wing.find_children("Membrane", "MeshInstance3D", true, false)
    _assert(membranes.size() == 3, "%s contains three major lightweight membrane regions." % side)

  _assert(visual.has_node("Tail/Segment01/Segment02/Segment03/Segment04/Stabilizers"), "The tail is long, hierarchical, and ends in stabilizers.")
  var stabilizers := visual.get_node("Tail/Segment01/Segment02/Segment03/Segment04/Stabilizers")
  _assert(stabilizers.has_node("CentralFilament") and stabilizers.has_node("LeftFilament") and stabilizers.has_node("RightFilament"), "Three tail filaments create the steering silhouette.")
  _assert(visual.has_node("RiderMount/KaelPlaceholder"), "Kael remains a separate mounted placeholder.")
  _assert(visual.has_node("ArchitectInterface/InterruptedEnergyChannel"), "The rider interface integrates an interrupted Divided Halo channel.")

  var material_names: Array[String] = []
  for material in visual.get_material_library():
    material_names.append(material.resource_name)
  for expected_name in ["M_Lunaris_OrganicBody", "M_Lunaris_BonePlate", "M_Lunaris_ArchitectMetal", "M_Lunaris_Energy", "M_Lunaris_WingMembrane", "M_Kael_Placeholder"]:
    _assert(expected_name in material_names, "%s exists in the shared prototype library." % expected_name)
  var energy_material := visual.get_material_library()[3]
  _assert(energy_material.emission_energy_multiplier <= 1.2, "Cyan energy remains restrained rather than Tron-like.")

  visual.set_silhouette_enabled(true)
  _assert(visual.silhouette_enabled, "The monochrome silhouette review mode can be enabled.")
  var silhouette_complete := true
  for mesh in visual.find_children("*", "MeshInstance3D", true, false):
    silhouette_complete = silhouette_complete and mesh.material_override != null
  _assert(silhouette_complete, "Silhouette review applies one dark override material to every mesh.")
  visual.set_silhouette_enabled(false)

  visual.set_wing_pose(LunarisVisual.WingPose.GLIDE)
  var glide_left := visual.wing_left.rotation
  var glide_fore: Vector3 = (visual.get_node("WingLeft/WingRoot/UpperWing/ForeWing") as Node3D).rotation
  visual.set_wing_pose(LunarisVisual.WingPose.FOLDED)
  _assert(visual.wing_left.rotation.distance_to(glide_left) > 0.7, "FOLDED substantially changes the root silhouette.")
  _assert(visual.get_node("WingLeft/WingRoot/UpperWing/ForeWing").rotation.distance_to(glide_fore) > 0.2, "FOLDED articulates internal wing sections.")
  var folded_rotation := visual.wing_left.rotation
  visual.set_wing_pose(LunarisVisual.WingPose.FULL_SPREAD)
  _assert(visual.wing_left.rotation.distance_to(folded_rotation) > 0.9, "FULL_SPREAD is distinct from FOLDED.")
  visual.set_wing_pose(LunarisVisual.WingPose.GLIDE)

  var visuals := visual.find_children("*", "VisualInstance3D", true, false)
  print("AOTS-009 LUNARIS_BUDGET visual_nodes=%d materials=%d" % [visuals.size(), visual.get_material_library().size()])
  _assert(visuals.size() < 90, "The procedural creature remains within a lightweight visual-node budget.")
  visual.queue_free()
  await process_frame

  var lab_scene := load("res://art/lunaris/lunaris_visual_lab.tscn") as PackedScene
  _assert(lab_scene != null, "The development-only Lunaris Visual Lab exists.")
  var lab := lab_scene.instantiate()
  root.add_child(lab)
  await process_frame
  lab.call(&"set_view", &"SIDE")
  lab.call(&"set_pose", LunarisVisual.WingPose.FOLDED)
  _assert((lab.get_node("ModelPivot/LunarisVisual") as LunarisVisual).current_pose == LunarisVisual.WingPose.FOLDED, "Visual Lab switches to FOLDED.")
  lab.call(&"set_pose", LunarisVisual.WingPose.GLIDE)
  _assert((lab.get_node("ModelPivot/LunarisVisual") as LunarisVisual).current_pose == LunarisVisual.WingPose.GLIDE, "Visual Lab switches to GLIDE.")
  lab.call(&"set_pose", LunarisVisual.WingPose.FULL_SPREAD)
  _assert((lab.get_node("ModelPivot/LunarisVisual") as LunarisVisual).current_pose == LunarisVisual.WingPose.FULL_SPREAD, "Visual Lab switches to FULL_SPREAD.")
  lab.call(&"set_silhouette_enabled", true)
  _assert((lab.get_node("ModelPivot/LunarisVisual") as LunarisVisual).silhouette_enabled, "Visual Lab exposes silhouette review mode.")
  lab.queue_free()
  await process_frame

  var flight_scene := load("res://world/test/flight_test.tscn") as PackedScene
  var flight_test := flight_scene.instantiate()
  var opening := flight_test.get_node("FirstFlightSequence") as FirstFlightSequence
  opening.play_opening_on_start = false
  root.add_child(flight_test)
  await process_frame
  await physics_frame
  var lunaris := flight_test.get_node("Lunaris") as LunarisFlightController
  var gameplay_visual := lunaris.get_node("VisualPivot/LunarisVisual") as LunarisVisual
  _assert(gameplay_visual != null, "Gameplay uses the reusable LunarisVisual scene.")
  _assert(not lunaris.has_node("VisualPivot/Body") and not lunaris.has_node("VisualPivot/LeftWing"), "The old primitive placeholder nodes are removed.")
  var collision := lunaris.get_node("CollisionShape3D") as CollisionShape3D
  _assert(collision.shape is BoxShape3D and (collision.shape as BoxShape3D).size.is_equal_approx(Vector3(5.8, 1.0, 3.6)), "The forgiving gameplay collision is unchanged.")
  var presentation := lunaris.get_node("Presentation") as LunarisFlightPresentation
  _assert(presentation.lunaris_visual == gameplay_visual, "Existing flight presentation drives the new visual reactions.")
  _assert(opening.lunaris_visual == gameplay_visual, "First Flight drives the new articulated wing deployment.")
  _finish()


func _assert(condition: bool, message: String) -> void:
  if condition:
    print("PASS: %s" % message)
  else:
    _failures.append(message)
    push_error("FAIL: %s" % message)


func _finish() -> void:
  if _failures.is_empty():
    print("AOTS-009 Lunaris visual prototype smoke test passed.")
    quit(0)
  else:
    print("AOTS-009 Lunaris visual prototype smoke test failed: %d failure(s)." % _failures.size())
    quit(1)
