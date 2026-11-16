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

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    spring_arm.add_excluded_object(get_rid())
    ray.add_exception(self)
    _create_character_visual()
    health_changed.emit(health)
    battery_changed.emit(battery)

func _create_character_visual() -> void:
    # Geometría placeholder reemplazable por un personaje importado y AnimationTree.
    _add_mesh_part(visuals, "Chaqueta", CapsuleMesh.new(), Vector3(0, 1.02, 0), Vector3(0.75, 0.82, 0.45), Color("#6ba8a3"))
    _add_mesh_part(visuals, "Cabeza", SphereMesh.new(), Vector3(0, 1.69, 0), Vector3(0.38, 0.42, 0.36), Color("#e7b597"))
    _add_mesh_part(visuals, "Mochila", BoxMesh.new(), Vector3(0, 1.08, 0.34), Vector3(0.55, 0.69, 0.34), Color("#647d6f"))
    _add_mesh_part(visuals, "PiernaIzq", CapsuleMesh.new(), Vector3(-0.16, 0.45, 0), Vector3(0.23, 0.60, 0.24), Color("#2a3c50"))
    _add_mesh_part(visuals, "PiernaDer", CapsuleMesh.new(), Vector3(0.16, 0.45, 0), Vector3(0.23, 0.60, 0.24), Color("#2a3c50"))
    _add_mesh_part(visuals, "BrazoIzq", CapsuleMesh.new(), Vector3(-0.43, 1.12, 0), Vector3(0.23, 0.64, 0.24), Color("#588b86"))
    _add_mesh_part(visuals, "BrazoDer", CapsuleMesh.new(), Vector3(0.43, 1.12, 0), Vector3(0.23, 0.64, 0.24), Color("#588b86"))
    _spear_model = Node3D.new()
    _spear_model.name = "EquippedSpearVisual"
    _spear_model.position = Vector3(0.57, 1.12, -0.23)
    visuals.add_child(_spear_model)
    _add_mesh_part(_spear_model, "Astil", CylinderMesh.new(), Vector3(0, 0.25, 0), Vector3(0.065, 1.65, 0.065), Color("#b48859"))
    _add_mesh_part(_spear_model, "Punta", CylinderMesh.new(), Vector3(0, 1.12, 0), Vector3(0.13, 0.35, 0.13), Color("#c5d8df"))
    _spear_model.visible = false

func _add_mesh_part(parent: Node3D, label: String, mesh: Mesh, at: Vector3, scaling: Vector3, tint: Color) -> void:
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

func set_ui_open(opened: bool) -> void:
    ui_open = opened
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if opened else Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if ui_open:
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        pivot.rotation.y -= event.relative.x * MOUSE_SENSITIVITY
        pivot.rotation.x = clampf(pivot.rotation.x - event.relative.y * MOUSE_SENSITIVITY, -1.33, 1.22)
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
    visuals.scale.y = move_toward(visuals.scale.y, 0.72 if crouching else 1.0, 2.0 * delta)

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
