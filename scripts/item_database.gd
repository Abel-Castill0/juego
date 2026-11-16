extends Node
## Datos separados del código: todo el loot y el crafting se cargan desde JSON.

const ITEMS_PATH := "res://resources/items.json"
const RECIPES_PATH := "res://resources/recipes.json"

var _items: Dictionary = {}
var _recipes: Array = []

func _ready() -> void:
    var item_data: Variant = _read_json(ITEMS_PATH)
    if item_data is Dictionary:
        _items = item_data
    var recipe_data: Variant = _read_json(RECIPES_PATH)
    if recipe_data is Array:
        _recipes = recipe_data
    for recipe in _recipes:
        if not recipe is Dictionary:
            push_error("Receta invalida: se esperaba Dictionary")
            continue
        if not _items.has(str(recipe.get("output", ""))):
            push_error("Salida de receta desconocida: " + str(recipe.get("id", "")))
        for ingredient_id in recipe.get("ingredients", {}).keys():
            if not _items.has(str(ingredient_id)):
                push_error("Ingrediente desconocido: " + str(ingredient_id))

func _read_json(path: String) -> Variant:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("No se pudo abrir: " + path)
        return null
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed == null:
        push_error("JSON invalido: " + path)
    return parsed

func get_item(item_id: String) -> Dictionary:
    return _items.get(item_id, {})

func get_recipes() -> Array:
    return _recipes

func get_recipe(recipe_id: String) -> Dictionary:
    for recipe in _recipes:
        if str(recipe.get("id", "")) == recipe_id:
            return recipe
    return {}

func label_of(item_id: String) -> String:
    return str(get_item(item_id).get("name", item_id))
