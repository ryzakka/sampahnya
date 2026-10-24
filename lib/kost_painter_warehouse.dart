part of 'kost_scene.dart';

// ====================================================================
//  Gudang sampah di sisi kanan kost (lahan x 300..396 koordinat rumah).
//  Semua digambar dari [KostSceneData.warehouse]; null = tidak digambar
//  (lobi, kustomisasi, intro). Murni visual: angka ditentukan server.
// ====================================================================

const double _whLotL = 300;
const double _whLotR = 396;

/// Titik parkir truk gudang di jalan (koordinat rumah).
const double _whTruckX = 352;

/// Pusat jalur gerobak tuang & posisi kotak sampah kiri.
const double _whBinX = 66;

final Map<String, TextPainter> _whTextCache = <String, TextPainter>{};

TextPainter _whTp(String s, double size, Color c) => _whTextCache.putIfAbsent(
  '$s|$size|${c.toARGB32()}',
      () => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        color: c,
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.3,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(),
);

extension KostPainterWarehouse on KostPainter {
  // (kiri, lebar, tinggi) badan gudang per tier
  ({double l, double w, double h}) _whBox(int tier) {
    if (tier <= 1) return (l: 332.0, w: 44.0, h: 34.0);
    if (tier == 2) return (l: 330.0, w: 58.0, h: 46.0);
    return (l: 324.0, w: 72.0, h: 60.0);
  }

  /// Tengah pintu (x) tempat sampah masuk / keluar.
  double _whDoorX(int tier) {
    final b = _whBox(tier);
    return b.l + b.w / 2;
  }

  /// 0..1 seberapa terbuka pintu gudang (truk bekerja / gerobak menuang).
  double _whDoorOpen(WhLive w) {
    var open = 0.0;
    final hp = w.truckProgress;
    if (hp != null) {
      open = math.max(
          open, _ease((hp - 0.20) / 0.06) * (1 - _ease((hp - 0.78) / 0.06)));
    }
    final age = w.pourAgeMs;
    if (age != null) {
      final u = age / Wh.pourAnimMs;
      open = math.max(
          open, _ease((u - 0.58) / 0.05) * (1 - _ease((u - 0.84) / 0.06)));
    }
    return open;
  }

  // ------------------------------------------------------------ gudang

