part of 'kost_scene.dart';

// ====================================================================
//  SUASANA YANG PEKA TERHADAP SEKITAR (v1)
//
//  Satu sumber kebenaran untuk hal-hal yang "bereaksi pada lingkungan":
//   - kualitas udara  (_air)      : polusi + kabut gas + asap bakar, dibilas hujan
//   - waktu           (_u)        : jam-jaman 0.25 .. 1.25 (0.75 senja, 1.0 tengah malam)
//   - jadwal kamar    (_nightState): lampu per kamar, kegiatan, kapan tidur / bangun
//   - korden          (_curtainClose): menutup mengikuti asap, bau, silau, privasi, tidur
//   - lalu lintas     (_trafficDensity / _walkerDensity): ramai di jam sibuk,
//                       sepi di tengah malam, menyingkir saat udara beracun / hujan
//
//  Semuanya fungsi murni dari KostSceneData (tanpa state / timer), sehingga
//  semua pemain melihat hal yang sama.
// ====================================================================

/// Kegiatan penghuni di balik jendela.
/// [day] = bukan jadwal malam (aturan siang lama berlaku).
enum _Act { day, idle, cook, chat, study, tv, phone, bedlamp }

/// Keadaan satu kamar: kegiatan, tingkat terang lampu (0..1, halus), dan
/// seberapa dalam tidurnya (0..1, untuk korden).
typedef _NightState = ({_Act act, double k, double sleep});

/// Hash deterministik kecil (aman di web: perkalian < 2^53).
int _mx(int n) {
  var x = (n.abs() % 2147483629) + 1;
  x = (x * 48271) % 2147483647;
  x = (x * 48271) % 2147483647;
  x = (x * 48271) % 2147483647;
  return x;
}

extension KostPainterAmbient on KostPainter {
  // ================================================================= UDARA

  /// Kualitas udara efektif 0..1 (0 = bersih). Polusi, gas beracun, dan asap
  /// pembakaran menaikkannya; hujan membilasnya.
  double get _air {
    var a = _c01(d.pollution / 100);
    if (d.smog) a = math.max(a, 0.82);
    final burn = _fxProgress(FxType.burn, 4500);
    if (burn != null) {
      final env = burn < 0.12
          ? burn / 0.12
          : (burn > 0.8 ? (1 - burn) / 0.2 : 1.0);
      a = math.max(a, 0.30 + 0.55 * env);
    }
    if (d.worldEvent == 'rain_flood') a *= 0.65;
    return _c01(a);
  }

  // ================================================================= WAKTU

  /// Jam-jaman 0.25 .. 1.25 (0.25 fajar, 0.5 siang, 0.75 senja, 1.0 tengah
  /// malam, 1.25 fajar berikutnya).
  double get _u {
    final ph = d.dayPhase ?? 0.5;
    return ph < 0.25 ? ph + 1.0 : ph;
  }

  /// Acak deterministik 0..1 per kamar & per rumah.
  double _rf(int idx, int salt) =>
      (_mx(idx * 977 + d.seed * 31 + salt * 7919) % 10000) / 10000.0;

  /// Batas terang jendela akibat kondisi buruk (sampah menumpuk).
  double get _litBase {
    final r = d.trashRatio;
    return r >= 0.9 ? 0.3 : (r >= 0.75 ? 0.6 : (r >= 0.5 ? 0.85 : 1.0));
  }

  /// Jadwal satu kamar. Lampu dinyalakan menjelang senja, kegiatan berganti
  /// tiap ~12 detik, sebagian besar kamar padam sebelum tengah malam, beberapa
  /// "anak begadang" masih belajar sampai dini hari, lalu pagi bangun lagi.
  _NightState _nightState(int idx) {
    if (d.dayPhase == null) return (act: _Act.day, k: 1.0, sleep: 0.0);
    final u = _u;
    final on = 0.735 + _rf(idx, 1) * 0.085; //  17:40 - 19:40
    final owl = _rf(idx, 2) < 0.22;
    final bed = owl
        ? 1.04 + _rf(idx, 3) * 0.13 //          00:55 - 04:05
        : 0.90 + _rf(idx, 3) * 0.12; //         21:35 - 00:30
    final wake = 1.185 + _rf(idx, 4) * 0.065; // 04:25 - 06:00
    const ramp = 0.012; //                       ~3,6 detik
    // kamar yang memang menyala di siang hari tetap menyala saat malam tiba
    final stay = ((_hh(idx) % 100) / 100) < 0.40;

    if (u >= wake) {
      final up = _ease((u - wake) / ramp);
      var k = up;
      if (!stay) {
        k *= 1 - _ease((u - (1.215 + _rf(idx, 10) * 0.03)) / ramp);
      }
      return (act: _morningAct(idx), k: k, sleep: 1 - up);
    }
    if (u >= bed) {
      final s = _ease((u - bed) / ramp);
      return (act: _pickAct(idx, bed - 0.001, on, owl), k: 1 - s, sleep: s);
    }
    if (u >= on) {
      final k = stay ? 1.0 : _ease((u - on) / ramp);
      return (act: _pickAct(idx, u, on, owl), k: k, sleep: 0.0);
    }
    return (act: _Act.day, k: 1.0, sleep: 0.0);
  }

