import 'dart:convert';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const navy = Color(0xFF0F172A), green = Color(0xFF10B981), coral = Color(0xFFE11D48), canvas = Color(0xFFF4F6FA);
const icons = [Icons.restaurant, Icons.directions_car, Icons.shopping_bag, Icons.receipt_long, Icons.favorite, Icons.movie, Icons.payments, Icons.work, Icons.card_giftcard, Icons.savings];
const colors = [0xFF6366F1, 0xFF14B8A6, 0xFFF59E0B, 0xFFEF4444, 0xFFEC4899, 0xFF8B5CF6, 0xFF10B981, 0xFF0EA5E9, 0xFFF97316, 0xFF64748B];
const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String pkr(num v) => 'Rs ${v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';
String fd(DateTime d) => '${d.day} ${months[d.month - 1]} ${d.year}';
double sum(Iterable<Map> l, String t) => l.where((x) => x['t'] == t).fold<double>(0, (a, x) => a + (x['a'] as num).toDouble());
DateTime dt(Map t) => DateTime.parse(t['d']);
void toast(BuildContext c, String m) => ScaffoldMessenger.of(c)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, backgroundColor: navy));

// ---------------- Store ----------------
class Store extends ChangeNotifier {
  List<Map> txs = [], cats = [];
  Map<String, double> budgets = {};
  String? pin;
  bool authed = false, locked = false, guest = false;
  late SharedPreferences p;

  Future<void> load() async {
    p = await SharedPreferences.getInstance();
    final s = p.getString('d');
    if (s != null) _from(jsonDecode(s)); else _defaults(false);
    pin = p.getString('pin');
    authed = p.getBool('auth') ?? false;
    guest = p.getBool('guest') ?? false;
    locked = pin != null && authed;
  }

  void _from(Map j) {
    txs = List<Map>.from((j['txs'] as List).map((e) => Map.from(e)));
    cats = List<Map>.from((j['cats'] as List).map((e) => Map.from(e)));
    budgets = Map<String, double>.from((j['budgets'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble())));
  }

  Map toJson() => {'txs': txs, 'cats': cats, 'budgets': budgets, 'pin': pin};

  void _defaults(bool sample) {
    const e = ['Food', 'Transport', 'Shopping', 'Bills', 'Health', 'Fun'];
    const i = ['Salary', 'Freelance', 'Gift'];
    cats = [
      for (var k = 0; k < e.length; k++) {'n': e[k], 't': 'e', 'c': colors[k], 'i': k},
      for (var k = 0; k < i.length; k++) {'n': i[k], 't': 'i', 'c': colors[6 + k], 'i': 6 + k},
    ];
    txs = [];
    budgets = {};
    if (sample) {
      final r = Random(7), n = DateTime.now();
      budgets = {'Food': 25000, 'Transport': 10000, 'Shopping': 15000, 'Bills': 20000, 'Health': 8000, 'Fun': 9000};
      for (var m = 0; m < 6; m++) {
        txs.add({'id': 's$m', 't': 'i', 'a': 150000.0, 'c': 'Salary', 'd': DateTime(n.year, n.month - m, 1).toIso8601String(), 'n': 'Monthly salary'});
        if (m % 2 == 0) txs.add({'id': 'f$m', 't': 'i', 'a': 20000.0 + r.nextInt(20000), 'c': 'Freelance', 'd': DateTime(n.year, n.month - m, 12).toIso8601String(), 'n': 'Project'});
        for (var k = 0; k < 9; k++) {
          txs.add({'id': 'e$m$k', 't': 'e', 'a': 800.0 + r.nextInt(9000), 'c': e[r.nextInt(e.length)], 'd': DateTime(n.year, n.month - m, 1 + r.nextInt(min(n.day, 27))).toIso8601String(), 'n': 'Sample expense'});
        }
      }
    }
  }

