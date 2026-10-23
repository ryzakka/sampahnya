part of 'kost_scene.dart';

final TextPainter _signReg = _makeSign('KOST', Colors.white);
final TextPainter _signExc =
_makeSign('EKSKLUSIF', const Color(0xFF80D8FF));
final TextPainter _signSul =
_makeSign('SULTAN', const Color(0xFFFFD54F));

/// Papan nama buatan pemain (di-cache: teks sama = TextPainter sama).
final Map<String, TextPainter> _signCache = <String, TextPainter>{};
TextPainter _customSign(String text) => _signCache.putIfAbsent(
    text, () => _makeSign(text, Colors.white));

TextPainter _makeSign(String text, Color color) => TextPainter(
  text: TextSpan(
    text: text,
    style: TextStyle(
      color: color,
      fontSize: text.length > 6 ? 7.2 : 8.8,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.0,
    ),
  ),
  textDirection: TextDirection.ltr,
)..layout();

// Urutan slot kantong sampah ketika MELUBER:
// 1) Meluber tepat di sekitar area kotak sampah/fasilitas (kiri bangunan) terlebih dahulu
// 2) Merembet ke sisi kanan bangunan
// 3) Menimbun halaman depan kost
final List<Offset> _slots = _buildSlots();

// Gundukan sampah di ATAP (dx, dy relatif terhadap garis atap). Hanya
// tampil di rumah yang tertimbun - dan jadi sasaran longsoran sinematik.
final List<Offset> _roofSlots = _buildRoofSlots();

List<Offset> _buildRoofSlots() {
  final s = <Offset>[];
  for (var r = 0; r < 5; r++) {
    final n = 17 - r * 2;
    for (var i = 0; i < n; i++) {
      s.add(Offset(112.0 + r * 9.0 + i * 10.8, -5.0 - r * 7.5));
    }
  }
  return s;
}

List<Offset> _buildSlots() {
  final s = <Offset>[];
  // Tahap 1: Meluber di sekitar kotak sampah (sisi kiri: x 20..96)
  for (var r = 0; r < 5; r++) {
    final n = 7 - r;
    for (var i = 0; i < n; i++) {
      final x = 88.0 - r * 4.5 - i * 10.5;
      final y = 254.0 - r * 7.5;
      s.add(Offset(x, y));
    }
  }
  // Tahap 2: Meluber ke sisi kanan bangunan (x 312..386)
  for (var r = 0; r < 6; r++) {
    final n = 8 - r;
    for (var i = 0; i < n; i++) {
      final x = 314.0 + r * 5.0 + i * 10.5;
      final y = 252.0 - r * 8.0;
      s.add(Offset(x, y));
    }
  }
  // Tahap 3: Menimbun halaman depan kost (x 112..290)
  for (var k = 0; k < 3; k++) {
    for (var i = 0; i < 17 - k; i++) {
      s.add(Offset(112 + k * 6.0 + i * 10.8, 262 - k * 8.0));
    }
  }
  return s;
}

final TextPainter _tapeText = TextPainter(
  text: const TextSpan(
    text: 'GARIS POLISI ★ DILARANG MELINTAS ★ ',
    style: TextStyle(
      color: Color(0xFF1B1B1B),
      fontSize: 5.0,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.3,
    ),
  ),
  textDirection: TextDirection.ltr,
)..layout();

final TextPainter _saleText = TextPainter(
  text: const TextSpan(
    text: 'DIJUAL',
    style: TextStyle(
      color: Colors.white,
      fontSize: 7.5,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.6,
    ),
  ),
  textDirection: TextDirection.ltr,
)..layout();

final TextPainter _sealText = TextPainter(
  text: const TextSpan(
    text: 'DISEGEL',
    style: TextStyle(
      color: Color(0xFFB71C1C),
      fontSize: 4.6,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.4,
    ),
  ),
  textDirection: TextDirection.ltr,
)..layout();

const List<Color> _shirts = [
  Color(0xFF42A5F5),
  Color(0xFFEF5350),
  Color(0xFF66BB6A),
  Color(0xFFAB47BC),
];
const List<double> _spotX = [150.0, 252.0, 120.0, 284.0];
const List<double> _spotY = [265.0, 268.0, 270.0, 264.0];
const double _doorX = 201;
final Map<String, TextPainter> _iconCache = <String, TextPainter>{};

const double _roadY = 297.0; // garis jalan (koordinat rumah)
const double _parkX = 318.0; // titik parkir truk angkut

const double _roofHover = 30;

class KostPainter extends CustomPainter {
  KostPainter(this.d, Listenable repaint, {this.insets = EdgeInsets.zero})
      : super(repaint: repaint);

  final KostSceneData d;
  final EdgeInsets insets;
  final Paint _p = Paint();

  double _vl = 0, _vr = _w, _vt = 0, _vb = _h;
  Rect get _view => Rect.fromLTRB(_vl, _vt, _vr, _vb);

  // --- khusus mode jalan (beberapa rumah berderet dalam satu kamera) ---
  // Pada mode normal semua bernilai default sehingga perilaku lama tidak berubah.
  bool _street = false;
  double _streetW = _w; // lebar total dunia (jumlah rumah x 400)
  double _sunX = 334;
  double _fxScale = 1.0; // pembesar partikel cuaca saat kamera menjauh


  int get _floors => math.min(3, math.max(1, (d.rooms / 4).ceil()));
  double get _roofY => _gy - _floors * _fh;
  bool get _critical => d.trashRatio >= 0.9 && !d.eliminated;

  /// Tingkat kepenuhan di DALAM kotak sampah (0.0 .. 1.0).
  /// Mencapai 1.0 (penuh) ketika rasio sampah menyentuh 1/3 (33.3%).
  double get _binFill {
    if (d.wasteLevel <= 0) return 0.0;
    if (d.eliminated) return 1.0;
    return _c01(d.trashRatio / (1.0 / 3.0));
  }

  /// Rasio sampah yang MELUBER keluar dari kotak sampah (0.0 .. 1.0).
  /// Jika punya fasilitas kotak sampah (wasteLevel > 0), bernilai 0 selama trashRatio <= 1/3.
  double get _overflowRatio {
    if (d.eliminated) return 1.0;
    if (d.wasteLevel <= 0) return _c01(d.trashRatio);
    const threshold = 1.0 / 3.0;
    if (d.trashRatio <= threshold) return 0.0;
    return _c01((d.trashRatio - threshold) / (1.0 - threshold));
  }

  // ------------------------------------------------ siklus siang-malam
  //
  // Semua turunan dari [KostSceneData.dayPhase]. Bila null (lobi, kustomisasi,
  // intro) hasilnya = siang tetap sehingga tampilan lama tidak berubah.

  /// Ketinggian matahari -1..1 (1 = zenit, -1 = titik terendah di bawah tanah).
  double get _sunElev =>
      d.dayPhase == null ? 1.0 : -math.cos(2 * math.pi * d.dayPhase!);

  /// Gelap malam 0..1 (halus; 1 = malam penuh).
  double get _night {
    if (d.dayPhase == null) return 0.0;
    final n = _c01((0.05 - _sunElev) / 0.35);
    return n * n * (3 - 2 * n);
  }

  /// Kekuatan semburat senja/fajar 0..1 (puncak saat matahari di horizon).
  double get _dusk =>
      d.dayPhase == null ? 0.0 : 1 - _c01(_sunElev.abs() / 0.45);

  /// Matahari/bulan: posisi melengkung melintasi langit. [a] = sudut busur
  /// (0 = terbit di kiri, pi/2 = puncak, pi = terbenam di kanan).
  Offset _celestialAt(double a) {
    final cx = (_vl + _vr) / 2;
    final half = (_vr - _vl) * 0.38;
    return Offset(cx - math.cos(a) * half, (_gy - 18) - math.sin(a) * (_gy - 62));
  }

  double get _litFactor {
    final r = d.trashRatio;
    final base = r >= 0.9 ? 0.3 : (r >= 0.75 ? 0.6 : (r >= 0.5 ? 0.85 : 1.0));
    // Siang: hanya sebagian jendela menyala; malam: semua (kecuali kondisi buruk).
    final dayK = d.dayPhase == null ? 1.0 : 0.4 + 0.6 * _night;
    return math.min(base, d.lights) * dayK;
  }

