import 'dart:math' as math;

import 'package:flutter/material.dart';

// ====================================================================
//  LALU LINTAS JALAN DEPAN KOST
// ====================================================================
//
//  * Lajur kiri (kemudi di kiri jalan, seperti di Indonesia): lajur dekat
//    penonton melaju ke KIRI layar, lajur jauh ke KANAN layar.
//  * 5 aliran: mobil (2 lajur), motor (2 tepi lajur), sepeda (1 jalur).
//  * Gerak 100% fungsi waktu (tanpa state): semua kendaraan dalam satu aliran
//    berkecepatan dasar sama, ditambah ayunan sinus kecil. Ayunan inilah yang
//    memberi kesan menginjak gas / rem (badan menunduk, lampu rem menyala)
//    tanpa pernah saling menembus: selisih ayunan dibatasi lebih kecil dari
//    jarak antar kendaraan.
//  * Saat kendaraan keluar layar dan masuk lagi dari sisi seberang, identitasnya
//    (jenis, warna, muatan) diundi ulang, jadi tidak ada pola berulang.
//  * Roda berputar menurut JARAK TEMPUH sebenarnya (bukan waktu), sehingga
//    selalu selaras dengan laju kendaraan.
//  * Malam / hujan: berkas lampu + genangan cahaya di aspal, pantulan di
//    jalan basah, jendela angkot & bus menyala dari dalam.
//  * Lajur jauh berkabut tipis (perspektif udara); debu roda & asap knalpot
//    menebal saat kendaraan menginjak gas dan saat polusi tinggi.

enum _Kind { car, motor, bicycle }

class _Lane {
  const _Lane(this.y, this.right, this.speed, this.scale, this.kind,
      this.spacing, this.haze);

  final double y; // garis tanah di koordinat rumah
  final bool right; // arah laju di layar
  final double speed; // px/detik (kecepatan dasar aliran)
  final double scale; // perspektif (lajur jauh sedikit lebih kecil)
  final _Kind kind;
  final double spacing; // jarak rata-rata antar kendaraan
  final double haze; // 0..1 kabut perspektif (lajur jauh lebih pucat)
}

class _Shape {
  const _Shape({
    required this.half,
    required this.rw,
    required this.fw,
    required this.wr,
    required this.top,
    required this.cabin,
    required this.windows,
    required this.heads,
    required this.lensY,
    this.rails = false,
  });

  final double half; // setengah panjang
  final double rw; // sumbu roda belakang (x)
  final double fw; // sumbu roda depan (x)
  final double wr; // jari-jari roda
  final double top; // garis pinggang bodi (y)
  final List<double> cabin; // poligon kabin (x,y,x,y,...)
  final List<List<double>> windows;
  final List<Offset> heads; // posisi kepala pengemudi/penumpang
  final double lensY;
  final bool rails;
}

class KostTraffic {
  KostTraffic._();

  static final Paint _p = Paint();
  static final Map<String, TextPainter> _labels = <String, TextPainter>{};

  // Pengaturan per frame (diisi di paint).
  static double _poll = 0;
  static bool _lights = false;
  static bool _rain = false;
  static bool _low = false;
  static bool _mirror = false;
  static double _hz = 0; // kabut lajur yang sedang digambar
  static double _density = 1.0; // 0..1 kepadatan kendaraan (jam sibuk/sepi)

  /// Pengendara bermasker saat udara kotor; makin kotor makin banyak yang
  /// memakainya (acak tetap per kendaraan, jadi tidak berkedip).
  static bool _masked(int id) {
    if (_poll < 0.35) return false;
    final k = ((_poll - 0.35) / 0.4).clamp(0.0, 1.0);
    return ((id >> 9) % 100) / 100.0 < k;
  }

