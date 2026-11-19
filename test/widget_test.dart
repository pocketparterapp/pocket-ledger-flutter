import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/main.dart';

void main() {
  testWidgets('Pocket Ledger dashboard starts', (tester) async {
    await tester.pumpWidget(const PocketLedgerApp());
    await tester.pump();

    expect(find.text('Pocket Ledger'), findsOneWidget);
    expect(find.text('TOTAL BALANCE'), findsOneWidget);
    expect(find.text('Add income'), findsOneWidget);
    expect(find.text('Add expense'), findsOneWidget);
  });
}