  void _drawWarehouse(Canvas canvas, double t) {
    final w = d.warehouse;
    if (w == null) return;

    // Alas beton lahan
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF90A4AE);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(_whLotL, _gy + 1, _whLotR - _whLotL, 5),
        const Radius.circular(2),
      ),
      _p,
    );

    if (!w.built) {
      _whVacantLot(canvas, t);
      return;
    }

    final b = _whBox(w.tier);
    final top = _gy - b.h;
    final cx = b.l + b.w / 2;
    final open = _whDoorOpen(w);
    final active = w.stored > 0.5;

    // bayangan
    _p.color = const Color(0x33000000);
    canvas.drawOval(
        Rect.fromLTWH(b.l - 2, _gy - 1, b.w + 10, 6), _p);

    // dinding
    final stripe = w.tier == 1
        ? const Color(0xFF43A047)
        : (w.tier == 2 ? const Color(0xFF1E88E5) : const Color(0xFFFB8C00));
    _p.color = const Color(0xFFB0BEC5);
    canvas.drawRect(Rect.fromLTWH(b.l, top, b.w, b.h), _p);
    // alur seng bergelombang
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = const Color(0x22000000);
    for (var x = b.l + 4; x < b.l + b.w - 1; x += 4) {
      canvas.drawLine(Offset(x, top + 4), Offset(x, _gy), _p);
    }
    _p.style = PaintingStyle.fill;
    // pita warna tier
    _p.color = stripe;
    canvas.drawRect(Rect.fromLTWH(b.l, top + 4, b.w, 3), _p);
    // tepi
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = const Color(0xFF546E7A);
    canvas.drawRect(Rect.fromLTWH(b.l, top, b.w, b.h), _p);
    _p.style = PaintingStyle.fill;

    // atap datar + penutup
    _p.color = const Color(0xFF455A64);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(b.l - 3, top - 3, b.w + 6, 4),
        const Radius.circular(1.5),
      ),
      _p,
    );
    _p.color = const Color(0xFF607D8B);
    canvas.drawRect(Rect.fromLTWH(b.l - 3, top - 3, b.w + 6, 1.2), _p);

    // jendela kecil (tier 2+)
    if (w.tier >= 2) {
      _p.color = const Color(0xFF81D4FA);
      canvas.drawRect(Rect.fromLTWH(b.l + 5, top + 12, 7, 5), _p);
      canvas.drawRect(Rect.fromLTWH(b.l + b.w - 12, top + 12, 7, 5), _p);
    }

    // pintu rolling (1 pintu tier 1-2, 2 pintu tier 3)
    final doors = w.tier >= 3 ? 2 : 1;
    final dw = w.tier == 1 ? 17.0 : (w.tier == 2 ? 20.0 : 19.0);
    final dh = w.tier == 1 ? 20.0 : (w.tier == 2 ? 24.0 : 28.0);
    for (var i = 0; i < doors; i++) {
      final dcx = doors == 1 ? cx : b.l + b.w * (i == 0 ? 0.27 : 0.73);
      _whDoor(canvas, t, w, Rect.fromLTWH(dcx - dw / 2, _gy - dh, dw, dh), open);
    }

    // papan nama + indikator isi
    final plateY = top + 9.0;
    final plate = Rect.fromCenter(
        center: Offset(cx, plateY + 4), width: w.tier == 1 ? 24 : 28, height: 9);
    _p.color = const Color(0xFF263238);
    canvas.drawRRect(
        RRect.fromRectAndRadius(plate, const Radius.circular(2)), _p);
    final tp = _whTp('GUDANG ${w.tier}', 4.4, const Color(0xFFFFEE58));
    tp.paint(canvas, Offset(cx - tp.width / 2, plate.top + 0.6));
    final barW = plate.width - 4;
    _p.color = const Color(0xFF37474F);
    canvas.drawRect(Rect.fromLTWH(plate.left + 2, plate.bottom - 3.2, barW, 2), _p);
    final f = w.fill;
    _p.color = f < 0.6
        ? const Color(0xFF66BB6A)
        : (f < 0.85 ? const Color(0xFFFFCA28) : const Color(0xFFEF5350));
    canvas.drawRect(
        Rect.fromLTWH(plate.left + 2, plate.bottom - 3.2, barW * f, 2), _p);

    // ---- komponen ----
    final roofY = top - 3.0;
    if (Wh.has(w.comps, kWhPencacah)) {
      _whShredder(canvas, t, b.l + 9, roofY, active);
    }
    if (Wh.has(w.comps, kWhPenggilingan)) {
      _whGrinder(canvas, t, cx, roofY, active);
    }
    if (Wh.has(w.comps, kWhIoT)) {
      _whIoT(canvas, t, b.l + b.w - 8, roofY);
    }
    if (Wh.has(w.comps, kWhKonveyor)) {
      _whConveyor(canvas, t, b.l + 3, b.w - 6, active || open > 0.1);
    }
    if (Wh.has(w.comps, kWhPenyortir)) {
      _whSorter(canvas, b.l - 23);
    }
    if (Wh.has(w.comps, kWhTimbang)) {
      _whScale(canvas, t, cx);
    }

    // gerobak tuang (kiri -> gudang)
    final age = w.pourAgeMs;
    if (age != null && age >= 0 && age <= Wh.pourAnimMs) {
      _whPourCart(canvas, t, w, age / Wh.pourAnimMs);
    }
  }

  void _whVacantLot(Canvas canvas, double t) {
    // pagar tali + tiang
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = const Color(0xFFFFB300);
    canvas.drawLine(const Offset(302, _gy - 9), const Offset(394, _gy - 9), _p);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF6D4C41);
    for (var x = 302.0; x <= 394.0; x += 23) {
      canvas.drawRect(Rect.fromLTWH(x - 1, _gy - 13, 2, 14), _p);
    }
    // papan
    const sign = Rect.fromLTWH(333, _gy - 34, 30, 15);
    _p.color = const Color(0xFF6D4C41);
    canvas.drawRect(const Rect.fromLTWH(347, _gy - 19, 2, 19), _p);
    _p.color = const Color(0xFFFFF59D);
    canvas.drawRRect(
        RRect.fromRectAndRadius(sign, const Radius.circular(2)), _p);
    final a = _whTp('LAHAN', 5, const Color(0xFF5D4037));
    final b = _whTp('GUDANG', 5, const Color(0xFF5D4037));
    a.paint(canvas, Offset(348 - a.width / 2, _gy - 33));
    b.paint(canvas, Offset(348 - b.width / 2, _gy - 26));
  }

  void _whDoor(
      Canvas canvas, double t, WhLive w, Rect r, double open) {
    // interior
    _p.color = const Color(0xFF263238);
    canvas.drawRect(r, _p);
    if (open > 0.05 && w.fill > 0.04) {
      final n = math.max(1, (w.fill * 5).ceil());
      for (var i = 0; i < n; i++) {
        final bx = r.left + 4 + (i % 3) * 5.5;
        final by = r.bottom - 3 - (i ~/ 3) * 4;
        _bag(canvas, Offset(bx, by), 700 + i, scale: 0.5);
      }
    }
    // tirai rolling turun sebesar (1 - open)
    final h = r.height * (1 - open);
    if (h > 0.5) {
      _p.color = const Color(0xFFCFD8DC);
      canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, h), _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = const Color(0x55455A64);
      for (var y = r.top + 2.5; y < r.top + h; y += 2.5) {
        canvas.drawLine(Offset(r.left, y), Offset(r.right, y), _p);
      }
      _p.style = PaintingStyle.fill;
    }
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF455A64);
    canvas.drawRect(r, _p);
    _p.style = PaintingStyle.fill;
  }

  // ------------------------------------------------ komponen tambahan

  /// Pencacah: corong + rotor berputar (di atap).
  void _whShredder(Canvas canvas, double t, double x, double y, bool on) {
    _p.color = const Color(0xFF607D8B);
    canvas.drawRect(Rect.fromLTWH(x - 6, y - 7, 12, 7), _p);
    final fun = Path()
      ..moveTo(x - 8, y - 7)
      ..lineTo(x + 8, y - 7)
      ..lineTo(x + 4, y - 11)
      ..lineTo(x - 4, y - 11)
      ..close();
    _p.color = const Color(0xFFFFB300);
    canvas.drawPath(fun, _p);
    canvas.save();
    canvas.translate(x, y - 3.5);
    canvas.rotate(on ? t * 7 : 0.4);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFECEFF1);
    canvas.drawLine(const Offset(-3.2, 0), const Offset(3.2, 0), _p);
    canvas.drawLine(const Offset(0, -3.2), const Offset(0, 3.2), _p);
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
    canvas.restore();
  }

  /// Penggilingan: drum horizontal bergaris yang berputar.
  void _whGrinder(Canvas canvas, double t, double x, double y, bool on) {
    final r = Rect.fromLTWH(x - 9, y - 10, 18, 9);
    _p.color = const Color(0xFF8D6E63);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), _p);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)));
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF5D4037);
    final off = on ? (t * 9) % 5 : 0.0;
    for (var gx = r.left - 5 + off; gx < r.right; gx += 5) {
      canvas.drawLine(Offset(gx, r.bottom), Offset(gx + 4, r.top), _p);
    }
    _p.style = PaintingStyle.fill;
    canvas.restore();
    // tumpukan pelet kecil di sisi drum
    _p.color = const Color(0xFFBCAAA4);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(x + 11 + i * 1.6, y - 0.8 - (i % 2)), 1.0, _p);
    }
  }

  /// IoT: tiang antena dengan lampu berkedip & gelombang sinyal.
  void _whIoT(Canvas canvas, double t, double x, double y) {
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF455A64);
    canvas.drawLine(Offset(x, y), Offset(x, y - 15), _p);
    canvas.drawLine(Offset(x - 3, y - 8), Offset(x + 3, y - 8), _p);
    final blink = math.sin(t * 6) > 0;
    _p.style = PaintingStyle.fill;
    _p.color = blink ? const Color(0xFF69F0AE) : const Color(0xFF1B5E20);
    canvas.drawCircle(Offset(x, y - 16), 1.8, _p);
    for (var k = 0; k < 2; k++) {
      final ph = (t * 0.9 + k * 0.5) % 1.0;
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = const Color(0xFF69F0AE).withValues(alpha: (1 - ph) * 0.8);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(x, y - 16), radius: 3 + ph * 9),
        -math.pi * 0.85,
        math.pi * 0.7,
        false,
        _p,
      );
    }
    _p.style = PaintingStyle.fill;
  }

  /// Ban berjalan di dasar dinding depan.
  void _whConveyor(Canvas canvas, double t, double x, double w, bool on) {
    _p.color = const Color(0xFF37474F);
    canvas.drawRect(Rect.fromLTWH(x, _gy - 5, w, 4), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFFFCA28);
    final sp = on ? 16.0 : 3.0;
    for (var k = 0.0; k < w; k += 6) {
      final px = x + ((k + t * sp) % w);
      canvas.drawLine(Offset(px, _gy - 4.6), Offset(px + 1.4, _gy - 3), _p);
      canvas.drawLine(Offset(px + 1.4, _gy - 3), Offset(px, _gy - 1.4), _p);
    }
    _p.style = PaintingStyle.fill;
  }

  /// Penyortir: tiga tong warna di halaman depan.
  void _whSorter(Canvas canvas, double x) {
    const cols = [Color(0xFFE53935), Color(0xFFFDD835), Color(0xFF1E88E5)];
    for (var i = 0; i < 3; i++) {
      final bx = x + i * 7.0;
      _p.color = cols[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, _gy - 9, 6, 11), const Radius.circular(1.2)),
        _p,
      );
      _p.color = const Color(0x44000000);
      canvas.drawRect(Rect.fromLTWH(bx - 0.4, _gy - 9.6, 6.8, 1.6), _p);
    }
  }

  /// Jembatan timbang: pelat di depan pintu + kotak layar digital.
  void _whScale(Canvas canvas, double t, double cx) {
    _p.color = const Color(0xFF78909C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 15, _gy + 1.5, 30, 3.2), const Radius.circular(1)),
      _p,
    );
    _p.color = const Color(0xFF263238);
    canvas.drawRect(Rect.fromLTWH(cx + 17, _gy - 8, 8, 10), _p);
    _p.color = math.sin(t * 3) > -0.5
        ? const Color(0xFF69F0AE)
        : const Color(0xFF2E7D32);
    canvas.drawRect(Rect.fromLTWH(cx + 18.5, _gy - 6.5, 5, 3), _p);
  }

  // ----------------------------------------------- gerobak tuang sampah

  /// Gerobak membawa isi kotak kiri menyusuri trotoar, menuang ke gudang,
  /// lalu kembali. [u] 0..1 = progres animasi.
  void _whPourCart(Canvas canvas, double t, WhLive w, double u) {
    final doorX = _whDoorX(w.tier);
    final endX = doorX - 15;
    const y = _gy + 10.0; // trotoar depan kost
    const bagsN = 4;

    double x;
    double dir; // +1 ke kanan, -1 ke kiri
    var moving = false;
    var tip = 0.0;
    var loaded = 0.0; // 0..1 fraksi kantong di gerobak
    if (u < 0.22) {
      x = _whBinX + 8;
      dir = 1;
      loaded = _ease(u / 0.20);
    } else if (u < 0.58) {
      final q = (u - 0.22) / 0.36;
      x = _lerp(_whBinX + 8, endX, _easeInOut3(q));
      dir = 1;
      moving = true;
      loaded = 1;
    } else if (u < 0.84) {
      x = endX;
      dir = 1;
      tip = _ease((u - 0.58) / 0.08) * (1 - _ease((u - 0.76) / 0.08));
      loaded = 1;
    } else {
      final q = (u - 0.84) / 0.16;
      x = _lerp(endX, _whBinX + 8, _easeInOut3(q));
      dir = -1;
      moving = q < 0.98;
    }
    final alpha = u > 0.96 ? 1 - (u - 0.96) / 0.04 : 1.0;

    final bob = moving ? math.sin(t * 22) * 0.5 : 0.0;
    canvas.save();
    canvas.translate(x, y + bob);
    canvas.scale(dir, 1);
    if (alpha < 1) {
      canvas.saveLayer(const Rect.fromLTWH(-40, -40, 80, 50),
          Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    }

    // pekerja (di belakang gerobak)
    final step = moving ? math.sin(t * 14) * 3 : 0.0;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF37474F);
    canvas.drawLine(const Offset(-19, -7), Offset(-19 + step, 0), _p);
    canvas.drawLine(const Offset(-19, -7), Offset(-19 - step, 0), _p);
    _p.strokeCap = StrokeCap.butt;
    _p.style = PaintingStyle.fill;
    _p.color = const Color(0xFFFF7043); // rompi
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-21.5, -16, 5, 9), const Radius.circular(1.2)),
      _p,
    );
    _p.color = const Color(0xFFFFCC80);
    canvas.drawCircle(const Offset(-19, -19), 2.6, _p);
    _p.color = const Color(0xFFFFC107); // helm
    canvas.drawArc(Rect.fromCircle(center: const Offset(-19, -19), radius: 3.0),
        math.pi, math.pi, true, _p);

    // gerobak (poros miring saat menuang di roda depan)
    canvas.save();
    canvas.translate(7, -3);
    canvas.rotate(tip * 0.75);
    canvas.translate(-7, 3);

    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFF5D4037);
    canvas.drawLine(const Offset(-17, -9), const Offset(-8, -6), _p); // gagang
    _p.style = PaintingStyle.fill;
    final body = Path()
      ..moveTo(-9, -12)
      ..lineTo(11, -12)
      ..lineTo(8, -4)
      ..lineTo(-6, -4)
      ..close();
    _p.color = const Color(0xFF43A047);
    canvas.drawPath(body, _p);
    _p.color = const Color(0xFF2E7D32);
    canvas.drawRect(const Rect.fromLTWH(-9, -12.8, 20, 1.6), _p);

    // kantong di gerobak: yang sudah "jatuh" tidak digambar
    final nIn = (loaded * bagsN).ceil();
    for (var i = 0; i < nIn; i++) {
      if (u >= 0.64 + i * 0.03) continue; // sudah jatuh ke gudang
      _bag(canvas, Offset(-4 + i * 4.2, -13.5 - (i % 2) * 1.8), 640 + i,
          scale: 0.55);
    }
    canvas.restore();

    // roda
    _p.color = const Color(0xFF212121);
    canvas.drawCircle(const Offset(7, -3), 3, _p);
    _p.color = const Color(0xFF9E9E9E);
    canvas.drawCircle(const Offset(7, -3), 1.1, _p);

    if (alpha < 1) canvas.restore();
    canvas.restore();

    // kantong yang jatuh dari gerobak ke pintu gudang (koordinat dunia)
    if (u >= 0.62 && u < 0.84) {
      for (var i = 0; i < bagsN; i++) {
        final q = ((u - 0.64 - i * 0.03) / 0.10).clamp(0.0, 1.0).toDouble();
        if (q <= 0 || q >= 1) continue;
        final px = _lerp(endX + 9 + i * 2, doorX, q);
        final py = _lerp(y - 12, _gy - 5, q) - math.sin(q * math.pi) * 7;
        _bag(canvas, Offset(px, py), 640 + i, scale: 0.55);
      }
    }
  }

  // ------------------------------------------------------- truk gudang

  /// Truk khusus gudang: dicat jingga, parkir di jalan depan gudang, memuat
  /// lewat peluncur dari pintu. Dipanggil dari [_truckLayer].
  void _whTruckLayer(Canvas canvas, double t, double vl, double vr) {
    final w = d.warehouse;
    final hp = w?.truckProgress;
    if (w == null || hp == null || !w.built || d.eliminated) return;

    const arriveEnd = 0.20;
    const leaveStart = 0.82;
    const parkX = _whTruckX;
    final inX = math.min(math.max(vr + 110, parkX + 220), parkX + 1000);
    final outX = math.max(math.min(vl - 110, parkX - 220), parkX - 1000);
    final inVisible = inX < vr + 40;
    final outVisible = outX > vl - 40;

    var x = parkX;
    var alpha = 1.0;
    var lean = 0.0;
    var brake = false;
    var moving = false;

    if (hp < arriveEnd) {
      final u = hp / arriveEnd;
      x = _lerp(inX, parkX, _easeOut3(u));
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
      x = _lerp(parkX, outX, _easeIn(go));
      if (outVisible) alpha = 1 - _ease((go - 0.7) / 0.3);
      lean = 0.03 * _ease(go / 0.2) * (1 - _ease((go - 0.2) / 0.4));
      moving = go > 0.02;
    }

    final vis = _ease((hp - 0.215) / 0.06) * (1 - _ease((hp - 0.755) / 0.06));
    final (double, double) lr = vis > 0.6 ? _workLid(t) : (0.0, 0.0);
    final bob = moving ? math.sin(t * 24) * 0.7 : math.sin(t * 38) * 0.22;

    // peluncur dari pintu gudang ke bak truk + kantong yang meluncur
    if (vis > 0.02) {
      final doorX = _whDoorX(w.tier);
      final from = Offset(doorX, _gy - 2);
      final to = Offset(x - 18, _roadY - 44);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF78909C).withValues(alpha: vis);
      canvas.drawLine(from, to, _p);
      _p
        ..strokeWidth = 1.2
        ..color = const Color(0xFFCFD8DC).withValues(alpha: vis);
      canvas.drawLine(from, to, _p);
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt;
      if (vis > 0.5) {
        for (var k = 0; k < 4; k++) {
          final q = (t * 0.7 + k * 0.25) % 1.0;
          final bp = Offset.lerp(from, to, q)!;
          _bag(canvas, bp.translate(0, -3), 900 + k, scale: 0.6);
        }
      }
    }

    _fadeLayer(
      canvas,
      Rect.fromLTRB(x - 130, _roadY - 90, x + 130, _roadY + 16),
      alpha,
          () {
        canvas.saveLayer(
          Rect.fromLTRB(x - 130, _roadY - 90, x + 130, _roadY + 16),
          Paint()
            ..colorFilter =
            const ColorFilter.mode(Color(0x77FF9100), BlendMode.srcATop),
        );
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
        canvas.restore();
      },
    );

    if (vis > 0.3) {
      _drawBannerText(
        canvas,
        'TRUK GUDANG',
        Offset(x - 30, _roadY - 104),
        const Color(0xFFFFB74D),
        alpha: vis,
      );
    }
  }
}