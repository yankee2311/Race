# RACE — Android / Godot 4.5.1

Versión **0.3.0 offline alpha**. Juego de conducción con 24 vehículos, 12 circuitos y 10 modalidades. El contenido nuevo usa modelos y entornos procedurales; sigue en desarrollo.

[Descargar APK de pruebas](https://github.com/yankee2311/Race/releases/tag/v0.3.0-alpha.1) · [Cambios, pruebas y limitaciones](Race/docs/RELEASE_0.3.0.md) · [CI](https://github.com/yankee2311/Race/actions/workflows/build-apk.yml)

## Ejecutar

1. Clonar con Git LFS: `git clone https://github.com/yankee2311/Race.git` y `git lfs pull`.
2. Abrir `Race/project.godot` con Godot **4.5.1**.
3. Ejecutar F6/F5 o `godot --path Race` desde la raíz del repositorio.

Teclado: WASD/flechas, espacio (freno de mano), C (cámara), R (recolocar), V (reversa), Esc (pausa). Android: botones, inclinación o volante virtual. Mandos: stick izquierdo, RT/LT y A.

## Pruebas

```bash
godot --headless --path Race --editor --import
godot --headless --path Race --fixed-fps 120 --script tests/physics_test.gd
godot --headless --path Race --fixed-fps 120 --script tests/expansion_test.gd
godot --headless --path Race --fixed-fps 120 --script tests/track_integration_test.gd
godot --headless --path Race --fixed-fps 120 --script tests/experience_test.gd
xvfb-run -a godot --audio-driver Dummy --path Race --fixed-fps 120 --script tests/selector_input_test.gd
```

El pipeline ejecuta las pruebas antes de exportar. Cada push a `main` publica el APK de prueba en la prepublicación 0.3.0. Los pushes a `feature/race-*` generan artefactos sin publicar una versión.

No hay servidores, cuentas, monetización ni SDKs de publicidad. Los autos nuevos son diseños ficticios generados por código. Consultar las licencias incluidas en `Race/assets` para Godot y fuentes.

La versión 0.2 y su documentación histórica permanecen en el historial Git. `Race/docs/RELEASE_0.3.0.md` define el alcance actual y los pendientes reales.
