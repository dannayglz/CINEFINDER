import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

const accent = Color(0xFFE50935);
const violet = Color(0xFF8B5CF6);
const bg = Color(0xFF0D0D12);
const surface = Color(0xFF1B1B25);
const apiKey = String.fromEnvironment('TMDB_API_KEY');

void main() => runApp(const CineFinderApp());

class CineFinderApp extends StatelessWidget {
  const CineFinderApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'CineFinder',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: bg,
          colorScheme: ColorScheme.fromSeed(
              seedColor: accent,
              brightness: Brightness.dark,
              surface: surface,
              primary: accent),
          appBarTheme: const AppBarTheme(
              backgroundColor: bg,
              foregroundColor: Colors.white,
              centerTitle: false),
          cardTheme: CardThemeData(
              color: surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18))),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: surface,
            hintStyle: const TextStyle(color: Colors.white38),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: const Color(0xFF14141C),
            indicatorColor: accent.withValues(alpha: .18),
            labelTextStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ),
        home: const MainShell(),
      );
}

class Movie {
  final int id;
  final String title;
  final String overview;
  final String poster;
  final String backdrop;
  final String date;
  final double rating;
  final List<int> genreIds;
  final List<String> genres;
  final int? runtime;
  final String? director;
  final List<String> cast;
  Movie(
      {required this.id,
      required this.title,
      this.overview = '',
      this.poster = '',
      this.backdrop = '',
      this.date = '',
      this.rating = 0,
      this.genreIds = const [],
      this.genres = const [],
      this.runtime,
      this.director,
      this.cast = const []});
  factory Movie.fromJson(Map<String, dynamic> j) => Movie(
        id: j['id'] ?? 0,
        title: j['title'] ?? j['name'] ?? 'Sin título',
        overview: j['overview'] ?? '',
        poster: j['poster_path'] ?? '',
        backdrop: j['backdrop_path'] ?? '',
        date: j['release_date'] ?? '',
        rating: (j['vote_average'] as num?)?.toDouble() ?? 0,
        genreIds: (j['genre_ids'] as List? ?? [])
            .whereType<num>()
            .map((e) => e.toInt())
            .toList(),
        genres: (j['genres'] as List? ?? [])
            .map((e) => e['name'] as String)
            .toList(),
        runtime: j['runtime'],
      );
  Movie withCredits(Map<String, dynamic> credits) => Movie(
      id: id,
      title: title,
      overview: overview,
      poster: poster,
      backdrop: backdrop,
      date: date,
      rating: rating,
      genreIds: genreIds,
      genres: genres,
      runtime: runtime,
      director: (credits['crew'] as List? ?? [])
          .where((e) => e['job'] == 'Director')
          .map((e) => e['name'] as String)
          .firstOrNull,
      cast: (credits['cast'] as List? ?? [])
          .take(8)
          .map((e) => e['name'] as String)
          .toList());
  int get year =>
      date.length >= 4 ? int.tryParse(date.substring(0, 4)) ?? 0 : 0;
}

final demoMovies = <Movie>[
  Movie(
      id: -1,
      title: 'Muestra de prueba · DEMO',
      overview:
          'Ficha ficticia incluida únicamente para probar favoritos, calificaciones y reseñas sin una clave de TMDB. No representa una película real ni incluye datos de catálogo.'),
];

class Tmdb {
  static const base = 'https://api.themoviedb.org/3';
  static const image = 'https://image.tmdb.org/t/p/w500';
  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String> extra = const {}]) async {
    if (apiKey.isEmpty) throw const ApiSetupException();
    final uri = Uri.parse('$base$path').replace(
        queryParameters: {'api_key': apiKey, 'language': 'es-MX', ...extra});
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('TMDB respondió con código ${response.statusCode}.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Movie>> list(String path,
          [Map<String, String> extra = const {}]) async =>
      ((await _get(path, extra))['results'] as List)
          .map((e) => Movie.fromJson(e))
          .toList();
  Future<List<Movie>> search(String query) async => ((await _get(
              '/search/movie', {'query': query, 'region': 'MX'}))['results']
          as List)
      .map((e) => Movie.fromJson(e))
      .toList();
  Future<Movie> details(Movie movie) async {
    final data =
        await _get('/movie/${movie.id}', {'append_to_response': 'credits'});
    final credits = data['credits'] as Map<String, dynamic>? ?? {};
    return Movie.fromJson(data).withCredits(credits);
  }

  Future<Map<String, dynamic>> providers(int id) async {
    final data = await _get('/movie/$id/watch/providers');
    return Map<String, dynamic>.from(data['results']?['MX'] ?? {});
  }
}

