# RACE 0.3.0 — Offline alpha

Nueva versión jugable para pruebas. APK debug, paquete Android existente `com.jeansaenz.gt77drivelab`, versionCode 30. No es una versión de producción ni la totalidad de la visión final.

## Implementado

- Catálogo de 24 vehículos originales: GT77 conserva su modelo importado; otros 23 usan carrocerías procedurales con siluetas por familia, masa, torque, adherencia, aerodinámica, tipo de tracción y timbre propios. No son 24 modelos artísticos detallados en Blender.
- 12 circuitos seleccionables: Proving Ground, Sierra y 10 trazados procedurales nuevos, más una recta independiente para Drag. Los 10 nuevos usan geometría plana y ambientaciones básicas; no reproducen todavía los desniveles y detalles visuales de la propuesta conceptual.
- Libre, contrarreloj, carrera rápida de 3 vueltas, campeonato de 3 eventos, drift de 90 s, sprint, rally, eliminación, drag de 402 m y academia. Sprint y rally recorren el 75 % del circuito; no son todavía tramos abiertos diseñados a mano.
- Cinco rivales de trayectoria con velocidad ajustada por curvatura, dificultad y desplazamiento lateral. **Sin colisiones con rivales**, daños o estrategia de boxes.
- Arcade deportivo predeterminado, Sport y Simulación; dirección limitada por aceleración lateral a alta velocidad; tracción FWD/RWD/AWD.
- Garaje 360°, pintura, mejoras de motor, neumáticos y frenos; créditos/XP locales y tres desafíos diarios.
- Récords separados por circuito, vehículo, ayudas, clima, sentido y mejoras. Sectores con delta; fantasma personal grabado a 20 Hz. No hay tabla global ni fantasmas de amigos.
- Interfaz adaptable, márgenes de área segura, exportación inmersiva, botones, inclinación, volante virtual, modo zurdo y lectura de mando Bluetooth.
- Condiciones seleccionables seco/mojado/atardecer/noche. Mojado reduce agarre y añade lluvia con calidad media/alta. No hay transición meteorológica ni simulación de charcos.
- Calidad baja/media/alta, límites 30/60 FPS, audio sintético por RPM/carga y ajustes de vibración.
- Modo foto: arrastrar para orbitar y guardar PNG en los datos privados de la app. No exporta a la galería Android ni comparte clips.

## Validación reproducible

Godot 4.5.1, GL Compatibility. El workflow falla ante errores de scripts o pruebas, genera evidencia y después exporta el APK.

- `physics_test.gd`: suspensión, aceleración, frenada, reversa, dirección, aero, multitáctil y sensores simulados.
- `expansion_test.gd`: 24 autos, cuatro contactos y aceleración; cambios de carril a 80/120/180/220 km/h en los tres estilos; 3,600 muestras de asfalto de circuitos nuevos; reglas y persistencia.
- `track_integration_test.gd`: 840 muestras de Sierra, superficies, aparición, cambio de circuito y protección de vueltas contra reversa/teletransporte.
- `experience_test.gd`: cinco resoluciones, diez modalidades, rivales, campeonato, recompensa única, recolocación, lluvia, sentido inverso, volante y modo zurdo.
- `selector_input_test.gd`: toque real sintetizado en servidor gráfico, entrada a pista, pausa y continuación.
- `capture_release.gd`: capturas reales del juego y de la interfaz.

Estos resultados son pruebas de escritorio/headless y renderizado por software. **No acreditan 60 FPS, consumo de batería, sensores, recortes de pantalla ni ergonomía en un dispositivo Android físico.**

## Instalación

Descargar `RACE_0.3.0.apk` de esta publicación y permitir la instalación desde la aplicación usada para descargarlo. Es una compilación de pruebas firmada con la clave debug histórica del repositorio. El hash está en `SHA256SUMS.txt`.

Si Android indica conflicto de firmas con una instalación previa, respaldar los datos que interese conservar antes de desinstalarla. Los récords 0.2 permanecen en su archivo anterior; 0.3 crea récords nuevos porque ahora separa configuraciones.

## Pendiente para cumplir la visión completa

Modelado y acabado profesional de los 23 autos nuevos y 10 entornos; trazados con relieve, peraltes y tramos abiertos; IA con colisiones/adelantamientos/recuperación; daños; temperaturas y compuestos de neumáticos; ajustes de suspensión/diferencial/transmisión; boxes; apertura de puertas, ruedas, alerones y calcomanías; HUD configurable y reposicionamiento libre de controles; repeticiones completas y exportación de clips; baking/LODs por activo y mediciones Android. Multijugador y servicios globales quedan fuera de esta entrega por la elección explícita de juego offline.
