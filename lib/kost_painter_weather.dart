part of 'kost_scene.dart';

// ====================================================================
//  CUACA & INSIDEN BARU
//  heavy_rain, strong_wind, drought, blackout, earthquake, night_market
//  (rat_plague: lihat _drawRats di kost_painter_life.dart;
//   guncangan gempa: lihat _shakeOffset di kost_painter.dart)
//
//  Dipanggil dari _drawWorldEventFront (lapisan depan).
// ====================================================================

extension KostPainterWeather on KostPainter {
  /// Hujan apa pun (banjir atau deras): langit kelabu, jalan basah, payung.
  bool get _isRainy =>
      d.worldEvent == 'rain_flood' || d.worldEvent == 'heavy_rain';

  void _drawWeatherFront(Canvas canvas, double t) {
    switch (d.worldEvent) {
      case 'heavy_rain':
        _wxHeavyRain(canvas, t);
      case 'strong_wind':
        _wxWind(canvas, t);
      case 'drought':
        _wxDrought(canvas, t);
      case 'blackout':
        _wxBlackout(canvas, t);
      case 'earthquake':
        _wxQuake(canvas, t);
      case 'night_market':
        _wxNightMarket(canvas, t);
    }
  }

  // ------------------------------------------------------ hujan deras

  void _wxHeavyRain(Canvas canvas, double t) {
    final spanX = _vr - _vl;
    final spanY = _vb - _vt;
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF455A64).withValues(alpha: 0.14);
    canvas.drawRect(Rect.fromLTRB(_vl, _vt, _vr, _vb), _p);