class ApiSetupException implements Exception {
  const ApiSetupException();
}

class LocalStore {
  LocalStore._();
  static final instance = LocalStore._();
  Database? _db;
  Future<Database> get db async => _db ??= await openDatabase(
          p.join(await getDatabasesPath(), 'cinefinder.db'),
          version: 1, onCreate: (db, _) async {
        await db.execute(
            'CREATE TABLE favorites(movieId INTEGER PRIMARY KEY, title TEXT, poster TEXT, rating REAL, date TEXT)');
        await db.execute(
            'CREATE TABLE reviews(id INTEGER PRIMARY KEY AUTOINCREMENT, movieId INTEGER UNIQUE, title TEXT, poster TEXT, content TEXT, stars INTEGER, createdAt TEXT, updatedAt TEXT)');
        await db.execute(
            'CREATE TABLE ratings(movieId INTEGER PRIMARY KEY, stars INTEGER, updatedAt TEXT)');
      });
  Future<List<Map<String, Object?>>> favorites() async =>
      (await (await db).query('favorites', orderBy: 'rowid DESC'));
  Future<bool> isFavorite(int id) async =>
      (await (await db).query('favorites', where: 'movieId=?', whereArgs: [id]))
          .isNotEmpty;
  Future<void> toggleFavorite(Movie m) async {
    final d = await db;
    if (await isFavorite(m.id)) {
      await d.delete('favorites', where: 'movieId=?', whereArgs: [m.id]);
    } else {
      await d.insert('favorites', {
        'movieId': m.id,
        'title': m.title,
        'poster': m.poster,
        'rating': m.rating,
        'date': m.date
      });
    }
  }

  Future<List<Map<String, Object?>>> reviews() async =>
      (await (await db).query('reviews', orderBy: 'updatedAt DESC'));
  Future<Map<String, Object?>?> review(int id) async {
    final x =
        await (await db).query('reviews', where: 'movieId=?', whereArgs: [id]);
    return x.firstOrNull;
  }

  Future<int> rating(int id) async {
    final rows = await (await db).query('ratings',
        columns: ['stars'], where: 'movieId=?', whereArgs: [id]);
    return rows.firstOrNull?['stars'] as int? ?? 0;
  }

