part of 'kost_scene.dart';

// ====================================================================
//  LATAR BELAKANG BERTEMA (biome). MURNI visual.
//
//  Satu ruangan = satu tema, dipilih acak tapi stabil dari id ruangan
//  ([KostBiome.forRoom]), jadi semua pemain melihat pemandangan yang sama
//  tanpa kolom baru di database. Tema kota = tampilan lama (tidak berubah).
//
//  Cara kerja: painter lama tetap memanggil _drawSky/_drawHills/_drawTrees/
//  _drawGround; tiap fungsi itu membaca d.biome. Warna polusi tetap
//  dicampur seperti biasa, jadi semua tema ikut kusam saat polusi naik.
// ====================================================================

enum KostBiome {
  kota,
  gunung,
  pantai,
  lembah,
  sawah;

  String get label => switch (this) {
    KostBiome.kota => 'Perkotaan',
    KostBiome.gunung => 'Pegunungan',
    KostBiome.pantai => 'Pantai',
    KostBiome.lembah => 'Lembah',
    KostBiome.sawah => 'Persawahan',
  };

  /// Tema acak tapi stabil untuk satu ruangan (sama di semua perangkat).
  static KostBiome forRoom(String roomId) {
    final h = roomId.codeUnits.fold<int>(11, (a, b) => (a * 37 + b) % 100003);
    return KostBiome.values[h % KostBiome.values.length];
  }

  Color get skyTop => switch (this) {
    KostBiome.kota => const Color(0xFF4CA8E0),
    KostBiome.gunung => const Color(0xFF3A86D6),
    KostBiome.pantai => const Color(0xFF2FB5F2),
    KostBiome.lembah => const Color(0xFF6AAFD6),
    KostBiome.sawah => const Color(0xFF52B2EA),
  };

  Color get skyBottom => switch (this) {
    KostBiome.kota => const Color(0xFFE3F5FB),
    KostBiome.gunung => const Color(0xFFD6ECFA),
    KostBiome.pantai => const Color(0xFFE6F8FF),
    KostBiome.lembah => const Color(0xFFEEF2DA),
    KostBiome.sawah => const Color(0xFFFFF1D0),
  };

  /// Warna jalur depan kost (rumput / pasir / tanah).
  Color get grass => switch (this) {
    KostBiome.kota => const Color(0xFF8DBB7A),
    KostBiome.gunung => const Color(0xFF7FAF6E),
    KostBiome.pantai => const Color(0xFFE8D5A0),
    KostBiome.lembah => const Color(0xFF6FA86A),
    KostBiome.sawah => const Color(0xFF9CCB5A),
  };

  /// Warna halaman depan (di bawah jalur rumput).
  Color get yard => switch (this) {
    KostBiome.kota => const Color(0xFFD0C9B8),
    KostBiome.gunung => const Color(0xFFC9C5BC),
    KostBiome.pantai => const Color(0xFFF0E2B8),
    KostBiome.lembah => const Color(0xFFCDC6AE),
    KostBiome.sawah => const Color(0xFFD9C9A0),
  };

  /// Bintik kecil di jalur depan (bunga / kerikil / kulit kerang).
  List<Color> get specks => switch (this) {
    KostBiome.gunung => const [
      Color(0xFFB0BEC5),
      Color(0xFF90A4AE),
      Color(0xFFECEFF1),
    ],
    KostBiome.pantai => const [
      Color(0xFFFFCC80),
      Color(0xFFFFFFFF),
      Color(0xFFF8BBD0),
    ],
    KostBiome.sawah => const [
      Color(0xFFFFF176),
      Color(0xFFFFFFFF),
      Color(0xFFFFD54F),
    ],
    _ => const [
      Color(0xFFFF8A80),
      Color(0xFFFFF176),
      Color(0xFFCE93D8),
      Color(0xFFFFFFFF),
    ],
  };
}

const Color _biomeSmog = Color(0xFF8E8A70);

extension KostPainterBiome on KostPainter {
  Color _bc(Color c, double p) => _mix(c, _biomeSmog, p);

