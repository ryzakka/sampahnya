part of 'kost_scene.dart';

/// Sidak polisi, segel, dan rumah tertimbun.
extension KostPainterSidak on KostPainter {
  // ------------------------- sidak RT/dinas & segel kost

  // ====================================================================
  //  SIDAK POLISI & RUMAH TERTIMBUN (adegan sinematik per rumah)
  // ====================================================================



  /// Satu pita polisi dari [a] ke [b], terbentang sampai [prog] (0..1).
  void _tapeStrip(
      Canvas canvas, Offset a, Offset b, double prog, double alpha) {
    prog = _c01(prog);
    if (prog <= 0.001 || alpha <= 0.02) return;
    final len = (b - a).distance;
    final ang = math.atan2(b.dy - a.dy, b.dx - a.dx);
    canvas.save();
    canvas.translate(a.dx, a.dy);
    canvas.rotate(ang);
    if (alpha < 1) {
      canvas.saveLayer(
        Rect.fromLTWH(-4, -8, len + 8, 16),
        Paint()..color = Color.fromRGBO(0, 0, 0, _c01(alpha)),
      );
    }
    canvas.clipRect(Rect.fromLTWH(0, -6, len * prog, 12));
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFD600);
    canvas.drawRect(Rect.fromLTWH(0, -3.4, len, 6.8), _p);
    _p.color = Colors.black87;
    canvas.drawRect(Rect.fromLTWH(0, -3.4, len, 0.7), _p);
    canvas.drawRect(Rect.fromLTWH(0, 2.7, len, 0.7), _p);
    var x = 3.0;
    while (x < len) {
      _tapeText.paint(canvas, Offset(x, -_tapeText.height / 2));
      x += _tapeText.width;
    }
    if (alpha < 1) canvas.restore();
    canvas.restore();
  }

  /// Tiang pita (belang merah-putih) di sisi rumah.
  void _tapePost(Canvas canvas, double x, double alpha) {
    if (alpha <= 0.02) return;
    for (var k = 0; k < 6; k++) {
      _p
        ..style = PaintingStyle.fill
        ..color = (k.isEven ? const Color(0xFFE53935) : Colors.white)
            .withValues(alpha: _c01(alpha));
      canvas.drawRect(Rect.fromLTWH(x - 1.6, _gy + 2 - (k + 1) * 8.0, 3.2, 8), _p);
    }
    _p.color = const Color(0xFF455A64).withValues(alpha: _c01(alpha));
    canvas.drawRect(Rect.fromLTWH(x - 4, _gy + 1, 8, 2.4), _p);
  }


  /// Petugas Satpol PP. [role]: 0 = biasa, 1 = komandan bermegafon,
  /// 2 = pemeriksa dengan papan catatan & senter. Menghadap +x lalu dibalik
  /// oleh [dir]. Detail: topi + lencana, rompi reflektif, ikat pinggang, sepatu.
  void _officer(Canvas canvas, Offset feet,
      {double swing = 0,
        double alpha = 1,
        double dir = 1,
        int role = 0,
        double t = 0}) {
    final a = _c01(alpha);
    if (a <= 0.02) return;
    if (a < 1) {
      canvas.saveLayer(
        Rect.fromCenter(center: feet.translate(0, -14), width: 70, height: 60),
        Paint()..color = Color.fromRGBO(0, 0, 0, a),
      );
    }
    const navy = Color(0xFF1E4FA3);
    const dark = Color(0xFF0D2547);
    const skin = Color(0xFFE0AC84);
    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.scale(dir >= 0 ? 1.0 : -1.0, 1.0);

    // bayangan
    _p
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.2);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 0.5), width: 12, height: 2.6), _p);

    // kaki + sepatu
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF16233D);
    canvas.drawLine(const Offset(0, -9), Offset(-swing, -0.8), _p);
    canvas.drawLine(const Offset(0, -9), Offset(swing, -0.8), _p);
    _p
      ..strokeWidth = 2.4
      ..color = Colors.black;
    canvas.drawLine(Offset(-swing, -0.5), Offset(-swing + 1.4, -0.5), _p);
    canvas.drawLine(Offset(swing, -0.5), Offset(swing + 1.4, -0.5), _p);

    // lengan belakang (selalu mengayun / bertolak pinggang)
    _p
      ..strokeWidth = 1.9
      ..color = navy;
    if (role == 0) {
      canvas.drawLine(const Offset(0, -16), Offset(-swing * 0.9, -10.5), _p);
    } else {
      canvas.drawLine(const Offset(0, -16), const Offset(-3.4, -11.5), _p); // tolak pinggang
    }

    // badan
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt
      ..color = navy;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3.7, -18, 7.4, 10), const Radius.circular(2.2)),
      _p,
    );
    // rompi reflektif + ikat pinggang + lencana
    _p.color = const Color(0xFFFFD600).withValues(alpha: 0.9);
    canvas.drawRect(const Rect.fromLTWH(-3.7, -14.4, 7.4, 1.1), _p);
    _p.color = const Color(0xFF212121);
    canvas.drawRect(const Rect.fromLTWH(-3.7, -10.2, 7.4, 1.4), _p);
    _p.color = const Color(0xFFFFD54F);
    canvas.drawRect(const Rect.fromLTWH(-0.6, -10.1, 1.5, 1.2), _p);
    canvas.drawCircle(const Offset(1.9, -16.3), 0.9, _p);

    // kepala + topi
    _p.color = skin;
    canvas.drawCircle(const Offset(0, -21.5), 3.3, _p);
    _p.color = dark;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3.9, -25.4, 7.8, 3.6), const Radius.circular(1.6)),
      _p,
    );
    canvas.drawRect(const Rect.fromLTWH(0.8, -22.2, 5.2, 1.2), _p); // pet
    _p.color = const Color(0xFFFFD600);
    canvas.drawCircle(const Offset(0.6, -23.6), 0.8, _p);

    // lengan depan menurut peran
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..color = navy;
    if (role == 0) {
      canvas.drawLine(const Offset(0, -16), Offset(swing * 0.9, -10.5), _p);
    } else if (role == 1) {
      // megafon: lengan terangkat & sedikit bergerak mengikuti ucapan
      final bob = math.sin(t * 9) * 0.7;
      final hand = Offset(5.4, -19.0 + bob);
      canvas.drawLine(const Offset(0, -16), hand, _p);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFE0E0E0);
      canvas.drawPath(
        Path()
          ..moveTo(hand.dx - 0.5, hand.dy - 1.4)
          ..lineTo(hand.dx + 6.4, hand.dy - 3.4)
          ..lineTo(hand.dx + 6.4, hand.dy + 2.4)
          ..lineTo(hand.dx - 0.5, hand.dy + 1.4)
          ..close(),
        _p,
      );
      _p.color = const Color(0xFFE53935);
      canvas.drawRect(Rect.fromLTWH(hand.dx + 5.2, hand.dy - 3.4, 1.2, 5.8), _p);
      _p.color = skin;
      canvas.drawCircle(hand, 1.2, _p);
    } else {
      // papan catatan di depan dada + senter di tangan belakang
      canvas.drawLine(const Offset(0, -16), const Offset(4.2, -13.4), _p);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF6D4C41);
      canvas.drawRect(const Rect.fromLTWH(3.4, -18.2, 5.4, 7), _p);
      _p.color = const Color(0xFFFFF8E1);
      canvas.drawRect(const Rect.fromLTWH(3.9, -17.5, 4.4, 5.6), _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = const Color(0xFF90A4AE);
      for (var k = 0; k < 3; k++) {
        canvas.drawLine(Offset(4.3, -16.4 + k * 1.7), Offset(7.9, -16.4 + k * 1.7), _p);
      }
      // pena menulis
      final wr = math.sin(t * 14) * 0.9;
      _p
        ..strokeWidth = 0.9
        ..color = const Color(0xFFD32F2F);
      canvas.drawLine(Offset(6.4 + wr, -14.2), Offset(7.6 + wr, -13), _p);
    }
    canvas.restore();
    if (a < 1) canvas.restore();
  }

  /// Berkas sirine merah/biru berputar yang menyapu dinding rumah.
  void _policeBeams(Canvas canvas, Offset src, double t, double k) {
    if (k <= 0.02) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(_vl, _vt, _vr, _gy + 8));
    for (var s = 0; s < 2; s++) {
      final red = s == 0;
      final ang = -0.78 + (red ? 1 : -1) * 0.62 * math.sin(t * 3.4);
      const len = 190.0;
      const w = 0.13;
      final c = red ? const Color(0xFFFF1744) : const Color(0xFF2979FF);
      final path = Path()
        ..moveTo(src.dx, src.dy)
        ..lineTo(src.dx + math.cos(ang - w) * len, src.dy + math.sin(ang - w) * len)
        ..lineTo(src.dx + math.cos(ang + w) * len, src.dy + math.sin(ang + w) * len)
        ..close();
      _p
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [c.withValues(alpha: 0.30 * k), c.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: src, radius: len));
      canvas.drawPath(path, _p);
      _p.shader = null;
    }
    canvas.restore();
  }

  /// Gelombang suara dari megafon.
  void _megaWaves(Canvas canvas, Offset tip, double dir, double t, double k) {
    if (k <= 0.02) return;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final u = ((t * 1.7) + i / 3) % 1.0;
      final r = 5 + u * 26;
      _p.color = Colors.white.withValues(alpha: (1 - u) * 0.65 * k);
      canvas.drawArc(
        Rect.fromCircle(center: tip, radius: r),
        dir >= 0 ? -0.62 : math.pi - 0.62,
        1.24,
        false,
        _p,
      );
    }
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }

  /// Segel di pintu: pita silang merah + kertas "DISEGEL". [u] 0..1 = tahap
  /// stempel (menghantam lalu memantul), [t] untuk kibaran kecil.
  void _doorSeal(Canvas canvas, double u, double t) {
    if (u <= 0 || d.compact) return;
    const door = Rect.fromLTWH(195, 214, 12, 22);
    final pop = _easeOutBack(u);
    // pita silang
    canvas.save();
    canvas.clipRect(door.inflate(1.4));
    for (final s in const [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(door.center.dx, door.center.dy);
      canvas.rotate(s * 0.95);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFD32F2F).withValues(alpha: _c01(u * 3));
      canvas.drawRect(Rect.fromLTWH(-16 * pop, -1.7, 32 * pop, 3.4), _p);
      _p.color = Colors.white.withValues(alpha: 0.6 * _c01(u * 3));
      canvas.drawRect(Rect.fromLTWH(-16 * pop, -0.4, 32 * pop, 0.8), _p);
      canvas.restore();
    }
    canvas.restore();
    // kertas segel
    final sc = 0.2 + 0.8 * pop;
    canvas.save();
    canvas.translate(door.center.dx, door.center.dy - 2 + math.sin(t * 2.3) * 0.15);
    canvas.rotate(-0.1);
    canvas.scale(sc);
    _p.color = const Color(0xFFFFF8E1);
    canvas.drawRect(const Rect.fromLTWH(-9, -5.4, 18, 10.8), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFB71C1C);
    canvas.drawRect(const Rect.fromLTWH(-8, -4.4, 16, 8.8), _p);
    _p.style = PaintingStyle.fill;
    _sealText.paint(canvas, Offset(-_sealText.width / 2, -_sealText.height / 2 - 0.6));
    _p.color = const Color(0xFFB71C1C);
    canvas.drawRect(const Rect.fromLTWH(-6, 1.8, 12, 0.7), _p);
    canvas.restore();
  }

  void _policeCar(Canvas canvas, double cx, double cy, double t,
      {bool lights = true}) {
    _p
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.22);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy + 0.5), width: 48, height: 6), _p);
    _p.color = const Color(0xFF263238);
    canvas.drawCircle(Offset(cx - 12, cy - 2), 3.8, _p);
    canvas.drawCircle(Offset(cx + 12, cy - 2), 3.8, _p);
    _p.color = const Color(0xFFBDBDBD);
    canvas.drawCircle(Offset(cx - 12, cy - 2), 1.4, _p);
    canvas.drawCircle(Offset(cx + 12, cy - 2), 1.4, _p);
    _p.color = const Color(0xFFECEFF1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 20, cy - 12, 40, 9), const Radius.circular(3)),
      _p,
    );
    _p.color = const Color(0xFF1565C0);
    canvas.drawRect(Rect.fromLTWH(cx - 20, cy - 8, 40, 3), _p);
    // pintu & tulisan samping
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0xFF78909C);
    canvas.drawLine(Offset(cx - 2, cy - 12), Offset(cx - 2, cy - 3.2), _p);
    canvas.drawLine(Offset(cx + 8, cy - 12), Offset(cx + 8, cy - 3.2), _p);
    _p.style = PaintingStyle.fill;
    _p.color = Colors.white.withValues(alpha: 0.9);
    canvas.drawRect(Rect.fromLTWH(cx - 17, cy - 7.4, 12, 1.6), _p);
    _p.color = const Color(0xFFECEFF1);
    canvas.drawPath(
      Path()
        ..moveTo(cx - 11, cy - 12)
        ..lineTo(cx - 6, cy - 19)
        ..lineTo(cx + 8, cy - 19)
        ..lineTo(cx + 12, cy - 12)
        ..close(),
      _p,
    );
    _p.color = const Color(0xFF90CAF9);
    canvas.drawPath(
      Path()
        ..moveTo(cx - 8.5, cy - 12.6)
        ..lineTo(cx - 5, cy - 17.4)
        ..lineTo(cx + 6.5, cy - 17.4)
        ..lineTo(cx + 9.5, cy - 12.6)
        ..close(),
      _p,
    );
    _p.color = const Color(0xFFFFF59D);
    canvas.drawCircle(Offset(cx + 19, cy - 9.5), 1.6, _p);
    _p.color = const Color(0xFFEF5350);
    canvas.drawRect(Rect.fromLTWH(cx - 20.5, cy - 9.5, 1.6, 2.6), _p);

    // sirine berkedip merah / biru (strobo ganda)
    final redOn = lights ? math.sin(t * 18) > 0 : false;
    final glow = redOn ? const Color(0xFFFF1744) : const Color(0xFF2979FF);
    final lc = Offset(cx + 1, cy - 21);
    if (lights) {
      _p.shader = RadialGradient(
        colors: [glow.withValues(alpha: 0.5), glow.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: lc, radius: 38));
      canvas.drawCircle(lc, 38, _p);
      _p.shader = null;
    }
    _p.color = redOn ? const Color(0xFFFF1744) : const Color(0xFF7F0D22);
    canvas.drawRect(Rect.fromLTWH(cx - 5, cy - 22.6, 5.4, 3.4), _p);
    _p.color = redOn || !lights ? const Color(0xFF14316B) : const Color(0xFF2979FF);
    canvas.drawRect(Rect.fromLTWH(cx + 0.4, cy - 22.6, 5.4, 3.4), _p);
  }

  /// Sidak polisi (versi dramatis):
  ///   0 .. 2600     mobil meluncur, mengerem (jejak ban, debu, bodi menunduk),
  ///                 berkas sirine berputar menyapu dinding
  ///   2600 .. 4400  petugas turun; komandan berpidato lewat megafon, pemeriksa
  ///                 menyorot tumpukan sampah dengan senter & mencatat
  ///   4400 .. 8000  garis polisi dibentang satu per satu
  ///   8000 .. 9600  pemeriksa menempel segel di pintu: hantaman, kilat, guncangan
  ///   (bila tidak disegel) pita dibereskan, petugas pergi, mobil melaju.
  /// Saat [KostSceneData.policeAgeMs] null tetapi kost masih disegel, yang
  /// tampil adalah keadaan AKHIR animasi (sehingga serah-terimanya mulus).
  void _drawInspectAndSeal(Canvas canvas, double t) {
    if (d.eliminated) return;
    final age = d.policeAgeMs;
    final sealed = d.sealedLeft > 0;
    if (age == null && !sealed) return;

    final done = age == null;
    final a = age ?? 1000000;
    final leaveU = (!sealed && !done)
        ? _c01((a - kPoliceLeaveStartMs) / (kPoliceTotalMs - 200 - kPoliceLeaveStartMs))
        : 0.0;
    final tapeA = 1 - leaveU;
    final tp = _c01((a - kPoliceTapeStartMs) / kPoliceTapeMs);
    const cy = 278.0;
    final sealImpact = kPoliceTapeEndMs + 500;
    final sealU = done ? 1.0 : _c01((a - sealImpact) / 420.0);
    final dark = done
        ? 1.0
        : _c01((a - kPoliceTapeEndMs) / 900.0) * (1 - leaveU);

    // ---- posisi mobil + gaya mengerem
    var carX = 152.0;
    var driveU = 1.0;
    var pitch = 0.0;
    if (a < kPoliceDriveMs) {
      driveU = a / kPoliceDriveMs;
      carX = _lerp(-90, 152, 1 - math.pow(1 - driveU, 3).toDouble());
      if (driveU > 0.7) {
        pitch = math.sin(_c01((driveU - 0.7) / 0.3) * math.pi) * 0.045;
      }
    }
    carX += leaveU * leaveU * 520;
    final carHere = carX > -70 && carX < 470;

    // ---- sorot sirine di tanah + berkas yang menyapu dinding
    final lightsOn = !done && leaveU < 0.9;
    final redOn = math.sin(t * 18) > 0;
    if (lightsOn && carHere) {
      _p
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [
            (redOn ? const Color(0xFFFF1744) : const Color(0xFF2979FF))
                .withValues(alpha: 0.34),
            (redOn ? const Color(0xFFFF1744) : const Color(0xFF2979FF))
                .withValues(alpha: 0),
          ],
        ).createShader(
            Rect.fromCenter(center: Offset(carX, cy + 2), width: 150, height: 34));
      canvas.drawOval(
          Rect.fromCenter(center: Offset(carX, cy + 2), width: 150, height: 34), _p);
      _p.shader = null;
      _policeBeams(canvas, Offset(carX + 1, cy - 21), t, _c01(1 - leaveU * 1.2));
    }

    // kilau sirine menyapu fasad rumah
    if (carX > 40 && leaveU < 0.7 && !done) {
      _p
        ..style = PaintingStyle.fill
        ..color = (redOn ? const Color(0xFFFF1744) : const Color(0xFF2979FF))
            .withValues(alpha: 0.10);
      canvas.drawRect(
        Rect.fromLTWH(_bl - 10, _roofY - 6, 210, _gy - _roofY + 8),
        _p,
      );
    }

    // fasad meredup setelah disegel (rumah "dimatikan")
    if (dark > 0.01) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF0B1220).withValues(alpha: 0.2 * dark);
      canvas.drawRect(
        Rect.fromLTWH(_bl - 8, _roofY - 24, 206, _gy - _roofY + 26),
        _p,
      );
    }

    // ---- jejak ban & debu saat mengerem
    if (!done && a < kPoliceLeaveStartMs) {
      final ta = _c01((driveU - 0.55) / 0.3) * 0.38;
      if (ta > 0.01) {
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = Colors.black.withValues(alpha: ta);
        final x0 = _lerp(-90, 152, 1 - math.pow(1 - 0.55, 3).toDouble());
        canvas.drawLine(Offset(x0, cy - 1.2), Offset(carX - 13, cy - 1.2), _p);
        canvas.drawLine(Offset(x0, cy + 2.2), Offset(carX + 11, cy + 2.2), _p);
        _p
          ..style = PaintingStyle.fill
          ..strokeCap = StrokeCap.butt;
      }
    }
    if (driveU < 1) {
      for (var k = 0; k < 7; k++) {
        final ph = _c01((driveU - 0.5 - k * 0.02) / 0.5);
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFCFD8DC)
              .withValues(alpha: _c01((1 - ph) * ph * 2.2) * 0.55);
        canvas.drawCircle(
            Offset(carX - 24 - k * 6 - ph * 10, cy - 2 - k * 1.8 - ph * 6),
            2.4 + k * 1.0 + ph * 3,
            _p);
      }
    }

    // ---- garis polisi: tiang + 4 pita (dua mendatar + silang)
    final tapes = <(Offset, Offset)>[
      (const Offset(96, _gy - 16), const Offset(304, _gy - 16)),
      (const Offset(304, _gy - 40), const Offset(96, _gy - 40)),
      (const Offset(98, _gy - 44), const Offset(302, _gy - 8)),
      (const Offset(302, _gy - 44), const Offset(98, _gy - 8)),
    ];
    final postA = tapeA * _c01(tp * 10);
    _tapePost(canvas, 96, postA);
    _tapePost(canvas, 304, postA);
    for (var i = 0; i < 4; i++) {
      // pita bergoyang halus ditiup angin setelah terpasang
      _tapeStrip(canvas, tapes[i].$1, tapes[i].$2, tp * 4 - i, tapeA);
    }

    // ---- segel di pintu
    _doorSeal(canvas, sealU, t);

    // ---- mobil (menunduk saat mengerem)
    if (carHere) {
      canvas.save();
      canvas.translate(carX, cy);
      canvas.rotate(pitch);
      canvas.translate(-carX, -cy);
      _policeCar(canvas, carX, cy, t, lights: lightsOn);
      canvas.restore();
    }

    // ---- petugas
    final offA = _c01(1 - leaveU * 3);
    final walk = math.sin(t * 16) * 3.2;
    final emerge = (a - kPoliceDriveMs) / 700.0;

    if (offA > 0 && (a >= kPoliceDriveMs || done)) {
      // Pemeriksa (peran 2): turun, menyorot sampah, lalu menuju pintu
      Offset f2;
      var sw2 = 0.0;
      var dir2 = 1.0;
      if (done) {
        f2 = const Offset(188, 254);
      } else if (a < kPoliceDriveMs + 700) {
        final u = _ease(_c01(emerge));
        f2 = Offset(_lerp(160, 226, u), _lerp(274, 262, u));
        sw2 = walk;
        dir2 = 1.0;
      } else if (a < kPoliceTapeStartMs) {
        // menyorot tumpukan sampah kiri-kanan sambil mencatat
        f2 = const Offset(226, 262);
        dir2 = math.sin(t * 1.3) > 0 ? 1.0 : -1.0;
      } else if (a < sealImpact - 600) {
        final u = _ease((a - kPoliceTapeStartMs) / (sealImpact - 600 - kPoliceTapeStartMs));
        f2 = Offset(_lerp(226, 188, u), _lerp(262, 254, u));
        sw2 = u < 1 ? walk : 0;
        dir2 = u < 1 ? -1.0 : 1.0;
      } else {
        f2 = const Offset(188, 254);
      }
      _officer(canvas, f2, swing: sw2, alpha: offA, dir: dir2, role: 2, t: t);

      // senter: berkas ke tanah saat memeriksa (tidak di keadaan akhir)
      if (!done && a >= kPoliceDriveMs + 700 && a < kPoliceTapeStartMs) {
        final tip = f2.translate(dir2 * 7, -12.5);
        final sweep = math.sin(t * 2.6);
        final target = Offset(f2.dx + dir2 * (40 + 38 * sweep.abs()), 256);
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFFF59D).withValues(alpha: 0.22 * offA);
        canvas.drawPath(
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(target.dx - 7, target.dy + 4)
            ..lineTo(target.dx + 7, target.dy + 4)
            ..close(),
          _p,
        );
        _p.color = const Color(0xFFFFF59D).withValues(alpha: 0.35 * offA);
        canvas.drawOval(
            Rect.fromCenter(center: Offset(target.dx, target.dy + 3), width: 16, height: 4),
            _p);
      }

      // Komandan (peran 1): pidato megafon lalu membentang pita
      Offset f1;
      var sw1 = 0.0;
      var dir1 = 1.0;
      var role1 = 1;
      if (done) {
        f1 = const Offset(98, 250);
        role1 = 0;
      } else if (a < kPoliceDriveMs + 700) {
        final u = _ease(_c01(emerge));
        f1 = Offset(_lerp(146, 118, u), _lerp(274, 264, u));
        sw1 = walk;
        dir1 = 1.0;
      } else if (a < kPoliceTapeStartMs) {
        f1 = const Offset(118, 264); // berdiri berpidato menghadap rumah
        dir1 = 1.0;
      } else if (tp < 1) {
        final seg = math.min(3, (tp * 4).floor());
        final su = tp * 4 - seg;
        final tt = tapes[seg];
        final fromX = seg == 0 ? 118.0 : tt.$1.dx;
        f1 = Offset(_lerp(fromX, tt.$2.dx, _ease(su)), 250);
        dir1 = tt.$2.dx >= tt.$1.dx ? 1.0 : -1.0;
        sw1 = walk;
        role1 = 0;
      } else {
        f1 = const Offset(98, 250);
        dir1 = 1.0;
        role1 = 0;
      }
      _officer(canvas, f1, swing: sw1, alpha: offA, dir: dir1, role: role1, t: t);

      // gelombang suara megafon
      if (!done && a >= kPoliceDriveMs + 700 && a < kPoliceTapeStartMs) {
        final k = _c01(math.min((a - kPoliceDriveMs - 700) / 250.0,
            (kPoliceTapeStartMs - a) / 300.0));
        _megaWaves(canvas, f1.translate(dir1 * 17, -19.2), dir1, t, k);
      }
    }

    // ---- hantaman segel: kilat, cincin kejut, serpihan kertas
    if (!done && a >= sealImpact && a < sealImpact + 700) {
      final q = (a - sealImpact) / 700.0;
      final c = const Offset(201, 224);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * (1 - q)
        ..color = const Color(0xFFFFD600).withValues(alpha: (1 - q) * 0.9);
      canvas.drawCircle(c, 6 + q * 46, _p);
      _p
        ..strokeWidth = 1.6 * (1 - q)
        ..color = Colors.white.withValues(alpha: (1 - q) * 0.8);
      canvas.drawCircle(c, 3 + q * 30, _p);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFF8E1).withValues(alpha: (1 - q) * 0.9);
      for (var k = 0; k < 9; k++) {
        final ang = -math.pi + k * (math.pi * 2 / 9) + 0.3;
        final dist = 8 + q * (22 + (k % 3) * 9);
        canvas.save();
        canvas.translate(c.dx + math.cos(ang) * dist, c.dy + math.sin(ang) * dist + q * q * 14);
        canvas.rotate(q * 8 + k);
        canvas.drawRect(const Rect.fromLTWH(-1.4, -0.9, 2.8, 1.8), _p);
        canvas.restore();
      }
      if (q < 0.18) {
        _p.color = Colors.white.withValues(alpha: (1 - q / 0.18) * 0.42);
        canvas.drawRect(_view, _p);
      }
    }

    // ---- teks
    const bannerPos = Offset(200, _gy - 56);
    if (!done) {
      if (a >= 500 && a < 2500) {
        final env = _c01(math.min((a - 500) / 300.0, (2500 - a) / 400.0));
        _drawBannerText(canvas, 'SIDAK DINAS TIBA!', bannerPos,
            const Color(0xFFFF5252),
            scale: 1.15 + 0.1 * math.sin(t * 14), alpha: env);
      }
      if (a >= kPoliceDriveMs + 900 && a < kPoliceTapeStartMs) {
        final env = _c01(math.min((a - kPoliceDriveMs - 900) / 300.0,
            (kPoliceTapeStartMs - a) / 350.0));
        _drawBannerText(canvas, 'HARAP KELUAR! KOST DISIDAK!', bannerPos,
            const Color(0xFF80D8FF),
            scale: 1.0 + 0.08 * math.sin(t * 16), alpha: env);
      }
      if (a >= sealImpact && a < sealImpact + 1300) {
        final q = (a - sealImpact) / 1300.0;
        final env = _c01(math.min(q * 8, (1 - q) * 3.5));
        _drawBannerText(canvas, 'DISEGEL!', bannerPos,
            const Color(0xFFFFD600),
            scale: 0.8 + 0.75 * _easeOutBack(math.min(1.0, q * 4)),
            alpha: env);
      }
    }
    if (sealed && (done || a >= sealImpact + 1300)) {
      _drawBannerText(
        canvas,
        'DISEGEL DINAS (${d.sealedLeft.ceil()}s)',
        bannerPos,
        const Color(0xFFFF5252),
      );
    }
  }

  // ------------------------------------------------------ RUMAH TERTIMBUN

  /// Longsoran kantong sampah yang jatuh mengisi sisa slot halaman lalu atap,
  /// persis di tempat keadaan "tertimbun" akan menggambarnya (tanpa lompatan).
  void _drawAvalanche(Canvas canvas, int age) {
    final total = _slots.length;
    final over = _overflowRatio;
    final count0 = over <= 0.005
        ? 0
        : math.max(1, (math.pow(over, 1.15) * total).round());
    final groundLeft = math.max(0, total - count0);
    final m = groundLeft + _roofSlots.length;
    const t0 = 900.0;
    const span = 3500.0;
    const fall = 560.0;
    for (var j = 0; j < m; j++) {
      final land = t0 + j * (span / m);
      final since = age - (land - fall);
      if (since < 0) continue;
      final Offset target;
      final int seed; // sama dengan seed di _drawBags agar tidak "berubah rupa"
      if (j < groundLeft) {
        target = _slots[count0 + j];
        seed = count0 + j;
      } else {
        final rs = _roofSlots[j - groundLeft];
        target = Offset(rs.dx, _roofY + rs.dy);
        seed = 300 + (j - groundLeft);
      }
      final q = since / fall;
      if (q < 1) {
        final e = q * q;
        final pos = Offset(
          target.dx + math.sin(j * 1.7) * 14 * (1 - e),
          target.dy - (1 - e) * 340,
        );
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(q * 6 + j);
        _bag(canvas, Offset.zero, seed);
        canvas.restore();
      } else {
        _bag(canvas, target, seed);
        final lt = (age - land) / 220.0;
        if (lt >= 0 && lt < 1) {
          _p
            ..style = PaintingStyle.fill
            ..color = const Color(0xFFBDBDBD).withValues(alpha: (1 - lt) * 0.35);
          canvas.drawCircle(target.translate(0, -2), 4 + lt * 7, _p);
        }
      }
    }
  }

  /// Papan "DIJUAL" yang tertancap di tumpukan sampah. [drop] = tinggi jatuh (px).
  void _saleSign(Canvas canvas, double drop) {
    canvas.save();
    canvas.translate(238, 262 - drop);
    canvas.rotate(-0.1);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF6D4C41);
    canvas.drawRect(const Rect.fromLTWH(-1.2, -2, 2.4, 20), _p);
    _p.color = const Color(0xFFB71C1C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-17, -16, 34, 15), const Radius.circular(2)),
      _p,
    );
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-15.5, -14.5, 31, 12), const Radius.circular(1.5)),
      _p,
    );
    _p.style = PaintingStyle.fill;
    _saleText.paint(canvas, Offset(-_saleText.width / 2, -8.5 - _saleText.height / 2));
    canvas.restore();
  }

  /// Penghuni yang kehilangan segalanya: duduk di atas kopernya, menangis
  /// di bawah hujan.
  void _sadResident(Canvas canvas, double t, double alpha) {
    if (alpha <= 0.02) return;
    const x = 206.0;
    const y = 288.0;
    canvas.saveLayer(
      Rect.fromLTWH(x - 34, y - 56, 68, 62),
      Paint()..color = Color.fromRGBO(0, 0, 0, _c01(alpha)),
    );
    canvas.save();
    canvas.translate(x + math.sin(t * 28) * 0.35, y);

    // koper
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF8D6E63);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-11, -12, 22, 12), const Radius.circular(2)),
      _p,
    );
    _p.color = const Color(0xFF5D4037);
    canvas.drawRect(const Rect.fromLTWH(-11, -7, 22, 1.4), _p);
    canvas.drawRect(const Rect.fromLTWH(-2.5, -13.4, 5, 1.6), _p);

    final ow = d.owner;
    if (ow != null) {
      // pemilik kost (karakter kustom pemain) duduk lesu di atas koper
      paintKostCharacter(canvas, _p, ow.look,
          t: t, pose: KostPose.sad, onBox: true, tears: false);
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt;
    } else {
      // kaki menjuntai
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF37474F);
      canvas.drawLine(const Offset(-1, -12), const Offset(-6, -1), _p);
      canvas.drawLine(const Offset(2, -12), const Offset(4, -1), _p);

      // badan membungkuk, kepala tertunduk
      canvas.save();
      canvas.translate(0, -12);
      canvas.rotate(0.32);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF78909C);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-3.6, -12, 7.2, 12), const Radius.circular(2.5)),
        _p,
      );
      _p.color = const Color(0xFFE0AC84);
      canvas.drawCircle(const Offset(1.5, -15.5), 3.8, _p);
      _p.color = const Color(0xFF3E2723);
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(1.5, -15.5), radius: 3.8),
        math.pi,
        math.pi,
        true,
        _p,
      );
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF78909C);
      canvas.drawLine(const Offset(0, -9), const Offset(3.4, -13.5), _p);
      canvas.restore();

    }

    // air mata
    _p.style = PaintingStyle.fill;
    for (var k = 0; k < 3; k++) {
      final u = (t * 1.3 + k * 0.33) % 1.0;
      _p.color = const Color(0xFF81D4FA).withValues(alpha: (1 - u) * 0.85);
      canvas.drawCircle(Offset(7.5 + k * 0.8, -24 + u * 16), 0.95, _p);
    }
    canvas.restore();
    canvas.restore();
  }

  void _drawBuriedCine(Canvas canvas, double t) {
    if (d.compact) return;
    final age = d.buriedAgeMs;
    final resting = d.eliminated && age == null;
    if (age == null && !resting) return;

    if (age != null && age < kBuriedCollapseMs && !d.eliminated) {
      _drawAvalanche(canvas, age);
    }

    // papan DIJUAL: jatuh menancap, lalu menetap di rumah yang tertimbun
    if (resting) {
      _saleSign(canvas, 0);
    } else if (age != null && age >= 5600) {
      final e = _easeOutBack((age - 5600) / 500.0);
      _saleSign(canvas, (1 - e) * 70);
    }

    // penghuni sedih (hanya selama adegan)
    if (age != null && age >= 5000) {
      final fin = _c01((age - 5000) / 700.0);
      final fout = _c01((9200 - age) / 700.0);
      _sadResident(canvas, t, math.min(fin, fout));
    }
  }

  void _drawFleeing(Canvas canvas, double t) {
    if (d.compact || d.eliminated || d.trashRatio < 0.9) return;
    for (var k = 0; k < 2; k++) {
      final prog = (t * 0.05 + k * 0.5) % 1.0;
      final x = 200 - prog * 300;
      const y = 266.0;
      final a =
      (prog < 0.1 ? prog / 0.1 : (prog > 0.9 ? (1 - prog) / 0.1 : 1.0));
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
      _p.color =
          (k == 0 ? const Color(0xFF8D6E63) : const Color(0xFF5C6BC0))
              .withValues(alpha: a);
      canvas.drawRect(Rect.fromLTWH(x - 11, y - 7, 8, 7), _p);
    }
  }

}

