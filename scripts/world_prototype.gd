extends Node3D
## Campo de pruebas estilizado. Arquitectura visual efímera: no representa chunks o zonas de fase 2.

const PICKUP_SCENE: PackedScene = preload("res://scenes/world_pickup.tscn")
var sun: DirectionalLight3D
var environment: Environment
var sun_sky: ProceduralSkyMaterial

func _ready() -> void:
    _create_lighting()
    _create_level()
    _create_pickups()
    GameClock.time_changed.connect(_on_clock_changed)
    _on_clock_changed(GameClock.phase, GameClock.format_time(), GameClock.is_night())

func _create_lighting() -> void:
    var world_environment := WorldEnvironment.new()
    world_environment.name = "TimeDrivenEnvironment"
    environment = Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    environment.ambient_light_energy = 0.75
    environment.fog_enabled = true
    environment.fog_density = 0.012
    environment.fog_light_color = Color("#829aa1")
    var sky := Sky.new()
    sun_sky = ProceduralSkyMaterial.new()
    sky.sky_material = sun_sky
    environment.sky = sky
    world_environment.environment = environment
    add_child(world_environment)
    sun = DirectionalLight3D.new()
    sun.name = "SunMoon"
    sun.shadow_enabled = true
    sun.light_energy = 1.6
    add_child(sun)

func _on_clock_changed(t: float, _clock_text: String, _night: bool) -> void:
    # 6:00..18:00 se ilumina gradualmente; 18:00..6:00 es noche.
    var solar: float = sin((t - 0.25) * TAU)
    var brightness: float = clampf(solar * 1.25 + 0.1, 0.0, 1.0)
    sun.rotation_degrees = Vector3(-20.0 - 65.0 * absf(solar), -75.0 + t * 360.0, 0.0)
    sun.light_energy = lerpf(0.04, 1.65, brightness)
    sun.light_color = Color("#ffbb8d").lerp(Color("#fff0db"), brightness)
    environment.ambient_light_energy = lerpf(0.18, 0.82, brightness)
    environment.fog_light_color = Color("#202b45").lerp(Color("#96acb0"), brightness)
    sun_sky.sky_top_color = Color("#061326").lerp(Color("#477d98"), brightness)
    sun_sky.sky_horizon_color = Color("#202e43").lerp(Color("#a5c2b9"), brightness)
    sun_sky.ground_bottom_color = Color("#0e1723")
    sun_sky.ground_horizon_color = Color("#343d45").lerp(Color("#6c7c72"), brightness)

func _make_box(label: String, center: Vector3, box_size: Vector3, color: Color, collidable: bool = true) -> Node3D:
    var body: Node3D
    if collidable:
        body = StaticBody3D.new()
    else:
        body = Node3D.new()
    body.name = label
    body.position = center
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = box_size
    mesh.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.9
    mesh.material_override = mat
    body.add_child(mesh)
    if collidable:
        var collider := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = box_size
        collider.shape = shape
        body.add_child(collider)
    add_child(body)
    return body

