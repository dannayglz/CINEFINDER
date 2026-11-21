import 'package:flutter_test/flutter_test.dart';
import 'package:cine_finder/main.dart';

void main() {
  testWidgets('shows CineFinder branding and the five main destinations',
      (tester) async {
    await tester.pumpWidget(const CineFinderApp());
    // The app contains network loading indicators, so only pump a frame here.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(Brand), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Buscar'), findsOneWidget);
    expect(find.text('Cines'), findsOneWidget);
    expect(find.text('Favoritos'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });
}
