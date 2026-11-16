extends Node3D
## Campo de pruebas estilizado. Arquitectura visual efímera: no representa chunks o zonas de fase 2.

const PICKUP_SCENE: PackedScene = preload("res://scenes/world_pickup.tscn")
var sun: DirectionalLight3D
var environment: Environment
var sun_sky: ProceduralSkyMaterial
var asphalt_material: StandardMaterial3D
var wood_material: StandardMaterial3D
var metal_material: StandardMaterial3D
var _wind_audio: AudioStreamPlayer

func _ready() -> void:
    _create_lighting()
    _create_ambient_audio()
    _create_level()
    _create_pickups()
    GameClock.time_changed.connect(_on_clock_changed)
    _on_clock_changed(GameClock.phase, GameClock.format_time(), GameClock.is_night())

func _create_ambient_audio() -> void:
    _wind_audio = AudioStreamPlayer.new()
    _wind_audio.name = "RecordedWindAmbience"
    var wind := load("res://audio/mission04/wind_forest.mp3") as AudioStreamMP3
    wind.loop = true
    _wind_audio.stream = wind
    _wind_audio.volume_db = -23.0
    add_child(_wind_audio)
    if DisplayServer.get_name() != "headless":
        _wind_audio.play()

func _exit_tree() -> void:
    if _wind_audio != null:
        _wind_audio.stop()
        _wind_audio.stream = null