  Future<void> saveRating(int id, int stars) async {
    await (await db).insert(
        'ratings',
        {
          'movieId': id,
          'stars': stars,
          'updatedAt': DateTime.now().toIso8601String()
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveReview(Movie m, String content, int stars,
      {int? existingId}) async {
    final d = await db;
    final now = DateTime.now().toIso8601String();
    final prior = await review(m.id);
    final row = {
      'movieId': m.id,
      'title': m.title,
      'poster': m.poster,
      'content': content.trim(),
      'stars': stars,
      'createdAt': prior?['createdAt'] ?? now,
      'updatedAt': now
    };
    await d.insert('reviews', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
    await d.insert(
        'ratings', {'movieId': m.id, 'stars': stars, 'updatedAt': now},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteReview(int id) async =>
      (await db).delete('reviews', where: 'id=?', whereArgs: [id]);
  Future<void> deleteFavorite(int id) async =>
      (await db).delete('favorites', where: 'movieId=?', whereArgs: [id]);
  Future<int> count(String table) async =>
      Sqflite.firstIntValue(
          await (await db).rawQuery('SELECT COUNT(*) FROM $table')) ??
      0;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selected = 0;
  final favoritesKey = GlobalKey<_FavoritesPageState>();
  final profileKey = GlobalKey<_ProfilePageState>();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: selected, children: [
          const HomePage(),
          const SearchPage(),
          const CinemasPage(),
          FavoritesPage(key: favoritesKey),
          ProfilePage(key: profileKey)
        ]),
        bottomNavigationBar: NavigationBar(
            selectedIndex: selected,
            onDestinationSelected: (i) {
              if (i == 3) favoritesKey.currentState?.refresh();
              if (i == 4) profileKey.currentState?.refresh();
              setState(() => selected = i);
            },
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.movie_outlined),
                  selectedIcon: Icon(Icons.movie),
                  label: 'Inicio'),
              NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
              NavigationDestination(
                  icon: Icon(Icons.location_on_outlined),
                  selectedIcon: Icon(Icons.location_on),
                  label: 'Cines'),
              NavigationDestination(
                  icon: Icon(Icons.favorite_border),
                  selectedIcon: Icon(Icons.favorite),
                  label: 'Favoritos'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Perfil'),
            ]),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final api = Tmdb();
  late Future<List<Movie>> popular;
  late Future<List<Movie>> trending;
  late Future<List<Movie>> nowPlaying;
  @override
  void initState() {
    super.initState();
    popular =
        apiKey.isEmpty ? Future.value(demoMovies) : api.list('/movie/popular');
    trending = apiKey.isEmpty
        ? Future.value(demoMovies)
        : api.list('/trending/movie/week');
    nowPlaying = apiKey.isEmpty
        ? Future.value([])
        : api.list('/movie/now_playing', {'region': 'MX'});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Brand()),
      body: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              popular = apiKey.isEmpty
                  ? Future.value(demoMovies)
                  : api.list('/movie/popular');
              trending = apiKey.isEmpty
                  ? Future.value(demoMovies)
                  : api.list('/trending/movie/week');
              nowPlaying = apiKey.isEmpty
                  ? Future.value([])
                  : api.list('/movie/now_playing', {'region': 'MX'});
            });
            await Future.wait([popular, trending, nowPlaying]);
          },
          child:
              ListView(padding: const EdgeInsets.only(bottom: 28), children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tu próxima película\nfavorita te espera.',
                          style: TextStyle(
                              fontSize: 28,
                              height: 1.18,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text('Descubre qué ver hoy.',
                          style: TextStyle(color: Colors.white60)),
                      const SizedBox(height: 20),
                      if (apiKey.isEmpty) const ApiNotice(),
                    ])),
            FutureBuilder<List<Movie>>(
                future: trending,
                builder: (c, s) => s.hasData
                    ? s.data!.isNotEmpty
                        ? Featured(movie: s.data!.first)
                        : const SizedBox.shrink()
                    : s.hasError
                        ? const SizedBox.shrink()
                        : const _FeaturedLoading()),
            MovieRail(title: 'Populares ahora', future: popular),
            MovieRail(title: 'Tendencias de la semana', future: trending),
            MovieRail(title: 'En cartelera', future: nowPlaying),
          ])));
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.local_movies, color: accent, size: 25),
        const SizedBox(width: 8),
        RichText(
            text: const TextSpan(
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                children: [
              TextSpan(text: 'CINE', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'FINDER', style: TextStyle(color: accent))
            ]))
      ]);
}

class ApiNotice extends StatelessWidget {
  const ApiNotice({super.key});
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, color: violet),
            const SizedBox(width: 12),
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Modo de demostración · conecta TMDB',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 5),
                  Text(
                      'Las fichas marcadas DEMO son ficticias y sirven para probar tus reseñas y favoritos. Configura TMDB_API_KEY para ver el catálogo real.',
                      style: TextStyle(color: Colors.white60, fontSize: 13))
                ]))
          ])));
}

class Featured extends StatelessWidget {
  final Movie movie;
  const Featured({super.key, required this.movie});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
          onTap: () => openMovie(context, movie),
          child: SizedBox(
              height: 240,
              child: Stack(fit: StackFit.expand, children: [
                Poster(
                    path: movie.backdrop.isNotEmpty
                        ? movie.backdrop
                        : movie.poster,
                    wide: true),
                DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                      Colors.black.withValues(alpha: .05),
                      Colors.black.withValues(alpha: .9)
                    ]))),
                Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DESTACADA',
                              style: TextStyle(
                                  color: Color(0xFFFFC857),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  fontSize: 11)),
                          const SizedBox(height: 6),
                          Text(movie.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w800)),
                          if (movie.id < 0)
                            const Text('DEMO · contenido de prueba',
                                style: TextStyle(
                                    color: Color(0xFFFFC857), fontSize: 12)),
                          const SizedBox(height: 8),
                          Row(children: [
                            Rating(movie.rating),
                            const SizedBox(width: 12),
                            Text('${movie.year}',
                                style: const TextStyle(color: Colors.white70)),
                            const Spacer(),
                            FilledButton(
                                onPressed: () => openMovie(context, movie),
                                child: const Text('Ver película'))
                          ])
                        ]))
              ]))));
}

class _FeaturedLoading extends StatelessWidget {
  const _FeaturedLoading();
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
          height: 220,
          child: Card(
              child: Center(child: CircularProgressIndicator(color: accent)))));
}

