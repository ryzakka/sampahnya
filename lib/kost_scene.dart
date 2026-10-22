import 'dart:math' as math;

import 'package:flutter/material.dart';

// ====================================================================
//  Adegan visual kost (v2)
//
//  - KostStage    : adegan memenuhi layar (dipakai pemain sendiri).
//                   `insets` = area yang tertutup HUD/panel; bangunan
//                   otomatis diposisikan di area yang tersisa, sementara
//                   langit/tanah/jalan tetap menyambung sampai tepi layar.
//  - KostScene    : versi kotak 4:3 untuk kartu lawan yang kecil.
//  - KostBackdrop : latar beranimasi untuk beranda & lobi.
//
//  Semua digambar dengan CustomPainter (tanpa aset gambar) pada dunia
//  virtual setinggi 300 unit; skala dihitung dari area yang tersedia.
// ====================================================================

final Stopwatch _clock = Stopwatch()..start();

/// Jam internal animasi (milidetik sejak aplikasi mulai).
int sceneNowMs() => _clock.elapsedMilliseconds;

enum FxType { build, burn, defense, incoming, outgoing, collapse }

/// Efek sesaat yang dipicu oleh event game (bangun, bakar, lempar, dst).
class KostFx {
  KostFx(this.type, {this.amount = 0}) : startMs = sceneNowMs();

  final FxType type;
  final int startMs;
  final double amount;

  int get age => sceneNowMs() - startMs;
}

/// Data yang dibutuhkan untuk menggambar satu kost.
class KostSceneData {
  const KostSceneData({
    required this.rooms,
    required this.maxRooms,
    required this.defense,
    required this.trashRatio,
    required this.pollution,
    this.eliminated = false,
    this.protectedLeft = 0,
    this.haulProgress,
    this.burnPenalty = false,
    this.smog = false,
    this.fx = const <KostFx>[],
    this.wall = const Color(0xFFF0DFB8),
    this.compact = false,
    this.facingRight = true,
  });

  final int rooms;
  final int maxRooms;
  final int defense; // 0..3
  final double trashRatio; // 0..1
  final double pollution; // 0..100
  final bool eliminated;
  final double protectedLeft; // detik
  final double? haulProgress; // null = tidak ada truk, 0..1 = progres
  final bool burnPenalty;
  final bool smog;
  final List<KostFx> fx;
  final Color wall;
  final bool compact; // versi kecil: tanpa penghuni, koin, dekorasi jauh
  final bool facingRight; // arah sisi lawan (lemparan datang/pergi)
}

/// Adegan memenuhi seluruh area induknya.
class KostStage extends StatelessWidget {
  const KostStage({
    super.key,
    required this.data,
    required this.repaint,
    this.insets = EdgeInsets.zero,
  });

  final KostSceneData data;
  final Listenable repaint;
  final EdgeInsets insets;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: KostPainter(data, repaint, insets: insets),
        size: Size.infinite,
      ),
    );
  }
}

/// Kotak 4:3 bersudut membulat, untuk kartu kost lawan.
class KostScene extends StatelessWidget {
  const KostScene({super.key, required this.data, required this.repaint});

  final KostSceneData data;
  final Listenable repaint;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: KostStage(data: data, repaint: repaint),
      ),
    );
  }
}

/// Latar beranimasi (awan, burung, mobil lewat) untuk beranda & lobi.
class KostBackdrop extends StatefulWidget {
  const KostBackdrop({
    super.key,
    this.insets = EdgeInsets.zero,
    this.rooms = 9,
    this.defense = 2,
    this.pollution = 10,
    this.trashRatio = 0.2,
  });

  final EdgeInsets insets;
  final int rooms;
  final int defense;
  final double pollution;
  final double trashRatio;

  @override
  State<KostBackdrop> createState() => _KostBackdropState();
}

class _KostBackdropState extends State<KostBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KostStage(
      repaint: _c,
      insets: widget.insets,
      data: KostSceneData(
        rooms: widget.rooms,
        maxRooms: 12,
        defense: widget.defense,
        trashRatio: widget.trashRatio,
        pollution: widget.pollution,
      ),
    );
  }
}

// ---------------------------------------------------------------- util

const double _w = 400;
const double _h = 300;
const double _gy = 236; // garis tanah (kaki bangunan)
const double _bl = 105; // sisi kiri bangunan
const double _cw = 47.5; // lebar satu kamar
const double _fh = 50; // tinggi satu lantai

const List<Color> _bagColors = [
  Color(0xFF263238),
  Color(0xFF37474F),
  Color(0xFF1B2A22),
  Color(0xFF455A64),
];

const List<Color> _carColors = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFFFDD835),
  Color(0xFF8E24AA),
  Color(0xFFEEEEEE),
];

double _c01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _lerp(double a, double b, double t) => a + (b - a) * t;
double _ease(double x) {
  x = _c01(x);
  return x * x * (3 - 2 * x);
}

double _easeOutBack(double x) {
  x = _c01(x);
  const c1 = 1.70158;
  const c3 = c1 + 1;
  final y = x - 1;
  return 1 + c3 * y * y * y + c1 * y * y;
}

int _hh(int n) => ((n * 7919 + 104729) * 15485863) % 1000003;
Color _mix(Color a, Color b, double t) => Color.lerp(a, b, _c01(t))!;

// ------------------------------------------------------------- painter

class KostPainter extends CustomPainter {
  KostPainter(this.d, Listenable repaint, {this.insets = EdgeInsets.zero})
      : super(repaint: repaint);

  final KostSceneData d;
  final EdgeInsets insets;
  final Paint _p = Paint();

  // batas pandang dalam koordinat dunia (diisi saat paint)
  double _vl = 0, _vr = _w, _vt = 0, _vb = _h;
  Rect get _view => Rect.fromLTRB(_vl, _vt, _vr, _vb);

  static final TextPainter _signText = TextPainter(
    text: const TextSpan(
      text: 'KOST',
      style: TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  // Urutan slot kantong sampah = urutan "terisi": tumpukan kanan & kiri
  // bergantian, terakhir menutupi halaman depan kost.
  static final List<Offset> _slots = _buildSlots();

  static List<Offset> _buildSlots() {
    final s = <Offset>[];
    for (var r = 0; r < 6; r++) {
      final n = 8 - r;
      for (var i = 0; i < n; i++) {
        final x = 314 + r * 5.0 + i * 10.5;
        final y = 252 - r * 8.0;
        s.add(Offset(x, y));
        s.add(Offset(_w - x, y));
      }
    }
    for (var k = 0; k < 3; k++) {
      for (var i = 0; i < 17 - k; i++) {
        s.add(Offset(112 + k * 6.0 + i * 10.8, 262 - k * 8.0));
      }
    }
    return s;
  }

  // ---- state turunan
  int get _floors => math.min(3, math.max(1, (d.rooms / 4).ceil()));
  double get _roofY => _gy - _floors * _fh;
  bool get _critical => d.trashRatio >= 0.9 && !d.eliminated;

  double get _litFactor {
    final r = d.trashRatio;
    if (r >= 0.9) return 0.3;
    if (r >= 0.75) return 0.6;
    if (r >= 0.5) return 0.85;
    return 1.0;
  }

  double? _fxProgress(FxType type, int durMs) {
    double? best;
    for (final f in d.fx) {
      if (f.type != type) continue;
      final a = f.age;
      if (a < 0 || a > durMs) continue;
      final v = a / durMs;
      if (best == null || v < best) best = v;
    }
    return best;
  }

  Rect _cell(int idx) {
    final floor = idx ~/ 4;
    final col = idx % 4;
    return Rect.fromLTWH(_bl + col * _cw, _gy - (floor + 1) * _fh, _cw, _fh);
  }

  @override
  bool shouldRepaint(covariant KostPainter oldDelegate) => true;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = sceneNowMs() / 1000.0;

    // area "panggung": layar dikurangi area HUD/panel
    final stage = Rect.fromLTRB(
      insets.left,
      insets.top,
      math.max(insets.left + 40, size.width - insets.right),
      math.max(insets.top + 40, size.height - insets.bottom),
    );
    final s = math.min(stage.width / _w, stage.height / _h);
    final ox = stage.center.dx - _w / 2 * s;
    final oy = stage.bottom - _h * s;
    _vl = -ox / s - 24;
    _vr = (size.width - ox) / s + 24;
    _vt = -oy / s - 24;
    _vb = (size.height - oy) / s + 24;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(ox, oy);
    canvas.scale(s);

    final shake = _fxProgress(FxType.collapse, 1500);
    if (shake != null) {
      canvas.translate(math.sin(shake * 60) * 4 * (1 - shake), 0);
    }

    final p = _c01(d.pollution / 100);
    _drawSky(canvas, t, p);
    _drawHills(canvas, p);
    _drawSkyline(canvas, p);
    _drawTrees(canvas, t, p);
    _drawGround(canvas, t, p);
    _drawCars(canvas, t);
    _drawBuilding(canvas, t);
    _drawFleeing(canvas, t);
    _drawDefense(canvas, t);
    _drawBags(canvas);
    _drawRats(canvas, t);
    _drawStinkAndFlies(canvas, t);
    _drawCrows(canvas, t);
    _drawTruck(canvas, t);
    _drawFire(canvas, t);
    _drawCollapse(canvas);
    _drawCrane(canvas, t);
    _drawThrown(canvas, t);
    _drawAsh(canvas, t, p);
    _drawHaze(canvas, p);

    if (_critical) {
      final pulse = 0.5 + 0.5 * math.sin(t * 6);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = const Color(0xFFD32F2F).withValues(alpha: 0.12 + 0.25 * pulse);
      canvas.drawRect(_view, _p);
      _p.style = PaintingStyle.fill;
    }
    if (d.eliminated) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF1E1E1E).withValues(alpha: 0.4);
      canvas.drawRect(_view, _p);
    }

