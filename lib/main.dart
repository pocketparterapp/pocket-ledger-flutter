import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const PocketLedgerApp());

const ink = Color(0xFF17151D);
const muted = Color(0xFF8C8795);
const canvas = Color(0xFFF4F2F7);
const violet = Color(0xFF6844E8);
const pale = Color(0xFFECE7FF);
const coral = Color(0xFFFF795F);
const green = Color(0xFF35A987);

class PocketLedgerApp extends StatelessWidget {
  const PocketLedgerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pocket Ledger', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: canvas, colorScheme: ColorScheme.fromSeed(seedColor: violet)),
    home: const LedgerHome(),
  );
}

class Entry {
  Entry(this.title, this.category, this.amount, this.income, this.date);
  final String title, category;
  final double amount;
  final bool income;
  final DateTime date;
}

class LedgerHome extends StatefulWidget {
  const LedgerHome({super.key});
  @override
  State<LedgerHome> createState() => _LedgerHomeState();
}

class _LedgerHomeState extends State<LedgerHome> {
  int tab = 0;
  double income = 125000, expenses = 48500;
  final List<Entry> entries = [
    Entry('Monthly salary', 'Salary', 100000, true, DateTime.now()),
    Entry('Grocery shopping', 'Groceries', 8500, false, DateTime.now()),
    Entry('Fuel station', 'Transport', 4500, false, DateTime.now()),
    Entry('Freelance project', 'Freelance', 25000, true, DateTime.now()),
  ];
  double get balance => income - expenses;

