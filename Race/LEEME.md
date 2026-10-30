# GT77 Drive Lab — Android / Godot

**Versión 0.2.0:** consulta [Sierra y selector de pistas](docs/SIERRA_INTEGRATION.md) para las novedades. Al abrir el juego, elige una pista y pulsa Conducir. Cada circuito conserva su propio récord.

Prototipo jugable 0.1.0, creado con Godot 4.5.1 e integrado con el modelo GT77 de la referencia. Conducción libre en un circuito de pruebas de aproximadamente 584 m, más zona de eslalon y obstáculos para la suspensión. Funciona sin conexión.

## Instalar y jugar

1. Copia `Race_GT77_Sierra_0.2.0.apk` a tu teléfono Android y ábrelo. Si Android solicita autorización para instalar desde la aplicación con la que abriste el archivo, completa ese paso.
2. Usa el teléfono en horizontal. Elige estilo de manejo, controles y pintura; pulsa **SALIR A PISTA**.
3. Empieza con **Asistido** o **Sport**. Frena antes de las curvas: no hay agarre infinito ni límites invisibles que mantengan el coche sobre la pista.

El APK incluye ARM de 32 y 64 bits. El manifiesto exige Android 7.0/API 24 o posterior; el render requiere OpenGL ES 3.0 compatible. La fluidez depende del dispositivo. Desactiva **Sombras** si necesitas reducir la carga gráfica. Objetivo de presentación: 60 fps; no se garantiza esa tasa en todo teléfono.

## Controles

| Acción | Android | Teclado, al abrir el proyecto en PC |
|---|---|---|
| Acelerar | GAS | W / flecha arriba |
| Frenar | FRENO | S / flecha abajo |
| Girar | ◀ / ▶ o inclinación | A / D o flechas |
| Freno de mano | F. MANO | Espacio |
| Cambiar cámara | Botón de cámara, arriba a la derecha | C |
| Reversa / avance | Botón D/R, con el coche casi detenido | V |
| Recolocar | RECOLOCAR | R |
| Pausar | Ⅱ / botón Atrás de Android | Esc |

Los pedales y la dirección aceptan varios dedos simultáneamente. La dirección por botones tiene una transición gradual. Para retroceder, detén el coche, selecciona R y utiliza GAS. No se cambia automáticamente a reversa al mantener el freno.

### Giroscopio e inclinación

Selecciona **Giroscopio / inclinación**, sostén el teléfono frente a ti como un volante y pulsa **CENTRAR GIRO**. Gira el teléfono a izquierda o derecha; GAS, FRENO y F. MANO permanecen en pantalla. Ajusta los grados para llegar al giro máximo en el menú, y usa **Invertir giro** si lo prefieres.

El control combina velocidad angular del giroscopio con gravedad, y utiliza acelerómetro filtrado cuando no hay lectura de gravedad. Si no dispone de esas lecturas, regresa a botones. El estado del HUD diferencia **GIRO + GRAVEDAD** de **INCLINACIÓN**. La prueba automatizada verifica las señales simuladas; la sensibilidad y latencia del sensor físico todavía requieren comprobación en un teléfono real.

## Estilos de manejo

| Modo | Ayudas |
|---|---|
| Asistido | ABS, control de tracción, mayor reducción de dirección con velocidad y amortiguación adicional de guiñada |
| Sport | ABS y control de tracción; respuesta más directa |
| Simulación | Sin ABS, sin control de tracción y con mayor autoridad de dirección a velocidad |

Los tres modos comparten masa, motor, suspensión y neumáticos. Simulación puede bloquear ruedas o perder tracción; los botones a fondo no sustituyen un pedal analógico.

## Cámaras y HUD

- **Capó:** cámara por delante del habitáculo, con carrocería visible.
- **Onboard:** puesto del conductor, volante animado y cabina simplificada.
- **Tercera persona:** seguimiento suavizado, FOV variable y comprobación de obstáculos entre coche y cámara.
- Velocidad en km/h, marcha, RPM, ABS/TCS, fuerza aerodinámica, aceleración lateral y carga de cada rueda.
- Minimap, cronómetro, vueltas y mejor registro local. Recolocar reinicia el intento de vuelta. No es un sistema competitivo contra recortes de pista.
- Menú de pausa, regreso a ajustes, sonido de motor sintetizado, chirrido aproximado y marcas de neumáticos.

## Física implementada

El coche es un `RigidBody3D` con cuatro consultas de contacto por rayos. Cada rueda calcula longitud de suspensión, muelle, amortiguación y fuerzas de neumático en su punto de apoyo. La carrocería puede inclinarse, saltar o volcar; no está fijada artificialmente al suelo.

