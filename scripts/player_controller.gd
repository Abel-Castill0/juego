class_name SurvivorPlayer
extends CharacterBody3D
## Controlador 3D cinemático. Física en _physics_process y cámara única sobre SpringArm3D.

signal battery_changed(current: float)
signal health_changed(current: float)
signal pickup_succeeded(item_id: String, quantity: int)
signal action_feedback(message: String, is_error: bool)
signal camera_transition_measured(elapsed_ms: float)

const WALK_SPEED: float = 4.1
const SPRINT_SPEED: float = 6.9
const CROUCH_SPEED: float = 2.1
const ACCELERATION: float = 17.0
const AIR_ACCELERATION: float = 4.0
const JUMP_VELOCITY: float = 6.0
const GRAVITY: float = 21.0
const MOUSE_SENSITIVITY: float = 0.0021
const CAMERA_LENGTH: float = 3.2
const CAMERA_CHANGE_SPEED: float = 17.0  # 3.2m / 17m/s = 0.188s.
const FLASHLIGHT_DRAIN_PER_SECOND: float = 0.30
const CHARACTER_SCENE: PackedScene = preload("res://assets/third_party/kenney/character/Model/characterMedium.fbx")
const IDLE_SCENE: PackedScene = preload("res://assets/third_party/kenney/character/Animations/idle.fbx")
const RUN_SCENE: PackedScene = preload("res://assets/third_party/kenney/character/Animations/run.fbx")
const JUMP_SCENE: PackedScene = preload("res://assets/third_party/kenney/character/Animations/jump.fbx")
const AXE_SCENE: PackedScene = preload("res://assets/third_party/kenney/survival/tool-axe.glb")

@onready var inventory: InventoryComponent = $Inventory
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visual
@onready var pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var ray: RayCast3D = $CameraPivot/SpringArm3D/Camera3D/InteractRay
@onready var flashlight: SpotLight3D = $CameraPivot/SpringArm3D/Camera3D/Flashlight
@onready var torch_light: OmniLight3D = $TorchLight

var ui_open: bool = false
var first_person: bool = false
var crouching: bool = false
var flashlight_enabled: bool = false
var torch_equipped: bool = false
var spear_equipped: bool = false
var battery: float = 100.0
var health: float = 78.0
var _camera_transition_started_usec: int = -1
var _camera_transition_target: float = CAMERA_LENGTH
var character_visual: Node3D
var character_skeleton: Skeleton3D
var _weapon_visual: Node3D
var _animation_player: AnimationPlayer
var _animation_tree: AnimationTree
var mouse_sensitivity: float = MOUSE_SENSITIVITY
var invert_mouse_y: bool = false
var camera_fov: float = 74.0
var _footstep_dirt: AudioStreamPlayer3D
var _footstep_asphalt: AudioStreamPlayer3D
var _landing_audio: AudioStreamPlayer3D
var _footstep_timer: float = 0.16

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _load_video_controls()
    spring_arm.add_excluded_object(get_rid())
    ray.add_exception(self)
    _create_character_visual()
    _create_character_audio()
    health_changed.emit(health)
    battery_changed.emit(battery)

func _load_video_controls() -> void:
    var config := ConfigFile.new()
    if config.load("user://settings.cfg") == OK:
        mouse_sensitivity = float(config.get_value("controls", "sensitivity", MOUSE_SENSITIVITY))
        invert_mouse_y = bool(config.get_value("controls", "invert_y", false))
        camera_fov = float(config.get_value("controls", "fov", 74.0))
    camera.fov = clampf(camera_fov, 60.0, 100.0)

func save_control_options(sensitivity: float, inverted_y: bool, fov_value: float) -> void:
    mouse_sensitivity = clampf(sensitivity, 0.0007, 0.006)
    invert_mouse_y = inverted_y
    camera_fov = clampf(fov_value, 60.0, 100.0)
    camera.fov = camera_fov
    var config := ConfigFile.new()
    config.set_value("controls", "sensitivity", mouse_sensitivity)
    config.set_value("controls", "invert_y", invert_mouse_y)
    config.set_value("controls", "fov", camera_fov)
    config.save("user://settings.cfg")

