# CineFinder — progreso

Actualizado: 21 de noviembre de 2026.

## Funciona en el código

- App Flutter con tema Material 3 oscuro y cinco destinos: inicio, búsqueda, cines, favoritos y perfil.
- Cliente TMDB para populares, tendencias, estrenos, búsqueda, detalles/créditos y proveedores regionales MX. Requiere clave inyectada al ejecutar.
- SQLite local para favoritos, calificación independiente y una reseña editable por película; perfil con nombre persistente.
- Edición y eliminación de reseñas desde el perfil; compartir con el selector nativo de Android.
- Cines cercanos mediante permiso de ubicación o búsqueda manual; los resultados abren Google Maps. No se ofrece cartelera propia.
- Sin clave TMDB, la app muestra una única ficha ficticia etiquetada DEMO para poder probar favoritos, calificaciones y reseñas; no se presenta como dato real.
- Estados informativos si falta TMDB o no hay datos; póster con carga y fallback.

## Validación y límites

- Flutter 3.47.1 / Dart 3.13.1.
- `flutter pub get`: correcto.
- `flutter analyze`: sin problemas.
- `flutter test`: pasó la prueba de branding y los cinco destinos.
- APK debug compilado desde una copia temporal para evitar los bloqueos de OneDrive en archivos intermedios. Artefacto: `artifacts/CineFinder-debug.apk`, compilado sin clave TMDB.
- No se configuró una clave TMDB: falta validar respuestas reales. Cines se consultan externamente en Maps, sin proveedor de cartelera.
- `flutter devices` no detectó un Android físico ni un emulador conectado. Falta instalar/probar en teléfono, revisar persistencia después de reiniciar y comprobar permisos, compartir y navegación en dispositivo.
- El aviso de atribución TMDB está en Acerca de; falta incluir el archivo de uno de los logos oficiales aprobados antes de distribuir.
- No se guardaron credenciales reales.

## Siguientes tareas

1. Configurar TMDB con `--dart-define=TMDB_API_KEY=...` y comprobar endpoints.
2. Instalar el APK en Android físico y validar flujos locales, compartir, ubicación, Maps y navegación.
3. Revisar atribución TMDB y proxy antes de distribuir una versión de producción.