| Parámetro | Valor de esta calibración |
|---|---|
| Masa | 1,280 kg |
| Tracción | Trasera |
| Radio de rueda | 0.366 m |
| Distancia entre ejes | 2.83 m |
| Vía | 1.76 m |
| Muelle por rueda | 43,000 N/m |
| Amortiguación compresión / extensión | 3,900 / 4,700 N·s/m |
| Longitud de referencia de suspensión | 0.34 m |
| Límites de longitud de suspensión | 0.09–0.55 m |
| Barra estabilizadora, coeficiente de transferencia | 6,500 N/m |
| Par máximo de la curva de motor | 520 N·m |
| Corte aproximado | 8,200 rpm |
| Transmisión | Automática de 6 marchas + reversa |
| Relación final | 3.75 |
| Cd / área frontal | 0.36 / 2.0 m² |
| Coeficiente de carga aerodinámica | 1.65 |
| Densidad del aire | 1.225 kg/m³ |
| Simulación del chasis | 120 Hz |

Los neumáticos calculan deslizamiento longitudinal y lateral, saturación suave de fuerzas y límite combinado de adherencia. Las ruedas tienen velocidad angular, reacción al par y cuatro subpasos de cálculo por actualización de física. La adherencia cambia entre asfalto, hierba y pianos. Hay dirección Ackermann, resistencia a la rodadura, frenado de motor y distribución de carga aerodinámica delantera/trasera. Arrastre y carga aerodinámica crecen con el cuadrado de la velocidad.

**Son parámetros de diseño del prototipo, no especificaciones verificadas del vehículo de la imagen.** No equivale a un simulador validado con telemetría: faltan curvas de neumáticos medidas, temperatura/desgaste, geometría completa de suspensión, diferencial avanzado, daños, lluvia y calibración instrumental. La colisión de carrocería usa un volumen simplificado.

## Modelo y pinturas

El modelo móvil conserva la apariencia del GT77, con aproximadamente 62,220 triángulos y las cuatro ruedas separadas. La carrocería y ruedas se agruparon por materiales; los elementos repetidos de la pista se dibujan mediante instancias. Los mapas de pintura son de 2048 × 2048 para reducir memoria.

Hay tres pinturas seleccionables en el APK: rojo/grafito, Arctic y Pearl. Se conserva el mapeado UV del modelo original: puedes crear nuevos mapas con sus plantillas y agregarlos al proyecto. Para ampliar el catálogo del juego, añade el PNG en `assets/`, su nombre en `car.gd > set_skin()` y la opción correspondiente en `main.gd`. Esta versión del APK no incluye importador de imágenes externas desde Android.

## Abrir y modificar el proyecto

1. Instala Godot **4.5.1**, versión estándar, e importa `project.godot`.
2. Espera la importación del GLB, fuentes y texturas.
3. Ejecuta `main.tscn` con F6 o el proyecto con F5.

Archivos principales:

- `scripts/car.gd`: suspensión, neumáticos, transmisión, ABS/TCS, aerodinámica y ruedas.
- `scripts/controls.gd`: multitáctil, teclado, sensores y calibración.
- `scripts/track.gd`: pista, colisiones, entorno e instancias.
- `scripts/main.gd`: menú, ajustes, cámaras, pausa y cronometraje.
- `scripts/hud.gd`: instrumentación y mapa.
- `scripts/engine_audio.gd`: síntesis de audio.

### Compilar otra vez el APK

Instala las plantillas de exportación de Godot 4.5.1, OpenJDK 17 y las herramientas Android SDK. Configura **Editor Settings → Export → Android** con las rutas de Java, SDK y la clave de pruebas `build/debug.keystore` local. Es una firma de desarrollo; el alias y contraseña son los valores de depuración estándar de Android. Para futuras actualizaciones de este APK conserva la misma firma y aumenta `version/code`.

Desde la carpeta del proyecto:

```bash
godot --headless --editor --import
godot --headless --export-debug Android ../GT77_Drive_Lab.apk
```

En Windows sustituye `godot` por la ruta del ejecutable de Godot entre comillas. El preset utiliza las plantillas precompiladas, sin Gradle. El APK entregado se verificó con `apksigner` y se inspeccionó con las herramientas del SDK.

## Pruebas y alcance de la validación

```bash
godot --headless --fixed-fps 120 --script res://tests/physics_test.gd
godot --headless --fixed-fps 120 --script res://tests/control_test.gd
```

`tests/results.json` y `tests/control_results.json` contienen los resultados reales. Se comprueban reposo, cuatro apoyos, aceleración, cambio automático, frenado, reversa, giro, aerodinámica, amortiguación tras una caída, multitáctil y calibración de señales de sensores. Las capturas de `docs/` proceden del juego ejecutándose en Godot con render OpenGL de escritorio.

**No se realizó una instalación ni una prueba en un dispositivo Android físico.** La compilación y firma del APK, el funcionamiento en Godot y las pruebas de física/entrada sí se realizaron. No se ha medido el rendimiento ni la precisión del giroscopio en un teléfono concreto.

## Referencias técnicas y licencias

- Exportación Android: https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html
- Entrada y sensores: https://docs.godotengine.org/en/4.5/classes/class_input.html
- Cuerpos rígidos: https://docs.godotengine.org/en/4.5/classes/class_rigidbody3d.html
- Licencias del motor y fuentes incluidas en `assets/GODOT_LICENSE.txt` y `assets/FONT_LICENSE.txt`.
