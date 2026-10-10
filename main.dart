import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SharedPreferences P;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  P = await SharedPreferences.getInstance();
  runApp(MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0B0618)), home: const App()));
}

int gi(String k) => P.getInt(k) ?? 0;
String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
double hy(double a, double b) => sqrt(a * a + b * b);
const skins = [Color(0xFF00E5FF), Color(0xFFFF4FD8), Color(0xFFFFD23F), Color(0xFF7CFF6B)];
const skinAt = [0, 3, 7, 14];

class Boss {
  late String name; late int shape, hue; late List<String> pats; late bool orbit; late double spd;
  Boss(int seed) {
    final r = Random(seed);
    const a = ['Grim', 'Neon', 'Rusty', 'Angry', 'Cosmic', 'Fuzzy', 'Toxic', 'Royal'];
    const n = ['Jellyfish', 'Robot', 'Pumpkin', 'Dragon', 'Toaster', 'Moth', 'Crab', 'Wizard'];
    name = '${a[r.nextInt(8)]} ${n[r.nextInt(8)]}';
    shape = r.nextInt(3); hue = r.nextInt(360);
    pats = ['ring', 'aim', 'spiral', 'rain']..shuffle(r);
    orbit = r.nextBool(); spd = .7 + r.nextDouble() * .6;
  }
}

class Game {
  final Boss b; final bool daily; final int bn, fl; final r = Random();
  double t = 0, px = 180, py = 520, tx = 180, ty = 520, inv = 0, fire = 0, flash = 0, shake = 0, sh = 0, rp = 0, hp = 150, bx = 180, by = 105, cx = 180, cy = 105, ang = 0;
  int lives, bombs = 1, ph = 0, score = 0;
  bool core = false, over = false, won = false, timeout = false;
  final bul = <List<double>>[], pb = <List<double>>[], pu = <List<double>>[];
  final cd = {'ring': 1.0, 'aim': 1.0, 'spiral': 1.0, 'rain': 1.0};
  Game(this.b, this.daily, this.bn, this.fl, int hl) : lives = 3 + hl;

  void bomb() { if (bombs > 0 && !over) { bombs--; bul.clear(); hp -= 10; shake = .5; HapticFeedback.heavyImpact(); } }

  void update(double dt) {
    if (over) return;
    t += dt;
    px += (tx - px) * min(1.0, dt * 12); py += ((ty - 50) - py) * min(1.0, dt * 12);
    px = px.clamp(14.0, 346.0).toDouble(); py = py.clamp(200.0, 616.0).toDouble();
    inv -= dt; flash -= dt; shake -= dt; sh -= dt; rp -= dt;
    final np = hp > 100 ? 0 : hp > 50 ? 1 : 2;
    if (np != ph) { ph = np; shake = .4; HapticFeedback.heavyImpact(); }
    bx = 180 + sin(t * b.spd) * 110; by = 105 + sin(t * b.spd * 1.7) * 18;
    final cyc = 3.4 - ph * .4;
    core = (t % cyc) < cyc * .45;
    cx = b.orbit ? bx + cos(t * 2.2) * 34 : bx; cy = b.orbit ? by + sin(t * 2.2) * 34 : by;
    fire -= dt;
    if (fire <= 0) { fire = .13 / (1 + .12 * fl) / (rp > 0 ? 1.6 : 1); pb.add([px - 7, py - 12]); pb.add([px + 7, py - 12]); }
    final m = 1 + ph * .18;
    for (final p in b.pats.take(ph + 1)) {
      cd[p] = (cd[p] ?? 0) - dt;
      if (cd[p]! > 0) continue;
      if (p == 'ring') { cd[p] = 2.2 / m; for (var i = 0; i < 14; i++) { final a = i / 14 * 6.283 + t; bul.add([bx, by, cos(a) * 105, sin(a) * 105]); } }
      if (p == 'aim') { cd[p] = 1.1 / m; final a = atan2(py - by, px - bx); for (var i = (ph > 0 ? -1 : 0); i <= (ph > 0 ? 1 : 0); i++) { bul.add([bx, by, cos(a + i * .25) * 150, sin(a + i * .25) * 150]); } }
      if (p == 'spiral') { cd[p] = .16 / m; ang += .55; bul.add([bx, by, cos(ang) * 115, sin(ang) * 115]); }
      if (p == 'rain') { cd[p] = .5 / m; bul.add([r.nextDouble() * 360, 0, 0, 140]); }
    }
    for (final q in pb) { q[1] -= 520 * dt; }
    pb.removeWhere((q) {
      if (q[1] < -10) return true;
      if (core && hy(q[0] - cx, q[1] - cy) < 20) { hp -= 3; flash = .08; score += 10; if (r.nextDouble() < .06) pu.add([cx, cy, r.nextInt(2).toDouble()]); return true; }
      if (hy(q[0] - bx, q[1] - by) < 48) { hp -= .6; score += 1; return true; }
      return false;
    });
    for (final q in bul) { q[0] += q[2] * dt; q[1] += q[3] * dt; }
    bul.removeWhere((q) {
      if (q[0] < -20 || q[0] > 380 || q[1] < -20 || q[1] > 660) return true;
      if (sh > 0 && hy(q[0] - px, q[1] - py) < 18) return true;
      if (inv <= 0 && sh <= 0 && hy(q[0] - px, q[1] - py) < 8) { lives--; inv = 1.3; shake = .3; HapticFeedback.mediumImpact(); return true; }
      return false;
    });
    for (final q in pu) { q[1] += 80 * dt; }
    pu.removeWhere((q) {
      if (q[1] > 650) return true;
      if (hy(q[0] - px, q[1] - py) < 22) { if (q[2] == 0) { sh = 4; } else { rp = 6; } return true; }
      return false;
    });
    if (hp <= 0) { over = true; won = true; score += 500; }
    else if (lives <= 0 || t >= 90) { over = true; timeout = lives > 0; }
  }
}