  void save() { p.setString('d', jsonEncode({'txs': txs, 'cats': cats, 'budgets': budgets, 'pin': pin})); notifyListeners(); }
  void start({required bool sample}) {
    // Preserve existing user data on sign-in; sample data is only for a fresh guest session.
    if (cats.isEmpty) _defaults(sample);
    else if (sample && txs.isEmpty) _defaults(true);
    guest = sample; authed = true; locked = false;
    p.setBool('auth', true); p.setBool('guest', sample); save();
  }
  void logout() { authed = false; locked = false; p.setBool('auth', false); notifyListeners(); }
  void addTx(Map t) { txs.add(t); save(); }
  void setPin(String? v) { pin = v; v == null ? p.remove('pin') : p.setString('pin', v); notifyListeners(); }
  void lock() { if (pin != null) { locked = true; notifyListeners(); } }
  void unlock() { locked = false; notifyListeners(); }
  void reset() { _defaults(false); guest = false; save(); }
  void restore(Map j) { _from(j); pin = j['pin']; pin == null ? p.remove('pin') : p.setString('pin', pin!); save(); }
  List<Map> month(DateTime m) => txs.where((t) => dt(t).year == m.year && dt(t).month == m.month).toList();
  Map? cat(String n) => cats.cast<Map?>().firstWhere((c) => c!['n'] == n, orElse: () => null);
}

final S = Store();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await S.load();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Pocket Ledger',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: green, scaffoldBackgroundColor: canvas, cardTheme: CardThemeData(color: Colors.white, elevation: 2, shadowColor: Colors.black12, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
        home: ListenableBuilder(
          listenable: S,
          builder: (_, __) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: S.locked ? const PinLock(key: ValueKey('l')) : !S.authed ? const Welcome(key: ValueKey('w')) : const Shell(key: ValueKey('s')),
          ),
        ),
      );
}

// ---------------- Welcome / Auth ----------------
class Welcome extends StatelessWidget {
  const Welcome({super.key});
  void auth(BuildContext c, bool up) {
    final n = TextEditingController(), e = TextEditingController(), p = TextEditingController();
    showModalBottomSheet(context: c, isScrollControlled: true, showDragHandle: true, builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(up ? 'Create account' : 'Welcome back', style: Theme.of(ctx).textTheme.headlineSmall),
        if (up) TextField(controller: n, decoration: const InputDecoration(labelText: 'Name')),
        TextField(controller: e, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
        TextField(controller: p, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
        const SizedBox(height: 16),
        FilledButton(onPressed: () {
          final users = Map<String, dynamic>.from(jsonDecode(S.p.getString('users') ?? '{}'));
          final em = e.text.trim().toLowerCase();
          if (!em.contains('@') || p.text.length < 4) { toast(ctx, 'Enter a valid email and a password (4+ chars)'); return; }
          if (up) {
            if (n.text.trim().isEmpty) { toast(ctx, 'Enter your name'); return; }
            users[em] = {'n': n.text.trim(), 'p': p.text};
            S.p.setString('users', jsonEncode(users));
          } else if (users[em]?['p'] != p.text) { toast(ctx, 'Wrong email or password'); return; }
          Navigator.pop(ctx);
          S.start(sample: false);
        }, child: Text(up ? 'Sign Up' : 'Sign In')),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [navy, Color(0xFF065F46)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Padding(padding: const EdgeInsets.all(28), child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 900), curve: Curves.easeOutBack,
            builder: (_, t, child) => Opacity(opacity: t.clamp(0, 1), child: Transform.translate(offset: Offset(0, 40 * (1 - t)), child: child)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const _Pulse(child: Icon(Icons.account_balance_wallet_rounded, size: 96, color: green)),
              const SizedBox(height: 24),
              const Text('Pocket Ledger', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              const Text('Track every rupee, plan smarter budgets and see where your money goes - all in one place.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 40),
              SizedBox(width: double.infinity, child: FilledButton(style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)), onPressed: () => auth(context, false), child: const Text('Sign In'))),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton(style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16), foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)), onPressed: () => auth(context, true), child: const Text('Sign Up'))),
              TextButton(onPressed: () => S.start(sample: true), child: const Text('Continue as Guest (sample data)', style: TextStyle(color: Colors.white70))),
            ]),
          ))))),
        ),
      );
}

class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  @override
  void dispose() { c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ScaleTransition(scale: Tween(begin: .92, end: 1.08).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)), child: widget.child);
}

// ---------------- PIN lock ----------------
class PinLock extends StatefulWidget {
  const PinLock({super.key});
  @override
  State<PinLock> createState() => _PinLockState();
}