func _create_lighting() -> void:
    var world_environment := WorldEnvironment.new()
    world_environment.name = "TimeDrivenEnvironment"
    environment = Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    environment.ambient_light_energy = 0.86
    environment.fog_enabled = true
    environment.fog_density = 0.008
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
    environment.ambient_light_energy = lerpf(0.26, 0.86, brightness)
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
    asphalt_material = _load_pbr("asphalt_01")
    wood_material = _load_pbr("wood_planks")
    metal_material = _load_pbr("metal_plate")
    var ground := _make_box("Suelo de tierra", Vector3(0, -0.38, 0), Vector3(65, 0.75, 65), Color("#536a60"))
    _apply_box_material(ground, asphalt_material)
    var road := _make_box("Camino", Vector3(0, 0.01, 0), Vector3(5.8, 0.04, 48.0), Color("#596669"), false)
    _apply_box_material(road, asphalt_material)
    var yard := _make_box("Zona central", Vector3(0, 0.015, -12.0), Vector3(24, 0.04, 10.0), Color("#697372"), false)
    _apply_box_material(yard, asphalt_material)
    var highway := _make_box("Acceso carretera", Vector3(0, 0.02, -27.0), Vector3(8.5, 0.05, 18.0), Color("#424b4e"), false)
    _apply_box_material(highway, asphalt_material)
    for lane_z in [-33.0, -21.0]:
        _make_box("Borde carretera", Vector3(0, 0.06, lane_z), Vector3(8.7, 0.13, 0.22), Color("#8a8778"), false)
    for dash in range(6):
        _make_box("Linea vial", Vector3(0, 0.055, -20.0 - float(dash) * 4.0), Vector3(0.18, 0.025, 1.8), Color("#b5a578"), false)
    # Muro bajo que permite verificar colisión de cámara en tercera persona.
    _apply_box_material(_make_box("Muro oeste", Vector3(-10, 1.1, -6), Vector3(0.65, 2.2, 13), Color("#85948f")), metal_material)
    _apply_box_material(_make_box("Muro este", Vector3(10, 1.2, -6), Vector3(0.65, 2.4, 13), Color("#7d8987")), metal_material)
    _apply_box_material(_make_box("Muro norte", Vector3(0, 1.25, -12.8), Vector3(21, 2.5, 0.7), Color("#89928b")), metal_material)
    # Refugio pequeño: paredes abiertas para entrar y observar la linterna.
    _apply_box_material(_make_box("Refugio pared izquierda", Vector3(-5, 1.6, 10.0), Vector3(0.5, 3.2, 7.0), Color("#677b79")), wood_material)
    _apply_box_material(_make_box("Refugio pared derecha", Vector3(5, 1.6, 10.0), Vector3(0.5, 3.2, 7.0), Color("#677b79")), wood_material)
    _apply_box_material(_make_box("Refugio pared fondo", Vector3(0, 1.6, 13.5), Vector3(10.4, 3.2, 0.5), Color("#637b7c")), wood_material)
    var refuge_roof := _make_box("Techo refugio", Vector3(0, 3.35, 10), Vector3(11, 0.35, 7.9), Color("#303e4c"))
    _apply_box_material(refuge_roof, metal_material)
    # Taller de servicio abandonado que conecta el refugio con la carretera.
    _apply_box_material(_make_box("Taller pared trasera", Vector3(0, 2.0, -18.0), Vector3(14.0, 4.0, 0.55), Color("#565c59")), metal_material)
    _apply_box_material(_make_box("Taller pared izquierda", Vector3(-6.75, 2.0, -12.5), Vector3(0.5, 4.0, 11.0), Color("#62655d")), metal_material)
    _apply_box_material(_make_box("Taller pared derecha", Vector3(6.75, 2.0, -12.5), Vector3(0.5, 4.0, 11.0), Color("#62655d")), metal_material)
    var workshop_roof := _make_box("Taller techo", Vector3(0, 4.05, -12.7), Vector3(14.0, 0.35, 11.5), Color("#343d40"))
    _apply_box_material(workshop_roof, metal_material)
    _apply_box_material(_make_box("Porton del taller", Vector3(0, 1.55, -6.95), Vector3(5.0, 3.1, 0.18), Color("#77776a"), false), metal_material)
    for slat in range(8):
        _make_box("Lama porton", Vector3(0, 0.35 + float(slat) * 0.34, -6.82), Vector3(4.8, 0.035, 0.04), Color("#454b49"), false)
    _make_box("Isla de servicio", Vector3(-3.3, 0.58, -26.0), Vector3(2.1, 1.15, 1.45), Color("#8b7958"))
    _make_box("Bomba de combustible", Vector3(-3.3, 1.7, -26.0), Vector3(0.85, 1.2, 0.75), Color("#a74d3f"))
    _make_box("Techo marquesina", Vector3(-3.3, 3.05, -26.0), Vector3(7.5, 0.24, 3.4), Color("#65716c"))
    # Vehículo inmóvil como hito de orientación a la salida.
    _make_box("Carroceria abandonada", Vector3(4.1, 0.72, -30.0), Vector3(2.2, 0.72, 4.4), Color("#566365"))
    _make_box("Cabina oxidada", Vector3(4.1, 1.4, -30.0), Vector3(1.9, 0.72, 2.1), Color("#3e4a4c"))
    for wheel_x in [3.0, 5.2]:
        for wheel_z in [-31.2, -28.8]:
            var wheel := CylinderMesh.new()
            wheel.top_radius = 0.36; wheel.bottom_radius = 0.36; wheel.height = 0.2; wheel.radial_segments = 10
            var tire := MeshInstance3D.new(); tire.mesh = wheel; tire.position = Vector3(wheel_x, 0.37, wheel_z); tire.rotation.z = PI * 0.5
            var tire_mat := StandardMaterial3D.new(); tire_mat.albedo_color = Color("#202323"); tire.material_override = tire_mat; add_child(tire)
    var refuge_floor := _make_box("Piso refugio", Vector3(0, 0.003, 10), Vector3(10, 0.006, 7.0), Color("#938674"), false)
    _apply_box_material(refuge_floor, wood_material)
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
    _create_vegetation_cluster(Vector3(-25, 0, -22), 16)
    _create_vegetation_cluster(Vector3(25, 0, -25), 18)
    _create_vegetation_cluster(Vector3(-24, 0, 16), 12)
    _create_sign("SALIDA / CARRETERA", Vector3(0, 3.0, -20.0))
    _create_box_radio(Vector3(2.4, 1.1, -10.2))
    _place_survival_props()
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

