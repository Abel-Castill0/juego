# AGENTS.md — UMBRAL

## Proyecto
Vertical slice de supervivencia en Godot 4.7.2 Standard (GDScript), Forward+, Windows/Linux.
Fase actual: **Fase 1 (MVP)**. No implementar fases 2/3 sin autorización explícita.

## Comandos de verificación (ejecutar antes de declarar "done")
- Importar sin GUI: `godot --headless --path . --import`
- Tests: `godot --headless --path . res://tests/inventory_tests.tscn`
  (o `--scene res://tests/inventory_tests.tscn` si tu build lo requiere; verifica `--help`).
- Arranque rápido: `godot --headless --path . res://scenes/main.tscn --quit-after 180`

**Advertencia crítica sobre Godot headless:** un exit code `0` **no garantiza** que no hubo errores. Revisa siempre `stdout`/`stderr` en busca de `ERROR`, `SCRIPT ERROR`, `Invalid get index` o fallos de carga[reference:3]. Un test que "pasó" pero imprimió errores **no es PASS**.

## Reglas de arquitectura (no negociables)
- Física en `_physics_process()`. `GameClock` es AutoLoad y está desacoplado del HUD.
- Inventario **transaccional**: si falla peso, slots, materiales u output, **cero** cambios de estado.
- Datos de ítems y recetas en `resources/*.json`; nunca hardcodeados en GDScript.
- `InputBootstrap` crea acciones en runtime; verifica su funcionamiento **en ejecución**, no solo en el editor.
- No introduzcas APIs de Godot 3.x, Unity ni dependencias no verificadas.

## Límites
- No hacer `git reset --hard`, borrar archivos ajenos, `push`, `merge` ni despliegue remoto sin autorización.
- No desactivar ni maquillar tests para obtener un PASS.
- Si una métrica (FPS, transición de cámara) no se puede medir en el entorno, márcala **`BLOCKED`**, nunca `PASS`.
- Al corregir un bug, añade o adapta una regresión.

## Criterio de "done" de Fase 1
1. Importación y arranque sin errores reales.
2. Tests automatizados PASS + escenarios manuales críticos verificados.
3. Transición de cámara medida < 300 ms (con método documentado).
4. Invariantes de inventario/crafting preservadas.
5. `README.md` y `docs/QA_FASE1.md` actualizados con evidencia real.