class _PinLockState extends State<PinLock> {
  String v = '';
  void tap(String k) {
    setState(() => k == '<' ? (v.isNotEmpty ? v = v.substring(0, v.length - 1) : null) : (v.length < 4 ? v += k : null));
    if (v.length == 4) {
      if (v == S.pin) { S.unlock(); } else { toast(context, 'Wrong PIN'); Future.delayed(const Duration(milliseconds: 300), () => setState(() => v = '')); }
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: navy,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_rounded, color: green, size: 56),
          const SizedBox(height: 12),
          const Text('Enter PIN', style: TextStyle(color: Colors.white, fontSize: 22)),
          const SizedBox(height: 20),
          Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < 4; i++) AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.all(8), width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle, color: i < v.length ? green : Colors.white24))]),
          const SizedBox(height: 20),
          SizedBox(width: 280, child: GridView.count(shrinkWrap: true, crossAxisCount: 3, childAspectRatio: 1.5, children: [
            for (final k in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '<']) k.isEmpty ? const SizedBox() : TextButton(onPressed: () => tap(k), child: k == '<' ? const Icon(Icons.backspace_outlined, color: Colors.white) : Text(k, style: const TextStyle(color: Colors.white, fontSize: 26))),
          ])),
        ])),
      );
}

// ---------------- Shell ----------------
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int idx = 0;
  static const titles = ['Dashboard', 'Manage Categories', 'Budget Planner', 'Reports & Analytics', 'App Security', 'Backup & Restore'];
  static const ics = [Icons.dashboard_rounded, Icons.category_rounded, Icons.pie_chart_rounded, Icons.bar_chart_rounded, Icons.lock_rounded, Icons.backup_rounded];
  Widget page() => [const Dash(), const Cats(), const Budget(), const Reports(), const Security(), const Backup()][idx];

  Widget side(bool drawer) => Container(
        width: 250, color: navy,
        child: SafeArea(child: Column(children: [
          const ListTile(leading: Icon(Icons.account_balance_wallet_rounded, color: green), title: Text('Pocket Ledger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          for (var i = 0; i < titles.length; i++) ListTile(
            selected: idx == i, selectedTileColor: Colors.white10, selectedColor: green, iconColor: Colors.white60, textColor: Colors.white70,
            leading: Icon(ics[i]), title: Text(titles[i]),
            onTap: () { setState(() => idx = i); if (drawer) Navigator.pop(context); },
          ),
          const Spacer(),
          ListTile(iconColor: Colors.white60, textColor: Colors.white70, leading: const Icon(Icons.logout), title: const Text('Sign out'), onTap: S.logout),
        ])),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    return ListenableBuilder(listenable: S, builder: (_, __) => Scaffold(
      drawer: wide ? null : Drawer(child: side(true)),
      appBar: AppBar(backgroundColor: canvas, title: Text(titles[idx], style: const TextStyle(fontWeight: FontWeight.w700)), actions: [
        IconButton(tooltip: 'Lock App', icon: const Icon(Icons.lock_outline), onPressed: () => S.pin == null ? toast(context, 'Set a PIN in App Security first') : S.lock()),
      ]),
      body: Row(children: [
        if (wide) side(false),
        Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 350), transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(a), child: c)), child: KeyedSubtree(key: ValueKey(idx), child: page()))),
      ]),
    ));
  }
}

// ---------------- Dashboard ----------------
void addTx(BuildContext c, String t) {
  final amt = TextEditingController(), note = TextEditingController();
  final opts = S.cats.where((x) => x['t'] == t).map((x) => x['n'] as String).toList();
  if (opts.isEmpty) { toast(c, 'Add a category first'); return; }
  var cat = opts.first, d = DateTime.now();
  showModalBottomSheet(context: c, isScrollControlled: true, showDragHandle: true, builder: (_) => StatefulBuilder(builder: (ctx, ss) => Padding(
    padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(t == 'i' ? 'Add Income' : 'Add Expense', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(color: t == 'i' ? green : coral, fontWeight: FontWeight.bold)),
      TextField(controller: amt, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (Rs)')),
      DropdownButtonFormField<String>(value: cat, decoration: const InputDecoration(labelText: 'Category'), items: [for (final o in opts) DropdownMenuItem(value: o, child: Text(o))], onChanged: (v) => cat = v!),
      ListTile(contentPadding: EdgeInsets.zero, title: Text(fd(d)), trailing: const Icon(Icons.calendar_today), onTap: () async {
        final r = await showDatePicker(context: ctx, initialDate: d, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (r != null) ss(() => d = r);
      }),
      TextField(controller: note, decoration: const InputDecoration(labelText: 'Payment method / Note')),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: t == 'i' ? green : coral, padding: const EdgeInsets.all(14)), onPressed: () {
        final a = double.tryParse(amt.text);
        if (a == null || a <= 0) { toast(ctx, 'Enter a valid amount'); return; }
        S.addTx({'id': '${DateTime.now().microsecondsSinceEpoch}', 't': t, 'a': a, 'c': cat, 'd': d.toIso8601String(), 'n': note.text});
        Navigator.pop(ctx);
        toast(c, 'Transaction Added');
      }, child: const Text('Save'))),
    ]),
  )));
}