  _Act _pickAct(int idx, double u, double on, bool owl) {
    final slot = ((u - on) / 0.04).floor();
    final r = _mx(idx * 53 + d.seed * 17 + slot * 7919);
    const early = [_Act.cook, _Act.chat, _Act.phone, _Act.idle, _Act.tv];
    const mid = [
      _Act.study,
      _Act.tv,
      _Act.phone,
      _Act.chat,
      _Act.study,
      _Act.idle,
    ];
    const late = [_Act.study, _Act.tv, _Act.phone, _Act.bedlamp, _Act.study];
    const owlPool = [
      _Act.study,
      _Act.study,
      _Act.phone,
      _Act.study,
      _Act.tv,
    ];
    final pool = u < 0.82 ? early : (u < 0.93 ? mid : (owl ? owlPool : late));
    return pool[r % pool.length];
  }

  _Act _morningAct(int idx) {
    const pool = [
      _Act.cook,
      _Act.phone,
      _Act.bedlamp,
      _Act.study,
      _Act.idle,
    ];
    return pool[_mx(idx * 61 + d.seed * 11) % pool.length];
  }

  // =============================================================== KORDEN

  /// Penutupan korden 0..1 (0 = terbuka & diikat, 0.5 = setengah, 1 = rapat).
  /// Tiap kamar punya ambangnya sendiri: saat asap menebal, kamar menutup
  /// korden satu per satu (dulu setengah, lalu rapat).
  double _curtainClose(int idx, _Act act, double k, double sleep) {
    final th = 0.26 + _rf(idx, 5) * 0.30;
    var c = _ease((_air - th) / 0.16);
    // bau sampah: jendela ditutup sebagian
    final r = d.eliminated ? 0.0 : d.trashRatio;
    c = math.max(c, _ease((r - 0.45 - _rf(idx, 6) * 0.2) / 0.15) * 0.65);
    if (d.dayPhase != null) {
      // silau tengah hari
      if (_rf(idx, 7) < 0.4) {
        c = math.max(c, _ease((_sunElev - 0.65) / 0.1) * 0.34);
      }
      final pr = _rf(idx, 8);
      final priv = switch (act) {
        _Act.tv => 0.15 + 0.30 * pr,
        _Act.phone => 0.10 + 0.30 * pr,
        _Act.bedlamp => 0.30 + 0.40 * pr,
        _Act.study => 0.25 * pr,
        _Act.cook => 0.20 * pr,
        _Act.chat => 0.30 * pr,
        _Act.idle => 0.30 * pr,
        _ => 0.0,
      };
      c = math.max(c, priv * k);
      c = math.max(c, (0.88 + 0.1 * pr) * sleep);
    }
    return _c01(c);
  }

