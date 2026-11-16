# QA de Fase 1 — UMBRAL

## Entorno

- Windows x86_64, Godot **4.7.2.stable.official.ed1daf0bf**, Standard (GDScript), descargado desde el [archivo oficial de Godot](https://godotengine.org/download/archive/4.7.2-stable/).
- Rama local: `fix/umbral-mvp-fase1-qa`; proyecto Forward+.
- Prueba renderizada con Vulkan 1.4.341 en NVIDIA GeForce RTX 4060 Laptop GPU.

## Cambios de Misión 02

- `scripts/player_controller.gd`: al alternar cámara registra `Time.get_ticks_usec()` y publica/imprime la duración cuando `SpringArm3D.spring_length` alcanza el destino.
- `scripts/world_prototype.gd`: carteles usan billboard, escala positiva y tamaño reducido; el cartel del patio se movió al lado izquierdo y por encima del muro. La iluminación ambiental mínima nocturna subió de 0.10 a 0.18.
- `scripts/world_pickup.gd`: reduje fuente y escala de los rótulos que se recortaban en el borde derecho.
- `tests/test_interactive.gd` y `tests/interactive_tests.tscn`: nueva suite renderizada con eventos inyectados, flujo E2E, captura en `RenderingServer.frame_post_draw` y medición de 10 s de FPS.
- `tests/test_inventory.gd`: conserva la regresión de Misión 01 para peso límite y rollback transaccional.
- `README.md`: añadí el comando de prueba interactiva, métricas de referencia y ruta de captura.

## Evidencia

| Verificación | Resultado | Evidencia |
|---|---|---|
| Versión real | PASS | Godot `4.7.2.stable.official.ed1daf0bf` |
| Importación | PASS | `--headless --path . --import`, código 0; sin errores de script ni de carga |
| Suite original | PASS | `--headless --path . res://tests/inventory_tests.tscn`: **39 PASS, 0 FAIL**, código 0 |
| Arranque original | PASS | `--headless --path . res://scenes/main.tscn --quit-after 180`, código 0, sin errores |
| Test unitario de acción | PASS | `Input.is_action_pressed()` confirma W/A/S/D con `InputEventKey` inyectados desde GDScript |
| Prueba de entrada inyectada | PASS | `Input.parse_input_event()` verifica desplazamiento W, cámara V, inventario Tab, pickup E y linterna F; también inyecta movimiento de ratón y clic izquierdo sobre receta |
| E2E del jugador | PASS | **26 PASS, 0 FAIL**, código 0. W mueve; E recoge tela y hierba, elimina cada pickup y actualiza cantidades; Tab abre; clic fabrica Vendaje; Tab cierra; F enciende y se verifica drenaje de batería |
| Transición renderizada de cámara | PASS | Medición monotónica **187.350 ms**, por debajo del límite de 300 ms |
| FPS promedio | PASS | **137.59 FPS** promedio durante 10 segundos de movimiento; 97 muestras con `Performance.TIME_FPS` en la ventana renderizada 1920×1080 |
| Auditoría visual nocturna | PASS | Captura revisada: cartel del patio completo, no invertido y dentro del encuadre; rótulo de pickup derecho contenido; escenario visible sin linterna |
| Foco/controles físicos manuales | **BLOCKED** | Los eventos de motor se probaron inyectados. No se hizo recorrido con periféricos físicos; la prueba automatizada no acredita sensación/foco manual de ratón |
| FPS en otros equipos | **BLOCKED** | La única medición corresponde a la RTX 4060 Laptop disponible; no representa otros equipos/GPU |

### Salida de referencia de la prueba interactiva

```text
CAMERA_TRANSITION_MS: 187.350
PASS: Test unitario de acción: W -> move_forward
PASS: Test unitario de acción: A -> move_left
PASS: Test unitario de acción: S -> move_backward
PASS: Test unitario de acción: D -> move_right
PASS: Prueba E2E: E aumenta inventario
PASS: Prueba de entrada inyectada: clic fabrica vendaje
PASS: Prueba E2E: batería drena con linterna encendida
PASS: Cartel del patio proyectado dentro del encuadre
PASS: Captura renderizada guardada (1920x1080)
FPS_AVERAGE_10S: 137.59
TOTAL_INTERACTIVE: 26 PASS | 0 FAIL
INTERACTIVE_EXIT=0
```

Captura producida en el test mediante `RenderingServer.frame_post_draw`: [tests/artifacts/umbral_mission02.png](../tests/artifacts/umbral_mission02.png). El viewport entregó 1920×1079 por el alto de ventana disponible; el test ajustó la salida PNG a 1920×1080.

## Verificaciones que siguen pendientes

1. Probar con periféricos físicos si se requiere validar el ratón real y el foco percibido de UI.
2. Medir FPS en los equipos objetivo adicionales antes de fijar una garantía de rendimiento.

## Alcance

Se conserva Fase 1. No se implementaron enemigos, combate, mapa multi-zona, chunks, streaming, floating origin, guardado mundial, HLOD ni AnimationTree.
