extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
  _run.call_deferred()


func _run() -> void:
  var packed_scene := load("res://world/test/flight_test.tscn") as PackedScene
  _assert(packed_scene != null, "The Sacred Ash art-target scene loads.")
  if packed_scene == null:
    _finish()
    return
  var flight_test := packed_scene.instantiate()
  var opening := flight_test.get_node("FirstFlightSequence") as FirstFlightSequence
  opening.play_opening_on_start = false
  root.add_child(flight_test)
  await process_frame
  await physics_frame

  var art_target := flight_test.get_node("SacredAshArtTarget") as SacredAshArtTarget
  _assert(art_target != null, "A dedicated Sacred Ash art-target module exists.")
  if art_target == null:
    _finish()
    return

  _assert(art_target.has_node("StartingCliffArtPass/PartialCeremonialArch"), "Starting Cliff has one large partial ceremonial arch.")
  _assert(art_target.has_node("StartingCliffArtPass/AsymmetricBladeWest"), "Starting Cliff has an asymmetric west blade.")
  _assert(art_target.has_node("StartingCliffArtPass/AsymmetricBladeEast"), "Starting Cliff has an asymmetric east blade.")
  var halo := art_target.get_node("StartingCliffArtPass/DividedHalo001")
  _assert(halo.get_meta("architect_motif") == "THE DIVIDED HALO", "The Divided Halo remains the primary Architect motif.")
  _assert(halo.has_node("HaloSegments") and halo.has_node("DividingBlade"), "The Divided Halo combines a broken ring and dividing blade.")

  var expected_modules := [
    "ARCH_01_MONUMENTAL_ARCH", "ARCH_02_VERTICAL_BLADE", "ARCH_03_BROKEN_WALL",
    "ARCH_04_DIVIDED_HALO", "ARCH_05_ARCHITECT_PILLAR", "ARCH_06_COLLAPSED_MONUMENT",
    "ARCH_07_GATE_MODULE", "ARCH_08_SPIRE_MODULE",
  ]
  var module_ids := art_target.get_architect_module_ids()
  for module_id in expected_modules:
    _assert(module_id in module_ids, "%s exists in the reusable Architect kit." % module_id)

  var midground := art_target.get_node("ValleyMidgroundArtPass")
  _assert(midground.get_meta("uses_negative_space"), "The Valley composition explicitly preserves negative space.")
  _assert(float(midground.get_meta("visual_corridor_half_width")) >= 100.0, "A deliberate sightline corridor protects the Spire.")
  _assert(midground.has_node("OpenCanyonGate"), "The Central Canyon includes a large fly-through gate.")
  _assert(midground.has_node("BreachedWallEast"), "The Central Canyon uses a breached irregular wall instead of a slab.")

  var canyon := flight_test.get_node("ValleyOfAsh/CentralCanyon")
  _assert(float(canyon.get_meta("minimum_visual_corridor_width")) >= 250.0, "The Central Canyon base preserves a wide open flight corridor.")
  _assert(canyon.find_children("*Wall*", "Node", true, false).is_empty(), "The Central Canyon no longer contains giant wall modules.")
  _assert(canyon.has_node("WestButtress00") and canyon.has_node("EastButtress00"), "Isolated rock buttresses replace corridor walls.")

  var spire_module := art_target.get_node("SpireSacredAshArtPass/ArchitectSpireModule")
  _assert(spire_module.has_node("DominantVerticalCore"), "The Spire has one dominant vertical core.")
  _assert(spire_module.has_node("IconicBrokenHalo"), "The Spire has one iconic broken halo.")
  _assert(spire_module.has_node("SmallCyanCore"), "The Spire cyan core remains very small.")
  _assert(not spire_module.has_node("FragmentedCrownRing"), "The Spire no longer relies on a second noisy ring.")

  var materials := art_target.get_material_library()
  _assert(materials.size() == 6, "The prototype material library remains intentionally small.")
  var dark_stone := materials[0]
  var aged_metal := materials[1]
  var cyan_active := materials[2]
  _assert(dark_stone.albedo_color.get_luminance() < 0.18 and dark_stone.albedo_color.get_luminance() > 0.02, "Architect stone is charcoal rather than opaque black.")
  _assert(dark_stone.roughness > 0.7, "Architect stone remains ancient and rough.")
  _assert(aged_metal.metallic > 0.4 and aged_metal.roughness > 0.6, "Aged metal remains weathered.")
  _assert(cyan_active.emission_enabled and cyan_active.emission_energy_multiplier <= 1.0, "Normal cyan emission remains restrained.")

  var environment := art_target.world_environment.environment
  _assert(environment.fog_enabled and environment.fog_density < 0.003, "Atmospheric haze preserves landmark readability.")
  _assert(art_target.sun.shadow_enabled, "The directional light retains architectural shadows.")
  _assert(art_target.art_target_camera.fov >= 58.0, "The hero camera preserves open sky and lateral escape routes.")

  _assert(art_target.ash_particles.amount <= 32, "Ash remains sparse and lightweight.")
  var particle_process := art_target.ash_particles.process_material as ParticleProcessMaterial
  var particle_mesh := art_target.ash_particles.draw_pass_1 as QuadMesh
  _assert(absf(particle_process.direction.x) > absf(particle_process.direction.y) * 4.0, "Ash drifts horizontally rather than falling like rain.")
  _assert(is_equal_approx(particle_mesh.size.x, particle_mesh.size.y), "Ash uses small square flecks rather than elongated streaks.")

  _assert(InputMap.has_action(&"toggle_screenshot_mode"), "Clean screenshot mode has a development action.")
  var canvas_layers := flight_test.find_children("*", "CanvasLayer", true, false)
  art_target.set_screenshot_mode_enabled(true)
  var all_ui_hidden := true
  for layer in canvas_layers:
    all_ui_hidden = all_ui_hidden and not (layer as CanvasLayer).visible
  _assert(all_ui_hidden and not art_target.speed_particles.visible, "Screenshot mode hides every CanvasLayer and capture streak source.")
  art_target.set_screenshot_mode_enabled(false)
  _assert((flight_test.get_node("DebugHUD") as CanvasLayer).visible, "Screenshot mode restores the normal HUD state.")

  art_target.set_art_target_camera_enabled(true)
  _assert(art_target.art_target_camera.current, "The art-target camera activates deterministically.")
  art_target.set_art_target_camera_enabled(false)
  _assert(art_target.gameplay_camera.current, "Gameplay camera is restored deterministically.")
  art_target.set_particles_enabled(false)
  _assert(not art_target.ash_particles.emitting, "Particles can be removed entirely for comparison.")
  art_target.set_particles_enabled(true)
  art_target.set_cyan_visualization_enabled(true)
  _assert(is_equal_approx(art_target.cyan_active_material.emission_energy_multiplier, 2.4), "Cyan debug visualization remains explicit.")
  art_target.set_cyan_visualization_enabled(false)

  _assert(art_target.find_children("*", "CollisionObject3D", true, false).is_empty(), "The Architect visual kit introduces no gameplay collision.")
  var visual_nodes := art_target.find_children("*", "VisualInstance3D", true, false)
  print("AOTS-008.2 ART_BUDGET visual_nodes=%d modules=%d" % [visual_nodes.size(), module_ids.size()])
  _assert(visual_nodes.size() < 170, "The modular art pass stays within its lightweight visual-node budget.")
  _assert(flight_test.has_node("FirstFlightSequence") and opening.player_has_control, "AOTS-007 and direct flight start remain integrated.")
  _finish()


func _assert(condition: bool, message: String) -> void:
  if condition:
    print("PASS: %s" % message)
  else:
    _failures.append(message)
    push_error("FAIL: %s" % message)


func _finish() -> void:
  if _failures.is_empty():
    print("AOTS-008.2 Sacred Ash form and composition smoke test passed.")
    quit(0)
  else:
    print("AOTS-008.2 smoke test failed: %d failure(s)." % _failures.size())
    quit(1)