class Dash extends StatelessWidget {
  const Dash({super.key});
  @override
  Widget build(BuildContext context) {
    final inc = sum(S.txs, 'i'), exp = sum(S.txs, 'e'), now = DateTime.now();
    final mt = S.month(now).where((t) => t['t'] == 'e');
    final spent = mt.fold<double>(0, (a, t) => a + (t['a'] as num));
    final budget = S.budgets.values.fold<double>(0, (a, b) => a + b);
    final byCat = <String, double>{};
    for (final t in mt) byCat[t['c']] = (byCat[t['c']] ?? 0) + (t['a'] as num);
    final total = max(max(budget, spent), 1.0);
    final recent = ([...S.txs]..sort((a, b) => b['d'].compareTo(a['d']))).take(8).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF047857)]), borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 8))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Net Balance', style: TextStyle(color: Colors.white70)),
          TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: inc - exp), duration: const Duration(milliseconds: 1000), curve: Curves.easeOutCubic, builder: (_, v, __) => Text(pkr(v), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800))),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 8, children: [_badge('Income', inc, green, Icons.arrow_downward), _badge('Expenses', exp, coral, Icons.arrow_upward)]),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: green, padding: const EdgeInsets.all(16)), onPressed: () => addTx(context, 'i'), icon: const Icon(Icons.add), label: const Text('Add Income'))),
        const SizedBox(width: 12),
        Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: coral, padding: const EdgeInsets.all(16)), onPressed: () => addTx(context, 'e'), icon: const Icon(Icons.remove), label: const Text('Add Expense'))),
      ]),
      if (S.guest) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () { S.reset(); toast(context, 'Sample data cleared'); }, icon: const Icon(Icons.delete_sweep), label: const Text('Clear sample data'))),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Budget Overview (this month)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 14),
        Center(child: TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 1100), curve: Curves.easeOutCubic, builder: (_, t, __) => SizedBox(width: 190, height: 190, child: CustomPaint(
          painter: Donut([for (final e in byCat.entries) MapEntry(e.value, Color((S.cat(e.key)?['c'] as int?) ?? 0xFF64748B))], total, t),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(budget > 0 ? '${(spent / budget * 100 * t).round()}%' : '--', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            Text('${pkr(spent)} / ${pkr(budget)}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ])),
        )))),
        const SizedBox(height: 10),
        if (byCat.isEmpty) const _Empty('No expenses this month') else Wrap(spacing: 14, runSpacing: 6, children: [for (final e in byCat.entries) Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, size: 10, color: Color((S.cat(e.key)?['c'] as int?) ?? 0xFF64748B)), const SizedBox(width: 5), Text('${e.key} ${pkr(e.value)}', style: const TextStyle(fontSize: 12))])]),
      ]))),
      const SizedBox(height: 14),
      const Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 8),
      if (recent.isEmpty) const _Empty('No transactions yet') else for (var i = 0; i < recent.length; i++) TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 350 + i * 90), curve: Curves.easeOut,
        builder: (_, t, c) => Opacity(opacity: t, child: Transform.translate(offset: Offset(30 * (1 - t), 0), child: c)),
        child: TxTile(recent[i]),
      ),
    ]);
  }

  Widget _badge(String l, double v, Color c, IconData i) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, size: 16, color: c), const SizedBox(width: 6), Text('$l  ${pkr(v)}', style: const TextStyle(color: Colors.white, fontSize: 13))]));
}

class TxTile extends StatelessWidget {
  final Map t;
  const TxTile(this.t, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = S.cat(t['c']), inc = t['t'] == 'i';
    return Card(margin: const EdgeInsets.symmetric(vertical: 4), child: ListTile(
      leading: CircleAvatar(backgroundColor: Color((c?['c'] as int?) ?? 0xFF64748B).withOpacity(.15), child: Icon(icons[(c?['i'] as int?) ?? 0], color: Color((c?['c'] as int?) ?? 0xFF64748B))),
      title: Text(t['c']), subtitle: Text('${fd(dt(t))}${(t['n'] as String).isEmpty ? '' : ' - ${t['n']}'}'),
      trailing: Text('${inc ? '+' : '-'}${pkr(t['a'])}', style: TextStyle(color: inc ? green : coral, fontWeight: FontWeight.bold)),
    ));
  }
}

