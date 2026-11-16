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
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color.from_string(str(item.get("color", "#b9ced2")), Color.WHITE)
    mat.metallic = 0.1
    mat.roughness = 0.58
    mat.emission_enabled = true
    mat.emission = mat.albedo_color * 0.12
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.38, 0.38, 0.38)
    mesh_instance.mesh = mesh
    mesh_instance.material_override = mat
    mesh_instance.rotation_degrees = Vector3(10, 20, 8)
    visual.add_child(mesh_instance)
    var label := Label3D.new()
    label.text = "%s  x%d" % [ItemDB.label_of(item_id), quantity]
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 18
    label.pixel_size = 0.002
    label.position = Vector3(0, 0.68, 0)
    label.modulate = Color(0.9, 0.97, 0.97)
    label.outline_size = 10
    visual.add_child(label)

func _process(delta: float) -> void:
    # Solo animación visual; no interviene en la física ni las interacciones.
    visual.rotation.y += delta * 0.65
    visual.position.y = 0.36 + sin(float(Time.get_ticks_msec()) / 450.0) * 0.06