  /// Apakah jendela kamar [idx] menyala (dipakai gambar jendela & kilau malam).
  bool _roomLit(int idx, double t) {
    final flicker = _critical && math.sin(t * 17 + idx * 2.3) > 0.82;
    return !d.eliminated && !flicker && ((_hh(idx) % 100) / 100) < _litFactor;
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

  void _drawBannerText(Canvas canvas, String label, Offset pos, Color color,
      {double scale = 1.0, double alpha = 1.0}) {
    if (alpha <= 0.02 || d.compact) return;
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(scale);
    final a = _c01(alpha);
    // Lapisan kontur hitam agar teks "meledak" dan terbaca jelas
    final outline = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.black.withValues(alpha: a * 0.9),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color.withValues(alpha: a),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
          shadows: [
            Shadow(
              color: color.withValues(alpha: a * 0.7),
              blurRadius: 10,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    outline.paint(canvas, Offset(-outline.width / 2, -outline.height / 2));
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant KostPainter oldDelegate) => true;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = sceneNowMs() / 1000.0;

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

    final sh = _shakeOffset(t);
    if (sh != Offset.zero) {
      canvas.translate(sh.dx, sh.dy);
    }

    final p = _c01(d.pollution / 100);
    _drawSky(canvas, t, p);
    _drawHills(canvas, p);
    _drawSkyline(canvas, p);
    _drawTrees(canvas, t, p);
    _drawGodRays(canvas, t, p);
    _drawGround(canvas, t, p);
    _drawWorldEventBack(canvas, t);
    _drawCars(canvas, t);
    _drawBuilding(canvas, t);
    _drawBountyCrown(canvas, t);
    _drawWasteFacility(canvas, t);
    _drawFleeing(canvas, t);
    _drawDefense(canvas, t);
    _drawBags(canvas);
    _drawResidents(canvas, t);
    _drawOwner(canvas, t);
    _drawRats(canvas, t);
    _drawStinkAndFlies(canvas, t);
    _drawCrows(canvas, t);
    _drawTruck(canvas, t);
    _drawInspectAndSeal(canvas, t);
    _drawFire(canvas, t);
    _drawCollapse(canvas);
    _drawBuriedCine(canvas, t);
    _drawCrane(canvas, t);
    _drawThrown(canvas, t);
    _drawParry(canvas, t);
    _drawWorldEventFront(canvas, t);
    _drawAsh(canvas, t, p);
    _drawHaze(canvas, p);
    _drawConfetti(canvas, t);
    _drawVignette(canvas, t, p);
    _drawEmojiReactions(canvas, t);
    _drawCinematic(canvas, t);

    _drawStateFrames(canvas, t);

    canvas.restore();
  }

  // --------------------------------------------- guncangan & bingkai status

  /// Guncangan kamera per rumah (dibangun, tier naik, kena lemparan, dibajak...).
  Offset _shakeOffset(double t) {
    final collapseShake = _fxProgress(FxType.collapse, 1500);
    final buildP = _buildP;
    final incomingP = _fxProgress(FxType.incoming, 1600);
    final tierP = _fxProgress(FxType.tier, 2400);

    double shakeX = 0, shakeY = 0;
    if (collapseShake != null) {
      shakeX += math.sin(collapseShake * 65) * 5 * (1 - collapseShake);
      shakeY += math.cos(collapseShake * 50) * 3 * (1 - collapseShake);
    }
    if (buildP != null) {
      if (_isFloorBuild) {
        // atap mendarat di lantai baru
        if (buildP > 0.85 && buildP < 0.95) {
          final q = 1 - (buildP - 0.85) / 0.10;
          shakeY += math.sin(buildP * 170) * 3.6 * q;
          shakeX += math.cos(buildP * 120) * 1.8 * q;
        }
      } else if (buildP > 0.72 && buildP < 0.80) {
        // "ting" kecil saat kamar selesai
        final q = 1 - (buildP - 0.72) / 0.08;
        shakeY += math.sin(buildP * 150) * 1.2 * q;
      }
    }
    if (tierP != null && tierP < 0.45) {
      final q = 1 - tierP / 0.45;
      shakeY += math.sin(tierP * 100) * 2.8 * q;
    }
    if (incomingP != null && incomingP > 0.44 && incomingP < 0.8) {
      final q = 1 - (incomingP - 0.44) / 0.36;
      shakeX += math.sin(incomingP * 110) * 3.2 * q;
    }
    // Guncangan kamera saat truk dibajak (hanya di sisi korban)
    final hj = _hijackFx();
    if (hj != null && hj.amount.round() != 1) {
      final hl = _hijackTimes(hj);
      final gp = (hj.age - hl.a) / hl.g; // kemajuan fase perebutan
      if (gp > 0.2 && gp < 0.6) {
        final q = 1 - (gp - 0.2) / 0.4;
        shakeX += math.sin(gp * 220) * 3.0 * q;
        shakeY += math.cos(gp * 180) * 2.2 * q;
      }
    }
    // Rumah bergetar makin keras sebelum runtuh
    final bAge = d.buriedAgeMs;
    if (bAge != null && bAge < kBuriedCollapseMs) {
      final q = _c01((bAge - 1200) / 3400.0);
      shakeX += math.sin(bAge * 0.09) * 2.6 * q;
      shakeY += math.cos(bAge * 0.13) * 1.7 * q;
    }
    // Guncangan saat segel polisi dihantam ke pintu
    final pAge = d.policeAgeMs;
    if (pAge != null) {
      final q = (pAge - (kPoliceTapeEndMs + 500)) / 650.0;
      if (q > 0 && q < 1) {
        shakeX += math.sin(q * 90) * 3.4 * (1 - q);
        shakeY += math.cos(q * 70) * 2.4 * (1 - q);
      }
    }
    // Napas kamera halus agar adegan terasa hidup
    if (!d.compact) {
      shakeX += math.sin(t * 0.55) * 0.8;
      shakeY += math.cos(t * 0.42) * 0.5;
    }
    return Offset(shakeX, shakeY);
  }

  /// Bingkai peringatan: serangan masuk, kritis, dan penggelapan saat tertimbun.
  void _drawStateFrames(Canvas canvas, double t) {
    // Peringatan serangan masuk: bingkai merah berdenyut cepat (jendela Tangkis)
    if (d.attackLeft > 0 && !d.eliminated) {
      final pulse = 0.5 + 0.5 * math.sin(t * 20);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..color = const Color(0xFFFF1744).withValues(alpha: 0.18 + 0.4 * pulse);
      canvas.drawRect(_view, _p);
      _p.style = PaintingStyle.fill;
      _drawBannerText(
        canvas,
        'SERANGAN MASUK! TANGKIS!',
        Offset(200, _roofY - 56),
        const Color(0xFFFF5252),
        scale: 1.1 + 0.12 * pulse,
      );
    }

    if (_critical) {
      final pulse = 0.5 + 0.5 * math.sin(t * 6);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color =
        const Color(0xFFD32F2F).withValues(alpha: 0.12 + 0.25 * pulse);
      canvas.drawRect(_view, _p);
      _p.style = PaintingStyle.fill;
    }
    if (d.eliminated) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF1E1E1E).withValues(alpha: 0.4);
      canvas.drawRect(_view, _p);
    }
  }

  List<_Res> _resOut = <_Res>[];
  final Set<int> _resOutRooms = <int>{};
  int _resMode = 0; // 0 tenang, 1 marah, 2 bau, 3 batuk, 4 tertimbun
  int _resMask = 0; // 0 tanpa, 1 masker, 2 masker gas
  bool _resSign = false;
}

/// Langit, tanah, malam, cuaca, kejadian dunia & mobil.
extension KostPainterScenery on KostPainter {
  // ============================================================ MODE JALAN
  //
  // Beberapa rumah berderet dalam SATU adegan. Instance painter dipakai per
  // lapisan oleh [KostStreetPainter]; setiap rumah menempati slot lebar 400
  // pada koordinat dunia (rumah ke-i mulai di x = i * 400).

  void _setView(Rect v) {
    _vl = v.left;
    _vr = v.right;
    _vt = v.top;
    _vb = v.bottom;
  }

  /// Langit, bukit, pepohonan, tanah & mobil: digambar SEKALI untuk semua rumah.
  void paintStreetBackdrop(
      Canvas canvas,
      Rect view,
      double t, {
        required double worldW,
        required double fxScale,
      }) {
    _street = true;
    _streetW = worldW;
    _fxScale = fxScale;
    _sunX = view.left + view.width * 0.82;
    _setView(view);
    final p = _c01(d.pollution / 100);
    _drawSky(canvas, t, p);
    _drawHills(canvas, p);
    _drawSkyline(canvas, p);
    _drawTrees(canvas, t, p);
    _drawGodRays(canvas, t, p);
    _drawGround(canvas, t, p);
    _drawLampPosts(canvas);
    _drawCars(canvas, t);
  }