class _Empty extends StatelessWidget {
  final String m;
  const _Empty(this.m);
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [const Icon(Icons.inbox_rounded, size: 56, color: Colors.black26), const SizedBox(height: 6), Text(m, style: const TextStyle(color: Colors.black45))])));
}

class Donut extends CustomPainter {
  final List<MapEntry<double, Color>> s;
  final double total, t;
  Donut(this.s, this.total, this.t);
  @override
  void paint(Canvas c, Size size) {
    final r = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - 12);
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 20..color = Colors.black12;
    c.drawArc(r, 0, 2 * pi, false, p);
    var a = -pi / 2;
    for (final e in s) {
      final sw = 2 * pi * (e.key / total) * t;
      p.color = e.value;
      c.drawArc(r, a, max(sw - .03, 0), false, p);
      a += sw;
    }
  }
  @override
  bool shouldRepaint(_) => true;
}

// ---------------- Categories ----------------
class Cats extends StatelessWidget {
  const Cats({super.key});
  void edit(BuildContext c, String t, [Map? old]) {
    final n = TextEditingController(text: old?['n'] ?? '');
    var col = old?['c'] ?? colors[0], ic = old?['i'] ?? 0;
    showDialog(context: c, builder: (_) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
      title: Text(old == null ? 'New category' : 'Edit category'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: n, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final k in colors) GestureDetector(onTap: () => ss(() => col = k), child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 30, height: 30, decoration: BoxDecoration(color: Color(k), shape: BoxShape.circle, border: Border.all(width: 3, color: col == k ? Colors.black87 : Colors.transparent))))]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [for (var i = 0; i < icons.length; i++) ChoiceChip(label: Icon(icons[i], size: 20), selected: ic == i, onSelected: (_) => ss(() => ic = i))]),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          final name = n.text.trim();
          if (name.isEmpty) return;
          if (old != null) {
            for (final x in S.txs.where((x) => x['c'] == old['n'])) x['c'] = name;
            if (S.budgets.containsKey(old['n'])) S.budgets[name] = S.budgets.remove(old['n'])!;
            old..['n'] = name..['c'] = col..['i'] = ic;
          } else {
            S.cats.add({'n': name, 't': t, 'c': col, 'i': ic});
          }
          S.save(); Navigator.pop(ctx); toast(c, 'Category saved');
        }, child: const Text('Save')),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(length: 2, child: ListenableBuilder(listenable: S, builder: (_, __) => Column(children: [
    const TabBar(tabs: [Tab(text: 'Income'), Tab(text: 'Expense')]),
    Expanded(child: TabBarView(children: [for (final t in ['i', 'e']) Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: () => edit(context, t), icon: const Icon(Icons.add), label: const Text('Add category')),
      body: ListView(padding: const EdgeInsets.all(16), children: [for (final c in S.cats.where((x) => x['t'] == t)) Card(child: ListTile(
        leading: CircleAvatar(backgroundColor: Color(c['c']), child: Icon(icons[c['i']], color: Colors.white)),
        title: Text(c['n']),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.edit), onPressed: () => edit(context, t, c)),
          IconButton(icon: const Icon(Icons.delete, color: coral), onPressed: () {
            if (S.txs.any((x) => x['c'] == c['n'])) { toast(context, 'Category is in use - cannot delete'); return; }
            S.cats.remove(c); S.budgets.remove(c['n']); S.save(); toast(context, 'Category deleted');
          }),
        ]),
      ))]),
    )])),
  ])));
}

