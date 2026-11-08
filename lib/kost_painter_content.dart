part of 'kost_scene.dart';

// ====================================================================
//  KONTEN BARU
//
//  Event dunia:
//    kerja_bakti     (positif) : warga bergotong royong -> laju sampah -20%,
//                                polusi turun lebih cepat.
//    sampah_kiriman  (negatif) : sampah hanyut dari hulu -> laju sampah +25%,
//                                polusi susah turun.
//  Hewan peliharaan:
//    turtle (kura-kura)        : income naik + sampah lemparan berkurang.
//
//  Angka gameplay HARUS sama dengan content_update.sql (server yang menentukan;
//  klien hanya menampilkan). Semua yang ada di file ini murni visual.
// ====================================================================

final TextPainter _kbText = TextPainter(
  text: const TextSpan(
    text: 'KERJA BAKTI',
    style: TextStyle(
      color: Colors.white,
      fontSize: 6.2,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.8,
    ),
  ),
  textDirection: TextDirection.ltr,
)..layout();

extension KostPainterContent on KostPainter {
  /// Jumlah rumah yang digambar (mode satu rumah = 1).
  int get _evHouses => math.max(1, (_streetW / _w).round());

  // ============================================================ KERJA BAKTI

  void _evKerjaBakti(Canvas canvas, double t) {
    for (var hi = 0; hi < _evHouses; hi++) {
      final ox = hi * _w;
      _kbBunting(canvas, t, ox);
      _kbWorkers(canvas, t, ox, hi);
    }
    _p
      ..style = PaintingStyle.fill
      ..shader = null;
  }

