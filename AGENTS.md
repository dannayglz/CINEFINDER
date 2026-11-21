# Guía del proyecto CineFinder

- Aplicación Flutter/Dart enfocada primero en Android.
- Mantén los datos de catálogo provenientes de TMDB identificados y no inventes disponibilidad, horarios ni reseñas públicas.
- La API se configura con `--dart-define=TMDB_API_KEY=...`; no guardes secretos en el repositorio.
- Favoritos, reseñas y calificaciones se conservan localmente en SQLite. Mantén las consultas de base de datos fuera de los widgets cuando sea viable.
- Conserva el tema oscuro y la paleta de CineFinder al añadir pantallas.
- Actualiza `docs/PROGRESO.md` con evidencia y pendientes reales.