// ---------------- Budget ----------------
class Budget extends StatelessWidget {
  const Budget({super.key});
  @override
  Widget build(BuildContext context) {
    final spent = <String, double>{};
    for (final t in S.month(DateTime.now()).where((t) => t['t'] == 'e')) spent[t['c']] = (spent[t['c']] ?? 0) + (t['a'] as num);
    final ex = S.cats.where((c) => c['t'] == 'e').toList();
    return ListView(padding: const EdgeInsets.all(16), children: [for (final c in ex) Builder(builder: (_) {
      final b = S.budgets[c['n']] ?? 0, s = spent[c['n']] ?? 0, pr = b == 0 ? 0.0 : s / b;
      final col = pr >= 1 ? coral : pr >= .8 ? Colors.amber.shade700 : green;
      return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: [Icon(icons[c['i']], color: Color(c['c'])), const SizedBox(width: 10), Expanded(child: Text(c['n'], style: const TextStyle(fontWeight: FontWeight.bold))), if (pr >= .8) Icon(pr >= 1 ? Icons.error : Icons.warning_amber, color: col), IconButton(icon: const Icon(Icons.edit), onPressed: () {
          final ctl = TextEditingController(text: b == 0 ? '' : b.round().toString());
          showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('Monthly limit - ${c['n']}'), content: TextField(controller: ctl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Limit (Rs)')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () { S.budgets[c['n']] = double.tryParse(ctl.text) ?? 0; S.save(); Navigator.pop(ctx); toast(context, 'Budget updated'); }, child: const Text('Save'))]));
        })]),
        TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: pr.clamp(0, 1).toDouble()), duration: const Duration(milliseconds: 800), curve: Curves.easeOut, builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: v, minHeight: 12, color: col, backgroundColor: Colors.black12))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${pkr(s)} / ${pkr(b)}'), Text(b == 0 ? 'No limit set' : s > b ? 'Over by ${pkr(s - b)}' : '${pkr(b - s)} left', style: TextStyle(color: col, fontWeight: FontWeight.w600))]),
      ])));
    })]);
  }
}

// ---------------- Reports ----------------
class Reports extends StatelessWidget {
  const Reports({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(length: 3, child: Column(children: const [
    TabBar(tabs: [Tab(text: 'Monthly Compare'), Tab(text: 'Calendar'), Tab(text: 'PDF Report')]),
    Expanded(child: TabBarView(children: [Compare(), CalendarTab(), PdfTab()])),
  ]));
}

class Compare extends StatelessWidget {
  const Compare({super.key});
  @override
  Widget build(BuildContext context) {
    final n = DateTime.now();
    final ms = [for (var i = 5; i >= 0; i--) DateTime(n.year, n.month - i)];
    final inc = [for (final m in ms) sum(S.month(m), 'i')], exp = [for (final m in ms) sum(S.month(m), 'e')];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.circle, size: 10, color: green), Text(' Income    '), Icon(Icons.circle, size: 10, color: coral), Text(' Expenses')]),
        const SizedBox(height: 10),
        SizedBox(height: 220, child: TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 1000), curve: Curves.easeOutCubic, builder: (_, t, __) => CustomPaint(size: Size.infinite, painter: Bars([for (final m in ms) months[m.month - 1]], inc, exp, t)))),
      ]))),
      Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('Month')), DataColumn(label: Text('Income')), DataColumn(label: Text('Expenses')), DataColumn(label: Text('Savings')), DataColumn(label: Text('Change'))], rows: [
        for (var i = 0; i < ms.length; i++) DataRow(cells: [
          DataCell(Text('${months[ms[i].month - 1]} ${ms[i].year}')), DataCell(Text(pkr(inc[i]))), DataCell(Text(pkr(exp[i]))),
          DataCell(Text(pkr(inc[i] - exp[i]), style: TextStyle(color: inc[i] >= exp[i] ? green : coral, fontWeight: FontWeight.bold))),
          DataCell(Text(i == 0 || exp[i - 1] == 0 ? '-' : '${((exp[i] - exp[i - 1]) / exp[i - 1] * 100).toStringAsFixed(1)}% spend')),
        ]),
      ]))),
    ]);
  }
}

