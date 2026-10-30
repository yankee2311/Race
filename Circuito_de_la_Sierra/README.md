# Circuito de la Sierra · v1.0

Circuito ficticio creado íntegramente en Blender 4.5.3 LTS, a escala real (1 unidad = 1 metro), con entorno de valle semiárido. Paquete de modelado e integración para Godot 4.4+, con una escena de inspección y recorrido guiado. No contiene un juego de conducción ni un controlador de automóvil.

## Abrir y explorar

**Blender:** abre `Circuito_de_la_Sierra.blend` en Blender 4.5 LTS o posterior. Las texturas están empaquetadas. La cámara `Overview` es la vista general; `Pit_Lane_View` y `Mountain_Sector` muestran detalles. Pulsa F12 para renderizar la cámara activa. Usa Material Preview para ver los materiales.

**Godot:** importa `godot/project.godot`, espera a que termine la importación del GLB y pulsa F6/F5 para ejecutar `main.tscn`. No requiere addons, internet ni paquetes externos. El proyecto usa Compatibility para ampliar la compatibilidad con equipos.

- **1:** vista general.
- **2:** recorrido de cámara sobre la pista, a 162 km/h inicialmente.
- **3:** cámara libre; WASD y Q/E para desplazarte.
- **Botón derecho:** orientar la cámara libre.
- **Shift:** desplazamiento rápido.
- **Rueda:** cambiar la velocidad del recorrido guiado.
- **Esc:** cerrar la inspección.

## Especificación implementada

| Elemento | Implementación |
|---|---|
| Recorrido | 4.200 m sobre el centro de la curva 3D, sin cruces |
| Recta principal | 900 m, completamente recta y a cota constante |
| Ancho asfaltado | 14 m |
| Elevación | 12 a 132 m: 120 m de desnivel |
| Pendiente longitudinal máxima | Aproximadamente 14,74%; requiere ajustar suspensión y potencia del vehículo |
| Peralte | Transición continua desde 0% hasta 8%; inversión gradual en las enlazadas |
| Sectores | Recta y horquilla; enlazadas de ascenso; descenso amplio de retorno |
| Segmentación | 14 segmentos de asfalto de 300 m; muros/vallas y escapatorias organizados por segmento |
| Pianos | Rojo/blanco, 1,5 m de ancho, relieve geométrico estriado, colisión incluida |
| Escapatorias | Grava a ambos lados, más ancha al exterior de las curvas; transición suave en inflexiones |
| Protecciones | Muros de hormigón, postes y malla simplificada; neumáticos en horquilla y descenso |
| Pit lane | Carril paralelo con conexiones de entrada y salida, muro separador, 26 garajes modulares |
| Instalaciones | Torre de control, parrilla, línea de meta, pórtico y referencias de frenada |
| Tribuna | Cubierta en voladizo, asientos, tres LOD geométricos |
| Entorno | Terreno dividido en 36 parches; rocas y vegetación estilizada de detalle moderado |
| Materiales | Asfalto y grava con base color, rugosidad/metallic ORM y normales exportables |
| GLB | UV, normales, tangentes, materiales y texturas embebidas; sin luces ni cámaras |

El circuito es un activo para prototipado y evolución visual. El entorno es estilizado; no usa fotogrametría. No se declara homologación de seguridad ni reproducción de un circuito real.

## Organización del Blender

- `01_TRACK_CHUNKS`: asfalto, pianos, marcas.
- `02_RUNOFF`: grava y taludes de transición.
- `03_BARRIERS`: muros, vallas y neumáticos.
- `04_PIT_COMPLEX`: instalaciones de boxes y control.
- `05_GRANDSTAND`: tribuna y LOD.
- `06_LANDSCAPE`: parches del valle.
- `07_PROPS`: señales, rocas y vegetación.
- `90_EDITABLE_GUIDE`: curva Bezier 3D y malla con modificadores Array + Curve. Oculta para evitar superposición con el asfalto exportado.
- `99_PRESENTATION`: cámaras y sol, sólo para Blender.

**Edición del trazado:** el master conserva sus modificadores y Tilt. Las mallas divididas son copias de exportación independientes; cambiar la curva no reconstruye automáticamente los chunks. Para regenerar toda la escena con el constructor, modifica `design.json` y ejecuta:

