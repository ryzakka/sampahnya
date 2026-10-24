part of 'kost_scene.dart';

// ====================================================================
//  POHON PEMBATAS ANTAR RUMAH (mode jalan)
//
//  Satu pohon utama di tiap batas dua rumah (+ semak kecil pendamping),
//  jenisnya berbeda-beda: rindang, cemara, kelapa, cipres, flamboyan,
//  beringin, bambu. Pilihan jenis stabil (dari hash biome & posisi, sama di
//  semua perangkat), dan tetangga tidak pernah sejenis berurutan.
//  Daftar jenis menyesuaikan biome ruangan.
//
//  Terpengaruh event (semua MURNI visual, ikut fase peringatan & fade):
//    angin kencang : menunduk searah angin, daun & ranting beterbangan
//    gempa         : bergetar hebat, daun/kelopak rontok
//    hujan/banjir  : kuyup & gelap, tetesan air dari tajuk
//    kemarau       : perlahan menguning, layu menunduk, daun gugur
//    subsidi eco   : segar, berbunga
//    pasar malam   : lampu hias warna-warni di tajuk
//    wabah tikus   : tikus berlarian di pangkal batang
//    mogok truk    : kantong sampah menumpuk di pangkal
//    semester baru : balon terikat di dahan
//  Polusi juga mengeringkan warna daun (seperti pohon latar).
// ====================================================================

const int _tBroad = 0;
const int _tPine = 1;
const int _tPalm = 2;
const int _tCypress = 3;
const int _tFlam = 4;
const int _tBanyan = 5;
const int _tBamboo = 6;

/// Pengaruh event pada pohon, dihitung sekali per frame (0..1 tiap faktor).
class _TreeEnv {
  const _TreeEnv({
    this.wind = 0,
    this.quake = 0,
    this.wet = 0,
    this.dry = 0,
    this.bloom = 0,
    this.lights = 0,
    this.rats = 0,
    this.bags = 0,
    this.balloons = 0,
  });

  final double wind, quake, wet, dry, bloom, lights, rats, bags, balloons;
}

extension KostPainterTrees on KostPainter {
  // ------------------------------------------------------ lingkungan

  _TreeEnv _treeEnv() {
    final ev = d.worldEvent;
    final k = ev == null ? 0.0 : _evK;
    final pe = d.pendingEvent;
    final w = pe == null ? 0.0 : _evSmooth(_warnK);

    // [evMul] saat aktif, [warnMul] saat masih peringatan
    double pick(String name, double evMul, double warnMul) =>
        ev == name ? k * evMul : (pe == name ? w * warnMul : 0.0);

    var dry = pick('drought', 1.0, 0.45);
    if (ev == 'drought') {
      // menguning bertahap selama kemarau, bukan sekejap
      dry *= 0.35 + 0.65 * _evSmooth(d.eventAge / 12.0);
    }
    return _TreeEnv(
      wind: pick('strong_wind', 1.0, 0.55),
      quake: pick('earthquake', 1.0, 0.30),
      wet: math.max(pick('heavy_rain', 1.0, 0.5), pick('rain_flood', 0.85, 0.5)),
      dry: dry,
      bloom: pick('eco_subsidy', 1.0, 0.5),
      lights: pick('night_market', 1.0, 1.0),
      rats: pick('rat_plague', 1.0, 0.6),
      bags: pick('hauler_strike', 1.0, 0.0),
      balloons: pick('new_semester', 1.0, 0.5),
    );
  }

  /// Warna daun setelah dipengaruhi polusi & event.
  Color _tc(Color base, _TreeEnv e, double p) {
    var c = _mix(base, const Color(0xFF8D8B4A), p * 1.2);
    c = _mix(c, const Color(0xFFC9A227), e.dry * 0.8);
    c = _mix(c, const Color(0xFF1B5E20), e.wet * 0.28);
    c = _mix(c, const Color(0xFF7CFF4F), e.bloom * 0.22);
    return c;
  }