class Bars extends CustomPainter {
  final List<String> l;
  final List<double> i, e;
  final double t;
  Bars(this.l, this.i, this.e, this.t);
  @override
  void paint(Canvas c, Size s) {
    final mx = [...i, ...e, 1.0].reduce(max), w = s.width / l.length, h = s.height - 22;
    for (var k = 0; k < l.length; k++) {
      for (var j = 0; j < 2; j++) {
        final v = (j == 0 ? i[k] : e[k]) / mx * h * t;
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * k + w * (.14 + j * .36), h - v, w * .32, v), const Radius.circular(5)), Paint()..color = j == 0 ? green : coral);
      }
      final tp = TextPainter(text: TextSpan(text: l[k], style: const TextStyle(color: Colors.black54, fontSize: 12)), textDirection: TextDirection.ltr)..layout();
      tp.paint(c, Offset(w * k + (w - tp.width) / 2, h + 4));
    }
  }
  @override
  bool shouldRepaint(_) => true;
}

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});
  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  DateTime m = DateTime(DateTime.now().year, DateTime.now().month), sel = DateTime.now();
  int view = 0;
  @override
  Widget build(BuildContext context) {
    final off = DateTime(m.year, m.month).weekday % 7, days = DateTime(m.year, m.month + 1, 0).day;
    final day = S.txs.where((t) { final d = dt(t); return d.year == sel.year && d.month == sel.month && d.day == sel.day; }).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => m = DateTime(m.year, m.month - 1))), Text('${months[m.month - 1]} ${m.year}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => m = DateTime(m.year, m.month + 1)))]),
        Row(children: [for (final d in ['S', 'M', 'T', 'W', 'T', 'F', 'S']) Expanded(child: Center(child: Text(d, style: const TextStyle(color: Colors.black45))))]),
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 7, children: [
          for (var i = 0; i < off + days; i++) i < off ? const SizedBox() : Builder(builder: (_) {
            final d = DateTime(m.year, m.month, i - off + 1), tx = S.txs.where((t) { final x = dt(t); return x.year == d.year && x.month == d.month && x.day == d.day; });
            final on = d.year == sel.year && d.month == sel.month && d.day == sel.day;
            return GestureDetector(onTap: () => setState(() => sel = d), child: AnimatedContainer(duration: const Duration(milliseconds: 250), margin: const EdgeInsets.all(3), decoration: BoxDecoration(color: on ? navy : Colors.transparent, borderRadius: BorderRadius.circular(10)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${d.day}', style: TextStyle(color: on ? Colors.white : Colors.black87)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [if (tx.any((t) => t['t'] == 'i')) const Icon(Icons.circle, size: 6, color: green), if (tx.any((t) => t['t'] == 'e')) const Icon(Icons.circle, size: 6, color: coral)]),
            ])));
          }),
        ]),
      ]))),
      const SizedBox(height: 8),
      Text(fd(sel), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 8),
      SegmentedButton<int>(segments: const [ButtonSegment(value: 0, label: Text('Transactions')), ButtonSegment(value: 1, label: Text('Daily Summary'))], selected: {view}, onSelectionChanged: (v) => setState(() => view = v.first)),
      const SizedBox(height: 8),
      AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: view == 0
        ? Column(key: const ValueKey(0), children: day.isEmpty ? [const _Empty('No transactions on this date')] : [for (final t in day) TxTile(t)])
        : Row(key: const ValueKey(1), children: [for (final x in [('Earned', sum(day, 'i'), green), ('Spent', sum(day, 'e'), coral), ('Net Flow', sum(day, 'i') - sum(day, 'e'), navy)]) Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [Text(x.$1, style: const TextStyle(color: Colors.black54)), const SizedBox(height: 6), Text(pkr(x.$2), style: TextStyle(color: x.$3, fontWeight: FontWeight.bold))]))))])),
    ]);
  }
}

class PdfTab extends StatefulWidget {
  const PdfTab({super.key});
  @override
  State<PdfTab> createState() => _PdfTabState();
}

class _PdfTabState extends State<PdfTab> {
  DateTime m = DateTime(DateTime.now().year, DateTime.now().month);
  @override
  Widget build(BuildContext context) {
    final n = DateTime.now(), list = S.month(m)..sort((a, b) => a['d'].compareTo(b['d']));
    final inc = sum(list, 'i'), exp = sum(list, 'e');
    return ListView(padding: const EdgeInsets.all(16), children: [
      DropdownButtonFormField<DateTime>(value: m, decoration: const InputDecoration(labelText: 'Report month', filled: true, fillColor: Colors.white), items: [for (var i = 0; i < 12; i++) DropdownMenuItem(value: DateTime(n.year, n.month - i), child: Text('${months[DateTime(n.year, n.month - i).month - 1]} ${DateTime(n.year, n.month - i).year}'))], onChanged: (v) => setState(() => m = v!)),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Financial Statement - ${months[m.month - 1]} ${m.year}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Divider(),
        Text('Total Income: ${pkr(inc)}', style: const TextStyle(color: green)), Text('Total Expenses: ${pkr(exp)}', style: const TextStyle(color: coral)), Text('Net Savings: ${pkr(inc - exp)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        const Divider(),
        if (list.isEmpty) const _Empty('No data for this month') else for (final t in list) Text('${fd(dt(t))}  ${t['c']}  ${t['t'] == 'i' ? '+' : '-'}${pkr(t['a'])}'),
      ]))),
      const SizedBox(height: 12),
      FilledButton.icon(style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)), icon: const Icon(Icons.picture_as_pdf), label: const Text('Generate PDF Report'), onPressed: () async {
        final doc = pw.Document();
        doc.addPage(pw.MultiPage(build: (_) => [
          pw.Header(level: 0, child: pw.Text('Pocket Ledger - ${months[m.month - 1]} ${m.year}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
          pw.Text('Income: ${pkr(inc)}    Expenses: ${pkr(exp)}    Net: ${pkr(inc - exp)}'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(headers: ['Date', 'Type', 'Category', 'Note', 'Amount'], data: [for (final t in list) [fd(dt(t)), t['t'] == 'i' ? 'Income' : 'Expense', t['c'], t['n'], pkr(t['a'])]]),
        ]));
        await Printing.layoutPdf(onLayout: (_) => doc.save(), name: 'report_${m.year}_${m.month}.pdf');
      }),
    ]);
  }
}