func _create_vegetation_cluster(center: Vector3, count: int) -> void:
    var crown := CylinderMesh.new()
    crown.top_radius = 0.1; crown.bottom_radius = 1.05; crown.height = 3.2; crown.radial_segments = 7
    var mat := StandardMaterial3D.new(); mat.albedo_color = Color("#31534c"); mat.roughness = 1.0
    var multi := MultiMesh.new(); multi.transform_format = MultiMesh.TRANSFORM_3D; multi.mesh = crown; multi.instance_count = count
    var rng := RandomNumberGenerator.new(); rng.seed = int(center.x * 101 + center.z * 57 + 904)
    for i in range(count):
        var x := rng.randf_range(-9.0, 9.0); var z := rng.randf_range(-8.0, 8.0); var s := rng.randf_range(0.75, 1.3)
        multi.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(x, 2.6 * s, z)))
    var foliage := MultiMeshInstance3D.new(); foliage.multimesh = multi; foliage.material_override = mat
    foliage.position = center; foliage.visibility_range_end = 64.0; foliage.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
    add_child(foliage)

func _create_box_radio(at: Vector3) -> void:
    var radio := _make_box("Radio averiada", at, Vector3(0.62, 0.35, 0.28), Color("#3b4847"), false)
    var aerial := MeshInstance3D.new(); var rod := CylinderMesh.new(); rod.top_radius = 0.012; rod.bottom_radius = 0.018; rod.height = 0.48
    aerial.mesh = rod; aerial.position = at + Vector3(0.18, 0.38, 0); aerial.rotation.z = -0.18
    var metal := StandardMaterial3D.new(); metal.albedo_color = Color("#a5a58f"); aerial.material_override = metal; add_child(aerial)

func _load_pbr(asset_name: String) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_texture = load("res://assets/textures/polyhaven/%s_diff_2k.jpg" % asset_name) as Texture2D
    material.normal_enabled = true
    material.normal_texture = load("res://assets/textures/polyhaven/%s_nor_gl_2k.jpg" % asset_name) as Texture2D
    material.roughness_texture = load("res://assets/textures/polyhaven/%s_rough_2k.jpg" % asset_name) as Texture2D
    material.uv1_scale = Vector3(9.0, 9.0, 1.0)
    material.roughness = 0.92
    return material

func _apply_box_material(body: Node3D, material: Material) -> void:
    var mesh_node := body.get_node_or_null("MeshInstance3D") as MeshInstance3D
    if mesh_node != null:
        mesh_node.material_override = material

func _place_survival_props() -> void:
    # Catorce props glTF reales del Kenney Survival Kit.
    _place_prop("barrel", Vector3(-5.4, 0.0, 0.8), 1.15)
    _place_prop("bedroll", Vector3(-2.7, 0.2, 11.0), 0.8)
    _place_prop("bottle", Vector3(2.0, 1.0, 11.1), 0.35)
    _place_prop("box", Vector3(6.6, 0.0, -2.8), 1.05)
    _place_prop("bucket", Vector3(-4.7, 0.0, -2.2), 1.0)
    _place_prop("chest", Vector3(-7.5, 0.0, -5.5), 0.95)
    _place_prop("metal-panel", Vector3(7.7, 1.3, -7.0), 1.0)
    _place_prop("metal-panel-screws", Vector3(-7.7, 1.4, -7.0), 1.0)
    _place_prop("resource-planks", Vector3(4.2, 0.05, -5.8), 0.8)
    _place_prop("signpost", Vector3(1.3, 0.0, -19.1), 0.9)
    _place_prop("tent", Vector3(8.2, 0.0, 9.6), 1.1)
    _place_prop("tool-axe", Vector3(1.6, 0.95, 11.2), 0.5)
    _place_prop("workbench", Vector3(4.1, 0.0, 7.9), 0.9)
    _place_prop("tree-log", Vector3(-3.6, 0.0, 5.7), 1.05)

func _place_prop(asset_name: String, at: Vector3, object_scale: float, yaw: float = 0.0) -> Node3D:
    var packed := load("res://assets/third_party/kenney/survival/%s.glb" % asset_name) as PackedScene
    if packed == null:
        push_error("No se pudo cargar prop GLB: " + asset_name)
        return null
    var instance := packed.instantiate() as Node3D
    instance.name = "Kenney_" + asset_name.replace("-", "_")
    instance.position = at
    instance.rotation.y = yaw
    instance.scale = Vector3.ONE * object_scale
    add_child(instance)
    return instance

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
