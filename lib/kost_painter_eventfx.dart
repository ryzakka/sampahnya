part of 'kost_scene.dart';

// ====================================================================
//  EFEK EVENT: PERINGATAN, TRANSISI, DAMPAK
//
//  1) PERINGATAN (~4 dtk sebelum event aktif): langit/udara mulai berubah
//     sesuai jenis event + denyut tepi layar berwarna. Data dari
//     KostSceneData.pendingEvent / pendingLeft.
//  2) TRANSISI: efek cuaca tidak lagi muncul/hilang mendadak. Intensitas
//     [_evK] naik ~1,6 dtk saat event mulai dan turun ~1,6 dtk setelah
//     event selesai (event yang baru berakhir tetap digambar sebentar,
//     lihat eventLeft < 0). Hujan deras -> banjir berlanjut tanpa jeda
//     (eventChained), air naik/surut perlahan.
//  3) DAMPAK: FxType.quake (dari game_events 'quake_hit') -> hentakan
//     kamera, cincin getar tanah, sampah tumpah dari jendela/atap, debu &
//     retak di gudang, angka "+N" melayang.
//
//  MURNI visual; angka gameplay tetap dari server.
// ====================================================================

const double _evFadeSec = 1.6;
const double _evWarnSec = 4.0;

extension KostPainterEventFx on KostPainter {
  double _evSmooth(double x) {
    final s = _c01(x);
    return s * s * (3 - 2 * s);
  }

  /// Fade-in 0..1 (1 bila event ini lanjutan langsung dari hujan deras).
  double get _evIn =>
      d.worldEvent == null || d.eventChained
          ? (d.worldEvent == null ? 0.0 : 1.0)
          : _evSmooth(d.eventAge / _evFadeSec);

  /// Fade-out 0..1. eventLeft < 0 = event sudah selesai, -eventLeft = detik
  /// sejak selesai (masih digambar selama [_evFadeSec]).
  double get _evOut =>
      d.eventLeft >= 0 ? 1.0 : _evSmooth(1 + d.eventLeft / _evFadeSec);

  /// Intensitas gabungan 0..1 untuk seluruh lapisan event.
  double get _evK => math.min(_evIn, _evOut);

  /// Kemajuan peringatan 0..1 (0 = baru diumumkan, 1 = event mulai).
  double get _warnK =>
      d.pendingEvent == null ? 0.0 : _c01(1 - d.pendingLeft / _evWarnSec);

  Color _evHue(String ev) => switch (ev) {
    'rain_flood' || 'heavy_rain' => const Color(0xFF42A5F5),
    'strong_wind' => const Color(0xFFB0BEC5),
    'drought' => const Color(0xFFFF8F00),
    'blackout' => const Color(0xFF7E57C2),
    'rat_plague' => const Color(0xFF8D6E63),
    'earthquake' => const Color(0xFFE65100),
    'new_semester' => const Color(0xFFFFCA28),
    'hauler_strike' => const Color(0xFFFF6F00),
    'eco_subsidy' => const Color(0xFF00E676),
    'night_market' => const Color(0xFFE040FB),
    _ => const Color(0xFFFFFFFF),
  };

  // ================================================== 1) PERINGATAN

  void _drawEventWarning(Canvas canvas, double t) {
    final ev = d.pendingEvent;
    if (ev == null || d.pendingLeft <= 0 || d.eliminated) return;
    final w = _evSmooth(_warnK);
    final col = _evHue(ev);
    final spanX = _vr - _vl;
    final spanY = _gy - _vt;
    final view = Rect.fromLTRB(_vl, _vt, _vr, _vb);

    // denyut tepi layar (makin cepat & pekat mendekati mulai)
    final pulse = 0.5 + 0.5 * math.sin(t * (4 + 7 * w));
    final c = view.center;
    final r = math.sqrt(view.width * view.width + view.height * view.height) / 2;
    _p
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          col.withValues(alpha: 0),
          col.withValues(alpha: (0.10 + 0.26 * w) * (0.45 + 0.55 * pulse)),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawRect(view, _p);
    _p.shader = null;

    switch (ev) {
      case 'heavy_rain' || 'rain_flood':
        _warnRain(canvas, t, w, spanX, spanY);
      case 'strong_wind':
        _warnWind(canvas, t, w, spanX, spanY);
      case 'drought':
        _warnDrought(canvas, t, w);
      case 'blackout':
        _warnBlackout(canvas, t, w);
      case 'earthquake':
        _warnQuake(canvas, t, w, spanX);
      case 'rat_plague':
        _warnRats(canvas, t, w, spanX);
      case 'night_market':
        canvas.saveLayer(view, Paint()..color = Color.fromRGBO(0, 0, 0, w));
        _wxNightMarket(canvas, t);
        canvas.restore();
      case 'new_semester' || 'eco_subsidy':
        _warnSparkle(canvas, t, w, spanX, spanY, col);
    }
    _p.style = PaintingStyle.fill;
  }

