import 'dart:math' as math;

import 'package:flutter/material.dart';

// ====================================================================
//  Adegan visual satu kost: bangunan bertingkat, tumpukan sampah, truk
//  sampah, api pembakaran, pertahanan (pagar/tembok/pos satpam/kubah),
//  derek saat membangun kamar, dan kantong sampah yang dilempar.
//
//  Semua digambar dengan CustomPainter pada kanvas virtual 400 x 300,
//  lalu diskalakan ke ukuran widget, jadi tidak butuh aset gambar.
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
  final bool compact; // versi kecil: tanpa penghuni & koin
  final bool facingRight; // arah sisi lawan (lemparan datang/pergi)
}

/// Widget siap pakai: rasio 4:3, sudut membulat.
class KostScene extends StatelessWidget {
  const KostScene({super.key, required this.data, required this.repaint});

  final KostSceneData data;
  final Listenable repaint;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: KostPainter(data, repaint),
          size: Size.infinite,
        ),
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
  KostPainter(this.d, Listenable repaint) : super(repaint: repaint);

  final KostSceneData d;
  final Paint _p = Paint();

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
    final t = sceneNowMs() / 1000.0;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / _w, size.height / _h);

    final shake = _fxProgress(FxType.collapse, 1500);
    if (shake != null) {
      canvas.translate(math.sin(shake * 60) * 4 * (1 - shake), 0);
    }

    final p = _c01(d.pollution / 100);
    _drawSky(canvas, t, p);
    _drawSkyline(canvas, p);
    _drawGround(canvas, p);
    _drawBuilding(canvas, t);
    _drawDefense(canvas, t);
    _drawBags(canvas);
    _drawStinkAndFlies(canvas, t);
    _drawTruck(canvas, t);
    _drawFire(canvas, t);
    _drawCollapse(canvas);
    _drawCrane(canvas, t);
    _drawThrown(canvas, t);
    _drawHaze(canvas, p);

    if (_critical) {
      final pulse = 0.5 + 0.5 * math.sin(t * 6);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = const Color(0xFFD32F2F).withValues(alpha: 0.12 + 0.25 * pulse);
      canvas.drawRect(const Rect.fromLTWH(0, 0, _w, _h), _p);
      _p.style = PaintingStyle.fill;
    }
    if (d.eliminated) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF1E1E1E).withValues(alpha: 0.4);
      canvas.drawRect(const Rect.fromLTWH(0, 0, _w, _h), _p);
    }

    canvas.restore();
  }

  // ----------------------------------------------------------- langit

  void _drawSky(Canvas canvas, double t, double p) {
    final heavy = _c01(p * 1.2 + (d.smog ? 0.25 : 0));
    final top = _mix(const Color(0xFF7EC8F0), const Color(0xFF8B8378), heavy);
    final bottom = _mix(const Color(0xFFDDF3FA), const Color(0xFFB3A48E), heavy);
    const rect = Rect.fromLTWH(0, 0, _w, _gy);
    _p
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ).createShader(rect);
    canvas.drawRect(rect, _p);
    _p.shader = null;

    // matahari meredup saat polusi naik
    final sunA = (1 - p * 1.1).clamp(0.15, 1.0).toDouble();
    _p.color = const Color(0xFFFFF176).withValues(alpha: 0.28 * sunA);
    canvas.drawCircle(const Offset(334, 46), 30, _p);
    _p.color = const Color(0xFFFFD54F).withValues(alpha: sunA);
    canvas.drawCircle(const Offset(334, 46), 16, _p);

    // awan melayang, makin kelabu
    final cloudColor = _mix(Colors.white, const Color(0xFF77716B), p * 1.1);
    for (var i = 0; i < 3; i++) {
      final x = ((t * (4 + i * 2) + i * 150) % 520) - 70;
      final y = 36.0 + i * 22;
      final s = 0.8 + i * 0.2;
      _p.color = cloudColor.withValues(alpha: 0.92);
      canvas.drawCircle(Offset(x, y), 13 * s, _p);
      canvas.drawCircle(Offset(x + 15 * s, y - 6 * s), 17 * s, _p);
      canvas.drawCircle(Offset(x + 32 * s, y), 13 * s, _p);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 10 * s, y, 52 * s, 12 * s),
          Radius.circular(6 * s),
        ),
        _p,
      );
    }
  }

  void _drawSkyline(Canvas canvas, double p) {
    final c = _mix(const Color(0xFFB9D3DE), const Color(0xFF8E857A), p);
    _p.color = c.withValues(alpha: 0.75);
    const blocks = [
      [0.0, 38.0, 62.0],
      [34.0, 30.0, 92.0],
      [62.0, 26.0, 52.0],
      [300.0, 30.0, 70.0],
      [328.0, 38.0, 104.0],
      [364.0, 36.0, 58.0],
    ];
    for (final b in blocks) {
      canvas.drawRect(Rect.fromLTWH(b[0], _gy - b[2], b[1], b[2]), _p);
    }
  }

  void _drawGround(Canvas canvas, double p) {
    _p.color = _mix(const Color(0xFF8DBB7A), const Color(0xFF7A7A5A), p);
    canvas.drawRect(const Rect.fromLTWH(0, _gy - 4, _w, 10), _p);
    _p.color = _mix(const Color(0xFFD0C9B8), const Color(0xFFA39C8C), p);
    canvas.drawRect(const Rect.fromLTWH(0, _gy + 4, _w, 34), _p);
    _p.color = const Color(0xFF4B4F55);
    canvas.drawRect(const Rect.fromLTWH(0, 272, _w, 28), _p);
    _p.color = const Color(0xFFB0B4B8);
    canvas.drawRect(const Rect.fromLTWH(0, 270, _w, 2), _p);
    _p.color = Colors.white.withValues(alpha: 0.6);
    for (var x = 8.0; x < _w; x += 46) {
      canvas.drawRect(Rect.fromLTWH(x, 285, 24, 2.5), _p);
    }
  }

  // --------------------------------------------------------- bangunan

  void _drawBuilding(Canvas canvas, double t) {
    final floors = _floors;
    final roofY = _roofY;
    final buildP = _fxProgress(FxType.build, 2200);
    final newest = d.rooms - 1;

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
        final a = (phase < 0.2 ? phase / 0.2 : 1.0) * (1 - phase);
        _p.color = const Color(0xFFFFC107).withValues(alpha: a.clamp(0.0, 1.0));
        canvas.drawCircle(Offset(r.center.dx, r.top + 6 - phase * 26), 3.2, _p);
        _p.color = const Color(0xFFFFF59D).withValues(alpha: a.clamp(0.0, 1.0));
        canvas.drawCircle(Offset(r.center.dx - 0.8, r.top + 5.2 - phase * 26), 1.2, _p);
      }
    }

    // atap
    final roofColor = _mix(d.wall, const Color(0xFF8D4B3B), 0.75);
    final roof = Path()
      ..moveTo(_bl - 8, roofY)
      ..lineTo(_bl + 10, roofY - 22)
      ..lineTo(_bl + 180, roofY - 22)
      ..lineTo(_bl + 198, roofY)
      ..close();
    _p.color = roofColor;
    canvas.drawPath(roof, _p);
    _p.color = _mix(roofColor, Colors.black, 0.3);
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

    // papan nama dengan ikon rumah
    _p.color = const Color(0xFF477A62);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(125, roofY - 40, 44, 18),
        const Radius.circular(3),
      ),
      _p,
    );
    _p.color = Colors.white;
    canvas.drawPath(
      Path()
        ..moveTo(137, roofY - 31)
        ..lineTo(147, roofY - 38)
        ..lineTo(157, roofY - 31)
        ..close(),
      _p,
    );
    canvas.drawRect(Rect.fromLTWH(140, roofY - 31, 14, 7), _p);

    // lampu darurat saat sampah hampir penuh
    if (_critical) {
      final pulse = 0.5 + 0.5 * math.sin(t * 8);
      _p.color = const Color(0xFFFF1744).withValues(alpha: 0.25 + 0.3 * pulse);
      canvas.drawCircle(Offset(190, roofY - 27), 12, _p);
      _p.color = const Color(0xFFFF1744);
      canvas.drawCircle(Offset(190, roofY - 27), 4.5, _p);
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
      ..color = const Color(0xFF8D6E4B).withValues(alpha: 0.45);
    canvas.drawRect(a, _p);
    canvas.drawLine(a.topLeft, a.bottomRight, _p);
    canvas.drawLine(a.topRight, a.bottomLeft, _p);
    _p.style = PaintingStyle.fill;
  }

  void _drawRoom(Canvas canvas, Rect r, int idx, double t) {
    final wall = d.wall;
    _p
      ..style = PaintingStyle.fill
      ..color = wall;
    canvas.drawRect(r, _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _mix(wall, Colors.black, 0.28);
    canvas.drawRect(r, _p);

    final lit = !d.eliminated && ((_hh(idx) % 100) / 100) < _litFactor;
    final win = Rect.fromLTWH(r.left + 9, r.top + 9, r.width - 18, 26);

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
      _p.color = shirts[_hh(idx + 3) % shirts.length];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 4.5, win.bottom - 8, 9, 9),
          const Radius.circular(3),
        ),
        _p,
      );
      _p.color = const Color(0xFFE0AC84);
      canvas.drawCircle(Offset(cx, win.bottom - 11), 3.3, _p);
      canvas.restore();
    }

    // pantulan kaca
    _p.color = Colors.white.withValues(alpha: lit ? 0.18 : 0.1);
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

    // lis + pot tanaman
    _p.color = _mix(wall, Colors.black, 0.3);
    canvas.drawRect(Rect.fromLTWH(r.left + 6, win.bottom + 1, r.width - 12, 3), _p);
    if (idx % 2 == 0) {
      _p.color = const Color(0xFF66BB6A);
      canvas.drawCircle(Offset(r.left + 12, win.bottom - 1), 3, _p);
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
      _p.color = const Color(0xFF37474F);
      canvas.drawRect(const Rect.fromLTWH(296, 222, 8, 5), _p);
      _p.color = const Color(0xFF263238);
      canvas.drawRect(const Rect.fromLTWH(300, 227, 2, 5), _p);
      if (math.sin(t * 5) > 0) {
        _p.color = const Color(0xFFFF1744);
        canvas.drawCircle(const Offset(298, 224.5), 1.4, _p);
      }
    }

    final prot = d.protectedLeft > 0;
    if (d.defense >= 3 || prot) _dome(canvas, t, prot);

    if (defP != null) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF40C4FF).withValues(alpha: (1 - defP) * 0.8);
      canvas.drawCircle(
        Offset(200, _gy - 70),
        _lerp(40, 200, _ease(defP)),
        _p,
      );
      _p.style = PaintingStyle.fill;
    }
  }

  void _picketFence(Canvas canvas) {
    const cream = Color(0xFFF2EAD3);
    _p
      ..style = PaintingStyle.fill
      ..color = cream;
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
    // paku di puncak tembok
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
    // gerbang besi
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

  void _dome(Canvas canvas, double t, bool strong) {
    final color = strong ? const Color(0xFFFFD54F) : const Color(0xFF40C4FF);
    final center = const Offset(200, _gy);
    const radius = 172.0;
    final pulse = 0.5 + 0.5 * math.sin(t * 3);
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(0, 0, _w, _gy + 2));
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
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      a,
      0.25,
      false,
      _p,
    );
    _p.style = PaintingStyle.fill;
    canvas.restore();
  }

  // ----------------------------------------------------------- sampah

  void _bag(Canvas canvas, Offset c, int seed, {double scale = 1}) {
    final h = _hh(seed);
    final bw = (12 + h % 3) * scale;
    final bh = (10 + (h ~/ 3) % 3) * scale;
    final o = Offset(c.dx + ((h % 7) - 3) * 0.4, c.dy);
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
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 0), width: 88, height: 6), _p);

    // bak + kabin
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
    _p.color = const Color(0xFF2E5E3A);
    canvas.drawRect(const Rect.fromLTWH(32, -36, 8, 11), _p);

    _p.color = const Color(0xFF2E9E5B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-40, -30, 24, 24), const Radius.circular(4)),
      _p,
    );
    _p.color = const Color(0xFFB3E5FC);
    canvas.drawRect(const Rect.fromLTWH(-38, -27, 12, 10), _p);
    if (math.sin(t * 8) > 0) {
      _p.color = const Color(0xFFFFA000);
      canvas.drawRect(const Rect.fromLTWH(-32, -33, 6, 3), _p);
    }

    // roda
    for (final wx in const [-26.0, 18.0]) {
      _p.color = const Color(0xFF212121);
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
      for (var side = 0; side < 2; side++) {
        for (var k = 0; k < 6; k++) {
          final bx = 322.0 + k * 11;
          final x = side == 0 ? bx : _w - bx;
          final h = (11 + _hh(k + side * 7) % 10) * (0.5 + 0.5 * e) * e;
          _flame(canvas, x, 250 - (_hh(k) % 3) * 7.0, h, t, k + side * 6);
        }
      }
      // asap hitam membubung
      for (var k = 0; k < 10; k++) {
        final phase = (t * 0.25 + k * 0.1) % 1.0;
        final base = k % 2 == 0 ? 348.0 : 52.0;
        final x = base + math.sin(phase * 5 + k) * 8 + phase * 26;
        final y = 238 - phase * 150;
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF2B2B2B).withValues(alpha: (1 - phase) * 0.55 * e);
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
      const Rect.fromLTWH(0, 0, _w, _h),
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

    // kilau setelah kamar terpasang
    if (p > 0.35) {
      final q = (p - 0.35) / 0.65;
      for (var k = 0; k < 6; k++) {
        final ang = k * math.pi / 3 + t * 2;
        final r = 8 + q * 34;
        final c = Offset(cell.center.dx + math.cos(ang) * r, cell.center.dy + math.sin(ang) * r);
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFFF176).withValues(alpha: (1 - q).clamp(0.0, 1.0));
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
            ..strokeWidth = 14
            ..color = const Color(0xFFD32F2F).withValues(alpha: 0.3 * (1 - q));
          canvas.drawRect(const Rect.fromLTWH(0, 0, _w, _h), _p);
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

  // ------------------------------------------------------------- kabut

  void _drawHaze(Canvas canvas, double p) {
    final a = p * 0.32 + (d.smog ? 0.28 : 0);
    if (a <= 0.01) return;
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF6B5E4C).withValues(alpha: a.clamp(0.0, 0.7));
    canvas.drawRect(const Rect.fromLTWH(0, 0, _w, _h), _p);
  }
}