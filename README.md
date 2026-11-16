# UMBRAL — Fase 1 / MVP de supervivencia (Godot 4.7.2)

**Proyecto fuente completo para Windows y Linux.** Vertical slice jugable, sin assets de pago ni licencias externas. **No es aún un videojuego final ni incluye monstruos, armas funcionales, streaming de chunks o mapa por zonas: esos sistemas corresponden a la fase 2.**

## 1. Requisitos

- Godot **4.7.2 Standard** (GDScript). Descargar desde <https://godotengine.org/download/archive/4.7.2-stable/>.
- Windows 10/11 o Linux con soporte Vulkan (renderizado **Forward+**).
- Teclado, ratón y GPU integrada moderna o dedicada. No se han medido FPS en hardware real.

## 2. Ejecutar en Windows

1. Descomprime `Umbral_Survival_MVP.zip` en una carpeta sin restricciones, por ejemplo `C:\Proyectos\Umbral_Survival_MVP`.
2. Abre Godot 4.7.2, pulsa **Importar** y selecciona `project.godot`.
3. Espera a que el editor importe los tres archivos `.wav` (solo la primera apertura).
4. Abre `scenes/main.tscn` o pulsa **F6** si tienes la escena abierta; pulsa **F5** para iniciar el proyecto principal.
5. Si el ratón está capturado, pulsa **Esc** para liberarlo y haz clic en la pantalla del juego para retomarlo.
6. Abre **Proyecto > Configuración del proyecto > Renderización** y verifica que el método de renderizado sea **Forward+**. El proyecto incluye la característica `Forward Plus` y no depende de APIs de Compatibility.

## 3. Ejecutar en Linux

1. Instala / extrae Godot 4.7.2 Standard.
2. Abre `project.godot` en el editor y ejecuta con F5.
3. Opcional desde la carpeta del proyecto: `godot --path . --editor` y `godot --path .` (ajusta `godot` al nombre de tu ejecutable).

## 4. Teclas

| Control | Acción |
|---|---|
| WASD | Moverse siguiendo orientación horizontal de cámara |
| Ratón | Mirar / orbitar |
| Shift | Correr (solo hacia delante y sin agacharse) |
| Ctrl | Agacharse (mantener) |
| Espacio | Saltar |
| V | Cambiar primera / tercera persona |
| E | Recoger el objeto al que apunta la mira |
| F | Encender / apagar linterna con consumo de batería |
| Tab | Abrir/cerrar inventario y crafting |
| N | Adelantar 2 horas del reloj, SOLO atajo QA |
| Esc | Liberar ratón / cerrar inventario |
| F1 | Ayuda contextual y opciones de sensibilidad, inversión Y y FOV |

## 5. Probar la Fase 1

1. **Movimiento:** camina/corre, salta y agáchate bajo el pasadizo marcado `PASO BAJO / CTRL`, junto al refugio. Bajo ese obstáculo, el personaje no debería incorporarse si hay colisión sobre la cabeza.
2. **Cambio de cámara:** pulsa `V` y verifica el cambio suave, sin cambiar la dirección de movimiento. Camina con la pared detrás de la cámara para comprobar el acortamiento de brazo con colisión.
3. **Recogida:** mira los objetos de tela, hierbas, madera, chatarra o pilas hasta ver `[E] RECOGER...`; pulsa `E` y comprueba que desaparecen y aumenta el inventario.
4. **Peso máximo:** intenta recoger `Madera x45` (31,5 kg) incluso con la mochila vacía: aparecerá `Demasiado peso`, y el objeto seguirá en el suelo.
5. **Apilamiento:** 64 unidades por pila; la 65.ª comienza otra casilla si hay espacio y peso disponibles.
6. **Recetas ocultas:** con mochila vacía no hay recetas visibles. Consigue **Tela** y **Hierbas** para desbloquear **Vendaje**; **Madera** y **Resina** para **Antorcha**; **Madera** y **Chatarra** para **Lanza improvisada**.
7. **Crafting:** pulsa `Tab`, haz clic en la receta y verifica que consume ingredientes y genera el producto; si faltan ingredientes, el botón estará inhabilitado.
8. **Uso de objetos:** clic sobre `Vendaje` para recuperar hasta 30 HP, `Pila` para recargar 35 puntos, `Antorcha` para iluminar o `Lanza improvisada` para equiparla visualmente (sin combate todavía).
9. **Día y noche:** espera 10 minutos reales para un ciclo completo o pulsa `N` cuatro o cinco veces. Observa cambio en luz ambiental y HUD.
10. **Linterna:** usa `F` de noche, mira el medidor de batería, gasta una pila y verifica que aumenta sin superar 100.