/// Truk sampah, pekerja, api.
extension KostPainterTruck on KostPainter {
  // ------------------------------------------------------ truk sampah
  //
  // Semua kendaraan digambar di "lapisan dunia" (di atas semua rumah) supaya
  // bisa melintasi batas rumah dan tidak tertutup bangunan tetangga. Truk
  // selalu MASUK dari luar layar dan KELUAR ke luar layar: tidak ada lagi
  // muncul / hilang mendadak. Mode satu rumah memakai jalur yang sama lewat
  // [_drawTruck]; mode jalan lewat [paintStreetTruck].


  /// Mode satu rumah. (Mode jalan: digambar oleh [paintStreetTruck].)
  void _drawTruck(Canvas canvas, double t) {
    if (_street) return;
    _truckLayer(canvas, t, _vl, _vr);
  }

  /// Dipanggil KostStreetPainter SETELAH semua rumah digambar.
  /// [view] = jangkauan layar dalam koordinat rumah ini. [thiefDx] = selisih
  /// posisi dunia rumah pembajak terhadap rumah ini (null bila tak diketahui).
  void paintStreetTruck(Canvas canvas, double t, Rect view,
      {double? thiefDx, bool thiefHauling = false}) {
    final sl = _vl, sr = _vr, st = _vt, sb = _vb;
    _street = true;
    _setView(view);
    _truckLayer(canvas, t, view.left, view.right,
        thiefDx: thiefDx, thiefHauling: thiefHauling);
    _vl = sl;
    _vr = sr;
    _vt = st;
    _vb = sb;
  }