  /// Umbul-umbul merah putih di atap + spanduk "KERJA BAKTI".
  void _kbBunting(Canvas canvas, double t, double ox) {
    final y0 = _roofY;
    final x0 = ox + _bl - 8;
    final x1 = ox + _bl + 4 * _cw + 8;
    Offset at(double u) =>
        Offset(x0 + (x1 - x0) * u, y0 - 6 + 7 * math.sin(u * math.pi));

    final line = Path()..moveTo(x0, y0 - 6);
    for (var i = 1; i <= 20; i++) {
      final o = at(i / 20);
      line.lineTo(o.dx, o.dy);
    }
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..shader = null
      ..color = const Color(0xFF5D4037);
    canvas.drawPath(line, _p);

    _p.style = PaintingStyle.fill;
    const cols = [Color(0xFFE53935), Color(0xFFFAFAFA)];
    const nf = 14;
    for (var i = 0; i < nf; i++) {
      final o = at((i + 0.5) / nf);
      final sw = math.sin(t * 2.2 + i * 0.7) * 0.8;
      _p.color = cols[i % 2];
      canvas.drawPath(
        Path()
          ..moveTo(o.dx - 2.6, o.dy)
          ..lineTo(o.dx + 2.6, o.dy)
          ..lineTo(o.dx + sw, o.dy + 5.2)
          ..close(),
        _p,
      );
    }

    // spanduk
    final cx = ox + 200.0;
    final by = y0 - 38 + math.sin(t * 1.4) * 0.6;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0xFF5D4037);
    canvas.drawLine(Offset(cx - 24, by + 5.5), Offset(cx - 24, y0 - 8), _p);
    canvas.drawLine(Offset(cx + 24, by + 5.5), Offset(cx + 24, y0 - 8), _p);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF2E7D32);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, by), width: 60, height: 11),
          const Radius.circular(2)),
      _p,
    );
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.white.withValues(alpha: 0.75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, by), width: 57, height: 8.2),
          const Radius.circular(1.5)),
      _p,
    );
    _p.style = PaintingStyle.fill;
    _kbText.paint(canvas, Offset(cx - _kbText.width / 2, by - _kbText.height / 2));
  }

  /// Warga berompi oranye menyapu halaman, debu mengepul & percikan bersih.
  void _kbWorkers(Canvas canvas, double t, double ox, int hi) {
    final n = _lite ? 2 : 3;
    for (var k = 0; k < n; k++) {
      final ph = _h01(hi * 5 + k * 3 + 1) * 6.2832;
      final cx = ox + 150 + k * 48 + math.sin(t * 0.45 + ph) * 26;
      final dir = math.cos(t * 0.45 + ph) >= 0 ? 1.0 : -1.0;
      final y = 270.0 + (k % 2) * 5;
      final sw = math.sin(t * 5 + ph);

      canvas.save();
      canvas.translate(cx, y);
      canvas.scale(dir, 1);

      _p
        ..style = PaintingStyle.fill
        ..shader = null
        ..color = const Color(0xFF000000).withValues(alpha: 0.14);
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, 0.6), width: 9, height: 2.6),
          _p);

      // kaki
      final step = math.sin(t * 6 + ph) * 1.6;
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF37474F);
      canvas.drawLine(Offset(-0.8, -5.5), Offset(-0.8 + step, 0), _p);
      canvas.drawLine(Offset(0.8, -5.5), Offset(0.8 - step, 0), _p);

      // rompi
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFF8F00);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(-2.4, -11.6, 4.8, 6.4), const Radius.circular(1.2)),
          _p);
      _p.color = const Color(0xFFFFEE58);
      canvas.drawRect(Rect.fromLTWH(-2.4, -9.0, 4.8, 0.9), _p);

      // kepala & topi
      _p.color = const Color(0xFFD7A98B);
      canvas.drawCircle(const Offset(0, -13.4), 2.1, _p);
      _p.color = k.isEven ? const Color(0xFFE53935) : const Color(0xFF1E88E5);
      canvas.drawRect(Rect.fromLTWH(-2.2, -15.7, 4.4, 1.4), _p);

      // lengan + sapu
      final ang = 0.85 + sw * 0.35;
      const hand = Offset(2.6, -8.6);
      final tip = hand + Offset(math.cos(ang) * 12, math.sin(ang) * 12);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFFD7A98B);
      canvas.drawLine(const Offset(0.8, -10.6), hand, _p);
      _p
        ..strokeWidth = 0.8
        ..color = const Color(0xFF6D4C41);
      canvas.drawLine(hand, tip, _p);
      _p
        ..strokeWidth = 0.6
        ..color = const Color(0xFFC9A66B);
      for (var b = -1; b <= 1; b++) {
        canvas.drawLine(tip, tip + Offset(2.0 + b * 0.6, 1.4 + b * 1.0), _p);
      }
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt;

      // debu saat sapuan maju
      if (sw > 0.55) {
        for (var i = 0; i < 2; i++) {
          _p.color = const Color(0xFFD7CCC8)
              .withValues(alpha: _c01((sw - 0.55) * 1.2) * 0.55);
          canvas.drawCircle(
              tip + Offset(3.2 + i * 2.2, -0.6 - i * 1.0), 1.0 + i * 0.5, _p);
        }
      }
      canvas.restore();

      // percikan "bersih" yang naik dari tempat yang baru disapu
      final up = (t * 0.6 + k * 0.31 + hi * 0.17) % 1.0;
      _polishStar(
        canvas,
        Offset(cx + dir * 9, y - 4 - up * 12),
        2.4 * math.sin(up * math.pi),
        const Color(0xFFB9F6CA),
        0.9,
      );
    }
  }

  // ========================================================= SAMPAH KIRIMAN

  /// Sampah hanyut dari hulu: semburat keruh di dasar layar + tumpukan
  /// kantong, kardus, botol & gelas yang terapung mengalir ke kanan.
  void _evSampahKiriman(Canvas canvas, double t) {
    final span = _vr - _vl;
    final murk = Rect.fromLTRB(_vl, 274, _vr, _vb);
    _p
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00795548), Color(0x38795548)],
      ).createShader(murk);
    canvas.drawRect(murk, _p);
    _p.shader = null;

    final n = _lite ? 10 : (span / 400 * 18).clamp(18, 60).round();
    for (var i = 0; i < n; i++) {
      final h = _hh(i * 19 + 700);
      final sp = 18.0 + (h % 14);
      final x = _vl + ((t * sp + (h % 1000) / 1000 * span) % span);
      final y = 290.0 + (i % 3) * 3.2 + math.sin(t * 2.0 + i) * 1.1;
      _kiriItem(canvas, x, y, h % 4, math.sin(t * 1.5 + i) * 0.25, 1.0);
    }
    _p
      ..style = PaintingStyle.fill
      ..shader = null;
  }

  /// Satu benda hanyut: 0 kantong hitam, 1 kardus, 2 botol, 3 gelas.
  void _kiriItem(
      Canvas canvas, double x, double y, int kind, double rot, double alpha) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rot);
    // riak kecil di bawah benda
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..shader = null
      ..color = Colors.white.withValues(alpha: 0.35 * alpha);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 2.4), width: 10, height: 2.2), _p);
    _p.style = PaintingStyle.fill;
    switch (kind) {
      case 0:
        _p.color = const Color(0xFF263238).withValues(alpha: alpha);
        canvas.drawCircle(const Offset(0, -1.2), 3.0, _p);
        canvas.drawPath(
            Path()
              ..moveTo(-1.0, -3.8)
              ..lineTo(0, -5.6)
              ..lineTo(1.0, -3.8)
              ..close(),
            _p);
        _p.color = Colors.white.withValues(alpha: 0.25 * alpha);
        canvas.drawCircle(const Offset(-1.0, -2.0), 0.8, _p);
      case 1:
        _p.color = const Color(0xFFA1887F).withValues(alpha: alpha);
        canvas.drawRect(Rect.fromLTWH(-3.2, -3.6, 6.4, 4.4), _p);
        _p.color = const Color(0xFFD7CCC8).withValues(alpha: alpha);
        canvas.drawRect(Rect.fromLTWH(-0.5, -3.6, 1.0, 4.4), _p);
      case 2:
        _p.color = const Color(0xFF80CBC4).withValues(alpha: 0.85 * alpha);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(-1.2, -5.2, 2.4, 6.2), const Radius.circular(1.0)),
            _p);
        _p.color = const Color(0xFF1565C0).withValues(alpha: alpha);
        canvas.drawRect(Rect.fromLTWH(-0.7, -6.2, 1.4, 1.1), _p);
      default:
        _p.color = const Color(0xFFF5F5F5).withValues(alpha: alpha);
        canvas.drawRect(Rect.fromLTWH(-1.6, -3.6, 3.2, 4.0), _p);
        _p.color = const Color(0xFFE53935).withValues(alpha: alpha);
        canvas.drawRect(Rect.fromLTWH(-1.6, -2.4, 3.2, 1.0), _p);
    }
    canvas.restore();
  }

  /// Peringatan: beberapa benda hanyut mulai tampak dari tepi layar.
  void _warnBags(Canvas canvas, double t, double w, double spanX) {
    final n = ((_lite ? 5 : 12) * w).round();
    for (var i = 0; i < n; i++) {
      final h = _hh(i * 23 + 900);
      final x = _vl + ((t * (14 + h % 10) + (h % 1000) / 1000 * spanX) % spanX);
      final y = 291.0 + (i % 3) * 3.2 + math.sin(t * 2.0 + i) * 1.1;
      _kiriItem(canvas, x, y, h % 4, math.sin(t * 1.5 + i) * 0.25, _c01(w * 1.4));
    }
    _p
      ..style = PaintingStyle.fill
      ..shader = null;
  }

  // ============================================================ KURA-KURA

  void _petTurtle(Canvas c, PetDef def, PetAgent a, double t) {
    final shell = def.body;
    final acc = def.accent;
    final skin = Color.lerp(shell, const Color(0xFFC9B97A), 0.62)!;
    final skinD = Color.lerp(skin, const Color(0xFF000000), 0.18)!;
    final pose = a.pose;
    final hide = pose == PetPose.sleep ||
        pose == PetPose.alert ||
        pose == PetPose.flee;
    final happy = pose == PetPose.cheer;
    final sad = pose == PetPose.sad;
    final ph = t * (a.walking ? 5 : 2) + a.slot * 1.3;
    final bob = happy ? -math.sin(t * 9 + a.slot).abs() * 1.8 : 0.0;

    c.save();
    c.translate(0, bob);

    // kaki
    final sw = (a.walking && !hide) ? math.sin(ph) * 1.1 : 0.0;
    _p
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = skinD;
    const lx = [-4.6, -2.2, 2.2, 4.6];
    for (var i = 0; i < 4; i++) {
      final off = i.isEven ? sw : -sw;
      c.drawOval(
          Rect.fromCenter(
              center: Offset(lx[i] + off, -1.3), width: 2.8, height: 2.8),
          _p);
    }

    if (!hide) {
      // ekor
      c.drawPath(
          Path()
            ..moveTo(-6.6, -3.2)
            ..lineTo(-9.0, -2.2)
            ..lineTo(-6.4, -1.8)
            ..close(),
          _p);

      // leher & kepala
      final head = happy
          ? Offset(9.2, -8.6 + math.sin(t * 7 + a.slot) * 0.6)
          : (sad
              ? const Offset(8.2, -2.8)
              : Offset(9.6 + math.sin(ph * 0.5) * 0.4,
                  -5.4 + math.sin(t * 1.3 + a.slot) * 0.4));
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..color = skin;
      c.drawLine(const Offset(5.4, -4.2), head, _p);
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt
        ..color = skin;
      c.drawOval(Rect.fromCenter(center: head, width: 5.2, height: 4.4), _p);

      final blink = ((t * 0.5 + a.slot * 1.7) % 4.5) < 0.12;
      if (blink || sad) {
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = const Color(0xFF212121);
        c.drawLine(head + const Offset(0.6, -0.7), head + const Offset(1.8, -0.7), _p);
        _p.style = PaintingStyle.fill;
      } else {
        _p.color = def.eye;
        c.drawCircle(head + const Offset(1.2, -0.7), 0.8, _p);
        _p.color = Colors.white.withValues(alpha: 0.8);
        c.drawCircle(head + const Offset(1.45, -0.95), 0.25, _p);
      }
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = const Color(0xFF3E2723);
      c.drawLine(head + const Offset(1.4, 1.0), head + const Offset(2.5, 0.9), _p);
      _p.style = PaintingStyle.fill;
    }

    // cangkang (turun sedikit saat bersembunyi)
    c.save();
    if (hide) c.translate(0, 0.7);
    _p
      ..style = PaintingStyle.fill
      ..color = shell;
    c.drawPath(
        Path()
          ..moveTo(-7.4, -2.2)
          ..quadraticBezierTo(-7.4, -11.4, 0, -11.4)
          ..quadraticBezierTo(7.4, -11.4, 7.4, -2.2)
          ..close(),
        _p);
    _p.color = acc;
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTRB(-7.6, -3.4, 7.6, -1.8), const Radius.circular(0.8)),
        _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = acc.withValues(alpha: 0.85);
    c.drawLine(const Offset(-2.6, -10.8), const Offset(-3.6, -3.4), _p);
    c.drawLine(const Offset(2.6, -10.8), const Offset(3.6, -3.4), _p);
    c.drawLine(const Offset(-5.4, -6.4), const Offset(5.4, -6.4), _p);
    _p.style = PaintingStyle.fill;
    _p.color = Colors.white.withValues(alpha: 0.25);
    c.drawOval(
        Rect.fromCenter(center: const Offset(-2.2, -9.4), width: 4.2, height: 1.6),
        _p);
    c.restore();

    c.restore();
  }
}