func _create_character_visual() -> void:
    character_visual = CHARACTER_SCENE.instantiate() as Node3D
    character_visual.name = "characterMedium"
    character_visual.scale = Vector3.ONE * 0.5
    visuals.add_child(character_visual)
    character_skeleton = _find_skeleton(character_visual)
    if character_skeleton == null:
        push_error("El personaje Kenney no contiene Skeleton3D")
        return
    var human_skin := load("res://assets/third_party/kenney/character/Skins/humanMaleA.png") as Texture2D
    _apply_character_skin(character_visual, human_skin)
    _setup_character_animation()
    _weapon_visual = AXE_SCENE.instantiate() as Node3D
    _weapon_visual.name = "EquippedWeaponModel"
    _weapon_visual.position = Vector3(0.48, 0.8, -0.18)
    _weapon_visual.rotation_degrees = Vector3(0, 0, -25)
    _weapon_visual.scale = Vector3(0.32, 0.32, 0.32)
    visuals.add_child(_weapon_visual)
    _weapon_visual.visible = false

func _setup_character_animation() -> void:
    _animation_player = AnimationPlayer.new()
    _animation_player.name = "CharacterAnimationPlayer"
    add_child(_animation_player)
    var library := AnimationLibrary.new()
    var idle := _extract_animation(IDLE_SCENE, "Root|Idle", "idle")
    idle.loop_mode = Animation.LOOP_LINEAR
    library.add_animation("idle", idle)
    var run := _extract_animation(RUN_SCENE, "Root|Run", "run")
    run.loop_mode = Animation.LOOP_LINEAR
    library.add_animation("run", run)
    var walk := run.duplicate() as Animation
    walk.resource_name = "walk"
    _retime_animation(walk, 1.45)
    library.add_animation("walk", walk)
    var crouch := idle.duplicate() as Animation
    crouch.resource_name = "crouch"
    library.add_animation("crouch", crouch)
    var jump := _extract_animation(JUMP_SCENE, "Root|Jump", "jump")
    jump.loop_mode = Animation.LOOP_NONE
    library.add_animation("jump", jump)
    _animation_player.add_animation_library("", library)
    var blend := AnimationNodeBlendSpace2D.new()
    var anim_node := AnimationNodeAnimation.new(); anim_node.animation = "idle"; blend.add_blend_point(anim_node, Vector2.ZERO, -1, "idle")
    anim_node = AnimationNodeAnimation.new(); anim_node.animation = "walk"; blend.add_blend_point(anim_node, Vector2(0, 1), -1, "walk")
    anim_node = AnimationNodeAnimation.new(); anim_node.animation = "run"; blend.add_blend_point(anim_node, Vector2(0, 2), -1, "run")
    anim_node = AnimationNodeAnimation.new(); anim_node.animation = "crouch"; blend.add_blend_point(anim_node, Vector2(-1, 0), -1, "crouch")
    anim_node = AnimationNodeAnimation.new(); anim_node.animation = "jump"; blend.add_blend_point(anim_node, Vector2(1, 0), -1, "jump")
    _animation_tree = AnimationTree.new()
    _animation_tree.name = "CharacterAnimationTree"
    _animation_tree.anim_player = NodePath("../CharacterAnimationPlayer")
    _animation_tree.tree_root = blend
    _animation_tree.active = true
    add_child(_animation_tree)

func _extract_animation(scene: PackedScene, wanted_name: String, output_name: String) -> Animation:
    var source_root := scene.instantiate()
    add_child(source_root)
    var source_player := _find_animation_player(source_root)
    if source_player == null:
        push_error("Clip importado sin AnimationPlayer: " + wanted_name)
        source_root.queue_free()
        return Animation.new()
    var animation := source_player.get_animation(wanted_name).duplicate() as Animation
    animation.resource_name = output_name
    for track in range(animation.get_track_count()):
        var source_path := str(animation.track_get_path(track))
        animation.track_set_path(track, NodePath("Visual/characterMedium/" + source_path))
    source_root.queue_free()
    return animation

func _retime_animation(animation: Animation, speed_factor: float) -> void:
    for track in range(animation.get_track_count()):
        for key in range(animation.track_get_key_count(track)):
            animation.track_set_key_time(track, key, animation.track_get_key_time(track, key) * speed_factor)
    animation.length *= speed_factor

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D: return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null: return found
    return null

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer: return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found != null: return found
    return null

func _apply_character_skin(node: Node, skin: Texture2D) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        for surface in range(mesh_instance.mesh.get_surface_count()):
            var source_mat := mesh_instance.mesh.surface_get_material(surface)
            var material := source_mat.duplicate() as StandardMaterial3D if source_mat is StandardMaterial3D else StandardMaterial3D.new()
            material.albedo_texture = skin
            material.albedo_color = Color.WHITE
            material.roughness = 0.82
            mesh_instance.set_surface_override_material(surface, material)
    for child in node.get_children(): _apply_character_skin(child, skin)

