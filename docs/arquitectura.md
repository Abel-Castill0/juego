# Decisiones de arquitectura — Fase 1

## 1. Cámara híbrida
Un solo `Camera3D` viaja con `SpringArm3D`; no hay dos cámaras que puedan perder sincronización. El pivote concentra yaw/pitch, y la distancia se interpola durante `_physics_process()`.
La colisión del brazo excluye el cuerpo del jugador y evita atravesar paredes con el objetivo en tercera persona.

## 2. Controlador cinemático
`CharacterBody3D.move_and_slide()` lleva desplazamientos de física, salto y agachado. El sistema suaviza velocidad y cabeceo/cámara y verifica espacio libre por encima del jugador antes de incorporarse.
El personaje 3D es placeholder y puede reemplazarse sin modificar movimiento ni inventario.

## 3. Inventario
`InventoryComponent` tiene 20 casillas, 30 kg y pilas de hasta 64. Cada alta o crafteo primero se simula sobre copias de los slots para rechazar una operación completa en vez de perder unidades.
Los materiales descubiertos se registran independientemente de los que quedan en posesión; las recetas se descubren una vez.

## 4. Crafteo y recursos
`ItemDB` carga `resources/items.json` y `resources/recipes.json`. Añadir o equilibrar recetas no exige modificar GDScript.
El coste de los ingredientes y el peso del resultado se comprueban antes de confirmar la transacción.

## 5. Día y noche
`GameClock` es AutoLoad, procesa un reloj continuo de 600 segundos y notifica con `time_changed`. HUD y mundo suscriben la señal por separado; nunca se consultan entre sí.
El modificador de luz y cielo es cosmético, suficiente para comprobar ciclo y consumo de linterna.

## 6. Objetos recogibles
`WorldPickup` conserva ID/cantidad; el jugador apunta con `RayCast3D` y pide al inventario aprobar la recogida antes de llamar a `queue_free`.
Los pickups de escena pueden sustituirse después por prefabs con mallas reales.

## 7. Renderizado
El proyecto usa configuración inicial Forward+ y piezas procedurales pequeñas para acelerar la importación; sombras y niebla básica producen una escena legible de día y noche.
No se anuncian 60 FPS ni ausencia de tirones sin pruebas en hardware objetivo; HLOD/chunks/vegetación avanzada son de fase 2/3.

## 8. Qué no está incluido
No existen enemigos, spawn, mapa multi-zona, combate a distancia, persistencia delta, streaming, IA, AnimationTree, remapeo de controles ni HLOD. Se implementarán solo después de aceptar el núcleo de Fase 1.

## 9. Criterio de salida
MVP aprobado cuando: se importa sin errores en Godot 4.7.2, arranca con F5, se recorren los casos del README, los tests automatizados retornan 0 y la verificación en Windows/Linux confirma que las entradas funcionan.
