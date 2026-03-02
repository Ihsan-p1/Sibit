import 'package:flutter_test/flutter_test.dart';
import 'package:sibit_app/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SibitApp(isJailbroken: false));
    expect(find.text('Selamat Datang, Pekerja'), findsOneWidget);
  });
}