Path poly(double cx, double cy, double r, int n, double rot) {
  final p = Path();
  for (var i = 0; i < n; i++) { final a = rot + i / n * 6.283; final x = cx + cos(a) * r, y = cy + sin(a) * r; i == 0 ? p.moveTo(x, y) : p.lineTo(x, y); }
  return p..close();
}

class GP extends CustomPainter {
  final Game g; final Color sc; GP(this.g, this.sc);
  void gl(Canvas c, Path p, Color col) {
    c.drawPath(p, Paint()..color = col.withOpacity(.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    c.drawPath(p, Paint()..color = col);
  }
  void tx(Canvas c, String s, double x, double y, {double sz = 12, Color col = Colors.white, bool right = false}) {
    final t = TextPainter(text: TextSpan(text: s, style: TextStyle(color: col, fontSize: sz, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    t.paint(c, Offset(right ? x - t.width : x, y));
  }
  @override
  void paint(Canvas c, Size s) {
    c.scale(s.width / 360, s.height / 640);
    if (g.shake > 0) c.translate((g.r.nextDouble() - .5) * 8, (g.r.nextDouble() - .5) * 8);
    final b = g.b;
    if (g.hp > 0) {
      final col = HSLColor.fromAHSL(1, b.hue.toDouble(), .9, g.flash > 0 ? .85 : .6).toColor();
      gl(c, b.shape == 0 ? poly(g.bx, g.by, 46, 24, 0) : b.shape == 1 ? poly(g.bx, g.by, 50, 6, g.t * .4) : poly(g.bx, g.by, 52, 4, .78), col);
      c.drawCircle(Offset(g.bx - 18, g.by - 6), 5, Paint()..color = Colors.black26);
      c.drawCircle(Offset(g.bx + 18, g.by - 6), 5, Paint()..color = Colors.black26);
      if (g.core) { gl(c, poly(g.cx, g.cy, 16, 20, 0), Colors.white); c.drawCircle(Offset(g.cx, g.cy), 7, Paint()..color = const Color(0xFFFF4FD8)); }
      else { c.drawCircle(Offset(g.cx, g.cy), 10, Paint()..color = const Color(0xFF222222)); }
    }
    for (final q in g.bul) { c.drawCircle(Offset(q[0], q[1]), 5, Paint()..color = const Color(0xFFFF7A7A)); }
    for (final q in g.pb) { c.drawRect(Rect.fromLTWH(q[0] - 1.5, q[1] - 8, 3, 10), Paint()..color = sc); }
    for (final q in g.pu) { gl(c, poly(q[0], q[1], 10, 12, 0), q[2] == 0 ? Colors.cyanAccent : Colors.amber); }
    if (g.lives > 0 && (g.inv <= 0 || (g.t * 14).floor() % 2 == 0)) {
      if (g.sh > 0) c.drawCircle(Offset(g.px, g.py), 20, Paint()..color = Colors.cyanAccent.withOpacity(.4));
      gl(c, Path()..moveTo(g.px, g.py - 16)..lineTo(g.px + 13, g.py + 12)..lineTo(g.px, g.py + 6)..lineTo(g.px - 13, g.py + 12)..close(), sc);
    }
    c.drawRect(const Rect.fromLTWH(14, 14, 332, 10), Paint()..color = const Color(0xFF2A1457));
    c.drawRect(Rect.fromLTWH(14, 14, 332 * max(0.0, g.hp / 150), 10), Paint()..color = HSLColor.fromAHSL(1, b.hue.toDouble(), .9, .6).toColor());
    tx(c, '${b.name}  ${g.daily ? "Boss #${g.bn}" : "Practice"}', 14, 30);
    tx(c, '${max(0, 90 - g.t.floor())}s  Phase ${g.ph + 1}/3  Score ${g.score}', 346, 30, right: true);
    tx(c, '${'♥' * max(0, g.lives)}', 14, 612, sz: 20, col: Colors.redAccent);
    if (g.t < 3) tx(c, 'Shoot the EYE when it glows!', 70, 320, sz: 16, col: Colors.amber);
  }
  @override
  bool shouldRepaint(covariant CustomPainter o) => true;
}

class App extends StatefulWidget { const App({super.key}); @override State<App> createState() => _AppS(); }

class _AppS extends State<App> {
  int scr = 0; Game? g; int coinsGot = 0;
  String get today => ymd(DateTime.now());
  int get bn => DateTime.now().difference(DateTime(2026, 10, 1)).inDays + 1;
  int get seed { final d = DateTime.now(); return d.year * 10000 + d.month * 100 + d.day; }
  int get skin => min(gi('skin'), skinAt.where((x) => gi('best') >= x).length - 1);

  void start(bool daily) {
    if (daily) { if (P.getString('done') == today) return; P.setString('done', today); P.setInt('dw', 0); }
    g = Game(Boss(daily ? seed : Random().nextInt(1 << 30)), daily, bn, gi('fl'), gi('hl'));
    setState(() => scr = 1);
  }

  void end() {
    final g = this.g!;
    coinsGot = g.score ~/ 10 + (g.won ? 20 : 0);
    P.setInt('coins', gi('coins') + coinsGot);
    if (g.won) P.setInt('wins', gi('wins') + 1);
    if (g.daily) {
      P.setInt('dw', g.won ? 1 : 0);
      if (g.won) {
        final y = ymd(DateTime.now().subtract(const Duration(days: 1)));
        final s = P.getString('last') == y ? gi('streak') + 1 : 1;
        P.setInt('streak', s); P.setString('last', today);
        if (s > gi('best')) P.setInt('best', s);
      } else { P.setInt('streak', 0); }
    }
    setState(() => scr = 2);
  }

  Widget btn(String t, VoidCallback? f, {bool alt = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: SizedBox(width: 290, height: 52, child: ElevatedButton(
      onPressed: f,
      style: ElevatedButton.styleFrom(backgroundColor: alt ? const Color(0xFF1A1033) : const Color(0xFF00E5FF), foregroundColor: alt ? const Color(0xFF00E5FF) : Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))));

  Widget stat(String v, String l) => Expanded(child: Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF1A1033), borderRadius: BorderRadius.circular(14)),
    child: Column(children: [Text(v, style: const TextStyle(fontSize: 22, color: Colors.amber, fontWeight: FontWeight.bold)), Text(l, style: const TextStyle(fontSize: 11, color: Colors.white60))])));

  Widget menu() {
    final done = P.getString('done') == today, b = Boss(seed);
    return Center(child: SingleChildScrollView(child: Column(children: [
      const Text('👾', style: TextStyle(fontSize: 70)),
      const Text('BOSS OF THE DAY', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF00E5FF), letterSpacing: 1)),
      const Text('One boss. One weakness. One try.', style: TextStyle(color: Colors.white60)),
      Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(12), width: 290, decoration: BoxDecoration(color: const Color(0xFF1A1033), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF3A2670), width: 2)),
        child: Column(children: [Text('Boss #$bn', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)), Text(b.name, style: const TextStyle(fontSize: 20)), Text(done ? (gi('dw') == 1 ? 'Beaten today!' : 'Try again tomorrow') : 'Not fought yet', style: const TextStyle(color: Colors.white60))])),
      btn(done ? 'Come back tomorrow' : 'Fight today\'s boss', done ? null : () => start(true)),
      btn('Practice (random boss)', () => start(false), alt: true),
      btn('Upgrade shop  (${gi('coins')} coins)', () => setState(() => scr = 3), alt: true),
      SizedBox(width: 300, child: Row(children: [stat('${gi('streak')}', 'streak'), stat('${gi('best')}', 'best'), stat('${gi('wins')}', 'beaten')])),
      TextButton(onPressed: () { final n = skinAt.where((x) => gi('best') >= x).length; P.setInt('skin', (skin + 1) % n); setState(() {}); }, child: Text('Tap to change ship ▲  (unlock at streaks 3, 7, 14)', style: TextStyle(color: skins[skin]))),
    ])));
  }

  Widget shop() {
    Widget row(String name, String key, int max, int base) {
      final l = gi(key), cost = base * (l + 1);
      return Padding(padding: const EdgeInsets.all(6), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 150, child: Text('$name  $l/$max')),
        ElevatedButton(onPressed: l >= max || gi('coins') < cost ? null : () { P.setInt('coins', gi('coins') - cost); P.setInt(key, l + 1); setState(() {}); }, child: Text(l >= max ? 'MAX' : '$cost coins'))]));
    }
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('UPGRADE SHOP', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.amber)),
      Text('Coins: ${gi('coins')}', style: const TextStyle(fontSize: 20)),
      row('Fire rate', 'fl', 5, 50), row('Extra life', 'hl', 3, 100),
      btn('Back', () => setState(() => scr = 0), alt: true)]));
  }

  Widget result() {
    final g = this.g!;
    final txt = 'Boss ${g.daily ? "#${g.bn}" : "(practice)"} ${g.b.name}\n${g.won ? "Beaten in ${g.t.round()}s" : "Survived ${g.t.round()}s"}  ${"♥" * max(0, g.lives)}\nStreak: ${gi('streak')}  Score: ${g.score}\nCan you beat it?';
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(g.won ? '🏆' : g.timeout ? '⏰' : '💀', style: const TextStyle(fontSize: 64)),
      Text(g.won ? 'BOSS DEFEATED!' : g.timeout ? 'It escaped!' : 'You were crushed', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
      Text('Weakness: the ${g.b.orbit ? "orbiting" : "blinking"} eye', style: const TextStyle(color: Colors.white60)),
      Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF1A1033), borderRadius: BorderRadius.circular(14)), child: Text('$txt\n+$coinsGot coins')),
      btn('Share result', () { Clipboard.setData(ClipboardData(text: txt)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied! Paste it anywhere.'))); }),
      btn('Menu', () => setState(() => scr = 0), alt: true)]));
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: [menu, () => GameView(g: g!, sc: skins[skin], onEnd: end), result, shop][scr]()));
}