  /// Id pembajak dari adegan bajak sisi KORBAN yang sedang aktif (atau null).
  String? activeHijackThief() {
    final f = _hijackFx();
    if (f == null || f.amount.round() == 1) return null;
    return f.peerId;
  }

  KostFx? _hijackFx() {
    KostFx? best;
    for (final f in d.fx) {
      if (f.type != FxType.hijack) continue;
      final a = f.age;
      final dur = f.durMs > 0 ? f.durMs : hijackDurationMs(1);
      if (a < 0 || a > dur) continue;
      if (best == null || a < best.age) best = f;
    }
    return best;
  }

  void _truckLayer(Canvas canvas, double t, double vl, double vr,
      {double? thiefDx, bool thiefHauling = false}) {
    _whTruckLayer(canvas, t, vl, vr);
    final hj = _hijackFx();
    final hp = d.haulProgress;
    if (hj != null) {
      final victim = hj.amount.round() != 1;
      if (victim) {
        // Korban: seluruh adegan (van datang, truk direbut, kabur ke rumah
        // pembajak) digambar dari sini; truk angkut biasa digantikan.
        _hijackWorld(
          canvas,
          t,
          hj,
          victimX: _parkX,
          thiefX: _parkX + (thiefDx ?? (_street ? -1400.0 : -1500.0)),
          vl: vl,
          vr: vr,
          thiefHauling: thiefHauling,
        );
        return;
      }
      // Pembajak: mode jalan sudah digambar oleh adegan rumah korban. Mode
      // satu rumah: gambar kedatangan truk rampasan dari arah korban.
      if (!_street) {
        _hijackWorld(
          canvas,
          t,
          hj,
          victimX: _parkX + 1500,
          thiefX: _parkX,
          vl: vl,
          vr: vr,
          thiefHauling: hp != null,
        );
      }
    }
    if (hp == null) return;
    _haulTruck(canvas, t, hp, vl, vr);
  }

