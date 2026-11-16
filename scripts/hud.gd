extends CanvasLayer
## HUD e inventario como capa de presentación. No controla inventario ni reloj internamente.

const COLOR_PANEL := Color(0.045, 0.075, 0.093, 0.92)
const COLOR_ACCENT := Color("#80d3bc")
const COLOR_ERROR := Color("#f39b92")
const PICKUP_SOUND: AudioStream = preload("res://audio/mission04/cloth_pickup.mp3")
const CRAFT_SOUND: AudioStream = preload("res://audio/craft.wav")
const ERROR_SOUND: AudioStream = preload("res://audio/error.wav")

var player: SurvivorPlayer
var inventory: InventoryComponent
var root: Control
var inventory_layer: ColorRect
var item_grid: GridContainer
var recipe_list: VBoxContainer
var weight_label: Label
var clock_label: Label
var health_bar: ProgressBar
var battery_bar: ProgressBar
var prompt_label: Label
var toast_label: Label
var hud_weight_label: Label
var inventory_open: bool = false
var _toast_timeout: float = 0.0
var _sfx_player: AudioStreamPlayer
var help_panel: PanelContainer
var _help_visible: bool = false
var _sort_inventory: bool = false
var _sfx_generation: int = 0

func _ready() -> void:
    player = get_parent().get_node("Player") as SurvivorPlayer
    inventory = player.inventory
    _create_hud()
    _create_inventory_layer()
    _sfx_player = AudioStreamPlayer.new()
    add_child(_sfx_player)
    inventory.changed.connect(_on_inventory_changed)
    inventory.recipe_discovered.connect(_on_recipe_discovered)
    player.action_feedback.connect(_on_action_feedback)
    player.pickup_succeeded.connect(_on_pickup_succeeded)
    player.battery_changed.connect(_update_battery)
    player.health_changed.connect(_update_health)
    GameClock.time_changed.connect(_on_clock_changed)
    _update_health(player.health)
    _update_battery(player.battery)
    _on_clock_changed(GameClock.phase, GameClock.format_time(), GameClock.is_night())
    _refresh_inventory()

func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = COLOR_PANEL
    style.corner_radius_top_left = 11
    style.corner_radius_top_right = 11
    style.corner_radius_bottom_left = 11
    style.corner_radius_bottom_right = 11
    style.content_margin_left = 16.0
    style.content_margin_right = 16.0
    style.content_margin_top = 12.0
    style.content_margin_bottom = 12.0
    return style

func _make_label(label_text: String, size: int = 16, tint: Color = Color.WHITE) -> Label:
    var text_label := Label.new()
    text_label.text = label_text
    text_label.add_theme_font_size_override("font_size", size)
    text_label.add_theme_color_override("font_color", tint)
    return text_label