class MovieRail extends StatelessWidget {
  final String title;
  final Future<List<Movie>> future;
  const MovieRail({super.key, required this.title, required this.future});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Movie>>(
      future: future,
      builder: (c, s) {
        if (s.hasError) return const SizedBox.shrink();
        if (!s.hasData) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800))),
                const SizedBox(
                    height: 220,
                    child:
                        Center(child: CircularProgressIndicator(color: accent)))
              ]);
        }
        if (s.data!.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800))),
          SizedBox(
              height: 220,
              child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: s.data!.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (c, i) => MovieTile(movie: s.data![i])))
        ]);
      });
}

class MovieTile extends StatelessWidget {
  final Movie movie;
  const MovieTile({super.key, required this.movie});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 128,
      child: InkWell(
          onTap: () => openMovie(context, movie),
          borderRadius: BorderRadius.circular(15),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child:
                      SizedBox(width: 128, child: Poster(path: movie.poster))),
            ),
            const SizedBox(height: 8),
            Text(movie.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            if (movie.id < 0)
              const Text('DEMO · ejemplo',
                  style: TextStyle(color: Color(0xFFFFC857), fontSize: 11))
            else
              Rating(movie.rating, small: true)
          ])));
}

class Poster extends StatelessWidget {
  final String path;
  final bool wide;
  const Poster({super.key, required this.path, this.wide = false});
  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return _fallback();
    return Image.network('${Tmdb.image}$path',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (c, child, progress) => progress == null
            ? child
            : Container(
                color: surface,
                alignment: Alignment.center,
                child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: accent))),
        errorBuilder: (_, __, ___) => _fallback());
  }

  Widget _fallback() => Container(
      color: surface,
      alignment: Alignment.center,
      child: Icon(Icons.local_movies_outlined,
          color: Colors.white24, size: wide ? 54 : 34));
}

class Rating extends StatelessWidget {
  final double value;
  final bool small;
  const Rating(this.value, {super.key, this.small = false});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.star_rounded,
            color: const Color(0xFFFFC857), size: small ? 15 : 18),
        const SizedBox(width: 3),
        Text(value == 0 ? '—' : value.toStringAsFixed(1),
            style: TextStyle(
                fontSize: small ? 12 : 14, fontWeight: FontWeight.w700))
      ]);
}

Future<void> openMovie(BuildContext context, Movie movie) async {
  await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => MovieDetails(movie: movie)));
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final ctl = TextEditingController();
  final api = Tmdb();
  List<Movie> results = [];
  bool loading = false, searched = false;
  String? error;
  Future<void> search() async {
    final q = ctl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
      searched = true;
    });
    if (apiKey.isEmpty) {
      results = demoMovies
          .where((movie) => movie.title.toLowerCase().contains(q.toLowerCase()))
          .toList();
      if (mounted) setState(() => loading = false);
      return;
    }
    try {
      results = await api.search(q);
    } catch (e) {
      error = e is ApiSetupException
          ? 'Configura TMDB_API_KEY para buscar películas.'
          : 'No se pudo completar la búsqueda. Revisa tu conexión e inténtalo de nuevo.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Text('Buscar películas',
              style: TextStyle(fontWeight: FontWeight.w800))),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: TextField(
                controller: ctl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => search(),
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Título de película',
                    suffixIcon: IconButton(
                        onPressed: search,
                        icon:
                            const Icon(Icons.arrow_forward, color: accent))))),
        Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: accent))
                : error != null
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white60))))
                    : results.isEmpty
                        ? EmptyState(
                            icon: Icons.movie_filter_outlined,
                            title: searched
                                ? 'No encontramos películas'
                                : 'Busca tu próxima película',
                            message: searched
                                ? 'Prueba con otro título.'
                                : 'Busca por título para explorar el catálogo de TMDB.')
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: .53,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 16),
                            itemCount: results.length,
                            itemBuilder: (c, i) =>
                                SearchResult(movie: results[i])))
      ]));
}

class SearchResult extends StatelessWidget {
  final Movie movie;
  const SearchResult({super.key, required this.movie});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: () => openMovie(context, movie),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: SizedBox(
                    width: double.infinity,
                    child: Poster(path: movie.poster)))),
        const SizedBox(height: 7),
        Text(movie.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 3),
        Text(movie.year == 0 ? '—' : '${movie.year}',
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        if (movie.id < 0)
          const Text('DEMO · ejemplo',
              style: TextStyle(color: Color(0xFFFFC857), fontSize: 10))
        else
          Rating(movie.rating, small: true)
      ]));
}