    // riak genangan di tanah
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    final ripples = d.compact ? 4 : 9;
    for (var k = 0; k < ripples; k++) {
      final ph = (t * 1.3 + k * 0.37) % 1.0;
      final rx = _vl + (_hh(k + 410) % 1000) / 1000 * spanX;
      final ry = _gy + 6 + (k % 3) * 5.0;
      _p.color = const Color(0xFFE3F2FD).withValues(alpha: (1 - ph) * 0.5);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(rx, ry), width: 4 + ph * 14, height: 1.5 + ph * 4),
          _p);
    }

    // butir hujan: lebih rapat, lebih cepat, lebih miring dari banjir
    _p
      ..strokeWidth = 1.2 * _fxScale
      ..color = const Color(0xFFE3F2FD).withValues(alpha: 0.6);
    final n = d.compact ? 28 : 90;
    for (var i = 0; i < n; i++) {
      final h = _hh(i + 300);
      final dx = _vl + ((h % 1000) / 1000 * spanX - t * 90) % spanX;
      final dy = _vt + ((t * 340 + h % 500) % spanY);
      canvas.drawLine(Offset(dx, dy),
          Offset(dx - 6 * _fxScale, dy + 15 * _fxScale), _p);
    }
    _p.style = PaintingStyle.fill;
  }

  // ------------------------------------------------------ angin kencang

  void _wxWind(Canvas canvas, double t) {
    final spanX = _vr - _vl;
    final spanY = _gy - _vt;
    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0 * _fxScale
      ..color = Colors.white.withValues(alpha: 0.35);
    final streaks = d.compact ? 10 : 26;
    for (var i = 0; i < streaks; i++) {
      final h = _hh(i + 700);
      final y = _vt + (h % 1000) / 1000 * spanY + math.sin(t * 3 + i) * 2;
      final speed = 380.0 + (h % 7) * 40;
      final x = _vl + ((t * speed + h % 900) % (spanX + 80)) - 40;
      final len = (26.0 + (h % 5) * 10) * _fxScale;
      canvas.drawLine(Offset(x - len, y), Offset(x, y), _p);
    }
    _p.strokeCap = StrokeCap.butt;

    // sampah/daun beterbangan
    const cols = [
      Color(0xFFF5F5F5), // kertas
      Color(0xFF8BC34A), // daun
      Color(0xFF8D6E63), // kardus
      Color(0xFFB0BEC5), // plastik
    ];
    _p.style = PaintingStyle.fill;
    final debris = d.compact ? 4 : 12;
    for (var i = 0; i < debris; i++) {
      final h = _hh(i + 740);
      final speed = 210.0 + (h % 90);
      final x = _vl + ((t * speed + h % 700) % (spanX + 60)) - 30;
      final y = _vt + 60 + (h % 1000) / 1000 * (spanY - 70) +
          math.sin(t * 4 + i) * 14;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 5 + i);
      _p.color = cols[i % cols.length].withValues(alpha: 0.9);
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: 6 * _fxScale, height: 4 * _fxScale),
          _p);
      canvas.restore();
    }
  }

  // ------------------------------------------------------ kemarau

  void _wxDrought(Canvas canvas, double t) {
    final view = Rect.fromLTRB(_vl, _vt, _vr, _vb);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFF8F00)
          .withValues(alpha: 0.09 + 0.02 * math.sin(t * 1.5));
    canvas.drawRect(view, _p);

    // silau matahari terik
    final c = Offset(_vl + (_vr - _vl) * 0.78, _vt + 34);
    _p.shader = RadialGradient(colors: [
      const Color(0xFFFFF59D).withValues(alpha: 0.38),
      const Color(0xFFFFF59D).withValues(alpha: 0),
    ]).createShader(Rect.fromCircle(center: c, radius: 150));
    canvas.drawCircle(c, 150, _p);
    _p.shader = null;

    // fatamorgana: garis bergelombang di atas tanah
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.11);
    final lines = d.compact ? 3 : 7;
    for (var k = 0; k < lines; k++) {
      final y = _gy - 4 - k * 5.0;
      final path = Path()..moveTo(_vl, y);
      for (var x = _vl; x <= _vr; x += 24) {
        path.lineTo(x, y + math.sin(t * 2.2 + x * 0.05 + k) * 1.6);
      }
      canvas.drawPath(path, _p);
    }
    _p.style = PaintingStyle.fill;
  }

  // ------------------------------------------------------ mati listrik

  void _wxBlackout(Canvas canvas, double t) {
    // Insinerator ramah lingkungan (Lv 10+) kebal: rumah ini tetap terang.
    if (d.wasteLevel >= 10) return;
    final flicker = (math.sin(t * 17) * math.sin(t * 5.3)) > 0.82 ? 0.35 : 1.0;
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF050816).withValues(alpha: 0.40 * flicker);
    canvas.drawRect(Rect.fromLTRB(_vl, _vt, _vr, _vb), _p);
  }

  // ------------------------------------------------------ gempa bumi
  // Guncangan kamera ada di _shakeOffset; di sini retakan, debu, puing.

  void _wxQuake(Canvas canvas, double t) {
    final spanX = _vr - _vl;
    final spanY = _gy - _vt;

    // retakan tanah (tetap selama gempa)
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF3E2723).withValues(alpha: 0.8);
    final cracks = d.compact ? 2 : 5;
    for (var k = 0; k < cracks; k++) {
      final x0 = _vl + (_hh(k + 520) % 1000) / 1000 * spanX;
      final path = Path()..moveTo(x0, _gy + 8);
      var x = x0, y = _gy + 8.0;
      for (var s = 0; s < 5; s++) {
        final h = _hh(k * 10 + s + 530);
        x += ((h % 15) - 5).toDouble();
        y += 4 + (h % 4);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, _p);
    }

    // debu naik dari tanah
    _p.style = PaintingStyle.fill;
    final dust = d.compact ? 10 : 28;
    for (var i = 0; i < dust; i++) {
      final h = _hh(i + 560);
      final life = (t * 0.7 + (h % 100) / 100) % 1.0;
      final x = _vl + (h % 1000) / 1000 * spanX;
      final y = _gy + 4 - life * 40;
      _p.color = const Color(0xFFBCAAA4).withValues(alpha: (1 - life) * 0.45);
      canvas.drawCircle(Offset(x, y), 2 + life * 7, _p);
    }

    // puing kecil berjatuhan
    final debris = d.compact ? 3 : 8;
    _p.color = const Color(0xFF6D4C41).withValues(alpha: 0.85);
    for (var i = 0; i < debris; i++) {
      final h = _hh(i + 590);
      final x = _vl + (h % 1000) / 1000 * spanX;
      final y = _vt + ((t * 210 + h % 400) % spanY);
      canvas.drawRect(Rect.fromLTWH(x, y, 3.5 * _fxScale, 3.5 * _fxScale), _p);
    }
  }

  // ------------------------------------------------------ pasar malam

  void _wxNightMarket(Canvas canvas, double t) {
    // Untaian lampu warna-warni melengkung di atas, berkedip bergantian.
    const cols = [
      Color(0xFFFF5252),
      Color(0xFFFFCA28),
      Color(0xFF29B6F6),
      Color(0xFF66BB6A),
    ];
    const seg = 120.0;
    final baseY = _vt + 34;
    final n = ((_vr - _vl) / seg).ceil() + 1;
    var idx = 0;
    for (var i = 0; i < n; i++) {
      final p0 = Offset(_vl + i * seg, baseY);
      final p2 = Offset(_vl + (i + 1) * seg, baseY);
      final cp = Offset((p0.dx + p2.dx) / 2, baseY + 26);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFF5D4037).withValues(alpha: 0.8);
      canvas.drawPath(
          Path()
            ..moveTo(p0.dx, p0.dy)
            ..quadraticBezierTo(cp.dx, cp.dy, p2.dx, p2.dy),
          _p);
      for (var b = 1; b <= 5; b++) {
        final u = b / 6.0;
        final x = (1 - u) * (1 - u) * p0.dx + 2 * u * (1 - u) * cp.dx + u * u * p2.dx;
        final y = (1 - u) * (1 - u) * p0.dy + 2 * u * (1 - u) * cp.dy + u * u * p2.dy;
        final glow = 0.6 + 0.4 * math.sin(t * 4 + idx);
        final col = cols[idx % cols.length];
        _p.style = PaintingStyle.fill;
        _p.color = col.withValues(alpha: 0.22 * glow);
        canvas.drawCircle(Offset(x, y + 3), 6, _p);
        _p.color = col.withValues(alpha: 0.95 * glow);
        canvas.drawCircle(Offset(x, y + 3), 2.4, _p);
        idx++;
      }
    }
    _p.style = PaintingStyle.fill;
  }
}