func _create_character_audio() -> void:
    _footstep_dirt = _make_audio_player_3d("FootstepsDirt", "res://audio/mission04/footsteps_dirt.mp3")
    _footstep_asphalt = _make_audio_player_3d("FootstepsAsphalt", "res://audio/mission04/footsteps_asphalt.mp3")
    _landing_audio = _make_audio_player_3d("LandingSound", "res://audio/mission04/landing_thud.mp3")

func _make_audio_player_3d(label: String, stream_path: String) -> AudioStreamPlayer3D:
    var audio := AudioStreamPlayer3D.new()
    audio.name = label
    audio.stream = load(stream_path) as AudioStream
    audio.unit_size = 4.0
    audio.max_distance = 22.0
    audio.volume_db = -7.0
    audio.position = Vector3(0.0, 0.12, 0.0)
    var cutoff := Timer.new()
    cutoff.name = "OneShotCutoff"
    cutoff.one_shot = true
    cutoff.timeout.connect(audio.stop)
    audio.add_child(cutoff)
    add_child(audio)
    return audio

func _play_short_audio(audio: AudioStreamPlayer3D, duration: float) -> void:
    if audio == null or audio.stream == null: return
    var cutoff := audio.get_node("OneShotCutoff") as Timer
    cutoff.stop()
    audio.pitch_scale = randf_range(0.94, 1.04)
    var stream_length := audio.stream.get_length()
    var start_at := randf_range(0.0, maxf(0.0, stream_length - duration))
    audio.play(start_at)
    cutoff.start(duration)

func set_ui_open(opened: bool) -> void:
    ui_open = opened
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if opened else Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if ui_open:
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        pivot.rotation.y -= event.relative.x * mouse_sensitivity
        pivot.rotation.x = clampf(pivot.rotation.x + event.relative.y * mouse_sensitivity * (1.0 if invert_mouse_y else -1.0), -1.33, 1.22)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("camera_toggle"):
        first_person = not first_person
        _camera_transition_target = 0.02 if first_person else CAMERA_LENGTH
        _camera_transition_started_usec = Time.get_ticks_usec()
        action_feedback.emit("Camara: PRIMERA PERSONA" if first_person else "Camara: TERCERA PERSONA", false)
    elif event.is_action_pressed("flashlight_toggle"):
        if battery <= 0.0 and not flashlight_enabled:
            action_feedback.emit("Linterna sin bateria; usa una pila en el inventario", true)
        else:
            flashlight_enabled = not flashlight_enabled
            if flashlight_enabled:
                torch_equipped = false
                torch_light.visible = false
            flashlight.visible = flashlight_enabled
    elif event.is_action_pressed("interact"):
        var pickup: WorldPickup = get_focused_pickup()
        if pickup != null:
            _collect(pickup)
    elif event.is_action_pressed("skip_time_debug"):
        GameClock.advance_minutes(120.0)
        action_feedback.emit("Reloj adelantado 2 horas (atajo de pruebas)", false)

func _physics_process(delta: float) -> void:
    var was_on_floor := is_on_floor()
    var target_camera_distance: float = 0.02 if first_person else CAMERA_LENGTH
    spring_arm.spring_length = move_toward(spring_arm.spring_length, target_camera_distance, CAMERA_CHANGE_SPEED * delta)
    if _camera_transition_started_usec >= 0 and is_equal_approx(spring_arm.spring_length, _camera_transition_target):
        var elapsed_ms: float = float(Time.get_ticks_usec() - _camera_transition_started_usec) / 1000.0
        _camera_transition_started_usec = -1
        camera_transition_measured.emit(elapsed_ms)
        print("CAMERA_TRANSITION_MS: %.3f" % elapsed_ms)
    visuals.visible = spring_arm.spring_length > 0.42

    var wants_crouch: bool = Input.is_action_pressed("crouch") and not ui_open
    if wants_crouch:
        crouching = true
    elif crouching and _can_stand():
        crouching = false
    var desired_height: float = 1.2 if crouching else 1.8
    var shape: CapsuleShape3D = collider.shape as CapsuleShape3D
    shape.height = move_toward(shape.height, desired_height, 3.5 * delta)
    collider.position.y = shape.height * 0.5
    pivot.position.y = move_toward(pivot.position.y, 1.03 if crouching else 1.58, 3.2 * delta)
    if character_visual != null:
        character_visual.scale.y = move_toward(character_visual.scale.y, 0.41 if crouching else 0.5, 2.0 * delta)

    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    elif Input.is_action_just_pressed("jump") and not ui_open and not crouching:
        velocity.y = JUMP_VELOCITY

    var raw_input := Vector2.ZERO if ui_open else Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    var direction: Vector3 = pivot.global_transform.basis * Vector3(raw_input.x, 0, raw_input.y)
    direction.y = 0.0
    direction = direction.normalized()
    var running: bool = Input.is_action_pressed("sprint") and not crouching and not ui_open and raw_input.y < 0.0
    var speed: float = CROUCH_SPEED if crouching else (SPRINT_SPEED if running else WALK_SPEED)
    var acceleration: float = ACCELERATION if is_on_floor() else AIR_ACCELERATION
    velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
    velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
    move_and_slide()
    var planar_speed := Vector2(velocity.x, velocity.z).length()
    if not was_on_floor and is_on_floor():
        _play_short_audio(_landing_audio, 0.42)
    _update_footsteps(delta, planar_speed, running)
    var stride := clampf(planar_speed / SPRINT_SPEED, 0.0, 1.0) * (1.0 if is_on_floor() else 0.2)
    if _animation_tree != null:
        var blend_position := Vector2.ZERO
        if not is_on_floor(): blend_position = Vector2(1.0, 0.0)
        elif crouching: blend_position = Vector2(-1.0, 0.0)
        elif stride > 0.05: blend_position = Vector2(0.0, 2.0 if running else 1.0)
        _animation_tree.set("parameters/blend_position", blend_position)
    if direction.length_squared() > 0.02:
        visuals.rotation.y = lerp_angle(visuals.rotation.y, atan2(-direction.x, -direction.z), minf(delta * 11.0, 1.0))

    if flashlight_enabled:
        battery = maxf(0.0, battery - FLASHLIGHT_DRAIN_PER_SECOND * delta)
        if battery <= 0.0:
            flashlight_enabled = false
            flashlight.visible = false
            action_feedback.emit("Bateria agotada", true)
        battery_changed.emit(battery)