  /// Siklus truk angkut (hp 0..1):
  ///  0.00-0.20  datang dari luar layar, melambat & mengerem (hidung menunduk)
  ///  0.20-0.28  parkir, pegas bodi reda, petugas turun dari bak belakang
  ///  0.28-0.76  bekerja: pungut -> lempar ke hopper -> pemadat bekerja
  ///  0.76-0.82  petugas naik lagi
  ///  0.82-1.00  siap jalan, tancap gas, melaju keluar layar (arah rute sama)
  void _haulTruck(Canvas canvas, double t, double hp, double vl, double vr) {
    const arriveEnd = 0.20;
    const leaveStart = 0.82;
    // Truk masuk dari kanan dan terus ke kiri: titik awal/akhir ada di luar
    // jangkauan layar (maks 1000 satuan agar kecepatan tetap wajar).
    final inX = math.min(math.max(vr + 110, _parkX + 220), _parkX + 1000);
    final outX = math.max(math.min(vl - 110, _parkX - 220), _parkX - 1000);
    // Kamera sangat jauh: ujung rute masih terlihat -> pudar, bukan pop.
    final inVisible = inX < vr + 40;
    final outVisible = outX > vl - 40;

    var x = _parkX;
    var alpha = 1.0;
    var lean = 0.0;
    var brake = false;
    var moving = false;

    if (hp < arriveEnd) {
      final u = hp / arriveEnd;
      x = _lerp(inX, _parkX, _easeOut3(u));
      if (inVisible) alpha = _ease(u / 0.3);
      brake = u > 0.45;
      lean = -0.035 * _ease((u - 0.5) / 0.45);
      moving = u < 0.93;
    } else if (hp < leaveStart) {
      final r = _c01((hp - arriveEnd) / 0.08);
      lean = -0.035 * math.exp(-r * 4) * math.cos(r * 10);
      brake = r < 0.5;
    } else {
      final u = (hp - leaveStart) / (1 - leaveStart);
      final go = _c01((u - 0.14) / 0.86);
      x = _lerp(_parkX, outX, _easeIn(go));
      if (outVisible) alpha = 1 - _ease((go - 0.7) / 0.3);
      lean = 0.03 * _ease(go / 0.2) * (1 - _ease((go - 0.2) / 0.4));
      moving = go > 0.02;
    }

    final vis = _ease((hp - 0.215) / 0.06) * (1 - _ease((hp - 0.755) / 0.06));
    final (double, double) lr = vis > 0.6 ? _workLid(t) : (0.0, 0.0);
    final bob = moving ? math.sin(t * 24) * 0.7 : math.sin(t * 38) * 0.22;

    _fadeLayer(
      canvas,
      Rect.fromLTRB(x - 130, _roadY - 90, x + 130, _roadY + 16),
      alpha,
          () {
        canvas.save();
        canvas.translate(x, _roadY);
        _truckBody(
          canvas,
          t,
          wheelA: x / 6.5,
          lean: lean,
          moving: moving,
          brake: brake,
          lid: lr.$1,
          ram: lr.$2,
          bob: bob,
        );
        canvas.restore();
      },
    );

    if (vis > 0.01) _workers(canvas, t, vis: vis);
  }

  /// (bukaan tutup hopper, gerak pelat pemadat) mengikuti ritme petugas.
  (double, double) _workLid(double t) {
    var lid = 0.0, ram = 0.0;
    for (var i = 0; i < 2; i++) {
      final ph = (t * 0.9 + i * 0.5) % 1.0;
      if (ph >= 0.5 && ph < 0.66) {
        lid = math.max(lid, math.sin((ph - 0.5) / 0.16 * math.pi));
      }
      if (ph >= 0.6 && ph < 0.86) {
        ram = math.max(ram, math.sin((ph - 0.6) / 0.26 * math.pi));
      }
    }
    return (lid, ram);
  }

  /// Gambar [draw] dengan transparansi [a] (tanpa layer bila a >= 1).
  void _fadeLayer(Canvas canvas, Rect bounds, double a, void Function() draw) {
    final al = _c01(a);
    if (al <= 0.02) return;
    if (al < 1) {
      canvas.saveLayer(bounds, Paint()..color = Color.fromRGBO(0, 0, 0, al));
    }
    draw();
    if (al < 1) canvas.restore();
  }

