part of 'kost_scene.dart';

// ====================================================================
//  Gudang sampah di sisi kanan kost (lahan x 300..396 koordinat rumah).
//  Semua digambar dari [KostSceneData.warehouse]; null = tidak digambar
//  (lobi, kustomisasi, intro). Murni visual: angka ditentukan server.
//
//  v2 - lebih halus & lebih cantik:
//   * mesin (pencacah, penggilingan, ban berjalan, kipas) berputar naik /
//     turun perlahan (kecepatan dikejar eksponensial, fase diintegrasikan),
//     bukan hidup-mati mendadak;
//   * indikator isi bergerak mulus, berdenyut merah saat hampir penuh;
//   * dinding berlapis cahaya, sambungan seng, paku keling, lampu pintu &
//     lampu putar saat bekerja, jendela dan lampu menyala di malam hari;
//   * koin kecil naik dari atap & asap cerobong saat sampah diproses;
//   * gerobak: langkah pekerja mengikuti jarak tempuh, roda berputar sesuai
//     jarak, tangan mendorong gagang, kantong jatuh berputar + debu;
//   * truk gudang: kantong meluncur di peluncur dengan percepatan.
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

// ---------------------------------------------------------- memori halus
//
// Painter dibuat ulang tiap frame, jadi nilai yang harus "mengejar" target
// (isi gudang, kecepatan mesin) disimpan di sini, per kunci rumah.
// Isi: [nilai/kecepatan, waktu terakhir, fase terintegrasi].

final Map<int, List<double>> _whMem = <int, List<double>>{};

/// Mengejar [target] secara eksponensial (halus, tidak melompat).
double _whSmooth(int key, double target, double t, {double rate = 3.0}) {
  final m = _whMem.putIfAbsent(key, () => <double>[target, t, 0.0]);
  final dt = t - m[1];
  if (dt > 0 && dt < 1.5) {
    m[0] += (target - m[0]) * (1 - math.exp(-rate * dt));
  } else if (dt != 0) {
    m[0] = target;
  }
  m[1] = t;
  return m[0];
}