class MovieDetails extends StatefulWidget {
  final Movie movie;
  const MovieDetails({super.key, required this.movie});
  @override
  State<MovieDetails> createState() => _MovieDetailsState();
}

class _MovieDetailsState extends State<MovieDetails> {
  late Movie movie = widget.movie;
  bool favorite = false;
  bool loading = false;
  int personalStars = 0;
  Map<String, List<dynamic>> providerGroups = {};
  String? providerLink;
  Map<String, Object?>? review;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    favorite = await LocalStore.instance.isFavorite(movie.id);
    review = await LocalStore.instance.review(movie.id);
    personalStars = await LocalStore.instance.rating(movie.id);
    if (apiKey.isNotEmpty) {
      try {
        movie = await Tmdb().details(movie);
        final availability = await Tmdb().providers(movie.id);
        providerLink = availability['link'] as String?;
        providerGroups = {
          for (final type in ['flatrate', 'rent', 'buy'])
            if (availability[type] is List)
              type: List<dynamic>.from(availability[type] as List)
        };
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  Future<void> _editReview() async {
    final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
            builder: (_) => ReviewEditor(
                movie: movie, existing: review, initialStars: personalStars)));
    if (result != null) {
      await LocalStore.instance
          .saveReview(movie, result['content'], result['stars']);
      review = await LocalStore.instance.review(movie.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          body: CustomScrollView(slivers: [
        SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            actions: [
              IconButton(
                  onPressed: () async {
                    await LocalStore.instance.toggleFavorite(movie);
                    favorite = !favorite;
                    if (mounted) setState(() {});
                  },
                  icon: Icon(favorite ? Icons.favorite : Icons.favorite_border,
                      color: favorite ? accent : null)),
              IconButton(
                  onPressed: () => _shareReview(),
                  icon: const Icon(Icons.ios_share))
            ],
            flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
              Poster(
                  path:
                      movie.backdrop.isNotEmpty ? movie.backdrop : movie.poster,
                  wide: true),
              DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                    Colors.transparent,
                    bg.withValues(alpha: .95)
                  ])))
            ]))),
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(movie.title,
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800)),
                      if (movie.id < 0)
                        const Card(
                            child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                    'DEMO: esta ficha es ficticia y solo sirve para probar funciones locales.'))),
                      const SizedBox(height: 10),
                      Wrap(spacing: 14, runSpacing: 8, children: [
                        Rating(movie.rating),
                        _meta('${movie.year}', Icons.calendar_today),
                        if (movie.runtime != null)
                          _meta('${movie.runtime} min', Icons.schedule)
                      ]),
                      const SizedBox(height: 18),
                      const SectionTitle('Tu calificación'),
                      const SizedBox(height: 4),
                      Row(
                          children: List.generate(
                              5,
                              (i) => IconButton(
                                  tooltip: '${i + 1} estrellas',
                                  onPressed: () async {
                                    personalStars = i + 1;
                                    await LocalStore.instance
                                        .saveRating(movie.id, personalStars);
                                    if (mounted) setState(() {});
                                  },
                                  icon: Icon(
                                      i < personalStars
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: const Color(0xFFFFC857),
                                      size: 30)))),
                      if (movie.genres.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Wrap(
                                spacing: 8,
                                children: movie.genres
                                    .map((x) => Chip(
                                        label: Text(x),
                                        visualDensity: VisualDensity.compact,
                                        side: BorderSide.none,
                                        backgroundColor: surface))
                                    .toList())),
                      const SizedBox(height: 18),
                      const SectionTitle('Sinopsis'),
                      const SizedBox(height: 6),
                      Text(
                          movie.overview.isEmpty
                              ? 'No hay sinopsis disponible.'
                              : movie.overview,
                          style: const TextStyle(
                              color: Colors.white70, height: 1.55)),
                      if (movie.director != null || movie.cast.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        const SectionTitle('Créditos'),
                        if (movie.director != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Text('Dirección · ${movie.director}',
                                  style:
                                      const TextStyle(color: Colors.white70))),
                        if (movie.cast.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Reparto · ${movie.cast.join(', ')}',
                                  style:
                                      const TextStyle(color: Colors.white70)))
                      ],
                      const SizedBox(height: 22),
                      const SectionTitle('Disponible en México'),
                      const SizedBox(height: 8),
                      if (apiKey.isEmpty)
                        const Text(
                            'Configura TMDB para consultar disponibilidad.',
                            style: TextStyle(color: Colors.white54))
                      else if (providerGroups.isEmpty)
                        const Text(
                            'No encontramos información de streaming para esta película en tu región.',
                            style: TextStyle(color: Colors.white54))
                      else
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final group in providerGroups.entries) ...[
                                Text(
                                    switch (group.key) {
                                      'flatrate' => 'Suscripción',
                                      'rent' => 'Renta',
                                      _ => 'Compra'
                                    },
                                    style:
                                        const TextStyle(color: Colors.white60)),
                                Wrap(
                                    spacing: 8,
                                    children: group.value
                                        .map((x) => Chip(
                                            avatar: CircleAvatar(
                                                backgroundImage: NetworkImage(
                                                    '${Tmdb.image}${x['logo_path']}')),
                                            label: Text(x['provider_name'])))
                                        .toList()),
                              ],
                              if (providerLink != null)
                                TextButton.icon(
                                    onPressed: () => launchUrl(
                                        Uri.parse(providerLink!),
                                        mode: LaunchMode.externalApplication),
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Ver opciones en TMDB'))
                            ]),
                      const SizedBox(height: 22),
                      Row(children: [
                        const Expanded(child: SectionTitle('Tu reseña')),
                        TextButton.icon(
                            onPressed: _editReview,
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(review == null ? 'Escribir' : 'Editar'))
                      ]),
                      if (review == null)
                        const Text('Aún no has escrito una reseña.',
                            style: TextStyle(color: Colors.white54))
                      else
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('★' * (review!['stars'] as int),
                                          style: const TextStyle(
                                              color: Color(0xFFFFC857),
                                              fontSize: 18)),
                                      const SizedBox(height: 8),
                                      Text('${review!['content']}')
                                    ]))),
                      const SizedBox(height: 20),
                      if (review != null)
                        OutlinedButton.icon(
                            onPressed: _shareReview,
                            icon: const Icon(Icons.share),
                            label: const Text('Compartir reseña'))
                    ])))
      ]));
  Widget _meta(String text, IconData icon) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.white54),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: Colors.white70))
      ]);
  Future<void> _shareReview() async {
    final r = review;
    if (r == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Escribe una reseña antes de compartirla.')));
      return;
    }
    Share.share(
        '🎬 ${movie.title}\n${'★' * (r['stars'] as int)}\n\n${r['content']}\n\n— CineFinder');
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800));
}