  /// Tinggi puncak bergerigi di [x]: sel selebar [period], tinggi tiap sel
  /// acak dari [off]. Selalu > 0 sehingga tidak ada celah di antara puncak.
  double _peakH(double x, double period, double amp, int off) {
    final k = (x / period).floor();
    final fr = x / period - k;
    final ph = amp * (0.55 + 0.45 * (_hh(k + off) % 100) / 100);
    final tri = 1 - (2 * fr - 1).abs();
    return ph * (0.12 + 0.88 * tri);
  }

  Path _ridgePath(double base, double period, double amp, int off,
      {double ripple = 0}) {
    final x0 = (_vl / 6).floor() * 6.0;
    final path = Path()..moveTo(x0, _gy);
    for (var x = x0; x <= _vr + 6; x += 6) {
      final r = ripple == 0 ? 0.0 : ripple * math.sin(x * 0.19 + off);
      path.lineTo(x, base - _peakH(x, period, amp, off) - r);
    }
    path.lineTo(_vr + 6, _gy);
    path.close();
    return path;
  }

  /// Lapisan jauh (pengganti bukit + gedung) sesuai tema.
  void _drawBiomeFar(Canvas canvas, double t, double p) {
    switch (d.biome) {
      case KostBiome.gunung:
        _farMountains(canvas, t, p);
      case KostBiome.pantai:
        _farSea(canvas, t, p);
      case KostBiome.lembah:
        _farValley(canvas, t, p);
      case KostBiome.sawah:
        _farPaddy(canvas, t, p);
      case KostBiome.kota:
        break;
    }
  }

  // ---------------------------------------------------------- gunung
  void _farMountains(Canvas canvas, double t, double p) {
    const period = 280.0;
    const amp = 120.0;
    final base = _gy - 18;
    _p
      ..style = PaintingStyle.fill
      ..color = _bc(const Color(0xFF8FA9C4), p).withValues(alpha: 0.95);
    canvas.drawPath(_ridgePath(base, period, amp, 41, ripple: 1.5), _p);

    // salju di puncak tinggi
    _p.color = _bc(const Color(0xFFF4F8FC), p * 0.6);
    final k0 = (_vl / period).floor() - 1;
    final k1 = (_vr / period).ceil() + 1;
    for (var k = k0; k < k1; k++) {
      final ph = amp * (0.55 + 0.45 * (_hh(k + 41) % 100) / 100);
      if (ph < amp * 0.72) continue;
      final cx = (k + 0.5) * period;
      final apexY = base - ph;
      final sd = ph * 0.28;
      final w = period * 0.159;
      final snow = Path()
        ..moveTo(cx, apexY)
        ..lineTo(cx + w, apexY + sd)
        ..lineTo(cx + w * 0.4, apexY + sd * 0.7)
        ..lineTo(cx, apexY + sd * 1.05)
        ..lineTo(cx - w * 0.4, apexY + sd * 0.7)
        ..lineTo(cx - w, apexY + sd)
        ..close();
      canvas.drawPath(snow, _p);
    }

    // punggung gunung tengah + dekat (hijau tua, bercemara)
    _p.color = _bc(const Color(0xFF5E8F6A), p).withValues(alpha: 0.96);
    canvas.drawPath(
        _ridgePath(_gy - 6, 150, 46, 63, ripple: 2.0), _p);
    _p.color = _bc(const Color(0xFF3F7550), p);
    canvas.drawPath(
        _ridgePath(_gy - 2, 96, 24, 85, ripple: 1.2), _p);
  }

  // ----------------------------------------------------------- pantai
  void _farSea(Canvas canvas, double t, double p) {
    final hy = _gy - 34;
    final rect = Rect.fromLTRB(_vl, hy, _vr, _gy);
    _p
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _bc(const Color(0xFF81D4FA), p),
          _bc(const Color(0xFF0288D1), p),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, _p);
    _p.shader = null;

