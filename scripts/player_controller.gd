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
var _spear_model: Node3D
var _camera_transition_started_usec: int = -1
var _camera_transition_target: float = CAMERA_LENGTH
var _motion_phase: float = 0.0
var _limbs: Array[Node3D] = []
var _animation_player: AnimationPlayer
var _animation_tree: AnimationTree
var mouse_sensitivity: float = MOUSE_SENSITIVITY
var invert_mouse_y: bool = false
var camera_fov: float = 74.0

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _load_video_controls()
    spring_arm.add_excluded_object(get_rid())
    ray.add_exception(self)
    _create_character_visual()
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
    # Superviviente low-poly con silueta humana: piezas angulares, sin primitivas cápsula.
    var torso := _add_mesh_part(visuals, "Chaqueta de campo", BoxMesh.new(), Vector3(0, 1.13, 0), Vector3(0.62, 0.72, 0.34), Color("#526d68"))
    torso.rotation.x = -0.04
    _add_mesh_part(visuals, "Cuello", CylinderMesh.new(), Vector3(0, 1.57, 0), Vector3(0.14, 0.16, 0.14), Color("#b58c70"))
    _add_mesh_part(visuals, "Cabeza", SphereMesh.new(), Vector3(0, 1.76, 0), Vector3(0.24, 0.29, 0.23), Color("#bc957d"))
    _add_mesh_part(visuals, "Cabello", BoxMesh.new(), Vector3(0, 1.96, 0.015), Vector3(0.39, 0.13, 0.38), Color("#292b28"))
    _add_mesh_part(visuals, "Mochila", BoxMesh.new(), Vector3(0, 1.19, 0.27), Vector3(0.45, 0.56, 0.25), Color("#384d43"))
    _add_mesh_part(visuals, "Correa izquierda", BoxMesh.new(), Vector3(-0.205, 1.18, -0.18), Vector3(0.07, 0.58, 0.04), Color("#b29765"))
    _add_mesh_part(visuals, "Correa derecha", BoxMesh.new(), Vector3(0.205, 1.18, -0.18), Vector3(0.07, 0.58, 0.04), Color("#b29765"))
    var leg_l := _add_mesh_part(visuals, "Pantalon cargo izquierdo", BoxMesh.new(), Vector3(-0.16, 0.58, 0), Vector3(0.23, 0.68, 0.27), Color("#39464b"))
    var leg_r := _add_mesh_part(visuals, "Pantalon cargo derecho", BoxMesh.new(), Vector3(0.16, 0.58, 0), Vector3(0.23, 0.68, 0.27), Color("#39464b"))
    _limbs.append(leg_l); _limbs.append(leg_r)
    _add_mesh_part(visuals, "Bolsillo cargo izquierdo", BoxMesh.new(), Vector3(-0.17, 0.62, -0.15), Vector3(0.18, 0.22, 0.08), Color("#586257"))
    _add_mesh_part(visuals, "Bolsillo cargo derecho", BoxMesh.new(), Vector3(0.17, 0.62, -0.15), Vector3(0.18, 0.22, 0.08), Color("#586257"))
    _add_mesh_part(visuals, "Bota izquierda", BoxMesh.new(), Vector3(-0.16, 0.13, -0.065), Vector3(0.27, 0.22, 0.42), Color("#252928"))
    _add_mesh_part(visuals, "Bota derecha", BoxMesh.new(), Vector3(0.16, 0.13, -0.065), Vector3(0.27, 0.22, 0.42), Color("#252928"))
    var arm_l := _add_mesh_part(visuals, "Manga izquierda", BoxMesh.new(), Vector3(-0.39, 1.13, 0), Vector3(0.20, 0.62, 0.22), Color("#526d68"))
    var arm_r := _add_mesh_part(visuals, "Manga derecha", BoxMesh.new(), Vector3(0.39, 1.13, 0), Vector3(0.20, 0.62, 0.22), Color("#526d68"))
    _limbs.append(arm_l); _limbs.append(arm_r)
    _add_mesh_part(visuals, "Guante izquierdo", BoxMesh.new(), Vector3(-0.39, 0.79, 0), Vector3(0.18, 0.13, 0.20), Color("#303735"))
    _add_mesh_part(visuals, "Guante derecho", BoxMesh.new(), Vector3(0.39, 0.79, 0), Vector3(0.18, 0.13, 0.20), Color("#303735"))
    _spear_model = Node3D.new()
    _spear_model.name = "EquippedSpearVisual"
    _spear_model.position = Vector3(0.57, 1.12, -0.23)
    visuals.add_child(_spear_model)
    _add_mesh_part(_spear_model, "Astil", CylinderMesh.new(), Vector3(0, 0.25, 0), Vector3(0.065, 1.65, 0.065), Color("#b48859"))
    _add_mesh_part(_spear_model, "Punta", CylinderMesh.new(), Vector3(0, 1.12, 0), Vector3(0.13, 0.35, 0.13), Color("#c5d8df"))
    _spear_model.visible = false
    _setup_character_animation()

func _setup_character_animation() -> void:
    _animation_player = AnimationPlayer.new()
    _animation_player.name = "CharacterAnimationPlayer"
    add_child(_animation_player)
    var library := AnimationLibrary.new()
    for anim_name in ["idle", "walk", "run", "crouch", "jump"]:
        var animation := Animation.new()
        animation.length = 1.0
        animation.loop_mode = Animation.LOOP_LINEAR if anim_name in ["idle", "walk", "run", "crouch"] else Animation.LOOP_NONE
        var scale := 0.0 if anim_name in ["idle", "crouch"] else (0.8 if anim_name == "walk" else 1.0)
        for i in range(4):
            var track := animation.add_track(Animation.TYPE_VALUE)
            animation.track_insert_key(track, 0.0, _limbs[i].rotation.x)
            var side := 1.0 if i in [0, 3] else -1.0
            var amplitude := 0.43 * scale * side
            animation.track_insert_key(track, 0.25, amplitude)
            animation.track_insert_key(track, 0.5, 0.0)
            animation.track_insert_key(track, 0.75, -amplitude)
            animation.track_insert_key(track, 1.0, 0.0)
            animation.track_set_path(track, NodePath("Visual/" + _limbs[i].name + ":rotation:x"))
        library.add_animation(anim_name, animation)
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

func _add_mesh_part(parent: Node3D, label: String, mesh: Mesh, at: Vector3, scaling: Vector3, tint: Color) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = label
    instance.mesh = mesh
    instance.position = at
    instance.scale = scaling
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = 0.88
    instance.material_override = mat
    parent.add_child(instance)
    return instance

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
    visuals.scale.y = 1.0

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
    _motion_phase += delta * (10.0 if running else 7.0)
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
                _spear_model.visible = spear_equipped
                return "Lanza equipada (combate en fase 2)" if spear_equipped else "Lanza guardada"
    return "Objeto no utilizable en esta fase"
