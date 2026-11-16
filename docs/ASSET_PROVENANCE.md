# Procedencia de assets — Misión 04

Los recursos descargados son de uso libre y están guardados junto a su licencia o procedencia para que la distribución del proyecto no dependa de enlaces a archivos temporales.

| Recurso incorporado | Uso | Procedencia y licencia |
|---|---|---|
| Kenney Animated Characters Retro 1.1 (`assets/third_party/kenney/character/`) | `characterMedium.fbx`, rig humano de 58 huesos; clips Idle, Run y Jump importados desde FBX; skins humanas. | [Página oficial](https://kenney.nl/assets/animated-characters-retro), CC0 1.0. La copia de `License.txt` acompaña los archivos. |
| Kenney Survival Kit 2.0 (`assets/third_party/kenney/survival/`) | 14 modelos distintos glTF: barril, cama enrollada, botella, caja, balde, cofre, panel metálico, panel con tornillos, tablones, poste, tienda, hacha, banco de trabajo y tronco; también hierba, piedra y martillo para pickups. | [Página oficial](https://kenney.nl/assets/survival-kit), CC0 1.0. La copia de `License.txt` acompaña los archivos. |
| Poly Haven Asphalt 01, Wood Planks, Metal Plate (`assets/textures/polyhaven/`) | Texturas difusas, normales OpenGL y rugosidad 2K para vía/suelo, madera del refugio y metal de cubiertas. | [Asphalt 01](https://polyhaven.com/a/asphalt_01), [Wood Planks](https://polyhaven.com/a/wood_planks), [Metal Plate](https://polyhaven.com/a/metal_plate); licencias CC0 verificadas en las fichas del autor. |
| Grabaciones CC0 (`audio/mission04/`) | Pasos sobre camino de tierra pedregoso, pasos de interior de madera/concreto para la zona asfaltada, viento de bosque, golpe de caída y golpe breve de tela para pickup. | Previsualizaciones originales publicadas en Freesound, accedidas mediante SoundSpool: [Footsteps: dirty stony path](https://soundspool.com/sounds/footsteps-exterior-walking-slowly-dirty-stony-path), [Footsteps: wood/concrete](https://soundspool.com/sounds/footsteps-in-factory-hall-on-wood-and-concrete), [Wind Forest 08](https://soundspool.com/sounds/wind-forest-08-strong-l-01), [Apples dropping thud](https://soundspool.com/sounds/applesdroppingthudinaforest), [Cloth flop](https://soundspool.com/sounds/clothflp-cloth-flop-balancando-tecido-bsl-calordocao). Licencia CC0 indicada para cada grabación en sus fichas de origen. |

Los sonidos locales se recortan/posicionan en reproducción para pasos, aterrizaje y feedback de recogida. No se redistribuyen paquetes ZIP de origen: solo los formatos/ficheros seleccionados y sus avisos de licencia.

## Notas de integración

- El personaje conserva su `CharacterBody3D` y colisionador del proyecto. El FBX importado proporciona `Skeleton3D` y la animación se ejecuta con `AnimationPlayer` + `AnimationTree` (`idle`, `walk`, `run`, `jump`, `crouch`). `walk` es un clip de carrera retimado y `crouch` reutiliza idle; el pack no trae esos clips con esos nombres.
- El modelo humano es estilizado y tiene camiseta de manga larga, pantalones y zapatillas, no una chaqueta de supervivencia ni botas robustas. Se documenta como diferencia visual pendiente, no como cumplimiento literal de vestimenta.
- Los edificios y la colisión del mundo de la Fase 1 siguen siendo geometría funcional existente; los props de ambientación añadidos son instancias de glTF real. El alcance no agrega streaming, enemigos ni combate.