    // pulau jauh
    _p.color = _bc(const Color(0xFF6B9A8A), p).withValues(alpha: 0.85);
    final k0 = (_vl / 900).floor() - 1;
    final k1 = (_vr / 900).ceil() + 1;
    for (var k = k0; k < k1; k++) {
      final h = _hh(k + 19);
      final cx = k * 900.0 + 200 + h % 400;
      final w = 70.0 + h % 60;
      final ht = 14.0 + h % 12;
      final isl = Path()
        ..moveTo(cx - w, hy + 1)
        ..quadraticBezierTo(cx - w * 0.3, hy - ht * 1.6, cx, hy - ht)
        ..quadraticBezierTo(cx + w * 0.4, hy - ht * 1.3, cx + w, hy + 1)
        ..close();
      canvas.drawPath(isl, _p);
    }

    // perahu layar
    final b0 = (_vl / 520).floor() - 1;
    final b1 = (_vr / 520).ceil() + 1;
    for (var k = b0; k < b1; k++) {
      final h = _hh(k + 23);
      if (h % 3 == 0) continue;
      final bx = k * 520.0 + 120 + h % 260;
      final by = hy + 12 + h % 8 + math.sin(t * 0.9 + k) * 1.2;
      _p.color = const Color(0xFF6D4C41);
      canvas.drawRect(Rect.fromLTWH(bx - 9, by, 18, 3), _p);
      _p.color = Colors.white.withValues(alpha: 0.95);
      canvas.drawPath(
          Path()
            ..moveTo(bx, by - 15)
            ..lineTo(bx + 8, by - 1)
            ..lineTo(bx, by - 1)
            ..close(),
          _p);
      _p.color = const Color(0xFFFFCDD2);
      canvas.drawPath(
          Path()
            ..moveTo(bx - 1, by - 11)
            ..lineTo(bx - 7, by - 1)
            ..lineTo(bx - 1, by - 1)
            ..close(),
          _p);
    }

