class_name WorldPickup
extends Area3D
## Objeto interactivo. El jugador confirma capacidad antes de eliminarlo del mundo.

@export var item_id: String = "wood"
@export_range(1, 64, 1) var quantity: int = 1

@onready var visual: Node3D = $Visual

func _ready() -> void:
    var item: Dictionary = ItemDB.get_item(item_id)
    if item.is_empty():
        push_error("Pickup desconocido: " + item_id)
        return
    var model_id := "bottle"
    var model_scale := 0.32
    match item_id:
        "cloth", "bandage": model_id = "bedroll"; model_scale = 0.48
        "herb": model_id = "grass"; model_scale = 0.34
        "wood": model_id = "resource-planks"; model_scale = 0.44
        "resin", "food": model_id = "bottle"; model_scale = 0.3
        "scrap": model_id = "metal-panel-screws"; model_scale = 0.3
        "battery": model_id = "tool-hammer"; model_scale = 0.26
    var model_scene := load("res://assets/third_party/kenney/survival/%s.glb" % model_id) as PackedScene
    if model_scene == null:
        push_error("Pickup sin modelo glTF: " + model_id)
        return
    var model := model_scene.instantiate() as Node3D
    model.name = "PickupModel_" + model_id
    model.scale = Vector3.ONE * model_scale
    model.rotation_degrees.y = 22.0
    visual.add_child(model)
    var label := Label3D.new()
    label.text = "%s  x%d" % [ItemDB.label_of(item_id), quantity]
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 18
    label.pixel_size = 0.002
    label.position = Vector3(0, 0.56, 0)
    label.modulate = Color(0.9, 0.97, 0.97)
    label.outline_size = 10
    visual.add_child(label)

func _process(delta: float) -> void:
    # Solo animación visual; no interviene en la física ni las interacciones.
    visual.rotation.y += delta * 0.65
    visual.position.y = 0.045 + sin(float(Time.get_ticks_msec()) / 450.0) * 0.025