  /// Bodi truk sampah, titik asal = tengah bawah (di tanah), menghadap KIRI.
  /// Pemanggil mengatur translate / scale (mirror) dan transparansi.
  void _truckBody(
      Canvas canvas,
      double t, {
        double wheelA = 0,
        double lean = 0,
        bool moving = false,
        bool brake = false,
        double lid = 0,
        double ram = 0,
        bool stolen = false,
        bool thiefInCab = false,
        double bob = 0,
      }) {
    // bayangan menempel di tanah
    _p
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.25);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 88, height: 6), _p);

    canvas.save();
    canvas.translate(0, bob);
    canvas.rotate(lean);

    // sorot lampu depan
    _p.color = const Color(0xFFFFF59D).withValues(alpha: 0.22);
    canvas.drawPath(
      Path()
        ..moveTo(-40, -15)
        ..lineTo(-88, -3)
        ..lineTo(-88, -24)
        ..close(),
      _p,
    );

    // asap knalpot (kecil saat diam, tebal saat melaju)
    final puffs = moving ? 4 : 2;
    for (var k = 0; k < puffs; k++) {
      final ph = (t * (moving ? 1.6 : 0.8) + k / puffs) % 1.0;
      final base = stolen ? const Color(0xFF424242) : const Color(0xFFBDBDBD);
      _p.color = base.withValues(alpha: (1 - ph) * (moving ? 0.5 : 0.22));
      canvas.drawCircle(
          Offset(44 + ph * 24, -6 - ph * 10), 3 + ph * (moving ? 6.5 : 4), _p);
    }

    // bak
    _p.color = const Color(0xFF43A047);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-16, -36, 56, 30), const Radius.circular(3)),
      _p,
    );
    _p.color = Colors.white.withValues(alpha: 0.5);
    canvas.drawRect(const Rect.fromLTWH(-16, -22, 56, 4), _p);
    _p.color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(const Offset(12, -29), 3.6, _p);
    _p.color = const Color(0xFF2E7D32);
    canvas.drawCircle(const Offset(12, -29), 1.6, _p);

    // pelat pemadat bergeser saat memadatkan sampah
    if (ram > 0.01) {
      _p.color = const Color(0xFF1B5E20).withValues(alpha: 0.75);
      canvas.drawRect(Rect.fromLTWH(_lerp(31, 21, ram), -34, 3, 24), _p);
    }

    // hopper + tutupnya (engsel di sisi belakang)
    _p.color = const Color(0xFF2E5E3A);
    canvas.drawRect(const Rect.fromLTWH(32, -36, 8, 11), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF1B3B25);
    canvas.drawLine(const Offset(40, -36),
        Offset(40 - 8 * math.cos(lid), -36 - 8 * math.sin(lid)), _p);
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;

    // kabin
    _p.color = stolen ? const Color(0xFFB71C1C) : const Color(0xFF2E9E5B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-40, -30, 24, 24), const Radius.circular(4)),
      _p,
    );
    _p.color = const Color(0xFFB3E5FC);
    canvas.drawRect(const Rect.fromLTWH(-38, -27, 12, 10), _p);
    _p.color = Colors.white.withValues(alpha: 0.35);
    canvas.drawRect(const Rect.fromLTWH(-37, -26, 4, 8), _p);
    if (thiefInCab) {
      _p.color = const Color(0xFF212121);
      canvas.drawCircle(const Offset(-32, -22), 3.8, _p);
      _p.color = Colors.white;
      canvas.drawCircle(const Offset(-33.4, -22.5), 0.8, _p);
      canvas.drawCircle(const Offset(-30.6, -22.5), 0.8, _p);
    }
    _p.color = const Color(0xFF212121);
    canvas.drawRect(const Rect.fromLTWH(-42, -22, 3, 2), _p);
    _p.color = const Color(0xFFFFF176);
    canvas.drawRect(const Rect.fromLTWH(-41, -15, 3, 4), _p);

    // lampu rem belakang
    _p.color = brake ? const Color(0xFFFF1744) : const Color(0xFF8E1B1B);
    canvas.drawRect(const Rect.fromLTWH(40, -17, 2.5, 5), _p);
    if (brake) {
      _p.color = const Color(0xFFFF1744).withValues(alpha: 0.28);
      canvas.drawCircle(const Offset(43, -14.5), 6, _p);
    }

    // sirene: oranye saat dinas, strobo merah-biru saat dibajak
    if (stolen) {
      final blink = math.sin(t * 18) > 0;
      final c = blink ? const Color(0xFFFF1744) : const Color(0xFF2979FF);
      _p.color = c.withValues(alpha: 0.35);
      canvas.drawCircle(const Offset(-29, -33), 10, _p);
      _p.color = c;
      canvas.drawRect(const Rect.fromLTWH(-32, -33, 6, 3), _p);
    } else {
      final siren = 0.5 + 0.5 * math.sin(t * 14);
      _p.color = const Color(0xFFFFA000).withValues(alpha: 0.3 + 0.5 * siren);
      canvas.drawCircle(const Offset(-29, -33), 6 + siren * 4, _p);
      _p.color = const Color(0xFFFFCA28);
      canvas.drawRect(const Rect.fromLTWH(-32, -33, 6, 3), _p);
    }

    // roda (berputar sesuai jarak tempuh)
    for (final wx in const [-26.0, 18.0]) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF212121);
      canvas.drawCircle(Offset(wx, -6), 6.5, _p);
      _p.color = const Color(0xFF9E9E9E);
      canvas.drawCircle(Offset(wx, -6), 2.6, _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.butt
        ..color = const Color(0xFF9E9E9E);
      for (var s = 0; s < 2; s++) {
        final a = wheelA + s * math.pi / 2;
        canvas.drawLine(
          Offset(wx + math.cos(a) * 5.2, -6 + math.sin(a) * 5.2),
          Offset(wx - math.cos(a) * 5.2, -6 - math.sin(a) * 5.2),
          _p,
        );
      }
      _p.style = PaintingStyle.fill;
    }
    canvas.restore();
  }

  /// Dua petugas angkut. [vis] 0..1: keluar/masuk lewat bak belakang truk
  /// (muncul sambil berjalan, bukan tiba-tiba). [freezeT] membekukan langkah
  /// pada waktu tertentu, [shock] = pose kaget, [idle] = tak membawa kantong,
  /// [dx] = pergeseran (berjalan menjauh), [alpha] = pudar.
  void _workers(
      Canvas canvas,
      double t, {
        double vis = 1,
        double alpha = 1,
        double? freezeT,
        double shock = 0,
        bool idle = false,
        double dx = 0,
      }) {
    final a = vis * alpha;
    if (a <= 0.02) return;
    final tt = freezeT ?? t;
    for (var i = 0; i < 2; i++) {
      final phase = (tt * 0.9 + i * 0.5) % 1.0;
      final tri = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
      final baseX = _lerp(_parkX + 64, _parkX + 34, tri) + dx;
      final x = vis < 1 ? _lerp(_parkX + 38, baseX, vis) : baseX;
      const y = 270.0;
      final carrying = !idle && phase < 0.5;
      final swing = shock > 0.05
          ? math.sin(t * 22 + i) * 2.5 * shock
          : (idle ? 0.0 : math.sin(tt * 10 + i) * 2);

      if (a < 1) {
        canvas.saveLayer(
          Rect.fromCenter(center: Offset(x, y - 14), width: 56, height: 60),
          Paint()..color = Color.fromRGBO(0, 0, 0, _c01(a)),
        );
      }

      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFF37474F);
      canvas.drawLine(Offset(x, y - 11), Offset(x, y - 4), _p);
      canvas.drawLine(Offset(x, y - 4), Offset(x - swing, y), _p);
      canvas.drawLine(Offset(x, y - 4), Offset(x + swing, y), _p);
      _p.color = const Color(0xFFFF8F00);
      if (shock > 0.2) {
        canvas.drawLine(Offset(x, y - 10), Offset(x - 4, y - 17), _p);
        canvas.drawLine(Offset(x, y - 10), Offset(x + 4, y - 17), _p);
      } else {
        canvas.drawLine(
            Offset(x, y - 10), Offset(x + (carrying ? 4 : 3), y - 15), _p);
      }
      _p.style = PaintingStyle.fill;
      _p.color = const Color(0xFFE0AC84);
      canvas.drawCircle(Offset(x, y - 14), 3, _p);
      _p.color = const Color(0xFFFF8F00);
      canvas.drawRect(Rect.fromLTWH(x - 3.5, y - 18, 7, 2.5), _p);

      if (shock > 0.2) {
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = const Color(0xFFFF5252).withValues(alpha: _c01(shock));
        canvas.drawLine(Offset(x, y - 31), Offset(x, y - 25), _p);
        _p.style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y - 22.5), 1.1, _p);
      }

      if (carrying) {
        // mengangkat kantong dari tumpukan
        final lift = _ease(phase / 0.08);
        _bag(canvas, Offset(x + 4, _lerp(y - 5, y - 20, lift)), 900 + i,
            scale: 0.7);
      } else if (!idle && phase >= 0.5 && phase < 0.64) {
        // melempar kantong ke mulut hopper (tidak lenyap begitu saja)
        final q = (phase - 0.5) / 0.14;
        _bag(
          canvas,
          Offset(
            _lerp(x + 4, _parkX + 35, q),
            _lerp(y - 20, 263, q) - math.sin(q * math.pi) * 9,
          ),
          900 + i,
          scale: 0.7 * (1 - 0.4 * q),
        );
      }

      if (a < 1) canvas.restore();
    }
  }

  // ------------------------------------------------------------- api

  void _drawFire(Canvas canvas, double t) {
    final burnP = _fxProgress(FxType.burn, 4500);

    if (burnP != null) {
      final env = burnP < 0.12
          ? burnP / 0.12
          : (burnP > 0.8 ? (1 - burnP) / 0.2 : 1.0);
      final e = _c01(env);

      for (final cx in const [350.0, 50.0]) {
        _p
          ..style = PaintingStyle.fill
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFF5722).withValues(alpha: 0.55 * e),
              const Color(0xFFFF9800).withValues(alpha: 0.22 * e),
              const Color(0xFFFF9800).withValues(alpha: 0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(cx, 236), radius: 85));
        canvas.drawCircle(Offset(cx, 236), 85, _p);
        _p.shader = null;
      }

      for (var side = 0; side < 2; side++) {
        for (var k = 0; k < 7; k++) {
          final bx = 318.0 + k * 10;
          final x = side == 0 ? bx : _w - bx;
          final h = (16 + _hh(k + side * 7) % 14) * (0.6 + 0.4 * e) * e;
          _flame(canvas, x, 252 - (_hh(k) % 3) * 7.0, h, t, k + side * 6);
        }
      }

      _p.style = PaintingStyle.fill;
      for (var k = 0; k < 22; k++) {
        final ph = (t * 0.85 + k * 0.045) % 1.0;
        final base = k % 2 == 0 ? 350.0 : 50.0;
        final x = base + math.sin(k * 3.1 + ph * 7) * 28;
        final y = 244 - ph * 115;
        _p.color = const Color(0xFFFFD54F).withValues(alpha: (1 - ph) * e);
        canvas.drawCircle(Offset(x, y), 1.4, _p);
      }

      for (var k = 0; k < 14; k++) {
        final phase = (t * 0.28 + k * 0.07) % 1.0;
        final base = k % 2 == 0 ? 348.0 : 52.0;
        final x = base + math.sin(phase * 5 + k) * 10 + phase * 30;
        final y = 238 - phase * 165;
        _p.color =
            const Color(0xFF212121).withValues(alpha: (1 - phase) * 0.62 * e);
        canvas.drawCircle(Offset(x, y), 7 + phase * 22, _p);
      }

      if (burnP < 0.65) {
        final q = burnP / 0.65;
        _drawBannerText(
          canvas,
          'BAKAR SAMPAH! +POLUSI',
          Offset(200, _roofY - 30 - q * 24),
          const Color(0xFFFF8A65),
          scale: 1.0 + math.sin(q * math.pi) * 0.2,
          alpha: 1 - q,
        );
      }
    } else if (d.burnPenalty && !d.eliminated) {
      for (var k = 0; k < 3; k++) {
        final phase = (t * 0.2 + k * 0.33) % 1.0;
        _p
          ..style = PaintingStyle.fill
          ..color =
          const Color(0xFF616161).withValues(alpha: (1 - phase) * 0.28);
        canvas.drawCircle(
          Offset(
              350 + math.sin(phase * 4 + k) * 6 + phase * 14, 236 - phase * 70),
          4 + phase * 9,
          _p,
        );
      }
    }
  }

  void _flame(Canvas canvas, double x, double y, double h, double t, int k) {
    if (h <= 0.5) return;
    final w = h * 0.55;
    final flick = math.sin(t * 16 + k) * 0.22;
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFF3D00).withValues(alpha: 0.92);
    canvas.drawPath(
      Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x - w, y - h * 0.35, x + flick * w, y - h)
        ..quadraticBezierTo(x + w, y - h * 0.35, x, y),
      _p,
    );
    _p.color = const Color(0xFFFFAB00).withValues(alpha: 0.95);
    canvas.drawPath(
      Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x - w * 0.65, y - h * 0.3,
            x + flick * w * 0.65, y - h * 0.78)
        ..quadraticBezierTo(x + w * 0.65, y - h * 0.3, x, y),
      _p,
    );
    _p.color = const Color(0xFFFFF59D).withValues(alpha: 0.95);
    canvas.drawPath(
      Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x - w * 0.35, y - h * 0.2,
            x + flick * w * 0.35, y - h * 0.45)
        ..quadraticBezierTo(x + w * 0.35, y - h * 0.2, x, y),
      _p,
    );
  }

  void _drawCollapse(Canvas canvas) {
    final cp = _fxProgress(FxType.collapse, 1500);
    if (cp == null) return;
    for (var k = 0; k < 9; k++) {
      final x = 110.0 + k * 24;
      final y = _gy - cp * 70 * (0.5 + (k % 3) * 0.3);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF9E9E9E).withValues(alpha: (1 - cp) * 0.6);
      canvas.drawCircle(Offset(x, y), 12 + cp * 26, _p);
    }
  }

}

/// Renovasi: tambah kamar/lantai, derek, tukang.
extension KostPainterRenovation on KostPainter {
  // ======================================================================
  //  RENOVASI
  //  - Tambah kamar : perancah + tukang (bata -> plester -> cat -> jadi)
  //  - Tambah lantai: atap diangkat derek, rangka beton tumbuh, dinding naik,
  //                   lalu atap diturunkan kembali (debu & guncangan)
  // ======================================================================

  /// Kamar baru yang dibangun adalah kamar pertama di lantai berikutnya.
  bool get _isFloorBuild {
    final n = d.rooms - 1;
    return n > 0 && n % 4 == 0 && n < 12;
  }

  int get _buildDurMs => _isFloorBuild ? 5200 : 2600;
  double? get _buildP => _fxProgress(FxType.build, _buildDurMs);