  /// Tiang lampu jalan di tiap slot rumah (x lokal 20). Hanya saat siklus
  /// siang-malam aktif; kilaunya digambar terpisah di [_drawNightLights].
  void _drawLampPosts(Canvas canvas) {
    if (d.dayPhase == null || d.compact) return;
    final k0 = math.max(0, ((_vl - 40) / _w).floor());
    final k1 = math.min((_streetW / _w).ceil() - 1, ((_vr + 40) / _w).floor());
    for (var k = k0; k <= k1; k++) {
      final x = k * _w + 20;
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF37474F);
      canvas.drawRect(Rect.fromLTWH(x - 1.2, _gy - 50, 2.4, 52), _p);
      canvas.drawRect(Rect.fromLTWH(x - 1.2, _gy - 51, 9, 2.2), _p);
      _p.color = _mix(const Color(0xFFCFD8DC), const Color(0xFFFFE9A8), _night);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 4, _gy - 50, 7, 3.4), const Radius.circular(1.5)),
        _p,
      );
    }
  }

  /// Kilau lampu jalan: dipanggil SETELAH peredam gelap agar tetap terang.
  void _drawNightLights(Canvas canvas, double t) {
    final night = _night;
    if (d.dayPhase == null || night < 0.05) return;
    final k0 = math.max(0, ((_vl - 60) / _w).floor());
    final k1 = math.min((_streetW / _w).ceil() - 1, ((_vr + 60) / _w).floor());
    for (var k = k0; k <= k1; k++) {
      final c = Offset(k * _w + 20 + 7.5, _gy - 48);
      // kerucut cahaya ke tanah
      final cone = Path()
        ..moveTo(c.dx - 3, c.dy + 2)
        ..lineTo(c.dx + 3, c.dy + 2)
        ..lineTo(c.dx + 30, _gy + 3)
        ..lineTo(c.dx - 30, _gy + 3)
        ..close();
      _p
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.plus
        ..color = const Color(0xFFFFE2A0).withValues(alpha: 0.10 * night);
      canvas.drawPath(cone, _p);
      for (var i = 0; i < 3; i++) {
        _p.color = const Color(0xFFFFD27A)
            .withValues(alpha: (0.10 + i * 0.09) * night);
        canvas.drawCircle(c, 22 - i * 7.0, _p);
      }
      _p.blendMode = BlendMode.srcOver;
    }
  }

  /// Kilau jendela menyala per rumah (koordinat lokal), juga setelah peredam.
  void _drawNightWindows(Canvas canvas, double t) {
    final night = _night;
    if (d.dayPhase == null || night < 0.05 || d.eliminated) return;
    final floors = _floors;
    final n = math.min(d.rooms, floors * 4);
    final buildP = _buildP;
    final newest = d.rooms - 1;
    _p
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.plus;
    for (var idx = 0; idx < n; idx++) {
      if (buildP != null && idx >= newest) continue;
      if (!_roomLit(idx, t)) continue;
      final r = _cell(idx);
      final win = Rect.fromLTWH(r.left + 9, r.top + 9, r.width - 18, 26);
      _p.color = const Color(0xFFFFB74D).withValues(alpha: 0.10 * night);
      canvas.drawRRect(
          RRect.fromRectAndRadius(win.inflate(7), const Radius.circular(6)), _p);
      _p.color = const Color(0xFFFFC870).withValues(alpha: 0.20 * night);
      canvas.drawRect(win, _p);
    }
    _p.blendMode = BlendMode.srcOver;
  }

  /// Satu rumah beserta seluruh aksinya (koordinat lokal 0..400).
  void paintStreetHouse(Canvas canvas, Rect view, double t) {
    _street = true;
    _setView(view);
    final sh = _shakeOffset(t);
    canvas.save();
    if (sh != Offset.zero) {
      canvas.translate(sh.dx, sh.dy);
    }
    _drawWorldEventBack(canvas, t);
    _drawBuilding(canvas, t);
    _drawBountyCrown(canvas, t);
    _drawWasteFacility(canvas, t);
    _drawFleeing(canvas, t);
    _drawDefense(canvas, t);
    _drawBags(canvas);
    _drawResidents(canvas, t);
    _drawOwner(canvas, t);
    _drawRats(canvas, t);
    _drawStinkAndFlies(canvas, t);
    _drawCrows(canvas, t);
    _drawTruck(canvas, t);
    _drawInspectAndSeal(canvas, t);
    _drawFire(canvas, t);
    _drawCollapse(canvas);
    _drawBuriedCine(canvas, t);
    _drawCrane(canvas, t);
    _drawWindup(canvas, t);
    _drawThrown(canvas, t);
    _drawParry(canvas, t);
    _drawConfetti(canvas, t);
    canvas.restore();
  }

  /// Hujan/banjir, abu, kabut & vinyet: sekali untuk seluruh layar.
  void paintStreetAtmosphere(
      Canvas canvas,
      Rect view,
      double t, {
        required double worldW,
        required double fxScale,
      }) {
    _street = true;
    _streetW = worldW;
    _fxScale = fxScale;
    _setView(view);
    final p = _c01(d.pollution / 100);
    _drawWorldEventFront(canvas, t);
    _drawAsh(canvas, t, p);
    _drawHaze(canvas, p);

    // Peredam malam (biru gelap, makin pekat ke bawah agar bulan/bintang
    // tetap terang) + semburat hangat saat senja/fajar.
    final night = _night;
    if (d.dayPhase != null && night > 0.01) {
      _p
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A1440).withValues(alpha: 0.06 * night),
            const Color(0xFF0A1440).withValues(alpha: 0.52 * night),
          ],
        ).createShader(_view);
      canvas.drawRect(_view, _p);
      _p.shader = null;
    }
    final dusk = _dusk;
    if (d.dayPhase != null && dusk > 0.02) {
      _p
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFF8A50).withValues(alpha: 0),
            const Color(0xFFFF8A50).withValues(alpha: 0.16 * dusk),
          ],
        ).createShader(_view);
      canvas.drawRect(_view, _p);
      _p.shader = null;
    }
    _drawNightLights(canvas, t);

    final a = 0.28 + p * 0.2;
    _p
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        radius: 0.9,
        colors: [
          Colors.black.withValues(alpha: 0),
          Colors.black.withValues(alpha: _c01(a)),
        ],
        stops: const [0.55, 1.0],
      ).createShader(_view);
    canvas.drawRect(_view, _p);
    _p.shader = null;
  }

  /// Emoji, sorotan, bingkai peringatan & semburan api milik satu rumah.
  void paintStreetOverlay(Canvas canvas, Rect view, double t) {
    _street = true;
    _setView(view);
    final burnP = _fxProgress(FxType.burn, 4500);
    if (burnP != null) {
      final env = burnP < 0.12
          ? burnP / 0.12
          : (burnP > 0.8 ? (1 - burnP) / 0.2 : 1.0);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFF6D00)
            .withValues(alpha: _c01(0.12 * env * (0.7 + 0.3 * math.sin(t * 12))));
      canvas.drawRect(_view, _p);
    }
    // Kilau jendela malam (setelah peredam gelap global)
    _drawNightWindows(canvas, t);
    // Emoji reaksi digambar sebagai widget (KostEmojiBubble) di atas semua
    // kartu UI agar tidak tertutup.
    _drawCinematic(canvas, t);
    _drawStateFrames(canvas, t);
  }

  // ----------------------------------------------------------- langit

  void _drawSky(Canvas canvas, double t, double p) {
    final isRain = d.worldEvent == 'rain_flood';
    final heavy = _c01(p * 1.2 + (d.smog ? 0.25 : 0) + (isRain ? 0.35 : 0));
    var top = _mix(const Color(0xFF4CA8E0), const Color(0xFF5D666B), heavy);
    var bottom = _mix(const Color(0xFFE3F5FB), const Color(0xFFA09C94), heavy);
    final night = _night;
    final dusk = _dusk;
    if (d.dayPhase != null) {
      // siang -> senja/fajar -> malam
      top = _mix(top, const Color(0xFF5B4B8A), dusk * 0.8);
      bottom = _mix(bottom, const Color(0xFFFF9A62), dusk * 0.85);
      top = _mix(top, const Color(0xFF070B24), night);
      bottom = _mix(bottom, const Color(0xFF1B2A55), night);
    }
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

    if (isRain && (t * 1.7) % 4.0 < 0.15) {
      _p.color = Colors.white.withValues(alpha: 0.45);
      canvas.drawRect(rect, _p);
    }

    // Bintang (tetap di koordinat dunia) & bulan, hanya saat gelap.
    if (night > 0.05) {
      final starVis = night * (1 - p * 0.8) * (isRain ? 0.2 : 1.0);
      if (starVis > 0.02) {
        final c0 = (_vl / 26).floor();
        final c1 = (_vr / 26).ceil();
        final step = d.compact ? 2 : 1;
        for (var k = c0; k < c1; k += step) {
          final h = _hh(k + 5000);
          if (h % 3 == 0) continue;
          final sx = k * 26.0 + (h % 23);
          final sy = -50.0 + ((h ~/ 7) % 1000) / 1000.0 * (_gy - 70 + 50);
          final tw = 0.55 + 0.45 * math.sin(t * (1.5 + (h % 5) * 0.4) + h);
          _p.color = Colors.white.withValues(alpha: _c01(starVis * tw));
          canvas.drawCircle(Offset(sx, sy), h % 5 == 0 ? 1.3 : 0.8, _p);
        }
      }
      final moonAng = d.dayPhase == null
          ? 0.0
          : (2 * math.pi * (d.dayPhase! - 0.25)) + math.pi;
      final moon = _celestialAt(moonAng);
      final moonA = (night * (isRain ? 0.25 : 1.0) * (1 - p * 0.6)).toDouble();
      _p.color = const Color(0xFFBBD4FF).withValues(alpha: 0.16 * moonA);
      canvas.drawCircle(moon, 30, _p);
      _p.color = const Color(0xFFE8EEFF).withValues(alpha: moonA);
      canvas.drawCircle(moon, 12, _p);
      // sabit bulan sabit
      _p.color = _mix(top, bottom, 0.1).withValues(alpha: moonA);
      canvas.drawCircle(moon + const Offset(5, -3), 10, _p);
    }

    final sunA = ((1 - p * 1.1) * (isRain ? 0.2 : 1.0))
        .clamp(0.1, 1.0)
        .toDouble() *
        (1 - night);
    final sun = d.dayPhase == null
        ? Offset(_sunX, 46)
        : _celestialAt(2 * math.pi * (d.dayPhase! - 0.25));
    if (d.dayPhase != null && dusk > 0.05) {
      // matahari jingga membesar dekat horizon
      _p.color = const Color(0xFFFF8A50).withValues(alpha: 0.22 * dusk * (1 - night));
      canvas.drawCircle(sun, 52, _p);
    }
    _p.color = const Color(0xFFFFF176).withValues(alpha: 0.28 * sunA);
    canvas.drawCircle(sun, 38, _p);
    if (sunA > 0.35 && !d.compact) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFE082).withValues(alpha: 0.38 * sunA);
      for (var k = 0; k < 12; k++) {
        final a = k * math.pi / 6 + t * 0.15;
        canvas.drawLine(
          sun + Offset(math.cos(a), math.sin(a)) * 22,
          sun +
              Offset(math.cos(a), math.sin(a)) *
                  (32 + math.sin(t * 2 + k) * 3.5),
          _p,
        );
      }
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt;
    }
    _p.color = const Color(0xFFFFD54F).withValues(alpha: sunA);
    canvas.drawCircle(sun, 16, _p);

    // Mode jalan: awan & burung bergerak di koordinat dunia (bukan layar) agar
    // tidak "meluncur" ketika kamera bergeser atau di-zoom.
    final span = _street ? _streetW + 400 : _vr - _vl;
    final spanStart = _street ? -200.0 : _vl;
    var cloudColor = _mix(
      Colors.white,
      const Color(0xFF54595E),
      _c01(p * 1.15 + (isRain ? 0.55 : 0)),
    );
    if (d.dayPhase != null) {
      cloudColor = _mix(cloudColor, const Color(0xFFFFB38A), dusk * 0.6);
      cloudColor = _mix(cloudColor, const Color(0xFF2B3558), night * 0.88);
    }
    final nClouds =
    _street ? (6 * span / 450).ceil() : (d.compact ? 3 : 6);
    for (var i = 0; i < nClouds; i++) {
      final x =
          ((t * (3 + (i % 6) * 1.4) + i * 170) % (span + 160)) + spanStart - 80;
      final y = 30.0 + (i % 3) * 24 + ((i ~/ 3) % 2) * 9;
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
    }

    if (p < 0.4 && !isRain && !d.compact && night < 0.3) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF37474F);
      final nBirds = _street ? math.min(16, (4 * span / 450).ceil()) : 4;
      for (var k = 0; k < nBirds; k++) {
        final x = ((t * (16 + (k % 4) * 5) + k * 140) % (span + 120)) +
            spanStart -
            60;
        final y = 62.0 + (k % 4) * 15 + math.sin(t * 2 + k) * 4;
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
      final hx0 = (_vl / 12).floor() * 12.0;
      final path = Path()..moveTo(hx0, _gy);
      for (var x = hx0; x <= _vr + 12; x += 12) {
        path.lineTo(
            x,
            base -
                amp * math.sin(x * fq + layer * 2.0) -
                amp * 0.4 * math.sin(x * fq * 2.3));
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
        final nightW = _night;
        _p.color = Colors.white.withValues(alpha: 0.2 * (1 - nightW));
        for (var yy = _gy - bh + 6; yy < _gy - 8; yy += 12) {
          for (var xx = x + 4; xx < x + bw - 4; xx += 8) {
            if (nightW > 0.05) {
              // malam: sebagian jendela gedung jauh menyala kuning
              final wl = _hh(k * 131 + (yy * 7).toInt() + (xx * 3).toInt()) % 100;
              if (wl < 55) {
                _p.color =
                    const Color(0xFFFFE08A).withValues(alpha: 0.85 * nightW);
                canvas.drawRect(Rect.fromLTWH(xx, yy, 3, 4), _p);
                _p.color = Colors.white.withValues(alpha: 0.2 * (1 - nightW));
                continue;
              }
            }
            canvas.drawRect(Rect.fromLTWH(xx, yy, 3, 4), _p);
          }
        }
      }
    }
  }

  void _drawTrees(Canvas canvas, double t, double p) {
    final start = (_vl / 90).floor() - 1;
    final end = (_vr / 90).ceil() + 1;
    final canopy =
    _mix(const Color(0xFF4CAF50), const Color(0xFF8D8B4A), p * 1.2);
    final canopy2 =
    _mix(const Color(0xFF66BB6A), const Color(0xFFA09A5A), p * 1.2);

    for (var k = start; k < end; k++) {
      final h = _hh(k + 77);
      final x = k * 90.0 + 20 + (h % 30);
      if (x > -14 && x < _streetW + 14) continue;
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

    final ls = (_vl / 180).floor() - 1;
    final le = (_vr / 180).ceil() + 1;
    for (var k = ls; k < le; k++) {
      final x = k * 180.0 + 62;
      if (x > -14 && x < _streetW + 14) continue;
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

    if (p < 0.5 && !d.compact) {
      const flowers = [
        Color(0xFFFF8A80),
        Color(0xFFFFF176),
        Color(0xFFCE93D8),
        Color(0xFFFFFFFF)
      ];
      final s = (_vl / 17).floor();
      final e = (_vr / 17).ceil();
      for (var k = s; k < e; k++) {
        final h = _hh(k + 300);
        if (h % 3 != 0) continue;
        _p.color = flowers[h % flowers.length];
        canvas.drawCircle(
            Offset(k * 17.0 + (h % 9), _gy - 2 + (h % 3)), 1.6, _p);
      }
    }

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

    _p.color = const Color(0xFF9EA2A6);
    canvas.drawRect(Rect.fromLTRB(_vl, 270, _vr, 273), _p);
    _p.color = const Color(0xFF4B4F55);
    canvas.drawRect(Rect.fromLTRB(_vl, 273, _vr, _vb), _p);
    _p.color = Colors.white.withValues(alpha: 0.65);
    for (var x = (_vl / 46).floor() * 46.0; x < _vr; x += 46) {
      canvas.drawRect(Rect.fromLTWH(x, 287, 24, 2.5), _p);
    }
  }

  // ------------------------------------------------ kejadian acak (world events)

  void _drawWorldEventBack(Canvas canvas, double t) {
    if (d.worldEvent == 'new_semester' && !d.compact) {
      const cols = [
        Color(0xFFFF5252),
        Color(0xFFFFCA28),
        Color(0xFF29B6F6),
        Color(0xFFAB47BC)
      ];
      for (var i = 0; i < 4; i++) {
        final bx = 60.0 + i * 95 + math.sin(t * 1.2 + i) * 10;
        final by = _roofY - 55 - (i % 2) * 18 + math.cos(t * 1.8 + i) * 5;
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.white70;
        canvas.drawLine(Offset(bx, by + 6), Offset(bx, by + 18), _p);
        _p
          ..style = PaintingStyle.fill
          ..color = cols[i % cols.length];
        canvas.drawOval(
            Rect.fromCenter(center: Offset(bx, by), width: 11, height: 14), _p);
      }
    }
  }

  void _drawWorldEventFront(Canvas canvas, double t) {
    final ev = d.worldEvent;
    if (ev == null) return;

    if (ev == 'rain_flood') {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF1976D2).withValues(alpha: 0.42);
      canvas.drawRect(Rect.fromLTRB(_vl, 267, _vr, _vb), _p);

      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFFBBDEFB).withValues(alpha: 0.45);
      for (var k = 0; k < 10; k++) {
        final rx = _vl + ((t * 25 + k * 65) % (_vr - _vl));
        final ry = 272.0 + (k % 3) * 8;
        canvas.drawOval(
            Rect.fromCenter(center: Offset(rx, ry), width: 18, height: 3), _p);
      }

      _p
        ..strokeWidth = 1.1 * _fxScale
        ..color = const Color(0xFFE3F2FD).withValues(alpha: 0.55);
      final nDrops = d.compact ? 18 : 55;
      final spanX = _vr - _vl;
      final spanY = _vb - _vt;
      for (var i = 0; i < nDrops; i++) {
        final h = _hh(i + 200);
        final dx = _vl + ((h % 1000) / 1000 * spanX - t * 60) % spanX;
        final dy = _vt + ((t * 260 + h % 500) % spanY);
        canvas.drawLine(Offset(dx, dy),
            Offset(dx - 4 * _fxScale, dy + 11 * _fxScale), _p);
      }
      _p.style = PaintingStyle.fill;
    } else if (ev == 'hauler_strike') {
      final nHouses = math.max(1, (_streetW / _w).round());
      for (final bx in [
        for (var hi = 0; hi < nHouses; hi++) ...[
          hi * _w + 135.0,
          hi * _w + 265.0,
        ],
      ]) {
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFF6F00);
        canvas.drawRect(Rect.fromLTWH(bx - 14, 268, 28, 6), _p);
        _p.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(bx - 8, 268, 5, 6), _p);
        canvas.drawRect(Rect.fromLTWH(bx + 3, 268, 5, 6), _p);
        _p.color = const Color(0xFF37474F);
        canvas.drawRect(Rect.fromLTWH(bx - 11, 274, 3, 6), _p);
        canvas.drawRect(Rect.fromLTWH(bx + 8, 274, 3, 6), _p);
      }
    } else if (ev == 'eco_subsidy' && !d.compact) {
      final spanX = _vr - _vl;
      final spanY = _gy - _vt;
      _p.style = PaintingStyle.fill;
      for (var i = 0; i < 18; i++) {
        final h = _hh(i + 88);
        final x = _vl + ((t * 28 + h % 600) % spanX);
        final y =
            _vt + ((t * 14 + h % 300) % spanY) + math.sin(t * 3 + i) * 5;
        _p.color = const Color(0xFF69F0AE).withValues(alpha: 0.7);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(x, y),
                width: 5 * _fxScale,
                height: 3 * _fxScale),
            _p);
      }
    }
  }

  void _drawCars(Canvas canvas, double t) {
    final worldL = _street ? 0.0 : _vl;
    final worldR = _street ? _streetW : _vr;
    KostTraffic.paint(
      canvas,
      t: t,
      viewL: _vl,
      viewR: _vr,
      worldL: worldL - 350,
      worldR: worldR + 350,
      lowDetail: d.compact,
      pollution: _c01(d.pollution / 100),
      lights: d.pollution > 60 || d.worldEvent == 'rain_flood' || _night > 0.3,
      rain: d.worldEvent == 'rain_flood',
    );
  }

}

