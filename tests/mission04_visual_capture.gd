extends Node
## Capturas PRE/POST comparables a 1920x1080 mediante RenderingServer.frame_post_draw.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const OUTPUT_ROOT := "res://tests/artifacts/mission04"
var main: Node3D
var player: SurvivorPlayer
var hud: CanvasLayer
var capture_set := "after"

func _ready() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--set="):
            capture_set = argument.trim_prefix("--set=")
    if DisplayServer.get_name() == "headless":
        printerr("BLOCKED: captura requiere renderer visible")
        get_tree().quit(2)
        return
    get_window().size = Vector2i(1920, 1080)
    GameClock.paused = true
    main = MAIN_SCENE.instantiate() as Node3D
    add_child(main)
    player = main.get_node("Player") as SurvivorPlayer
    hud = main.get_node("HUD") as CanvasLayer
    await get_tree().process_frame
    call_deferred("_capture_all")

func _set_camera(at: Vector3, yaw: float) -> void:
    player.global_position = at
    player.first_person = false
    player.spring_arm.spring_length = SurvivorPlayer.CAMERA_LENGTH
    player.pivot.rotation = Vector3(0.05, yaw, 0.0)
    player.visuals.visible = true

func _set_time(phase: float) -> void:
    GameClock.phase = phase
    GameClock.time_changed.emit(phase, GameClock.format_time(), GameClock.is_night())
    hud.toast_label.text = ""

func _capture_all() -> void:
    var folder := "%s/%s" % [OUTPUT_ROOT, capture_set]
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    _set_time(0.42)
    _set_camera(Vector3(0.0, 0.05, 4.5), 0.0)
    await _capture(folder, "patio_day.png")
    _set_time(0.42)
    _set_camera(Vector3(0.0, 0.05, 1.0), PI)
    await _capture(folder, "shelter_overview.png")
    _set_time(0.42)
    _set_camera(Vector3(0.0, 0.05, 4.5), 0.0)
    player.inventory.add_item("cloth", 4)
    player.inventory.add_item("herb", 2)
    player.inventory.add_item("battery", 1)
    hud._toggle_inventory(true)
    await _capture(folder, "inventory.png")
    hud._toggle_inventory(false)
    _set_time(0.0)
    _set_camera(Vector3(0.0, 0.05, 4.5), 0.0)
    await _capture(folder, "night.png")
    print("CAPTURE_SET_COMPLETE: %s (%s)" % [capture_set, folder])
    main.queue_free()
    await get_tree().process_frame
    await get_tree().process_frame
    get_tree().quit(0)

func _capture(folder: String, filename: String) -> void:
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    var image := get_viewport().get_texture().get_image()
    if image.get_width() != 1920 or image.get_height() != 1080:
        image.resize(1920, 1080, Image.INTERPOLATE_BILINEAR)
    var path := folder.path_join(filename)
    var error := image.save_png(path)
    if error != OK:
        printerr("CAPTURE_FAILED: %s (%s)" % [path, error])
    else:
        print("CAPTURE: %s (%dx%d)" % [path, image.get_width(), image.get_height()])
