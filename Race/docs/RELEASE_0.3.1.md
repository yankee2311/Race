# RACE 0.3.1 — Hotfix de estabilización Android

**Estado:** versión candidata de pruebas, requiere validación en un Samsung Galaxy A05 real.
**Base:** RACE 0.3.0 · Godot 4.5.1 Compatibility · paquete `com.jeansaenz.gt77drivelab`.
No altera el catálogo de 24 vehículos, 12 circuitos ni los 10 modos offline.

## Cambios técnicos

- Perfil Lite automático para Galaxy A05 (SM-A055): límite 30 FPS, escala 3D 70 %, sombras y vibración deshabilitadas inicialmente; conserva las preferencias modificadas deliberadamente por el usuario después de la primera activación.
- El perfil Lite reduce la frecuencia física a 60 Hz; el resto conserva 120 Hz. Se incorpora una regresión dedicada a 60 Hz para acelerar, frenar, verificar estabilidad del chasis y comprobar cuatro contactos de ruedas.
- Búsqueda de puntos de circuito mediante rejilla espacial 2D; fallback exacto cuando el automóvil está lejos de la pista. Nuevas pruebas comparan la búsqueda con fuerza bruta en los 12 trazados.
- HUD: precálculo de la polilínea del minimapa, reconstrucción solo cuando cambia el circuito.
- Audio: el generador se detiene de verdad al silenciar, pausar, salir al garaje o entrar a modo foto.
- Las marcas de derrape rechazan vectores degenerados/no finitos y la física recupera transformaciones/velocidades inválidas.
- Durante los cambios de pista se deja un cuadro entre liberación del escenario anterior e inserción del nuevo para disminuir el pico de memoria.
- `RACE_DIAG` en el log de Android emite modelo, perfil, pista, vehículo y cada 10 segundos FPS, tiempo de física, memoria interna instrumentada, nodos y velocidad.

## Alcance y limitaciones

Estas correcciones reducen riesgos conocidos; **no se afirma que resuelvan el cierre aleatorio sin un logcat del Galaxy A05**. Godot headless y su simulación de Android no sustituyen el controlador Mali, la administración de memoria ni las condiciones térmicas reales. La métrica `MEMORY_STATIC` de Performance puede no estar disponible en builds release; la de esta entrega es debug.

## Validación de dispositivo

1. Actualizar desde 0.3.0 manteniendo el identificador de paquete y firma debug.
2. Comprobar en Ajustes que se activó calidad Baja / 30 FPS / Sombras OFF.
3. Recorrer Proving Ground, Sierra y dos circuitos nuevos con modo Libre durante al menos 30 minutos cada uno. Repetir con diferentes vehículos.
4. Confirmar que no existen ANR, SIGSEGV, errores de script ni cierres nativos.
5. Con ADB: `adb logcat -c`, después `adb logcat -v threadtime > race_a05_031.txt`; reproducir el fallo y recoger `RACE_DIAG` / `FATAL` / `libgodot`.

## Rollback

Si el perfil de física a 60 Hz presenta pérdida de estabilidad, revertir a la rama/v0.3.0 previamente verificada hasta completar la calibración. No desinstalar sin respaldo de los datos de usuario.