class ReviewEditor extends StatefulWidget {
  final Movie movie;
  final Map<String, Object?>? existing;
  final int initialStars;
  const ReviewEditor(
      {super.key, required this.movie, this.existing, this.initialStars = 0});
  @override
  State<ReviewEditor> createState() => _ReviewEditorState();
}

class _ReviewEditorState extends State<ReviewEditor> {
  late int stars = widget.existing?['stars'] as int? ?? widget.initialStars;
  late final ctl =
      TextEditingController(text: widget.existing?['content'] as String? ?? '');
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(
              widget.existing == null ? 'Escribir reseña' : 'Editar reseña')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(widget.movie.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        const Text('Tu calificación',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(
            children: List.generate(
                5,
                (i) => IconButton(
                    onPressed: () => setState(() => stars = i + 1),
                    icon: Icon(
                        i < stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: const Color(0xFFFFC857),
                        size: 36)))),
        const SizedBox(height: 18),
        TextField(
            controller: ctl,
            onChanged: (_) => setState(() {}),
            minLines: 5,
            maxLines: 9,
            maxLength: 1000,
            decoration: const InputDecoration(
                hintText: '¿Qué te pareció la película?')),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: stars == 0 || ctl.text.trim().isEmpty
                ? null
                : () => Navigator.pop(
                    context, {'stars': stars, 'content': ctl.text.trim()}),
            child: const Text('Guardar reseña'))
      ]));
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Future<List<Map<String, Object?>>> favorites;
  @override
  void initState() {
    super.initState();
    favorites = LocalStore.instance.favorites();
  }

  void refresh() => setState(() => favorites = LocalStore.instance.favorites());

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Text('Mis favoritos',
              style: TextStyle(fontWeight: FontWeight.w800))),
      body: FutureBuilder<List<Map<String, Object?>>>(
          future: favorites,
          builder: (c, s) {
            if (!s.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: accent));
            }
            final rows = s.data!;
            if (rows.isEmpty) {
              return const EmptyState(
                  icon: Icons.favorite_border,
                  title: 'Tu lista empieza aquí',
                  message:
                      'Guarda películas que quieras ver y aparecerán en esta sección.');
            }
            return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                itemBuilder: (c, i) {
                  final r = rows[i];
                  final m = Movie(
                      id: r['movieId'] as int,
                      title: r['title'] as String,
                      poster: r['poster'] as String,
                      date: r['date'] as String,
                      rating: (r['rating'] as num).toDouble());
                  return Card(
                      child: ListTile(
                          contentPadding: const EdgeInsets.all(8),
                          leading: SizedBox(
                              width: 55,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Poster(path: m.poster))),
                          title: Text(m.title,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Rating(m.rating, small: true),
                          onTap: () async {
                            await openMovie(context, m);
                            if (mounted) setState(() {});
                          },
                          trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.white60),
                              onPressed: () async {
                                await LocalStore.instance.deleteFavorite(m.id);
                                refresh();
                              })));
                });
          }));
}