func _create_hud() -> void:
    root = Control.new()
    root.name = "HudRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    var stats := PanelContainer.new()
    stats.name = "Status"
    stats.add_theme_stylebox_override("panel", _panel_style())
    stats.position = Vector2(20, 20)
    stats.custom_minimum_size = Vector2(248, 0)
    root.add_child(stats)
    var rows := VBoxContainer.new()
    rows.add_theme_constant_override("separation", 7)
    stats.add_child(rows)
    rows.add_child(_make_label("UMBRAL     //     SUPERVIVENCIA", 14, COLOR_ACCENT))
    rows.add_child(_make_label("SALUD", 13))
    health_bar = ProgressBar.new()
    health_bar.custom_minimum_size = Vector2(200, 12)
    health_bar.show_percentage = false
    rows.add_child(health_bar)
    rows.add_child(_make_label("BATERIA DE LINTERNA", 13))
    battery_bar = ProgressBar.new()
    battery_bar.custom_minimum_size = Vector2(200, 12)
    battery_bar.show_percentage = false
    rows.add_child(battery_bar)
    hud_weight_label = _make_label("CARGA  0.0 / 30.0 kg", 13, COLOR_ACCENT)
    rows.add_child(hud_weight_label)

    var information := PanelContainer.new()
    information.add_theme_stylebox_override("panel", _panel_style())
    information.anchor_left = 1.0
    information.anchor_right = 1.0
    information.offset_left = -254.0
    information.offset_right = -20.0
    information.offset_top = 20.0
    root.add_child(information)
    var info_box := VBoxContainer.new()
    information.add_child(info_box)
    info_box.add_child(_make_label("CICLO AMBIENTAL", 13, COLOR_ACCENT))
    clock_label = _make_label("10:00 / DIA", 22)
    info_box.add_child(clock_label)
    info_box.add_child(_make_label("10 min = 1 dia", 12))

    var crosshair := _make_label("+", 24, COLOR_ACCENT)
    crosshair.anchor_left = 0.5
    crosshair.anchor_top = 0.5
    crosshair.anchor_right = 0.5
    crosshair.anchor_bottom = 0.5
    crosshair.offset_left = -9.0
    crosshair.offset_top = -18.0
    root.add_child(crosshair)

    prompt_label = _make_label("", 16, Color("#f0e4c8"))
    prompt_label.anchor_left = 0.5
    prompt_label.anchor_right = 0.5
    prompt_label.anchor_top = 0.60
    prompt_label.anchor_bottom = 0.60
    prompt_label.offset_left = -270.0
    prompt_label.offset_right = 270.0
    prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(prompt_label)

    toast_label = _make_label("", 18, COLOR_ACCENT)
    toast_label.anchor_left = 0.5
    toast_label.anchor_right = 0.5
    toast_label.anchor_top = 0.18
    toast_label.anchor_bottom = 0.18
    toast_label.offset_left = -330.0
    toast_label.offset_right = 330.0
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(toast_label)

    var hint := _make_label("F1 AYUDA", 13, Color("#c6d4cb"))
    hint.anchor_left = 0.5; hint.anchor_right = 0.5; hint.anchor_top = 1.0; hint.anchor_bottom = 1.0
    hint.offset_left = -42; hint.offset_right = 42; hint.offset_top = -36; hint.offset_bottom = -12
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(hint)
    help_panel = PanelContainer.new()
    help_panel.visible = false
    help_panel.position = Vector2(20, 238)
    help_panel.add_theme_stylebox_override("panel", _panel_style())
    var help_box := VBoxContainer.new()
    help_box.add_child(_make_label("CONTROLES\nWASD  Mover\nShift  Correr hacia delante\nCtrl  Agacharse  •  Espacio  Saltar\nE  Recoger  •  F  Linterna\nV  Cambiar cámara  •  Tab  Mochila\nEsc  Liberar ratón", 14))
    var options := HBoxContainer.new()
    var sens_down := Button.new(); sens_down.text = "Sens −"; sens_down.pressed.connect(func() -> void: _change_options(-0.0002, 0.0))
    var sens_up := Button.new(); sens_up.text = "Sens +"; sens_up.pressed.connect(func() -> void: _change_options(0.0002, 0.0))
    var invert_button := Button.new(); invert_button.text = "Invertir Y"; invert_button.pressed.connect(func() -> void: _change_invert_y())
    var fov_down := Button.new(); fov_down.text = "FOV −"; fov_down.pressed.connect(func() -> void: _change_options(0.0, -5.0))
    var fov_up := Button.new(); fov_up.text = "FOV +"; fov_up.pressed.connect(func() -> void: _change_options(0.0, 5.0))
    options.add_child(sens_down); options.add_child(sens_up); options.add_child(invert_button); options.add_child(fov_down); options.add_child(fov_up)
    help_box.add_child(options)
    help_panel.add_child(help_box)
    root.add_child(help_panel)