```sh
blender --background --python build_circuit.py
```

El constructor usa Blender y su NumPy incluido. `design.json` contiene los nodos y ambos handles de la curva. La longitud y los límites de los segmentos del constructor están fijados a 4.200 m; si se altera significativamente el diseño, hay que recalibrar su longitud y esos parámetros antes de generar. Al ejecutarse, el constructor reemplaza los archivos generados de este paquete; guarda previamente las ediciones manuales.

## Integración y físicas

El GLB está en `godot/assets/Circuito_de_la_Sierra.glb`. Puede importarse directamente en otro proyecto Godot. Los nombres terminados en `-col` producen colisiones estáticas de triángulos. La escena `main.tscn` carga el modelo y asigna `PhysicsMaterial` según la superficie:

| Recurso | Fricción |
|---|---:|
| `physics/asphalt.tres` | 1,0 |
| `physics/kerb.tres` | 0,8 |
| `physics/gravel.tres` | 0,4 |

El terreno y los taludes comparten el material físico de superficie suelta. Los neumáticos son geometría visual delante de los muros de contención; no se simulan como cuerpos dinámicos individuales. Las instalaciones usan colisión de malla; los pequeños elementos de paisaje no tienen colisión.

**La fricción no sustituye al modelo de neumáticos:** un vehículo con ruedas por raycast o fuerzas personalizadas debe leer el grupo de superficie (`surface_asphalt`, `surface_kerb`, `surface_loose`) y ajustar agarre, resistencia y frenado. Una fricción baja por sí sola no reproduce el hundimiento ni la desaceleración de una trampa de grava. Esos comportamientos quedan para la integración del vehículo.

`AI_Centerline` es un `Path3D` cerrado, generado desde `assets/centerline.json`, con `AI_PathFollow_Demo`. Es una línea central de referencia; aún no es una trazada competitiva optimizada ni incluye IA de adelantamientos/evitación por raycasts. El recorrido de cámara permite revisar curvas y elevaciones. `VehicleSpawn` marca un punto de salida para integrar posteriormente un coche.

## Rendimiento y LOD

Los segmentos independientes permiten el frustum culling habitual del motor, pero no implementan streaming de carga/descarga. Godot genera también LOD de malla durante su importación. La tribuna dispone de geometría explícita:

- LOD0: hasta 300 m, con asientos.
- LOD1: de 300 a 750 m, cubierta, soportes y terrazas.
- LOD2: más de 750 m, volumen simplificado.

LOD1/2 permanecen ocultos en Blender; se exportan y la escena Godot controla sus rangos. El paisaje está agrupado; los rangos de vegetación y rocas se aplican por grupo. Es una base orientada a escritorio. Antes de una versión móvil, medir draw calls, memoria y FPS en el dispositivo objetivo, reducir las barreras de neumáticos, la densidad de asientos y las colisiones de terreno lejano. No se afirma una tasa de FPS sin medición.

## Validación incluida

- `validation_blender.json`: mediciones del trazado y conteo de geometría.
- `godot/validation_godot.json`: prueba real de importación, recursos físicos, recorrido y colisión mediante raycasts.
- `godot/scripts/validate.gd`: prueba reproducible con `godot --headless --path godot --script res://scripts/validate.gd`.
- `previews/`: tres renders del modelo real, realizados en Blender.

Se verificaron UV y normales exportadas, texturas PBR embebidas, ausencia de luces/cámaras en GLB y cierre del circuito. Las pruebas son geométricas y de integración; la suspensión, estabilidad y sensación de conducción deben validarse con el controlador de vehículo elegido. La importación sin pantalla de Godot puede emitir un mensaje de su almacenamiento de texturas dummy; no impidió cargar el modelo ni ejecutar la validación de físicas.

## Referencias técnicas

- Godot, sufijos de importación: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html
- Blender, glTF: https://docs.blender.org/manual/en/latest/addons/import_export/scene_gltf2.html

Geometría, señales y texturas procedurales creadas para este proyecto. Sin logos comerciales ni assets de terceros. Fecha de entrega: 29 de octubre de 2026.