**Nota:** la batería comienza al 100% y baja 0,30 unidades por segundo (aproximadamente 5 min 33 s encendida desde el 100%). El objetivo es comprobar drenaje y recarga en el MVP, no balance final.

## 6. Tests automatizados (Godot)

Desde la raíz del proyecto, después de importar assets:

```powershell
# PowerShell (Windows; ajusta ruta al ejecutable)
& "C:\Ruta\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import
& "C:\Ruta\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/inventory_tests.tscn
& "C:\Ruta\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://scenes/main.tscn --quit-after 180
```

```bash
# Linux
godot --headless --path . --import
godot --headless --path . res://tests/inventory_tests.tscn
godot --headless --path . res://scenes/main.tscn --quit-after 180
```

El test imprime líneas `PASS` y un resumen, y retorna código 0 si todas pasan, o 1 si alguna falla. Casos: InputMap, JSON, 20 slots, pilas 64/65, peso menor/exacto/excedido, descubrimiento, materiales, crafting y rollback ante mochila llena, reloj, carga de escena e interpolación de cámara en física. Para el recorrido interactivo inyectado y las métricas renderizadas, ejecuta además la prueba de Misión 02 de abajo.

### Prueba interactiva instrumentada (Misión 02)

Ejecuta con renderizado normal, sin `--headless`, porque mide FPS reales de la escena:

```powershell
& "C:\Ruta\Godot_v4.7.2-stable_win64_console.exe" --path . res://tests/interactive_tests.tscn
```

La suite inyecta teclado y ratón dentro de Godot, ejecuta recogida/crafting/linterna, mide cámara y promedia FPS durante 10 segundos. Genera `tests/artifacts/umbral_mission02.png` a 1920×1080. Última salida en la RTX 4060 Laptop: 26 PASS, cámara 187.350 ms, 137.59 FPS promedio. La medición variará con hardware y carga.

### Misión 03: comparativa visual y rendimiento

La escena rediseñada añade ayuda contextual con `F1`, el taller/estación y acceso vial, un vehículo y radio como hitos, vegetación agrupada, objetos reconocibles y opciones locales de cámara. Las capturas PRE/POST y los resultados completos están en [`docs/QA_FASE1.md`](docs/QA_FASE1.md). Para regenerar las capturas POST, ejecuta la escena `res://tests/mission03_visual_capture.tscn` con renderer visible. La suite E2E también informa promedio, p95 y p99 durante movimiento con linterna y mide 10 alternancias de cámara.

## 7. Estructura de archivos

```text
Umbral_Survival_MVP/
├── project.godot
├── scenes/
│   ├── main.tscn
│   ├── player.tscn
│   ├── hud.tscn
│   ├── world.tscn
│   └── world_pickup.tscn
├── scripts/
│   ├── input_bootstrap.gd
│   ├── item_database.gd
│   ├── game_clock.gd
│   ├── inventory_component.gd
│   ├── player_controller.gd
│   ├── world_pickup.gd
│   ├── world_prototype.gd
│   └── hud.gd
├── resources/
│   ├── items.json
│   └── recipes.json
├── audio/
│   ├── pickup.wav
│   ├── craft.wav
│   └── error.wav
├── tests/
│   ├── inventory_tests.tscn
│   ├── test_inventory.gd
│   ├── interactive_tests.tscn
│   ├── test_interactive.gd
│   └── artifacts/umbral_mission02.png
└── docs/
    └── arquitectura.md
```

## 8. Estado QA de entrega

La evidencia y los bloqueos restantes están en [`docs/QA_FASE1.md`](docs/QA_FASE1.md). En esta máquina, Godot 4.7.2 Standard midió 187.350 ms de transición y 137.59 FPS promedio renderizado durante 10 s. Las métricas representan Windows x86_64 y una RTX 4060 Laptop; no garantizan los mismos resultados en otros equipos.