  /// Simpangan pucuk (px) = goyang pelan + angin + gempa.
  double _treeSway(double t, int h, _TreeEnv e, double p, {double flex = 1.0}) {
    final ph = (h % 100) * 0.37;
    final calm = math.sin(t * 1.2 + ph) * 1.6 * (1 - p);
    final wind = e.wind *
        (7 + 5 * math.sin(t * 0.9 + ph) + 3 * math.sin(t * 5.5 + ph * 0.7));
    final quake = e.quake *
        (math.sin(t * 38 + ph) * 2.4 + math.sin(t * 23 + ph * 0.5) * 1.4);
    return (calm + wind + quake) * flex;
  }

  // ------------------------------------------------------ jenis per biome

  List<int> _treePool(KostBiome b) => switch (b) {
    KostBiome.kota => const [_tBroad, _tFlam, _tBanyan, _tBamboo, _tPalm],
    KostBiome.gunung => const [_tPine, _tCypress, _tBroad],
    KostBiome.pantai => const [_tPalm, _tBamboo, _tFlam],
    KostBiome.sawah => const [_tPalm, _tBamboo, _tBroad, _tBanyan],
    KostBiome.lembah => const [_tCypress, _tPine, _tBroad, _tFlam],
  };

  int _treeSpecies(int i, List<int> pool) {
    int pickAt(int k) =>
        pool[_hh(k * 31 + d.biome.index * 7 + 11) % pool.length];
    var prev = -1;
    var s = pool.first;
    for (var k = 1; k <= i; k++) {
      s = pickAt(k);
      if (s == prev && pool.length > 1) {
        s = pool[(pool.indexOf(s) + 1) % pool.length];
      }
      prev = s;
    }
    return s;
  }

  // ------------------------------------------------------ pintu masuk

  void _drawStreetTrees(Canvas canvas, double t, double p) {
    final n = (_streetW / _w).round();
    if (n < 2) return;
    final e = _treeEnv();
    final pool = _treePool(d.biome);
    final lite = d.compact || _fxScale > 1.8;
    final base = _gy + 3.0;

    for (var i = 1; i < n; i++) {
      final bx = i * _w;
      if (bx < _vl - 90 || bx > _vr + 90) continue;
      final h = _hh(i * 31 + d.biome.index * 7 + 11);
      final x = bx + 2.0 + (h % 13) - 6;
      final s = 0.9 + (h % 5) / 10;

      // semak pendamping (di belakang pohon utama)
      if (!lite) {
        _shrub(canvas, x - 17 - (h % 7), base, 0.8 + (h % 3) / 10, h, t, p, e);
      }

      final Rect crown;
      Color leaf = _tc(const Color(0xFF4CAF50), e, p);
      switch (_treeSpecies(i, pool)) {
        case _tPine:
          crown = _treePine(canvas, x, base, s, h, t, p, e);
        case _tPalm:
          crown = _treePalm(canvas, x, base, s, h, t, p, e);
        case _tCypress:
          crown = _treeCypress(canvas, x, base, s, h, t, p, e);
        case _tFlam:
          crown = _treeFlam(canvas, x, base, s, h, t, p, e);
          leaf = _mix(const Color(0xFFE53935), const Color(0xFFC9A227), e.dry * 0.7);
        case _tBanyan:
          crown = _treeBanyan(canvas, x, base, s, h, t, p, e);
        case _tBamboo:
          crown = _treeBamboo(canvas, x, base, s, h, t, p, e);
        default:
          crown = _treeBroad(canvas, x, base, s, h, t, p, e);
      }
      _treeFx(canvas, crown, x, base, h, t, e, leaf, lite);
    }
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt
      ..blendMode = BlendMode.srcOver;
  }

  // ------------------------------------------------------ bentuk