    // kilau ombak
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var x = (_vl / 22).floor() * 22.0; x < _vr; x += 22) {
      final h = _hh(x ~/ 22 + 400);
      final y = hy + 5 + (h % 22);
      final a = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(t * 1.4 + x * 0.05 + h));
      _p.color = Colors.white.withValues(alpha: a);
      canvas.drawLine(Offset(x, y), Offset(x + 6 + h % 5, y), _p);
    }

    // buih di tepi pantai
    final foam = Path()..moveTo(_vl, _gy - 2);
    for (var x = _vl; x <= _vr + 8; x += 8) {
      foam.lineTo(x, _gy - 3 + math.sin(t * 1.5 + x * 0.08) * 1.6);
    }
    _p
      ..strokeWidth = 2.2
      ..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawPath(foam, _p);
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }

  // ----------------------------------------------------------- lembah
  void _farValley(Canvas canvas, double t, double p) {
    const period = 230.0;
    const amp = 84.0;
    final base = _gy - 14;
    _p
      ..style = PaintingStyle.fill
      ..color = _bc(const Color(0xFF7FA88E), p).withValues(alpha: 0.95);
    canvas.drawPath(_ridgePath(base, period, amp, 51, ripple: 2.5), _p);

    // air terjun di tebing (acak per sel)
    final k0 = (_vl / 760).floor() - 1;
    final k1 = (_vr / 760).ceil() + 1;
    for (var k = k0; k < k1; k++) {
      final h = _hh(k + 31);
      if (h % 3 != 0) continue;
      final x = k * 760.0 + 150 + h % 300;
      final topY = base - _peakH(x, period, amp, 51) + 4;
      final endY = _gy - 14;
      if (endY - topY < 14) continue;
      _p.color = Colors.white.withValues(alpha: 0.85);
      canvas.drawRect(Rect.fromLTRB(x - 2.2, topY, x + 2.2, endY), _p);
      _p.color = const Color(0xFF81D4FA).withValues(alpha: 0.55);
      for (var i = 0; i < 5; i++) {
        final yy = topY + ((t * 38 + i * 19) % (endY - topY));
        canvas.drawRect(Rect.fromLTWH(x - 1.2, yy, 2.4, 5), _p);
      }
      _p.color = Colors.white.withValues(alpha: 0.5);
      canvas.drawCircle(Offset(x, endY), 7, _p);
    }

    _p.color = _bc(const Color(0xFF5E9E6E), p);
    canvas.drawPath(_ridgePath(_gy - 4, 130, 34, 77, ripple: 2.0), _p);

    // kabut pagi melayang
    final mist = Rect.fromLTRB(_vl, _gy - 52, _vr, _gy - 6);
    _p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: 0),
        Colors.white.withValues(alpha: 0.32),
        Colors.white.withValues(alpha: 0),
      ],
    ).createShader(mist);
    canvas.drawRect(mist, _p);
    _p.shader = null;
    _p.color = Colors.white.withValues(alpha: 0.22);
    final span = (_street ? _streetW + 600 : _vr - _vl + 300);
    final start = _street ? -300.0 : _vl - 150;
    for (var i = 0; i < 6; i++) {
      final x = ((t * (2.2 + i * 0.5) + i * 260) % span) + start;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, _gy - 30 - (i % 3) * 8),
              width: 150,
              height: 14),
          _p);
    }
  }

  // ---------------------------------------------------------- sawah
  void _farPaddy(Canvas canvas, double t, double p) {
    // gunung berapi jauh
    final k0 = (_vl / 880).floor() - 1;
    final k1 = (_vr / 880).ceil() + 1;
    for (var k = k0; k < k1; k++) {
      final h = _hh(k + 7);
      if (h % 2 != 0) continue;
      final cx = k * 880.0 + 180 + h % 360;
      final top = _gy - 118.0 - (h % 20);
      final cone = Path()
        ..moveTo(cx - 170, _gy - 10)
        ..quadraticBezierTo(cx - 60, _gy - 28, cx - 18, top)
        ..lineTo(cx + 18, top)
        ..quadraticBezierTo(cx + 60, _gy - 28, cx + 170, _gy - 10)
        ..close();
      _p
        ..style = PaintingStyle.fill
        ..color = _bc(const Color(0xFF7C95A8), p);
      canvas.drawPath(cone, _p);
      _p.color = _bc(const Color(0xFF5E7488), p);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, top), width: 38, height: 8), _p);
      // asap tipis naik
      for (var i = 0; i < 4; i++) {
        final u = ((t * 0.18 + i * 0.25) % 1.0);
        _p.color = Colors.white.withValues(alpha: 0.5 * (1 - u));
        canvas.drawCircle(
            Offset(cx + math.sin(u * 5 + i) * 8 + u * 14, top - 6 - u * 46),
            6 + u * 11,
            _p);
      }
    }

    // bukit hijau muda
    _p
      ..style = PaintingStyle.fill
      ..color = _bc(const Color(0xFF9CCB8E), p).withValues(alpha: 0.95);
    canvas.drawPath(_ridgePath(_gy - 12, 210, 20, 93, ripple: 3), _p);

    // petak sawah berundak
    const rows = [
      Color(0xFFB7DA6B),
      Color(0xFF8BC34A),
      Color(0xFFC9E37E),
    ];
    for (var r = 0; r < 3; r++) {
      final y0 = _gy - 26.0 + r * 9;
      final path = Path()..moveTo(_vl, _gy);
      for (var x = _vl; x <= _vr + 10; x += 10) {
        path.lineTo(x, y0 + math.sin(x * 0.03 + r * 1.7) * 2.2);
      }
      path.lineTo(_vr + 10, _gy);
      path.close();
      _p.color = _bc(rows[r], p);
      canvas.drawPath(path, _p);
    }
    // kilau air di petak terbawah
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.35);
    for (var x = (_vl / 31).floor() * 31.0; x < _vr; x += 31) {
      final h = _hh(x ~/ 31 + 600);
      if (h % 2 == 0) continue;
      final a = 0.2 + 0.3 * (0.5 + 0.5 * math.sin(t * 1.8 + h));
      _p.color = Colors.white.withValues(alpha: a);
      canvas.drawLine(Offset(x, _gy - 6), Offset(x + 7, _gy - 6), _p);
    }
    _p.style = PaintingStyle.fill;
  }

  // ------------------------------------------------------------ pohon
  /// Pohon di sisi kiri/kanan deretan kost (di luar lebar jalan).
  void _drawBiomeTrees(Canvas canvas, double t, double p) {
    final start = (_vl / 90).floor() - 1;
    final end = (_vr / 90).ceil() + 1;
    for (var k = start; k < end; k++) {
      final h = _hh(k + 77);
      final x = k * 90.0 + 20 + (h % 30);
      if (x > -14 && x < _streetW + 14) continue;
      final sway = math.sin(t * 1.2 + k) * 1.6 * (1 - p);
      switch (d.biome) {
        case KostBiome.gunung:
          _pine(canvas, x, h, p, snow: true);
        case KostBiome.pantai:
        case KostBiome.sawah:
          _palm(canvas, x, h, p, sway, t);
        case KostBiome.lembah:
          if (h % 2 == 0) {
            _cypress(canvas, x, h, p, sway);
          } else {
            _pine(canvas, x, h, p, snow: false);
          }
        case KostBiome.kota:
          break;
      }
    }
  }

  void _pine(Canvas canvas, double x, int h, double p, {required bool snow}) {
    final s = 0.85 + (h % 5) / 12;
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF5D4037);
    canvas.drawRect(Rect.fromLTWH(x - 2, _gy - 8, 4, 12), _p);
    final c1 = _bc(const Color(0xFF2E7D32), p * 1.2);
    final c2 = _bc(const Color(0xFF1B5E20), p * 1.2);
    for (var i = 0; i < 3; i++) {
      final w = (28 - i * 7) * s;
      final yb = _gy - 6 - i * 15 * s;
      _p.color = i.isEven ? c1 : c2;
      canvas.drawPath(
          Path()
            ..moveTo(x, yb - 20 * s)
            ..lineTo(x + w / 2, yb)
            ..lineTo(x - w / 2, yb)
            ..close(),
          _p);
    }
    if (snow) {
      _p.color = Colors.white.withValues(alpha: 0.85);
      final top = _gy - 6 - 30 * s - 20 * s;
      canvas.drawPath(
          Path()
            ..moveTo(x, top)
            ..lineTo(x + 5 * s, top + 8 * s)
            ..lineTo(x - 5 * s, top + 8 * s)
            ..close(),
          _p);
    }
  }

  void _cypress(Canvas canvas, double x, int h, double p, double sway) {
    final s = 0.9 + (h % 4) / 10;
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF5D4037);
    canvas.drawRect(Rect.fromLTWH(x - 1.5, _gy - 6, 3, 10), _p);
    _p.color = _bc(const Color(0xFF2F6B3A), p * 1.2);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(x + sway * 0.4, _gy - 28 * s),
            width: 15 * s,
            height: 50 * s),
        _p);
    _p.color = _bc(const Color(0xFF3F8A4C), p * 1.2).withValues(alpha: 0.7);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(x + 2 + sway * 0.4, _gy - 31 * s),
            width: 7 * s,
            height: 34 * s),
        _p);
  }

  void _palm(Canvas canvas, double x, int h, double p, double sway, double t) {
    final lean = ((h % 3) - 1) * 8.0;
    final topX = x + lean + sway * 0.6;
    final topY = _gy - 56.0 - (h % 9);
    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..color = const Color(0xFF8D6E63);
    canvas.drawPath(
        Path()
          ..moveTo(x, _gy + 3)
          ..quadraticBezierTo(x + lean * 0.2, _gy - 28, topX, topY),
        _p);
    _p
      ..strokeWidth = 3.2
      ..color = _bc(const Color(0xFF2E9A4A), p * 1.2);
    for (var i = 0; i < 7; i++) {
      final a = -math.pi + i * math.pi / 6;
      final flap = math.sin(t * 1.6 + i + x) * 1.5 * (1 - p);
      final ctrl = Offset(
          topX + math.cos(a) * 14, topY + math.sin(a) * 14 - 8 + flap);
      final tip = Offset(topX + math.cos(a) * 28,
          topY + math.sin(a) * 10 + 13 + flap * 1.5);
      canvas.drawPath(
          Path()
            ..moveTo(topX, topY)
            ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy),
          _p);
    }
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xFF6D4C41);
    canvas.drawCircle(Offset(topX - 3, topY + 4), 2.6, _p);
    canvas.drawCircle(Offset(topX + 3, topY + 5), 2.6, _p);
  }
}