func _create_inventory_layer() -> void:
    inventory_layer = ColorRect.new()
    inventory_layer.name = "InventoryOverlay"
    inventory_layer.color = Color(0.008, 0.022, 0.03, 0.84)
    inventory_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    inventory_layer.mouse_filter = Control.MOUSE_FILTER_STOP
    inventory_layer.visible = false
    add_child(inventory_layer)

    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _panel_style())
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -420.0
    panel.offset_right = 420.0
    panel.offset_top = -290.0
    panel.offset_bottom = 290.0
    inventory_layer.add_child(panel)

    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 15)
    panel.add_child(outer)
    var header := HBoxContainer.new()
    outer.add_child(header)
    header.add_child(_make_label("MOCHILA  //  CAMPAMENTO", 24, COLOR_ACCENT))
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(spacer)
    var close_button := Button.new()
    close_button.text = "CERRAR [TAB]"
    close_button.pressed.connect(func() -> void: _toggle_inventory(false))
    header.add_child(close_button)
    weight_label = _make_label("", 16)
    outer.add_child(weight_label)
    outer.add_child(HSeparator.new())

    var columns := HBoxContainer.new()
    columns.add_theme_constant_override("separation", 18)
    outer.add_child(columns)
    var left := VBoxContainer.new()
    left.add_theme_constant_override("separation", 10)
    columns.add_child(left)
    left.add_child(_make_label("INVENTARIO  •  20 ESPACIOS / PILAS x64", 14, COLOR_ACCENT))
    var sort_button := Button.new(); sort_button.text = "Ordenar por nombre"; sort_button.pressed.connect(func() -> void: _sort_inventory = not _sort_inventory; _refresh_inventory())
    left.add_child(sort_button)
    item_grid = GridContainer.new()
    item_grid.columns = 5
    item_grid.add_theme_constant_override("h_separation", 7)
    item_grid.add_theme_constant_override("v_separation", 7)
    left.add_child(item_grid)
    left.add_child(_make_label("Clic en vendaje/pila para usar; antorcha/lanza para equipar.", 12))
    left.add_child(_make_label("Las recetas se revelan cuando descubres sus materiales.", 12))

    var separator := VSeparator.new()
    columns.add_child(separator)
    var right := VBoxContainer.new()
    right.custom_minimum_size = Vector2(240.0, 0.0)
    columns.add_child(right)
    right.add_child(_make_label("FABRICACION", 18, COLOR_ACCENT))
    recipe_list = VBoxContainer.new()
    recipe_list.add_theme_constant_override("separation", 9)
    right.add_child(recipe_list)
    var bottom := _make_label("ESC libera el raton  •  clic en pantalla para volver a mirar", 12)
    outer.add_child(bottom)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
        _help_visible = not _help_visible
        help_panel.visible = _help_visible and not inventory_open
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("inventory_toggle"):
        _toggle_inventory(not inventory_open)
        get_viewport().set_input_as_handled()
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        if inventory_open:
            _toggle_inventory(false)
        else:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.pressed and not inventory_open and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _toggle_inventory(opened: bool) -> void:
    inventory_open = opened
    inventory_layer.visible = opened
    help_panel.visible = _help_visible and not opened
    player.set_ui_open(opened)
    if opened:
        _refresh_inventory()

func _change_options(sensitivity_delta: float, fov_delta: float) -> void:
    player.save_control_options(player.mouse_sensitivity + sensitivity_delta, player.invert_mouse_y, player.camera_fov + fov_delta)

func _change_invert_y() -> void:
    player.save_control_options(player.mouse_sensitivity, not player.invert_mouse_y, player.camera_fov)

func _on_inventory_changed() -> void:
    _refresh_inventory()

func _on_recipe_discovered(recipe_id: String) -> void:
    var recipe: Dictionary = ItemDB.get_recipe(recipe_id)
    # Diferido para que el aviso de pickup no pise el descubrimiento.
    call_deferred("_show_toast", "NUEVA RECETA: " + str(recipe.get("name", recipe_id)), false)
    _refresh_inventory()