  void _trunk(Canvas c, double x, double base, Offset top, double w, Color col) {
    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w
      ..color = col;
    c.drawPath(
        Path()
          ..moveTo(x, base)
          ..quadraticBezierTo(
              x + (top.dx - x) * 0.15, (base + top.dy) / 2, top.dx, top.dy),
        _p);
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }

  void _shrub(Canvas c, double x, double base, double s, int h, double t,
      double p, _TreeEnv e) {
    final dx = _treeSway(t, h + 5, e, p) * 0.35;
    _p
      ..style = PaintingStyle.fill
      ..color = _tc(const Color(0xFF558B2F), e, p);
    c.drawCircle(Offset(x + dx, base - 8 * s), 8 * s, _p);
    c.drawCircle(Offset(x - 7 * s + dx * 0.7, base - 4 * s), 6 * s, _p);
    c.drawCircle(Offset(x + 7 * s + dx * 0.7, base - 4 * s), 6.5 * s, _p);
    _p.color = _tc(const Color(0xFF7CB342), e, p);
    c.drawCircle(Offset(x - 2 * s + dx, base - 11 * s), 4 * s, _p);
  }

  /// Pohon rindang (tajuk bulat).
  Rect _treeBroad(Canvas c, double x, double base, double s, int h, double t,
      double p, _TreeEnv e) {
    final dx = _treeSway(t, h, e, p);
    final droop = e.wet * 2.0 + e.dry * 3.0;
    final top = Offset(x + dx, base - 36 * s + droop);
    _trunk(c, x, base, Offset(x + dx * 0.5, base - 24 * s), 5 * s,
        const Color(0xFF6D4C41));
    _p.color = _tc(const Color(0xFF4CAF50), e, p);
    c.drawCircle(top, 17 * s, _p);
    c.drawCircle(top + Offset(-12 * s, 9 * s), 12 * s, _p);
    c.drawCircle(top + Offset(12 * s, 9 * s), 12 * s, _p);
    _p.color = _tc(const Color(0xFF66BB6A), e, p);
    c.drawCircle(top + Offset(-5 * s, -5 * s), 9 * s, _p);
    return Rect.fromCircle(center: top + Offset(0, 4 * s), radius: 20 * s);
  }