  /// Korden + debu di kaca. Digambar di atas isi kamar, di dalam jendela.
  void _drawCurtains(Canvas canvas, Rect win, int idx, double t, bool lit,
      _NightState st) {
    final close = _curtainClose(idx, st.act, lit ? st.k : 0.0, st.sleep);
    const cols = [
      Color(0xFFE57373),
      Color(0xFF64B5F6),
      Color(0xFF81C784),
      Color(0xFFFFB74D),
    ];
    var col = cols[_hh(idx + 9) % cols.length];
    final air = _air;

    if (d.compact) {
      if (close < 0.25) return;
      _p
        ..style = PaintingStyle.fill
        ..color = col.withValues(alpha: 0.8);
      final wd = win.width / 2 * close;
      canvas.drawRect(Rect.fromLTWH(win.left, win.top, wd, win.height), _p);
      canvas.drawRect(
          Rect.fromLTWH(win.right - wd, win.top, wd, win.height), _p);
      return;
    }

    canvas.save();
    canvas.clipRect(win);

    // kaca berdebu bila udara kotor
    final dust = _ease((air - 0.3) / 0.5);
    if (dust > 0.02) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFBFB8A6).withValues(alpha: 0.16 * dust);
      canvas.drawRect(win, _p);
    }

    // cahaya kamar tembus korden; kain berdebu di udara kotor
    if (lit) col = _mix(col, const Color(0xFFFFEFC0), 0.30 * st.k);
    col = _mix(col, const Color(0xFF9E9484), 0.35 * air);

    // goyang tertiup angin (hilang saat rapat / udara berat)
    final cs = math.sin(t * 1.6 + idx * 1.3) *
        1.2 *
        (1 - 0.75 * close) *
        (1 - 0.5 * air);
    final half = win.width / 2;
    final wd = _lerp(4.4, half + 0.4, close);
    final wMid = _lerp(wd * 0.62, wd, close);
    final wBot = _lerp(wd * 0.92, wd, close);

    for (final dir in const [1.0, -1.0]) {
      final x0 = dir > 0 ? win.left : win.right;
      double xs(double dd) => x0 + dir * dd;
      final panel = Path()
        ..moveTo(x0, win.top)
        ..lineTo(xs(wd + cs * 0.4), win.top)
        ..lineTo(xs(wMid + cs * 0.6), win.top + win.height * 0.62)
        ..lineTo(xs(wBot + cs), win.bottom)
        ..lineTo(x0, win.bottom)
        ..close();
      _p
        ..style = PaintingStyle.fill
        ..color = col.withValues(alpha: 0.88);
      canvas.drawPath(panel, _p);
      // lipatan kain
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = Colors.black.withValues(alpha: 0.16);
      for (final f in const [0.38, 0.72]) {
        canvas.drawLine(
          Offset(xs(wd * f), win.top + 1),
          Offset(xs(wBot * f + cs * f), win.bottom),
          _p,
        );
      }
      _p.style = PaintingStyle.fill;
    }

    // rel korden
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF4E342E);
    canvas.drawLine(Offset(win.left, win.top + 0.6),
        Offset(win.right, win.top + 0.6), _p);
    _p.style = PaintingStyle.fill;
    canvas.restore();
  }

  // ======================================================== CAHAYA JENDELA

  /// Warna cahaya yang tumpah dari jendela menurut kegiatan di dalamnya.
  Color _actGlow(_Act a, double t, int idx) {
    switch (a) {
      case _Act.tv:
        {
          final f = 0.5 + 0.5 * math.sin(t * 3.1 + idx * 1.7);
          return Color.lerp(
              const Color(0xFF6FB7FF), const Color(0xFFC77DFF), f)!;
        }
      case _Act.study:
        return const Color(0xFFFFF1C9);
      case _Act.phone:
        return const Color(0xFF8FA8E8);
      case _Act.bedlamp:
        return const Color(0xFFFF9E5E);
      case _Act.cook:
        return const Color(0xFFFFD27A);
      default:
        return const Color(0xFFFFC870);
    }
  }

  // ======================================================== POTRET KAMAR

  void _aFill(Canvas c, Rect r, Color col) {
    _p
      ..style = PaintingStyle.fill
      ..color = col;
    c.drawRect(r, _p);
  }

  void _aRRect(Canvas c, Rect r, double rad, Color col) {
    _p
      ..style = PaintingStyle.fill
      ..color = col;
    c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(rad)), _p);
  }

  void _aDot(Canvas c, Offset o, double r, Color col) {
    _p
      ..style = PaintingStyle.fill
      ..color = col;
    c.drawCircle(o, r, _p);
  }

  void _aLine(Canvas c, Offset a, Offset b, double w, Color col) {
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = col;
    c.drawLine(a, b, _p);
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }

  /// Isi jendela satu kamar pada malam hari: kegiatan penghuni bila lampu
  /// menyala, atau lampu standby kecil bila kamar gelap (tidur).
  void _drawRoomScene(
      Canvas canvas, Rect w, int idx, double t, bool lit, _NightState st) {
    canvas.save();
    canvas.clipRect(w);
    if (!lit) {
      if (_rf(idx, 9) < 0.55) {
        final pulse = 0.55 + 0.45 * math.sin(t * 1.3 + idx * 2.1);
        _aDot(
          canvas,
          Offset(w.right - 4.5, w.bottom - 5),
          0.8,
          (idx.isEven ? const Color(0xFF66BB6A) : const Color(0xFFFF5252))
              .withValues(alpha: 0.75 * pulse),
        );
      }
    } else {
      final fade = st.k < 0.98;
      if (fade) {
        canvas.saveLayer(
          w.inflate(1),
          Paint()..color = Color.fromRGBO(0, 0, 0, _c01(st.k)),
        );
      }
      final act = _resOutRooms.contains(idx) ? _Act.idle : st.act;
      _sceneBody(canvas, w, idx, t, act);
      if (fade) canvas.restore();
    }
    canvas.restore();
  }

  void _sceneBody(Canvas c, Rect w, int idx, double t, _Act act) {
    final shirt = _shirts[_hh(idx + 3) % _shirts.length];
    const hairs = [
      Color(0xFF2B2B2B),
      Color(0xFF4E342E),
      Color(0xFF1B1B1B),
      Color(0xFF5D4037),
    ];
    final hair = hairs[_hh(idx + 5) % hairs.length];
    switch (act) {
      case _Act.study:
        _sceneStudy(c, w, idx, t, shirt, hair);
      case _Act.tv:
        _sceneTv(c, w, idx, t, shirt, hair);
      case _Act.phone:
        _scenePhone(c, w, idx, t, shirt, hair);
      case _Act.chat:
        _sceneChat(c, w, idx, t, shirt, hair);
      case _Act.cook:
        _sceneCook(c, w, idx, t, shirt, hair);
      case _Act.bedlamp:
        _sceneBed(c, w, idx, t, shirt, hair);
      default:
        _sceneIdle(c, w, idx, t);
    }
  }

  static const Color _skinTone = Color(0xFFE0AC84);

  /// Belajar: lampu meja menyorot buku, kepala menunduk, tangan menulis.
  void _sceneStudy(
      Canvas c, Rect w, int idx, double t, Color shirt, Color hair) {
    final l = w.left, b = w.bottom, ww = w.width;
    _aFill(c, w, const Color(0xFFDCC48E));
    // rak buku di dinding
    _aFill(c, Rect.fromLTWH(l + 1.5, b - 20.5, 9.5, 1.1),
        const Color(0xFF8D6E63));
    const books = [
      Color(0xFFE57373),
      Color(0xFF64B5F6),
      Color(0xFFFFD54F),
      Color(0xFF81C784),
    ];
    for (var i = 0; i < 4; i++) {
      final h = 3.4 + (i % 2) * 0.9;
      _aFill(c, Rect.fromLTWH(l + 2.0 + i * 2.2, b - 20.5 - h, 1.8, h),
          books[i]);
    }
    // kerucut cahaya lampu belajar
    final lx = l + ww - 9.0;
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFF8D6).withValues(alpha: 0.55);
    c.drawPath(
      Path()
        ..moveTo(lx - 3.2, b - 14.2)
        ..lineTo(lx + 3.2, b - 14.2)
        ..lineTo(lx + 7.5, b - 5.4)
        ..lineTo(lx - 12.0, b - 5.4)
        ..close(),
      _p,
    );
    // pelajar
    final bob = math.sin(t * 2.4 + idx) * 0.35;
    final hx = l + 12.4;
    final hy = b - 16.4 + bob;
    _aRRect(c, Rect.fromLTWH(l + 6.6, b - 14.2, 6.4, 9), 2.4, shirt);
    final hand = Offset(l + 17.5 + math.sin(t * 6 + idx) * 0.9, b - 7.6);
    _aLine(c, Offset(l + 11.4, b - 12.2), hand, 1.7, shirt);
    _aDot(c, hand, 1.0, _skinTone);
    _aDot(c, Offset(hx, hy), 3.1, _skinTone);
    _p.color = hair;
    c.drawArc(Rect.fromCircle(center: Offset(hx, hy), radius: 3.25),
        math.pi * 0.95, math.pi * 1.1, true, _p);
    // buku & meja
    _aFill(c, Rect.fromLTWH(l + 14.2, b - 7.6, 8.8, 1.7),
        const Color(0xFFFAFAFA));
    _aFill(c, Rect.fromLTWH(l + 18.5, b - 7.6, 0.5, 1.7),
        const Color(0xFFB0BEC5));
    _aFill(c, Rect.fromLTWH(l, b - 5.6, ww, 5.6), const Color(0xFF6D4C41));
    _aFill(c, Rect.fromLTWH(l, b - 5.6, ww, 0.9), const Color(0xFF8D6E63));
    // lampu meja
    _aLine(c, Offset(l + ww - 3.6, b - 5.6), Offset(lx + 0.4, b - 14.2), 1.0,
        const Color(0xFF37474F));
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFF3C4);
    c.drawPath(
      Path()
        ..moveTo(lx - 3.4, b - 14.2)
        ..lineTo(lx + 3.4, b - 14.2)
        ..lineTo(lx, b - 18.2)
        ..close(),
      _p,
    );
    _aDot(c, Offset(lx, b - 14.0), 4.6,
        const Color(0xFFFFFFFF).withValues(alpha: 0.30));
  }

  /// Nonton: layar TV berkedip biru-ungu, penonton dari belakang di sofa.
  void _sceneTv(Canvas c, Rect w, int idx, double t, Color shirt, Color hair) {
    final l = w.left, b = w.bottom, ww = w.width;
    final f = 0.5 + 0.5 * math.sin(t * 3.1 + idx * 1.7);
    final scr = Color.lerp(const Color(0xFF6FB7FF), const Color(0xFFC77DFF), f)!;
    _aFill(c, w, const Color(0xFF232C4A));
    _aDot(c, Offset(l + ww - 8.5, b - 12.5), 15, scr.withValues(alpha: 0.16));
    _aDot(c, Offset(l + ww - 8.5, b - 12.5), 9, scr.withValues(alpha: 0.18));
    final tv = Rect.fromLTWH(l + ww - 14.5, b - 17.2, 12, 8.2);
    _aRRect(c, tv.inflate(0.9), 1.0, const Color(0xFF10131C));
    _aFill(c, tv, scr);
    // adegan di layar bergeser
    final bx = tv.left + 0.8 + ((t * 7 + idx * 3) % (tv.width - 3.2));
    _aFill(c, Rect.fromLTWH(bx, tv.top + 1.0, 1.6, tv.height - 2.0),
        Colors.white.withValues(alpha: 0.55));
    _aFill(c, Rect.fromLTWH(tv.left + 1.2, tv.bottom - 2.2, tv.width - 2.4, 0.9),
        Colors.white.withValues(alpha: 0.3));
    // sofa + penonton
    _aRRect(c, Rect.fromLTWH(l - 1, b - 8.2, ww * 0.64, 8.2), 2.2,
        const Color(0xFF5D4037));
    final hx = l + 7.0;
    _aRRect(c, Rect.fromLTWH(hx - 3.6, b - 11.2, 7.2, 5.0), 2.0, shirt);
    _aDot(c, Offset(hx, b - 13.6), 2.9, hair);
    _aDot(c, Offset(hx + 1.6, b - 13.8), 1.2, scr.withValues(alpha: 0.4));
    if (idx.isOdd) {
      final s2 = _shirts[_hh(idx + 7) % _shirts.length];
      final hx2 = l + 14.6;
      _aRRect(c, Rect.fromLTWH(hx2 - 3.2, b - 10.6, 6.4, 4.6), 2.0, s2);
      _aDot(c, Offset(hx2, b - 12.8), 2.6, const Color(0xFF4E342E));
      _aDot(c, Offset(hx2 + 1.4, b - 13.0), 1.1, scr.withValues(alpha: 0.4));
    }
  }

  /// Main ponsel di kasur: wajah disinari layar biru.
  void _scenePhone(
      Canvas c, Rect w, int idx, double t, Color shirt, Color hair) {
    final l = w.left, b = w.bottom, ww = w.width;
    const blankets = [
      Color(0xFF3F5B8C),
      Color(0xFF6B4C7A),
      Color(0xFF3E6B5A),
      Color(0xFF8C5A3F),
    ];
    final pulse = 0.85 + 0.15 * math.sin(t * 9 + idx);
    _aFill(c, w, const Color(0xFF1C2338));
    _aFill(c, Rect.fromLTWH(l, b - 6.6, ww, 6.6), blankets[idx % 4]);
    _aRRect(c, Rect.fromLTWH(l + 0.8, b - 10.2, 7.4, 3.6), 1.6,
        const Color(0xFFDADCE6));
    final dim = _mix(shirt, Colors.black, 0.45);
    final hx = l + 14.2;
    _aRRect(c, Rect.fromLTWH(l + 7.6, b - 14.8, 7.6, 9), 3, dim);
    _aLine(c, Offset(l + 12.4, b - 12.6), Offset(l + 17.2, b - 15.8), 1.6, dim);
    _aDot(c, Offset(hx, b - 17.6), 3.0,
        _mix(_skinTone, const Color(0xFF9FB8F0), 0.35));
    _p.color = _mix(hair, Colors.black, 0.2);
    c.drawArc(Rect.fromCircle(center: Offset(hx, b - 17.6), radius: 3.15),
        math.pi * 0.95, math.pi * 1.1, true, _p);
    // ponsel + cahayanya
    final ph = Offset(l + 18.4, b - 16.4);
    _aDot(c, ph, 10, const Color(0xFF82B1FF).withValues(alpha: 0.20 * pulse));
    _aDot(c, ph, 5.5, const Color(0xFFB3C7FF).withValues(alpha: 0.28 * pulse));
    _aRRect(c, Rect.fromCenter(center: ph, width: 2.2, height: 3.6), 0.6,
        const Color(0xFFEAF2FF));
  }

  /// Ngobrol berdua: yang bicara mengangguk, gelembung titik-titik muncul.
  void _sceneChat(
      Canvas c, Rect w, int idx, double t, Color shirt, Color hair) {
    final l = w.left, b = w.bottom, ww = w.width;
    final s2 = _shirts[_hh(idx + 7) % _shirts.length];
    _aFill(c, w, const Color(0xFFEBCB8B));
    _aFill(c, Rect.fromLTWH(l, b - 5.0, ww, 5.0), const Color(0xFFB08F62));
    final talker = ((t * 0.45 + idx) % 2.0) < 1.0 ? 0 : 1;
    final bob0 = talker == 0 ? math.sin(t * 9 + idx) * 0.5 : 0.0;
    final bob1 = talker == 1 ? math.sin(t * 9 + idx) * 0.5 : 0.0;
    final x0 = l + 8.4;
    final x1 = l + ww - 8.4;
    _aRRect(c, Rect.fromLTWH(x0 - 3.2, b - 13.4, 6.4, 8.8), 2.4, shirt);
    _aRRect(c, Rect.fromLTWH(x1 - 3.2, b - 13.4, 6.4, 8.8), 2.4, s2);
    _aDot(c, Offset(x0, b - 16.4 + bob0), 3.0, _skinTone);
    _aDot(c, Offset(x1, b - 16.4 + bob1), 3.0, const Color(0xFFC68B5E));
    _p.color = hair;
    c.drawArc(Rect.fromCircle(center: Offset(x0, b - 16.4 + bob0), radius: 3.15),
        math.pi, math.pi, true, _p);
    _p.color = const Color(0xFF2B2B2B);
    c.drawArc(Rect.fromCircle(center: Offset(x1, b - 16.4 + bob1), radius: 3.15),
        math.pi, math.pi, true, _p);
    // gelembung bicara
    final bx = talker == 0 ? x0 + 2.0 : x1 - 2.0;
    _aRRect(c, Rect.fromLTWH(bx - 4.2, b - 25.0, 8.4, 4.6), 2.2,
        Colors.white.withValues(alpha: 0.95));
    for (var i = 0; i < 3; i++) {
      final on = ((t * 3 + i) % 3) < 2;
      _aDot(c, Offset(bx - 2.2 + i * 2.2, b - 22.7), 0.7,
          const Color(0xFF546E7A).withValues(alpha: on ? 0.9 : 0.3));
    }
  }

  /// Masak / sarapan: uap naik dari panci, api kompor berkedip.
  void _sceneCook(
      Canvas c, Rect w, int idx, double t, Color shirt, Color hair) {
    final l = w.left, b = w.bottom, ww = w.width;
    _aFill(c, w, const Color(0xFFFFE9A6));
    _aFill(c, Rect.fromLTWH(l, b - 17.5, ww, 0.8),
        Colors.black.withValues(alpha: 0.08));
    // koki
    final hx = l + 9.6;
    _aRRect(c, Rect.fromLTWH(l + 6.0, b - 15.0, 6.4, 9), 2.4, shirt);
    _aDot(c, Offset(hx, b - 18.4), 3.1, _skinTone);
    _p.color = hair;
    c.drawArc(Rect.fromCircle(center: Offset(hx, b - 18.4), radius: 3.25),
        math.pi * 0.95, math.pi * 1.1, true, _p);
    final tip = Offset(l + 17.4 + math.sin(t * 4 + idx) * 1.2, b - 10.8);
    _aLine(c, Offset(l + 11.0, b - 12.6), tip, 1.7, shirt);
    _aDot(c, tip, 1.0, _skinTone);
    // meja dapur + panci
    _aFill(c, Rect.fromLTWH(l, b - 6.4, ww, 6.4), const Color(0xFF90A4AE));
    _aFill(c, Rect.fromLTWH(l, b - 6.4, ww, 0.9), const Color(0xFFCFD8DC));
    final px = l + 19.6;
    final flick = 0.7 + 0.3 * math.sin(t * 17 + idx);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFF9100).withValues(alpha: 0.9 * flick);
    c.drawPath(
      Path()
        ..moveTo(px - 3, b - 6.4)
        ..lineTo(px - 1.5, b - 8.2 * flick)
        ..lineTo(px, b - 6.4)
        ..lineTo(px + 1.5, b - 8.2 * flick)
        ..lineTo(px + 3, b - 6.4)
        ..close(),
      _p,
    );
    _aRRect(c, Rect.fromLTWH(px - 4.2, b - 11.6, 8.4, 4.8), 1.0,
        const Color(0xFF607D8B));
    _aFill(c, Rect.fromLTWH(px - 4.8, b - 12.4, 9.6, 1.0),
        const Color(0xFF455A64));
    // uap
    for (var k = 0; k < 3; k++) {
      final u = (t * 0.55 + k / 3 + idx * 0.13) % 1.0;
      _aDot(
        c,
        Offset(px - 2.4 + k * 2.4 + math.sin(u * 7 + k) * 1.1,
            b - 13.0 - u * 9.0),
        1.2 + u * 1.5,
        Colors.white.withValues(alpha: 0.7 * (1 - u)),
      );
    }
  }

  /// Lampu tidur: membaca di kasur, atau sudah terlelap (💤).
  void _sceneBed(Canvas c, Rect w, int idx, double t, Color shirt, Color hair) {
    final l = w.left, b = w.bottom, ww = w.width;
    final asleep = _u >= 1.0 && _rf(idx, 11) < 0.6;
    const blankets = [
      Color(0xFF3F5B8C),
      Color(0xFF6B4C7A),
      Color(0xFF3E6B5A),
      Color(0xFF8C5A3F),
    ];
    final bl = blankets[(idx + 1) % 4];
    _aFill(c, w, const Color(0xFF4A3426));
    final lamp = Offset(l + ww - 4.6, b - 13.0);
    _aDot(c, lamp, 13, const Color(0xFFFF9E5E).withValues(alpha: 0.22));
    _aDot(c, lamp, 7, const Color(0xFFFFC27A).withValues(alpha: 0.30));
    // kasur + bantal + orang berbaring
    _aFill(c, Rect.fromLTWH(l, b - 7.4, ww, 7.4), _mix(bl, Colors.black, 0.2));
    _aRRect(c, Rect.fromLTWH(l + 0.8, b - 10.8, 8.2, 3.6), 1.6,
        const Color(0xFFE6DCCB));
    _aDot(c, Offset(l + 5.6, b - 11.6), 2.7, _skinTone);
    _p.color = hair;
    c.drawArc(Rect.fromCircle(center: Offset(l + 5.4, b - 11.7), radius: 2.9),
        math.pi * 0.85, math.pi * 1.2, true, _p);
    _aRRect(c, Rect.fromLTWH(l + 8.0, b - 11.4, ww - 15.0, 4.8), 2.2, bl);
    if (asleep) {
      final u = (t * 0.35 + idx * 0.21) % 1.0;
      final tp = _icon('💤');
      c.save();
      c.translate(l + 9.5 + math.sin(u * 6) * 1.2, b - 19.0 - u * 3.0);
      c.scale(0.62);
      tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
      c.restore();
    } else {
      // buku di tangan
      final bk = Offset(l + 11.2, b - 13.4 + math.sin(t * 0.9 + idx) * 0.3);
      _aRRect(c, Rect.fromCenter(center: bk, width: 5.2, height: 3.4), 0.5,
          const Color(0xFFFFF8E1));
      _aFill(c, Rect.fromCenter(center: bk, width: 0.4, height: 3.4),
          const Color(0xFFB0A080));
    }
    // meja kecil + lampu
    _aFill(c, Rect.fromLTWH(l + ww - 7.4, b - 7.0, 6.4, 7.0),
        const Color(0xFF5D4037));
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFD9A0);
    c.drawPath(
      Path()
        ..moveTo(lamp.dx - 2.8, b - 7.0)
        ..lineTo(lamp.dx + 2.8, b - 7.0)
        ..lineTo(lamp.dx + 1.6, b - 12.0)
        ..lineTo(lamp.dx - 1.6, b - 12.0)
        ..close(),
      _p,
    );
  }

  /// Lampu menyala tanpa orang (sedang keluar / di kamar mandi).
  void _sceneIdle(Canvas c, Rect w, int idx, double t) {
    final l = w.left, b = w.bottom, ww = w.width;
    _aFill(c, w, const Color(0xFFFFDD7A));
    const posters = [
      Color(0xFF42A5F5),
      Color(0xFFEF5350),
      Color(0xFF66BB6A),
      Color(0xFFAB47BC),
    ];
    _aFill(c, Rect.fromLTWH(l + 3, b - 21, 7, 9), posters[idx % 4]);
    _aFill(c, Rect.fromLTWH(l + 4.2, b - 19.6, 4.6, 0.9),
        Colors.white.withValues(alpha: 0.7));
    final sway = math.sin(t * 1.4 + idx) * 0.6;
    _aLine(c, Offset(l + ww * 0.62, w.top), Offset(l + ww * 0.62 + sway, w.top + 5),
        0.6, const Color(0xFF6D4C41));
    _aDot(c, Offset(l + ww * 0.62 + sway, w.top + 6), 1.8,
        const Color(0xFFFFFDE7));
    // jemuran baju
    _aFill(c, Rect.fromLTWH(l + ww - 11, b - 18, 8, 7),
        _shirts[_hh(idx + 3) % _shirts.length].withValues(alpha: 0.9));
    _aFill(c, Rect.fromLTWH(l, b - 4.0, ww, 4.0), const Color(0xFFB08F62));
  }

  // ========================================================= LALU LINTAS

  /// Kepadatan kendaraan 0..1: ramai di jam sibuk pagi/sore, makin sepi
  /// menjelang tengah malam, menipis saat udara beracun atau hujan.
  double get _trafficDensity {
    if (d.dayPhase == null) return 1.0;
    final ph = d.dayPhase!;
    double bump(double c, double wd) => 1 - _ease((ph - c).abs() / wd);
    final rush = math.max(bump(0.31, 0.06), bump(0.73, 0.06));
    final day = 0.72 + 0.28 * rush;
    final mid = math.min(ph, 1 - ph); // jarak ke tengah malam
    final deep = 1 - _ease((mid - 0.02) / 0.14);
    var k = _lerp(day, _lerp(0.40, 0.06, deep), _night);
    k *= 1 - 0.35 * _ease((_air - 0.5) / 0.4);
    if (d.worldEvent == 'rain_flood') k *= 0.6;
    return k.clamp(0.04, 1.0).toDouble();
  }

  /// Kepadatan pejalan kaki: lebih cepat sepi daripada kendaraan.
  double get _walkerDensity {
    if (d.dayPhase == null) return 1.0;
    final k = _trafficDensity * 1.15 * (1 - 0.45 * _night);
    return k.clamp(0.03, 1.0).toDouble();
  }

  // ====================================================== PEJALAN KAKI

  /// Warga yang lewat di trotoar depan kost. Peka lingkungan: jumlahnya
  /// mengikuti [_walkerDensity] (sepi tengah malam / hujan / udara beracun),
  /// bermasker bila udara kotor, memakai payung saat hujan.
  void _drawStreetWalkers(Canvas canvas, double t, double worldL, double worldR) {
    if (d.compact) return;
    final dens = _walkerDensity;
    final air = _air;
    final rain = d.worldEvent == 'rain_flood';
    final len = math.max(300.0, worldR - worldL);
    final n = math.max(1, (len / 85).round());
    final gap = len / n;
    for (var i = 0; i < n; i++) {
      final h = _mx(i * 131 + 17);
      final rank = (h % 1000) / 1000.0;
      final vis = dens >= 0.995 ? 1.0 : _c01((dens - rank) / 0.08);
      if (vis <= 0.02) continue;
      final dir = (h >> 3) % 2 == 0 ? 1.0 : -1.0;
      final speed = 7.0 + (h >> 5) % 7; // px/dtk
      final pos = ((t * speed * dir + i * gap + (h % 40)) % len + len) % len;
      final x = worldL + pos;
      if (x < _vl - 20 || x > _vr + 20) continue;
      final y = 263.5 + (h >> 9) % 5 * 1.1;
      final swing = math.sin(t * speed * 0.55 + h) * 2.6;
      final masked = air > 0.28 + ((h >> 11) % 40) / 100.0 * 0.4;
      _person(
        canvas,
        Offset(x, y),
        shirt: _shirts[(h >> 13) % _shirts.length],
        mask: masked,
        swing: swing,
        alpha: vis,
      );
      if (rain) {
        // payung kecil di atas kepala
        _p
          ..style = PaintingStyle.fill
          ..color = _shirts[(h >> 15) % _shirts.length]
              .withValues(alpha: 0.9 * vis);
        canvas.drawArc(
          Rect.fromCenter(center: Offset(x, y - 20), width: 15, height: 10),
          math.pi,
          math.pi,
          true,
          _p,
        );
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = const Color(0xFF37474F).withValues(alpha: vis);
        canvas.drawLine(Offset(x, y - 20), Offset(x, y - 10), _p);
        _p.style = PaintingStyle.fill;
      }
    }
  }
}