// ---------------- Security ----------------
Future<String?> pinDialog(BuildContext c, String title) {
  final ctl = TextEditingController();
  return showDialog<String>(context: c, builder: (ctx) => AlertDialog(title: Text(title), content: TextField(controller: ctl, autofocus: true, obscureText: true, maxLength: 4, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, letterSpacing: 12)), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () => ctl.text.length == 4 ? Navigator.pop(ctx, ctl.text) : toast(ctx, 'PIN must be 4 digits'), child: const Text('OK'))]));
}

class Security extends StatelessWidget {
  const Security({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: S, builder: (_, __) => ListView(padding: const EdgeInsets.all(16), children: [
    Card(child: Column(children: [
      SwitchListTile(secondary: const Icon(Icons.lock), title: const Text('App Lock PIN'), subtitle: Text(S.pin == null ? 'Disabled' : 'Enabled'), value: S.pin != null, onChanged: (v) async {
        if (v) { final p = await pinDialog(context, 'Set a 4-digit PIN'); if (p != null) { S.setPin(p); if (context.mounted) toast(context, 'PIN enabled'); } }
        else { final p = await pinDialog(context, 'Enter current PIN'); if (p == S.pin) { S.setPin(null); if (context.mounted) toast(context, 'PIN disabled'); } else if (p != null && context.mounted) toast(context, 'Wrong PIN'); }
      }),
      if (S.pin != null) ListTile(leading: const Icon(Icons.password), title: const Text('Change PIN'), onTap: () async {
        final o = await pinDialog(context, 'Current PIN');
        if (o == null) return;
        if (o != S.pin) { if (context.mounted) toast(context, 'Wrong PIN'); return; }
        final p = context.mounted ? await pinDialog(context, 'New PIN') : null;
        if (p != null) { S.setPin(p); if (context.mounted) toast(context, 'PIN changed'); }
      }),
      if (S.pin != null) ListTile(leading: const Icon(Icons.lock_outline), title: const Text('Lock app now'), onTap: S.lock),
    ])),
  ]));
}

// ---------------- Backup ----------------
class Backup extends StatelessWidget {
  const Backup({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    Card(child: ListTile(leading: const Icon(Icons.download, color: green), title: const Text('Export Backup'), subtitle: const Text('Save all data as a .json file'), onTap: () async {
      await Share.share(jsonEncode(S.toJson()), subject: 'pocket_ledger_backup.json');
      if (context.mounted) toast(context, 'Backup exported');
    })),
    Card(child: ListTile(leading: const Icon(Icons.upload_file, color: Colors.blue), title: const Text('Restore Data'), subtitle: const Text('Pick a previously saved .json backup'), onTap: () async {
      final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
      if (r == null || r.files.single.bytes == null) return;
      try { S.restore(jsonDecode(utf8.decode(r.files.single.bytes!))); if (context.mounted) toast(context, 'Backup Restored'); }
      catch (_) { if (context.mounted) toast(context, 'Invalid backup file'); }
    })),
    Card(child: ListTile(leading: const Icon(Icons.delete_forever, color: coral), title: const Text('Reset All Data'), subtitle: const Text('Deletes transactions, budgets and custom categories'), onTap: () => showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Reset everything?'), content: const Text('This cannot be undone.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(backgroundColor: coral), onPressed: () { S.reset(); Navigator.pop(ctx); toast(context, 'All data reset'); }, child: const Text('Reset'))],
    )))),
  ]);
}