    canvas.restore();
  }

  // ----------------------------------------------------------- langit

  void _drawSky(Canvas canvas, double t, double p) {
    final heavy = _c01(p * 1.2 + (d.smog ? 0.25 : 0));
    final top = _mix(const Color(0xFF5BB4EA), const Color(0xFF7B746A), heavy);
    final bottom = _mix(const Color(0xFFE3F5FB), const Color(0xFFB3A48E), heavy);
    final rect = Rect.fromLTRB(_vl, _vt, _vr, _gy);
    _p
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ).createShader(rect);
    canvas.drawRect(rect, _p);
    _p.shader = null;

    // matahari: meredup saat polusi naik, sinar berputar pelan
    final sunA = (1 - p * 1.1).clamp(0.15, 1.0).toDouble();
    const sun = Offset(334, 46);
    _p.color = const Color(0xFFFFF176).withValues(alpha: 0.25 * sunA);
    canvas.drawCircle(sun, 34, _p);
    if (sunA > 0.35 && !d.compact) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFE082).withValues(alpha: 0.35 * sunA);
      for (var k = 0; k < 10; k++) {
        final a = k * math.pi / 5 + t * 0.15;
        canvas.drawLine(
          sun + Offset(math.cos(a), math.sin(a)) * 22,
          sun + Offset(math.cos(a), math.sin(a)) * (30 + math.sin(t * 2 + k) * 3),
          _p,
        );
      }
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt;
    }
    _p.color = const Color(0xFFFFD54F).withValues(alpha: sunA);
    canvas.drawCircle(sun, 16, _p);

    // awan melayang melintasi seluruh lebar layar
    final span = _vr - _vl;
    final cloudColor = _mix(Colors.white, const Color(0xFF6D6760), p * 1.15);
    final nClouds = d.compact ? 3 : 6;
    for (var i = 0; i < nClouds; i++) {
      final x = ((t * (3 + i * 1.4) + i * 170) % (span + 160)) + _vl - 80;
      final y = 30.0 + (i % 3) * 24 + (i ~/ 3) * 9;
      final s = 0.7 + (i % 3) * 0.22;
      _p.color = cloudColor.withValues(alpha: 0.93);
      canvas.drawCircle(Offset(x, y), 13 * s, _p);
      canvas.drawCircle(Offset(x + 15 * s, y - 7 * s), 17 * s, _p);
      canvas.drawCircle(Offset(x + 32 * s, y), 13 * s, _p);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 10 * s, y, 52 * s, 12 * s),
          Radius.circular(6 * s),
        ),
        _p,
      );
      _p.color = Colors.black.withValues(alpha: 0.06);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 6 * s, y + 6 * s, 44 * s, 6 * s),
          Radius.circular(3 * s),
        ),
        _p,
      );
    }

    // burung hanya muncul saat udara bersih
    if (p < 0.4 && !d.compact) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF37474F);
      for (var k = 0; k < 4; k++) {
        final x = ((t * (16 + k * 5) + k * 140) % (span + 120)) + _vl - 60;
        final y = 62.0 + k * 15 + math.sin(t * 2 + k) * 4;
        final flap = math.sin(t * 9 + k * 1.3) * 3.2;
        canvas.drawLine(Offset(x - 6, y - flap), Offset(x, y), _p);
        canvas.drawLine(Offset(x, y), Offset(x + 6, y - flap), _p);
      }
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt;
    }
  }

  void _drawHills(Canvas canvas, double p) {
    if (d.compact) return;
    for (var layer = 0; layer < 2; layer++) {
      final c = layer == 0
          ? _mix(const Color(0xFFA9D6B5), const Color(0xFF8E8A70), p)
          : _mix(const Color(0xFF8CC49C), const Color(0xFF7A7458), p);
      final base = _gy - (layer == 0 ? 54 : 36);
      final amp = layer == 0 ? 20.0 : 13.0;
      final fq = layer == 0 ? 0.014 : 0.022;
      final path = Path()..moveTo(_vl, _gy);
      for (var x = _vl; x <= _vr + 12; x += 12) {
        path.lineTo(x, base - amp * math.sin(x * fq + layer * 2.0) - amp * 0.4 * math.sin(x * fq * 2.3));
      }
      path.lineTo(_vr + 12, _gy);
      path.close();
      _p
        ..style = PaintingStyle.fill
        ..color = c.withValues(alpha: 0.9);
      canvas.drawPath(path, _p);
    }
  }

  void _drawSkyline(Canvas canvas, double p) {
    final c = _mix(const Color(0xFFB5CFDB), const Color(0xFF8E857A), p);
    final start = (_vl / 34).floor();
    final end = (_vr / 34).ceil();
    for (var k = start; k < end; k++) {
      final h = _hh(k + 1000);
      if (h % 4 == 0) continue;
      final bh = 36.0 + (h % 70);
      final bw = 24.0 + (h % 11);
      final x = k * 34.0;
      _p
        ..style = PaintingStyle.fill
        ..color = c.withValues(alpha: 0.62);
      canvas.drawRect(Rect.fromLTWH(x, _gy - bh, bw, bh), _p);
      if (!d.compact) {
        _p.color = Colors.white.withValues(alpha: 0.2);
        for (var yy = _gy - bh + 6; yy < _gy - 8; yy += 12) {
          for (var xx = x + 4; xx < x + bw - 4; xx += 8) {
            canvas.drawRect(Rect.fromLTWH(xx, yy, 3, 4), _p);
          }
        }
      }
    }
  }

  void _drawTrees(Canvas canvas, double t, double p) {
    final start = (_vl / 90).floor() - 1;
    final end = (_vr / 90).ceil() + 1;
    final canopy = _mix(const Color(0xFF4CAF50), const Color(0xFF8D8B4A), p * 1.2);
    final canopy2 = _mix(const Color(0xFF66BB6A), const Color(0xFFA09A5A), p * 1.2);

    // pohon (hanya di luar area bangunan & tumpukan sampah)
    for (var k = start; k < end; k++) {
      final h = _hh(k + 77);
      final x = k * 90.0 + 20 + (h % 30);
      if (x > -14 && x < 414) continue;
      final sway = math.sin(t * 1.2 + k) * 1.6 * (1 - p);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF6D4C41);
      canvas.drawRect(Rect.fromLTWH(x - 2.5, _gy - 26, 5, 30), _p);
      _p.color = canopy;
      canvas.drawCircle(Offset(x + sway, _gy - 36), 15, _p);
      canvas.drawCircle(Offset(x - 11 + sway, _gy - 27), 11, _p);
      canvas.drawCircle(Offset(x + 11 + sway, _gy - 27), 11, _p);
      _p.color = canopy2;
      canvas.drawCircle(Offset(x - 4 + sway, _gy - 40), 8, _p);
    }

    // lampu jalan
    final ls = (_vl / 180).floor() - 1;
    final le = (_vr / 180).ceil() + 1;
    for (var k = ls; k < le; k++) {
      final x = k * 180.0 + 62;
      if (x > -14 && x < 414) continue;
      _p.color = const Color(0xFF546E7A);
      canvas.drawRect(Rect.fromLTWH(x - 1.5, _gy - 44, 3, 48), _p);
      canvas.drawRect(Rect.fromLTWH(x - 1.5, _gy - 46, 12, 3), _p);
      final glow = 0.15 + p * 0.25;
      _p.color = const Color(0xFFFFE082).withValues(alpha: glow);
      canvas.drawCircle(Offset(x + 9, _gy - 42), 12, _p);
      _p.color = const Color(0xFFFFF59D);
      canvas.drawCircle(Offset(x + 9, _gy - 43), 3, _p);
    }
  }

  void _drawGround(Canvas canvas, double t, double p) {
    final grass = _mix(const Color(0xFF8DBB7A), const Color(0xFF7A7A5A), p);
    _p
      ..style = PaintingStyle.fill
      ..color = grass;
    canvas.drawRect(Rect.fromLTRB(_vl, _gy - 4, _vr, _gy + 6), _p);

    // bunga hanya tumbuh saat udara cukup bersih
    if (p < 0.5 && !d.compact) {
      const flowers = [Color(0xFFFF8A80), Color(0xFFFFF176), Color(0xFFCE93D8), Color(0xFFFFFFFF)];
      final s = (_vl / 17).floor();
      final e = (_vr / 17).ceil();
      for (var k = s; k < e; k++) {
        final h = _hh(k + 300);
        if (h % 3 != 0) continue;
        _p.color = flowers[h % flowers.length];
        canvas.drawCircle(Offset(k * 17.0 + (h % 9), _gy - 2 + (h % 3)), 1.6, _p);
      }
    }

    // trotoar + ubin
    _p.color = _mix(const Color(0xFFD0C9B8), const Color(0xFFA39C8C), p);
    canvas.drawRect(Rect.fromLTRB(_vl, _gy + 6, _vr, 270), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = Colors.black.withValues(alpha: 0.08);
    for (var x = (_vl / 26).floor() * 26.0; x < _vr; x += 26) {
      canvas.drawLine(Offset(x, _gy + 6), Offset(x - 5, 270), _p);
    }
    canvas.drawLine(Offset(_vl, 253), Offset(_vr, 253), _p);
    _p.style = PaintingStyle.fill;

    // jalan
    _p.color = const Color(0xFF9EA2A6);
    canvas.drawRect(Rect.fromLTRB(_vl, 270, _vr, 273), _p);
    _p.color = const Color(0xFF4B4F55);
    canvas.drawRect(Rect.fromLTRB(_vl, 273, _vr, _vb), _p);
    _p.color = Colors.white.withValues(alpha: 0.65);
    for (var x = (_vl / 46).floor() * 46.0; x < _vr; x += 46) {
      canvas.drawRect(Rect.fromLTWH(x, 287, 24, 2.5), _p);
    }
  }

  // mobil lewat sebagai suasana kota
  void _drawCars(Canvas canvas, double t) {
    final span = _vr - _vl + 220;
    final n = d.compact ? 1 : 3;
    for (var k = 0; k < n; k++) {
      final right = k % 2 == 0;
      final speed = 36.0 + k * 11;
      final x = (t * speed + k * 190) % span;
      final cx = right ? _vl - 110 + x : _vr + 110 - x;
      _car(canvas, cx, right ? 296 : 281, k, right);
    }
  }

  void _car(Canvas canvas, double x, double y, int k, bool right) {
    canvas.save();
    canvas.translate(x, y);
    if (!right) canvas.scale(-1, 1);
    _p
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.22);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 40, height: 4), _p);
    _p.color = _carColors[k % _carColors.length];
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-17, -11, 34, 8), const Radius.circular(3)),
      _p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-9, -11)
        ..lineTo(-5, -18)
        ..lineTo(7, -18)
        ..lineTo(11, -11)
        ..close(),
      _p,
    );
    _p.color = const Color(0xFFB3E5FC);
    canvas.drawPath(
      Path()
        ..moveTo(-6.5, -11)
        ..lineTo(-3.5, -16.5)
        ..lineTo(0, -16.5)
        ..lineTo(0, -11)
        ..close(),
      _p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(2, -11)
        ..lineTo(2, -16.5)
        ..lineTo(6, -16.5)
        ..lineTo(8.5, -11)
        ..close(),
      _p,
    );
    _p.color = const Color(0xFFFFF59D);
    canvas.drawRect(const Rect.fromLTWH(15, -9, 3, 3), _p);
    _p.color = const Color(0xFFEF5350);
    canvas.drawRect(const Rect.fromLTWH(-18, -9, 2, 3), _p);
    for (final wx in const [-9.0, 9.0]) {
      _p.color = const Color(0xFF212121);
      canvas.drawCircle(Offset(wx, -3), 3.6, _p);
      _p.color = const Color(0xFFBDBDBD);
      canvas.drawCircle(Offset(wx, -3), 1.4, _p);
    }
    canvas.restore();
  }

  // --------------------------------------------------------- bangunan

  void _drawBuilding(Canvas canvas, double t) {
    final floors = _floors;
    final roofY = _roofY;
    final buildP = _fxProgress(FxType.build, 2200);
    final newest = d.rooms - 1;

    // bayangan di tanah
    _p
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.18);
    canvas.drawOval(Rect.fromLTWH(_bl - 12, _gy + 1, 214, 11), _p);

    for (var idx = 0; idx < floors * 4; idx++) {
      final r = _cell(idx);
      if (idx >= d.rooms) {
        _scaffold(canvas, r);
        continue;
      }
      double scale = 1;
      if (buildP != null && idx == newest) {
        if (buildP < 0.35) {
          _scaffold(canvas, r);
          continue;
        }
        scale = _easeOutBack((buildP - 0.35) / 0.3);
      }
      canvas.save();
      if (scale != 1) {
        canvas.translate(r.center.dx, r.center.dy);
        canvas.scale(scale);
        canvas.translate(-r.center.dx, -r.center.dy);
      }
      _drawRoom(canvas, r, idx, t);
      canvas.restore();
    }

    // koin naik dari kamar yang menghasilkan uang
    if (!d.compact && !d.eliminated && d.trashRatio < 0.9) {
      for (var idx = 0; idx < math.min(d.rooms, floors * 4); idx++) {
        final h = _hh(idx);
        if (h % 3 != 0) continue;
        final phase = (t * 0.4 + (h % 10) / 10) % 1.0;
        final r = _cell(idx);
        final a = ((phase < 0.2 ? phase / 0.2 : 1.0) * (1 - phase)).clamp(0.0, 1.0);
        _p.color = const Color(0xFFFFC107).withValues(alpha: a);
        canvas.drawCircle(Offset(r.center.dx, r.top + 6 - phase * 26), 3.4, _p);
        _p.color = const Color(0xFFFFF59D).withValues(alpha: a);
        canvas.drawCircle(Offset(r.center.dx - 0.8, r.top + 5.2 - phase * 26), 1.2, _p);
      }
    }

    // atap berpola genteng
    final roofColor = _mix(d.wall, const Color(0xFF8D4B3B), 0.75);
    final roof = Path()
      ..moveTo(_bl - 8, roofY)
      ..lineTo(_bl + 10, roofY - 22)
      ..lineTo(_bl + 180, roofY - 22)
      ..lineTo(_bl + 198, roofY)
      ..close();
    _p
      ..style = PaintingStyle.fill
      ..color = roofColor;
    canvas.drawPath(roof, _p);
    canvas.save();
    canvas.clipPath(roof);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = _mix(roofColor, Colors.black, 0.35).withValues(alpha: 0.6);
    for (var y = roofY - 17; y < roofY; y += 5.5) {
      canvas.drawLine(Offset(_bl - 8, y), Offset(_bl + 190, y), _p);
    }
    for (var row = 0; row < 4; row++) {
      for (var x = _bl - 8 + (row % 2) * 6.0; x < _bl + 190; x += 12) {
        canvas.drawLine(Offset(x, roofY - 22 + row * 5.5), Offset(x, roofY - 16.5 + row * 5.5), _p);
      }
    }
    canvas.restore();
    _p
      ..style = PaintingStyle.fill
      ..color = _mix(roofColor, Colors.black, 0.3);
    canvas.drawRect(Rect.fromLTWH(_bl - 8, roofY - 3, 206, 3), _p);

    // tangki air
    _p.color = const Color(0xFF78909C);
    canvas.drawRect(Rect.fromLTWH(238, roofY - 40, 24, 18), _p);
    _p.color = const Color(0xFF546E7A);
    canvas.drawPath(
      Path()
        ..moveTo(236, roofY - 40)
        ..lineTo(250, roofY - 47)
        ..lineTo(264, roofY - 40)
        ..close(),
      _p,
    );
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF455A64);
    canvas.drawLine(Offset(238, roofY - 33), Offset(262, roofY - 33), _p);
    canvas.drawLine(Offset(238, roofY - 27), Offset(262, roofY - 27), _p);

    // parabola di atap
    canvas.drawLine(Offset(274, roofY - 22), Offset(274, roofY - 30), _p);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFECEFF1);
    canvas.drawArc(Rect.fromLTWH(267, roofY - 38, 14, 12), 0.4, 2.6, true, _p);

    // papan nama
    _p.color = const Color(0xFF477A62);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(120, roofY - 41, 58, 19),
        const Radius.circular(3),
      ),
      _p,
    );
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(121.5, roofY - 39.5, 55, 16),
        const Radius.circular(2),
      ),
      _p,
    );
    _p
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawPath(
      Path()
        ..moveTo(125, roofY - 31)
        ..lineTo(132, roofY - 38)
        ..lineTo(139, roofY - 31)
        ..close(),
      _p,
    );
    canvas.drawRect(Rect.fromLTWH(127, roofY - 31, 10, 6), _p);
    _signText.paint(canvas, Offset(143, roofY - 36));
    _p.color = const Color(0xFF546E7A);
    canvas.drawRect(Rect.fromLTWH(131, roofY - 22, 3, 3), _p);
    canvas.drawRect(Rect.fromLTWH(164, roofY - 22, 3, 3), _p);

    // lampu darurat saat sampah hampir penuh
    if (_critical) {
      final pulse = 0.5 + 0.5 * math.sin(t * 8);
      _p.color = const Color(0xFFFF1744).withValues(alpha: 0.25 + 0.3 * pulse);
      canvas.drawCircle(Offset(205, roofY - 27), 13, _p);
      _p.color = const Color(0xFFFF1744);
      canvas.drawCircle(Offset(205, roofY - 27), 4.5, _p);
    }
  }

  void _scaffold(Canvas canvas, Rect r) {
    final a = r.deflate(2);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF8D6E4B).withValues(alpha: 0.08);
    canvas.drawRect(a, _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF8D6E4B).withValues(alpha: 0.5);
    canvas.drawRect(a, _p);
    canvas.drawLine(a.topLeft, a.bottomRight, _p);
    canvas.drawLine(a.topRight, a.bottomLeft, _p);
    canvas.drawLine(a.centerLeft, a.centerRight, _p);
    _p.style = PaintingStyle.fill;
  }

  void _drawRoom(Canvas canvas, Rect r, int idx, double t) {
    final wall = d.wall;
    _p
      ..style = PaintingStyle.fill
      ..color = wall;
    canvas.drawRect(r, _p);

    // tekstur dinding & lantai beton
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = _mix(wall, Colors.black, 0.12).withValues(alpha: 0.6);
    canvas.drawLine(Offset(r.left, r.top + 5), Offset(r.right, r.top + 5), _p);
    _p
      ..style = PaintingStyle.fill
      ..color = _mix(wall, Colors.black, 0.22);
    canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - 3, r.width, 3), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _mix(wall, Colors.black, 0.28);
    canvas.drawRect(r, _p);

    final lit = !d.eliminated && ((_hh(idx) % 100) / 100) < _litFactor;
    final win = Rect.fromLTWH(r.left + 9, r.top + 9, r.width - 18, 26);

    if (lit) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFE082).withValues(alpha: 0.2);
      canvas.drawRect(win.inflate(3), _p);
    }
    _p
      ..style = PaintingStyle.fill
      ..color = lit ? const Color(0xFFFFDD7A) : const Color(0xFF39465A);
    canvas.drawRect(win, _p);

    // penghuni di balik jendela
    if (lit && !d.compact && idx % 3 != 1) {
      canvas.save();
      canvas.clipRect(win);
      final cx = win.center.dx + math.sin(t * 1.3 + idx) * 5;
      const shirts = [
        Color(0xFF42A5F5),
        Color(0xFFEF5350),
        Color(0xFF66BB6A),
        Color(0xFFAB47BC),
      ];
      final shirt = shirts[_hh(idx + 3) % shirts.length];
      _p
        ..style = PaintingStyle.fill
        ..color = shirt;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 4.5, win.bottom - 8, 9, 9),
          const Radius.circular(3),
        ),
        _p,
      );
      if (idx % 4 == 0) {
        // melambaikan tangan
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = shirt;
        canvas.drawLine(
          Offset(cx + 4, win.bottom - 6),
          Offset(cx + 8, win.bottom - 13 + math.sin(t * 7 + idx) * 2),
          _p,
        );
        _p.strokeCap = StrokeCap.butt;
      }
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFE0AC84);
      canvas.drawCircle(Offset(cx, win.bottom - 11), 3.3, _p);
      _p.color = const Color(0xFF3E2723);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, win.bottom - 11.5), radius: 3.4),
        math.pi,
        math.pi,
        true,
        _p,
      );
      canvas.restore();
    }

    // pantulan kaca
    _p
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: lit ? 0.18 : 0.1);
    canvas.drawPath(
      Path()
        ..moveTo(win.left, win.top + 10)
        ..lineTo(win.left + 10, win.top)
        ..lineTo(win.left + 17, win.top)
        ..lineTo(win.left, win.top + 17)
        ..close(),
      _p,
    );

    // tirai
    _p.color = (idx % 2 == 0 ? const Color(0xFFE57373) : const Color(0xFF4DB6AC))
        .withValues(alpha: 0.85);
    canvas.drawPath(
      Path()
        ..moveTo(win.left, win.top)
        ..lineTo(win.left + 7, win.top)
        ..lineTo(win.left, win.top + 11)
        ..close(),
      _p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(win.right, win.top)
        ..lineTo(win.right - 7, win.top)
        ..lineTo(win.right, win.top + 11)
        ..close(),
      _p,
    );

    // bingkai
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFF6B5843);
    canvas.drawRect(win, _p);
    canvas.drawLine(Offset(win.center.dx, win.top), Offset(win.center.dx, win.bottom), _p);
    _p.style = PaintingStyle.fill;

    // lis jendela + dekorasi
    _p.color = _mix(wall, Colors.black, 0.3);
    canvas.drawRect(Rect.fromLTWH(r.left + 6, win.bottom + 1, r.width - 12, 3), _p);
    if (idx % 2 == 0) {
      _p.color = const Color(0xFF8D6E63);
      canvas.drawRect(Rect.fromLTWH(r.left + 9, win.bottom - 1.5, 6, 3), _p);
      _p.color = const Color(0xFF66BB6A);
      canvas.drawCircle(Offset(r.left + 12, win.bottom - 3.5), 3, _p);
    }
    if (idx % 4 == 2) {
      // AC outdoor
      _p.color = const Color(0xFFECEFF1);
      canvas.drawRect(Rect.fromLTWH(r.right - 20, r.top + 39, 13, 7), _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFF90A4AE);
      canvas.drawLine(Offset(r.right - 17, r.top + 40), Offset(r.right - 17, r.top + 45), _p);
      canvas.drawLine(Offset(r.right - 13, r.top + 40), Offset(r.right - 13, r.top + 45), _p);
      _p.style = PaintingStyle.fill;
    } else if (!d.compact && idx % 5 == 1) {
      // jemuran
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFF8D6E63);
      canvas.drawLine(Offset(r.left + 6, r.top + 40), Offset(r.right - 6, r.top + 40), _p);
      _p.style = PaintingStyle.fill;
      const clothes = [Color(0xFFEF5350), Color(0xFF42A5F5), Color(0xFFFFEE58)];
      for (var k = 0; k < 3; k++) {
        _p.color = clothes[(k + idx) % 3];
        canvas.drawRect(
          Rect.fromLTWH(r.left + 10 + k * 10, r.top + 40, 6, 6 + math.sin(t * 2 + k + idx) * 0.9),
          _p,
        );
      }
    }
    if (!d.compact && idx % 7 == 3) {
      // kucing di lis jendela
      final cx = r.right - 14;
      final cy = win.bottom - 0.5;
      _p.color = const Color(0xFFFFA726);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy - 2), width: 9, height: 5), _p);
      canvas.drawCircle(Offset(cx + 4, cy - 5), 2.6, _p);
      canvas.drawPath(
        Path()
          ..moveTo(cx + 2.4, cy - 6.4)
          ..lineTo(cx + 3, cy - 9)
          ..lineTo(cx + 4.2, cy - 7)
          ..close(),
        _p,
      );
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = const Color(0xFFFFA726);
      canvas.drawLine(
        Offset(cx - 4, cy - 2),
        Offset(cx - 7, cy - 5 + math.sin(t * 3) * 1.5),
        _p,
      );
      _p.style = PaintingStyle.fill;
    }
  }

  // penghuni kabur membawa koper saat sampah sangat banyak
  void _drawFleeing(Canvas canvas, double t) {
    if (d.compact || d.eliminated || d.trashRatio < 0.75) return;
    for (var k = 0; k < 2; k++) {
      final prog = (t * 0.05 + k * 0.5) % 1.0;
      final x = 200 - prog * 300;
      const y = 266.0;
      final a = (prog < 0.1 ? prog / 0.1 : (prog > 0.9 ? (1 - prog) / 0.1 : 1.0));
      final swing = math.sin(t * 9 + k) * 2;
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF455A64).withValues(alpha: a);
      canvas.drawLine(Offset(x, y - 11), Offset(x, y - 4), _p);
      canvas.drawLine(Offset(x, y - 4), Offset(x - swing, y), _p);
      canvas.drawLine(Offset(x, y - 4), Offset(x + swing, y), _p);
      canvas.drawLine(Offset(x, y - 10), Offset(x - 5, y - 6), _p);
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt
        ..color = const Color(0xFFE0AC84).withValues(alpha: a);
      canvas.drawCircle(Offset(x, y - 14), 3, _p);
      _p.color = (k == 0 ? const Color(0xFF8D6E63) : const Color(0xFF5C6BC0)).withValues(alpha: a);
      canvas.drawRect(Rect.fromLTWH(x - 11, y - 7, 8, 7), _p);
    }
  }

  // ------------------------------------------------------- pertahanan

  void _drawDefense(Canvas canvas, double t) {
    final defP = _fxProgress(FxType.defense, 2200);

    if (d.defense >= 1) {
      final grow = defP == null ? 1.0 : _ease(defP / 0.45);
      canvas.save();
      canvas.translate(0, 254);
      canvas.scale(1, grow);
      canvas.translate(0, -254);
      if (d.defense == 1) {
        _picketFence(canvas);
      } else {
        _brickWall(canvas);
      }
      canvas.restore();
    }

    if (d.defense >= 2) {
      _guardPost(canvas, t);
      // CCTV + lampu merah berkedip
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF37474F);
      canvas.drawRect(const Rect.fromLTWH(296, 222, 8, 5), _p);
      _p.color = const Color(0xFF263238);
      canvas.drawRect(const Rect.fromLTWH(300, 227, 2, 5), _p);
      if (math.sin(t * 5) > 0) {
        _p.color = const Color(0xFFFF1744);
        canvas.drawCircle(const Offset(298, 224.5), 1.4, _p);
      }
    }

    if (d.defense >= 3) _pylons(canvas, t);

    final prot = d.protectedLeft > 0;
    if (d.defense >= 3 || prot) _dome(canvas, t, prot);

    if (defP != null) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF40C4FF).withValues(alpha: (1 - defP) * 0.8);
      canvas.drawCircle(Offset(200, _gy - 70), _lerp(40, 200, _ease(defP)), _p);
      _p.style = PaintingStyle.fill;
    }
  }

  void _picketFence(Canvas canvas) {
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFF2EAD3);
    canvas.drawRect(const Rect.fromLTWH(100, 243, 200, 2.5), _p);
    canvas.drawRect(const Rect.fromLTWH(100, 249, 200, 2.5), _p);
    for (var x = 101.0; x < 300; x += 8) {
      if (x > 184 && x < 214) continue; // celah gerbang
      canvas.drawRect(Rect.fromLTWH(x, 238, 5, 16), _p);
      canvas.drawPath(
        Path()
          ..moveTo(x, 238)
          ..lineTo(x + 2.5, 234.5)
          ..lineTo(x + 5, 238)
          ..close(),
        _p,
      );
    }
    _p.color = const Color(0xFF8D6E4B);
    canvas.drawRect(const Rect.fromLTWH(183, 233, 4, 22), _p);
    canvas.drawRect(const Rect.fromLTWH(213, 233, 4, 22), _p);
  }

  void _brickWall(Canvas canvas) {
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFB4654A);
    canvas.drawRect(const Rect.fromLTWH(100, 234, 200, 20), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF7A3F2D).withValues(alpha: 0.7);
    for (var row = 0; row < 3; row++) {
      final y = 240.0 + row * 6;
      canvas.drawLine(Offset(100, y), Offset(300, y), _p);
      for (var x = 100.0 + (row % 2) * 8; x < 300; x += 16) {
        canvas.drawLine(Offset(x, y - 6), Offset(x, y), _p);
      }
    }
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF455A64);
    for (var x = 101.0; x < 298; x += 10) {
      if (x > 186 && x < 212) continue;
      canvas.drawPath(
        Path()
          ..moveTo(x, 234)
          ..lineTo(x + 2.5, 228)
          ..lineTo(x + 5, 234)
          ..close(),
        _p,
      );
    }
    _p.color = const Color(0xFF3E2F28);
    canvas.drawRect(const Rect.fromLTWH(188, 234, 24, 20), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF90A4AE);
    for (var x = 191.0; x < 212; x += 4) {
      canvas.drawLine(Offset(x, 234), Offset(x, 254), _p);
    }
    _p.style = PaintingStyle.fill;
  }

  void _guardPost(Canvas canvas, double t) {
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFECEFF1);
    canvas.drawRect(const Rect.fromLTWH(266, 224, 24, 30), _p);
    _p.color = const Color(0xFF1565C0);
    canvas.drawPath(
      Path()
        ..moveTo(262, 224)
        ..lineTo(278, 214)
        ..lineTo(294, 224)
        ..close(),
      _p,
    );
    _p.color = const Color(0xFFB3E5FC);
    canvas.drawRect(const Rect.fromLTWH(270, 230, 16, 11), _p);
    final bob = math.sin(t * 2) * 0.8;
    _p.color = const Color(0xFFE0AC84);
    canvas.drawCircle(Offset(278, 237 + bob), 3.4, _p);
    _p.color = const Color(0xFF0D47A1);
    canvas.drawRect(Rect.fromLTWH(274.5, 232.5 + bob, 7, 2.5), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF607D8B);
    canvas.drawRect(const Rect.fromLTWH(270, 230, 16, 11), _p);
    _p.style = PaintingStyle.fill;
  }

  // dua menara energi dengan busur listrik di atas bangunan
  void _pylons(Canvas canvas, double t) {
    final pulse = 0.5 + 0.5 * math.sin(t * 4);
    for (final x in const [94.0, 306.0]) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF455A64);
      canvas.drawRect(Rect.fromLTWH(x - 2.5, 218, 5, 38), _p);
      canvas.drawRect(Rect.fromLTWH(x - 5, 252, 10, 4), _p);
      _p.color = const Color(0xFF40C4FF).withValues(alpha: 0.25 + 0.3 * pulse);
      canvas.drawCircle(Offset(x, 214), 9, _p);
      _p.color = const Color(0xFF80D8FF);
      canvas.drawCircle(Offset(x, 214), 4.5, _p);
    }
    final roofY = _roofY;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF80D8FF).withValues(alpha: 0.35 + 0.35 * pulse);
    canvas.drawPath(
      Path()
        ..moveTo(94, 214)
        ..quadraticBezierTo(200, roofY - 74 + math.sin(t * 5) * 3, 306, 214),
      _p,
    );
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }

  void _dome(Canvas canvas, double t, bool strong) {
    final color = strong ? const Color(0xFFFFD54F) : const Color(0xFF40C4FF);
    const center = Offset(200, _gy);
    const radius = 172.0;
    final pulse = 0.5 + 0.5 * math.sin(t * 3);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(_vl, _vt, _vr, _gy + 2));
    _p
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0),
          color.withValues(alpha: strong ? 0.32 + 0.12 * pulse : 0.2),
        ],
        stops: const [0, 0.7, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, _p);
    _p.shader = null;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = strong ? 2.5 : 1.6
      ..color = color.withValues(alpha: strong ? 0.8 : 0.5);
    canvas.drawCircle(center, radius, _p);
    // kilau bergerak di tepi kubah
    final a = math.pi + (t * 0.6 % 1.0) * math.pi;
    _p
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.5);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 2), a, 0.25, false, _p);
    _p.style = PaintingStyle.fill;
    canvas.restore();
  }

  // ----------------------------------------------------------- sampah

  void _bag(Canvas canvas, Offset c, int seed, {double scale = 1}) {
    final h = _hh(seed);
    final o = Offset(c.dx + ((h % 7) - 3) * 0.4, c.dy);

    // variasi sampah: kardus & ban
    if (scale == 1 && h % 9 == 0) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFC49A6C);
      canvas.drawRect(Rect.fromCenter(center: o, width: 12, height: 9), _p);
      _p.color = const Color(0xFFE0C090);
      canvas.drawRect(Rect.fromCenter(center: o.translate(0, -1), width: 12, height: 2), _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = const Color(0xFF8D6E4B);
      canvas.drawRect(Rect.fromCenter(center: o, width: 12, height: 9), _p);
      _p.style = PaintingStyle.fill;
      return;
    }
    if (scale == 1 && h % 13 == 0) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF212121);
      canvas.drawCircle(o, 4, _p);
      _p
        ..strokeWidth = 0.8
        ..color = const Color(0xFF616161);
      canvas.drawCircle(o, 2, _p);
      _p.style = PaintingStyle.fill;
      return;
    }

    final bw = (12 + h % 3) * scale;
    final bh = (10 + (h ~/ 3) % 3) * scale;
    _p
      ..style = PaintingStyle.fill
      ..color = _bagColors[h % _bagColors.length];
    canvas.drawOval(Rect.fromCenter(center: o, width: bw, height: bh), _p);
    _p.color = Colors.white.withValues(alpha: 0.14);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(o.dx - bw * 0.15, o.dy - bh * 0.15),
        width: bw * 0.35,
        height: bh * 0.3,
      ),
      _p,
    );
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * scale
      ..color = _bagColors[h % _bagColors.length];
    canvas.drawLine(
      Offset(o.dx, o.dy - bh / 2 + 1),
      Offset(o.dx + 2 * scale, o.dy - bh / 2 - 3 * scale),
      _p,
    );
    _p.style = PaintingStyle.fill;
  }

  void _drawBags(Canvas canvas) {
    final total = _slots.length;
    int count;
    if (d.eliminated) {
      count = total;
    } else if (d.trashRatio <= 0.01) {
      count = 0;
    } else {
      count = math.max(1, (math.pow(d.trashRatio, 1.15) * total).round());
    }
    for (var i = 0; i < count && i < total; i++) {
      _bag(canvas, _slots[i], i);
    }
  }

  void _drawRats(Canvas canvas, double t) {
    if (d.compact || !(d.trashRatio >= 0.75 || d.eliminated)) return;
    for (var k = 0; k < 4; k++) {
      final base = k % 2 == 0 ? 350.0 : 50.0;
      final ang = t * 1.6 + k * 2;
      final x = base + math.sin(ang) * 34;
      final y = 259.0 + (k % 2) * 3;
      final dir = math.cos(ang) >= 0 ? 1.0 : -1.0;
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF757575);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 9, height: 4.5), _p);
      canvas.drawCircle(Offset(x + dir * 5, y), 2, _p);
      _p.color = const Color(0xFFE57373);
      canvas.drawCircle(Offset(x + dir * 6.4, y - 0.6), 0.6, _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = const Color(0xFFBCAAA4);
      canvas.drawLine(Offset(x - dir * 4.5, y), Offset(x - dir * 9, y - 2 + math.sin(t * 8 + k) * 1.2), _p);
      _p.style = PaintingStyle.fill;
    }
  }

  void _drawCrows(Canvas canvas, double t) {
    if (d.compact || !(_critical || d.eliminated)) return;
    for (var k = 0; k < 3; k++) {
      final cx = k % 2 == 0 ? 350.0 : 50.0;
      final ang = t * 0.8 + k * 2.1;
      final x = cx + math.cos(ang) * 36;
      final y = 192 + math.sin(ang) * 14 - k * 8;
      final flap = math.sin(t * 9 + k) * 4;
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF101010);
      canvas.drawLine(Offset(x - 7, y - flap), Offset(x, y), _p);
      canvas.drawLine(Offset(x, y), Offset(x + 7, y - flap), _p);
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt;
    }
  }

  void _drawStinkAndFlies(Canvas canvas, double t) {
    if (!(d.trashRatio >= 0.5 || d.eliminated)) return;
    final ratio = d.eliminated ? 1.0 : d.trashRatio;

    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF9CCC65).withValues(alpha: 0.25 + 0.3 * ratio);
    for (final bx in const [336.0, 364.0, 36.0, 64.0]) {
      final path = Path()..moveTo(bx, 232);
      for (var s = 1; s <= 12; s++) {
        path.lineTo(bx + math.sin(t * 2 + s * 0.6 + bx) * 3.5, 232 - s * 2.8);
      }
      canvas.drawPath(path, _p);
    }
    _p.style = PaintingStyle.fill;

    final flies = 2 + (ratio * 10).round();
    _p.color = const Color(0xFF212121);
    for (var k = 0; k < flies; k++) {
      final cx = k % 2 == 0 ? 350.0 : 50.0;
      final x = cx + math.sin(t * (2 + k % 3) + k) * 28;
      final y = 218 + math.cos(t * (3 + k % 2) + k * 1.7) * 14 - ratio * 10;
      canvas.drawCircle(Offset(x, y), 1.1, _p);
    }
  }

  // ------------------------------------------------------ truk sampah

  void _drawTruck(Canvas canvas, double t) {
    final hp = d.haulProgress;
    if (hp == null) return;

    double x;
    var facingLeft = true;
    var moving = false;
    if (hp < 0.15) {
      x = _lerp(470, 318, _ease(hp / 0.15));
      moving = hp < 0.14;
    } else if (hp < 0.85) {
      x = 318;
    } else {
      x = _lerp(318, 470, _ease((hp - 0.85) / 0.15));
      facingLeft = false;
      moving = true;
    }

    canvas.save();
    canvas.translate(x, 297);
    if (!facingLeft) canvas.scale(-1, 1);
    if (moving) canvas.translate(0, math.sin(t * 24) * 0.7);

    _p
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.25);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 88, height: 6), _p);

    // sorot lampu depan
    _p.color = const Color(0xFFFFF59D).withValues(alpha: 0.16);
    canvas.drawPath(
      Path()
        ..moveTo(-40, -15)
        ..lineTo(-82, -4)
        ..lineTo(-82, -22)
        ..close(),
      _p,
    );

    // debu knalpot / jalan saat melaju
    if (moving) {
      for (var k = 0; k < 3; k++) {
        final ph = (t * 1.4 + k * 0.33) % 1.0;
        _p.color = const Color(0xFFBDBDBD).withValues(alpha: (1 - ph) * 0.45);
        canvas.drawCircle(Offset(44 + ph * 20, -6 - ph * 8), 3 + ph * 6, _p);
      }
    }

    // bak
    _p.color = const Color(0xFF43A047);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-16, -36, 56, 30), const Radius.circular(3)),
      _p,
    );
    _p.color = Colors.white.withValues(alpha: 0.5);
    canvas.drawRect(const Rect.fromLTWH(-16, -22, 56, 4), _p);
    _p.color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(const Offset(12, -29), 3.6, _p);
    _p.color = const Color(0xFF2E7D32);
    canvas.drawCircle(const Offset(12, -29), 1.6, _p);

    // corong belakang; tutup terbuka saat parkir
    _p.color = const Color(0xFF2E5E3A);
    canvas.drawRect(const Rect.fromLTWH(32, -36, 8, 11), _p);
    if (!moving) {
      final open = 0.5 + 0.5 * math.sin(t * 3);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF1B3B25);
      canvas.drawLine(const Offset(40, -36), Offset(40 + 7 * open, -36 - 6 * open), _p);
      _p.style = PaintingStyle.fill;
    }

    // kabin
    _p.color = const Color(0xFF2E9E5B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-40, -30, 24, 24), const Radius.circular(4)),
      _p,
    );
    _p.color = const Color(0xFFB3E5FC);
    canvas.drawRect(const Rect.fromLTWH(-38, -27, 12, 10), _p);
    _p.color = Colors.white.withValues(alpha: 0.35);
    canvas.drawRect(const Rect.fromLTWH(-37, -26, 4, 8), _p);
    _p.color = const Color(0xFF212121);
    canvas.drawRect(const Rect.fromLTWH(-42, -22, 3, 2), _p); // kaca spion
    _p.color = const Color(0xFFFFF176);
    canvas.drawRect(const Rect.fromLTWH(-41, -15, 3, 4), _p); // lampu depan
    if (math.sin(t * 8) > 0) {
      _p.color = const Color(0xFFFFA000);
      canvas.drawRect(const Rect.fromLTWH(-32, -33, 6, 3), _p);
    }

    // roda
    for (final wx in const [-26.0, 18.0]) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF212121);
      canvas.drawCircle(Offset(wx, -6), 6.5, _p);
      _p.color = const Color(0xFF9E9E9E);
      canvas.drawCircle(Offset(wx, -6), 2.6, _p);
      final a = moving ? t * 10 : 0.0;
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF616161);
      canvas.drawLine(
        Offset(wx + math.cos(a) * 2.4, -6 + math.sin(a) * 2.4),
        Offset(wx - math.cos(a) * 2.4, -6 - math.sin(a) * 2.4),
        _p,
      );
      _p.style = PaintingStyle.fill;
    }
    canvas.restore();

    if (hp >= 0.15 && hp < 0.85) _drawWorkers(canvas, t);
  }

  void _drawWorkers(Canvas canvas, double t) {
    for (var i = 0; i < 2; i++) {
      final phase = (t * 0.9 + i * 0.5) % 1.0;
      final tri = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
      final x = _lerp(382, 352, tri);
      const y = 270.0;
      final carrying = phase < 0.5;
      final swing = math.sin(t * 10 + i) * 2;

      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFF37474F);
      canvas.drawLine(Offset(x, y - 11), Offset(x, y - 4), _p);
      canvas.drawLine(Offset(x, y - 4), Offset(x - swing, y), _p);
      canvas.drawLine(Offset(x, y - 4), Offset(x + swing, y), _p);
      _p.color = const Color(0xFFFF8F00);
      canvas.drawLine(Offset(x, y - 10), Offset(x + (carrying ? 4 : 3), y - 15), _p);
      _p.style = PaintingStyle.fill;
      _p.color = const Color(0xFFE0AC84);
      canvas.drawCircle(Offset(x, y - 14), 3, _p);
      _p.color = const Color(0xFFFF8F00);
      canvas.drawRect(Rect.fromLTWH(x - 3.5, y - 18, 7, 2.5), _p);
      if (carrying) _bag(canvas, Offset(x + 4, y - 20), 900 + i, scale: 0.7);
    }
  }

  // ------------------------------------------------------------- api

  void _drawFire(Canvas canvas, double t) {
    final burnP = _fxProgress(FxType.burn, 4500);

    if (burnP != null) {
      final env = burnP < 0.15
          ? burnP / 0.15
          : (burnP > 0.8 ? (1 - burnP) / 0.2 : 1.0);
      final e = _c01(env);

      // cahaya api di sekitar tumpukan
      for (final cx in const [350.0, 50.0]) {
        _p
          ..style = PaintingStyle.fill
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFF9800).withValues(alpha: 0.4 * e),
              const Color(0xFFFF9800).withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: Offset(cx, 240), radius: 60));
        canvas.drawCircle(Offset(cx, 240), 60, _p);
        _p.shader = null;
      }

      for (var side = 0; side < 2; side++) {
        for (var k = 0; k < 6; k++) {
          final bx = 322.0 + k * 11;
          final x = side == 0 ? bx : _w - bx;
          final h = (11 + _hh(k + side * 7) % 10) * (0.5 + 0.5 * e) * e;
          _flame(canvas, x, 250 - (_hh(k) % 3) * 7.0, h, t, k + side * 6);
        }
      }

      // percikan bara
      _p.style = PaintingStyle.fill;
      for (var k = 0; k < 14; k++) {
        final ph = (t * 0.7 + k * 0.07) % 1.0;
        final base = k % 2 == 0 ? 350.0 : 50.0;
        final x = base + math.sin(k * 3.1 + ph * 6) * 22;
        final y = 242 - ph * 90;
        _p.color = const Color(0xFFFFB300).withValues(alpha: (1 - ph) * e);
        canvas.drawCircle(Offset(x, y), 1.1, _p);
      }

      // asap hitam membubung
      for (var k = 0; k < 10; k++) {
        final phase = (t * 0.25 + k * 0.1) % 1.0;
        final base = k % 2 == 0 ? 348.0 : 52.0;
        final x = base + math.sin(phase * 5 + k) * 8 + phase * 26;
        final y = 238 - phase * 150;
        _p.color = const Color(0xFF2B2B2B).withValues(alpha: (1 - phase) * 0.55 * e);
        canvas.drawCircle(Offset(x, y), 6 + phase * 18, _p);
      }
    } else if (d.burnPenalty && !d.eliminated) {
      // sisa asap tipis selama penalti
      for (var k = 0; k < 3; k++) {
        final phase = (t * 0.2 + k * 0.33) % 1.0;
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF616161).withValues(alpha: (1 - phase) * 0.28);
        canvas.drawCircle(
          Offset(350 + math.sin(phase * 4 + k) * 6 + phase * 14, 236 - phase * 70),
          4 + phase * 9,
          _p,
        );
      }
    }
  }

  void _flame(Canvas canvas, double x, double y, double h, double t, int k) {
    if (h <= 0.5) return;
    final w = h * 0.55;
    final flick = math.sin(t * 14 + k) * 0.18;
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFF6D00).withValues(alpha: 0.92);
    canvas.drawPath(
      Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x - w, y - h * 0.35, x + flick * w, y - h)
        ..quadraticBezierTo(x + w, y - h * 0.35, x, y),
      _p,
    );
    _p.color = const Color(0xFFFFEA00).withValues(alpha: 0.95);
    canvas.drawPath(
      Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x - w * 0.5, y - h * 0.25, x + flick * w * 0.5, y - h * 0.65)
        ..quadraticBezierTo(x + w * 0.5, y - h * 0.25, x, y),
      _p,
    );
  }

  void _drawCollapse(Canvas canvas) {
    final cp = _fxProgress(FxType.collapse, 1500);
    if (cp == null) return;
    for (var k = 0; k < 7; k++) {
      final x = 120.0 + k * 28;
      final y = _gy - cp * 60 * (0.5 + (k % 3) * 0.3);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF9E9E9E).withValues(alpha: (1 - cp) * 0.5);
      canvas.drawCircle(Offset(x, y), 10 + cp * 22, _p);
    }
  }

  // ----------------------------------------------------------- derek

  void _drawCrane(Canvas canvas, double t) {
    final p = _fxProgress(FxType.build, 2200);
    if (p == null) return;
    final idx = math.max(0, math.min(d.rooms - 1, _floors * 4 - 1));
    final cell = _cell(idx);
    final mastTop = _roofY - 46;
    final a = p > 0.85 ? (1 - p) / 0.15 : 1.0;

    canvas.saveLayer(
      _view,
      Paint()..color = Color.fromRGBO(0, 0, 0, a.clamp(0.0, 1.0)),
    );

    const yellow = Color(0xFFF2B01E);
    _p
      ..style = PaintingStyle.fill
      ..color = yellow;
    canvas.drawRect(Rect.fromLTWH(96, mastTop, 5, _gy - mastTop), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = const Color(0xFF6D5A12);
    for (var y = mastTop; y < _gy - 8; y += 10) {
      canvas.drawLine(Offset(96, y), Offset(101, y + 10), _p);
    }
    _p.style = PaintingStyle.fill;
    _p.color = yellow;
    canvas.drawRect(Rect.fromLTWH(86, mastTop, 216, 4), _p);
    _p.color = const Color(0xFF616161);
    canvas.drawRect(Rect.fromLTWH(84, mastTop - 2, 12, 10), _p);
    _p.color = const Color(0xFFFFCA28);
    canvas.drawRect(Rect.fromLTWH(102, mastTop - 9, 11, 9), _p);
    _p.color = const Color(0xFFB3E5FC);
    canvas.drawRect(Rect.fromLTWH(104, mastTop - 7, 5, 4), _p);

    final hx = cell.center.dx;
    final restY = mastTop + 6;
    final dropY = cell.top - 10;
    final hookY = p < 0.35
        ? _lerp(restY, dropY, _ease(p / 0.35))
        : _lerp(dropY, restY, _ease((p - 0.35) / 0.45));

    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF424242);
    canvas.drawLine(Offset(hx, mastTop + 4), Offset(hx, hookY), _p);
    _p.style = PaintingStyle.fill;
    _p.color = const Color(0xFFE65100);
    canvas.drawRect(Rect.fromLTWH(hx - 4, hookY, 8, 6), _p);
    if (p < 0.35) {
      _p.color = d.wall;
      canvas.drawRect(Rect.fromLTWH(hx - 9, hookY + 6, 18, 9), _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _mix(d.wall, Colors.black, 0.3);
      canvas.drawRect(Rect.fromLTWH(hx - 9, hookY + 6, 18, 9), _p);
      _p.style = PaintingStyle.fill;
    }
    canvas.restore();

    // debu + kilau setelah kamar terpasang
    if (p > 0.35) {
      final q = (p - 0.35) / 0.65;
      for (var k = 0; k < 4; k++) {
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFBCAAA4).withValues(alpha: (1 - q) * 0.4);
        canvas.drawCircle(
          Offset(cell.center.dx + (k - 1.5) * 12, cell.bottom - 2 - q * 6),
          4 + q * 9,
          _p,
        );
      }
      for (var k = 0; k < 6; k++) {
        final ang = k * math.pi / 3 + t * 2;
        final r = 8 + q * 34;
        final c = Offset(cell.center.dx + math.cos(ang) * r, cell.center.dy + math.sin(ang) * r);
        _p.color = const Color(0xFFFFF176).withValues(alpha: (1 - q).clamp(0.0, 1.0));
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - 4)
            ..lineTo(c.dx + 1.4, c.dy - 1.4)
            ..lineTo(c.dx + 4, c.dy)
            ..lineTo(c.dx + 1.4, c.dy + 1.4)
            ..lineTo(c.dx, c.dy + 4)
            ..lineTo(c.dx - 1.4, c.dy + 1.4)
            ..lineTo(c.dx - 4, c.dy)
            ..lineTo(c.dx - 1.4, c.dy - 1.4)
            ..close(),
          _p,
        );
      }
    }
  }

  // ---------------------------------------------------- lemparan sampah

  void _drawThrown(Canvas canvas, double t) {
    final right = d.facingRight;

    for (final f in d.fx) {
      final age = f.age.toDouble();
      if (f.type == FxType.incoming) {
        final from = Offset(right ? 440 : -40, 30);
        final to = Offset(right ? 350 : 50, 238);
        for (var j = 0; j < 5; j++) {
          final local = (age - j * 180) / 900;
          if (local < 0 || local > 1.4) continue;
          if (local <= 1) {
            final x = _lerp(from.dx, to.dx, local) + (j - 2) * 6;
            final y = _lerp(from.dy, to.dy, local) - math.sin(local * math.pi) * 60;
            canvas.save();
            canvas.translate(x, y);
            canvas.rotate(local * 9);
            _bag(canvas, Offset.zero, 500 + j);
            canvas.restore();
          } else {
            final q = (local - 1) / 0.4;
            _p
              ..style = PaintingStyle.fill
              ..color = const Color(0xFF9E9E9E).withValues(alpha: (1 - q) * 0.45);
            canvas.drawCircle(Offset(to.dx + (j - 2) * 8, 244), 6 + q * 10, _p);
          }
        }
        // kilat merah di tepi saat kena lempar
        if (!d.compact && age > 900 && age < 1500) {
          final q = (age - 900) / 600;
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = 24
            ..color = const Color(0xFFD32F2F).withValues(alpha: 0.3 * (1 - q));
          canvas.drawRect(_view, _p);
          _p.style = PaintingStyle.fill;
        }
      } else if (f.type == FxType.outgoing) {
        final from = Offset(right ? 250 : 150, _roofY - 24);
        final to = Offset(right ? 440 : -40, _roofY - 80);
        for (var j = 0; j < 3; j++) {
          final local = (age - j * 140) / 1100;
          if (local < 0 || local > 1) continue;
          final x = _lerp(from.dx, to.dx, local);
          final y = _lerp(from.dy, to.dy, local) - math.sin(local * math.pi) * 50;
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(local * 7);
          _bag(canvas, Offset.zero, 700 + j, scale: 0.9);
          canvas.restore();
        }
      }
    }
  }

  // ----------------------------------------------- abu, kabut, suasana

  void _drawAsh(Canvas canvas, double t, double p) {
    if (p < 0.55 && !d.smog) return;
    final n = d.compact ? 8 : 34;
    final spanX = _vr - _vl;
    final spanY = _gy - _vt;
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF424242).withValues(alpha: 0.45);
    for (var i = 0; i < n; i++) {
      final h = _hh(i + 50);
      final x = _vl + (h % 1000) / 1000 * spanX + math.sin(t + i) * 6;
      final y = _vt + ((t * (14 + h % 18) + h % 300) % spanY);
      canvas.drawCircle(Offset(x, y), 0.9 + (h % 3) * 0.4, _p);
    }
  }

  void _drawHaze(Canvas canvas, double p) {
    final a = p * 0.32 + (d.smog ? 0.28 : 0);
    if (a <= 0.01) return;
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF6B5E4C).withValues(alpha: a.clamp(0.0, 0.7));
    canvas.drawRect(_view, _p);
  }
}