  /// Cemara bersusun.
  Rect _treePine(Canvas c, double x, double base, double s, int h, double t,
      double p, _TreeEnv e) {
    final dx = _treeSway(t, h, e, p);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF5D4037);
    c.drawRect(Rect.fromLTWH(x - 2 * s, base - 12 * s, 4 * s, 14 * s), _p);
    final droop = e.wet * 1.5 + e.dry * 2.0;
    for (var i = 0; i < 4; i++) {
      final sx = dx * (0.25 + 0.22 * i);
      final yb = base - 8 * s - i * 15 * s + droop * (i / 3);
      final w = (32 - i * 6.5) * s;
      _p.color = _tc(i.isEven ? const Color(0xFF2E7D32) : const Color(0xFF1B5E20), e, p);
      c.drawPath(
          Path()
            ..moveTo(x + sx, yb - 20 * s)
            ..lineTo(x + sx - w / 2, yb)
            ..lineTo(x + sx + w / 2, yb)
            ..close(),
          _p);
    }
    return Rect.fromCenter(
        center: Offset(x + dx * 0.6, base - 40 * s), width: 34 * s, height: 56 * s);
  }

  /// Pohon kelapa.
  Rect _treePalm(Canvas c, double x, double base, double s, int h, double t,
      double p, _TreeEnv e) {
    final dx = _treeSway(t, h, e, p);
    final lean = ((h % 3) - 1) * 7.0 + e.wind * 6;
    final topX = x + lean + dx * 0.7;
    final topY = base - 52 * s - (h % 7);
    _trunk(c, x, base, Offset(topX, topY), 4.2 * s, const Color(0xFF8D6E63));
    final droop = e.dry * 5 + e.wet * 3;
    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.2 * s
      ..color = _tc(const Color(0xFF2E9A4A), e, p);
    for (var i = 0; i < 7; i++) {
      final a = -math.pi + i * math.pi / 6;
      final flap = math.sin(t * 1.6 + i + x) * 1.5 * (1 - p) +
          e.wind * math.sin(t * 6 + i) * 3 +
          e.quake * math.sin(t * 30 + i) * 2;
      final ctrl = Offset(topX + math.cos(a) * 14 * s + e.wind * 5,
          topY + math.sin(a) * 14 * s - 8 + flap);
      final tip = Offset(topX + math.cos(a) * 28 * s + e.wind * 9,
          topY + math.sin(a) * 10 * s + 13 + flap * 1.5 + droop);
      c.drawPath(
          Path()
            ..moveTo(topX, topY)
            ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy),
          _p);
    }
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xFF6D4C41);
    c.drawCircle(Offset(topX - 3 * s, topY + 4 * s), 2.6 * s, _p);
    c.drawCircle(Offset(topX + 3 * s, topY + 5 * s), 2.6 * s, _p);
    return Rect.fromCenter(
        center: Offset(topX, topY + 8 * s), width: 56 * s, height: 26 * s);
  }

  /// Cipres ramping.
  Rect _treeCypress(Canvas c, double x, double base, double s, int h, double t,
      double p, _TreeEnv e) {
    final dx = _treeSway(t, h, e, p);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF5D4037);
    c.drawRect(Rect.fromLTWH(x - 1.8 * s, base - 8 * s, 3.6 * s, 10 * s), _p);
    const widths = [12.0, 16.0, 15.0, 12.0, 9.0, 5.0];
    for (var i = 0; i < widths.length; i++) {
      final sx = dx * (i / 5);
      _p.color = _tc(i.isEven ? const Color(0xFF2F7D3E) : const Color(0xFF256B35), e, p);
      c.drawOval(
          Rect.fromCenter(
              center: Offset(x + sx, base - 10 * s - i * 9.5 * s),
              width: widths[i] * 2 * s,
              height: 15 * s),
          _p);
    }
    return Rect.fromCenter(
        center: Offset(x + dx * 0.6, base - 38 * s), width: 30 * s, height: 62 * s);
  }

  /// Flamboyan: payung lebar berbunga merah-jingga.
  Rect _treeFlam(Canvas c, double x, double base, double s, int h, double t,
      double p, _TreeEnv e) {
    final dx = _treeSway(t, h, e, p);
    final droop = e.wet * 2.0 + e.dry * 3.0;
    final top = Offset(x + dx, base - 38 * s + droop);
    const wood = Color(0xFF6D4C41);
    _trunk(c, x, base, Offset(x + dx * 0.3, base - 22 * s), 6 * s, wood);
    _trunk(c, x + dx * 0.3, base - 20 * s,
        Offset(top.dx - 15 * s, top.dy + 4 * s), 3 * s, wood);
    _trunk(c, x + dx * 0.3, base - 20 * s,
        Offset(top.dx + 15 * s, top.dy + 4 * s), 3 * s, wood);
    // daun hijau di bawah, bunga di atasnya
    _p
      ..style = PaintingStyle.fill
      ..color = _tc(const Color(0xFF43A047), e, p);
    c.drawOval(
        Rect.fromCenter(center: top + Offset(0, 3 * s), width: 50 * s, height: 20 * s),
        _p);
    _p.color = _mix(const Color(0xFFE53935), const Color(0xFFC9A227), e.dry * 0.7);
    c.drawOval(
        Rect.fromCenter(center: top, width: 42 * s, height: 24 * s), _p);
    c.drawOval(
        Rect.fromCenter(center: top + Offset(-16 * s, 2 * s), width: 28 * s, height: 18 * s),
        _p);
    c.drawOval(
        Rect.fromCenter(center: top + Offset(16 * s, 2 * s), width: 28 * s, height: 18 * s),
        _p);
    // kelopak yang lebih terang
    final pet = 12 + (e.bloom * 8).round();
    for (var i = 0; i < pet; i++) {
      final hh = _hh(i + h * 5);
      final ang = (hh % 628) / 100;
      final rr = ((hh ~/ 7) % 100) / 100;
      _p.color = (i.isEven ? const Color(0xFFFF7043) : const Color(0xFFFFAB91))
          .withValues(alpha: 1 - 0.5 * e.dry);
      c.drawCircle(
          Offset(top.dx + math.cos(ang) * 19 * s * rr,
              top.dy + math.sin(ang) * 8 * s * rr - 2 * s),
          2.1 * s,
          _p);
    }
    return Rect.fromCenter(center: top, width: 54 * s, height: 30 * s);
  }

  /// Beringin: tajuk lebar gelap + akar gantung yang berayun.
  Rect _treeBanyan(Canvas c, double x, double base, double s, int h, double t,
      double p, _TreeEnv e) {
    final dx = _treeSway(t, h, e, p) * 0.7;
    final droop = e.wet * 1.5 + e.dry * 2.5;
    const wood = Color(0xFF5D4037);
    _trunk(c, x, base, Offset(x + dx * 0.3, base - 26 * s), 9 * s, wood);
    _trunk(c, x - 6 * s, base, Offset(x - 3 * s, base - 14 * s), 3 * s, wood);
    _trunk(c, x + 6 * s, base, Offset(x + 3 * s, base - 14 * s), 3 * s, wood);
    const blobs = [
      [-24.0, 4.0, 14.0],
      [-12.0, -6.0, 17.0],
      [2.0, -10.0, 19.0],
      [16.0, -4.0, 16.0],
      [27.0, 5.0, 13.0],
    ];
    final cy = base - 42 * s + droop;
    _p.style = PaintingStyle.fill;
    for (var i = 0; i < blobs.length; i++) {
      _p.color = _tc(i.isEven ? const Color(0xFF2E7D32) : const Color(0xFF388E3C), e, p);
      c.drawCircle(Offset(x + dx + blobs[i][0] * s, cy + blobs[i][1] * s),
          blobs[i][2] * s, _p);
    }
    // akar gantung
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..color = wood;
    for (var i = 0; i < 6; i++) {
      final rx = x + dx + (-22 + i * 9.0) * s;
      final len = (14 + (_hh(i + h) % 17)) * s;
      final sw = math.sin(t * 1.5 + i + h) * (1 + e.wind * 5 + e.quake * 3);
      c.drawPath(
          Path()
            ..moveTo(rx, cy + 12 * s)
            ..quadraticBezierTo(rx + sw * 0.4, cy + 12 * s + len * 0.5,
                rx + sw, cy + 12 * s + len),
          _p);
    }
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
    return Rect.fromCenter(
        center: Offset(x + dx, cy), width: 68 * s, height: 38 * s);
  }

  /// Rumpun bambu: lentur, paling heboh kena angin.
  Rect _treeBamboo(Canvas c, double x, double base, double s, int h, double t,
      double p, _TreeEnv e) {
    final dx = _treeSway(t, h, e, p, flex: 1.7);
    var maxH = 0.0;
    for (var i = 0; i < 5; i++) {
      final hh = _hh(i + h * 3);
      final sx = x + (i - 2) * 5.0 * s;
      final ht = (44 + hh % 16) * s - e.dry * 4;
      maxH = math.max(maxH, ht);
      final lean = (i - 2) * 3.0 + dx * (0.8 + (hh % 5) / 10);
      final top = Offset(sx + lean, base - ht);
      _p
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4 * s
        ..color = _tc(const Color(0xFF9CCC65), e, p);
      c.drawPath(
          Path()
            ..moveTo(sx, base)
            ..quadraticBezierTo(sx + lean * 0.3, base - ht * 0.55, top.dx, top.dy),
          _p);
      // ruas
      _p
        ..strokeWidth = 1.0
        ..color = const Color(0xFF558B2F);
      for (var k = 1; k <= 3; k++) {
        final u = k / 4.0;
        final nx = sx + lean * u * u * 1.0;
        final ny = base - ht * u;
        c.drawLine(Offset(nx - 1.8 * s, ny), Offset(nx + 1.8 * s, ny), _p);
      }
      // rumpun daun di pucuk
      _p
        ..style = PaintingStyle.fill
        ..color = _tc(const Color(0xFF558B2F), e, p);
      for (var k = 0; k < 3; k++) {
        c.save();
        c.translate(top.dx, top.dy + 2);
        c.rotate(-0.9 + k * 0.9 + math.sin(t * 2 + i + k) * 0.12 * (1 + e.wind * 3));
        c.drawOval(Rect.fromLTWH(0, -1.2 * s, 12 * s, 2.6 * s), _p);
        c.restore();
      }
    }
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
    return Rect.fromLTRB(x - 18 * s + dx * 0.5, base - maxH - 4, x + 18 * s + dx * 1.2,
        base - maxH * 0.45);
  }

  // ------------------------------------------------------ efek event

  void _treeFx(Canvas c, Rect cb, double x, double base, int h, double t,
      _TreeEnv e, Color leaf, bool lite) {
    // daun/kelopak rontok: angin (menyamping), gempa (jatuh lurus), kemarau
    final f = math.max(e.wind, math.max(e.quake * 0.9, e.dry * 0.45));
    if (f > 0.03) {
      final n = (f * (lite ? 4 : 11)).round();
      _p.style = PaintingStyle.fill;
      for (var i = 0; i < n; i++) {
        final hh = _hh(i + h * 3);
        final u = (t * (0.35 + (hh % 5) * 0.06) + (hh % 100) / 100) % 1.0;
        final sx = cb.center.dx + ((hh % 1000) / 1000 - 0.5) * cb.width * 0.9;
        final sy = cb.center.dy;
        final px = sx + e.wind * 80 * u + math.sin(t * 3 + i) * 3 * (1 - e.quake * 0.7);
        final py = sy + u * (base - sy);
        c.save();
        c.translate(px, py);
        c.rotate(t * 4 + i);
        _p.color = leaf.withValues(alpha: (1 - u * 0.5) * math.min(1.0, f * 2));
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: 3.6, height: 2.2), _p);
        c.restore();
      }
    }

    // tetes air dari tajuk saat hujan
    if (e.wet > 0.25 && !lite) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = const Color(0xFFE3F2FD).withValues(alpha: 0.6 * e.wet);
      for (var i = 0; i < 4; i++) {
        final hh = _hh(i + h * 9);
        final u = (t * 1.4 + (hh % 100) / 100) % 1.0;
        final dxp = cb.left + 6 + (hh % 1000) / 1000 * (cb.width - 12);
        final y0 = cb.bottom - 4;
        final y = y0 + u * (base - y0);
        c.drawLine(Offset(dxp, y), Offset(dxp, y + 3.5), _p);
      }
      _p.style = PaintingStyle.fill;
    }

    // lampu hias pasar malam
    if (e.lights > 0.02) {
      const cols = [
        Color(0xFFFF5252),
        Color(0xFFFFCA28),
        Color(0xFF29B6F6),
        Color(0xFF66BB6A),
      ];
      _p.style = PaintingStyle.fill;
      for (var i = 0; i < 10; i++) {
        final ang = i / 10 * 2 * math.pi;
        final px = cb.center.dx + math.cos(ang) * cb.width * 0.42;
        final py = cb.center.dy + math.sin(ang) * cb.height * 0.36 + 2;
        final glow = 0.6 + 0.4 * math.sin(t * 4 + i + h);
        final col = cols[(i + h) % cols.length];
        _p.color = col.withValues(alpha: 0.22 * glow * e.lights);
        c.drawCircle(Offset(px, py), 5, _p);
        _p.color = col.withValues(alpha: 0.95 * glow * e.lights);
        c.drawCircle(Offset(px, py), 1.8, _p);
      }
    }

    // bunga segar saat subsidi eco
    if (e.bloom > 0.05 && !lite) {
      _p.style = PaintingStyle.fill;
      for (var i = 0; i < 9; i++) {
        final hh = _hh(i + h * 11);
        final px = cb.left + 4 + (hh % 1000) / 1000 * (cb.width - 8);
        final py = cb.top + 4 + ((hh ~/ 9) % 1000) / 1000 * (cb.height - 8);
        final tw = 0.6 + 0.4 * math.sin(t * 3 + i);
        _p.color = (i.isEven ? const Color(0xFFF8BBD0) : Colors.white)
            .withValues(alpha: 0.9 * e.bloom * tw);
        c.drawCircle(Offset(px, py), 1.7, _p);
      }
    }

    // tikus di pangkal batang (wabah)
    if (e.rats > 0.05) {
      _p.style = PaintingStyle.fill;
      for (var i = 0; i < 2; i++) {
        final rx = x + math.sin(t * (1.6 + i * 0.5) + h + i * 2) * 16;
        final dir = math.cos(t * (1.6 + i * 0.5) + h + i * 2) >= 0 ? 1.0 : -1.0;
        final ry = base + 3 + i * 3 + math.sin(t * 22 + i) * 0.5;
        _p.color = const Color(0xFF3E2723).withValues(alpha: 0.85 * e.rats);
        c.drawOval(Rect.fromCenter(center: Offset(rx, ry), width: 6, height: 3.2), _p);
        c.drawCircle(Offset(rx + dir * 3, ry), 1.4, _p);
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6;
        c.drawLine(Offset(rx - dir * 3, ry), Offset(rx - dir * 6.5, ry - 1), _p);
        _p.style = PaintingStyle.fill;
      }
    }

    // kantong sampah menumpuk saat truk mogok
    if (e.bags > 0.05) {
      _p.style = PaintingStyle.fill;
      for (var i = 0; i < 3; i++) {
        final bx = x + (i - 1) * 9.0 + ((h + i) % 5) - 2;
        final by = base + 4 + (i == 1 ? -2 : 0);
        final sc = e.bags;
        _p.color = (i == 1 ? const Color(0xFF263238) : const Color(0xFF37474F))
            .withValues(alpha: sc);
        c.drawOval(
            Rect.fromCenter(center: Offset(bx, by), width: 8 * sc, height: 7 * sc), _p);
        c.drawRect(Rect.fromLTWH(bx - 1, by - 5.2 * sc, 2, 2.2 * sc), _p);
      }
    }

    // balon semester baru terikat di dahan
    if (e.balloons > 0.05) {
      const cols = [Color(0xFFFF5252), Color(0xFFFFCA28), Color(0xFF29B6F6)];
      for (var i = 0; i < 2; i++) {
        final ax = cb.center.dx + (i == 0 ? -cb.width * 0.25 : cb.width * 0.2);
        final ay = cb.center.dy;
        final bob = math.sin(t * 1.8 + i + h) * 3;
        final by = ay - 20 - i * 6 + bob;
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..color = Colors.white70.withValues(alpha: e.balloons);
        c.drawLine(Offset(ax, ay), Offset(ax + bob * 0.4, by + 6), _p);
        _p
          ..style = PaintingStyle.fill
          ..color = cols[(i + h) % cols.length].withValues(alpha: e.balloons);
        c.drawOval(
            Rect.fromCenter(center: Offset(ax + bob * 0.4, by), width: 10, height: 13), _p);
      }
    }
    _p.style = PaintingStyle.fill;
  }
}