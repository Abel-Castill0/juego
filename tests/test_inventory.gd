extends Node
## Regresion headless: ejecutar con godot --headless --path . --scene res://tests/inventory_tests.tscn

var passed: int = 0
var failed: int = 0

func _ready() -> void:
    call_deferred("_run")

func _expect(condition: bool, label: String) -> void:
    if condition:
        passed += 1
        print("PASS: ", label)
    else:
        failed += 1
        printerr("FAIL: ", label)

func _new_inventory() -> InventoryComponent:
    var inv := InventoryComponent.new()
    add_child(inv)
    return inv

func _run() -> void:
    _expect(InputMap.has_action("camera_toggle"), "Bootstrap crea acciones")
    _expect(ItemDB.get_item("wood").has("weight_kg"), "Carga JSON items")
    _expect(ItemDB.get_recipes().size() == 3, "Carga tres recetas JSON")
    var inventory := _new_inventory()
    _expect(inventory.slots.size() == 20, "Inventario 5x4")
    _expect(inventory.add_item("cloth", 65).is_empty(), "Recoge 65 telas")
    _expect(inventory.slots[0]["quantity"] == 64 and inventory.slots[1]["quantity"] == 1, "Limite de 64 por pila")
    _expect(is_equal_approx(inventory.weight_kg(), 9.75), "Peso exacto de tela")
    _expect(inventory.add_item("herb", 1).is_empty(), "Recolecta hierbas")
    _expect(inventory.discovered_recipes.has("bandage"), "Descubre receta por materiales")
    _expect(not inventory.discovered_recipes.has("torch"), "No descubre antorcha antes de encontrar resina")
    _expect(inventory.can_craft("bandage"), "Puede fabricar vendaje")
    _expect(inventory.craft("bandage").is_empty(), "Fabricacion transaccional")
    _expect(inventory.get_count("bandage") == 1 and inventory.get_count("cloth") == 63, "Descuenta ingredientes")
    _expect(inventory.add_item("resin", 1).is_empty(), "Encuentra resina")
    _expect(not inventory.discovered_recipes.has("torch"), "Se necesita madera para desbloquear antorcha")
    _expect(inventory.add_item("wood", 1).is_empty(), "Obtiene madera")
    _expect(inventory.discovered_recipes.has("torch"), "Descubre antorcha")
    _expect(inventory.craft("torch").is_empty() and inventory.get_count("torch") == 1, "Fabrica antorcha")
    _expect(inventory.add_item("scrap", 2).is_empty(), "Encuentra chatarra")
    _expect(inventory.discovered_recipes.has("spear"), "Descubre lanza")
    _expect(not inventory.can_craft("spear"), "No fabrica lanza sin madera disponible")
    _expect(inventory.add_item("wood", 1).is_empty(), "Obtiene mas madera")
    _expect(inventory.craft("spear").is_empty(), "Fabrica lanza")
    _expect(inventory.get_count("spear") == 1 and inventory.get_count("scrap") == 0, "Consumo correcto de chatarra")

    var overweight := _new_inventory()
    _expect(overweight.add_item("wood", 42).is_empty(), "Acepta 29.4 kg")
    var before: int = overweight.get_count("wood")
    _expect(not overweight.add_item("wood", 1).is_empty(), "Rechaza pickup si rebasa 30 kg")
    _expect(overweight.get_count("wood") == before, "Pickup fallido no muta inventario")
    _expect(not overweight.add_item("unknown", 1).is_empty(), "Rechaza IDs desconocidos")

    var exact_weight := _new_inventory()
    _expect(exact_weight.add_item("wood", 42).is_empty(), "Acepta madera por debajo del límite")
    _expect(exact_weight.add_item("cloth", 4).is_empty(), "Acepta exactamente 30 kg")
    var exact_slots_before: Array[Dictionary] = exact_weight._copy_slots()
    _expect(not exact_weight.add_item("cloth", 1).is_empty(), "Rechaza peso por encima de 30 kg")
    _expect(is_equal_approx(exact_weight.weight_kg(), 30.0) and exact_weight.slots == exact_slots_before, "Rechazo por peso conserva unidades y peso")

    var full_inventory := _new_inventory()
    _expect(full_inventory.add_item("cloth", 3).is_empty(), "Prepara ingredientes para prueba de mochila llena")
    _expect(full_inventory.add_item("herb", 2).is_empty(), "Desbloquea receta para prueba de mochila llena")
    for slot_index in range(2, InventoryComponent.SLOT_COUNT):
        full_inventory.slots[slot_index] = {"id": "scrap", "quantity": 1}
    var craft_slots_before: Array[Dictionary] = full_inventory._copy_slots()
    var craft_weight_before: float = full_inventory.weight_kg()
    _expect(not full_inventory.craft("bandage").is_empty(), "Rechaza crafting si no cabe el resultado")
    _expect(full_inventory.slots == craft_slots_before and is_equal_approx(full_inventory.weight_kg(), craft_weight_before), "Craft fallido no altera slots, unidades ni peso")

    var phase_before: float = GameClock.phase
    GameClock.advance_minutes(120)
    _expect(is_equal_approx(GameClock.phase, fposmod(phase_before + 120.0 / 1440.0, 1.0)), "Reloj avanza 2 h")

    _expect(ResourceLoader.load("res://scenes/main.tscn") != null, "Main.tscn importable")
    var player_scene: PackedScene = load("res://scenes/player.tscn")
    var camera_player: SurvivorPlayer = player_scene.instantiate() as SurvivorPlayer
    add_child(camera_player)
    await get_tree().physics_frame
    camera_player.first_person = true
    var camera_frames: int = 0
    while camera_player.spring_arm.spring_length > 0.03 and camera_frames < 20:
        await get_tree().physics_frame
        camera_frames += 1
    _expect(camera_player.spring_arm.spring_length <= 0.03 and camera_frames <= 20, "Transición de cámara converge dentro de 20 frames de física")
    camera_player.queue_free()
    print("TOTAL: %d PASS | %d FAIL" % [passed, failed])
    get_tree().quit(0 if failed == 0 else 1)