/// Fase putar yang diintegrasikan dari kecepatan yang naik/turun perlahan
/// menuju [speed]: mesin menyala dan berhenti dengan inersia.
double _whSpin(int key, double speed, double t, {double rate = 2.2}) {
  final m = _whMem.putIfAbsent(key, () => <double>[0.0, t, 0.0]);
  final dt = t - m[1];
  if (dt > 0 && dt < 1.5) {
    m[0] += (speed - m[0]) * (1 - math.exp(-rate * dt));
    m[2] += m[0] * dt;
  } else if (dt != 0) {
    m[0] = speed;
  }
  m[1] = t;
  return m[2];
}

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
    final key = d.seed * 16;
    final night = _night;

    // Alas beton lahan + sambungan
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
    _p.color = const Color(0x22FFFFFF);
    canvas.drawRect(const Rect.fromLTWH(_whLotL, _gy + 1, _whLotR - _whLotL, 1), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4
      ..color = const Color(0x33455A64);
    for (var x = _whLotL + 12; x < _whLotR; x += 16) {
      canvas.drawLine(Offset(x, _gy + 1.5), Offset(x - 1.5, _gy + 6), _p);
    }
    _p.style = PaintingStyle.fill;

    if (!w.built) {
      _whVacantLot(canvas, t);
      return;
    }

    final b = _whBox(w.tier);
    final top = _gy - b.h;
    final cx = b.l + b.w / 2;
    final open = _whDoorOpen(w);
    final on = w.stored > 0.5;
    final busy = open > 0.05 || w.truckProgress != null || w.pourAgeMs != null;

    // nilai yang bergerak mulus
    final fillS = _whSmooth(key + 1, w.fill, t, rate: 2.5);
    final run = _whSmooth(key + 2, on ? 1.0 : 0.0, t, rate: 1.6);
    final shrPh = _whSpin(key + 3, on ? 8.0 : 0.0, t);
    final grdPh = _whSpin(key + 4, on ? 9.0 : 0.0, t);
    final cnvPh = _whSpin(key + 5, (on || open > 0.1) ? 16.0 : 2.5, t);
    final fanPh = _whSpin(key + 6, on ? 11.0 : 1.2, t, rate: 1.4);

    // bayangan
    _p.color = const Color(0x33000000);
    canvas.drawOval(Rect.fromLTWH(b.l - 2, _gy - 1, b.w + 10, 6), _p);

    // dinding
    final stripe = w.tier == 1
        ? const Color(0xFF43A047)
        : (w.tier == 2 ? const Color(0xFF1E88E5) : const Color(0xFFFB8C00));
    final wallRect = Rect.fromLTWH(b.l, top, b.w, b.h);
    _p.color = w.tier == 1
        ? const Color(0xFFB4C3CA)
        : (w.tier == 2 ? const Color(0xFFBDCAD1) : const Color(0xFFC6D1D7));
    canvas.drawRect(wallRect, _p);
    // lapisan cahaya: terang di atas, gelap di bawah
    _p.color = const Color(0x1AFFFFFF);
    canvas.drawRect(Rect.fromLTWH(b.l, top, b.w, b.h * 0.32), _p);
    _p.color = const Color(0x14000000);
    canvas.drawRect(Rect.fromLTWH(b.l, _gy - b.h * 0.28, b.w, b.h * 0.28), _p);
    // alur seng bergelombang (terang + gelap berpasangan)
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (var x = b.l + 3; x < b.l + b.w - 1; x += 4) {
      _p.color = const Color(0x22000000);
      canvas.drawLine(Offset(x, top + 4), Offset(x, _gy), _p);
      _p.color = const Color(0x18FFFFFF);
      canvas.drawLine(Offset(x + 0.8, top + 4), Offset(x + 0.8, _gy), _p);
    }
    _p.style = PaintingStyle.fill;
    // sisi kanan lebih gelap (volume)
    _p.color = const Color(0x16000000);
    canvas.drawRect(Rect.fromLTWH(b.l + b.w - 3, top, 3, b.h), _p);
    // pita warna tier + paku keling
    _p.color = stripe;
    canvas.drawRect(Rect.fromLTWH(b.l, top + 4, b.w, 3), _p);
    _p.color = const Color(0x33FFFFFF);
    canvas.drawRect(Rect.fromLTWH(b.l, top + 4, b.w, 0.9), _p);
    _p.color = const Color(0x55263238);
    for (var x = b.l + 3; x < b.l + b.w - 2; x += 6) {
      canvas.drawCircle(Offset(x, top + 8.6), 0.45, _p);
    }
    // tepi
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = const Color(0xFF546E7A);
    canvas.drawRect(wallRect, _p);
    _p.style = PaintingStyle.fill;
    // alas beton (plinth)
    _p.color = const Color(0xFF78909C);
    canvas.drawRect(Rect.fromLTWH(b.l - 0.5, _gy - 2, b.w + 1, 2.4), _p);

    // atap datar + penutup (lebih tebal & bergaris)
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
    _p.color = const Color(0x33000000);
    canvas.drawRect(Rect.fromLTWH(b.l - 3, top + 0.2, b.w + 6, 0.8), _p);

    // jendela kecil (tier 2+): menyala hangat saat malam
    if (w.tier >= 2) {
      final glass = _mix(
          const Color(0xFF81D4FA), const Color(0xFFFFE082), night * 0.9);
      for (final wx in [b.l + 5, b.l + b.w - 12]) {
        _p.color = glass;
        canvas.drawRect(Rect.fromLTWH(wx, top + 12, 7, 5), _p);
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..color = const Color(0xFF546E7A);
        canvas.drawRect(Rect.fromLTWH(wx, top + 12, 7, 5), _p);
        canvas.drawLine(Offset(wx + 3.5, top + 12), Offset(wx + 3.5, top + 17), _p);
        _p.style = PaintingStyle.fill;
        _p.color = const Color(0x40FFFFFF);
        canvas.drawRect(Rect.fromLTWH(wx + 0.6, top + 12.6, 1.8, 3.8), _p);
      }
    }

    // pintu rolling (1 pintu tier 1-2, 2 pintu tier 3)
    final doors = w.tier >= 3 ? 2 : 1;
    final dw = w.tier == 1 ? 17.0 : (w.tier == 2 ? 20.0 : 19.0);
    final dh = w.tier == 1 ? 20.0 : (w.tier == 2 ? 24.0 : 28.0);
    for (var i = 0; i < doors; i++) {
      final dcx = doors == 1 ? cx : b.l + b.w * (i == 0 ? 0.27 : 0.73);
      final dr = Rect.fromLTWH(dcx - dw / 2, _gy - dh, dw, dh);
      _whDoor(canvas, t, w, dr, open, fillS, night);
    }

    // papan nama + indikator isi (mulus, berdenyut bila hampir penuh)
    final plateY = top + 9.0;
    final plate = Rect.fromCenter(
        center: Offset(cx, plateY + 4), width: w.tier == 1 ? 24 : 28, height: 9);
    _p.color = const Color(0xFF263238);
    canvas.drawRRect(
        RRect.fromRectAndRadius(plate, const Radius.circular(2)), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = const Color(0xFF78909C);
    canvas.drawRRect(
        RRect.fromRectAndRadius(plate, const Radius.circular(2)), _p);
    _p.style = PaintingStyle.fill;
    final tp = _whTp('GUDANG ${w.tier}', 4.4, const Color(0xFFFFEE58));
    tp.paint(canvas, Offset(cx - tp.width / 2, plate.top + 0.6));
    final barW = plate.width - 4;
    _p.color = const Color(0xFF37474F);
    canvas.drawRect(Rect.fromLTWH(plate.left + 2, plate.bottom - 3.2, barW, 2), _p);
    final f = fillS;
    const low = Color(0xFF66BB6A);
    const mid = Color(0xFFFFCA28);
    const hi = Color(0xFFEF5350);
    var bar = f < 0.5
        ? low
        : (f < 0.75
        ? _mix(low, mid, (f - 0.5) / 0.25)
        : _mix(mid, hi, (f - 0.75) / 0.15));
    if (f > 0.9) {
      bar = _mix(bar, Colors.white, 0.25 * (0.5 + 0.5 * math.sin(t * 7)));
    }
    _p.color = bar;
    canvas.drawRect(
        Rect.fromLTWH(plate.left + 2, plate.bottom - 3.2, barW * f, 2), _p);

    // ---- komponen ----
    final roofY = top - 3.0;
    if (w.tier >= 2) {
      _whRoofFan(canvas, b.l + b.w * 0.70, roofY, fanPh);
    }
    if (w.tier >= 3) {
      _whChimney(canvas, b.l + b.w * 0.86, roofY);
    }
    if (Wh.has(w.comps, kWhPencacah)) {
      _whShredder(canvas, t, b.l + 9, roofY, shrPh, run);
    }
    if (Wh.has(w.comps, kWhPenggilingan)) {
      _whGrinder(canvas, t, cx, roofY, grdPh, fillS);
    }
    if (Wh.has(w.comps, kWhIoT)) {
      _whIoT(canvas, t, b.l + b.w - 8, roofY);
    }
    if (Wh.has(w.comps, kWhKonveyor)) {
      _whConveyor(canvas, b.l + 3, b.w - 6, cnvPh);
    }
    if (Wh.has(w.comps, kWhPenyortir)) {
      _whSorter(canvas, t, b.l - 23, run);
    }
    if (Wh.has(w.comps, kWhTimbang)) {
      _whScale(canvas, t, cx, open);
    }

    // lampu putar di atap saat gudang bekerja
    if (busy) _whBeacon(canvas, t, b.l + 5, roofY - 1);

    if (!d.compact) {
      // koin naik dari atap & asap bila sedang memproses
      if (run > 0.05) {
        _whCoins(canvas, t, cx + 2, roofY - 2, run, w.tier, w.comps);
        if (w.tier >= 3) {
          _whSmoke(canvas, t, b.l + b.w * 0.86 + 1.5, roofY - 13, run);
        } else if (Wh.has(w.comps, kWhPenggilingan)) {
          _whSmoke(canvas, t, cx + 5, roofY - 11, run);
        }
      }
      // cahaya malam: lampu pintu menyorot tanah
      if (night > 0.05) {
        _p.blendMode = BlendMode.plus;
        for (var i = 0; i < doors; i++) {
          final dcx = doors == 1 ? cx : b.l + b.w * (i == 0 ? 0.27 : 0.73);
          final ly = _gy - dh - 3.0;
          final cone = Path()
            ..moveTo(dcx - 1.5, ly + 1.5)
            ..lineTo(dcx + 1.5, ly + 1.5)
            ..lineTo(dcx + dw * 0.9, _gy + 4)
            ..lineTo(dcx - dw * 0.9, _gy + 4)
            ..close();
          _p.color = const Color(0xFFFFE2A0).withValues(alpha: 0.10 * night);
          canvas.drawPath(cone, _p);
          _p.color = const Color(0xFFFFD27A).withValues(alpha: 0.18 * night);
          canvas.drawCircle(Offset(dcx, ly), 5, _p);
        }
        if (w.tier >= 2) {
          _p.color = const Color(0xFFFFCA6B).withValues(alpha: 0.16 * night);
          canvas.drawRect(Rect.fromLTWH(b.l + 5, top + 12, 7, 5).inflate(2), _p);
          canvas.drawRect(
              Rect.fromLTWH(b.l + b.w - 12, top + 12, 7, 5).inflate(2), _p);
        }
        _p.blendMode = BlendMode.srcOver;
      }
    }

    // gerobak tuang (kiri -> gudang)
    final age = w.pourAgeMs;
    if (age != null && age >= 0 && age <= Wh.pourAnimMs) {
      _whPourCart(canvas, t, w, age / Wh.pourAnimMs);
    }
  }

  void _whVacantLot(Canvas canvas, double t) {
    // pagar tali melengkung + tiang
    const l = 302.0, r = 394.0;
    final sag = 2.2 + math.sin(t * 1.3) * 0.25;
    final rope = Path()
      ..moveTo(l, _gy - 9)
      ..quadraticBezierTo((l + r) / 2, _gy - 9 + sag * 2, r, _gy - 9);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = const Color(0xFFFFB300);
    canvas.drawPath(rope, _p);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF6D4C41);
    for (var x = l; x <= r; x += 23) {
      canvas.drawRect(Rect.fromLTWH(x - 1, _gy - 13, 2, 14), _p);
      _p.color = const Color(0xFFFFB300);
      canvas.drawCircle(Offset(x, _gy - 13), 1.2, _p);
      _p.color = const Color(0xFF6D4C41);
    }
    // kerucut pengaman
    for (final cxk in const [312.0, 384.0]) {
      _p.color = const Color(0xFFFF7043);
      canvas.drawPath(
        Path()
          ..moveTo(cxk - 2.6, _gy + 1)
          ..lineTo(cxk + 2.6, _gy + 1)
          ..lineTo(cxk + 0.7, _gy - 6)
          ..lineTo(cxk - 0.7, _gy - 6)
          ..close(),
        _p,
      );
      _p.color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(cxk - 1.7, _gy - 3.3, 3.4, 1.0), _p);
    }
    // papan bergoyang pelan dari tiang
    canvas.save();
    canvas.translate(348, _gy - 19);
    canvas.rotate(math.sin(t * 1.1) * 0.025);
    canvas.translate(-348, -(_gy - 19));
    const sign = Rect.fromLTWH(333, _gy - 34, 30, 15);
    _p.color = const Color(0xFF6D4C41);
    canvas.drawRect(const Rect.fromLTWH(347, _gy - 19, 2, 19), _p);
    _p.color = const Color(0xFFFFF59D);
    canvas.drawRRect(
        RRect.fromRectAndRadius(sign, const Radius.circular(2)), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0xFF8D6E63);
    canvas.drawRRect(
        RRect.fromRectAndRadius(sign, const Radius.circular(2)), _p);
    _p.style = PaintingStyle.fill;
    final a = _whTp('LAHAN', 5, const Color(0xFF5D4037));
    final b = _whTp('GUDANG', 5, const Color(0xFF5D4037));
    a.paint(canvas, Offset(348 - a.width / 2, _gy - 33));
    b.paint(canvas, Offset(348 - b.width / 2, _gy - 26));
    canvas.restore();
  }

  void _whDoor(Canvas canvas, double t, WhLive w, Rect r, double open,
      double fill, double night) {
    // bingkai + interior
    _p.color = const Color(0xFF546E7A);
    canvas.drawRect(r.inflate(1.1), _p);
    _p.color = const Color(0xFF263238);
    canvas.drawRect(r, _p);
    if (open > 0.05) {
      // cahaya hangat dari dalam
      _p.color = const Color(0xFFFFB74D).withValues(alpha: 0.18 * open);
      canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.6), _p);
      if (fill > 0.04) {
        final n = math.max(1, (fill * 5).ceil());
        for (var i = 0; i < n; i++) {
          final bx = r.left + 4 + (i % 3) * 5.5;
          final by = r.bottom - 3 - (i ~/ 3) * 4;
          _bag(canvas, Offset(bx, by), 700 + i, scale: 0.5);
        }
      }
    }
    // tirai rolling turun sebesar (1 - open), berlamela + bayangan
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
      _p.color = const Color(0x22FFFFFF);
      canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width * 0.4, h), _p);
      // gagang bawah tirai
      _p.color = const Color(0xFF78909C);
      canvas.drawRect(Rect.fromLTWH(r.left, r.top + h - 1.4, r.width, 1.4), _p);
      _p.color = const Color(0xFFECEFF1);
      canvas.drawRect(
          Rect.fromLTWH(r.center.dx - 1.6, r.top + h - 1.1, 3.2, 0.8), _p);
    }
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF455A64);
    canvas.drawRect(r, _p);
    _p.style = PaintingStyle.fill;

    // lampu di atas pintu
    final ly = r.top - 3.0;
    _p.color = const Color(0xFF37474F);
    canvas.drawRect(Rect.fromLTWH(r.center.dx - 1.8, ly - 0.5, 3.6, 1.6), _p);
    _p.color = Color.lerp(
        const Color(0xFFFFF59D), const Color(0xFFFFFFFF), night * 0.6)!;
    canvas.drawCircle(Offset(r.center.dx, ly + 1.4), 0.9, _p);

    // landai strip peringatan kuning-hitam di depan pintu
    if (!d.compact) {
      final ry = _gy + 1.0;
      _p.color = const Color(0xFF212121);
      canvas.drawRect(Rect.fromLTWH(r.left - 1, ry, r.width + 2, 1.6), _p);
      _p.color = const Color(0xFFFFCA28);
      for (var x = r.left - 1; x < r.right; x += 4) {
        canvas.drawPath(
          Path()
            ..moveTo(x, ry + 1.6)
            ..lineTo(x + 2, ry + 1.6)
            ..lineTo(x + 3.2, ry)
            ..lineTo(x + 1.2, ry)
            ..close(),
          _p,
        );
      }
    }
  }

  // ------------------------------------------------ komponen tambahan

  /// Kipas ventilasi atap (tier 2+): bilah tampak menyempit-melebar.
  void _whRoofFan(Canvas canvas, double x, double y, double ph) {
    _p.color = const Color(0xFF546E7A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 4, y - 3.6, 8, 3.6), const Radius.circular(1.2)),
      _p,
    );
    _p.color = const Color(0xFF263238);
    canvas.drawRect(Rect.fromLTWH(x - 3, y - 3.0, 6, 2.2), _p);
    final dx = math.cos(ph) * 2.6;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFCFD8DC);
    canvas.drawLine(Offset(x - dx, y - 1.9), Offset(x + dx, y - 1.9), _p);
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }

  /// Cerobong (tier 3).
  void _whChimney(Canvas canvas, double x, double y) {
    _p.color = const Color(0xFF6D4C41);
    canvas.drawRect(Rect.fromLTWH(x - 2.6, y - 12, 5.2, 12), _p);
    _p.color = const Color(0x22FFFFFF);
    canvas.drawRect(Rect.fromLTWH(x - 2.6, y - 12, 1.8, 12), _p);
    _p.color = const Color(0xFF3E2723);
    canvas.drawRect(Rect.fromLTWH(x - 3.4, y - 13.4, 6.8, 1.8), _p);
  }

  /// Lampu putar jingga: menyapu cahaya saat gudang bekerja.
  void _whBeacon(Canvas canvas, double t, double x, double y) {
    _p.color = const Color(0xFF37474F);
    canvas.drawRect(Rect.fromLTWH(x - 2, y - 1.4, 4, 1.4), _p);
    final k = 0.5 + 0.5 * math.sin(t * 7.5);
    _p.color = Color.lerp(
        const Color(0xFFE65100), const Color(0xFFFFB74D), k)!;
    canvas.drawArc(Rect.fromCircle(center: Offset(x, y - 1.4), radius: 2.2),
        math.pi, math.pi, true, _p);
    if (d.compact) return;
    _p.blendMode = BlendMode.plus;
    _p.color = const Color(0xFFFFA726).withValues(alpha: 0.30 * k);
    canvas.drawCircle(Offset(x, y - 2), 5.5, _p);
    _p.blendMode = BlendMode.srcOver;
    // berkas yang menyapu
    final ang = t * 5.0;
    final dx = math.cos(ang);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFCC80).withValues(alpha: 0.45 * dx.abs());
    canvas.drawLine(Offset(x, y - 2), Offset(x + dx * 9, y - 2.8), _p);
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }

  /// Koin kecil naik dari atap saat sampah diproses (laju mengikuti mesin).
  void _whCoins(Canvas canvas, double t, double x, double y, double run,
      int tier, int comps) {
    final sp = 0.26 + 0.42 * math.min(1.0, Wh.procRate(tier, comps) / 0.4);
    for (var k = 0; k < 3; k++) {
      final u = (t * sp + k / 3.0) % 1.0;
      final a = run * _ease(u / 0.12) * (1 - u) * (1 - u * 0.4);
      if (a <= 0.02) continue;
      final px = x + math.sin(u * 5.5 + k * 2.1) * 3.0 + (k - 1) * 4.0;
      final py = y - u * 22;
      final r = 1.5 + 0.7 * _easeOutBack(u / 0.2);
      _p.color = const Color(0xFFFFC107).withValues(alpha: a);
      canvas.drawCircle(Offset(px, py), r, _p);
      _p.color = const Color(0xFFFFE082).withValues(alpha: a);
      canvas.drawCircle(Offset(px - 0.4, py - 0.4), r * 0.55, _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.4
        ..color = const Color(0xFFFF8F00).withValues(alpha: a);
      canvas.drawCircle(Offset(px, py), r, _p);
      _p.style = PaintingStyle.fill;
    }
  }

  /// Asap tipis dari cerobong / penggilingan.
  void _whSmoke(Canvas canvas, double t, double x, double y, double run) {
    for (var k = 0; k < 4; k++) {
      final u = (t * 0.32 + k * 0.25) % 1.0;
      final a = 0.30 * run * _ease(u / 0.15) * (1 - u);
      if (a <= 0.01) continue;
      _p.color = const Color(0xFFB0BEC5).withValues(alpha: a);
      canvas.drawCircle(
        Offset(x + u * 6 + math.sin(u * 5 + k) * 1.3, y - u * 20),
        1.3 + u * 3.6,
        _p,
      );
    }
  }

  /// Pencacah: corong + rotor berputar (di atap). [ph] fase terintegrasi.
  void _whShredder(Canvas canvas, double t, double x, double y, double ph,
      double run) {
    final vib = math.sin(t * 46) * 0.22 * run;
    canvas.save();
    canvas.translate(vib, 0);
    _p.color = const Color(0xFF607D8B);
    canvas.drawRect(Rect.fromLTWH(x - 6, y - 7, 12, 7), _p);
    _p.color = const Color(0x22FFFFFF);
    canvas.drawRect(Rect.fromLTWH(x - 6, y - 7, 12, 1.6), _p);
    final fun = Path()
      ..moveTo(x - 8, y - 7)
      ..lineTo(x + 8, y - 7)
      ..lineTo(x + 4, y - 11)
      ..lineTo(x - 4, y - 11)
      ..close();
    _p.color = const Color(0xFFFFB300);
    canvas.drawPath(fun, _p);
    _p.color = const Color(0x33000000);
    canvas.drawRect(Rect.fromLTWH(x - 8, y - 7.6, 16, 0.6), _p);
    canvas.save();
    canvas.translate(x, y - 3.5);
    canvas.rotate(ph + 0.4);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFECEFF1);
    canvas.drawLine(const Offset(-3.2, 0), const Offset(3.2, 0), _p);
    canvas.drawLine(const Offset(0, -3.2), const Offset(0, 3.2), _p);
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xFF455A64);
    canvas.drawCircle(Offset.zero, 0.9, _p);
    canvas.restore();
    canvas.restore();
  }

  /// Penggilingan: drum horizontal bergaris yang berputar, pelet menumpuk.
  void _whGrinder(Canvas canvas, double t, double x, double y, double ph,
      double fill) {
    final r = Rect.fromLTWH(x - 9, y - 10, 18, 9);
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
    _p.color = const Color(0xFF8D6E63);
    canvas.drawRRect(rr, _p);
    canvas.save();
    canvas.clipRRect(rr);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF5D4037);
    final off = (ph * 1.0) % 5;
    for (var gx = r.left - 5 + off; gx < r.right; gx += 5) {
      canvas.drawLine(Offset(gx, r.bottom), Offset(gx + 4, r.top), _p);
    }
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0x2DFFFFFF);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 2.4), _p);
    _p.color = const Color(0x22000000);
    canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - 2.2, r.width, 2.2), _p);
    canvas.restore();
    // tumpukan pelet di sisi drum: makin banyak saat gudang makin penuh
    final n = 2 + (fill * 4).round();
    _p.color = const Color(0xFFBCAAA4);
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(
          Offset(x + 11 + (i % 4) * 1.5 + (i ~/ 4) * 0.6,
              y - 0.8 - (i % 2) * 0.9 - (i ~/ 4) * 1.4),
          1.0,
          _p);
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
    // kedipan halus (bukan on-off keras)
    final k = 0.5 + 0.5 * math.sin(t * 6);
    _p.style = PaintingStyle.fill;
    _p.color = Color.lerp(
        const Color(0xFF1B5E20), const Color(0xFF69F0AE), k * k)!;
    canvas.drawCircle(Offset(x, y - 16), 1.8, _p);
    if (!d.compact) {
      _p.blendMode = BlendMode.plus;
      _p.color = const Color(0xFF69F0AE).withValues(alpha: 0.28 * k * k);
      canvas.drawCircle(Offset(x, y - 16), 4.2, _p);
      _p.blendMode = BlendMode.srcOver;
    }
    for (var kk = 0; kk < 2; kk++) {
      final ph = (t * 0.9 + kk * 0.5) % 1.0;
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = const Color(0xFF69F0AE)
            .withValues(alpha: (1 - ph) * 0.8 * _ease(ph / 0.1));
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

  /// Ban berjalan di dasar dinding depan. [ph] = jarak geser terintegrasi.
  void _whConveyor(Canvas canvas, double x, double w, double ph) {
    _p.color = const Color(0xFF37474F);
    canvas.drawRect(Rect.fromLTWH(x, _gy - 5, w, 4), _p);
    _p.color = const Color(0x22FFFFFF);
    canvas.drawRect(Rect.fromLTWH(x, _gy - 5, w, 0.8), _p);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(x, _gy - 5, w, 4));
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFFFCA28);
    for (var k = 0.0; k < w + 6; k += 6) {
      final px = x + ((k + ph) % (w + 6)) - 3;
      canvas.drawLine(Offset(px, _gy - 4.6), Offset(px + 1.4, _gy - 3), _p);
      canvas.drawLine(Offset(px + 1.4, _gy - 3), Offset(px, _gy - 1.4), _p);
    }
    _p.style = PaintingStyle.fill;
    canvas.restore();
    // rol ujung
    _p.color = const Color(0xFF78909C);
    canvas.drawCircle(Offset(x, _gy - 3), 2.0, _p);
    canvas.drawCircle(Offset(x + w, _gy - 3), 2.0, _p);
  }

  /// Penyortir: tiga tong warna di halaman depan; tutupnya bergerak kecil
  /// bergantian saat gudang bekerja.
  void _whSorter(Canvas canvas, double t, double x, double run) {
    const cols = [Color(0xFFE53935), Color(0xFFFDD835), Color(0xFF1E88E5)];
    for (var i = 0; i < 3; i++) {
      final bx = x + i * 7.0;
      final lift = run * math.max(0.0, math.sin(t * 2.2 + i * 2.1)) * 1.1;
      _p.color = cols[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, _gy - 9, 6, 11), const Radius.circular(1.2)),
        _p,
      );
      _p.color = const Color(0x22FFFFFF);
      canvas.drawRect(Rect.fromLTWH(bx + 0.5, _gy - 8.5, 1.4, 10), _p);
      _p.color = const Color(0x44000000);
      canvas.drawRect(
          Rect.fromLTWH(bx - 0.4, _gy - 9.6 - lift, 6.8, 1.6), _p);
    }
  }

  /// Jembatan timbang: pelat di depan pintu + kotak layar digital.
  void _whScale(Canvas canvas, double t, double cx, double open) {
    _p.color = const Color(0xFF78909C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 15, _gy + 1.5, 30, 3.2), const Radius.circular(1)),
      _p,
    );
    _p.color = const Color(0x33FFFFFF);
    canvas.drawRect(Rect.fromLTWH(cx - 15, _gy + 1.5, 30, 0.8), _p);
    _p.color = const Color(0xFF263238);
    canvas.drawRect(Rect.fromLTWH(cx + 17, _gy - 8, 8, 10), _p);
    // layar menyala terang saat menimbang (pintu terbuka)
    final k = 0.55 + 0.45 * math.sin(t * 3);
    _p.color = Color.lerp(
        const Color(0xFF2E7D32), const Color(0xFF69F0AE), open > 0.1 ? 1.0 : k * 0.6)!;
    canvas.drawRect(Rect.fromLTWH(cx + 18.5, _gy - 6.5, 5, 3), _p);
    _p.color = const Color(0xFF69F0AE).withValues(alpha: 0.5);
    canvas.drawRect(Rect.fromLTWH(cx + 18.9, _gy - 2.2, 1.0, 1.0), _p);
    canvas.drawRect(Rect.fromLTWH(cx + 20.6, _gy - 2.2, 1.0, 1.0), _p);
  }

  // ----------------------------------------------- gerobak tuang sampah

  /// Gerobak membawa isi kotak kiri menyusuri trotoar, menuang ke gudang,
  /// lalu kembali. [u] 0..1 = progres animasi.
  void _whPourCart(Canvas canvas, double t, WhLive w, double u) {
    final doorX = _whDoorX(w.tier);
    final endX = doorX - 15;
    const y = _gy + 10.0; // trotoar depan kost
    const bagsN = 4;
    final startX = _whBinX + 8;
    final span = endX - startX;

    double x;
    double dir; // +1 ke kanan, -1 ke kiri
    var spd = 0.0; // 0..1 laju jalan (nol saat diam)
    var trav = 0.0; // jarak tempuh (untuk roda & langkah)
    var tip = 0.0;
    var loaded = 0.0; // 0..1 fraksi kantong di gerobak
    if (u < 0.22) {
      x = startX;
      dir = 1;
      loaded = _ease(u / 0.20);
    } else if (u < 0.58) {
      final q = (u - 0.22) / 0.36;
      x = _lerp(startX, endX, _easeInOut3(q));
      dir = 1;
      spd = math.sin(q * math.pi).clamp(0.0, 1.0).toDouble();
      trav = x - startX;
      loaded = 1;
    } else if (u < 0.84) {
      x = endX;
      dir = 1;
      trav = span;
      tip = _ease((u - 0.58) / 0.08) * (1 - _ease((u - 0.76) / 0.08));
      loaded = 1;
    } else {
      final q = (u - 0.84) / 0.16;
      x = _lerp(endX, startX, _easeInOut3(q));
      dir = -1;
      spd = math.sin(q * math.pi).clamp(0.0, 1.0).toDouble();
      trav = span + (endX - x);
    }
    final alpha = u > 0.96 ? 1 - (u - 0.96) / 0.04 : 1.0;
    final moving = spd > 0.02;

    // bayangan di tanah mengikuti gerobak
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0x26000000).withValues(alpha: 0.15 * alpha);
    canvas.drawOval(Rect.fromCenter(center: Offset(x - 4, y + 0.6), width: 38, height: 3.2), _p);

    final bob = moving ? math.sin(trav * 0.9) * 0.45 * spd : 0.0;
    canvas.save();
    canvas.translate(x, y + bob);
    canvas.scale(dir, 1);
    if (alpha < 1) {
      canvas.saveLayer(const Rect.fromLTWH(-40, -40, 80, 50),
          Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    }

    // pekerja (di belakang gerobak): langkah mengikuti jarak, condong maju
    final stride = math.sin(trav * 0.55) * (0.6 + 2.4 * spd);
    final lean = 0.9 * spd;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF37474F);
    canvas.drawLine(const Offset(-19, -7), Offset(-19 + stride, -0.2 - (stride < 0 ? stride * 0.12 : 0)), _p);
    canvas.drawLine(const Offset(-19, -7), Offset(-19 - stride, -0.2 - (stride > 0 ? -stride * 0.12 : 0)), _p);
    // lengan mendorong gagang
    _p
      ..strokeWidth = 1.3
      ..color = const Color(0xFFE64A19);
    canvas.drawLine(Offset(-19 + lean, -14.2), Offset(-15.6, -8.6 + tip * 1.5), _p);
    _p
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.fill;
    _p.color = const Color(0xFFFF7043); // rompi
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-21.5 + lean, -16, 5, 9), const Radius.circular(1.2)),
      _p,
    );
    _p.color = const Color(0xFFFFEE58); // strip reflektif
    canvas.drawRect(Rect.fromLTWH(-21.5 + lean, -12.4, 5, 0.9), _p);
    _p.color = const Color(0xFFFFCC80);
    canvas.drawCircle(Offset(-19 + lean * 1.2, -19), 2.6, _p);
    _p.color = const Color(0xFFFFC107); // helm
    canvas.drawArc(
        Rect.fromCircle(center: Offset(-19 + lean * 1.2, -19), radius: 3.0),
        math.pi,
        math.pi,
        true,
        _p);

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
    _p.color = const Color(0x26FFFFFF);
    canvas.drawPath(
      Path()
        ..moveTo(-9, -12)
        ..lineTo(11, -12)
        ..lineTo(10.2, -9.6)
        ..lineTo(-8.2, -9.6)
        ..close(),
      _p,
    );
    _p.color = const Color(0xFF2E7D32);
    canvas.drawRect(const Rect.fromLTWH(-9, -12.8, 20, 1.6), _p);

    // kantong di gerobak: muncul berurutan dengan efek "pop"; yang sudah
    // jatuh ke gudang tidak digambar lagi
    final lf = loaded * bagsN;
    for (var i = 0; i < bagsN; i++) {
      final pop = _easeOutBack(lf - i);
      if (pop <= 0.02) continue;
      if (u >= 0.64 + i * 0.03) continue;
      _bag(canvas, Offset(-4 + i * 4.2, -13.5 - (i % 2) * 1.8), 640 + i,
          scale: 0.55 * pop.clamp(0.0, 1.15).toDouble());
    }
    canvas.restore();

    // roda: jari-jari berputar sesuai jarak tempuh
    _p.color = const Color(0xFF212121);
    canvas.drawCircle(const Offset(7, -3), 3, _p);
    _p.color = const Color(0xFF9E9E9E);
    canvas.drawCircle(const Offset(7, -3), 1.1, _p);
    final wa = trav / 3.0;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = const Color(0xFF757575);
    canvas.drawLine(Offset(7 + math.cos(wa) * 2.4, -3 + math.sin(wa) * 2.4),
        Offset(7 - math.cos(wa) * 2.4, -3 - math.sin(wa) * 2.4), _p);
    _p.style = PaintingStyle.fill;

    if (alpha < 1) canvas.restore();
    canvas.restore();

    // debu kecil di kaki saat jalan cepat
    if (moving && spd > 0.35) {
      for (var k = 0; k < 3; k++) {
        final pu = (t * 2.2 + k / 3.0) % 1.0;
        _p.color = const Color(0xFFBCAAA4)
            .withValues(alpha: 0.30 * (1 - pu) * spd * alpha);
        canvas.drawCircle(
          Offset(x - dir * (20 + pu * 7), y - 0.6 - pu * 2.6),
          0.8 + pu * 1.5,
          _p,
        );
      }
    }

    // kantong yang jatuh dari gerobak ke pintu gudang (koordinat dunia)
    if (u >= 0.62 && u < 0.90) {
      for (var i = 0; i < bagsN; i++) {
        final t0 = 0.64 + i * 0.03;
        final q = ((u - t0) / 0.10).clamp(0.0, 1.0).toDouble();
        if (q > 0 && q < 1) {
          // lintasan parabola: lambat di puncak, mempercepat saat turun
          final px = _lerp(endX + 9 + i * 2, doorX, _ease(q));
          final py = _lerp(y - 12, _gy - 5, q * q) - math.sin(q * math.pi) * 8;
          canvas.save();
          canvas.translate(px, py);
          canvas.rotate((q * 2.4 + i) * (i.isEven ? 1 : -1));
          _bag(canvas, Offset.zero, 640 + i, scale: 0.55);
          canvas.restore();
        }
        // debu saat mendarat di pintu
        final lt = (u - t0 - 0.10) / 0.07;
        if (lt > 0 && lt < 1 && !d.compact) {
          for (var k = 0; k < 4; k++) {
            final a = (k - 1.5) * 0.9;
            _p.color = const Color(0xFFCFD8DC)
                .withValues(alpha: 0.55 * (1 - lt) * (1 - lt));
            canvas.drawCircle(
              Offset(doorX + a * (2 + lt * 5), _gy - 3 - lt * 3 - (k % 2) * 1.2),
              0.8 + lt * 1.8,
              _p,
            );
          }
        }
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
    // Truk gudang masuk dari KIRI dan keluar ke KANAN (kebalikan truk angkut).
    final inX = math.max(math.min(vl - 110, parkX - 220), parkX - 1000);
    final outX = math.min(math.max(vr + 110, parkX + 220), parkX + 1000);
    final inVisible = inX > vl - 40;
    final outVisible = outX < vr + 40;

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
    final bob = moving ? math.sin(t * 24) * 0.7 : math.sin(t * 38) * 0.22;
    final hatch = _ease(vis * 1.6);
    final load = _c01((hp - 0.25) / 0.5); // isi kontainer 0..1

    // peluncur dari pintu gudang ke bak truk + kantong yang meluncur
    if (vis > 0.02) {
      final doorX = _whDoorX(w.tier);
      final from = Offset(doorX, _gy - 2);
      final to = Offset(x - 14, _roadY - 56);
      // penyangga peluncur
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF546E7A).withValues(alpha: vis);
      for (final k in const [0.35, 0.7]) {
        final pt = Offset.lerp(from, to, k)!;
        canvas.drawLine(pt, Offset(pt.dx, _gy + 3), _p);
      }
      _p
        ..strokeWidth = 3.6
        ..color = const Color(0xFF546E7A).withValues(alpha: vis);
      canvas.drawLine(from, to, _p);
      _p
        ..strokeWidth = 3.0
        ..color = const Color(0xFF78909C).withValues(alpha: vis);
      canvas.drawLine(from, to, _p);
      _p
        ..strokeWidth = 1.1
        ..color = const Color(0xFFCFD8DC).withValues(alpha: vis);
      canvas.drawLine(from, to, _p);
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt;
      if (vis > 0.3) {
        for (var k = 0; k < 4; k++) {
          // meluncur dengan percepatan, berguling pelan
          final q = (t * 0.55 + k * 0.25) % 1.0;
          final e = q * q * 0.6 + q * 0.4;
          final bp = Offset.lerp(from, to, e)!;
          final fade = _ease(q / 0.12) * (1 - _ease((q - 0.88) / 0.12));
          if (fade <= 0.02) continue;
          canvas.save();
          canvas.translate(bp.dx, bp.dy - 3);
          canvas.rotate(math.sin(q * 6 + k) * 0.35);
          _bag(canvas, Offset.zero, 900 + k, scale: 0.6 * fade * vis);
          canvas.restore();
        }
      }
    }

    _fadeLayer(
      canvas,
      Rect.fromLTRB(x - 130, _roadY - 100, x + 130, _roadY + 16),
      alpha,
          () {
        canvas.save();
        canvas.translate(x, _roadY);
        _whTruckBody(
          canvas,
          t,
          wheelA: x / 6.5,
          lean: lean,
          moving: moving,
          brake: brake,
          hatch: hatch,
          load: load,
          loading: vis > 0.3,
          bob: bob,
        );
        canvas.restore();
      },
    );

    if (vis > 0.3) {
      _drawBannerText(
        canvas,
        'TRUK GUDANG',
        Offset(x - 14, _roadY - 110),
        const Color(0xFFFFB74D),
        alpha: vis,
      );
    }
  }

  /// Truk gudang: kontainer jingga menghadap KANAN, kabin datar di kanan,
  /// tiga as roda, lampu strobo berputar, palka atap yang membuka saat
  /// memuat, pegas yang ambles seiring isi, dan indikator isi di sisi bak.
  /// Titik asal: tengah-bawah di tanah.
  void _whTruckBody(
      Canvas canvas,
      double t, {
        required double wheelA,
        required double lean,
        required bool moving,
        required bool brake,
        required double hatch,
        required double load,
        required bool loading,
        required double bob,
      }) {
    // bayangan
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0x38000000);
    canvas.drawOval(const Rect.fromLTWH(-50, -3, 100, 6), _p);

    // roda (tiga as): 2 belakang, 1 depan
    void wheel(double cx) {
      canvas.save();
      canvas.translate(cx, -6.5 + bob * 0.4);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF212121);
      canvas.drawCircle(Offset.zero, 6.5, _p);
      canvas.rotate(-wheelA);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFFB0BEC5);
      for (var k = 0; k < 3; k++) {
        final a = k * math.pi / 3;
        canvas.drawLine(Offset(math.cos(a) * 4.2, math.sin(a) * 4.2),
            Offset(-math.cos(a) * 4.2, -math.sin(a) * 4.2), _p);
      }
      _p.style = PaintingStyle.fill;
      _p.color = const Color(0xFFFFB300);
      canvas.drawCircle(Offset.zero, 1.6, _p);
      canvas.restore();
    }

    wheel(-32);
    wheel(-14);
    wheel(28);

    // bodi: ambles saat terisi + goyang kecil saat peluncur menghantam
    final sink = load * 2.2;
    final shake = loading && !moving ? math.sin(t * 31) * 0.35 : 0.0;
    canvas.save();
    canvas.translate(shake, bob - sink);
    canvas.rotate(-lean);

    // sasis
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF37474F);
    canvas.drawRect(const Rect.fromLTWH(-46, -15, 94, 5), _p);

    // kontainer
    final box = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-46, -56, 62, 42), const Radius.circular(2));
    _p.color = const Color(0xFFF57C00);
    canvas.drawRRect(box, _p);
    _p.color = const Color(0xFFFFA726);
    canvas.drawRect(const Rect.fromLTWH(-46, -56, 62, 5), _p);
    // rusuk vertikal
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFE65100);
    for (var xx = -38.0; xx < 14; xx += 8) {
      canvas.drawLine(Offset(xx, -50), Offset(xx, -21), _p);
    }
    // strip bahaya hitam-kuning di bawah
    _p.style = PaintingStyle.fill;
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(-46, -21, 62, 6));
    _p.color = const Color(0xFFFFEB3B);
    canvas.drawRect(const Rect.fromLTWH(-46, -21, 62, 6), _p);
    _p.color = const Color(0xFF212121);
    for (var xx = -52.0; xx < 18; xx += 10) {
      final path = Path()
        ..moveTo(xx, -15)
        ..lineTo(xx + 5, -15)
        ..lineTo(xx + 11, -21)
        ..lineTo(xx + 6, -21)
        ..close();
      canvas.drawPath(path, _p);
    }
    canvas.restore();

    // indikator isi di sisi bak
    _p.color = const Color(0xFF263238);
    canvas.drawRect(const Rect.fromLTWH(-42, -46, 7, 22), _p);
    _p.color = Color.lerp(const Color(0xFF66BB6A), const Color(0xFFEF5350), load)!;
    final fh = 20 * load;
    canvas.drawRect(Rect.fromLTWH(-41, -25 - fh, 5, fh), _p);

    // atap + palka yang membuka
    _p.color = const Color(0xFF455A64);
    canvas.drawRect(const Rect.fromLTWH(-48, -58, 66, 3), _p);
    // tumpukan sampah menyembul dari palka saat terisi
    if (hatch > 0.5 && load > 0.1) {
      _p.color = const Color(0xFF2E7D32);
      canvas.drawOval(Rect.fromLTWH(-26, -62 - 3 * load, 16, 6 + 3 * load), _p);
    }
    canvas.save();
    canvas.translate(-26, -58);
    canvas.rotate(-hatch * 1.25);
    _p.color = const Color(0xFF78909C);
    canvas.drawRect(const Rect.fromLTWH(0, -2, 16, 2.4), _p);
    canvas.restore();

    // kabin
    final cab = Path()
      ..moveTo(18, -15)
      ..lineTo(18, -46)
      ..lineTo(34, -46)
      ..lineTo(43, -31)
      ..lineTo(48, -29)
      ..lineTo(48, -15)
      ..close();
    _p.color = const Color(0xFFECEFF1);
    canvas.drawPath(cab, _p);
    _p.color = const Color(0xFFFF9800);
    canvas.drawRect(const Rect.fromLTWH(18, -21, 30, 6), _p);
    final win = Path()
      ..moveTo(22, -42)
      ..lineTo(33, -42)
      ..lineTo(40, -31)
      ..lineTo(22, -31)
      ..close();
    _p.color = const Color(0xFF4FC3F7);
    canvas.drawPath(win, _p);
    _p.color = const Color(0x55FFFFFF);
    canvas.drawRect(const Rect.fromLTWH(24, -41, 3, 9), _p);

    // lampu depan (+ sorot) & lampu rem
    _p.color = const Color(0xFFFFF59D);
    canvas.drawRect(const Rect.fromLTWH(46, -25, 3, 4), _p);
    if (moving) {
      _p.color = const Color(0x33FFF59D);
      final beam = Path()
        ..moveTo(49, -24)
        ..lineTo(76, -30)
        ..lineTo(76, -12)
        ..close();
      canvas.drawPath(beam, _p);
    }
    _p.color = brake ? const Color(0xFFFF1744) : const Color(0xFF8E0000);
    canvas.drawRect(const Rect.fromLTWH(-47, -25, 2, 6), _p);

    // lampu strobo berputar di atap kabin
    final spin = t * 9;
    final on = math.sin(spin) > 0;
    _p.color = const Color(0xFF424242);
    canvas.drawRect(const Rect.fromLTWH(24, -49, 8, 3), _p);
    _p.color = on ? const Color(0xFFFFAB00) : const Color(0xFF8D5A00);
    canvas.drawCircle(const Offset(28, -51), 2.4, _p);
    if (on) {
      _p.color = const Color(0x44FFAB00);
      canvas.drawCircle(const Offset(28, -51), 8, _p);
    }
    final bx = math.cos(spin) * 7;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x66FFAB00);
    canvas.drawLine(const Offset(28, -51), Offset(28 + bx, -53), _p);
    _p.style = PaintingStyle.fill;

    // knalpot tegak + asap saat jalan / tancap gas
    _p.color = const Color(0xFF616161);
    canvas.drawRect(const Rect.fromLTWH(15, -56, 2.4, 20), _p);
    if (moving) {
      for (var k = 0; k < 3; k++) {
        final q = (t * 1.6 + k / 3) % 1.0;
        _p.color = Color.fromRGBO(120, 120, 120, 0.4 * (1 - q));
        canvas.drawCircle(
            Offset(16 - q * 14, -58 - q * 10), 2 + q * 3.5, _p);
      }
    }

    canvas.restore();

    // debu di roda saat jalan
    if (moving) {
      for (var k = 0; k < 3; k++) {
        final q = (t * 2.2 + k / 3) % 1.0;
        _p.color = Color.fromRGBO(190, 170, 140, 0.35 * (1 - q));
        canvas.drawCircle(Offset(-40 - q * 14, -3 - q * 5), 1.5 + q * 2.5, _p);
      }
    }
  }
}