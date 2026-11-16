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

Se conserva Fase 1. No se implementaron enemigos, combate, mapa multi-zona, chunks, streaming, floating origin, guardado mundial ni HLOD.

## Misión 03 — Rediseño visual, game feel y UX/UI

### Resultados verificados (Godot 4.7.2 Standard, RTX 4060 Laptop)

| Verificación | Estado | Evidencia |
|---|---|---|
| Importación | PASS | `--headless --path . --import`; finalizó sin errores ni warnings de script |
| Suite original de inventario | PASS | `inventory_tests.tscn`: **39 PASS, 0 FAIL** |
| Suite E2E previa + regresiones M03 | PASS | `interactive_tests.tscn`: **32 PASS, 0 FAIL**; conserva las 26 verificaciones E2E existentes y añade seis comprobaciones M03 |
| Arranque de escena principal | PASS | `--headless --path . res://scenes/main.tscn --quit-after 180`; sin salida de error |
| Inyección y flujo E2E | PASS | `Input.parse_input_event`: W/A/S/D, W mueve, V alterna cámara, E recoge, Tab abre, clic fabrica vendaje, F enciende linterna y drena batería |
| Alternancias de cámara | PASS | 10 alternancias automatizadas completadas; mediciones observadas entre **179.790 y 194.392 ms** (<300 ms) |
| FPS después | PASS | 10 s de movimiento nocturno con linterna activa y alternancias de cámara cada segundo: promedio **141.22 FPS**, p95 **144 FPS**, p99 **144 FPS** (97 muestras, RTX 4060 Laptop; límite observado de 144 FPS) |
| FPS antes p95/p99 | BLOCKED | El registro de Misión 02 solo conservó promedio **137.59 FPS**; no hay muestras crudas para calcular percentiles retrospectivos |
| Hardware iGPU | BLOCKED | No hay GPU integrada de referencia disponible en este entorno |
| Revisión humana de game feel y onboarding <90 s | BLOCKED | La automatización comprueba entradas/estado; no mide percepción de control ni tiempo de aprendizaje de una persona |
| Proporciones humanas / rig | BLOCKED parcial | El modelo sustituto low-poly tiene silueta, chaqueta, cargo, botas y mochila, pero sigue construido con piezas paramétricas. No hay `Skeleton3D` ni rig importado; la animación procedural de extremidades se mezcla mediante `AnimationTree`/`BlendSpace2D`. El criterio humano a 10 m y ausencia de foot sliding requieren revisión visual humana. |
| Audio ambiental y aterrizaje | BLOCKED | Se conservaron sonidos de pickup/crafting/error; no se añadieron ni midieron viento, pasos o feedback de aterrizaje. |
| Capturas PRE/POST | PASS | Cuatro pares 1920×1080 guardados bajo `tests/artifacts/mission03/{before,after}/`; captura posterior generada en renderer Vulkan mediante `RenderingServer.frame_post_draw` |

### Capturas comparativas

| Plano | PRE | POST |
|---|---|---|
| Patio diurno | ![Patio antes](../tests/artifacts/mission03/before/patio_day.png) | ![Patio después](../tests/artifacts/mission03/after/patio_day.png) |
| Refugio | ![Refugio antes](../tests/artifacts/mission03/before/shelter_overview.png) | ![Refugio después](../tests/artifacts/mission03/after/shelter_overview.png) |
| Inventario | ![Inventario antes](../tests/artifacts/mission03/before/inventory.png) | ![Inventario después](../tests/artifacts/mission03/after/inventory.png) |
| Noche | ![Noche antes](../tests/artifacts/mission03/before/night.png) | ![Noche después](../tests/artifacts/mission03/after/night.png) |

### Cambios M03

- Superviviente geométrico low-poly con ropa diferenciada y movimiento alternado de brazos/piernas; `AnimationPlayer`, `AnimationTree` y `BlendSpace2D` activos.
- Escena de Fase 1 ampliada con taller/estación, acceso vial, vehículo abandonado, señal de salida, radio y vegetación por grupos MultiMesh con visibilidad limitada. Pickups usan siluetas diferentes para tela, hierbas, madera, chatarra y pilas.
- Luz ambiental nocturna ligeramente elevada, niebla reducida, F1 abre ayuda contextual y el inventario presenta iconos, ordenación y estado de recetas. Sensibilidad, inversión Y y FOV se pueden ajustar desde la ayuda y guardan en `user://settings.cfg`.
- La animación de locomoción se genera localmente. No se añadió esqueleto deformable/Skeleton3D; los rótulos de pickup siguen usando texto 3D, y no se añadieron pasos ni viento.
- Procedencia: [docs/ASSET_PROVENANCE.md](ASSET_PROVENANCE.md). No hay assets externos.
