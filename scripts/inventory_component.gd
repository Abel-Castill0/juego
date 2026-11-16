class_name InventoryComponent
extends Node
## Inventario de 20 casillas con operaciones transaccionales.
## El fallo por peso/espacio nunca consume el pickup ni materiales.

signal changed
signal recipe_discovered(recipe_id: String)

const SLOT_COUNT: int = 20
const WEIGHT_LIMIT_KG: float = 30.0

var slots: Array[Dictionary] = []
var discovered_materials: Dictionary = {}
var discovered_recipes: Dictionary = {}

func _ready() -> void:
    for _i in range(SLOT_COUNT):
        slots.append({})

func weight_kg() -> float:
    return _weight_of(slots)

func _weight_of(source: Array[Dictionary]) -> float:
    var result: float = 0.0
    for slot in source:
        if slot.is_empty():
            continue
        result += float(ItemDB.get_item(str(slot["id"])).get("weight_kg", 0.0)) * int(slot["quantity"])
    return result

func _copy_slots() -> Array[Dictionary]:
    var duplicate_slots: Array[Dictionary] = []
    for slot in slots:
        duplicate_slots.append(slot.duplicate(true))
    return duplicate_slots

func _try_insert(target: Array[Dictionary], item_id: String, quantity: int) -> bool:
    var item: Dictionary = ItemDB.get_item(item_id)
    if item.is_empty() or quantity <= 0:
        return false
    var max_stack: int = mini(int(item.get("max_stack", 64)), 64)
    var remaining: int = quantity
    for index in range(target.size()):
        if remaining == 0:
            break
        if target[index].is_empty() or target[index].get("id", "") != item_id:
            continue
        var available: int = max_stack - int(target[index]["quantity"])
        var transfer: int = mini(maxi(available, 0), remaining)
        target[index]["quantity"] = int(target[index]["quantity"]) + transfer
        remaining -= transfer
    for index in range(target.size()):
        if remaining == 0:
            break
        if not target[index].is_empty():
            continue
        var transfer: int = mini(max_stack, remaining)
        target[index] = {"id": item_id, "quantity": transfer}
        remaining -= transfer
    return remaining == 0

func add_item(item_id: String, quantity: int) -> String:
    var item: Dictionary = ItemDB.get_item(item_id)
    if item.is_empty() or quantity <= 0:
        return "Objeto o cantidad invalida"
    var proposed_weight: float = weight_kg() + float(item.get("weight_kg", 0.0)) * quantity
    if proposed_weight > WEIGHT_LIMIT_KG + 0.0001:
        return "Demasiado peso: %.1f / %.1f kg" % [proposed_weight, WEIGHT_LIMIT_KG]
    var simulated: Array[Dictionary] = _copy_slots()
    if not _try_insert(simulated, item_id, quantity):
        return "Inventario lleno (20 casillas)"
    slots = simulated
    _record_discovery(item_id)
    changed.emit()
    return ""

func _record_discovery(item_id: String) -> void:
    discovered_materials[item_id] = true
    for recipe in ItemDB.get_recipes():
        var recipe_id: String = str(recipe.get("id", ""))
        if discovered_recipes.has(recipe_id):
            continue
        var all_discovered: bool = true
        for required_id in recipe.get("ingredients", {}).keys():
            if not discovered_materials.has(str(required_id)):
                all_discovered = false
                break
        if all_discovered:
            discovered_recipes[recipe_id] = true
            recipe_discovered.emit(recipe_id)

func get_count(item_id: String) -> int:
    var count: int = 0
    for slot in slots:
        if slot.get("id", "") == item_id:
            count += int(slot["quantity"])
    return count

func consume(item_id: String, quantity: int = 1) -> bool:
    if quantity <= 0 or get_count(item_id) < quantity:
        return false
    var simulated: Array[Dictionary] = _copy_slots()
    _remove_from(simulated, item_id, quantity)
    slots = simulated
    changed.emit()
    return true

func _remove_from(target: Array[Dictionary], item_id: String, quantity: int) -> void:
    var left: int = quantity
    for index in range(target.size()):
        if left == 0:
            break
        if target[index].get("id", "") != item_id:
            continue
        var removed: int = mini(int(target[index]["quantity"]), left)
        target[index]["quantity"] = int(target[index]["quantity"]) - removed
        left -= removed
        if int(target[index]["quantity"]) == 0:
            target[index] = {}

func can_craft(recipe_id: String) -> bool:
    return craft_error(recipe_id).is_empty()

func craft_error(recipe_id: String) -> String:
    var recipe: Dictionary = ItemDB.get_recipe(recipe_id)
    if recipe.is_empty() or not discovered_recipes.has(recipe_id):
        return "Receta sin descubrir"
    var ingredients: Dictionary = recipe.get("ingredients", {})
    for item_id in ingredients.keys():
        if get_count(str(item_id)) < int(ingredients[item_id]):
            return "Faltan materiales: " + ItemDB.label_of(str(item_id))
    var simulated: Array[Dictionary] = _copy_slots()
    for item_id in ingredients.keys():
        _remove_from(simulated, str(item_id), int(ingredients[item_id]))
    var output_id: String = str(recipe.get("output", ""))
    var output_quantity: int = int(recipe.get("quantity", 1))
    var output_weight: float = float(ItemDB.get_item(output_id).get("weight_kg", 0.0)) * output_quantity
    if _weight_of(simulated) + output_weight > WEIGHT_LIMIT_KG + 0.0001:
        return "Crafteo excede 30 kg"
    if not _try_insert(simulated, output_id, output_quantity):
        return "Sin casillas para el resultado"
    return ""

func craft(recipe_id: String) -> String:
    var error_text: String = craft_error(recipe_id)
    if not error_text.is_empty():
        return error_text
    var recipe: Dictionary = ItemDB.get_recipe(recipe_id)
    var simulated: Array[Dictionary] = _copy_slots()
    for item_id in recipe["ingredients"].keys():
        _remove_from(simulated, str(item_id), int(recipe["ingredients"][item_id]))
    _try_insert(simulated, str(recipe["output"]), int(recipe.get("quantity", 1)))
    slots = simulated
    _record_discovery(str(recipe["output"]))
    changed.emit()
    return ""