  String money(num n) {
    final raw = n.round().toString();
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write(',');
      out.write(raw[i]);
    }
    return 'Rs. ' + out.toString();
  }

  Future<void> addEntry(bool isIncome) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final categories = isIncome
      ? ['Salary', 'Business', 'Freelance', 'Other']
      : ['Food', 'Groceries', 'Transport', 'Shopping', 'Bills', 'Health', 'Other'];
    var category = categories.first;
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(builder: (context, updateSheet) => Container(
        padding: EdgeInsets.fromLTRB(22, 14, 22, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE5E1EA), borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 22),
          Text(isIncome ? 'Add income' : 'Add expense', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: ink)),
          const SizedBox(height: 6), const Text('Enter your transaction details.', style: TextStyle(color: muted)),
          const SizedBox(height: 22), const _FieldLabel('AMOUNT'), const SizedBox(height: 8),
          TextField(controller: amount, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _decoration('0', prefix: 'Rs. '), style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18), const _FieldLabel('CATEGORY'), const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: categories.map((item) => ChoiceChip(label: Text(item), selected: category == item, selectedColor: pale, onSelected: (_) => updateSheet(() => category = item), labelStyle: TextStyle(color: category == item ? violet : ink, fontWeight: FontWeight.w600))).toList()),
          const SizedBox(height: 18), const _FieldLabel('NOTE (OPTIONAL)'), const SizedBox(height: 8),
          TextField(controller: note, decoration: _decoration('What was this for?')),
          const SizedBox(height: 22),
          SizedBox(width: double.infinity, height: 54, child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: isIncome ? violet : coral, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () {
              final value = double.tryParse(amount.text.trim());
              if (value == null || value <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
                return;
              }
              final description = note.text.trim();
              Navigator.pop(sheetContext);
              setState(() {
                if (isIncome) { income += value; } else { expenses += value; }
                entries.insert(0, Entry(description.isEmpty ? category : description, category, value, isIncome, DateTime.now()));
              });
            },
            child: Text(isIncome ? 'Save income' : 'Save expense', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          )),
        ])),
      )),
    );
    amount.dispose();
    note.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: IndexedStack(index: tab, children: [_dashboard(), _activity(), _calendar()])),
    bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), backgroundColor: Colors.white, indicatorColor: pale, destinations: const [
      NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'Activity'),
      NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'Calendar'),
    ]),
  );

  Widget _dashboard() => CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
    SliverPadding(padding: const EdgeInsets.fromLTRB(21, 18, 21, 28), sliver: SliverList(delegate: SliverChildListDelegate([
      _header(), const SizedBox(height: 28),
      const Text('TOTAL BALANCE', style: TextStyle(color: muted, fontSize: 10, letterSpacing: 1.7, fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      TweenAnimationBuilder<double>(key: ValueKey(balance), tween: Tween(begin: 0, end: balance), duration: const Duration(milliseconds: 950), curve: Curves.easeOutCubic, builder: (_, v, __) => Text(money(v), style: const TextStyle(color: ink, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.4))),
      const SizedBox(height: 18), _overview(), const SizedBox(height: 17),
      Row(children: [Expanded(child: _action('Add income', Icons.add_rounded, violet, () => addEntry(true))), const SizedBox(width: 12), Expanded(child: _action('Add expense', Icons.remove_rounded, coral, () => addEntry(false)))]),
      const SizedBox(height: 28),
      Row(children: [const Expanded(child: Text('Spending breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink))), Text(money(expenses), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: muted))]),
      const SizedBox(height: 15),
      _spend('Food & groceries', 'Rs. 18,500', .76, violet),
      _spend('Transport', 'Rs. 12,000', .49, coral),
      _spend('Shopping', 'Rs. 8,000', .34, const Color(0xFF8C75E8)),
      _spend('Bills & utilities', 'Rs. 10,000', .41, green),
      const SizedBox(height: 13), _heading('Recent transactions', 'View all', () => setState(() => tab = 1)),
      const SizedBox(height: 12), ...entries.take(4).map(_tile),
    ]))),
  ]);

  Widget _header() => Row(children: [
    Container(width: 44, height: 44, decoration: BoxDecoration(color: violet, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 23)),
    const SizedBox(width: 11),
    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Pocket Ledger', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: ink)), SizedBox(height: 2), Text('YOUR MONEY, IN CONTROL', style: TextStyle(fontSize: 9, letterSpacing: 1.3, color: muted, fontWeight: FontWeight.w700))])),
    Container(width: 43, height: 43, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.notifications_none_rounded, color: ink)),
  ]);

  Widget _overview() {
    final ratio = income <= 0 ? 0.0 : (expenses / income).clamp(0.0, 1.0);
    return Container(padding: const EdgeInsets.all(19), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: violet.withOpacity(.055), blurRadius: 22, offset: const Offset(0, 9))]), child: Column(children: [
      Row(children: [const Expanded(child: Text('Balance overview', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ink))), Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: pale, borderRadius: BorderRadius.circular(30)), child: const Text('This month', style: TextStyle(color: violet, fontSize: 10, fontWeight: FontWeight.w800)))]),
      const SizedBox(height: 19),
      Row(children: [
        SizedBox(width: 139, height: 139, child: CustomPaint(painter: _RingPainter(ratio), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('SAVED', style: TextStyle(color: muted, fontSize: 9, letterSpacing: 1.4, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(((1-ratio)*100).round().toString() + '%', style: const TextStyle(color: ink, fontSize: 25, fontWeight: FontWeight.w900))])))),
        const SizedBox(width: 22),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_legend('Income', money(income), violet), const SizedBox(height: 15), _legend('Expenses', money(expenses), coral), const SizedBox(height: 15), _legend('Net balance', money(balance), const Color(0xFF6471B2))])),
      ]),
    ]));
  }

  Widget _legend(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 7), Text(label, style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w600))]),
    const SizedBox(height: 4), Text(value, style: const TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w800)),
  ]);

  Widget _action(String title, IconData icon, Color color, VoidCallback tap) => Material(color: color, borderRadius: BorderRadius.circular(16), child: InkWell(onTap: tap, borderRadius: BorderRadius.circular(16), child: SizedBox(height: 54, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 7), Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))]))));

  Widget _spend(String title, String value, double progress, Color color) => Padding(padding: const EdgeInsets.only(bottom: 15), child: Column(children: [
    Row(children: [Expanded(child: Text(title, style: const TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w700))), Text(value, style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700))]),
    const SizedBox(height: 8), ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: progress, minHeight: 7, backgroundColor: const Color(0xFFEAE7EF), valueColor: AlwaysStoppedAnimation(color))),
  ]));

  Widget _heading(String title, String action, VoidCallback tap) => Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink))), TextButton(onPressed: tap, child: Text(action, style: const TextStyle(color: violet, fontWeight: FontWeight.w800, fontSize: 11)))]);

  Widget _tile(Entry e) {
    final color = e.income ? green : coral;
    return Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17)), child: Row(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withOpacity(.11), borderRadius: BorderRadius.circular(13)), child: Icon(e.income ? Icons.south_west_rounded : Icons.north_east_rounded, color: color, size: 19)),
      const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e.title, style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 12)), const SizedBox(height: 4), Text(e.category, style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w600))])),
      Text((e.income ? '+' : '-') + money(e.amount), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
    ]));
  }

  Widget _activity() => Padding(padding: const EdgeInsets.fromLTRB(21, 22, 21, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Activity', style: TextStyle(color: ink, fontSize: 27, fontWeight: FontWeight.w900)), const SizedBox(height: 5), const Text('Your income and expenses in one place.', style: TextStyle(color: muted, fontSize: 12)),
    const SizedBox(height: 20), Row(children: [Expanded(child: _total('Income', income, green)), const SizedBox(width: 10), Expanded(child: _total('Expenses', expenses, coral))]),
    const SizedBox(height: 20), const Text('All transactions', style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 12),
    Expanded(child: ListView(children: entries.map(_tile).toList())),
  ]));

  Widget _total(String label, double value, Color color) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: muted, fontSize: 11)), const SizedBox(height: 7), Text(money(value), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14))]));

  Widget _calendar() {
    final now = DateTime.now();
    final count = DateTime(now.year, now.month + 1, 0).day;
    final offset = DateTime(now.year, now.month, 1).weekday - 1;
    return Padding(padding: const EdgeInsets.fromLTRB(21, 22, 21, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Calendar', style: TextStyle(color: ink, fontSize: 27, fontWeight: FontWeight.w900)), const SizedBox(height: 5), const Text('A quick view of your monthly activity.', style: TextStyle(color: muted, fontSize: 12)), const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)), child: Column(children: [
        Text(_month(now.month) + ' ' + now.year.toString(), style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 17),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [for (final d in ['M','T','W','T','F','S','S']) SizedBox(width: 30, child: Center(child: Text(d, style: TextStyle(color: muted, fontWeight: FontWeight.w800, fontSize: 11))))]),
        const SizedBox(height: 9),
        GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: offset + count, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 5, crossAxisSpacing: 5), itemBuilder: (_, i) {
          final day = i - offset + 1;
          if (day < 1 || day > count) return const SizedBox();
          final selected = day == now.day;
          return Container(decoration: BoxDecoration(color: selected ? violet : Colors.transparent, shape: BoxShape.circle), child: Center(child: Text(day.toString(), style: TextStyle(color: selected ? Colors.white : ink, fontWeight: selected ? FontWeight.w900 : FontWeight.w500, fontSize: 12))));
        }),
      ])),
      const SizedBox(height: 18), const Text('Today', style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 10),
      Expanded(child: ListView(children: entries.where((e) => e.date.day == now.day && e.date.month == now.month && e.date.year == now.year).map(_tile).toList())),
    ]));
  }

  String _month(int m) => const ['January','February','March','April','May','June','July','August','September','October','November','December'][m - 1];
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(label, style: const TextStyle(color: muted, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w800));
}

InputDecoration _decoration(String hint, {String? prefix}) => InputDecoration(hintText: hint, prefixText: prefix, filled: true, fillColor: canvas, contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: violet, width: 1.2)));

class _RingPainter extends CustomPainter {
  _RingPainter(this.ratio);
  final double ratio;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final base = Paint()..color = const Color(0xFFECE9F1)..style = PaintingStyle.stroke..strokeWidth = 13;
    final incomePaint = Paint()..color = violet..style = PaintingStyle.stroke..strokeWidth = 13..strokeCap = StrokeCap.round;
    final expensePaint = Paint()..color = coral..style = PaintingStyle.stroke..strokeWidth = 13..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, base);
    final sweep = ratio * math.pi * 2;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 - sweep, false, incomePaint);
    if (sweep > .01) canvas.drawArc(rect, -math.pi / 2 + math.pi * 2 - sweep, sweep, false, expensePaint);
  }
  @override
  bool shouldRepaint(covariant _RingPainter old) => old.ratio != ratio;
}
