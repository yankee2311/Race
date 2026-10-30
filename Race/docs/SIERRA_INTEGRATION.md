# Race 0.2.0 · Circuito de la Sierra

El juego abre un selector con dos circuitos jugables: **GT77 Proving Ground** y **Circuito de la Sierra**. Cada tarjeta actualiza la vista previa, mapa a escala, longitud, ancho, recta principal, desnivel, peralte y descripción. El botón inferior abre los ajustes anteriores o carga la pista seleccionada.

## Cambios

- Se restauró la estructura `scripts/`, `assets/`, `tests/` y `docs/`: el repositorio recibido tenía los archivos en la raíz y sus referencias apuntaban a estas carpetas.
- Sierra conserva los 4.200 m, 14 segmentos de asfalto, 14 m de ancho, 900 m de recta y 120 m de desnivel. Se adaptaron mallas decorativas y distancias de visibilidad para Android. El asfalto no fue diezmado; la geometría total del escenario se redujo de 665.155 a 306.650 triángulos.
- Carga de Sierra en segundo plano con pantalla de espera. Sólo una pista y su entorno permanecen activos. El catálogo no carga los dos circuitos al navegar entre tarjetas.
- Spawn y recolocación respetan cota, tangente y normal de la superficie. El minimapa encaja los límites de cada trazado y muestra la posición/dirección del coche.
- Cronometraje independiente de coordenadas fijas: salida/meta y tres controles secuenciales, sentido de marcha y rechazo de saltos de posición. La primera pasada por meta inicia el tiempo. Recolocar invalida la vuelta hasta volver a cruzar la salida.
- Mejor vuelta guardada por pista en `user://settings.cfg` y selección persistente.
- El modelo de neumáticos lee las superficies de Sierra: asfalto, pianos, césped/tierra y grava. La grava reduce agarre y aumenta la resistencia a la rodadura; no es simulación de hundimiento granular.
- Se preservan pinturas, ABS/TCS, modos de conducción, controles multitáctiles/giroscopio, cámaras, reversa y audio.
- La clave pública de depuración que venía en la raíz se conserva localmente para firmar esta actualización y queda fuera del nuevo árbol de Git. No es una clave de producción. El generador de claves de pruebas no reemplaza una existente.

## Android

- Godot 4.5.1 estándar / Compatibility, OpenJDK 17.
- `com.jeansaenz.gt77drivelab`, versión 0.2.0, código 2.
- ARM de 32 y 64 bits, Android 7/API 24 o superior, OpenGL ES 3.0.
- APK firmado para pruebas locales. Conserva la firma de desarrollo del proyecto recibido.
- No requiere red. No incluye claves de firma, tests ni documentación dentro del APK.

Para compilar, instala las plantillas Android de Godot 4.5.1, SDK platform-tools y build-tools 35, configura Java/SDK/clave en las preferencias de exportación Android y ejecuta:

```sh
godot --headless --editor --import
godot --headless --export-debug Android ../outputs/Race_GT77_Sierra_0.2.0.apk
```

Sin una clave de pruebas existente, `bash scripts/create_debug_keystore.sh` crea una local. Una clave nueva no permite actualizar instalaciones firmadas con otra clave.

## Validación

```sh
godot --headless --fixed-fps 120 --script res://tests/physics_test.gd
godot --headless --fixed-fps 120 --script res://tests/control_test.gd
godot --headless --fixed-fps 120 --script res://tests/track_integration_test.gd
```

Los resultados están en `tests/`. La prueba de integración cubre las dos pistas, carga repetida, neumáticos en contacto, aceleración, recolocación en montaña, 840 raycasts de la pista, superficies, cronometraje direccional y límites del minimapa. `tests/capture_ui.gd` reproduce capturas del selector y conducción con un renderizador gráfico. La firma y manifiesto se verifican con `apksigner` y `aapt`.

No se ha probado este APK en un teléfono físico ni se han medido sus FPS en hardware Android. En equipos modestos, desactiva Sombras en Ajustes. No se incluye IA rival, carrera multijugador ni homologación de físicas reales.

La prueba `tests/selector_input_test.gd` requiere un renderizador gráfico: verifica toques en las tarjetas, ajustes y salida a pista, y distribución a 1280×720, 960×720 y 1600×720.