func _update_footsteps(delta: float, planar_speed: float, running: bool) -> void:
    if not is_on_floor() or ui_open or planar_speed < 0.7:
        _footstep_timer = minf(_footstep_timer, 0.12)
        return
    _footstep_timer -= delta
    if _footstep_timer > 0.0: return
    var on_asphalt := absf(global_position.x) < 2.9 and global_position.z < 12.0 and global_position.z > -38.0
    _play_short_audio(_footstep_asphalt if on_asphalt else _footstep_dirt, 0.34)
    _footstep_timer = 0.34 if running else 0.52

func _can_stand() -> bool:
    # Examinar solo la zona sobre la cabeza agachada: no incluye el suelo.
    var head_clearance := BoxShape3D.new()
    head_clearance.size = Vector3(0.59, 0.50, 0.59)
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = head_clearance
    query.transform = Transform3D(Basis(), global_position + Vector3(0.0, 1.50, 0.0))
    query.exclude = [get_rid()]
    query.collision_mask = 1
    return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func get_focused_pickup() -> WorldPickup:
    if ui_open:
        return null
    # RayCast3D se actualiza en ticks fisicos; la UI solo consulta el resultado.
    if not ray.is_colliding():
        return null
    var object: Object = ray.get_collider()
    if object is WorldPickup:
        return object as WorldPickup
    return null

func _collect(pickup: WorldPickup) -> void:
    var message: String = inventory.add_item(pickup.item_id, pickup.quantity)
    if not message.is_empty():
        action_feedback.emit(message, true)
        return
    pickup_succeeded.emit(pickup.item_id, pickup.quantity)
    action_feedback.emit("+%d %s" % [pickup.quantity, ItemDB.label_of(pickup.item_id)], false)
    pickup.queue_free()

func use_inventory_item(item_id: String) -> String:
    match item_id:
        "battery":
            if battery >= 100.0:
                return "La bateria ya esta llena"
            if inventory.consume("battery", 1):
                battery = minf(100.0, battery + 35.0)
                battery_changed.emit(battery)
                return "Pila utilizada: +35 de bateria"
        "bandage":
            if health >= 100.0:
                return "Salud maxima"
            if inventory.consume("bandage", 1):
                health = minf(100.0, health + 30.0)
                health_changed.emit(health)
                return "Vendaje utilizado: +30 de salud"
        "torch":
            if inventory.get_count("torch") > 0:
                torch_equipped = not torch_equipped
                torch_light.visible = torch_equipped
                if torch_equipped:
                    flashlight_enabled = false
                    flashlight.visible = false
                return "Antorcha equipada" if torch_equipped else "Antorcha guardada"
        "spear":
            if inventory.get_count("spear") > 0:
                spear_equipped = not spear_equipped
                _weapon_visual.visible = spear_equipped
                return "Lanza equipada (combate en fase 2)" if spear_equipped else "Lanza guardada"
    return "Objeto no utilizable en esta fase"