/// Bangunan, kamar, dan fasilitas bank sampah.
extension KostPainterBuilding on KostPainter {
  // ---------------------------------------- bangunan & kelas kost (tier 0..2)

  void _drawBuilding(Canvas canvas, double t) {
    final floors = _floors;
    final roofY = _roofY;
    final buildP = _buildP;
    final bp = buildP ?? 0.0;
    final floorBuild = buildP != null && _isFloorBuild;
    final tierP = _fxProgress(FxType.tier, 2400);
    final newest = d.rooms - 1;
    _planResidents(t);

    _p
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.18);
    canvas.drawOval(Rect.fromLTWH(_bl - 12, _gy + 1, 214, 11), _p);

    if (d.kostTier >= 2) {
      final postTop = floorBuild
          ? _lerp(roofY + _fh, roofY, _ease(_c01((bp - 0.17) / 0.25)))
          : roofY;
      _p.color = const Color(0xFFFFD54F);
      canvas.drawRect(Rect.fromLTWH(_bl - 5, postTop, 5, _gy - postTop), _p);
      canvas.drawRect(Rect.fromLTWH(_bl + 190, postTop, 5, _gy - postTop), _p);
    }

    for (var idx = 0; idx < floors * 4; idx++) {
      final r = _cell(idx);
      if (floorBuild && idx ~/ 4 == floors - 1) {
        // tambah lantai: sel di lantai baru dibangun dari rangka
        _newFloorCell(canvas, r, idx, t, bp);
        continue;
      }
      if (idx >= d.rooms) {
        // Kamar belum dibangun: tetap ada rangka beton + ruang mentah di
        // dalamnya, bukan kotak kosong di bawah atap yang melayang.
        _emptyShell(canvas, r, idx, t);
        continue;
      }
      if (buildP != null && idx == newest) {
        // tambah kamar: bata -> plester -> cat
        _drawRoomUnderRenovation(canvas, r, idx, t, bp);
        continue;
      }
      _drawRoom(canvas, r, idx, t);
    }