  static void _mask(Canvas c, Offset head) {
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFB3E5FC);
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(head.dx + 0.2, head.dy - 0.1, 2.9, 1.9),
          const Radius.circular(0.6)),
      _p,
    );
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.35
      ..color = const Color(0xFFECEFF1);
    c.drawLine(Offset(head.dx + 0.2, head.dy + 0.5),
        Offset(head.dx - 1.6, head.dy - 0.4), _p);
    _p.style = PaintingStyle.fill;
  }

  /// Cache shader gradien (kunci = bounds + warna) supaya tidak membuat ulang
  /// ratusan shader per frame. Dibersihkan otomatis bila terlalu besar.
  static final Map<int, Shader> _shaders = <int, Shader>{};

  static const List<_Lane> _lanes = [
    _Lane(278.5, true, 56, 0.92, _Kind.motor, 300, 0.14), // tepi lajur jauh
    _Lane(281, true, 37, 0.95, _Kind.car, 340, 0.12), // mobil, lajur jauh
    _Lane(292, false, 25, 1.0, _Kind.bicycle, 560, 0.03), // sepeda
    _Lane(296, false, 44, 1.0, _Kind.car, 330, 0.0), // mobil, lajur dekat
    _Lane(298.5, false, 60, 1.0, _Kind.motor, 290, 0.0), // tepi lajur dekat
  ];

  static const List<Color> _palette = [
    Color(0xFFF2F2F2),
    Color(0xFFB0BEC5),
    Color(0xFF263238),
    Color(0xFFC62828),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFEF6C00),
    Color(0xFF6D4C41),
    Color(0xFFFFD54F),
    Color(0xFF455A64),
  ];

  static const List<List<Color>> _angkotSchemes = [
    [Color(0xFF2E7D32), Color(0xFFFFFFFF)],
    [Color(0xFF1565C0), Color(0xFFFFC107)],
    [Color(0xFFEF6C00), Color(0xFFFFFFFF)],
    [Color(0xFFC62828), Color(0xFFFFEB3B)],
    [Color(0xFF6A1B9A), Color(0xFFFFFFFF)],
    [Color(0xFF00838F), Color(0xFFFFEE58)],
  ];

  static const List<List<Color>> _bus = [
    [Color(0xFFF5F5F5), Color(0xFF1565C0)],
    [Color(0xFFFFC107), Color(0xFF37474F)],
    [Color(0xFF2E7D32), Color(0xFFF5F5F5)],
    [Color(0xFFE53935), Color(0xFFF5F5F5)],
  ];

  static const List<String> _routes = [
    '01', '04', '07', '11', '12', '15', 'B2', 'K5', '3A', '08', 'D9', '21',
  ];

  static const List<Color> _jackets = [
    Color(0xFF1E88E5),
    Color(0xFFE53935),
    Color(0xFF5D4037),
    Color(0xFF455A64),
    Color(0xFFFFB300),
    Color(0xFF7B1FA2),
  ];

  static const List<Color> _skins = [
    Color(0xFFF6D2B3),
    Color(0xFFE0AC84),
    Color(0xFFC68B5E),
    Color(0xFF9C6644),
  ];

  static const _Shape _sedan = _Shape(
    half: 19.5,
    rw: -11.5,
    fw: 11.5,
    wr: 4.2,
    top: -12.5,
    cabin: [-10, -12.5, -7, -19.8, 5, -19.8, 11, -12.5],
    windows: [
      [-8.6, -12.9, -6.3, -18.6, -0.9, -18.6, -0.9, -12.9],
      [0.9, -12.9, 0.9, -18.6, 4.5, -18.6, 8.9, -12.9],
    ],
    heads: [Offset(3.0, -16.5), Offset(-3.4, -16.3)],
    lensY: -10.6,
  );

  static const _Shape _hatch = _Shape(
    half: 17,
    rw: -9,
    fw: 9.5,
    wr: 4.2,
    top: -12.5,
    cabin: [-13.6, -12.5, -10, -19.8, 4.5, -19.8, 10.5, -12.5],
    windows: [
      [-12.2, -12.9, -9.2, -18.6, -0.9, -18.6, -0.9, -12.9],
      [0.9, -12.9, 0.9, -18.6, 3.9, -18.6, 8.4, -12.9],
    ],
    heads: [Offset(2.6, -16.5), Offset(-3.6, -16.3)],
    lensY: -10.6,
  );

  static const _Shape _mpv = _Shape(
    half: 21,
    rw: -12.5,
    fw: 12.5,
    wr: 4.4,
    top: -14,
    cabin: [-18, -14, -16.5, -23.4, 6.5, -23.4, 13, -14],
    windows: [
      [-15.6, -14.5, -14.6, -21.8, -7.2, -21.8, -7.2, -14.5],
      [-5.6, -14.5, -5.6, -21.8, 1.6, -21.8, 1.6, -14.5],
      [3.2, -14.5, 3.2, -21.8, 6.0, -21.8, 10.6, -14.5],
    ],
    heads: [Offset(4.6, -18.6), Offset(-3.0, -18.4), Offset(-10.8, -18.4)],
    lensY: -11.6,
    rails: true,
  );

  // ------------------------------------------------------------- utilitas

  /// Hash deterministik (Lehmer); aman di web karena perkalian < 2^53.
  static int _th(int n) {
    var x = (n.abs() % 2147483629) + 1;
    x = (x * 48271) % 2147483647;
    x = (x * 48271) % 2147483647;
    x = (x * 48271) % 2147483647;
    return x;
  }

  static double _c01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  /// Lampu rem halus (smoothstep) dari ayunan kecepatan: menyala saat badan
  /// menunduk (melambat), padam perlahan saat mulai menginjak gas.
  static double _brake(double sinT) {
    final u = _c01((sinT - 0.3) / 0.5);
    return u * u * (3 - 2 * u);
  }

  /// Pengali asap/debu: menebal saat menginjak gas (sinT negatif).
  static double _boost(double sinT) => 1 + _c01(-sinT) * 0.9;

  static Color _onColor(Color bg) =>
      bg.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;

  static Color _shade(Color c, double k) =>
      Color.lerp(c, k > 0 ? Colors.white : Colors.black, k.abs())!;

  static Color _tint(Color c) {
    var o = Color.lerp(c, const Color(0xFF8E8E7C), _poll * 0.35)!;
    if (_hz > 0) o = Color.lerp(o, const Color(0xFFB9C7D0), _hz)!;
    return o;
  }

  static Path _poly(List<double> v) {
    final path = Path()..moveTo(v[0], v[1]);
    for (var i = 2; i < v.length; i += 2) {
      path.lineTo(v[i], v[i + 1]);
    }
    return path..close();
  }

  static TextPainter _tp(String text, double size, Color color) {
    final key = '$text|$size|${color.toARGB32()}';
    return _labels.putIfAbsent(
      key,
          () => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
  }

  /// Teks yang selalu terbaca benar walau kendaraan sedang dicerminkan.
  static void _label(
      Canvas c, String text, double cx, double cy, double size, Color color) {
    if (_low) return;
    final tp = _tp(text, size, color);
    c.save();
    c.translate(cx, cy);
    if (_mirror) c.scale(-1, 1);
    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
    c.restore();
  }

  static void _fillGrad(Canvas c, Path path, Color base) {
    final b = path.getBounds();
    final key = Object.hash(b.left, b.top, b.right, b.bottom, base.toARGB32());
    _p
      ..style = PaintingStyle.fill
      ..shader = _shaders.putIfAbsent(
        key,
            () => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_shade(base, 0.24), base, _shade(base, -0.24)],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(b),
      );
    c.drawPath(path, _p);
    _p.shader = null;
  }

  /// [lit]: jendela menyala hangat dari dalam saat malam (angkot & bus).
  static void _glass(Canvas c, Path path, {bool lit = false}) {
    final b = path.getBounds();
    final warm = lit && _lights;
    final key = Object.hash(b.left, b.top, b.right, b.bottom, _poll, _hz, warm);
    _p
      ..style = PaintingStyle.fill
      ..shader = _shaders.putIfAbsent(
        key,
            () => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: warm
              ? const [Color(0xFFFFF3C4), Color(0xFFFFC857)]
              : [
            _tint(const Color(0xFFDDF1FA)),
            _tint(const Color(0xFF6F9AB3)),
          ],
        ).createShader(b),
      );
    c.drawPath(path, _p);
    _p.shader = null;
    if (_low) return;
    // pantulan langit: jalur miring putih tipis
    c.save();
    c.clipPath(path);
    _p.color = Colors.white.withValues(alpha: 0.3);
    final w = b.width;
    c.drawPath(
      Path()
        ..moveTo(b.left + w * 0.18, b.bottom)
        ..lineTo(b.left + w * 0.42, b.top)
        ..lineTo(b.left + w * 0.58, b.top)
        ..lineTo(b.left + w * 0.34, b.bottom)
        ..close(),
      _p,
    );
    c.restore();
  }

  static void _shadow(Canvas c, double half) {
    _p
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.2);
    c.drawOval(
        Rect.fromCenter(
            center: const Offset(0, 0.4), width: half * 2.1, height: 4.2),
        _p);
    _p.color = Colors.black.withValues(alpha: 0.2);
    c.drawOval(
        Rect.fromCenter(
            center: const Offset(0, 0.3), width: half * 1.5, height: 2.2),
        _p);
  }

  static void _wheel(Canvas c, double x, double r, double dist,
      {Color rim = const Color(0xFFCFD8DC)}) {
    final y = -r;
    final ang = dist / r;
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF17171A);
    c.drawCircle(Offset(x, y), r, _p);
    if (_low) {
      _p.color = rim;
      c.drawCircle(Offset(x, y), r * 0.42, _p);
      return;
    }
    _p.color = const Color(0xFF2E2E33);
    c.drawCircle(Offset(x, y), r * 0.84, _p);
    _p.color = rim;
    c.drawCircle(Offset(x, y), r * 0.6, _p);
    // kilap ban berputar: memperjelas putaran roda walau jari-jari tipis
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.12
      ..strokeCap = StrokeCap.butt
      ..color = Colors.white.withValues(alpha: 0.1);
    for (var i = 0; i < 2; i++) {
      c.drawArc(Rect.fromCircle(center: Offset(x, y), radius: r * 0.9),
          ang + i * math.pi, 0.8, false, _p);
    }
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.55
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF78909C);
    for (var i = 0; i < 5; i++) {
      final a = ang + i * math.pi * 2 / 5;
      c.drawLine(
        Offset(x, y),
        Offset(x + math.cos(a) * r * 0.55, y + math.sin(a) * r * 0.55),
        _p,
      );
    }
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF90A4AE);
    c.drawCircle(Offset(x, y), r * 0.16, _p);
  }

  static void _headlamp(Canvas c, double x, double y,
      {double w = 2.8, double h = 2.4}) {
    _p
      ..style = PaintingStyle.fill
      ..color = _lights ? const Color(0xFFFFFDE7) : const Color(0xFFFFF59D);
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x - w / 2, y - h / 2, w, h), const Radius.circular(0.8)),
      _p,
    );
    if (!_lights || _low) return;
    _p.color = const Color(0xFFFFF59D).withValues(alpha: 0.28);
    c.drawCircle(Offset(x + 1, y), 4.2, _p);
    _p.shader = const LinearGradient(
      colors: [Color(0x66FFF9C4), Color(0x00FFF9C4)],
    ).createShader(Rect.fromLTWH(x, y - 7, 46, 14));
    c.drawPath(
      Path()
        ..moveTo(x, y - 0.8)
        ..lineTo(x + 46, y - 7)
        ..lineTo(x + 46, y + 5)
        ..lineTo(x, y + 1.0)
        ..close(),
      _p,
    );
    _p.shader = null;
  }

  static void _taillamp(Canvas c, double x, double y, double brake,
      {double w = 2.2, double h = 2.4}) {
    final strength = math.max(_lights ? 0.55 : 0.0, brake);
    _p
      ..style = PaintingStyle.fill
      ..color =
      Color.lerp(const Color(0xFF8E1B1B), const Color(0xFFFF3B30), strength)!;
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x - w / 2, y - h / 2, w, h), const Radius.circular(0.6)),
      _p,
    );
    if (strength > 0.05 && !_low) {
      _p.color = const Color(0xFFFF1744).withValues(alpha: 0.18 + 0.3 * strength);
      c.drawCircle(Offset(x - 1.2, y), 3.0 + 2.2 * brake, _p);
    }
  }

  static void _exhaust(Canvas c, double x, double y, double t, double ph,
      {double size = 1, double dark = 0.55, double boost = 1}) {
    if (_low) return;
    _p.style = PaintingStyle.fill;
    final a = dark * (0.75 + _poll * 0.5) * math.min(boost, 1.6);
    for (var k = 0; k < 3; k++) {
      final u = (t * 0.9 + k / 3 + ph) % 1.0;
      _p.color = const Color(0xFF5A5A5A)
          .withValues(alpha: (a * (1 - u) * 0.8).clamp(0.0, 1.0).toDouble());
      c.drawCircle(
        Offset(x - 1 - u * 13, y - u * 3.4 - 0.5),
        (0.7 + u * 1.8) * size * (0.9 + 0.1 * boost),
        _p,
      );
    }
  }

  /// Debu tipis yang terangkat dari roda belakang (tidak saat hujan).
  static void _dust(Canvas c, double x, double t, int id) {
    if (_low || _rain) return;
    _p.style = PaintingStyle.fill;
    final ph = (id % 100) / 100.0;
    for (var k = 0; k < 3; k++) {
      final u = (t * 0.7 + k / 3 + ph) % 1.0;
      _p.color = const Color(0xFFBCA98A)
          .withValues(alpha: (1 - u) * (0.1 + 0.1 * _poll));
      c.drawCircle(Offset(x - 2 - u * 10, -1.2 - u * 3.2), 0.9 + u * 2.0, _p);
    }
  }

  /// Cahaya kendaraan di aspal: genangan lampu depan, bias lampu rem, dan
  /// pantulan vertikal saat jalan basah. Digambar sebelum badan kendaraan.
  static void _groundLight(Canvas c, double front, double rear, double brake) {
    if (_low) return;
    _p.style = PaintingStyle.fill;
    if (_lights) {
      for (var i = 0; i < 3; i++) {
        final k = 1 - i * 0.3;
        _p.color = const Color(0xFFFFF59D).withValues(alpha: 0.075);
        c.drawOval(
          Rect.fromCenter(
              center: Offset(front + 6 + 14 * k, 1.5),
              width: 12 + 36 * k,
              height: 2.2 + 3.0 * k),
          _p,
        );
      }
    }
    final s = math.max(_lights ? 0.4 : 0.0, brake);
    if (s > 0.001) {
      for (var i = 0; i < 2; i++) {
        final k = 1 - i * 0.45;
        _p.color = const Color(0xFFFF1744).withValues(alpha: 0.12 * s);
        c.drawOval(
          Rect.fromCenter(
              center: Offset(rear - 3 - 4 * k, 1.5),
              width: 8 + 12 * k,
              height: 2 + 2.4 * k),
          _p,
        );
      }
    }
    if (_rain && _lights) {
      _p.color = const Color(0xFFFFF59D).withValues(alpha: 0.18);
      c.drawRect(Rect.fromLTWH(front - 3.2, 1.0, 1.6, 5.0), _p);
      _p.color = const Color(0xFFFF1744).withValues(alpha: 0.15 + 0.2 * s);
      c.drawRect(Rect.fromLTWH(rear + 1.0, 1.0, 1.4, 4.0), _p);
    }
  }

  static void _spray(Canvas c, double x, double t) {
    if (!_rain || _low) return;
    _p.style = PaintingStyle.fill;
    for (var k = 0; k < 5; k++) {
      final u = (t * 2.6 + k * 0.2 + x * 0.07) % 1.0;
      _p.color = const Color(0xFFE3F2FD).withValues(alpha: (1 - u) * 0.6);
      c.drawCircle(
        Offset(x - 3 - u * 7, -0.8 - math.sin(u * math.pi) * 4.2),
        0.55 + u * 0.5,
        _p,
      );
    }
  }

  /// Kepala + bahu penumpang (dipotong oleh bingkai jendela pemanggil).
  static void _passenger(
      Canvas c, double x, double y, int id, double t, double scale) {
    final sk = _skins[id % _skins.length];
    final cl = _jackets[(id ~/ 5) % _jackets.length];
    final bob = math.sin(t * 2.2 + id) * 0.25;
    _p
      ..style = PaintingStyle.fill
      ..color = cl;
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(x, y + 3.4 * scale + bob),
              width: 4.6 * scale,
              height: 3.6 * scale),
          Radius.circular(1.4 * scale)),
      _p,
    );
    _p.color = sk;
    c.drawCircle(Offset(x, y + bob), 1.75 * scale, _p);
    if (id % 3 == 0) {
      _p.color = const Color(0xFF2B2B33);
      c.drawArc(
          Rect.fromCircle(center: Offset(x, y + bob), radius: 1.85 * scale),
          math.pi,
          math.pi,
          true,
          _p);
    }
  }

  // ----------------------------------------------------------------- paint

  static void paint(
      Canvas canvas, {
        required double t,
        required double viewL,
        required double viewR,
        required double worldL,
        required double worldR,
        required bool lowDetail,
        required double pollution,
        required bool lights,
        required bool rain,
        double density = 1.0,
      }) {
    _density = density;
    // Polusi dikuantisasi agar kunci cache shader tidak berubah tiap frame.
    _poll = (pollution.clamp(0.0, 1.0) * 24).round() / 24;
    _lights = lights;
    _rain = rain;
    _low = lowDetail;
    if (_shaders.length > 400) _shaders.clear();

    final len = math.max(300.0, worldR - worldL);
    for (var li = 0; li < _lanes.length; li++) {
      _paintLane(canvas, li, _lanes[li], t, viewL, viewR, worldL, worldR, len);
    }
    _hz = 0;
  }

  static void _paintLane(Canvas canvas, int li, _Lane lane, double t,
      double viewL, double viewR, double worldL, double worldR, double len) {
    _hz = lane.haze;
    final n = math.max(1, (len / lane.spacing).round());
    final gap = len / n;
    for (var i = 0; i < n; i++) {
      final jit = ((_th(li * 977 + i * 31 + 5) % 2001) - 1000) / 1000.0;
      final off = i * gap + jit * 0.1 * gap;
      final base = t * lane.speed + off;
      final cyc = (base / len).floor();
      final u = base - cyc * len;
      final id = _th(li * 7919 + i * 131 + cyc * 17 + 11);

      // Ayunan kecepatan (gas/rem). Dibatasi agar tidak saling menembus.
      final (double amp, double w) = switch (lane.kind) {
        _Kind.motor => (6.0 + (id >> 3) % 7, 0.5 + ((id >> 7) % 40) / 100.0),
        _Kind.bicycle => (3.0 + (id >> 3) % 4, 0.4 + ((id >> 7) % 30) / 100.0),
        _Kind.car => (8.0 + (id >> 3) % 9, 0.28 + ((id >> 7) % 20) / 100.0),
      };
      final sinT = math.sin(w * t + (id % 628) / 100.0);
      final m = amp * sinT;
      final pos = u + m;
      final x = lane.right ? worldL + pos : worldR - pos;
      if (x < viewL - 120 || x > viewR + 120) continue;

      // Jalan sepi: tiap slot punya peringkat tetap; di atas kepadatan ia
      // menghilang (memudar halus di pita sempit, tanpa melompat).
      var vis = 1.0;
      if (_density < 0.995) {
        final rank = (_th(li * 131 + i * 911 + 3) % 1000) / 1000.0;
        vis = ((_density - rank) / 0.06).clamp(0.0, 1.0);
        if (vis <= 0.01) continue;
      }

      canvas.save();
      canvas.translate(x, lane.y);
      canvas.scale(lane.right ? lane.scale : -lane.scale, lane.scale);
      if (vis < 1.0) {
        canvas.saveLayer(
          const Rect.fromLTRB(-100, -70, 100, 24),
          Paint()..color = Color.fromRGBO(0, 0, 0, vis),
        );
      }
      _mirror = !lane.right;
      _drawVehicle(canvas, lane.kind, id, base + m, sinT, t);
      if (vis < 1.0) canvas.restore();
      canvas.restore();
    }
  }

  static void _drawVehicle(
      Canvas c, _Kind kind, int id, double dist, double sinT, double t) {
    switch (kind) {
      case _Kind.motor:
        _motor(c, id, dist, sinT, t);
      case _Kind.bicycle:
        _bicycle(c, id, dist, sinT, t);
      case _Kind.car:
        final r = (id ~/ 7) % 100;
        if (r < 20) {
          _car(c, _sedan, id, dist, sinT, t, taxi: (id >> 5) % 6 == 0);
        } else if (r < 40) {
          _car(c, _hatch, id, dist, sinT, t);
        } else if (r < 62) {
          _car(c, _mpv, id, dist, sinT, t);
        } else if (r < 76) {
          _angkot(c, id, dist, sinT, t);
        } else if (r < 89) {
          _pickup(c, id, dist, sinT, t);
        } else {
          _busBody(c, id, dist, sinT, t);
        }
    }
  }

  static double _bob(double dist, int id, double k) =>
      (math.sin(dist * 0.31 + id * 0.01) * 0.25 +
          math.sin(dist * 0.83 + id * 0.02) * 0.12) *
          k;

  // ================================================================ MOBIL

  static void _car(Canvas c, _Shape sh, int id, double dist, double sinT,
      double t,
      {bool taxi = false}) {
    final brake = _brake(sinT);
    final body = _tint(taxi
        ? const Color(0xFF1E88E5)
        : _palette[(id ~/ 13) % _palette.length]);
    _shadow(c, sh.half);
    _groundLight(c, sh.half, -sh.half, brake);

    c.save();
    c.translate(0, _bob(dist, id, 1));
    c.translate(0, -6);
    c.rotate(sinT * 0.028);
    c.translate(0, 6);

    final lowerR = RRect.fromLTRBR(-sh.half, sh.top, sh.half, -3.6,
        const Radius.circular(3.2));
    _fillGrad(c, Path()..addRRect(lowerR), body);
    _fillGrad(c, _poly(sh.cabin), body);

    // lekuk roda + garis pintu + gagang
    c.save();
    c.clipRRect(lowerR);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF111114);
    c.drawCircle(Offset(sh.rw, -sh.wr), sh.wr + 1.1, _p);
    c.drawCircle(Offset(sh.fw, -sh.wr), sh.wr + 1.1, _p);
    _p.color = Colors.black.withValues(alpha: 0.32);
    c.drawRect(
        Rect.fromLTRB(-sh.half + 2, -5.8, sh.half - 2, -3.5), _p);
    if (taxi) {
      _p.color = Colors.white.withValues(alpha: 0.9);
      c.drawRect(
          Rect.fromLTRB(-sh.half, sh.top + 2.6, sh.half, sh.top + 4.4), _p);
    }
    c.restore();

    if (!_low) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.4
        ..color = Colors.black.withValues(alpha: 0.28);
      for (final sx in const [-10.5, 0.0, 10.2]) {
        c.drawLine(Offset(sx, sh.top + 0.4), Offset(sx, -5.6), _p);
      }
      _p
        ..style = PaintingStyle.fill
        ..color = _shade(body, 0.5);
      for (final hx in const [-3.0, 4.2]) {
        c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(hx, sh.top + 2.2, 2.4, 0.8), const Radius.circular(0.4)),
          _p,
        );
      }
    }

    if (!_low) {
      // garis bahu bodi: kilap tipis memanjang
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.28);
      c.drawLine(Offset(-sh.half + 3.4, sh.top + 1.0),
          Offset(sh.half - 3.4, sh.top + 1.0), _p);
    }

    // kaca + siluet orang
    final clip = Path();
    for (final wnd in sh.windows) {
      final wp = _poly(wnd);
      _glass(c, wp);
      clip.addPath(wp, Offset.zero);
    }
    c.save();
    c.clipPath(clip);
    final nHeads = 1 + (id >> 9) % sh.heads.length;
    for (var k = 0; k < sh.heads.length; k++) {
      if (k >= nHeads) break;
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF2B2B33).withValues(alpha: 0.82);
      c.drawCircle(sh.heads[k], 1.7, _p);
      c.drawRect(
          Rect.fromLTWH(sh.heads[k].dx - 0.7, sh.heads[k].dy, 1.4, 2.4), _p);
    }
    c.restore();

    // atap (sorot cahaya tipis), rel atap, lampu taksi
    final roof = sh.cabin;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round
      ..color = _shade(body, 0.45).withValues(alpha: 0.8);
    c.drawLine(Offset(roof[2] + 1, roof[3]), Offset(roof[4] - 1, roof[5]), _p);
    if (sh.rails) {
      _p
        ..strokeWidth = 0.9
        ..color = const Color(0xFF455A64);
      c.drawLine(Offset(roof[2] + 2, roof[3] - 1), Offset(roof[4] - 2, roof[5] - 1), _p);
    }
    if (taxi) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFF8E1);
      c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-2.6, roof[5] - 2.6, 5.2, 2.6), const Radius.circular(0.8)),
        _p,
      );
      _p.color = const Color(0xFFFFB300);
      c.drawRect(Rect.fromLTWH(-1.6, roof[5] - 1.8, 3.2, 1.0), _p);
    }

    // bumper, grille, spion, lampu
    _p
      ..style = PaintingStyle.fill
      ..color = _shade(const Color(0xFF455A64), -0.2);
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTRB(sh.half - 2.2, sh.top + 4.8, sh.half + 0.5, -3.8),
          const Radius.circular(1)),
      _p,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTRB(-sh.half - 0.5, sh.top + 4.8, -sh.half + 2.2, -3.8),
          const Radius.circular(1)),
      _p,
    );
    c.drawRect(
        Rect.fromLTWH(sh.fw - 1.5, sh.top - 0.4, 2.2, 1.0), _p); // spion
    _headlamp(c, sh.half - 1.4, sh.lensY);
    _taillamp(c, -sh.half + 1.0, sh.lensY, brake);

    // wiper saat hujan
    if (_rain && !_low) {
      final a = math.sin(t * 6) * 0.5;
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = const Color(0xFF263238);
      final px = sh.windows.last[6];
      final py = sh.windows.last[7];
      c.drawLine(Offset(px - 1.2, py),
          Offset(px - 1.2 - math.sin(a + 0.9) * 3.4, py - math.cos(a + 0.9) * 3.4), _p);
    }
    c.restore();

    _wheel(c, sh.rw, sh.wr, dist);
    _wheel(c, sh.fw, sh.wr, dist);
    _spray(c, sh.rw - sh.wr, t);
    _dust(c, sh.rw - sh.wr, t, id);
    _exhaust(c, -sh.half - 0.4, -4.0, t, (id % 100) / 100.0,
        size: 0.8, dark: 0.4, boost: _boost(sinT));
  }

  // ================================================================ ANGKOT

  static void _angkot(
      Canvas c, int id, double dist, double sinT, double t) {
    final scheme = _angkotSchemes[(id ~/ 11) % _angkotSchemes.length];
    final body = _tint(scheme[0]);
    final stripe = _tint(scheme[1]);
    final route = _routes[(id ~/ 17) % _routes.length];
    final brake = _brake(sinT);
    _shadow(c, 23.5);
    _groundLight(c, 23.5, -23.5, brake);

    c.save();
    c.translate(0, _bob(dist, id, 1.5));
    c.translate(0, -8);
    c.rotate(sinT * 0.034);
    c.translate(0, 8);

    final shell = _poly([
      -23.5, -3.8, -23.5, -24, 13.5, -24, 16.8, -17.5, 23.5, -15, 23.5, -3.8,
    ]);
    _fillGrad(c, shell, body);

    c.save();
    c.clipPath(shell);
    _p
      ..style = PaintingStyle.fill
      ..color = stripe;
    c.drawRect(const Rect.fromLTWH(-24, -9.6, 48, 2.3), _p);
    c.drawRect(const Rect.fromLTWH(-24, -13.0, 48, 0.9), _p);
    _p.color = Colors.black.withValues(alpha: 0.3);
    c.drawRect(const Rect.fromLTWH(-24, -5.8, 48, 2.2), _p);
    _p
      ..color = const Color(0xFF111114)
      ..style = PaintingStyle.fill;
    c.drawCircle(const Offset(-14.5, -4.7), 5.8, _p);
    c.drawCircle(const Offset(14.5, -4.7), 5.8, _p);
    c.restore();

    // jendela samping + penumpang
    const panes = [
      [-21.5, -14.8],
      [-13.8, -7.1],
      [-6.1, 0.6],
      [1.6, 8.3],
    ];
    for (var k = 0; k < panes.length; k++) {
      final p0 = panes[k];
      final wp = _poly([p0[0], -22, p0[1], -22, p0[1], -15, p0[0], -15]);
      _glass(c, wp, lit: true);
      c.save();
      c.clipPath(wp);
      final cnt = (id >> (3 + k)) % 3; // 0..2 penumpang per jendela
      for (var q = 0; q < cnt; q++) {
        final px = p0[0] + 2.2 + q * 3.2;
        _passenger(c, px, -19.2, id + k * 7 + q * 3, t, 1.0);
      }
      c.restore();
    }
    // kaca depan + sopir
    final wind = _poly([9.6, -22.4, 12.9, -22.4, 15.6, -17.2, 9.6, -17.2]);
    _glass(c, wind, lit: true);
    c.save();
    c.clipPath(wind);
    _passenger(c, 11.6, -19.6, id + 91, t, 1.0);
    c.restore();

    if (!_low) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.45
        ..color = Colors.black.withValues(alpha: 0.35);
      c.drawLine(const Offset(0.9, -22.5), const Offset(0.9, -5.6), _p);
      c.drawLine(const Offset(9.0, -22.5), const Offset(9.0, -5.6), _p);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFECEFF1);
      c.drawRect(const Rect.fromLTWH(-1.2, -11.2, 1.8, 0.8), _p);
    }
    _label(c, route, -9.5, -11.5, 4.4, _onColor(stripe));

    // papan trayek di atap + rak bagasi
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFFDE7);
    c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-4.5, -27.4, 9, 3.4), const Radius.circular(0.8)),
      _p,
    );
    _label(c, route, 0, -25.7, 3.1, const Color(0xFF263238));
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = const Color(0xFF37474F);
    c.drawLine(const Offset(-21, -24.8), const Offset(10, -24.8), _p);
    if ((id >> 4) % 3 == 0) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFD7CCC8);
      c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-19, -29.4, 7, 4.8), const Radius.circular(2)),
        _p,
      );
      _p.color = const Color(0xFF8D6E63);
      c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-11, -28.6, 6, 4.0), const Radius.circular(2)),
        _p,
      );
    }

    // bumper, lampu, spion
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF37474F);
    c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTRB(21.2, -7.2, 24.2, -3.9), const Radius.circular(1)),
      _p,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTRB(-24.2, -7.2, -21.4, -3.9), const Radius.circular(1)),
      _p,
    );
    c.drawRect(const Rect.fromLTWH(14.4, -17.6, 2.2, 1.2), _p);
    _headlamp(c, 22.8, -11.6, w: 2.6, h: 2.8);
    _taillamp(c, -23.0, -11.6, brake, w: 2.0, h: 3.0);
    c.restore();

    _wheel(c, -14.5, 4.7, dist);
    _wheel(c, 14.5, 4.7, dist);
    _spray(c, -14.5 - 4.7, t);
    _dust(c, -14.5 - 4.7, t, id);
    _exhaust(c, -24, -4.4, t, (id % 100) / 100.0, size: 1.1, dark: 0.7, boost: _boost(sinT));
  }

  // ================================================================ PICKUP

  static void _pickup(
      Canvas c, int id, double dist, double sinT, double t) {
    final body = _tint(_palette[(id ~/ 13) % _palette.length]);
    final brake = _brake(sinT);
    final load = (id >> 5) % 6;
    _shadow(c, 26);
    _groundLight(c, 26, -26, brake);

    c.save();
    c.translate(0, _bob(dist, id, 1.8));
    c.translate(0, -7);
    c.rotate(sinT * 0.03);
    c.translate(0, 7);

    // chassis + bak
    final chassis = RRect.fromLTRBR(
        -26, -9.8, 26, -3.8, const Radius.circular(1.6));
    _fillGrad(c, Path()..addRRect(chassis), _shade(body, -0.08));
    final bedWall = RRect.fromLTRBR(
        -26, -14.4, 4.6, -4.4, const Radius.circular(1.2));
    _fillGrad(c, Path()..addRRect(bedWall), body);
    if (!_low) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.4
        ..color = Colors.black.withValues(alpha: 0.25);
      for (var x = -21.0; x < 4; x += 5.0) {
        c.drawLine(Offset(x, -13.6), Offset(x, -5.2), _p);
      }
    }

    // muatan (sedikit tertinggal gerak badan = efek pegas)
    final lag = math.sin(dist * 0.5 + id) * 0.5;
    c.save();
    c.translate(0, lag);
    _cargo(c, load, dist);
    c.restore();

    // kabin
    final cab = _poly([
      5.5, -9.8, 7.2, -19.2, 15.6, -19.2, 21.5, -12.4, 26, -11.4, 26, -3.8,
      5.5, -3.8,
    ]);
    _fillGrad(c, cab, body);
    final wnd = _poly([8.3, -18, 14.6, -18, 18.6, -13.2, 8.1, -13.2]);
    _glass(c, wnd);
    c.save();
    c.clipPath(wnd);
    _passenger(c, 11.0, -16.0, id + 53, t, 0.95);
    c.restore();
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF263238);
    c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTRB(3.4, -17.6, 5.8, -5.2), const Radius.circular(0.8)),
      _p,
    );
    _p.color = Colors.black.withValues(alpha: 0.3);
    c.drawRect(const Rect.fromLTRB(-25, -5.8, 25, -3.7), _p);

    // lekuk roda
    c.save();
    c.clipPath(Path()
      ..addRRect(chassis)
      ..addPath(cab, Offset.zero));
    _p.color = const Color(0xFF111114);
    c.drawCircle(const Offset(-16, -4.8), 5.9, _p);
    c.drawCircle(const Offset(15, -4.8), 5.9, _p);
    c.restore();

    // bumper, lampu, gagang
    _p.color = const Color(0xFFB0BEC5);
    c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTRB(24.4, -6.8, 27, -4.0), const Radius.circular(0.8)),
      _p,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTRB(-27.4, -6.8, -25.2, -4.0), const Radius.circular(0.8)),
      _p,
    );
    _headlamp(c, 25.0, -9.2, w: 2.2, h: 2.6);
    _taillamp(c, -25.8, -9.6, brake, w: 1.6, h: 2.6);
    _p.color = _shade(body, 0.5);
    c.drawRect(const Rect.fromLTWH(11.6, -12.0, 2.4, 0.8), _p);
    c.restore();

    _wheel(c, -16, 4.8, dist);
    _wheel(c, 15, 4.8, dist);
    _spray(c, -16 - 4.8, t);
    _dust(c, -16 - 4.8, t, id);
    _exhaust(c, -27, -3.6, t, (id % 100) / 100.0, size: 1.0, dark: 0.6, boost: _boost(sinT));
  }

  static void _cargo(Canvas c, int kind, double dist) {
    switch (kind) {
      case 0: // karung beras
        for (var k = 0; k < 6; k++) {
          final row = k < 3 ? 0 : 1;
          final col = k < 3 ? k : k - 3;
          final x = -22.0 + col * 7.6 + row * 3.8;
          final y = -14.2 - row * 5.0;
          _p
            ..style = PaintingStyle.fill
            ..color = row == 0 ? const Color(0xFFE8DDC4) : const Color(0xFFF3ECD8);
          c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x, y - 5, 7.2, 5.4), const Radius.circular(2.4)),
            _p,
          );
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.4
            ..color = const Color(0xFF8D7B5C);
          c.drawLine(Offset(x + 1.2, y - 2.6), Offset(x + 6.0, y - 2.6), _p);
        }
        break;
      case 1: // peti sayur
        for (var k = 0; k < 3; k++) {
          final x = -23.0 + k * 8.4;
          _p
            ..style = PaintingStyle.fill
            ..color = const Color(0xFF8D6E63);
          c.drawRect(Rect.fromLTWH(x, -19.4, 8.0, 5.2), _p);
          _p.color = k == 1 ? const Color(0xFFEF6C00) : const Color(0xFF66BB6A);
          c.drawOval(Rect.fromLTWH(x + 0.4, -21.8, 7.2, 3.4), _p);
          _p
            ..color = Colors.black.withValues(alpha: 0.25)
            ..strokeWidth = 0.4
            ..style = PaintingStyle.stroke;
          c.drawLine(Offset(x, -16.8), Offset(x + 8, -16.8), _p);
        }
        break;
      case 2: // tabung gas
        for (var k = 0; k < 5; k++) {
          final x = -22.6 + k * 5.0;
          final col = k.isEven ? const Color(0xFF43A047) : const Color(0xFF1E88E5);
          _p
            ..style = PaintingStyle.fill
            ..color = col;
          c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x, -22.2, 4.2, 8.2), const Radius.circular(1.8)),
            _p,
          );
          _p.color = const Color(0xFF455A64);
          c.drawRect(Rect.fromLTWH(x + 1.2, -23.6, 1.8, 1.6), _p);
        }
        break;
      case 3: // bambu / pipa menjulur ke belakang
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round;
        for (var k = 0; k < 4; k++) {
          _p.color = k.isEven ? const Color(0xFFC6B26A) : const Color(0xFFB09A52);
          c.drawLine(Offset(3.5, -15.0 - k * 1.3),
              Offset(-34, -12.0 - k * 1.7 + math.sin(dist * 0.4 + k) * 0.5), _p);
        }
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFE53935);
        c.drawRect(const Rect.fromLTWH(-37.6, -17.8, 3.4, 2.4), _p);
        break;
      case 4: // terpal biru diikat tali
        final tarp = Path()
          ..moveTo(-24, -14.2)
          ..quadraticBezierTo(-12, -28, 3, -14.2)
          ..close();
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF1976D2);
        c.drawPath(tarp, _p);
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..color = const Color(0xFFBBDEFB);
        for (var x = -18.0; x < 0; x += 8) {
          c.drawLine(Offset(x, -14.2), Offset(x + 1.5, -22.0), _p);
        }
        break;
      default: // bak kosong, ada kain terpal terlipat
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF90A4AE);
        c.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(-18, -16.6, 9, 2.6), const Radius.circular(1.2)),
          _p,
        );
        break;
    }
  }

  // ================================================================== BUS

  static void _busBody(
      Canvas c, int id, double dist, double sinT, double t) {
    final scheme = _bus[(id ~/ 11) % _bus.length];
    final body = _tint(scheme[0]);
    final stripe = _tint(scheme[1]);
    final route = _routes[(id ~/ 19) % _routes.length];
    final brake = _brake(sinT);
    _shadow(c, 38);
    _groundLight(c, 38, -38, brake);

    c.save();
    c.translate(0, _bob(dist, id, 0.7));
    c.translate(0, -10);
    c.rotate(sinT * 0.02);
    c.translate(0, 10);

    final shell = _poly([
      -38, -4.6, -38, -27, 30, -27, 35.5, -21, 38, -19, 38, -4.6,
    ]);
    _fillGrad(c, shell, body);

    c.save();
    c.clipPath(shell);
    _p
      ..style = PaintingStyle.fill
      ..color = stripe;
    c.drawRect(const Rect.fromLTWH(-39, -11.4, 78, 3.0), _p);
    c.drawRect(const Rect.fromLTWH(-39, -14.4, 78, 0.9), _p);
    _p.color = Colors.black.withValues(alpha: 0.3);
    c.drawRect(const Rect.fromLTWH(-39, -6.4, 78, 2.0), _p);
    _p.color = const Color(0xFF111114);
    c.drawCircle(const Offset(-24, -5.4), 6.4, _p);
    c.drawCircle(const Offset(20, -5.4), 6.4, _p);
    c.restore();

    // jendela samping + penumpang
    for (var k = 0; k < 6; k++) {
      final x0 = -35.0 + k * 8.8;
      final wp = _poly([x0, -25, x0 + 7.6, -25, x0 + 7.6, -17, x0, -17]);
      _glass(c, wp, lit: true);
      c.save();
      c.clipPath(wp);
      final cnt = (id >> (2 + k)) % 3;
      for (var q = 0; q < cnt; q++) {
        _passenger(c, x0 + 2.2 + q * 2.8, -21.0, id + k * 5 + q * 9, t, 1.0);
      }
      c.restore();
    }
    // pintu lipat
    for (var k = 0; k < 2; k++) {
      final x0 = 19.5 + k * 4.7;
      final wp = _poly([x0, -25, x0 + 3.9, -25, x0 + 3.9, -6.6, x0, -6.6]);
      _glass(c, wp, lit: true);
    }
    // kaca depan + sopir
    final wind = _poly([28.8, -25.4, 32, -25.4, 35.4, -21.2, 28.8, -21.2]);
    _glass(c, wind, lit: true);
    c.save();
    c.clipPath(wind);
    _passenger(c, 31.0, -23.6, id + 77, t, 1.0);
    c.restore();

    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.45
      ..color = Colors.black.withValues(alpha: 0.38);
    c.drawLine(const Offset(18.4, -25), const Offset(18.4, -5.6), _p);
    c.drawLine(const Offset(28.2, -25), const Offset(28.2, -5.6), _p);

    // papan tujuan menyala + AC atap
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF263238);
    c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(20, -30.4, 11, 3.6), const Radius.circular(0.9)),
      _p,
    );
    _p.color = const Color(0xFFFFB300);
    c.drawRect(const Rect.fromLTWH(20.8, -29.6, 9.4, 2.0), _p);
    _label(c, route, 25.5, -28.6, 3.2, const Color(0xFF3E2723));
    _p.color = _shade(body, -0.15);
    c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-22, -30.4, 26, 3.6), const Radius.circular(1.6)),
      _p,
    );
    _label(c, route, -17, -13.2, 4.6, _onColor(stripe));

    // bumper, spion, lampu
    _p.color = const Color(0xFF37474F);
    c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTRB(36.0, -7.6, 39.2, -4.8), const Radius.circular(1)),
      _p,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTRB(-39.4, -7.6, -36.8, -4.8), const Radius.circular(1)),
      _p,
    );
    c.drawRect(const Rect.fromLTWH(30.4, -22.0, 2.2, 1.2), _p);
    _headlamp(c, 37.2, -10.4, w: 2.4, h: 3.2);
    _taillamp(c, -37.6, -12.0, brake, w: 1.8, h: 3.6);
    c.restore();

    _wheel(c, -24, 5.2, dist);
    _wheel(c, 20, 5.2, dist);
    _spray(c, -24 - 5.2, t);
    _dust(c, -24 - 5.2, t, id);
    _exhaust(c, -39, -6.0, t, (id % 100) / 100.0, size: 1.5, dark: 0.85, boost: _boost(sinT));
  }

  // =============================================================== MOTOR

  static void _motor(Canvas c, int id, double dist, double sinT, double t) {
    final body = _tint(_palette[(id ~/ 13) % _palette.length]);
    final matic = (id >> 4) % 2 == 0;
    final ojol = (id >> 6) % 10 < 3;
    final withPass = !ojol && (id >> 9) % 4 == 0;
    final jacket = ojol ? const Color(0xFF2E7D32) : _jackets[(id >> 3) % _jackets.length];
    final helmet = ojol ? const Color(0xFF2E7D32) : _palette[(id >> 11) % _palette.length];
    final skin = _skins[(id >> 8) % _skins.length];
    final brake = _brake(sinT);
    final sway = math.sin(dist * 0.2 + id) * 0.25;

    _shadow(c, 11);
    _groundLight(c, 12, -12, brake);

    c.save();
    c.translate(0, _bob(dist, id, 1.2));
    c.translate(0, -5);
    c.rotate(sinT * 0.03);
    c.translate(0, 5);

    // rangka + mesin
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF37474F);
    c.drawPath(
      _poly([-4, -5.6, 3.4, -5.6, 4.2, -9.8, -3.2, -9.4]),
      _p,
    );
    // knalpot
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFB0BEC5);
    c.drawLine(const Offset(-3, -6.2), const Offset(-12.6, -5.3), _p);

    // bodi
    _p
      ..style = PaintingStyle.fill
      ..color = body;
    if (matic) {
      c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-11.2, -11.2, 8.4, 5.4), const Radius.circular(2)),
        _p,
      );
      _p.color = _shade(body, -0.25);
      c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-3.6, -7.6, 8.4, 1.6), const Radius.circular(0.8)),
        _p,
      );
      _p.color = body;
      c.drawPath(_poly([3.8, -7.6, 5.2, -14.2, 7.0, -14.2, 6.6, -7.6]), _p);
    } else {
      c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-1.6, -12.8, 6.8, 3.6), const Radius.circular(1.6)),
        _p,
      );
      _p.color = _shade(body, -0.2);
      c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-10.8, -10.8, 7.2, 2.4), const Radius.circular(1.2)),
        _p,
      );
    }
    // jok
    _p.color = const Color(0xFF263238);
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-9.8, -12.0, matic ? 9.0 : 8.0, 1.8), const Radius.circular(0.9)),
      _p,
    );

    // garpu, stang, lampu depan, spakbor
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFB0BEC5);
    c.drawLine(const Offset(8.8, -4.4), const Offset(6.2, -13.8), _p);
    _p
      ..strokeWidth = 1.0
      ..color = const Color(0xFF263238);
    c.drawLine(const Offset(5.0, -14.4), const Offset(7.6, -14.8), _p);
    _p
      ..strokeWidth = 1.1
      ..color = body;
    c.drawArc(Rect.fromCircle(center: const Offset(8.8, -4.4), radius: 5.5),
        math.pi * 1.08, math.pi * 0.5, false, _p);
    _headlamp(c, 8.4, -12.6, w: 2.2, h: 2.4);
    _taillamp(c, -11.8, -9.6, brake, w: 1.6, h: 2.0);

    // boks pengantar (ojol) di rak belakang
    if (ojol) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF2E7D32);
      c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-15.6, -19.4, 8.6, 7.4), const Radius.circular(1.2)),
        _p,
      );
      _p.color = Colors.white.withValues(alpha: 0.9);
      c.drawRect(const Rect.fromLTWH(-15.6, -16.4, 8.6, 1.2), _p);
      c.drawCircle(const Offset(-11.3, -17.8), 0.8, _p);
    }

    // pembonceng
    if (withPass) {
      _rider(c, hip: const Offset(-8.4, -11.4), lean: 0.0, sway: sway,
          jacket: _jackets[(id >> 13) % _jackets.length],
          helmet: _palette[(id >> 15) % _palette.length], skin: skin,
          hold: const Offset(-5.4, -13.2), kneeTo: const Offset(-3.6, -9.2),
          foot: const Offset(-4.4, -5.4), small: true,
          mask: _masked(id + 7));
    }
    // pengemudi
    _rider(c, hip: const Offset(-4.2, -11.4), lean: 2.6, sway: sway,
        jacket: jacket, helmet: helmet, skin: skin,
        hold: const Offset(6.6, -14.0), kneeTo: const Offset(1.8, -9.4),
        foot: const Offset(1.2, -5.2), small: false,
        flutter: math.sin(dist * 0.7 + id) * 0.8,
        mask: _masked(id));
    c.restore();

    _wheel(c, -8.6, 4.4, dist, rim: const Color(0xFFB0BEC5));
    _wheel(c, 8.8, 4.4, dist, rim: const Color(0xFFB0BEC5));
    _spray(c, -8.6 - 4.4, t);
    _dust(c, -8.6 - 4.4, t, id);
    _exhaust(c, -13, -5.0, t, (id % 100) / 100.0, size: 0.55, dark: 0.35, boost: _boost(sinT));
  }

  static void _rider(
      Canvas c, {
        required Offset hip,
        required double lean,
        required double sway,
        required Color jacket,
        required Color helmet,
        required Color skin,
        required Offset hold,
        required Offset kneeTo,
        required Offset foot,
        required bool small,
        double flutter = 0,
        bool mask = false,
      }) {
    final sh = hip + Offset(lean + sway, small ? -7.0 : -7.8);
    final head = sh + Offset(small ? 0.6 : 1.2, -3.4);
    // kaki
    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.1
      ..color = const Color(0xFF37474F);
    c.drawLine(hip, kneeTo, _p);
    _p.strokeWidth = 1.9;
    c.drawLine(kneeTo, foot, _p);
    // ujung jaket berkibar tertiup angin
    if (!small && !_low) {
      _p
        ..style = PaintingStyle.fill
        ..color = _shade(jacket, -0.15);
      c.drawPath(
        Path()
          ..moveTo(sh.dx - 1.0, sh.dy + 0.2)
          ..lineTo(sh.dx - 4.6 - flutter.abs(), hip.dy - 1.6 + flutter)
          ..lineTo(hip.dx - 1.2, hip.dy - 0.4)
          ..close(),
        _p,
      );
      _p.style = PaintingStyle.stroke;
    }
    // badan
    _p
      ..strokeWidth = 4.6
      ..color = jacket;
    c.drawLine(hip, sh, _p);
    // lengan ke stang / pinggang
    _p
      ..strokeWidth = 1.5
      ..color = jacket;
    c.drawLine(sh, hold, _p);
    // kepala + helm
    _p
      ..style = PaintingStyle.fill
      ..color = skin;
    c.drawCircle(head, 2.4, _p);
    _p.color = helmet;
    c.drawArc(Rect.fromCircle(center: head, radius: 3.0), math.pi * 0.9,
        math.pi * 1.2, true, _p);
    if (mask) _mask(c, head);
    if (!small || _lights) {
      _p.color = const Color(0xFF263238).withValues(alpha: 0.85);
      c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(head.dx + 0.3, head.dy - 1.2, 2.4, 1.5),
            const Radius.circular(0.5)),
        _p,
      );
    }
  }

  // ============================================================== SEPEDA

  static Offset _knee(Offset hip, Offset foot, double l1, double l2) {
    var dx = foot.dx - hip.dx;
    var dy = foot.dy - hip.dy;
    var dd = math.sqrt(dx * dx + dy * dy);
    final maxD = l1 + l2 - 0.05;
    if (dd > maxD) {
      final k = maxD / dd;
      dx *= k;
      dy *= k;
      dd = maxD;
    }
    if (dd < 0.001) return hip;
    final a = (l1 * l1 - l2 * l2 + dd * dd) / (2 * dd);
    final h = math.sqrt(math.max(0.0, l1 * l1 - a * a));
    final ux = dx / dd;
    final uy = dy / dd;
    final mx = hip.dx + ux * a;
    final my = hip.dy + uy * a;
    final k1 = Offset(mx - uy * h, my + ux * h);
    final k2 = Offset(mx + uy * h, my - ux * h);
    return k1.dx > k2.dx ? k1 : k2;
  }

  static void _bicycle(Canvas c, int id, double dist, double sinT, double t) {
    final frame = _tint(_palette[(id ~/ 13) % _palette.length]);
    final jacket = _jackets[(id >> 3) % _jackets.length];
    final skin = _skins[(id >> 8) % _skins.length];
    final hat = (id >> 5) % 3; // 0 caping, 1 helm, 2 tanpa
    final cargo = (id >> 7) % 3; // 0 keranjang, 1 karung, 2 kosong
    _shadow(c, 9);
    _groundLight(c, 9, -9, 0);

    c.save();
    c.translate(0, _bob(dist, id, 0.6));

    const rear = Offset(-7.4, -4.6);
    const front = Offset(7.4, -4.6);
    const bb = Offset(-0.6, -5.6);
    const seat = Offset(-2.6, -11.2);
    const head = Offset(5.4, -11.0);

    // bagasi
    if (cargo == 0) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = const Color(0xFF6D4C41);
      c.drawRect(const Rect.fromLTWH(7.6, -16.4, 4.6, 3.4), _p);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF81C784);
      c.drawCircle(const Offset(9.2, -16.8), 1.6, _p);
      c.drawCircle(const Offset(11.0, -16.4), 1.3, _p);
    } else if (cargo == 1) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFE8DDC4);
      c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-11.8, -15.6, 6.4, 5.2), const Radius.circular(2.2)),
        _p,
      );
    }

    // rangka
    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0
      ..color = frame;
    for (final seg in const [
      [rear, bb],
      [bb, seat],
      [rear, seat],
      [seat, head],
      [bb, head],
      [head, front],
    ]) {
      c.drawLine(seg[0], seg[1], _p);
    }
    _p
      ..strokeWidth = 0.9
      ..color = const Color(0xFF263238);
    c.drawLine(head, const Offset(5.0, -13.2), _p);
    c.drawLine(const Offset(5.0, -13.2), const Offset(6.8, -13.4), _p);
    c.drawLine(seat, const Offset(-3.4, -12.0), _p);
    _p
      ..strokeWidth = 1.5
      ..color = const Color(0xFF263238);
    c.drawLine(const Offset(-4.4, -12.1), const Offset(-1.8, -12.1), _p);

    // engkol + pedal
    final crank = dist * 0.115;
    final p1 = bb + Offset(math.cos(crank) * 2.2, math.sin(crank) * 2.2);
    final p2 = bb - Offset(math.cos(crank) * 2.2, math.sin(crank) * 2.2);
    _p
      ..strokeWidth = 0.8
      ..color = const Color(0xFF78909C);
    c.drawLine(p2, p1, _p);

    // pengendara
    const hipP = Offset(-2.6, -12.4);
    final lean = math.sin(dist * 0.1 + id) * 0.2;
    final sh = hipP + Offset(3.8 + lean, -6.2);
    final headC = sh + const Offset(1.0, -2.6);
    _p
      ..strokeWidth = 2.0
      ..color = const Color(0xFF455A64);
    for (final pedal in [p1, p2]) {
      final kn = _knee(hipP, pedal, 4.8, 5.0);
      c.drawLine(hipP, kn, _p);
      c.drawLine(kn, pedal, _p);
    }
    _p
      ..strokeWidth = 3.6
      ..color = jacket;
    c.drawLine(hipP, sh, _p);
    _p
      ..strokeWidth = 1.3
      ..color = jacket;
    c.drawLine(sh, const Offset(6.2, -13.3), _p);
    _p
      ..style = PaintingStyle.fill
      ..color = skin;
    c.drawCircle(headC, 2.4, _p);
    if (hat == 0) {
      _p.color = const Color(0xFFD7B56D);
      c.drawPath(
        Path()
          ..moveTo(headC.dx - 4.2, headC.dy - 1.0)
          ..lineTo(headC.dx + 0.4, headC.dy - 4.6)
          ..lineTo(headC.dx + 4.4, headC.dy - 1.0)
          ..close(),
        _p,
      );
    } else if (hat == 1) {
      _p.color = _palette[(id >> 11) % _palette.length];
      c.drawArc(Rect.fromCircle(center: headC, radius: 2.9), math.pi,
          math.pi, true, _p);
    }
    if (_masked(id)) _mask(c, headC);

    // lampu sepeda (malam / kabut asap)
    if (_lights) {
      _headlamp(c, 8.0, -12.4, w: 1.6, h: 1.6);
      _taillamp(c, -9.2, -8.4, 0.0, w: 1.2, h: 1.4);
    }

    // roda tipis dengan jari-jari
    for (final w in const [rear, front]) {
      final ang = dist / 4.6;
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = const Color(0xFF212121);
      c.drawCircle(w, 4.5, _p);
      if (!_low) {
        _p
          ..strokeWidth = 0.3
          ..color = const Color(0xFFB0BEC5);
        for (var i = 0; i < 6; i++) {
          final a = ang + i * math.pi / 3;
          c.drawLine(
            Offset(w.dx - math.cos(a) * 4.3, w.dy - math.sin(a) * 4.3),
            Offset(w.dx + math.cos(a) * 4.3, w.dy + math.sin(a) * 4.3),
            _p,
          );
        }
      }
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF90A4AE);
      c.drawCircle(w, 0.8, _p);
    }
    c.restore();
  }
}