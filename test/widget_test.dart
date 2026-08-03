import 'package:campus_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows missing Mapbox configuration screen', (tester) async {
    await tester.pumpWidget(const MissingMapboxTokenApp());

    expect(
      find.text('Missing Mapbox configuration'),
      findsOneWidget,
    );
  });
}