  /// Selisih tinggi atap (relatif posisi akhir) selama tambah lantai.
  double _roofDy(double fp) {
    if (fp < 0.05) return _fh;
    if (fp < 0.17) return _lerp(_fh, -_roofHover, _ease((fp - 0.05) / 0.12));
    if (fp < 0.72) return -_roofHover;
    if (fp < 0.85) {
      final u = (fp - 0.72) / 0.13;
      return _lerp(-_roofHover, 0, u * u);
    }
    final u = (fp - 0.85) / 0.09;
    if (u >= 1) return 0;
    return -3.2 * (1 - u) * math.sin(u * math.pi * 2.5).abs();
  }

  /// Ayunan atap yang tergantung di kait derek (radian).
  double _roofSway(double fp, double t) {
    if (fp < 0.05 || fp >= 0.85) return 0;
    final amp = math.min(1.0, (fp - 0.05) / 0.08) *
        math.min(1.0, (0.85 - fp) / 0.10);
    return math.sin(t * 2.3) * 0.03 * amp;
  }

  /// Titik pada atap (koordinat akhir) setelah terangkat & berayun.
  Offset _roofPt(Offset local, double fp, double t) {
    final dy = _roofDy(fp);
    final sw = _roofSway(fp, t);
    final pivot = Offset(200, _roofY - 90);
    final p = Offset(local.dx, local.dy + dy) - pivot;
    final c = math.cos(sw), s = math.sin(sw);
    return pivot + Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c);
  }

  void _sparkle(Canvas canvas, Offset c, double r, Color col, double rot) {
    if (r <= 0.2) return;
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final rr = i.isEven ? r : r * 0.28;
      final a = rot - math.pi / 2 + i * math.pi / 4;
      final x = c.dx + math.cos(a) * rr;
      final y = c.dy + math.sin(a) * rr;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    _p
      ..style = PaintingStyle.fill
      ..color = col;
    canvas.drawPath(path, _p);
  }

  // ------------------------------------------------ kamar sedang direnovasi

  /// Dinding bata yang naik lapis demi lapis (jendela tetap dibiarkan terbuka).
  void _renovBrickWall(Canvas canvas, Rect r, double frac, int idx) {
    final wall =
    Rect.fromLTRB(r.left + 3.5, r.top + 3, r.right - 3.5, r.bottom - 3);
    final topY = wall.bottom - wall.height * frac;
    final win = Rect.fromLTWH(r.left + 9, r.top + 9, r.width - 18, 26);
    canvas.save();
    canvas.clipPath(Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTRB(wall.left, topY, wall.right, wall.bottom)),
      Path()..addRect(win.inflate(1.4)),
    ));
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFB4654A);
    canvas.drawRect(wall, _p);
    const bh = 4.2;
    var row = 0;
    for (var y = wall.bottom; y > topY - bh; y -= bh, row++) {
      for (var x = wall.left + (row.isOdd ? 4.0 : 0.0); x < wall.right; x += 8) {
        final tone = _hh(idx * 131 + row * 17 + x.toInt()) % 5;
        _p.color = tone == 0
            ? const Color(0xFF9E5540)
            : (tone == 1 ? const Color(0xFFC77455) : const Color(0xFFB4654A));
        canvas.drawRect(Rect.fromLTWH(x + 0.4, y - bh + 0.4, 7.2, bh - 0.8), _p);
      }
    }
    canvas.restore();
    // adukan basah di barisan teratas
    if (frac < 1) {
      _p.color = const Color(0xFF9E9E9E);
      canvas.drawRect(
          Rect.fromLTWH(wall.left, topY - 1.4, wall.width, 2.0), _p);
    }
  }

  /// Tahap akhir: plester kelabu menyapu -> cat/tampilan kamar jadi menyapu ->
  /// jendela berkilau. Sama dipakai tambah kamar & tambah lantai.
  void _renovFinish(Canvas canvas, Rect r, int idx, double t,
      {required double plaster, required double paint, required double fin}) {
    final win = Rect.fromLTWH(r.left + 9, r.top + 9, r.width - 18, 26);
    if (plaster > 0) {
      final x = math.min(r.left + r.width * plaster, r.right - 3.5);
      canvas.save();
      canvas.clipPath(Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTRB(r.left + 3.5, r.top + 3, x, r.bottom - 3)),
        Path()..addRect(win.inflate(1.4)),
      ));
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFCFC9BD);
      canvas.drawRect(r, _p);
      _p.color = Colors.white.withValues(alpha: 0.2);
      for (var k = 0; k < 4; k++) {
        canvas.drawRect(
            Rect.fromLTWH(r.left + 4, r.top + 8 + k * 9.0, r.width - 8, 2.2), _p);
      }
      canvas.restore();
    }
    if (paint > 0) {
      final x = r.left + (r.width + 2) * paint;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(r.left - 1, r.top - 1, x, r.bottom + 1));
      _drawRoom(canvas, r, idx, t);
      canvas.restore();
      if (paint < 1) {
        _p
          ..style = PaintingStyle.fill
          ..color = Colors.white.withValues(alpha: 0.32);
        canvas.drawRect(Rect.fromLTWH(x - 3, r.top, 3, r.height), _p);
      }
    }
    if (fin > 0 && fin < 1) {
      final a = math.sin(fin * math.pi);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFF59D).withValues(alpha: a * 0.28);
      canvas.drawRect(win.inflate(4), _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFEA00).withValues(alpha: a * 0.8);
      canvas.drawRect(r.inflate(1.5), _p);
      _p.style = PaintingStyle.fill;
      final sc = const Color(0xFFFFFDE7).withValues(alpha: a);
      _sparkle(canvas, win.topLeft + const Offset(4, 4), 5 * a, sc, fin * 2);
      _sparkle(canvas, win.topRight + const Offset(-5, 6), 4 * a, sc, -fin * 2);
      _sparkle(canvas, win.center + const Offset(2, 3), 3.2 * a, sc, fin);
    }
  }

  /// Kamar baru (lantai yang sama): rangka mentah -> bata -> plester -> cat.
  void _drawRoomUnderRenovation(
      Canvas canvas, Rect r, int idx, double t, double p) {
    final pulse = (p > 0.72 && p < 0.88)
        ? 0.035 * math.sin((p - 0.72) / 0.16 * math.pi)
        : 0.0;
    canvas.save();
    if (pulse != 0) {
      canvas.translate(r.center.dx, r.bottom);
      canvas.scale(1 + pulse, 1 + pulse * 1.4);
      canvas.translate(-r.center.dx, -r.bottom);
    }
    _emptyShell(canvas, r, idx, t);
    if (p < 0.12) _scaffold(canvas, r);
    final brick = _ease(_c01((p - 0.08) / 0.30));
    if (brick > 0) _renovBrickWall(canvas, r, brick, idx);
    _renovFinish(
      canvas,
      r,
      idx,
      t,
      plaster: _ease(_c01((p - 0.38) / 0.12)),
      paint: _ease(_c01((p - 0.50) / 0.22)),
      fin: _c01((p - 0.72) / 0.16),
    );
    canvas.restore();
  }

  // ----------------------------------------------- lantai baru dibangun

  /// Satu sel di lantai baru: kolom beton tumbuh, balok menyusul, dinding naik
  /// dari bawah; kamar baru lalu diplester & dicat. Keadaan akhirnya identik
  /// dengan gambar normal (kamar jadi / rangka mentah).
  void _newFloorCell(Canvas canvas, Rect r, int idx, double t, double fp) {
    final col = idx % 4;
    final newest = idx == d.rooms - 1;
    final wallP = _ease(_c01((fp - 0.38) / 0.20));
    if (wallP > 0) {
      canvas.save();
      canvas.clipRect(
          Rect.fromLTRB(r.left, r.bottom - r.height * wallP, r.right, r.bottom));
      _emptyShell(canvas, r, idx, t);
      canvas.restore();
      if (wallP < 1) {
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF9E9E9E);
        canvas.drawRect(
            Rect.fromLTWH(
                r.left + 4, r.bottom - r.height * wallP - 1.6, r.width - 8, 2.2),
            _p);
      }
    }
    if (newest) {
      _renovFinish(
        canvas,
        r,
        idx,
        t,
        plaster: _ease(_c01((fp - 0.58) / 0.07)),
        paint: _ease(_c01((fp - 0.64) / 0.10)),
        fin: _c01((fp - 0.74) / 0.12),
      );
    }
    // kolom beton tumbuh + besi tulangan
    final cp = _ease(_c01((fp - 0.17 - col * 0.028) / 0.15));
    if (cp > 0) {
      for (final cx in [r.left, r.right - 4.0]) {
        final h = r.height * cp;
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFB5B2AB);
        canvas.drawRect(Rect.fromLTWH(cx, r.bottom - h, 4, h), _p);
        _p.color = Colors.black.withValues(alpha: 0.18);
        canvas.drawRect(
            Rect.fromLTWH(cx + (cx == r.left ? 3.2 : 0), r.bottom - h, 0.8, h), _p);
        if (cp < 1) {
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9
            ..color = const Color(0xFF6D4C41);
          canvas.drawLine(Offset(cx + 1, r.bottom - h - 7),
              Offset(cx + 1, r.bottom - h), _p);
          canvas.drawLine(Offset(cx + 3, r.bottom - h - 5),
              Offset(cx + 3, r.bottom - h), _p);
          _p.style = PaintingStyle.fill;
        }
      }
    }
    // balok/pelat atas menyusul dari kiri ke kanan
    final slab = _ease(_c01((fp - 0.30 - col * 0.025) / 0.10));
    if (slab > 0 && cp > 0.9) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF7A7A7A);
      canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width * slab, 3.2), _p);
    }
  }

  // -------------------------------------------------- peralatan & tukang

  /// Perancah pipa baja: tiang, palang silang, dek papan, pagar & jaring.
  void _scaffoldRig(
      Canvas canvas, double xL, double xR, double yTop, double deckY) {
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFB0BEC5);
    canvas.drawLine(Offset(xL, _gy), Offset(xL, yTop), _p);
    canvas.drawLine(Offset(xR, _gy), Offset(xR, yTop), _p);
    _p.strokeWidth = 1.0;
    for (var y = _gy; y - _fh >= yTop - 1; y -= _fh) {
      final up = ((_gy - y) / _fh).round().isEven;
      canvas.drawLine(Offset(xL, up ? y : y - _fh), Offset(xR, up ? y - _fh : y), _p);
      canvas.drawLine(Offset(xL, y), Offset(xR, y), _p);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFF8F00);
      canvas.drawCircle(Offset(xL, y), 1.5, _p);
      canvas.drawCircle(Offset(xR, y), 1.5, _p);
      _p
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFFB0BEC5);
    }
    _p.style = PaintingStyle.fill;
    if (deckY < _gy - 2) {
      // jaring pengaman
      _p.color = const Color(0xFF43A047).withValues(alpha: 0.16);
      canvas.drawRect(Rect.fromLTRB(xL, deckY - 17, xR, deckY), _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = const Color(0xFF2E7D32).withValues(alpha: 0.35);
      for (var x = xL + 5; x < xR; x += 5) {
        canvas.drawLine(Offset(x, deckY - 17), Offset(x, deckY), _p);
      }
      for (var y = deckY - 13; y < deckY; y += 4) {
        canvas.drawLine(Offset(xL, y), Offset(xR, y), _p);
      }
      _p
        ..strokeWidth = 1.1
        ..color = const Color(0xFFB0BEC5);
      canvas.drawLine(Offset(xL, deckY - 17), Offset(xR, deckY - 17), _p);
      // dek papan kayu
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF8D6E4B);
      canvas.drawRect(Rect.fromLTRB(xL - 3, deckY, xR + 3, deckY + 3.2), _p);
      _p
        ..color = const Color(0xFF5D4037)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6;
      for (var x = xL; x < xR; x += 9) {
        canvas.drawLine(Offset(x, deckY), Offset(x, deckY + 3.2), _p);
      }
      _p.style = PaintingStyle.fill;
    }
  }

  /// Katrol material: ember bata naik-turun dari tanah ke dek kerja.
  void _hoist(Canvas canvas, double x, double topY, double deckTop, double t) {
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF90A4AE);
    canvas.drawLine(Offset(x - 10, topY + 3), Offset(x, topY + 3), _p);
    canvas.drawLine(Offset(x - 10, topY + 3), Offset(x - 10, topY + 9), _p);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF455A64);
    canvas.drawCircle(Offset(x, topY + 3), 3, _p);
    final u = (t * 0.45) % 1.0;
    final k = u < 0.5 ? _ease(u / 0.5) : 1 - _ease((u - 0.5) / 0.5);
    final by = _lerp(_gy - 9, deckTop, k);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = const Color(0xFF212121);
    canvas.drawLine(Offset(x, topY + 6), Offset(x, by - 5), _p);
    canvas.drawLine(Offset(x - 10, topY + 9), Offset(x - 5, by - 3), _p);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF78909C);
    canvas.drawPath(
      Path()
        ..moveTo(x - 6, by - 4)
        ..lineTo(x + 6, by - 4)
        ..lineTo(x + 4.5, by + 4)
        ..lineTo(x - 4.5, by + 4)
        ..close(),
      _p,
    );
    if (u < 0.5) {
      _p.color = const Color(0xFFB4654A);
      canvas.drawRect(Rect.fromLTWH(x - 4.5, by - 7, 9, 3.4), _p);
    }
  }

  /// Tukang berhelm: 0 = diam, 1 = bata, 2 = sendok plester, 3 = rol cat,
  /// 4 = palu. [arm] sudut lengan (rad, 0 = lurus ke depan, negatif = ke atas).
  void _worker(Canvas canvas, Offset foot, double dir,
      {double arm = 0.7,
        int tool = 0,
        bool cheer = false,
        double t = 0,
        Color vest = const Color(0xFFFF8F00)}) {
    canvas.save();
    canvas.translate(foot.dx, foot.dy);
    canvas.scale(dir, 1);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF37474F);
    canvas.drawRect(const Rect.fromLTWH(-3.2, -6, 2.6, 6), _p);
    canvas.drawRect(const Rect.fromLTWH(0.6, -6, 2.6, 6), _p);
    _p.color = const Color(0xFF212121);
    canvas.drawRect(const Rect.fromLTWH(-3.6, -1.4, 3.4, 1.4), _p);
    canvas.drawRect(const Rect.fromLTWH(0.6, -1.4, 3.4, 1.4), _p);
    _p.color = vest;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3.6, -14, 7.2, 8.4), const Radius.circular(1.6)),
      _p,
    );
    _p.color = Colors.white.withValues(alpha: 0.8);
    canvas.drawRect(const Rect.fromLTWH(-3.6, -10.5, 7.2, 1.2), _p);
    _p.color = const Color(0xFFFFCCBC);
    canvas.drawCircle(const Offset(0.4, -17.2), 3.0, _p);
    _p.color = const Color(0xFFFFD600);
    canvas.drawArc(
        Rect.fromCircle(center: const Offset(0.4, -17.6), radius: 3.5),
        math.pi,
        math.pi,
        true,
        _p);
    canvas.drawRect(const Rect.fromLTWH(-3.8, -17.8, 8.6, 1.1), _p);

    final ang = cheer ? -2.35 + math.sin(t * 12) * 0.35 : arm;
    canvas.save();
    canvas.translate(0.5, -12.6);
    canvas.rotate(ang);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round
      ..color = vest;
    canvas.drawLine(Offset.zero, const Offset(6.5, 0), _p);
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xFFFFCCBC);
    canvas.drawCircle(const Offset(6.5, 0), 1.5, _p);
    if (!cheer) {
      switch (tool) {
        case 1:
          _p.color = const Color(0xFFB4654A);
          canvas.drawRect(const Rect.fromLTWH(6.0, -2.6, 3.8, 2.4), _p);
          break;
        case 2:
          _p.color = const Color(0xFF6D4C41);
          canvas.drawRect(const Rect.fromLTWH(6.0, -0.6, 2.6, 1.2), _p);
          _p.color = const Color(0xFFCFD8DC);
          canvas.drawPath(
            Path()
              ..moveTo(8.4, -1.6)
              ..lineTo(12.4, 0)
              ..lineTo(8.4, 1.6)
              ..close(),
            _p,
          );
          break;
        case 3:
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9
            ..color = const Color(0xFF616161);
          canvas.drawLine(const Offset(6.5, 0), const Offset(9, -1.5), _p);
          _p
            ..style = PaintingStyle.fill
            ..color = _mix(d.wall, Colors.white, 0.25);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(8.2, -7.2, 3.2, 7.4), const Radius.circular(1.4)),
            _p,
          );
          break;
        case 4:
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = const Color(0xFF8D6E63);
          canvas.drawLine(const Offset(6.5, 0), const Offset(11, -3), _p);
          _p
            ..style = PaintingStyle.fill
            ..color = const Color(0xFF455A64);
          canvas.drawRect(const Rect.fromLTWH(9.6, -5.4, 4, 3), _p);
          break;
        default:
          break;
      }
    }
    canvas.restore();
    canvas.restore();
  }

  /// Debu halus yang naik dari titik kerja.
  void _siteDust(Canvas canvas, Offset o, double t, double k) {
    if (k <= 0) return;
    for (var i = 0; i < 4; i++) {
      final ph = (t * 1.1 + i * 0.25) % 1.0;
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFD7CCC8).withValues(alpha: 0.42 * k * (1 - ph));
      canvas.drawCircle(
          o + Offset(math.sin(i * 2.3 + ph * 3) * 7, -ph * 14), 2.5 + ph * 4, _p);
    }
  }

  /// Perlengkapan proyek di tanah: gerobak, tumpukan bata, pasir, semen, kerucut.
  void _siteProps(Canvas canvas, double t, bool big) {
    // tumpukan bata
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFB4654A);
    final bx = big ? 60.0 : 70.0;
    for (var row = 0; row < 3; row++) {
      canvas.drawRect(
          Rect.fromLTWH(bx + row * 1.5, _gy - 4 - row * 3.6, 22 - row * 3, 3.4), _p);
    }
    _p.color = const Color(0xFFE6DCCB).withValues(alpha: 0.7);
    for (var row = 0; row < 3; row++) {
      canvas.drawRect(
          Rect.fromLTWH(bx + row * 1.5, _gy - 4 - row * 3.6 + 1.6, 22 - row * 3, 0.5),
          _p);
    }
    // gerobak dorong
    final gx = bx - 26;
    _p.color = const Color(0xFFFB8C00);
    canvas.drawPath(
      Path()
        ..moveTo(gx, _gy - 11)
        ..lineTo(gx + 17, _gy - 11)
        ..lineTo(gx + 14, _gy - 4)
        ..lineTo(gx + 3, _gy - 4)
        ..close(),
      _p,
    );
    _p.color = const Color(0xFFC9B79C);
    canvas.drawOval(Rect.fromLTWH(gx + 2, _gy - 14, 13, 5), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF6D4C41);
    canvas.drawLine(Offset(gx + 14, _gy - 8), Offset(gx + 24, _gy - 14), _p);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF212121);
    canvas.drawCircle(Offset(gx + 6, _gy - 2.6), 2.6, _p);

    // pasir, kantong semen, kerucut pengaman (kanan)
    final rx = big ? 312.0 : 306.0;
    _p.color = const Color(0xFFD7C08A);
    canvas.drawPath(
      Path()
        ..moveTo(rx, _gy)
        ..quadraticBezierTo(rx + 12, _gy - 20, rx + 26, _gy)
        ..close(),
      _p,
    );
    _p.color = const Color(0xFFD7CCC8);
    canvas.drawRect(Rect.fromLTWH(rx + 30, _gy - 6, 12, 6), _p);
    canvas.drawRect(Rect.fromLTWH(rx + 32, _gy - 11.5, 10, 5.5), _p);
    _p.color = const Color(0xFF8D6E63);
    canvas.drawRect(Rect.fromLTWH(rx + 34, _gy - 4.4, 5, 1.4), _p);
    for (final cx in [_bl - 16.0, _bl + 206.0]) {
      _p.color = const Color(0xFFFF6D00);
      canvas.drawPath(
        Path()
          ..moveTo(cx - 4.5, _gy)
          ..lineTo(cx + 4.5, _gy)
          ..lineTo(cx + 1.4, _gy - 11)
          ..lineTo(cx - 1.4, _gy - 11)
          ..close(),
        _p,
      );
      _p.color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(cx - 3, _gy - 6, 6, 1.8), _p);
    }
  }

  // -------------------------------------------------------- tambah kamar

  void _drawRoomSite(Canvas canvas, double t, double p) {
    final idx = math.max(0, d.rooms - 1);
    final r = _cell(idx);
    final sa = _c01(p / 0.06) * (1 - _ease(_c01((p - 0.80) / 0.12)));
    if (sa > 0.01) {
      canvas.saveLayer(_view, Paint()..color = Color.fromRGBO(0, 0, 0, sa));
      _siteProps(canvas, t, false);
      _scaffoldRig(canvas, r.left - 5, r.right + 5, r.top - 8, r.bottom);
      if (r.bottom < _gy - 20) {
        _hoist(canvas, r.right + 11, r.top - 6, r.bottom - 9, t);
      }
      if (!d.compact) _roomCrew(canvas, r, t, p);
      canvas.restore();
    }

    // debu di titik kerja
    final brick = _ease(_c01((p - 0.08) / 0.30));
    if (p > 0.08 && p < 0.38) {
      _siteDust(canvas,
          Offset(r.center.dx, r.bottom - 3 - (r.height - 6) * brick), t, 1);
    } else if (p >= 0.38 && p < 0.72) {
      final edge = p < 0.50
          ? r.left + r.width * _ease(_c01((p - 0.38) / 0.12))
          : r.left + r.width * _ease(_c01((p - 0.50) / 0.22));
      _siteDust(canvas, Offset(edge, r.center.dy), t, p < 0.50 ? 1 : 0.5);
    }

    if (p > 0.76) {
      final q = _c01((p - 0.76) / 0.24);
      _drawBannerText(
        canvas,
        'KAMAR BARU! +INCOME',
        Offset(r.center.dx, r.top - 10 - q * 28),
        const Color(0xFFFFEE58),
        scale: 0.95 + math.sin(q * math.pi) * 0.25,
        alpha: 1 - q,
      );
    }
  }

  void _roomCrew(Canvas canvas, Rect r, double t, double p) {
    final foot = r.bottom - 0.5;
    final cheer = p > 0.76;
    final plasterP = _ease(_c01((p - 0.38) / 0.12));
    final paintP = _ease(_c01((p - 0.50) / 0.22));

    // tumpukan bata di dek selama pemasangan
    if (p < 0.42) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFB4654A);
      canvas.drawRect(Rect.fromLTWH(r.left + 26, foot - 3.4, 9, 3.4), _p);
      canvas.drawRect(Rect.fromLTWH(r.left + 27, foot - 6.8, 7, 3.4), _p);
    }

    // tukang utama: bata -> plester -> cat -> bersorak
    if (cheer) {
      _worker(canvas, Offset(r.left + 14, foot), 1, cheer: true, t: t);
    } else if (p < 0.38) {
      _worker(canvas, Offset(r.left + 13, foot), 1,
          arm: -0.2 + math.sin(t * 7) * 0.5, tool: 1);
    } else if (p < 0.50) {
      final x = r.left + 6 + (r.width - 12) * plasterP;
      _worker(canvas, Offset(x, foot), 1,
          arm: -0.55 + math.sin(t * 6) * 0.4, tool: 2);
    } else {
      final x = r.left + 5 + (r.width - 10) * paintP;
      _worker(canvas, Offset(x, foot), 1,
          arm: -0.7 + math.sin(t * 5) * 0.55, tool: 3);
    }

    // pembantu di sisi kanan: memalu bekisting / mengaduk lalu bersorak
    if (cheer) {
      _worker(canvas, Offset(r.right - 9, foot), -1,
          cheer: true, t: t + 0.4, vest: const Color(0xFF00ACC1));
    } else {
      final swing = math.sin(t * 9);
      _worker(canvas, Offset(r.right - 9, foot), -1,
          arm: p < 0.5 ? -1.0 + swing.abs() * 1.4 : 0.6,
          tool: p < 0.5 ? 4 : 0,
          vest: const Color(0xFF00ACC1));
      if (p < 0.5 && swing > 0.92) {
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = const Color(0xFFFFEE58);
        final o = Offset(r.right - 18, foot - 9);
        canvas.drawLine(o, o + const Offset(-3, -2), _p);
        canvas.drawLine(o, o + const Offset(-3, 1.5), _p);
        _p.style = PaintingStyle.fill;
      }
    }
  }

  // ------------------------------------------------------- tambah lantai

  void _towerCrane(Canvas canvas, double t, double p, double mastTop) {
    const yellow = Color(0xFFFBC02D);
    _p
      ..style = PaintingStyle.fill
      ..color = yellow;
    canvas.drawRect(Rect.fromLTWH(92, mastTop, 6, _gy - mastTop), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF5D4037);
    for (var y = mastTop; y < _gy - 8; y += 9) {
      canvas.drawLine(Offset(92, y), Offset(98, y + 9), _p);
    }
    // jib + jib belakang + penahan
    _p
      ..style = PaintingStyle.fill
      ..color = yellow;
    canvas.drawRect(Rect.fromLTWH(60, mastTop, 252, 4.5), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF5D4037);
    canvas.drawLine(Offset(95, mastTop - 22),
        Offset(310, mastTop), _p);
    canvas.drawLine(Offset(95, mastTop - 22),
        Offset(62, mastTop), _p);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF616161);
    canvas.drawRect(Rect.fromLTWH(60, mastTop + 4.5, 16, 10), _p);
    _p.color = const Color(0xFF424242);
    canvas.drawRect(Rect.fromLTWH(62, mastTop + 5, 12, 3), _p);
    // kabin operator + lampu peringatan
    _p.color = const Color(0xFFFFCA28);
    canvas.drawRect(Rect.fromLTWH(99, mastTop - 10, 12, 10), _p);
    _p.color = const Color(0xFFB3E5FC);
    canvas.drawRect(Rect.fromLTWH(101, mastTop - 8, 6, 5), _p);
    final blink = math.sin(t * 6) > 0 ? 1.0 : 0.25;
    _p.color = const Color(0xFFFF1744).withValues(alpha: blink);
    canvas.drawCircle(Offset(95, mastTop - 24), 2.2, _p);

    // troli & kait
    const hx = 200.0;
    _p.color = const Color(0xFFE65100);
    canvas.drawRect(Rect.fromLTWH(hx - 6, mastTop - 1, 12, 6), _p);
    Offset hook;
    if (p < 0.05) {
      final apex0 = Offset(hx, _roofY - 2);
      hook = Offset(hx, _lerp(mastTop + 6, apex0.dy, _ease(p / 0.05)));
    } else if (p < 0.88) {
      hook = _roofPt(Offset(hx, _roofY - 52), p, t);
    } else {
      hook = Offset(hx,
          _lerp(_roofY - 52, mastTop + 6, _ease((p - 0.88) / 0.08)));
    }
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFF212121);
    canvas.drawLine(Offset(hx - 2, mastTop + 5), Offset(hook.dx - 2, hook.dy), _p);
    canvas.drawLine(Offset(hx + 2, mastTop + 5), Offset(hook.dx + 2, hook.dy), _p);
    // sling baja ke dua sudut atap
    if (p >= 0.0 && p < 0.86) {
      final l = _roofPt(Offset(_bl + 10, _roofY - 22), p, t);
      final rr = _roofPt(Offset(_bl + 180, _roofY - 22), p, t);
      _p
        ..strokeWidth = 1.0
        ..color = const Color(0xFF37474F);
      canvas.drawLine(hook.translate(0, 6), l, _p);
      canvas.drawLine(hook.translate(0, 6), rr, _p);
    }
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFF6F00);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(hook.dx - 5, hook.dy, 10, 7), const Radius.circular(2)),
      _p,
    );
  }

  void _drawFloorSite(Canvas canvas, double t, double p) {
    final baseY = _roofY + _fh;
    final mastTop = _roofY - 92;
    final wallP = _ease(_c01((p - 0.38) / 0.20));
    final deckY = baseY - (_fh - 26) * wallP;
    final a = (p < 0.04 ? p / 0.04 : 1.0) * (p > 0.90 ? (1 - p) / 0.10 : 1.0);
    final sa = _c01(p / 0.05) * (1 - _ease(_c01((p - 0.82) / 0.10)));

    // derek + perlengkapan tanah
    canvas.saveLayer(_view, Paint()..color = Color.fromRGBO(0, 0, 0, _c01(a)));
    _siteProps(canvas, t, true);
    _towerCrane(canvas, t, p, mastTop);
    if (!d.compact && p > 0.02 && p < 0.86) {
      // juru isyarat di tanah mengarahkan derek
      _worker(canvas, const Offset(172, _gy), -1,
          arm: -1.45 + math.sin(t * 6) * 0.5,
          vest: const Color(0xFFC6FF00),
          cheer: p > 0.86,
          t: t);
    }
    canvas.restore();

    // perancah + dek kerja yang naik + tukang
    if (sa > 0.01) {
      canvas.saveLayer(_view, Paint()..color = Color.fromRGBO(0, 0, 0, sa));
      _scaffoldRig(canvas, _bl - 7, _bl + 197, _roofY + 4, deckY);
      _hoist(canvas, _bl + 207, _roofY - 4, deckY - 9, t);
      if (!d.compact) _floorCrew(canvas, t, p, deckY);
      canvas.restore();
    }

    // percikan las di kolom
    if (p > 0.17 && p < 0.40 && !d.compact) {
      final wk = _c01((p - 0.17) / 0.20) * 3.9;
      final col = wk.floor();
      final cp = _ease(_c01((p - 0.17 - col * 0.028) / 0.15));
      final w = Offset(_bl + (wk) * _cw + 2, baseY - _fh * cp);
      if (math.sin(t * 38) > -0.2) {
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFE1F5FE).withValues(alpha: 0.9);
        canvas.drawCircle(w, 2.6, _p);
        _p.color = const Color(0xFF40C4FF).withValues(alpha: 0.35);
        canvas.drawCircle(w, 6.5, _p);
      }
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 7; k++) {
        final ph = (t * 3 + k * 0.17) % 1.0;
        final ang = -math.pi * (0.1 + 0.8 * ((k * 37) % 10) / 10);
        final dx = math.cos(ang) * 18 * ph;
        final dy = math.sin(ang) * 18 * ph + 26 * ph * ph;
        _p.color = const Color(0xFFFFD54F).withValues(alpha: 1 - ph);
        canvas.drawLine(w + Offset(dx, dy), w + Offset(dx + 1.6, dy + 1.6), _p);
      }
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt;
    }

    // atap mendarat: debu menyebar di sepanjang tepi atas lantai
    if (p > 0.85 && p < 0.97) {
      final q = _c01((p - 0.85) / 0.12);
      for (var k = 0; k < 10; k++) {
        final side = k.isEven ? -1.0 : 1.0;
        final spread = (k ~/ 2 + 1) * 10.0;
        final x = 200 + side * (spread + 38 * _ease(q) * (0.4 + k * 0.08));
        final y = _roofY - 2 - q * (6 + (k % 3) * 6);
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFD7CCC8).withValues(alpha: (1 - q) * 0.6);
        canvas.drawCircle(Offset(x.clamp(_bl - 20, _bl + 210).toDouble(), y),
            4 + q * 9, _p);
      }
    }

    if (p > 0.88) {
      final q = _c01((p - 0.88) / 0.12);
      _drawBannerText(
        canvas,
        'LANTAI BARU! +INCOME',
        Offset(200, _roofY - 62 - q * 26),
        const Color(0xFFFFEE58),
        scale: 0.95 + math.sin(q * math.pi) * 0.25,
        alpha: 1 - q,
      );
    }
  }

  void _floorCrew(Canvas canvas, double t, double p, double deckY) {
    final foot = deckY - 0.5;
    final cheer = p > 0.80;
    final weldK = _c01((p - 0.17) / 0.20) * 3.9;

    // tukang besi / las: berpindah dari kolom ke kolom
    if (cheer) {
      _worker(canvas, Offset(_bl + 20, foot), 1, cheer: true, t: t);
    } else if (p >= 0.17 && p < 0.40) {
      _worker(canvas, Offset(_bl + weldK * _cw - 8, foot), 1,
          arm: -0.9 + math.sin(t * 10).abs() * 1.3, tool: 4);
    } else if (p >= 0.58 && p < 0.80) {
      // pengaci: plester lalu cat kamar baru (kolom pertama lantai ini)
      final plasterP = _ease(_c01((p - 0.58) / 0.07));
      final paintP = _ease(_c01((p - 0.64) / 0.10));
      if (p < 0.64) {
        _worker(canvas, Offset(_bl + 6 + (_cw - 12) * plasterP, foot), 1,
            arm: -0.55 + math.sin(t * 6) * 0.4, tool: 2);
      } else {
        _worker(canvas, Offset(_bl + 5 + (_cw - 10) * paintP, foot), 1,
            arm: -0.7 + math.sin(t * 5) * 0.55, tool: 3);
      }
    } else {
      _worker(canvas, Offset(_bl + 20, foot), 1, arm: 0.7);
    }

    // dua tukang bata: memasang dinding sambil mengikuti tinggi dek
    final laying = p >= 0.38 && p < 0.58;
    for (var k = 0; k < 2; k++) {
      final x = _bl + (k == 0 ? 112.0 : 165.0);
      final dir = k == 0 ? 1.0 : -1.0;
      if (cheer) {
        _worker(canvas, Offset(x, foot), dir,
            cheer: true, t: t + k * 0.5, vest: const Color(0xFF00ACC1));
      } else {
        _worker(canvas, Offset(x, foot), dir,
            arm: laying ? -0.2 + math.sin(t * 7 + k * 1.7) * 0.5 : 0.7,
            tool: laying ? 1 : 0,
            vest: const Color(0xFF00ACC1));
      }
    }
    // debu pekerjaan dinding
    if (laying) {
      for (var k = 0; k < 4; k++) {
        _siteDust(canvas, Offset(_bl + 24 + k * 48.0, foot - 24), t + k * 0.3, 0.8);
      }
    }
  }

  /// Titik masuk gambar renovasi (tambah kamar / tambah lantai). Dipanggil
  /// dari kedua mode (rumah tunggal & jalan).
  void _drawCrane(Canvas canvas, double t) {
    final p = _buildP;
    if (p == null) return;
    if (_isFloorBuild) {
      _drawFloorSite(canvas, t, p);
    } else {
      _drawRoomSite(canvas, t, p);
    }
  }

}