# CineFinder

Aplicación Flutter para descubrir películas con TMDB, localizar cines mediante Maps y guardar favoritos, calificaciones y reseñas en el dispositivo.

## Requisitos

- Flutter estable (Dart 3.4 o posterior) y Android SDK.
- Una clave TMDB para activar catálogo, búsqueda, detalles y disponibilidad. La app no incluye una clave.

## Ejecutar

```powershell
flutter pub get
flutter run --dart-define=TMDB_API_KEY=TU_CLAVE_TMDB
```

Sin la clave, la app muestra una ficha ficticia marcada DEMO para probar favoritos, calificaciones y reseñas; no la presenta como catálogo real. Para activar TMDB, configura la clave. Para crear un APK de depuración:

```powershell
flutter build apk --debug --dart-define=TMDB_API_KEY=TU_CLAVE_TMDB
```

El APK de depuración generado para esta versión está en `artifacts/CineFinder-debug.apk` (compilado sin clave TMDB).

Una clave compilada dentro de una app móvil puede extraerse. Para producción, coloca las consultas TMDB detrás de un proxy propio; nunca agregues una credencial privada al repositorio. `docs/.env.example` muestra el nombre de la variable usada durante desarrollo.

## Funciones disponibles

- Inicio con populares, tendencias y estrenos de TMDB; búsqueda y detalles con créditos y proveedores en México.
- Navegación inferior por Inicio, Buscar, Cines, Favoritos y Perfil.
- Favoritos, calificación y reseña por película guardados localmente en SQLite; perfil local con nombre editable.
- Compartir una reseña con el selector nativo de Android.
- Ubicación con permiso y búsqueda manual de cines que abre Google Maps. CineFinder no ofrece cartelera ni una lista propia de salas.

## Datos y atribución

El catálogo y sus imágenes dependen de TMDB y de una conexión a internet. El perfil muestra el aviso requerido: “This product uses the TMDB API but is not endorsed or certified by TMDB.” Antes de distribuir, agrega uno de los logos oficiales aprobados de TMDB y revisa sus [requisitos de atribución](https://developer.themoviedb.org/docs/faq) y [condiciones de uso](https://www.themoviedb.org/documentation/api/terms-of-use).