  void _warnRain(Canvas canvas, double t, double w, double spanX, double spanY) {
    // awan gelap menurun dari atas
    _p
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF37474F).withValues(alpha: 0.38 * w),
          const Color(0xFF37474F).withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTRB(_vl, _vt, _vr, _gy));
    canvas.drawRect(Rect.fromLTRB(_vl, _vt, _vr, _gy), _p);
    _p.shader = null;

    // petir jauh (kilat tipis) di paruh akhir peringatan
    if (w > 0.45 && (t * 1.9) % 3.0 < 0.14) {
      _p.color = Colors.white.withValues(alpha: 0.22 * w);
      canvas.drawRect(Rect.fromLTRB(_vl, _vt, _vr, _gy), _p);
    }

    // gerimis pertama: jarang, makin rapat
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * _fxScale
      ..color = const Color(0xFFE3F2FD).withValues(alpha: 0.5 * w);
    final n = ((d.compact ? 6 : 22) * w).round();
    for (var i = 0; i < n; i++) {
      final h = _hh(i + 300);
      final dx = _vl + ((h % 1000) / 1000 * spanX - t * 60) % spanX;
      final dy = _vt + ((t * 300 + h % 500) % (_vb - _vt));
      canvas.drawLine(
          Offset(dx, dy), Offset(dx - 4 * _fxScale, dy + 11 * _fxScale), _p);
    }
  }

  void _warnWind(Canvas canvas, double t, double w, double spanX, double spanY) {
    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0 * _fxScale
      ..color = Colors.white.withValues(alpha: 0.30 * w);
    final n = ((d.compact ? 4 : 12) * w).ceil();
    for (var i = 0; i < n; i++) {
      final h = _hh(i + 700);
      final y = _vt + (h % 1000) / 1000 * spanY + math.sin(t * 3 + i) * 2;
      final x = _vl + ((t * (200.0 + (h % 5) * 50) + h % 900) % (spanX + 80)) - 40;
      final len = (20.0 + (h % 5) * 8) * _fxScale;
      canvas.drawLine(Offset(x - len, y), Offset(x, y), _p);
    }
    _p.strokeCap = StrokeCap.butt;

    // beberapa daun/kertas mulai terbang
    _p.style = PaintingStyle.fill;
    final leaves = (5 * w).round();
    for (var i = 0; i < leaves; i++) {
      final h = _hh(i + 740);
      final x = _vl + ((t * (150.0 + h % 60) + h % 700) % (spanX + 60)) - 30;
      final y = _vt + 80 + (h % 1000) / 1000 * (spanY - 90) + math.sin(t * 4 + i) * 10;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 4 + i);
      _p.color = (i.isEven ? const Color(0xFF8BC34A) : const Color(0xFFF5F5F5))
          .withValues(alpha: 0.85 * w);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 5 * _fxScale, height: 3.5 * _fxScale),
          _p);
      canvas.restore();
    }
  }

  void _warnDrought(Canvas canvas, double t, double w) {
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFF8F00).withValues(alpha: 0.08 * w);
    canvas.drawRect(Rect.fromLTRB(_vl, _vt, _vr, _vb), _p);

    final c = Offset(_vl + (_vr - _vl) * 0.78, _vt + 34);
    final rad = 60 + 90 * w;
    _p.shader = RadialGradient(colors: [
      const Color(0xFFFFF59D).withValues(alpha: 0.34 * w),
      const Color(0xFFFFF59D).withValues(alpha: 0),
    ]).createShader(Rect.fromCircle(center: c, radius: rad));
    canvas.drawCircle(c, rad, _p);
    _p.shader = null;

    // uap panas mulai menggelombang
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.10 * w);
    final lines = (d.compact ? 2 : 5);
    for (var k = 0; k < lines; k++) {
      final y = _gy - 4 - k * 5.0;
      final path = Path()..moveTo(_vl, y);
      for (var x = _vl; x <= _vr; x += 24) {
        path.lineTo(x, y + math.sin(t * 2.2 + x * 0.05 + k) * 1.4 * w);
      }
      canvas.drawPath(path, _p);
    }
  }

  void _warnBlackout(Canvas canvas, double t, double w) {
    if (d.wasteLevel >= 10) return; // Insinerator Lv 10+ kebal
    // lampu berkedip makin sering; percikan di tiang listrik
    final thr = 0.92 - 0.75 * w;
    final f = math.sin(t * 23) * math.sin(t * 7.1);
    if (f > thr) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF050816).withValues(alpha: 0.18 + 0.30 * w);
      canvas.drawRect(Rect.fromLTRB(_vl, _vt, _vr, _vb), _p);
    }
    if (w > 0.3 && (t * 6.3) % 1.0 < 0.18) {
      final sx = _vl + (_vr - _vl) * (0.2 + 0.6 * ((_hh((t * 6.3).floor()) % 100) / 100));
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFF59D).withValues(alpha: 0.9);
      for (var k = 0; k < 4; k++) {
        final a = -math.pi / 2 + (k - 1.5) * 0.7;
        canvas.drawLine(Offset(sx, _gy - 30),
            Offset(sx + math.cos(a) * 7, _gy - 30 + math.sin(a) * 7), _p);
      }
      _p.strokeCap = StrokeCap.butt;
    }
  }

  void _warnQuake(Canvas canvas, double t, double w, double spanX) {
    // debu dan kerikil rontok dari atap
    final x0 = _bl, x1 = _bl + 4 * _cw;
    _p.style = PaintingStyle.fill;
    final n = ((d.compact ? 5 : 16) * (0.3 + 0.7 * w)).round();
    for (var i = 0; i < n; i++) {
      final h = _hh(i + 1500);
      final life = (t * 0.9 + (h % 100) / 100) % 1.0;
      final x = x0 + (h % 1000) / 1000 * (x1 - x0);
      final y = _roofY + life * (_gy - _roofY);
      _p.color = const Color(0xFFBCAAA4).withValues(alpha: (1 - life) * 0.5 * w);
      canvas.drawCircle(Offset(x, y), 0.9 + (h % 3) * 0.5, _p);
    }
    // retak tipis tanah mulai merambat
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF3E2723).withValues(alpha: 0.7 * w);
    final cracks = d.compact ? 1 : 3;
    for (var k = 0; k < cracks; k++) {
      final xs = _vl + (_hh(k + 520) % 1000) / 1000 * spanX;
      var x = xs, y = _gy + 8.0;
      final path = Path()..moveTo(x, y);
      final steps = (5 * w).ceil();
      for (var s = 0; s < steps; s++) {
        final h = _hh(k * 10 + s + 530);
        x += ((h % 15) - 5).toDouble();
        y += 4 + (h % 4);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, _p);
    }
  }

  void _warnRats(Canvas canvas, double t, double w, double spanX) {
    // bayangan tikus berlarian dari tepi layar
    _p.style = PaintingStyle.fill;
    final n = d.compact ? 2 : 5;
    for (var i = 0; i < n; i++) {
      final h = _hh(i + 1600);
      final fromLeft = i.isEven;
      final u = _c01(w * 1.4 - (i % 3) * 0.12);
      if (u <= 0) continue;
      final x = fromLeft ? _vl + u * spanX * 0.45 : _vr - u * spanX * 0.45;
      final y = _gy + 14 + (h % 4) * 5.0;
      final dir = fromLeft ? 1.0 : -1.0;
      final bob = math.sin(t * 22 + i) * 0.6;
      _p.color = const Color(0xFF3E2723).withValues(alpha: 0.85);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y + bob), width: 7, height: 3.6), _p);
      canvas.drawCircle(Offset(x + dir * 3.6, y + bob), 1.6, _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7;
      canvas.drawLine(Offset(x - dir * 3.4, y + bob),
          Offset(x - dir * 7.5, y + bob - 1 + math.sin(t * 10 + i)), _p);
      _p.style = PaintingStyle.fill;
    }
  }

  void _warnSparkle(Canvas canvas, double t, double w, double spanX, double spanY,
      Color col) {
    _p.style = PaintingStyle.fill;
    final n = ((d.compact ? 6 : 18) * w).round();
    for (var i = 0; i < n; i++) {
      final h = _hh(i + 1700);
      final life = (t * 0.45 + (h % 100) / 100) % 1.0;
      final x = _vl + (h % 1000) / 1000 * spanX + math.sin(t * 2 + i) * 4;
      final y = _gy - life * spanY * 0.8;
      _p.color = col.withValues(alpha: math.sin(life * math.pi) * 0.75 * w);
      canvas.drawCircle(Offset(x, y), 1.4 + (h % 3) * 0.5, _p);
    }
  }

  /// Getaran awal gempa (dipanggil dari _shakeOffset): pelan, membesar
  /// selama peringatan agar pemain "merasakan" gempa akan datang.
  Offset _warnQuakeShake(double t) {
    if (d.pendingEvent != 'earthquake' || d.pendingLeft <= 0) return Offset.zero;
    final w = _evSmooth(_warnK);
    final resist = math.min(0.7, d.kostTier * 0.25 + d.wasteLevel * 0.02);
    final k = (1 - resist) * w * 0.35;
    return Offset(math.sin(t * 34) * 1.6 * k, math.cos(t * 27) * 1.1 * k);
  }

  // ================================================== 2) TRANSISI

  /// Lapisan depan event: peringatan (selalu) + efek event yang memudar
  /// masuk/keluar lewat saveLayer (hanya saat k < 1, jadi murah).
  void _drawWorldEventFront(Canvas canvas, double t) {
    _drawEventWarning(canvas, t);
    if (d.worldEvent == null) return;
    final k = _evK;
    if (k <= 0.004) return;
    final fade = k < 0.999;
    if (fade) {
      canvas.saveLayer(Rect.fromLTRB(_vl, _vt, _vr, _vb),
          Paint()..color = Color.fromRGBO(0, 0, 0, k));
    }
    _drawWorldEventFrontBody(canvas, t);
    if (fade) canvas.restore();
  }

  void _drawWorldEventBack(Canvas canvas, double t) {
    if (d.worldEvent == null) return;
    final k = _evK;
    if (k <= 0.004) return;
    final fade = k < 0.999;
    if (fade) {
      canvas.saveLayer(Rect.fromLTRB(_vl, _vt, _vr, _vb),
          Paint()..color = Color.fromRGBO(0, 0, 0, k));
    }
    _drawWorldEventBackBody(canvas, t);
    if (fade) canvas.restore();
  }

  /// Air banjir: naik perlahan (~4 dtk) saat banjir mulai, surut saat
  /// selesai; permukaan bergelombang + buih + puing mengapung.
  void _drawFloodWater(Canvas canvas, double t) {
    final rise = _evSmooth(d.eventAge / 4.0) * (d.eventLeft < 0 ? _evOut : 1.0);
    if (rise <= 0.01) return;
    final top = _vb - (_vb - 267) * rise;
    double surf(double x) =>
        top + math.sin(t * 2.4 + x * 0.07) * 1.6 * rise + math.sin(t * 1.3 + x * 0.03) * 1.2;

    final wave = Path()..moveTo(_vl, surf(_vl));
    for (var x = _vl + 8; x <= _vr + 8; x += 8) {
      wave.lineTo(x, surf(x));
    }
    final body = Path.from(wave)
      ..lineTo(_vr + 8, _vb + 4)
      ..lineTo(_vl, _vb + 4)
      ..close();
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF1976D2).withValues(alpha: 0.42);
    canvas.drawPath(body, _p);

    // buih di permukaan
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFE3F2FD).withValues(alpha: 0.45 * rise);
    canvas.drawPath(wave, _p);

    // puing mengapung (kantong, kardus, botol)
    _p.style = PaintingStyle.fill;
    const cols = [Color(0xFF455A64), Color(0xFF8D6E63), Color(0xFFB0BEC5), Color(0xFF8BC34A)];
    final n = d.compact ? 3 : 8;
    final span = _vr - _vl;
    for (var i = 0; i < n; i++) {
      final h = _hh(i + 2100);
      final x = _vl + ((t * (10 + h % 8) + h % 700) % (span + 40)) - 20;
      final y = surf(x) + 1.5 + math.sin(t * 2 + i) * 0.8;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(t * 1.6 + i) * 0.25);
      _p.color = cols[i % cols.length].withValues(alpha: 0.9 * rise);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: 6, height: 3.4),
              const Radius.circular(1.2)),
          _p);
      canvas.restore();
    }
  }

  // ================================================== 3) DAMPAK GEMPA

  /// Hentakan kamera saat gempa menghantam (peluruhan cepat ~0,9 dtk).
  Offset _quakeImpactShake() {
    final p = _fxProgress(FxType.quake, 2800);
    if (p == null) return Offset.zero;
    final ms = p * 2800;
    if (ms > 900) return Offset.zero;
    final q = 1 - ms / 900;
    final resist = math.min(0.7, d.kostTier * 0.25 + d.wasteLevel * 0.02);
    final k = (1 - resist) * q * q;
    return Offset(math.sin(ms * 0.09) * 5.0 * k, math.cos(ms * 0.07) * 3.4 * k);
  }

  void _drawQuakeImpact(Canvas canvas, double t) {
    final p = _fxProgress(FxType.quake, 2800);
    if (p == null) return;
    var amt = 0.0;
    for (final f in d.fx) {
      if (f.type == FxType.quake) amt = math.max(amt, f.amount);
    }
    final ms = p * 2800;

    // cincin getar tanah dari bawah rumah
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final cx = _bl + 2 * _cw;
    for (var r = 0; r < 3; r++) {
      final u = _c01((ms - r * 220) / 1100);
      if (u <= 0 || u >= 1) continue;
      _p.color = const Color(0xFF8D6E63).withValues(alpha: (1 - u) * 0.55);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx, _gy + 8), width: 60 + u * 300, height: 6 + u * 26),
          _p);
    }

    // sampah tumpah dari jendela/atap: jatuh, memantul sekali, lalu
    // terguling sedikit di halaman
    final pieces = (6 + (amt / 4).clamp(0, 14)).round();
    const cols = [
      Color(0xFF455A64),
      Color(0xFF6D4C41),
      Color(0xFFF5F5F5),
      Color(0xFF8BC34A),
      Color(0xFF29B6F6),
    ];
    _p.style = PaintingStyle.fill;
    final x0 = _bl, x1 = _bl + 4 * _cw;
    for (var i = 0; i < pieces; i++) {
      final h = _hh(i + 1800 + d.seed);
      final delay = (h % 600).toDouble();
      final lt = (ms - delay) / 1500.0;
      if (lt <= 0 || lt > 1) continue;
      final sx = x0 + (h % 1000) / 1000 * (x1 - x0);
      final startY = _roofY + 6 + (h % 7) * ((_gy - _roofY) / 8);
      final groundY = _gy + 10 + (h % 5) * 5.0;
      // jatuh bebas lalu pantul kecil
      double y;
      if (lt < 0.55) {
        final f = lt / 0.55;
        y = startY + (groundY - startY) * f * f;
      } else {
        final f = (lt - 0.55) / 0.45;
        y = groundY - math.sin(f * math.pi) * 6 * (1 - f);
      }
      final drift = ((h % 21) - 10) * 0.9 * _c01(lt / 0.7);
      final size = 3.0 + (h % 4);
      canvas.save();
      canvas.translate(sx + drift, y);
      canvas.rotate(lt * (6 + h % 5) * (h.isEven ? 1 : -1));
      _p.color = cols[h % cols.length].withValues(alpha: lt > 0.85 ? (1 - lt) / 0.15 : 1.0);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: size * 1.3, height: size),
              const Radius.circular(1.2)),
          _p);
      canvas.restore();
    }

    // gudang: debu mengepul, retak muncul sebentar, kotak bergetar
    final wh = d.warehouse;
    if (wh != null && wh.built) {
      final b = _whBox(wh.tier);
      final dustN = d.compact ? 5 : 12;
      for (var i = 0; i < dustN; i++) {
        final h = _hh(i + 1900);
        final u = _c01((ms - (h % 300)) / 1500);
        if (u <= 0 || u >= 1) continue;
        final x = b.l + (h % 1000) / 1000 * b.w;
        final y = _gy - 2 - u * 26;
        _p.color = const Color(0xFFBCAAA4).withValues(alpha: (1 - u) * 0.6);
        canvas.drawCircle(Offset(x, y), 2 + u * 7, _p);
      }
      if (ms < 1800) {
        final a = ms < 1400 ? 0.9 : (1800 - ms) / 400 * 0.9;
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF263238).withValues(alpha: a);
        final top = _gy - b.h;
        final path = Path()
          ..moveTo(b.l + b.w * 0.3, top + 2)
          ..lineTo(b.l + b.w * 0.34, top + b.h * 0.25)
          ..lineTo(b.l + b.w * 0.28, top + b.h * 0.45)
          ..lineTo(b.l + b.w * 0.36, top + b.h * 0.7);
        canvas.drawPath(path, _p);
        _p.style = PaintingStyle.fill;
      }
    }

    // angka "+N" melayang di atas atap
    if (amt >= 1 && ms > 150 && ms < 2600) {
      final u = _c01((ms - 150) / 2450);
      final a = u < 0.15 ? u / 0.15 : (u > 0.7 ? (1 - u) / 0.3 : 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: '+${amt.round()} SAMPAH',
          style: TextStyle(
            color: const Color(0xFFFF7043).withValues(alpha: a),
            fontSize: 7.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, _roofY - 14 - u * 22));
      tp.dispose();
    }
    _p.style = PaintingStyle.fill;
  }
}