class GameView extends StatefulWidget {
  final Game g; final Color sc; final VoidCallback onEnd;
  const GameView({super.key, required this.g, required this.sc, required this.onEnd});
  @override State<GameView> createState() => _GV();
}

class _GV extends State<GameView> with SingleTickerProviderStateMixin {
  late final Ticker tk; Duration last = Duration.zero; bool ended = false;
  @override
  void initState() {
    super.initState();
    tk = createTicker((d) {
      final dt = ((d - last).inMicroseconds / 1e6).clamp(0.0, .05).toDouble();
      last = d; widget.g.update(dt); setState(() {});
      if (widget.g.over && !ended) { ended = true; Future.delayed(const Duration(milliseconds: 900), () { if (mounted) widget.onEnd(); }); }
    })..start();
  }
  @override
  void dispose() { tk.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, c) {
    final w = min(c.maxWidth, c.maxHeight * 9 / 16), h = w * 16 / 9;
    void mv(Offset o) { widget.g.tx = o.dx / w * 360; widget.g.ty = o.dy / h * 640; }
    return Center(child: SizedBox(width: w, height: h, child: GestureDetector(
      onPanStart: (d) => mv(d.localPosition), onPanUpdate: (d) => mv(d.localPosition),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: GP(widget.g, widget.sc))),
        Positioned(right: 10, bottom: 10, child: GestureDetector(onTap: widget.g.bomb, child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white12), child: Text('💣${widget.g.bombs}', style: const TextStyle(fontSize: 22))))),
      ]))));
  });
}
