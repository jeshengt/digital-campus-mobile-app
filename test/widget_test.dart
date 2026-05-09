import 'package:flutter_test/flutter_test.dart';
import 'package:utmgo/app/app.dart';

void main() {
  testWidgets('shows Firebase setup screen when configuration is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const UtmGoApp(
        isFirebaseReady: false,
        firebaseErrorMessage: 'No Firebase app has been configured.',
      ),
    );

    expect(find.text('Firebase setup required'), findsOneWidget);
    expect(find.text('Next setup step'), findsOneWidget);
  });
}
