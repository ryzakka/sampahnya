part of 'kost_scene.dart';

// ====================================================================
//  Lapisan "polish": hiasan hidup tambahan untuk adegan kost.
//
//  Semua MURNI visual (tanpa efek gameplay), deterministik dari waktu adegan
//  [t] sehingga tidak butuh state, dan patuh pada Mode Ringan:
//    * kunang-kunang  : malam, udara bersih, tidak hujan  (hilang di Ringan)
//    * kupu-kupu      : siang, udara bersih, cuaca tenang (hilang di Ringan)
//    * bintang jatuh  : malam cerah                       (hilang di Sangat Ringan)
//    * debu cahaya    : siang / senja berkabut cahaya     (berkurang di Ringan)
//    * kilau bersih   : kost nyaris tanpa sampah          (hilang di Sangat Ringan)
// ====================================================================

/// Bilangan acak stabil 0..1 dari bilangan bulat [n].
double _h01(int n) => (_hh(n) % 1000) / 1000.0;

/// Bagian pecahan 0..1 (untuk gerak berulang/wrap-around).
double _fract(double v) => v - v.floorToDouble();

extension KostPainterPolish on KostPainter {
  /// Cuaca cukup tenang untuk makhluk kecil beterbangan.
  bool get _calmWeather =>
      !_isRainy &&
      d.worldEvent != 'strong_wind' &&
      d.worldEvent != 'earthquake' &&
      d.worldEvent != 'blackout';

  void _polishStar(Canvas canvas, Offset o, double r, Color c, double a) {
    if (a <= 0.01 || r <= 0.05) return;
    final path = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
      ..close();
    _p
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = c.withValues(alpha: _c01(a));
    canvas.drawPath(path, _p);
  }

  // ------------------------------------------------------ kunang-kunang

  /// Titik cahaya hijau-kuning yang melayang pelan & berkedip di malam hari.
  void _drawFireflies(Canvas canvas, double t, double p) {
    if (d.compact || _lite || d.eliminated || d.dayPhase == null) return;
    if (!_calmWeather) return;
    final k = _night * (1 - _c01(p * 1.6)) * (1 - 0.5 * _c01(d.trashRatio * 1.2));
    if (k < 0.05) return;

    final span = _vr - _vl;
    final n = (span / 400 * 12).clamp(12, 40).round();
    _p
      ..style = PaintingStyle.fill
      ..shader = null;
    for (var i = 0; i < n; i++) {
      final ph = _h01(i * 7 + 3) * 6.2832;
      final x0 = _vl + _h01(i * 7 + 1) * span;
      final y0 = 168 + _h01(i * 7 + 2) * 104;
      final x = x0 + math.sin(t * 0.33 + ph) * 22 + math.sin(t * 0.9 + ph * 2) * 6;
      final y = y0 + math.cos(t * 0.27 + ph) * 14 + math.sin(t * 1.1 + ph) * 4;
      final s = math.sin(t * (1.1 + _h01(i * 7 + 4) * 1.4) + ph);
      final blink = s <= 0 ? 0.0 : s * s * s;
      final a = k * blink;
      if (a < 0.03) continue;
      final o = Offset(x, y);
      _p.color = const Color(0xFFC6FF00).withValues(alpha: _c01(0.16 * a));
      canvas.drawCircle(o, 7.5, _p);
      _p.color = const Color(0xFFE6FF7A).withValues(alpha: _c01(0.35 * a));
      canvas.drawCircle(o, 3.2, _p);
      _p.color = const Color(0xFFFFFFE0).withValues(alpha: _c01(0.95 * a));
      canvas.drawCircle(o, 1.1, _p);
    }
  }

  // ------------------------------------------------------- kupu-kupu

  static const List<Color> _butterflyCols = [
    Color(0xFFFFA726),
    Color(0xFFF5F5F5),
    Color(0xFF81D4FA),
    Color(0xFFF48FB1),
  ];

