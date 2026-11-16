extends Node
## Registro de acciones físicas: funciona con teclados QWERTY y AZERTY al usar physical_keycode.
## Las acciones se dan de alta una sola vez y pueden remapearse más adelante.

const BINDINGS: Dictionary = {
    "move_forward": KEY_W,
    "move_backward": KEY_S,
    "move_left": KEY_A,
    "move_right": KEY_D,
    "sprint": KEY_SHIFT,
    "crouch": KEY_CTRL,
    "jump": KEY_SPACE,
    "interact": KEY_E,
    "camera_toggle": KEY_V,
    "inventory_toggle": KEY_TAB,
    "flashlight_toggle": KEY_F,
    "skip_time_debug": KEY_N,
}

func _enter_tree() -> void:
    for action in BINDINGS.keys():
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        var key_event := InputEventKey.new()
        key_event.physical_keycode = int(BINDINGS[action])
        InputMap.action_add_event(action, key_event)