func _create_level() -> void:
    _make_box("Suelo de tierra", Vector3(0, -0.38, 0), Vector3(65, 0.75, 65), Color("#536a60"))
    _make_box("Camino", Vector3(0, 0.01, 0), Vector3(5.8, 0.04, 48.0), Color("#596669"), false)
    _make_box("Zona central", Vector3(0, 0.015, -12.0), Vector3(24, 0.04, 10.0), Color("#697372"), false)
    # Muro bajo que permite verificar colisión de cámara en tercera persona.
    _make_box("Muro oeste", Vector3(-10, 1.1, -6), Vector3(0.65, 2.2, 13), Color("#85948f"))
    _make_box("Muro este", Vector3(10, 1.2, -6), Vector3(0.65, 2.4, 13), Color("#7d8987"))
    _make_box("Muro norte", Vector3(0, 1.25, -12.8), Vector3(21, 2.5, 0.7), Color("#89928b"))
    # Refugio pequeño: paredes abiertas para entrar y observar la linterna.
    _make_box("Refugio pared izquierda", Vector3(-5, 1.6, 10.0), Vector3(0.5, 3.2, 7.0), Color("#677b79"))
    _make_box("Refugio pared derecha", Vector3(5, 1.6, 10.0), Vector3(0.5, 3.2, 7.0), Color("#677b79"))
    _make_box("Refugio pared fondo", Vector3(0, 1.6, 13.5), Vector3(10.4, 3.2, 0.5), Color("#637b7c"))
    _make_box("Techo refugio", Vector3(0, 3.35, 10), Vector3(11, 0.35, 7.9), Color("#303e4c"))
    _make_box("Piso refugio", Vector3(0, 0.003, 10), Vector3(10, 0.006, 7.0), Color("#938674"), false)
    # Pasadizo bajo al costado del refugio: requiere agacharse y bloquea incorporarse.
    _make_box("Techo pasadizo bajo", Vector3(-7.0, 1.52, 8.5), Vector3(2.4, 0.28, 4.0), Color("#52666c"))
    _make_box("Soporte pasadizo", Vector3(-8.25, 0.70, 8.5), Vector3(0.22, 1.4, 3.8), Color("#718581"))
    _make_box("Cama", Vector3(-2.7, 0.47, 11.1), Vector3(1.85, 0.67, 2.85), Color("#9d9e8b"))
    _make_box("Mesa", Vector3(2.0, 0.85, 11.5), Vector3(2.8, 0.22, 1.6), Color("#9f876a"))
    for side in [-1, 1]:
        _make_box("Patio contenedor %d" % side, Vector3(side * 14.2, 1.35, 7.0), Vector3(6, 2.7, 3.5), Color("#466f77") if side < 0 else Color("#90695a"))
        for stripe in range(3):
            _make_box("Contenedor perfil %d %d" % [side, stripe], Vector3(side * 14.2 + stripe * 1.4 - 1.4, 1.42, 5.2), Vector3(0.13, 2.5, 0.1), Color("#9da6a1"), false)
    for i in range(6):
        var x: float = -8.0 + float(i % 3) * 6.5
        var z: float = -20.0 - float(i / 3) * 5.0
        _make_box("Cajon %d" % i, Vector3(x, 0.58, z), Vector3(1.5, 1.15, 1.35), Color("#a18465"))
    # Colocar postes con luces fijas débiles como referencia visual nocturna.
    for pole_z in [-5.0, -19.0]:
        _make_box("Poste", Vector3(3.9, 2.7, pole_z), Vector3(0.22, 5.4, 0.22), Color("#505c64"))
        var lamp := OmniLight3D.new()
        lamp.position = Vector3(3.9, 5.0, pole_z)
        lamp.light_color = Color("#f0be7b")
        lamp.light_energy = 0.65
        lamp.omni_range = 8.0
        add_child(lamp)
    for i in range(13):
        var x: float = -28.0 + float(i) * 4.8
        _create_low_tree(Vector3(x, 0, -29.0 + float(i % 4) * 1.4))
    _create_sign("ESTACION REFUGIO  /  SECTOR A", Vector3(0, 2.0, 7.4))
    _create_sign("PASO BAJO  /  CTRL", Vector3(-7.0, 2.05, 6.45))
    _create_sign("PATIO DE RECOLECCION  /  PROTOTIPO", Vector3(-8.5, 4.0, -11.0))

func _create_sign(text_value: String, at: Vector3) -> void:
    var label := Label3D.new()
    label.text = text_value
    label.position = at
    label.scale = Vector3.ONE
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 42 if text_value.begins_with("PATIO DE RECOLECCION") else 48
    label.pixel_size = 0.006
    label.modulate = Color("#c9e0d5")
    label.outline_size = 13
    add_child(label)

func _create_low_tree(at: Vector3) -> void:
    _make_box("Tronco", at + Vector3(0, 1.1, 0), Vector3(0.5, 2.2, 0.5), Color("#6d6252"), false)
    var cone_mesh := CylinderMesh.new()
    cone_mesh.top_radius = 0.1
    cone_mesh.bottom_radius = 1.25
    cone_mesh.height = 3.7
    var mesh := MeshInstance3D.new()
    mesh.mesh = cone_mesh
    mesh.position = at + Vector3(0, 3.5, 0)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#385f5c")
    mesh.material_override = mat
    add_child(mesh)

func _create_pickups() -> void:
    # Reparto deliberado de materiales para desbloquear las 3 recetas.
    var specimens: Array = [
        ["cloth", 2, Vector3(-2.2, 0.12, 8)],
        ["herb", 2, Vector3(-3.5, 0.12, 7.2)],
        ["wood", 3, Vector3(1.5, 0.12, 6.4)],
        ["resin", 2, Vector3(3.2, 0.12, 7.1)],
        ["scrap", 3, Vector3(6.4, 0.12, 2.5)],
        ["battery", 2, Vector3(-6.8, 0.12, 2.0)],
        ["food", 4, Vector3(3.2, 0.12, -2.5)],
        ["wood", 10, Vector3(7.0, 0.12, -7.8)],
        ["scrap", 18, Vector3(-7.2, 0.12, -7.0)],
        ["cloth", 8, Vector3(6.9, 0.12, -11.0)],
        ["wood", 45, Vector3(-4.0, 0.12, -17.0)],
        ["herb", 12, Vector3(0.0, 0.12, -22.0)],
    ]
    for specimen in specimens:
        var pickup: WorldPickup = PICKUP_SCENE.instantiate() as WorldPickup
        pickup.item_id = str(specimen[0])
        pickup.quantity = int(specimen[1])
        pickup.position = specimen[2]
        add_child(pickup)