    if (!d.compact && !d.eliminated && d.trashRatio < 0.9) {
      for (var idx = 0; idx < math.min(d.rooms, floors * 4); idx++) {
        if (buildP != null && idx >= newest) continue;
        final h = _hh(idx);
        if (h % 3 != 0) continue;
        final phase = (t * 0.45 + (h % 10) / 10) % 1.0;
        final r = _cell(idx);
        final a =
        ((phase < 0.2 ? phase / 0.2 : 1.0) * (1 - phase)).clamp(0.0, 1.0);
        final cy = r.top + 6 - phase * 28;
        final cx = r.center.dx + math.sin(phase * 6 + idx) * 3;
        _p.color = const Color(0xFFFFC107).withValues(alpha: a);
        canvas.drawCircle(Offset(cx, cy), 3.8, _p);
        _p.color = const Color(0xFFFFF59D).withValues(alpha: a);
        canvas.drawCircle(Offset(cx - 0.9, cy - 0.9), 1.3, _p);
      }
    }

    // atap ikut terangkat & berayun saat tambah lantai
    canvas.save();
    if (floorBuild) {
      final roofDy = _roofDy(bp);
      final roofSw = _roofSway(bp, t);
      canvas.translate(0, roofDy);
      if (roofSw != 0) {
        final pl = roofY - 90 - roofDy;
        canvas.translate(200, pl);
        canvas.rotate(roofSw);
        canvas.translate(-200, -pl);
      }
    }
    if (d.kostTier == 2) {
      _p
        ..style = PaintingStyle.fill
        ..color = d.style?.roofColor ?? const Color(0xFF263238);
      canvas.drawRect(Rect.fromLTWH(_bl - 8, roofY - 8, 206, 8), _p);
      _p.color = const Color(0xFFFFD54F);
      canvas.drawRect(Rect.fromLTWH(_bl - 8, roofY - 10, 206, 2.5), _p);

      _p.color = const Color(0xFF80DEEA).withValues(alpha: 0.45);
      canvas.drawRect(Rect.fromLTWH(_bl, roofY - 17, 190, 7), _p);

      _p.color = const Color(0xFFECEFF1);
      canvas.drawRect(Rect.fromLTWH(204, roofY - 34, 2, 18), _p);
      _p.color = const Color(0xFFE53935);
      canvas.drawPath(
        Path()
          ..moveTo(188, roofY - 30)
          ..quadraticBezierTo(205, roofY - 42, 222, roofY - 30)
          ..close(),
        _p,
      );
    } else {
      final roofColor = d.style?.roofColor ??
          (d.kostTier == 1
              ? const Color(0xFF37474F)
              : _mix(d.wall, const Color(0xFF8D4B3B), 0.75));
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
      canvas.restore();
      _p
        ..style = PaintingStyle.fill
        ..color = _mix(roofColor, Colors.black, 0.3);
      canvas.drawRect(Rect.fromLTWH(_bl - 8, roofY - 3, 206, 3), _p);
      // kilau di bubungan + bayangan atap yang jatuh di dinding
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..color = _mix(roofColor, Colors.white, 0.4).withValues(alpha: 0.8);
      canvas.drawLine(
          Offset(_bl + 10, roofY - 21.4), Offset(_bl + 180, roofY - 21.4), _p);
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt
        ..color = Colors.black.withValues(alpha: 0.16);
      canvas.drawRect(Rect.fromLTWH(_bl, roofY, 190, 4.5), _p);
    }

    _p.color =
    d.kostTier >= 1 ? const Color(0xFF0288D1) : const Color(0xFF78909C);
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

