# Misión Codex 01 — Reparar, validar y cerrar el MVP de UMBRAL (Godot 4.7.2)

## GOAL (objetivo único)
Llevar el proyecto UMBRAL de "código fuente generado sin ejecutar" a **MVP de Fase 1 verificado**: importa, arranca, los tests pasan, las invariantes de inventario/crafting se cumplen y la evidencia queda documentada.

## CONTEXT (leer antes de tocar nada)
1. `AGENTS.md` (raíz) — reglas permanentes del repo.
2. `project.godot`, `README.md`, `docs/arquitectura.md`.
3. Escenas: `scenes/main.tscn`, `player.tscn`, `world.tscn`, `hud.tscn`, `world_pickup.tscn`.
4. Scripts: `scripts/player_controller.gd`, `inventory_component.gd`, `item_database.gd`, `input_bootstrap.gd`, `game_clock.gd`, `world_pickup.gd`, `world_prototype.gd`, `hud.gd`.
5. Recursos y tests: `resources/items.json`, `resources/recipes.json`, `tests/inventory_tests.tscn`, `tests/test_inventory.gd`.

**Primera acción obligatoria:** verifica la versión real con `godot --version`. Si no es 4.7.x, busca e instala 4.7.2 Standard desde la fuente oficial antes de continuar.

## CONSTRAINTS (límites duros)
- **Alcance estricto Fase 1.** NO implementar: enemigos, IA, combate real, mapa multi-zona, chunks, floating origin, guardado mundial, HLOD, AnimationTree nuevo.
- **Conserva el comportamiento existente.** Si hay Git, crea rama `fix/umbral-mvp-fase1-qa`; no `reset --hard` ni borres trabajo. Si no hay Git, inicializa repo local.
- **No declares PASS sin evidencia.** Si no puedes operar GUI o medir GPU, marca esa métrica como `BLOCKED`, nunca `PASS`.
- **Un exit code 0 en Godot headless no es prueba de éxito.** Revisa siempre stdout/stderr[reference:8].

## VALIDATION SPECS (qué debe cumplirse para cerrar)
Ejecuta el bucle **Review → Repair → Validate** hasta que todos los ítems aplicables estén en PASS o BLOCKED justificado[reference:9].

### A. Importación y parseo
- [ ] `godot --headless --path . --import` termina sin `SCRIPT ERROR` ni fallos de carga.
- [ ] Arranque de `main.tscn` headless (`--quit-after`) sin errores de nodo/señal.

### B. Jugador y cámara
- [ ] WASD relativo a cámara, Shift, Ctrl, Space, V funcionan en ejecución.
- [ ] Transición 1ª/3ª persona **medida** con `Time.get_ticks_usec()` o método equivalente; resultado < 300 ms documentado.
- [ ] Cámara en 3ª persona no atraviesa paredes; dirección de movimiento no se invierte al cambiar.

### C. Inventario y crafting (invariantes)
- [ ] 20 slots, 30 kg, stacks 64/65, mochila llena, peso exacto y excedido.
- [ ] Rollback completo: recogida/craft fallido **no altera** unidades, peso ni el pickup en el suelo.
- [ ] 3 recetas ocultas hasta descubrir todos sus materiales; crafting atómico.
- [ ] Tests automatizados con resumen PASS/FAIL y exit code correcto (0 = todo pasó, >0 = falló).

### D. Día/noche y linterna
- [ ] `GameClock` AutoLoad activo; ciclo de 600 s verificable sin esperar 10 min reales (delta controlado).
- [ ] Linterna F: encendido, drenaje, recarga con pila, tope 100.

### E. UI y foco
- [ ] Tab/Esc abren/cierran inventario; el ratón se libera/captura correctamente.
- [ ] Botones del HUD se regeneran sin errores ni pérdida de foco.

### F. Documentación
- [ ] `README.md` actualizado: instalación Win/Linux, controles, comandos exactos de tests, limitaciones.
- [ ] `docs/QA_FASE1.md` creado: entorno/versión, bugs con archivo:línea, corrección, tabla PASS/FAIL/BLOCKED con evidencia, comandos y códigos de salida, métricas reales.

## FORMATO DE ENTREGA FINAL (obligatorio)
1. **Estado:** APROBADO / APROBACIÓN PARCIAL / NO APROBADO.
2. **Cambios:** lista de archivos modificados y una frase por corrección.
3. **Evidencia:** versión de Godot, comandos ejecutados, salida de tests, códigos de salida, métricas de cámara/FPS (o marca `BLOCKED` con motivo).
4. **Pendientes:** solo bloqueos demostrados, con motivo técnico y paso mínimo para resolverlos.
5. **Cómo jugar:** ruta de `project.godot`, escena F5, controles y pruebas manuales finales para el usuario.

## INSTRUCCIÓN DE ARRANQUE
No te detengas tras escribir un plan. Inspecciona, importa, ejecuta, corrige el primer error, vuelve a ejecutar. Repite hasta alcanzar el máximo estado verificable en este entorno. Si un permiso o hardware impide una verificación, documenta el bloqueo exacto y continúa con lo demás. 