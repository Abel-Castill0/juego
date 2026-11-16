extends Node
## Reloj global: la UI no modifica el tiempo ni conduce el ciclo solar.
signal time_changed(phase: float, hour_text: String, night: bool)

const CYCLE_SECONDS: float = 600.0
var phase: float = 0.42  # Inicio ~10:05, con 0.0 = medianoche.
var paused: bool = false
var _emit_accumulator: float = 0.0

func _ready() -> void:
    call_deferred("_broadcast")

func _process(delta: float) -> void:
    if paused:
        return
    phase = fposmod(phase + delta / CYCLE_SECONDS, 1.0)
    _emit_accumulator += delta
    if _emit_accumulator >= 0.15:
        _emit_accumulator = 0.0
        _broadcast()

func is_night() -> bool:
    return phase < 0.25 or phase >= 0.75

func format_time() -> String:
    var total_minutes: int = int(floor(phase * 1440.0))
    return "%02d:%02d" % [total_minutes / 60, total_minutes % 60]

func advance_minutes(minutes: float) -> void:
    phase = fposmod(phase + minutes / 1440.0, 1.0)
    _broadcast()

func _broadcast() -> void:
    time_changed.emit(phase, format_time(), is_night())