  /// Beberapa kupu-kupu melayang zig-zag di halaman saat siang cerah.
  void _drawButterflies(Canvas canvas, double t, double p) {
    if (d.compact || _lite || d.eliminated) return;
    if (!_calmWeather || p > 0.4) return;
    if (d.dayPhase != null && (_night > 0.15 || _dusk > 0.6)) return;
    final k = (1 - p / 0.4) * (1 - 0.6 * _c01(d.trashRatio * 1.5));
    if (k < 0.1) return;

    final span = _vr - _vl;
    final n = (span / 400 * 3).clamp(3, 9).round();
    for (var i = 0; i < n; i++) {
      final ph = _h01(i * 11 + 5) * 6.2832;
      final x0 = _vl + _h01(i * 11 + 1) * span;
      final x = x0 + math.sin(t * 0.4 + ph) * 46 + math.sin(t * 1.3 + ph) * 8;
      final y = 214 + _h01(i * 11 + 2) * 34 +
          math.sin(t * 0.6 + ph * 1.7) * 16 +
          math.sin(t * 5.0 + ph) * 1.6;
      final flap = 0.25 + 0.75 * math.sin(t * 16 + ph).abs();
      final col = _butterflyCols[_hh(i * 11 + 9) % _butterflyCols.length];
      final a = _c01(k);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(t * 1.7 + ph) * 0.3);
      _p
        ..style = PaintingStyle.fill
        ..shader = null;
      for (final sg in const [-1.0, 1.0]) {
        _p.color = col.withValues(alpha: 0.92 * a);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(sg * 2.3 * flap, -1.3),
                width: 4.6 * flap,
                height: 4.4),
            _p);
        _p.color = _mix(col, const Color(0xFF6D4C41), 0.35)
            .withValues(alpha: 0.85 * a);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(sg * 1.7 * flap, 1.6),
                width: 3.2 * flap,
                height: 3.0),
            _p);
      }
      _p.color = const Color(0xFF3E2723).withValues(alpha: a);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(-0.5, -2.6, 1.0, 5.4), const Radius.circular(0.5)),
          _p);
      canvas.restore();
    }
  }

  // ----------------------------------------------------- bintang jatuh

  /// Sesekali goresan bintang jatuh melintasi langit malam yang cerah.
  void _drawShootingStar(Canvas canvas, double t, double p) {
    if (d.compact || _ultra || d.dayPhase == null || d.eliminated) return;
    if (_isRainy || p > 0.5) return;
    final k = _c01((_night - 0.6) / 0.4);
    if (k <= 0) return;

    const cycle = 11.0;
    final id = (t / cycle).floor();
    if (_hh(id * 13 + 7) % 100 > 55) return; // tidak setiap siklus
    final ph = (t % cycle) / cycle;
    const dur = 0.07;
    if (ph > dur) return;
    final q = ph / dur;
    final env = math.sin(q * math.pi);

    final span = _vr - _vl;
    final sx = _vl + span * (0.15 + 0.6 * _h01(id * 5 + 1));
    final sy = 14 + 56 * _h01(id * 5 + 2);
    final dir = _h01(id * 5 + 3) < 0.5 ? 1.0 : -1.0;
    final ang = (dir > 0 ? 0.0 : math.pi) + dir * 0.42;
    final dx = math.cos(ang), dy = math.sin(ang);
    final head = Offset(sx + dx * q * 200, sy + dy * q * 200);

    _p
      ..style = PaintingStyle.stroke
      ..shader = null
      ..strokeCap = StrokeCap.round;
    const segs = 9;
    for (var i = 0; i < segs; i++) {
      final f0 = i / segs, f1 = (i + 1) / segs;
      final a = (1 - f0) * (1 - f0) * env * k;
      _p
        ..strokeWidth = 1.9 * (1 - f0 * 0.7)
        ..color = const Color(0xFFE3F2FD).withValues(alpha: _c01(0.85 * a));
      canvas.drawLine(
        Offset(head.dx - dx * 64 * f0, head.dy - dy * 64 * f0),
        Offset(head.dx - dx * 64 * f1, head.dy - dy * 64 * f1),
        _p,
      );
    }
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt
      ..color = Colors.white.withValues(alpha: _c01(env * k));
    canvas.drawCircle(head, 1.6, _p);
    _p.color = const Color(0xFFB3E5FC).withValues(alpha: _c01(0.35 * env * k));
    canvas.drawCircle(head, 4.5, _p);
  }

  // ---------------------------------------------------- debu cahaya

  /// Butir debu halus berkilau yang melayang saat cahaya matahari kuat
  /// (siang cerah dan terutama senja / "golden hour").
  void _drawDustMotes(Canvas canvas, double t, double p) {
    if (d.compact || _ultra || d.eliminated || _isRainy) return;
    final light = d.dayPhase == null
        ? 0.6
        : _c01(_sunElev * 1.6) * (1 - _night) + _dusk * 0.5;
    final s = _c01(light) * (1 - _c01(p * 1.4));
    if (s < 0.08) return;

    final span = _vr - _vl;
    var n = (span / 400 * 14).clamp(14, 44).round();
    if (KostPerf.on) n = (n * 0.5).round();
    final warm = _c01(_dusk * 1.4);
    final col = _mix(const Color(0xFFFFF8D6), const Color(0xFFFFC27A), warm);
    _p
      ..style = PaintingStyle.fill
      ..shader = null;
    for (var i = 0; i < n; i++) {
      final ph = _h01(i * 9 + 3) * 6.2832;
      final sp = 0.003 + _h01(i * 9 + 4) * 0.004;
      final x = _vl + _fract(_h01(i * 9 + 1) + t * sp) * span;
      final y = 36 + _h01(i * 9 + 2) * 190 + math.sin(t * 0.5 + ph) * 8;
      final tw = 0.5 + 0.5 * math.sin(t * 1.6 + ph * 6);
      final a = s * 0.55 * (0.25 + 0.75 * tw);
      final r = 0.6 + _h01(i * 9 + 5) * 0.9;
      _p.color = col.withValues(alpha: _c01(a));
      canvas.drawCircle(Offset(x, y), r, _p);
      if (r > 1.1 && tw > 0.8) {
        _p.color = col.withValues(alpha: _c01(a * 0.25));
        canvas.drawCircle(Offset(x, y), r * 3.2, _p);
      }
    }
  }

  // ------------------------------------------------------- kilau bersih

  /// Kost yang bersih (sampah sangat sedikit) berkilau: percikan bintang
  /// kecil muncul di atap & kaca secara bergantian. Umpan balik visual
  /// bahwa pemain sedang mengelola sampah dengan baik.
  void _drawCleanGlint(Canvas canvas, double t) {
    if (_ultra || d.eliminated || d.rooms <= 0) return;
    final clean = 1 - _c01(d.trashRatio / 0.12);
    if (clean <= 0.05) return;
    final night = d.dayPhase == null ? 0.0 : _night;
    final fh = _floors * _fh;
    final body = clean * (1 - 0.5 * night);
    for (var i = 0; i < 4; i++) {
      final period = 2.6 + i * 0.7;
      final u = (t + i * 1.37) / period;
      final id = u.floor();
      final q = u - id;
      const act = 0.22;
      if (q > act) continue;
      final s = math.sin(q / act * math.pi);
      final x = _bl + 6 + _h01(id * 17 + i * 3 + 1) * (4 * _cw - 12);
      final y = _roofY + 2 + _h01(id * 17 + i * 3 + 2) * (fh - 8);
      final r = (2.2 + 2.6 * _h01(id * 17 + i)) * s;
      _polishStar(canvas, Offset(x, y), r * 1.8, const Color(0xFFFFF8E1),
          0.55 * s * body);
      _polishStar(canvas, Offset(x, y), r, Colors.white, 0.95 * s * body);
    }
  }
}