    final signBg = d.style?.signColor ??
        (d.kostTier == 2
            ? const Color(0xFF212121)
            : (d.kostTier == 1
            ? const Color(0xFF0D47A1)
            : const Color(0xFF477A62)));
    if (!d.compact) {
      final glow = 0.5 + 0.5 * math.sin(t * 2.4);
      _p
        ..style = PaintingStyle.fill
        ..color = _mix(signBg, Colors.white, 0.5)
            .withValues(alpha: 0.08 + 0.08 * glow);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(116, roofY - 42, 68, 20).inflate(4),
          const Radius.circular(8),
        ),
        _p,
      );
    }
    _p
      ..style = PaintingStyle.fill
      ..color = signBg;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(116, roofY - 42, 68, 20),
        const Radius.circular(4),
      ),
      _p,
    );
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = d.kostTier == 2
          ? const Color(0xFFFFD54F)
          : Colors.white.withValues(alpha: 0.75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(117.5, roofY - 40.5, 65, 17),
        const Radius.circular(3),
      ),
      _p,
    );
    _p.style = PaintingStyle.fill;

    final customName = d.style?.name ?? '';
    final tp = customName.isNotEmpty
        ? _customSign(customName)
        : (d.kostTier == 2
        ? _signSul
        : (d.kostTier == 1 ? _signExc : _signReg));
    tp.paint(canvas, Offset(150 - tp.width / 2, roofY - 36));

    canvas.restore();

    if (tierP != null) {
      final a = 1 - tierP;
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * a
        ..color = const Color(0xFFFFD54F).withValues(alpha: a * 0.9);
      canvas.drawRect(
        Rect.fromLTWH(_bl - 6, roofY - 12, 202, _gy - roofY + 12)
            .inflate(tierP * 18),
        _p,
      );
      _p.style = PaintingStyle.fill;
      _drawBannerText(
        canvas,
        d.kostTier == 2 ? 'NAIK KELAS SULTAN!' : 'NAIK KELAS EKSKLUSIF!',
        Offset(200, roofY - 48 - tierP * 26),
        const Color(0xFFFFD54F),
        scale: 1.05 + math.sin(tierP * math.pi) * 0.25,
        alpha: a,
      );
    }

    if (_critical) {
      final pulse = 0.5 + 0.5 * math.sin(t * 8);
      _p.color = const Color(0xFFFF1744).withValues(alpha: 0.25 + 0.3 * pulse);
      canvas.drawCircle(Offset(205, roofY - 27), 13, _p);
      _p.color = const Color(0xFFFF1744);
      canvas.drawCircle(Offset(205, roofY - 27), 4.5, _p);
    }
  }

  /// Kamar yang belum dibangun: rangka beton (kolom + pelat lantai + pelat
  /// plafon) dengan ruang mentah di dalamnya - plesteran belum jadi, bukaan
  /// jendela tanpa kaca, tembok bata setengah jadi, dan perkakas tukang.
  /// Hasilnya terbaca sebagai "lantai yang sedang dikerjakan", sehingga atap
  /// tidak lagi terlihat melayang di atas kotak kosong.
  void _emptyShell(Canvas canvas, Rect r, int idx, double t) {
    final h = _hh(idx * 5 + 11);

    // ---- dinding belakang: plester/beton mentah, gelap di bawah pelat atas
    _p
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF5F5A54), Color(0xFF9E978B), Color(0xFFB3ACA0)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(r);
    canvas.drawRect(r, _p);
    _p.shader = null;

    // bercak plesteran yang belum rata
    _p.color = Colors.white.withValues(alpha: 0.06);
    canvas.drawRect(
        Rect.fromLTWH(r.left + 6 + (h % 9), r.top + 14, 11, 9), _p);
    _p.color = Colors.black.withValues(alpha: 0.07);
    canvas.drawRect(
        Rect.fromLTWH(r.right - 20 - (h % 7), r.top + 24, 9, 12), _p);

    // ---- bukaan jendela: lubang gelap berbingkai kayu kasar (tanpa kaca)
    final win = Rect.fromLTWH(r.left + 9, r.top + 9, r.width - 18, 26);
    _p.color = const Color(0xFF1F242B).withValues(alpha: 0.92);
    canvas.drawRect(win, _p);
    _p.color = Colors.white.withValues(alpha: 0.05);
    canvas.drawRect(Rect.fromLTWH(win.left, win.top, win.width, 5), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFF8D6E4B);
    canvas.drawRect(win, _p);
    // palang kayu penahan (bekisting)
    canvas.drawLine(win.topLeft, win.bottomRight,
        _p..color = const Color(0xFF8D6E4B).withValues(alpha: 0.55));
    _p.style = PaintingStyle.fill;

    // ---- tembok bata setengah jadi di bagian bawah
    if (h % 3 != 0) {
      final courses = 2 + h % 3; // 2..4 lapis
      const bh = 4.2;
      final wallTop = r.bottom - 3 - courses * bh;
      final wall = Rect.fromLTRB(r.left + 3.5, wallTop, r.right - 3.5, r.bottom - 3);
      _p.color = const Color(0xFFB4654A);
      canvas.drawRect(wall, _p);
      canvas.save();
      canvas.clipRect(wall);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = const Color(0xFFE6DCCB).withValues(alpha: 0.85);
      for (var c = 0; c <= courses; c++) {
        final y = wall.bottom - c * bh;
        canvas.drawLine(Offset(wall.left, y), Offset(wall.right, y), _p);
        for (var x = wall.left + (c.isOdd ? 4.0 : 0.0); x < wall.right; x += 8) {
          canvas.drawLine(Offset(x, y - bh), Offset(x, y), _p);
        }
      }
      canvas.restore();
      _p.style = PaintingStyle.fill;
      // tiang pegangan tukang + adukan semen di atas tembok
      _p.color = const Color(0xFF9E9E9E);
      canvas.drawRect(Rect.fromLTWH(wall.left + 5 + (h % 12), wallTop - 2.2, 8, 2.2), _p);
    }

    // ---- perkakas tukang (berbeda tiap kamar)
    final bx = r.left + 8 + (h % 20);
    switch (h % 4) {
      case 0: // tumpukan kantong semen
        _p.color = const Color(0xFFD7CCC8);
        canvas.drawRect(Rect.fromLTWH(bx, r.bottom - 8, 11, 5), _p);
        canvas.drawRect(Rect.fromLTWH(bx + 1.5, r.bottom - 12.5, 9, 4.5), _p);
        _p.color = const Color(0xFF8D6E63);
        canvas.drawRect(Rect.fromLTWH(bx + 3, r.bottom - 6.5, 5, 1.4), _p);
        break;
      case 1: // ember adukan + sekop
        _p.color = const Color(0xFFFB8C00);
        canvas.drawRect(Rect.fromLTWH(bx, r.bottom - 9, 7, 6), _p);
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF6D4C41);
        canvas.drawLine(Offset(bx + 9, r.bottom - 3), Offset(bx + 14, r.bottom - 16), _p);
        _p.style = PaintingStyle.fill;
        break;
      case 2: // tangga kayu bersandar
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFA1887F);
        canvas.drawLine(Offset(bx, r.bottom - 3), Offset(bx + 6, r.top + 14), _p);
        canvas.drawLine(Offset(bx + 6, r.bottom - 3), Offset(bx + 12, r.top + 14), _p);
        for (var s = 0; s < 5; s++) {
          final yy = r.bottom - 6 - s * 6.0;
          canvas.drawLine(Offset(bx + 0.8 + s * 0.9, yy), Offset(bx + 6.8 + s * 0.9, yy), _p);
        }
        _p.style = PaintingStyle.fill;
        break;
      default: // lampu kerja menggantung, berkedip tipis
        final fl = 0.75 + 0.25 * math.sin(t * 9 + idx);
        final lx = r.center.dx;
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0xFF212121);
        canvas.drawLine(Offset(lx, r.top + 3), Offset(lx, r.top + 12), _p);
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFFE082).withValues(alpha: 0.18 * fl);
        canvas.drawCircle(Offset(lx, r.top + 14), 13, _p);
        _p.color = const Color(0xFFFFF59D).withValues(alpha: fl);
        canvas.drawCircle(Offset(lx, r.top + 13.5), 2.4, _p);
    }

    // ---- pelat lantai (bawah) & pelat plafon (atas)
    _p.color = const Color(0xFF6E6E6E);
    canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - 3, r.width, 3), _p);
    _p.color = Colors.white.withValues(alpha: 0.18);
    canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - 3, r.width, 0.8), _p);
    _p.color = const Color(0xFF7A7A7A);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 3.2), _p);
    _p.color = Colors.black.withValues(alpha: 0.22);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top + 3.2, r.width, 2.4), _p);

    // ---- kolom beton di kedua sisi (+ sengkang tulangan)
    for (final cx in [r.left, r.right - 4.0]) {
      _p.color = const Color(0xFFB5B2AB);
      canvas.drawRect(Rect.fromLTWH(cx, r.top, 4, r.height), _p);
      _p.color = Colors.black.withValues(alpha: 0.18);
      canvas.drawRect(Rect.fromLTWH(cx + (cx == r.left ? 3.2 : 0), r.top, 0.8, r.height), _p);
    }

    // ---- pita peringatan di kamar yang berikutnya akan dibangun
    if (idx == d.rooms && !d.eliminated) {
      canvas.save();
      canvas.clipRect(r.deflate(1));
      canvas.translate(r.left, r.top + 36);
      canvas.rotate(-0.12);
      _p.color = const Color(0xFFFFD600);
      canvas.drawRect(Rect.fromLTWH(-4, 0, r.width + 8, 4.2), _p);
      _p.color = Colors.black87;
      for (var sx = -4.0; sx < r.width + 8; sx += 8) {
        canvas.drawPath(
          Path()
            ..moveTo(sx, 0)
            ..lineTo(sx + 3.2, 0)
            ..lineTo(sx + 1.2, 4.2)
            ..lineTo(sx - 2, 4.2)
            ..close(),
          _p,
        );
      }
      canvas.restore();
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
    final wall = d.kostTier == 2
        ? _mix(d.wall, const Color(0xFFFFF8E1), 0.55)
        : (d.kostTier == 1
        ? _mix(d.wall, const Color(0xFFECEFF1), 0.45)
        : d.wall);
    _p
      ..style = PaintingStyle.fill
      ..color = wall;
    canvas.drawRect(r, _p);

    _p
      ..style = PaintingStyle.fill
      ..color = d.kostTier == 2
          ? const Color(0xFFFFB300)
          : _mix(wall, Colors.black, 0.22);
    canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - 3, r.width, 3), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _mix(wall, Colors.black, 0.28);
    canvas.drawRect(r, _p);

    // Lampu berkedip panik saat kondisi kritis
    final lit = _roomLit(idx, t);
    final win = Rect.fromLTWH(r.left + 9, r.top + 9, r.width - 18, 26);

    if (lit) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFE082).withValues(alpha: 0.22);
      canvas.drawRect(win.inflate(3), _p);
    }
    _p
      ..style = PaintingStyle.fill
      ..color = lit
          ? (d.kostTier == 2
          ? const Color(0xFFFFE57F)
          : const Color(0xFFFFDD7A))
          : const Color(0xFF39465A);
    canvas.drawRect(win, _p);

    if (lit && !d.compact && idx % 3 != 1 && !_resOutRooms.contains(idx)) {
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
      _p.color = const Color(0xFFE0AC84);
      canvas.drawCircle(Offset(cx, win.bottom - 11), 3.3, _p);
      canvas.restore();
    }

    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = d.kostTier == 2
          ? const Color(0xFFFFB300)
          : (d.kostTier == 1
          ? const Color(0xFF455A64)
          : const Color(0xFF6B5843));
    canvas.drawRect(win, _p);
    canvas.drawLine(
        Offset(win.center.dx, win.top), Offset(win.center.dx, win.bottom), _p);
    _p.style = PaintingStyle.fill;

    if (!d.compact) {
      // kilau kaca yang menyapu pelan
      canvas.save();
      canvas.clipRect(win);
      final gl = (t * 0.16 + idx * 0.37) % 1.0;
      final gx = win.left - 10 + gl * (win.width + 24);
      _p
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: lit ? 0.14 : 0.2);
      canvas.drawPath(
        Path()
          ..moveTo(gx, win.bottom)
          ..lineTo(gx + 4, win.bottom)
          ..lineTo(gx + 10, win.top)
          ..lineTo(gx + 6, win.top)
          ..close(),
        _p,
      );
      // tirai yang bergoyang tertiup angin
      if (lit) {
        const curtains = [
          Color(0xFFE57373),
          Color(0xFF64B5F6),
          Color(0xFF81C784),
          Color(0xFFFFB74D),
        ];
        final cc =
        curtains[_hh(idx + 9) % curtains.length].withValues(alpha: 0.8);
        final cs = math.sin(t * 1.6 + idx * 1.3) * 1.2;
        _p.color = cc;
        canvas.drawPath(
          Path()
            ..moveTo(win.left, win.top)
            ..lineTo(win.left + 5 + cs, win.top)
            ..lineTo(win.left + 3 + cs * 0.6, win.top + win.height * 0.6)
            ..lineTo(win.left, win.bottom)
            ..close(),
          _p,
        );
        canvas.drawPath(
          Path()
            ..moveTo(win.right, win.top)
            ..lineTo(win.right - 5 - cs, win.top)
            ..lineTo(win.right - 3 - cs * 0.6, win.top + win.height * 0.6)
            ..lineTo(win.right, win.bottom)
            ..close(),
          _p,
        );
      }
      canvas.restore();
      // ambang jendela
      _p.color = _mix(wall, Colors.black, 0.32);
      canvas.drawRect(
          Rect.fromLTWH(win.left - 2, win.bottom, win.width + 4, 2.4), _p);
      // pot tanaman di ambang
      if (idx % 3 == 0) {
        final sx = math.sin(t * 1.8 + idx) * 0.5;
        _p.color = const Color(0xFFBF6B3F);
        canvas.drawRect(
            Rect.fromLTWH(win.left + 1, win.bottom - 4.2, 6, 4.2), _p);
        _p.color = const Color(0xFF5CAA5E);
        canvas.drawCircle(
            Offset(win.left + 4 + sx, win.bottom - 6.2), 2.8, _p);
        canvas.drawCircle(
            Offset(win.left + 1.6 + sx, win.bottom - 4.9), 1.9, _p);
      }
    }

    if (d.kostTier >= 1) {
      _p.color = const Color(0xFF80D8FF).withValues(alpha: 0.38);
      canvas.drawRect(
          Rect.fromLTWH(r.left + 5, win.bottom - 4, r.width - 10, 7), _p);
    }

    if (d.kostTier >= 1 || idx % 4 == 2) {
      _p.color = const Color(0xFFECEFF1);
      canvas.drawRect(Rect.fromLTWH(r.right - 18, r.top + 38, 12, 7), _p);
      _p.color = const Color(0xFF546E7A);
      canvas.drawCircle(Offset(r.right - 13, r.top + 41.5), 2.3, _p);
    }
  }

  // ------------------------- fasilitas bank sampah & insinerator (Lv 1..12)

  void _drawWasteFacility(Canvas canvas, double t) {
    final lv = d.wasteLevel;
    if (lv <= 0) return;

    final wp = _fxProgress(FxType.waste, 2200);
    final pop = wp == null ? 1.0 : _easeOutBack(wp / 0.45);
    final fill = _binFill; // 0..1 (penuh saat trashRatio >= 1/3)

    canvas.save();
    canvas.translate(72, _gy + 4);
    canvas.scale(pop, pop);
    canvas.translate(-72, -(_gy + 4));

    // Alas beton fasilitas
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF90A4AE);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(40, _gy + 1, 62, 5), const Radius.circular(2)),
      _p,
    );

    if (lv == 1) {
      _smallBin(canvas, 78, _gy + 2, const Color(0xFF43A047), fill);
    } else if (lv == 2) {
      _medBin(canvas, 74, _gy + 2, const Color(0xFF2E7D32), fill);
    } else if (lv == 3) {
      _bigDumpster(canvas, 66, _gy + 2, const Color(0xFF1565C0), fill);
    } else if (lv == 4) {
      _bigDumpster(canvas, 54, _gy + 2, const Color(0xFF1565C0), fill);
      _smallBin(canvas, 84, _gy + 2, const Color(0xFF43A047), fill);
    } else if (lv == 5) {
      _bigDumpster(canvas, 50, _gy + 2, const Color(0xFF1565C0), fill);
      _medBin(canvas, 80, _gy + 2, const Color(0xFFFBC02D), fill);
    } else if (lv == 6) {
      _bigDumpster(canvas, 44, _gy + 2, const Color(0xFF1565C0), fill);
      _bigDumpster(canvas, 74, _gy + 2, const Color(0xFF2E7D32), fill);
    } else if (lv == 7) {
      _bigDumpster(canvas, 42, _gy + 2, const Color(0xFF1565C0), fill);
      _recycleMachine(canvas, 68, _gy + 2, t, fill);
    } else if (lv == 8 || lv == 9) {
      _pollutingIncinerator(canvas, 48, _gy + 2, t, big: lv == 9, fill: fill);
    } else if (lv >= 10) {
      _ecoIncinerator(canvas, 46, _gy + 2, t, tier: lv - 9, fill: fill);
    }

    canvas.restore();

    if (wp != null) {
      final a = 1 - wp;
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * a
        ..color = const Color(0xFF69F0AE).withValues(alpha: a);
      canvas.drawCircle(Offset(72, _gy - 14), 10 + wp * 42, _p);
      _p.style = PaintingStyle.fill;

      _drawBannerText(
        canvas,
        'BANK SAMPAH LV $lv!',
        Offset(75, _gy - 38 - wp * 26),
        const Color(0xFF69F0AE),
        scale: 0.95 + math.sin(wp * math.pi) * 0.2,
        alpha: a,
      );
    }
  }

  /// Menggambar kantong-kantong sampah yang menyembul di dalam mulut kotak sampah
  /// ketika `fill > 0.05`. Semakin penuh (`fill -> 1.0`), kantong makin tinggi menyembul.
  void _drawBinTrashInside(
      Canvas canvas, double x, double topY, double width, double fill) {
    if (fill <= 0.03) return;
    final count = math.max(1, (fill * (width / 5.5)).ceil());
    for (var i = 0; i < count; i++) {
      final frac = count == 1 ? 0.5 : i / (count - 1);
      final bx = x + 3 + frac * (width - 6);
      final by = topY + 2.5 - fill * 3.8 - (i % 2) * 1.4;
      _bag(canvas, Offset(bx, by), 300 + i + x.toInt(), scale: 0.52 + fill * 0.16);
    }
  }

  void _smallBin(
      Canvas canvas, double x, double bottomY, Color c, double fill) {
    const h = 14.0;
    const w = 11.0;
    final topY = bottomY - h;

    // Isi sampah menyembul di dalam kotak
    _drawBinTrashInside(canvas, x, topY, w, fill);

    // Badan kotak kecil
    _p
      ..style = PaintingStyle.fill
      ..color = c;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, topY, w, h), const Radius.circular(2)),
      _p,
    );

    // Tutup kotak terangkat/miring bila sedang terisi sampah
    canvas.save();
    final lift = fill * 3.5;
    canvas.translate(x, topY - 2 - lift);
    canvas.rotate(-fill * 0.35);
    _p.color = _mix(c, Colors.black, 0.25);
    canvas.drawRect(const Rect.fromLTWH(-1, 0, w + 2, 2.5), _p);
    canvas.restore();
  }

  void _medBin(Canvas canvas, double x, double bottomY, Color c, double fill) {
    const h = 19.0;
    const w = 16.0;
    final topY = bottomY - h;

    _drawBinTrashInside(canvas, x, topY, w, fill);

    _p
      ..style = PaintingStyle.fill
      ..color = c;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, topY, w, h), const Radius.circular(2.5)),
      _p,
    );

    canvas.save();
    final lift = fill * 4.2;
    canvas.translate(x, topY - 3 - lift);
    canvas.rotate(-fill * 0.4);
    _p.color = const Color(0xFFFFCA28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-1, 0, w + 2, 3.5), const Radius.circular(2)),
      _p,
    );
    canvas.restore();
  }

  void _bigDumpster(
      Canvas canvas, double x, double bottomY, Color c, double fill) {
    const h = 21.0;
    const w = 26.0;
    final topY = bottomY - h - 2;

    _drawBinTrashInside(canvas, x, topY, w, fill);

    _p
      ..style = PaintingStyle.fill
      ..color = c;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, topY, w, h), const Radius.circular(3)),
      _p,
    );
    _p.color = _mix(c, Colors.white, 0.25);
    canvas.drawRect(Rect.fromLTWH(x + 2, bottomY - 15, w - 4, 2.5), _p);

    // Indikator bar kecil di badan dumpster
    _p.color = Colors.black.withValues(alpha: 0.35);
    canvas.drawRect(Rect.fromLTWH(x + 3, bottomY - 9, w - 6, 3), _p);
    _p.color = fill >= 0.95
        ? const Color(0xFFFF5252)
        : (fill >= 0.6 ? const Color(0xFFFFCA28) : const Color(0xFF69F0AE));
    canvas.drawRect(
        Rect.fromLTWH(x + 3, bottomY - 9, (w - 6) * fill, 3), _p);

    // Tutup dumpster terangkat miring mengikuti kepenuhan
    canvas.save();
    final lift = fill * 4.8;
    canvas.translate(x, topY - 3 - lift);
    canvas.rotate(-fill * 0.38);
    _p.color = const Color(0xFF263238);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-1, 0, w + 2, 3.5), const Radius.circular(2)),
      _p,
    );
    canvas.restore();

    _p.color = const Color(0xFF263238);
    canvas.drawCircle(Offset(x + 5, bottomY - 1.5), 2.2, _p);
    canvas.drawCircle(Offset(x + 21, bottomY - 1.5), 2.2, _p);
  }

  void _recycleMachine(
      Canvas canvas, double x, double bottomY, double t, double fill) {
    // Corong penampung sampah di atas mesin daur ulang
    _drawBinTrashInside(canvas, x + 3, bottomY - 32, 24, fill);

    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF00897B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, bottomY - 30, 30, 30), const Radius.circular(4)),
      _p,
    );
    final cx = x + 15;
    final cy = bottomY - 15;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = const Color(0xFFA7FFEB);
    canvas.drawCircle(Offset(cx, cy), 7, _p);
    final ang = t * 4;
    canvas.drawLine(
      Offset(cx + math.cos(ang) * 7, cy + math.sin(ang) * 7),
      Offset(cx - math.cos(ang) * 7, cy - math.sin(ang) * 7),
      _p,
    );
    _p.style = PaintingStyle.fill;
  }

  void _pollutingIncinerator(Canvas canvas, double x, double bottomY, double t,
      {required bool big, required double fill}) {
    final w = big ? 44.0 : 34.0;
    final h = big ? 32.0 : 26.0;

    // Bak penampung umpan sampah di samping insinerator
    _drawBinTrashInside(canvas, x + 2, bottomY - h - 2, w * 0.55, fill);

    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF455A64);
    canvas.drawRect(Rect.fromLTWH(x + 6, bottomY - h - 18, 7, 18), _p);
    if (big) {
      canvas.drawRect(Rect.fromLTWH(x + 24, bottomY - h - 22, 8, 22), _p);
    }

    for (var k = 0; k < (big ? 8 : 5); k++) {
      final ph = (t * 0.45 + k * 0.14) % 1.0;
      final sx = x + (k % 2 == 0 ? 9 : (big ? 28 : 9)) + ph * 14;
      final sy = bottomY - h - 20 - ph * 55;
      _p.color = const Color(0xFF212121).withValues(alpha: (1 - ph) * 0.65);
      canvas.drawCircle(Offset(sx, sy), 4 + ph * 9, _p);
    }

    _p.color = const Color(0xFF8D4B3B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, bottomY - h, w, h), const Radius.circular(4)),
      _p,
    );
    final flick = 0.7 + 0.3 * math.sin(t * 14);
    _p.color = const Color(0xFFFF6D00).withValues(alpha: flick);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 8, bottomY - 13, w - 16, 10),
          const Radius.circular(3)),
      _p,
    );
  }

  void _ecoIncinerator(Canvas canvas, double x, double bottomY, double t,
      {required int tier, required double fill}) {
    final w = 32.0 + tier * 6.0;
    final h = 26.0 + tier * 4.0;

    // Silo penampung sampah tertutup kaca di bagian atas reaktor
    _drawBinTrashInside(canvas, x + 4, bottomY - h - 2, w - 8, fill);

    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFECEFF1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 6, bottomY - h - 16, 9, 16),
          const Radius.circular(3)),
      _p,
    );
    if (tier >= 2) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 20, bottomY - h - 20, 10, 20),
            const Radius.circular(3)),
        _p,
      );
    }

    for (var k = 0; k < 4; k++) {
      final ph = (t * 0.35 + k * 0.25) % 1.0;
      _p.color = const Color(0xFFE0F7FA).withValues(alpha: (1 - ph) * 0.55);
      canvas.drawCircle(
          Offset(x + 12 + math.sin(t * 2 + k) * 3, bottomY - h - 18 - ph * 28),
          3 + ph * 4,
          _p);
    }

    _p.color = const Color(0xFFF5F7F8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, bottomY - h, w, h), const Radius.circular(6)),
      _p,
    );
    _p.color = const Color(0xFF00BFA5);
    canvas.drawRect(Rect.fromLTWH(x, bottomY - h + 5, w, 4), _p);

    final pulse = 0.6 + 0.4 * math.sin(t * 6);
    _p.color = const Color(0xFF00E676).withValues(alpha: pulse);
    canvas.drawCircle(Offset(x + w / 2, bottomY - h / 2 + 2), 4.5 + tier, _p);
  }

}