func _refresh_inventory() -> void:
    if inventory == null or item_grid == null:
        return
    var weight: float = inventory.weight_kg()
    weight_label.text = "CARGA: %.2f / %.2f kg" % [weight, InventoryComponent.WEIGHT_LIMIT_KG]
    hud_weight_label.text = "CARGA  %.1f / 30.0 kg" % weight
    weight_label.add_theme_color_override("font_color", COLOR_ERROR if weight >= 28.0 else COLOR_ACCENT)
    for child in item_grid.get_children():
        child.queue_free()
    var display_slots: Array = inventory.slots.duplicate(true)
    if _sort_inventory:
        display_slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            if a.is_empty(): return false
            if b.is_empty(): return true
            return ItemDB.label_of(str(a["id"])) < ItemDB.label_of(str(b["id"]))
        )
    for slot_index in range(InventoryComponent.SLOT_COUNT):
        var slot: Dictionary = display_slots[slot_index]
        var button := Button.new()
        button.custom_minimum_size = Vector2(105, 72)
        button.add_theme_font_size_override("font_size", 12)
        if slot.is_empty():
            button.text = "—"
            button.disabled = true
        else:
            var item_id: String = str(slot["id"])
            var item: Dictionary = ItemDB.get_item(item_id)
            var glyphs := {"cloth":"▤", "herb":"✿", "wood":"▰", "resin":"◆", "scrap":"⚙", "battery":"▣", "food":"◉", "bandage":"✚", "torch":"♨", "spear":"⌁"}
            button.text = "%s  %s\nx%d" % [str(glyphs.get(item_id, "•")), str(item.get("name", item_id)), int(slot["quantity"])]
            button.tooltip_text = "%s\n%.2f kg/unid.\n%s" % [str(item.get("name", item_id)), float(item.get("weight_kg", 0.0)), str(item.get("description", ""))]
            button.pressed.connect(_on_item_clicked.bind(item_id))
        item_grid.add_child(button)
    for child in recipe_list.get_children():
        child.queue_free()
    var seen: int = 0
    for recipe in ItemDB.get_recipes():
        if not inventory.discovered_recipes.has(str(recipe["id"])):
            continue
        seen += 1
        var ingredients: PackedStringArray = []
        for item_id in recipe["ingredients"].keys():
            ingredients.append("%s x%d" % [ItemDB.label_of(str(item_id)), int(recipe["ingredients"][item_id])])
        var recipe_button := Button.new()
        recipe_button.text = "%s%s\n%s" % [str(recipe["name"]), "  ✓" if inventory.can_craft(str(recipe["id"])) else "  ○", "  •  ".join(ingredients)]
        recipe_button.custom_minimum_size = Vector2(230, 65)
        recipe_button.disabled = not inventory.can_craft(str(recipe["id"]))
        recipe_button.tooltip_text = "Fabricar: " + str(recipe["name"]) if not recipe_button.disabled else inventory.craft_error(str(recipe["id"]))
        recipe_button.pressed.connect(_on_craft_clicked.bind(str(recipe["id"])))
        recipe_list.add_child(recipe_button)
    if seen == 0:
        recipe_list.add_child(_make_label("No hay recetas descubiertas.\nBusca tela, hierbas, madera,\nresina y chatarra.", 14))

func _on_item_clicked(item_id: String) -> void:
    var message: String = player.use_inventory_item(item_id)
    var failed: bool = message.begins_with("Objeto") or message.begins_with("Salud maxima") or message.begins_with("La bateria")
    _show_toast(message, failed)
    _play_sound(ERROR_SOUND if failed else PICKUP_SOUND, 0.48 if not failed else -1.0)

func _on_craft_clicked(recipe_id: String) -> void:
    var result: String = inventory.craft(recipe_id)
    var is_error: bool = not result.is_empty()
    var message: String = result if is_error else "FABRICADO: " + str(ItemDB.get_recipe(recipe_id).get("name", recipe_id))
    _show_toast(message, is_error)
    _play_sound(ERROR_SOUND if is_error else CRAFT_SOUND)

func _on_pickup_succeeded(_item_id: String, _quantity: int) -> void:
    _play_sound(PICKUP_SOUND, 0.48)

func _play_sound(stream: AudioStream, stop_after_seconds: float = -1.0) -> void:
    if _sfx_player == null:
        return
    _sfx_generation += 1
    var generation := _sfx_generation
    _sfx_player.stop()
    _sfx_player.stream = stream
    _sfx_player.play()
    if stop_after_seconds > 0.0:
        _stop_sfx_after(generation, stop_after_seconds)

func _stop_sfx_after(generation: int, delay: float) -> void:
    await get_tree().create_timer(delay).timeout
    if generation == _sfx_generation and _sfx_player != null:
        _sfx_player.stop()

func _on_action_feedback(message: String, is_error: bool) -> void:
    _show_toast(message, is_error)
    if is_error:
        _play_sound(ERROR_SOUND)

func _show_toast(message: String, is_error: bool) -> void:
    toast_label.text = message
    toast_label.add_theme_color_override("font_color", COLOR_ERROR if is_error else COLOR_ACCENT)
    _toast_timeout = 2.7

func _update_battery(value: float) -> void:
    battery_bar.value = value

func _update_health(value: float) -> void:
    health_bar.value = value

func _on_clock_changed(_phase: float, formatted_time: String, is_night: bool) -> void:
    clock_label.text = "%s  /  %s" % [formatted_time, "NOCHE" if is_night else "DIA"]

func _process(delta: float) -> void:
    # Refresco estrictamente visual: retícula, pistas y mensajes.
    if _toast_timeout > 0.0:
        _toast_timeout -= delta
        if _toast_timeout <= 0.0:
            toast_label.text = ""
    if inventory_open or player == null:
        prompt_label.text = ""
        return
    var focused: WorldPickup = player.get_focused_pickup()
    prompt_label.text = "[E] RECOGER %s  x%d" % [ItemDB.label_of(focused.item_id), focused.quantity] if focused != null else ""