class CinemasPage extends StatefulWidget {
  const CinemasPage({super.key});
  @override
  State<CinemasPage> createState() => _CinemasPageState();
}

class _CinemasPageState extends State<CinemasPage> {
  final city = TextEditingController();
  String? status;
  bool loading = false;
  Position? position;
  Future<void> locate() async {
    setState(() {
      loading = true;
      status = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        status =
            'Ubicación denegada. Busca una ciudad para abrir los cines en Maps.';
      } else {
        position = await Geolocator.getCurrentPosition(
                locationSettings:
                    const LocationSettings(accuracy: LocationAccuracy.medium))
            .timeout(const Duration(seconds: 12));
        status = 'Abriendo cines cercanos en Google Maps…';
        final uri = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${position!.latitude},${position!.longitude}+cines');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      status = 'No se pudo obtener la ubicación. Busca manualmente por ciudad.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> searchCity() async {
    if (city.text.trim().isEmpty) {
      setState(() => status = 'Escribe una ciudad para buscar.');
      return;
    }
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('cines en ${city.text.trim()}')}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    setState(() => status =
        'Resultados de cines abiertos en Google Maps. CineFinder no proporciona cartelera ni datos de salas.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Text('Cines cercanos',
              style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Container(
            height: 170,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                    colors: [Color(0xFF49225B), Color(0xFF201B32)])),
            child: const Stack(children: [
              Positioned(
                  right: 18,
                  bottom: 12,
                  child: Icon(Icons.location_on,
                      size: 100, color: Colors.white12)),
              Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on, color: Color(0xFFB79BFF)),
                        SizedBox(height: 10),
                        Text('Encuentra un cine\ncerca de ti',
                            style: TextStyle(
                                fontSize: 23, fontWeight: FontWeight.w800)),
                        SizedBox(height: 6),
                        Text(
                            'Usa Maps para consultar salas y horarios actuales.',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12))
                      ]))
            ])),
        const SizedBox(height: 20),
        FilledButton.icon(
            onPressed: loading ? null : locate,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
            label:
                Text(loading ? 'Buscando ubicación…' : 'Buscar cerca de mí')),
        const SizedBox(height: 24),
        const SectionTitle('O busca por ciudad'),
        const SizedBox(height: 10),
        TextField(
            controller: city,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => searchCity(),
            decoration: InputDecoration(
                hintText: 'Ej. Saltillo, Coahuila',
                suffixIcon: IconButton(
                    onPressed: searchCity,
                    icon: const Icon(Icons.search, color: accent)))),
        const SizedBox(height: 14),
        if (status != null)
          Text(status!,
              style: const TextStyle(color: Colors.white60, height: 1.5)),
        const SizedBox(height: 12),
        const Text(
            'Los horarios de películas requieren una fuente local confiable; no se muestran datos de cartelera inventados.',
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5))
      ]));
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final name = TextEditingController();
  int favs = 0, reviews = 0;
  bool ready = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    name.text = prefs.getString('username') ?? 'Cinéfilo';
    favs = await LocalStore.instance.count('favorites');
    reviews = await LocalStore.instance.count('reviews');
    if (mounted) setState(() => ready = true);
  }

  void refresh() {
    setState(() => ready = false);
    _load();
  }

  Future<void> _editReview(Movie movie, Map<String, Object?> row) async {
    final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
            builder: (_) => ReviewEditor(movie: movie, existing: row)));
    if (result != null) {
      await LocalStore.instance.saveReview(
          movie, result['content'] as String, result['stars'] as int);
      refresh();
    }
  }

  Future<bool> _confirmDeleteReview() async =>
      await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('Eliminar reseña'),
                  content:
                      const Text('Esta reseña se quitará de este dispositivo.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Eliminar'))
                  ])) ??
      false;

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        'username', name.text.trim().isEmpty ? 'Cinéfilo' : name.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Perfil guardado.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Text('Mi perfil',
              style: TextStyle(fontWeight: FontWeight.w800))),
      body: !ready
          ? const Center(child: CircularProgressIndicator(color: accent))
          : ListView(padding: const EdgeInsets.all(20), children: [
              Center(
                  child: CircleAvatar(
                      radius: 44,
                      backgroundColor: violet.withValues(alpha: .2),
                      child:
                          const Icon(Icons.person, size: 48, color: violet))),
              const SizedBox(height: 14),
              const Center(
                  child: Text('Tu espacio cinéfilo',
                      style: TextStyle(color: Colors.white60))),
              const SizedBox(height: 22),
              TextField(
                  controller: name,
                  maxLength: 30,
                  decoration: const InputDecoration(
                      labelText: 'Nombre de usuario',
                      prefixIcon: Icon(Icons.badge_outlined))),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: _save, child: const Text('Guardar perfil')),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                    child: _StatCard(
                        number: '$favs',
                        label: 'Favoritos',
                        icon: Icons.favorite)),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatCard(
                        number: '$reviews',
                        label: 'Reseñas',
                        icon: Icons.rate_review))
              ]),
              const SizedBox(height: 24),
              const SectionTitle('Mis reseñas y calificaciones'),
              const SizedBox(height: 10),
              FutureBuilder<List<Map<String, Object?>>>(
                  future: LocalStore.instance.reviews(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                              child: CircularProgressIndicator(color: accent)));
                    }
                    final rows = snapshot.data!;
                    if (rows.isEmpty) {
                      return const Text('Tus reseñas aparecerán aquí.',
                          style: TextStyle(color: Colors.white54));
                    }
                    return Column(
                        children: rows.map((row) {
                      final movie = Movie(
                          id: row['movieId'] as int,
                          title: row['title'] as String,
                          poster: row['poster'] as String);
                      final updatedAt =
                          (row['updatedAt'] as String).split('T').first;
                      return Card(
                          child: ListTile(
                              contentPadding: const EdgeInsets.all(8),
                              leading: SizedBox(
                                  width: 48,
                                  child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Poster(path: movie.poster))),
                              title: Text(movie.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('★' * (row['stars'] as int),
                                        style: const TextStyle(
                                            color: Color(0xFFFFC857))),
                                    Text(row['content'] as String,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    Text('Actualizada: $updatedAt',
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11))
                                  ]),
                              trailing: PopupMenuButton<String>(
                                  onSelected: (action) async {
                                    if (action == 'edit') {
                                      await _editReview(movie, row);
                                    } else {
                                      if (await _confirmDeleteReview()) {
                                        await LocalStore.instance
                                            .deleteReview(row['id'] as int);
                                        refresh();
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                        PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Editar')),
                                        PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Eliminar'))
                                      ])));
                    }).toList());
                  }),
              const SizedBox(height: 24),
              const SectionTitle('Acerca de CineFinder'),
              const SizedBox(height: 10),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Datos de películas: TMDB',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            const Text(
                                'This product uses the TMDB API but is not endorsed or certified by TMDB.',
                                style: TextStyle(
                                    color: Colors.white70, height: 1.4)),
                            TextButton.icon(
                                onPressed: () => launchUrl(
                                    Uri.parse('https://www.themoviedb.org'),
                                    mode: LaunchMode.externalApplication),
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Visitar TMDB'))
                          ]))),
              const Card(
                  child: ListTile(
                      leading: Icon(Icons.info_outline, color: violet),
                      title: Text('CineFinder 1.0'),
                      subtitle: Text(
                          'Descubre películas y guarda tus opiniones en este dispositivo.'))),
              const Card(
                  child: ListTile(
                      leading: Icon(Icons.storage_outlined, color: violet),
                      title: Text('Datos locales'),
                      subtitle: Text(
                          'Tus reseñas, calificaciones y favoritos permanecen en el dispositivo.')))
            ]));
}

class _StatCard extends StatelessWidget {
  final String number, label;
  final IconData icon;
  const _StatCard(
      {required this.number, required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Icon(icon, color: accent),
            const SizedBox(height: 8),
            Text(number,
                style:
                    const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: Colors.white60))
          ])));
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, message;
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.message});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: violet, size: 48),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, height: 1.45))
          ])));
}
