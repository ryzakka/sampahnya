part of 'kost_scene.dart';

/// Pengait suara pintu (diisi GameScreen; null = diam, mis. di layar pembuka).
/// Dipanggil tiap frame gambar dengan seed rumah & apakah pintunya sedang
/// terbuka; pemanggil yang mendeteksi tepi "baru terbuka".
void Function(int seed, bool open)? kostDoorHook;

/// Penghuni, pertahanan, sampah & hama.
extension KostPainterResidents on KostPainter {
  // ------------------------------------------------------- penghuni kost
  //
  // Penghuni keluar-masuk lewat pintu depan sesuai kondisi kost:
  //   sampah >=50% menutup hidung, >=75% marah-marah, >=90% demo ramai (papan),
  //   polusi >=60% bermasker & batuk, >=85% masker gas, tertimbun duduk lesu.
  // Jadwal murni fungsi waktu + seed rumah (tanpa state/timer), jadi tiap rumah
  // punya ritme sendiri dan semua pemain melihat hal yang sama. Ekspresi hanya
  // lewat ikon agar tetap terbaca saat kamera menjauh.



  TextPainter _icon(String e) => _iconCache.putIfAbsent(
    e,
        () => TextPainter(
      text: TextSpan(text: e, style: const TextStyle(fontSize: 10.5)),
      textDirection: TextDirection.ltr,
    )..layout(),
  );

  /// Kamar asal penghuni ke-k (siluet jendelanya hilang saat dia di luar).
  int _resRoom(int k) {
    const base = [0, 2, 3, 5];
    return d.rooms > 0 ? base[k % base.length] % d.rooms : 0;
  }

  /// Jadwal keluar-masuk penghuni ke-k pada waktu t; null = sedang di dalam.
  _Res? _resSchedule(int k, double t, double frac) {
    final h = _hh(d.seed * 31 + k * 17 + 5);
    final len = 15.0 + (h % 7);
    final ph = (t + (h % 997) / 997 * len) % len;
    final dur = math.max(len * frac, 3.4);
    if (ph >= dur) return null;
    const w = 1.3;
    final outbound = ph < dur / 2;
    var m = 1.0;
    var walking = false;
    if (ph < w) {
      m = _ease(ph / w);
      walking = true;
    } else if (ph > dur - w) {
      m = _ease((dur - ph) / w);
      walking = true;
    }
    final sx = _spotX[k % _spotX.length];
    final sy = _spotY[k % _spotY.length];
    final toward = sx >= _doorX ? 1.0 : -1.0;
    return (
    k: k,
    x: _lerp(_doorX, sx, m),
    y: _lerp(238, sy, m),
    m: m,
    walking: walking,
    dir: walking && !outbound ? -toward : toward,
    );
  }

  void _planResidents(double t) {
    _resOut = <_Res>[];
    _resOutRooms.clear();
    _resMode = 0;
    _resSign = false;
    if (d.compact) return;

    final r = d.eliminated ? 1.0 : d.trashRatio;
    final p = _c01(d.pollution / 100);
    _resMask = p >= 0.85 ? 2 : (p >= 0.6 ? 1 : 0);

    var n = 0;
    var frac = 0.0;
    if (d.eliminated) {
      _resMode = 4;
      return;
    } else if (r >= 0.75) {
      _resMode = 1;
      n = r >= 0.9 ? 4 : 2;
      frac = r >= 0.9 ? 0.78 : 0.45;
      _resSign = r >= 0.9;
    } else if (r >= 0.5) {
      _resMode = 2;
      n = d.rooms >= 6 ? 2 : 1;
      frac = 0.3;
    } else if (p >= 0.6) {
      _resMode = 3;
      n = 1;
      frac = p >= 0.85 ? 0.14 : 0.24;
    } else {
      return;
    }
    if (p >= 0.85 && _resMode != 3) frac *= 0.7; // udara beracun: cepat masuk
    n = math.min(n, math.max(1, (d.rooms / 2).ceil()));
    for (var k = 0; k < n; k++) {
      final s = _resSchedule(k, t, frac);
      if (s == null) continue;
      _resOut.add(s);
      _resOutRooms.add(_resRoom(k));
    }
  }

  void _drawResidents(Canvas canvas, double t) {
    if (d.compact) return;

    if (_resMode == 4) {
      _drawDoor(canvas, 0);
      const xs = [128.0, 160.0, 262.0];
      for (var k = 0; k < 3; k++) {
        final dir = k == 2 ? -1.0 : 1.0;
        _sitter(canvas, xs[k], 271, k, t, _shirts[(k + 1) % _shirts.length], dir);
        _resIcon(canvas, xs[k], 271 - 25, '😭', t, k);
      }
      return;
    }

    var open = 0.0;
    for (final s in _resOut) {
      open = math.max(open, _c01(1 - s.m / 0.4));
    }
    _drawDoor(canvas, open);
    kostDoorHook?.call(d.seed, open > 0.02);

    final hit = _fxProgress(FxType.incoming, 1600) != null;
    for (final s in _resOut) {
      final k = s.k;
      final pose = s.walking ? 0 : _resMode == 1 ? 1 : (_resMode == 2 ? 2 : 3);
      final dir = (!s.walking && _resMode == 1 && hit)
          ? (d.facingRight ? 1.0 : -1.0)
          : s.dir;
      final sign = _resSign && k.isOdd;
      _resident(
        canvas,
        s.x,
        s.y,
        shirt: _shirts[_hh(_resRoom(k) + 3) % _shirts.length],
        pose: pose,
        dir: dir,
        t: t,
        k: k,
        walking: s.walking,
        mask: _resMask,
        alpha: _c01(s.m * 5),
        sign: sign,
      );
      if (!s.walking) {
        final String e;
        if (_resMode == 1) {
          e = ((t * 0.8 + k * 0.7) % 2 < 1) ? '💢' : '😡';
        } else if (_resMode == 2) {
          e = '🤢';
        } else {
          e = math.sin(t * 2.2 + k) > 0.5 ? '🤧' : '😷';
        }
        _resIcon(canvas, s.x, s.y - (sign ? 36 : 27), e, t, k);
      }
    }
  }

  /// Pemilik kost: karakter kustom pemain di halaman depan.
  void _drawOwner(Canvas canvas, double t) {
    final o = d.owner;
    if (o == null || d.compact) return;
    o.update(d, t);
    if (!o.visible) return;
    const y = 268.0;
    final ring = Rect.fromCenter(
        center: const Offset(0, 1.5), width: 20, height: 5);
    canvas.save();
    canvas.translate(o.x, y);
    // lingkaran emas di kaki: penanda "pemilik" yang tetap terbaca
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFCA28).withValues(alpha: 0.2);
    canvas.drawOval(ring, _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFFFCA28).withValues(alpha: 0.7);
    canvas.drawOval(ring, _p);
    _p.style = PaintingStyle.fill;
    // arah hadap halus + napas lembut (lebih terasa saat diam)
    final ds = o.dirS.abs() < 0.08 ? (o.dirS < 0 ? -0.08 : 0.08) : o.dirS;
    final breath = o.walking ? 0.0 : math.sin(t * 2.2 + o.seed * 0.3) * 0.012;
    canvas.scale(ds * 1.12, 1.12 * (1 + breath));
    paintKostCharacter(canvas, _p, o.look,
        t: t,
        pose: o.pose,
        phase: o.seed * 0.07,
        walking: o.walking,
        mask: o.mask);
    canvas.restore();
    if (o.icon != null) {
      _resIcon(canvas, o.x, y - 33, o.icon!, t, o.seed);
    }
  }

  void _drawDoor(Canvas canvas, double open) {
    if (d.compact) return;
    const door = Rect.fromLTWH(195, 214, 12, 22);
    final dc = d.style?.doorColor ?? const Color(0xFF6D4C41);

    // kusen
    _p
      ..style = PaintingStyle.fill
      ..color = _mix(dc, Colors.black, 0.5);
    canvas.drawRect(
        Rect.fromLTRB(door.left - 1.6, door.top - 1.6, door.right + 1.6,
            door.bottom),
        _p);
    // ruang di balik pintu (menyala hangat saat terbuka)
    _p.color =
        _mix(const Color(0xFF2B1F18), const Color(0xFFFFC860), open * 0.6);
    canvas.drawRect(door, _p);
    // daun pintu
    final leafW = door.width * (1 - 0.75 * open);
    _p.color = dc;
    canvas.drawRect(
        Rect.fromLTWH(door.left, door.top, leafW, door.height), _p);
    if (open < 0.5) {
      // panel bawah + kaca kecil
      _p.color = _mix(dc, Colors.black, 0.2);
      canvas.drawRect(
          Rect.fromLTWH(door.left + 1.8, door.top + 11.5, leafW - 3.6, 8), _p);
      _p.color = const Color(0xFFB3E5FC).withValues(alpha: 0.75);
      canvas.drawRect(
          Rect.fromLTWH(door.left + 2.2, door.top + 2.4, leafW - 4.4, 6), _p);
    }
    if (open < 0.3) {
      _p.color = const Color(0xFFFFCA28);
      canvas.drawCircle(Offset(door.right - 2.5, door.top + 12), 0.9, _p);
    }
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF3E2723);
    canvas.drawRect(door, _p);
    _p.style = PaintingStyle.fill;

    // kanopi kecil di atas pintu (warna ikut papan nama)
    _p.color = d.style?.signColor ?? const Color(0xFF477A62);
    canvas.drawPath(
      Path()
        ..moveTo(door.left - 3, door.top - 1.6)
        ..lineTo(door.right + 3, door.top - 1.6)
        ..lineTo(door.right + 1.6, door.top - 6)
        ..lineTo(door.left - 1.6, door.top - 6)
        ..close(),
      _p,
    );
    _p.color = Colors.white.withValues(alpha: 0.25);
    canvas.drawRect(
        Rect.fromLTRB(door.left - 3, door.top - 2.6, door.right + 3, door.top - 1.6),
        _p);
    // keset kaki
    _p.color = const Color(0xFF5D4037).withValues(alpha: 0.85);
    canvas.drawRect(
        Rect.fromLTWH(door.left - 1, door.bottom - 1.2, door.width + 2, 2), _p);
  }

  /// Gelembung ikon kecil di atas kepala penghuni.
  void _resIcon(
      Canvas canvas, double x, double y, String e, double t, int k) {
    final tp = _icon(e);
    // muncul dengan membal (easeOutBack) tiap kali ikon baru/berganti
    final key = k * 1000003 + e.hashCode;
    final born = _iconBorn[key];
    if (born == null || t - born.last > 0.4) {
      _iconBorn[key] = _IconLife(t, t);
    } else {
      born.last = t;
    }
    final age = t - _iconBorn[key]!.first;
    final intro = age >= 0.35 ? 1.0 : _easeOutBack(_c01(age / 0.35));
    final pop = (0.9 + 0.08 * math.sin(t * 5 + k * 2)) * intro;
    canvas.save();
    canvas.translate(x, y + math.sin(t * 3 + k) * 0.8);
    canvas.scale(pop.clamp(0.0, 1.4).toDouble());
    _p
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.92);
    canvas.drawCircle(Offset.zero, 7.2, _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = const Color(0xFF546E7A);
    canvas.drawCircle(Offset.zero, 7.2, _p);
    _p.style = PaintingStyle.fill;
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _resident(
      Canvas canvas,
      double x,
      double y, {
        required Color shirt,
        required int pose, // 0 jalan, 1 marah, 2 tutup hidung, 3 batuk
        required double dir,
        required double t,
        required int k,
        required bool walking,
        required int mask,
        double alpha = 1,
        bool sign = false,
      }) {
    final a = _c01(alpha);
    if (a <= 0.02) return;
    if (a < 1) {
      canvas.saveLayer(
        Rect.fromCenter(center: Offset(x, y - 14), width: 60, height: 60),
        Paint()..color = Color.fromRGBO(0, 0, 0, a),
      );
    }
    final ph = t * (walking ? 10 : 7) + k * 1.7;
    final cw = math.sin(t * 2.2 + k);
    final cough = !walking && pose == 3 && cw > 0.5;
    final hop = (!walking && pose == 1)
        ? -math.sin(ph).abs() * 2.6
        : (walking ? -math.sin(ph).abs() * 1.1 : 0.0);
    var lean = 0.0;
    // batuk: membungkuk masuk/keluar dengan halus, bukan lompat
    if (!walking && pose == 3) lean = 0.32 * _ease(_c01((cw - 0.35) / 0.3));
    if (walking && mask == 2) lean = 0.16;
    final sw = walking ? math.sin(ph) * 3.0 : 0.0;
    const skin = Color(0xFFE0AC84);

    // bayangan lembut di tanah; mengecil saat melompat
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF000000).withValues(alpha: 0.14);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(x, y + 0.8),
            width: 11 + hop * 0.8,
            height: 2.8),
        _p);

    canvas.save();
    canvas.translate(x, y + hop);
    canvas.scale(dir, 1);
    canvas.rotate(lean);

    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF37474F);
    canvas.drawLine(const Offset(0, -6), Offset(-sw, 0), _p);
    canvas.drawLine(const Offset(0, -6), Offset(sw, 0), _p);

    _p.color = shirt;
    Offset? fist;
    if (walking) {
      canvas.drawLine(const Offset(0, -12), Offset(sw * 0.9, -7.5), _p);
      canvas.drawLine(const Offset(0, -12), Offset(-sw * 0.9, -7.5), _p);
    } else if (pose == 1) {
      final e = Offset(5, -19 + math.sin(ph * 1.3) * 2.2);
      canvas.drawLine(const Offset(0, -12), e, _p);
      canvas.drawLine(const Offset(0, -12), const Offset(-4, -8), _p);
      fist = e;
    } else if (pose == 2) {
      canvas.drawLine(
          const Offset(0, -12), Offset(-4.5, -9 + math.sin(ph * 1.2) * 1.5), _p);
    } else {
      canvas.drawLine(const Offset(0, -12), const Offset(-3.5, -7), _p);
    }

    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt
      ..color = shirt;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3.2, -14, 6.4, 9), const Radius.circular(2)),
      _p,
    );
    _p.color = skin;
    canvas.drawCircle(const Offset(0, -17.5), 3.2, _p);
    if (mask == 1) {
      _p.color = const Color(0xFFE3F2FD);
      canvas.drawRect(const Rect.fromLTWH(-0.4, -17.4, 3.7, 2.3), _p);
    } else if (mask == 2) {
      _p.color = const Color(0xFF33691E);
      canvas.drawRect(const Rect.fromLTWH(-0.6, -17.8, 4.0, 3.0), _p);
      _p.color = const Color(0xFF455A64);
      canvas.drawCircle(const Offset(3.6, -16.3), 1.5, _p);
    }

    if (!walking && pose == 1) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = const Color(0xFFB71C1C);
      canvas.drawLine(const Offset(0.4, -19.8), const Offset(2.8, -18.9), _p);
      _p.style = PaintingStyle.fill;
    }

    if (!walking && (pose == 2 || pose == 3)) {
      // tangan menutup hidung / mulut
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = shirt;
      canvas.drawLine(const Offset(0, -12), const Offset(2.6, -16.2), _p);
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt
        ..color = skin;
      canvas.drawCircle(const Offset(3.1, -16.4), 1.3, _p);
    }

    if (fist != null) {
      _p.color = skin;
      canvas.drawCircle(fist, 1.4, _p);
      if (sign) {
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF8D6E63);
        canvas.drawLine(fist, fist + const Offset(0.6, -8), _p);
        final board = Rect.fromLTWH(fist.dx - 3.2, fist.dy - 15, 8, 7);
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFFF8E1);
        canvas.drawRect(board, _p);
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0xFFD32F2F);
        canvas.drawRect(board, _p);
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFD32F2F);
        canvas.drawRect(Rect.fromLTWH(fist.dx + 0.2, fist.dy - 14, 1.2, 3.4), _p);
        canvas.drawCircle(Offset(fist.dx + 0.8, fist.dy - 9.3), 0.7, _p);
      }
    }

    if (cough) {
      for (var i = 0; i < 3; i++) {
        _p.color = const Color(0xFFBDBDBD).withValues(alpha: 0.75 - i * 0.2);
        canvas.drawCircle(
            Offset(6.5 + i * 3.4, -16.5 - i * 1.3), 1.1 + i * 0.4, _p);
      }
    }
    canvas.restore();
    if (a < 1) canvas.restore();
  }

  /// Penghuni duduk lesu di samping kopernya (kost tertimbun).
  void _sitter(Canvas canvas, double x, double y, int k, double t, Color shirt,
      double dir) {
    canvas.save();
    canvas.translate(x, y + math.sin(t * 14 + k) * 0.4); // terisak
    canvas.scale(dir, 1);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF8D6E63);
    canvas.drawRect(const Rect.fromLTWH(-15, -9, 9, 8), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF4E342E);
    canvas.drawLine(const Offset(-12.5, -9), const Offset(-12.5, -11), _p);
    canvas.drawLine(const Offset(-10.5, -9), const Offset(-10.5, -11), _p);
    canvas.drawLine(const Offset(-12.5, -11), const Offset(-10.5, -11), _p);

    _p
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF37474F);
    canvas.drawLine(const Offset(0, -3), const Offset(7, -4.5), _p);
    canvas.drawLine(const Offset(7, -4.5), const Offset(7.5, 0), _p);
    _p.color = shirt;
    canvas.drawLine(const Offset(0, -8), const Offset(5, -6), _p);
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, -11, 6, 8.5), const Radius.circular(2)),
      _p,
    );
    _p.color = const Color(0xFFE0AC84);
    canvas.drawCircle(const Offset(1.2, -14.2), 3.2, _p);
    canvas.restore();
  }

  // ------------------------------------------------------- pertahanan

  void _drawDefense(Canvas canvas, double t) {
    final defP = _fxProgress(FxType.defense, 2400);

    if (d.defense >= 1) {
      final grow = defP == null ? 1.0 : _easeOutBack(defP / 0.45);
      canvas.save();
      canvas.translate(0, 254);
      canvas.scale(1, grow);
      canvas.translate(0, -254);
      if (d.defense == 1) {
        _picketFence(canvas);
      } else {
        _brickWall(canvas);
      }
      canvas.restore();
    }

    if (d.defense >= 2) {
      _guardPost(canvas, t);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF37474F);
      canvas.drawRect(const Rect.fromLTWH(296, 222, 8, 5), _p);
      _p.color = const Color(0xFF263238);
      canvas.drawRect(const Rect.fromLTWH(300, 227, 2, 5), _p);
      if (math.sin(t * 5) > 0) {
        _p.color = const Color(0xFFFF1744);
        canvas.drawCircle(const Offset(298, 224.5), 1.4, _p);
      }
    }

    if (d.defense >= 3) _pylons(canvas, t);

    final prot = d.protectedLeft > 0;
    // Kubah HANYA tampil saat proteksi singkat aktif (tidak lagi permanen di Lv 3)
    if (prot) _dome(canvas, t, true);

    if (defP != null) {
      for (var ring = 0; ring < 2; ring++) {
        final local = _c01((defP - ring * 0.15) / 0.85);
        if (local <= 0) continue;
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - local)
          ..color =
          const Color(0xFF00E5FF).withValues(alpha: (1 - local) * 0.85);
        canvas.drawCircle(
            Offset(200, _gy - 60), _lerp(25, 220, _ease(local)), _p);
      }
      _p.style = PaintingStyle.fill;

      _drawBannerText(
        canvas,
        'PERTAHANAN NAIK!',
        Offset(200, _roofY - 36 - defP * 28),
        const Color(0xFF80D8FF),
        scale: 1.0 + math.sin(defP * math.pi) * 0.25,
        alpha: 1 - defP,
      );
    }
  }

  void _picketFence(Canvas canvas) {
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFF2EAD3);
    canvas.drawRect(const Rect.fromLTWH(100, 243, 200, 2.5), _p);
    canvas.drawRect(const Rect.fromLTWH(100, 249, 200, 2.5), _p);
    for (var x = 101.0; x < 300; x += 8) {
      if (x > 184 && x < 214) continue;
      canvas.drawRect(Rect.fromLTWH(x, 238, 5, 16), _p);
      canvas.drawPath(
        Path()
          ..moveTo(x, 238)
          ..lineTo(x + 2.5, 234.5)
          ..lineTo(x + 5, 238)
          ..close(),
        _p,
      );
    }
    _p.color = const Color(0xFF8D6E4B);
    canvas.drawRect(const Rect.fromLTWH(183, 233, 4, 22), _p);
    canvas.drawRect(const Rect.fromLTWH(213, 233, 4, 22), _p);
  }

  void _brickWall(Canvas canvas) {
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFB4654A);
    canvas.drawRect(const Rect.fromLTWH(100, 234, 200, 20), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF7A3F2D).withValues(alpha: 0.7);
    for (var row = 0; row < 3; row++) {
      final y = 240.0 + row * 6;
      canvas.drawLine(Offset(100, y), Offset(300, y), _p);
      for (var x = 100.0 + (row % 2) * 8; x < 300; x += 16) {
        canvas.drawLine(Offset(x, y - 6), Offset(x, y), _p);
      }
    }
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF455A64);
    for (var x = 101.0; x < 298; x += 10) {
      if (x > 186 && x < 212) continue;
      canvas.drawPath(
        Path()
          ..moveTo(x, 234)
          ..lineTo(x + 2.5, 228)
          ..lineTo(x + 5, 234)
          ..close(),
        _p,
      );
    }
    _p.color = const Color(0xFF3E2F28);
    canvas.drawRect(const Rect.fromLTWH(188, 234, 24, 20), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF90A4AE);
    for (var x = 191.0; x < 212; x += 4) {
      canvas.drawLine(Offset(x, 234), Offset(x, 254), _p);
    }
    _p.style = PaintingStyle.fill;
  }

  void _guardPost(Canvas canvas, double t) {
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFECEFF1);
    canvas.drawRect(const Rect.fromLTWH(266, 224, 24, 30), _p);
    _p.color = const Color(0xFF1565C0);
    canvas.drawPath(
      Path()
        ..moveTo(262, 224)
        ..lineTo(278, 214)
        ..lineTo(294, 224)
        ..close(),
      _p,
    );
    _p.color = const Color(0xFFB3E5FC);
    canvas.drawRect(const Rect.fromLTWH(270, 230, 16, 11), _p);
    final bob = math.sin(t * 2) * 0.8;
    _p.color = const Color(0xFFE0AC84);
    canvas.drawCircle(Offset(278, 237 + bob), 3.4, _p);
    _p.color = const Color(0xFF0D47A1);
    canvas.drawRect(Rect.fromLTWH(274.5, 232.5 + bob, 7, 2.5), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF607D8B);
    canvas.drawRect(const Rect.fromLTWH(270, 230, 16, 11), _p);
    _p.style = PaintingStyle.fill;
  }

  void _pylons(Canvas canvas, double t) {
    final pulse = 0.5 + 0.5 * math.sin(t * 4);
    for (final x in const [94.0, 306.0]) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF455A64);
      canvas.drawRect(Rect.fromLTWH(x - 2.5, 218, 5, 38), _p);
      canvas.drawRect(Rect.fromLTWH(x - 5, 252, 10, 4), _p);
      _p.color = const Color(0xFF40C4FF).withValues(alpha: 0.25 + 0.3 * pulse);
      canvas.drawCircle(Offset(x, 214), 9, _p);
      _p.color = const Color(0xFF80D8FF);
      canvas.drawCircle(Offset(x, 214), 4.5, _p);
    }
    final roofY = _roofY;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF80D8FF).withValues(alpha: 0.45 + 0.35 * pulse);
    canvas.drawPath(
      Path()
        ..moveTo(94, 214)
        ..quadraticBezierTo(200, roofY - 74 + math.sin(t * 5) * 3, 306, 214),
      _p,
    );
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }

  void _dome(Canvas canvas, double t, bool strong) {
    final color = strong ? const Color(0xFFFFD54F) : const Color(0xFF40C4FF);
    const center = Offset(200, _gy);
    const radius = 172.0;
    final pulse = 0.5 + 0.5 * math.sin(t * 3);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(_vl, _vt, _vr, _gy + 2));
    _p
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0),
          color.withValues(alpha: strong ? 0.32 + 0.12 * pulse : 0.2),
        ],
        stops: const [0, 0.7, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, _p);
    _p.shader = null;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = strong ? 2.5 : 1.6
      ..color = color.withValues(alpha: strong ? 0.8 : 0.5);
    canvas.drawCircle(center, radius, _p);
    final a = math.pi + (t * 0.6 % 1.0) * math.pi;
    _p
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.5);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 2), a, 0.25,
        false, _p);
    _p.style = PaintingStyle.fill;
    canvas.restore();
  }

  // ---------------------------------------- sampah & logika meluber > 1/3

  void _bag(Canvas canvas, Offset c, int seed, {double scale = 1}) {
    final h = _hh(seed);
    final o = Offset(c.dx + ((h % 7) - 3) * 0.4, c.dy);

    if (scale == 1 && h % 9 == 0) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFC49A6C);
      canvas.drawRect(Rect.fromCenter(center: o, width: 12, height: 9), _p);
      _p.color = const Color(0xFFE0C090);
      canvas.drawRect(
          Rect.fromCenter(center: o.translate(0, -1), width: 12, height: 2),
          _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = const Color(0xFF8D6E4B);
      canvas.drawRect(Rect.fromCenter(center: o, width: 12, height: 9), _p);
      _p.style = PaintingStyle.fill;
      return;
    }
    if (scale == 1 && h % 13 == 0) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF212121);
      canvas.drawCircle(o, 4, _p);
      _p
        ..strokeWidth = 0.8
        ..color = const Color(0xFF616161);
      canvas.drawCircle(o, 2, _p);
      _p.style = PaintingStyle.fill;
      return;
    }

    final bw = (12 + h % 3) * scale;
    final bh = (10 + (h ~/ 3) % 3) * scale;
    _p
      ..style = PaintingStyle.fill
      ..color = _bagColors[h % _bagColors.length];
    canvas.drawOval(Rect.fromCenter(center: o, width: bw, height: bh), _p);
    _p.color = Colors.white.withValues(alpha: 0.14);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(o.dx - bw * 0.15, o.dy - bh * 0.15),
        width: bw * 0.35,
        height: bh * 0.3,
      ),
      _p,
    );
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * scale
      ..color = _bagColors[h % _bagColors.length];
    canvas.drawLine(
      Offset(o.dx, o.dy - bh / 2 + 1),
      Offset(o.dx + 2 * scale, o.dy - bh / 2 - 3 * scale),
      _p,
    );
    _p.style = PaintingStyle.fill;
  }

  void _drawBags(Canvas canvas) {
    final total = _slots.length;
    final over = _overflowRatio; // 0 jika wasteLevel > 0 dan trashRatio <= 1/3

    int count;
    if (d.eliminated) {
      count = total;
    } else if (over <= 0.005) {
      count = 0;
    } else {
      count = math.max(1, (math.pow(over, 1.15) * total).round());
    }
    for (var i = 0; i < count && i < total; i++) {
      _bag(canvas, _slots[i], i);
    }
    // Rumah yang tertimbun: atapnya pun tertutup sampah.
    if (d.eliminated && !d.compact) {
      for (var k = 0; k < _roofSlots.length; k++) {
        final s = _roofSlots[k];
        _bag(canvas, Offset(s.dx, _roofY + s.dy), 300 + k);
      }
    }
  }

  void _drawRats(Canvas canvas, double t) {
    final plague = d.worldEvent == 'rat_plague';
    if (d.compact || _ultra || !(d.trashRatio >= 0.75 || d.eliminated || plague)) return;
    final guards = ((d.pets?.hasSpecies(PetSpecies.cat) ?? false) ? 2 : 4) *
        (plague ? 2 : 1); // wabah tikus: dua kali lipat
    for (var k = 0; k < guards; k++) {
      final base = k % 2 == 0 ? 350.0 : 50.0;
      final ang = t * 1.6 + k * 2;
      final x = base + math.sin(ang) * 34;
      final y = 259.0 + (k % 2) * 3;
      final dir = math.cos(ang) >= 0 ? 1.0 : -1.0;
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF757575);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 9, height: 4.5), _p);
      canvas.drawCircle(Offset(x + dir * 5, y), 2, _p);
      _p.color = const Color(0xFFE57373);
      canvas.drawCircle(Offset(x + dir * 6.4, y - 0.6), 0.6, _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = const Color(0xFFBCAAA4);
      canvas.drawLine(Offset(x - dir * 4.5, y),
          Offset(x - dir * 9, y - 2 + math.sin(t * 8 + k) * 1.2), _p);
      _p.style = PaintingStyle.fill;
    }
  }

  void _drawCrows(Canvas canvas, double t) {
    if (_lite || !(_critical || d.eliminated)) return;
    for (var k = 0; k < 3; k++) {
      final cx = k % 2 == 0 ? 350.0 : 50.0;
      final ang = t * 0.8 + k * 2.1;
      final x = cx + math.cos(ang) * 36;
      final y = 192 + math.sin(ang) * 14 - k * 8;
      final flap = math.sin(t * 9 + k) * 4;
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF101010);
      canvas.drawLine(Offset(x - 7, y - flap), Offset(x, y), _p);
      canvas.drawLine(Offset(x, y), Offset(x + 7, y - flap), _p);
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt;
    }
  }

  void _drawStinkAndFlies(Canvas canvas, double t) {
    if (_ultra || !(d.trashRatio >= 0.5 || d.eliminated)) return;
    final ratio = d.eliminated ? 1.0 : d.trashRatio;

    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF9CCC65).withValues(alpha: 0.25 + 0.3 * ratio);
    for (final bx in const [336.0, 364.0, 36.0, 64.0]) {
      final path = Path()..moveTo(bx, 232);
      for (var s = 1; s <= 12; s++) {
        path.lineTo(
            bx + math.sin(t * 2 + s * 0.6 + bx) * 3.5, 232 - s * 2.8);
      }
      canvas.drawPath(path, _p);
    }
    _p.style = PaintingStyle.fill;

    final flies = 2 + (ratio * 10).round();
    _p.color = const Color(0xFF212121);
    for (var k = 0; k < flies; k++) {
      final cx = k % 2 == 0 ? 350.0 : 50.0;
      final x = cx + math.sin(t * (2 + k % 3) + k) * 28;
      final y =
          218 + math.cos(t * (3 + k % 2) + k * 1.7) * 14 - ratio * 10;
      canvas.drawCircle(Offset(x, y), 1.1, _p);
    }
  }

}

/// Mahkota, tangkis, lemparan, emoji, efek sinematik, suasana.
extension KostPainterFx on KostPainter {
  // ------------------------------------------- mahkota bounty & tangkis

  void _drawBountyCrown(Canvas canvas, double t) {
    if (!d.isBounty || d.eliminated) return;
    final cy = _roofY - 58 + math.sin(t * 3) * 1.5;
    const cx = 150.0;
    final pulse = 0.5 + 0.5 * math.sin(t * 4);

    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.18 + 0.18 * pulse);
    canvas.drawCircle(Offset(cx, cy), 18, _p);

    final crown = Path()
      ..moveTo(cx - 12, cy + 8)
      ..lineTo(cx - 14, cy - 6)
      ..lineTo(cx - 6, cy)
      ..lineTo(cx, cy - 9)
      ..lineTo(cx + 6, cy)
      ..lineTo(cx + 14, cy - 6)
      ..lineTo(cx + 12, cy + 8)
      ..close();
    _p.color = const Color(0xFFFFC107);
    canvas.drawPath(crown, _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF8D6E00);
    canvas.drawPath(crown, _p);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFE53935);
    canvas.drawCircle(Offset(cx, cy + 3), 2, _p);

    _drawBannerText(canvas, 'BURONAN +40', Offset(cx, cy - 18),
        const Color(0xFFFFD54F));
  }

  void _drawParry(Canvas canvas, double t) {
    const dur = 1800;
    for (final f in d.fx) {
      if (f.type != FxType.parry) continue;
      final age = f.age;
      if (age < 0 || age > dur) continue;
      final q = age / dur;

      // perisai biru-putih yang meledak ke luar
      for (var ring = 0; ring < 3; ring++) {
        final local = _c01((q - ring * 0.12) / 0.8);
        if (local <= 0) continue;
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * (1 - local)
          ..color = (ring == 1 ? Colors.white : const Color(0xFF40C4FF))
              .withValues(alpha: (1 - local) * 0.9);
        canvas.drawCircle(
            Offset(200, _gy - 60), _lerp(20, 190, _ease(local)), _p);
      }
      _p.style = PaintingStyle.fill;

      if (q < 0.25) {
        _p.color = Colors.white.withValues(alpha: (1 - q / 0.25) * 0.5);
        canvas.drawRect(_view, _p);
      }

      _drawBannerText(
        canvas,
        'TANGKIS!',
        Offset(200, _roofY - 30 - q * 26),
        const Color(0xFF80D8FF),
        scale: 1.1 + math.sin(q * math.pi) * 0.35,
        alpha: 1 - q,
      );
    }
  }

  // ---------------------------------------------------- lemparan sampah

  void _drawThrown(Canvas canvas, double t) {
    final right = d.facingRight;

    for (final f in d.fx) {
      final age = f.age.toDouble();
      if (f.type == FxType.incoming) {
        // Terbang antar rumah digambar KostStreetPainter (koordinat dunia).
        // Di sini hanya dampak saat sampah mendarat (kantong ke-j mendarat di
        // age 730 + 80*j ms; sama dengan jadwal terbang di KostStreetPainter).
        final to = Offset(right ? 350 : 50, 238);
        for (var j = 0; j < 5; j++) {
          final q = (age - 730 - j * 80) / 700;
          if (q <= 0 || q >= 1) continue;
          final cx = to.dx + (j - 2) * 8;
          _p
            ..style = PaintingStyle.fill
            ..color = const Color(0xFF8D6E63).withValues(alpha: (1 - q) * 0.65);
          canvas.drawCircle(Offset(cx, 244), 7 + q * 14, _p);
        }
        if (!d.compact && age > 720 && age < 1620) {
          final q = (age - 720) / 900;
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = 24
            ..color =
            const Color(0xFFD32F2F).withValues(alpha: 0.35 * (1 - q));
          canvas.drawRect(_view, _p);
          _p.style = PaintingStyle.fill;

          _drawBannerText(
            canvas,
            'DISERANG SAMPAH!',
            Offset(to.dx, 200 - q * 26),
            const Color(0xFFFF8A80),
            scale: 1.0 + math.sin(q * math.pi) * 0.25,
            alpha: 1 - q,
          );
        }
      } else if (f.type == FxType.outgoing) {
        // Momen pelepasan: kilatan di titik lempar. Kantongnya sendiri terbang
        // lewat KostStreetPainter sesuai jarak ke rumah tujuan.
        final from = Offset(right ? 250 : 150, _roofY - 24);
        if (age >= 0 && age < 400) {
          final fq = 1 - age / 400;
          _p
            ..style = PaintingStyle.fill
            ..color = const Color(0xFFFFAB00).withValues(alpha: fq * 0.7);
          canvas.drawCircle(from, 14 * fq, _p);
        }
        if (age >= 0 && age < 1100) {
          final q = age / 1100;
          _drawBannerText(
            canvas,
            'LEMPAR SAMPAH!',
            Offset(from.dx, from.dy - 16 - q * 20),
            const Color(0xFFFFCC80),
            scale: 1.0,
            alpha: 1 - q,
          );
        }
      }
    }
  }

  // ------------------------------- persiapan serangan (menunggu Tangkis)

  /// Penyerang mengangkat kantong / menyalakan sirene di titik lempar selama
  /// korban masih punya jendela Tangkis. Animasi lempar baru jalan sesudahnya.
  void _drawWindup(Canvas canvas, double t) {
    if (d.charge == 0 || d.eliminated) return;
    final right = d.facingRight;
    final o = Offset(right ? 250 : 150, _roofY - 24);
    // Makin dekat jendela Tangkis habis, makin tegang (getar & denyut cepat).
    final urgency = _c01(1 - d.chargeLeft / 2.5);
    final pop = _easeOutBack(_c01((2.5 - d.chargeLeft) / 0.3));
    final pulse = 0.5 + 0.5 * math.sin(t * (8 + 10 * urgency));

    if (d.charge == 1) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFAB00)
            .withValues(alpha: (0.14 + 0.2 * pulse) * _c01(pop));
      canvas.drawCircle(o, (13 + 9 * urgency + 3 * pulse) * pop, _p);
      canvas.save();
      canvas.translate(o.dx, o.dy - 3 - pulse * 2 * pop);
      canvas.rotate(math.sin(t * (7 + 8 * urgency)) * (0.15 + 0.3 * urgency));
      _bag(canvas, Offset.zero, 777,
          scale: math.max(0.01, (1.1 + 0.3 * urgency + 0.08 * pulse) * pop));
      canvas.restore();
      _drawBannerText(canvas, 'SIAP MELEMPAR…', Offset(o.dx, o.dy - 30),
          const Color(0xFFFFCC80),
          alpha: _c01(pop));
    } else {
      final on = math.sin(t * (14 + 8 * urgency)) > 0;
      final c = on ? const Color(0xFFFF1744) : const Color(0xFF2979FF);
      _p
        ..style = PaintingStyle.fill
        ..color = c.withValues(alpha: 0.3 * _c01(pop));
      canvas.drawCircle(o, (13 + 5 * urgency + 3 * pulse) * pop, _p);
      _p.color = c;
      canvas.drawCircle(o, 4.5 * _c01(pop), _p);
      _drawBannerText(canvas, 'SIDAK DIKIRIM…', Offset(o.dx, o.dy - 28),
          const Color(0xFFFF8A80),
          alpha: _c01(pop));
    }
  }

  // ------------------------------------ gelembung emoji reaksi beranimasi

  void _drawEmojiReactions(Canvas canvas, double t) {
    const dur = 3600.0;
    for (final f in d.fx) {
      if (f.type != FxType.emoji) continue;
      final age = f.age.toDouble();
      if (age < 0 || age > dur) continue;

      final p = age / dur;
      final emoji = emojiFromCode(f.amount.round());
      final pop = p < 0.14
          ? _easeOutBack(p / 0.14)
          : (p > 0.82 ? (1 - p) / 0.18 : 1.0);
      final alpha = p > 0.80 ? ((1 - p) / 0.20).clamp(0.0, 1.0) : 1.0;

      final baseCx = 200.0 + math.sin(p * math.pi * 3.5) * (d.compact ? 6 : 12);
      final baseCy = (_roofY - (d.compact ? 22 : 42)) - p * (d.compact ? 24 : 38);

      canvas.save();
      canvas.translate(baseCx, baseCy);
      canvas.scale(pop * (d.compact ? 1.15 : 1.0));

      // Gelembung balon komik putih dengan outline emas
      final bubbleR = d.compact ? 17.0 : 21.0;
      _p
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: 0.94 * alpha);
      canvas.drawCircle(Offset.zero, bubbleR, _p);

      // Ekor balon mengarah ke atap kost
      final tail = Path()
        ..moveTo(-5, bubbleR - 2)
        ..lineTo(0, bubbleR + 7)
        ..lineTo(6, bubbleR - 2)
        ..close();
      canvas.drawPath(tail, _p);

      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFFFFCA28).withValues(alpha: alpha);
      canvas.drawCircle(Offset.zero, bubbleR, _p);
      _p.style = PaintingStyle.fill;

      // Gambar karakter Emoji utama
      final tp = TextPainter(
        text: TextSpan(
          text: emoji,
          style: TextStyle(fontSize: d.compact ? 20 : 24),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

      // Partikel mini emoji memancar di sekeliling balon (pada layar utama)
      if (!d.compact && p < 0.75) {
        final pq = p / 0.75;
        for (var k = 0; k < 4; k++) {
          final ang = -math.pi * 0.85 + k * 0.56 + math.sin(t * 4 + k) * 0.1;
          final dist = bubbleR + 4 + pq * 24;
          final px = math.cos(ang) * dist;
          final py = math.sin(ang) * dist - pq * 10;
          final miniTp = TextPainter(
            text: TextSpan(
              text: emoji,
              style: TextStyle(
                fontSize: 11 * (1 - pq * 0.4),
                color: Colors.white.withValues(alpha: (1 - pq) * alpha),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          miniTp.paint(canvas, Offset(px - miniTp.width / 2, py - miniTp.height / 2));
        }
      }

      canvas.restore();
    }
  }

  // ------------------------------------------- efek sinematik & dramatis

  void _drawGodRays(Canvas canvas, double t, double p) {
    if (_lite || p > 0.45 || d.eliminated || _isRainy) {
      return;
    }
    // Berkas cahaya hanya saat matahari tinggi (siang), bukan senja/malam.
    if (d.dayPhase != null && _sunElev < 0.55) return;
    final sun = Offset(_sunX, 46);
    final fade = 1 - p / 0.45;
    _p
      ..style = PaintingStyle.fill
      ..shader = null;
    for (var k = 0; k < 5; k++) {
      final ang = math.pi * 0.62 + k * 0.13 + math.sin(t * 0.5 + k) * 0.03;
      final w = 0.05 + (k % 2) * 0.025;
      const len = 380.0;
      final path = Path()
        ..moveTo(sun.dx, sun.dy)
        ..lineTo(sun.dx + math.cos(ang - w) * len,
            sun.dy + math.sin(ang - w) * len)
        ..lineTo(sun.dx + math.cos(ang + w) * len,
            sun.dy + math.sin(ang + w) * len)
        ..close();
      final a = _c01(0.05 + 0.035 * math.sin(t * 1.3 + k * 1.7)) * fade;
      _p.color = const Color(0xFFFFF59D).withValues(alpha: a);
      canvas.drawPath(path, _p);
    }
  }

  void _confettiBurst(Canvas canvas, Offset o, double q, int n, int seed) {
    if (q <= 0 || q >= 1) return;
    const cols = [
      Color(0xFFFFD54F),
      Color(0xFFFF5252),
      Color(0xFF40C4FF),
      Color(0xFF69F0AE),
      Color(0xFFE040FB),
    ];
    _p.style = PaintingStyle.fill;
    for (var k = 0; k < n; k++) {
      final h = _hh(seed + k);
      final ang = -math.pi / 2 + ((h % 1000) / 1000 - 0.5) * math.pi * 1.5;
      final sp = 50.0 + (h % 90);
      final x = o.dx + math.cos(ang) * sp * q + math.sin(q * 12 + k) * 3;
      final y = o.dy + math.sin(ang) * sp * q + 110 * q * q;
      final a = _c01(1 - q * q);
      _p.color = cols[h % cols.length].withValues(alpha: a);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(q * 9 + k);
      canvas.drawRect(const Rect.fromLTWH(-2, -1.2, 4, 2.4), _p);
      canvas.restore();
    }
  }

  void _drawConfetti(Canvas canvas, double t) {
    if (d.compact) return;
    final tierP = _fxProgress(FxType.tier, 2400);
    if (tierP != null) {
      _confettiBurst(canvas, Offset(200, _roofY - 10), tierP, 46, 4000);
    }
    final buildP = _buildP;
    if (buildP != null) {
      final floorB = _isFloorBuild;
      final done = floorB ? 0.88 : 0.76;
      if (buildP > done) {
        final idx = math.max(0, math.min(d.rooms - 1, _floors * 4 - 1));
        _confettiBurst(
          canvas,
          floorB ? Offset(200, _roofY - 20) : _cell(idx).center,
          (buildP - done) / (1 - done),
          floorB ? 40 : 26,
          5000,
        );
      }
    }
  }

  void _drawVignette(Canvas canvas, double t, double p) {
    var a = 0.28 + p * 0.2 + (_critical ? 0.12 : 0);
    if (d.compact) a *= 0.6;
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

    // Semburan cahaya oranye saat membakar sampah
    final burnP = _fxProgress(FxType.burn, 4500);
    if (burnP != null) {
      final env = burnP < 0.12
          ? burnP / 0.12
          : (burnP > 0.8 ? (1 - burnP) / 0.2 : 1.0);
      _p.color = const Color(0xFFFF6D00)
          .withValues(alpha: _c01(0.12 * env * (0.7 + 0.3 * math.sin(t * 12))));
      canvas.drawRect(_view, _p);
    }
  }

  void _drawCinematic(Canvas canvas, double t) {
    final fx = _hijackFx();
    if (fx != null && fx.amount.round() != 1) {
      final hl = _hijackTimes(fx);
      final ms = fx.age.toDouble();
      // p = kemajuan fase perebutan (0..1); sorotan hanya di sekitar fase itu
      final p = (ms - hl.a) / hl.g;
      final env = _c01((ms - (hl.a - 500)) / 500) *
          (1 - _c01((ms - (hl.a + hl.g + 500)) / 800));
      final e = _ease(env);

      // Sorotan sinematik: sekitar truk terang, sisanya digelapkan
      if (!d.compact) {
        const center = Offset(290, 278);
        _p
          ..style = PaintingStyle.fill
          ..shader = RadialGradient(
            colors: [
              Colors.black.withValues(alpha: 0),
              Colors.black.withValues(alpha: 0.55 * e),
            ],
            stops: const [0.35, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: 210));
        canvas.drawRect(_view, _p);
        _p.shader = null;
      }

      // Denyut alarm merah
      if (p > 0.3 && p < 0.85) {
        final pulse = 0.5 + 0.5 * math.sin(t * 18);
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..color = const Color(0xFFFF1744).withValues(alpha: 0.12 + 0.28 * pulse);
        canvas.drawRect(_view, _p);
        _p.style = PaintingStyle.fill;
      }

      // Kilatan putih tepat saat maling merebut kemudi
      final fl = 1 - (p - 0.42).abs() / 0.12;
      if (fl > 0) {
        _p
          ..style = PaintingStyle.fill
          ..color = Colors.white.withValues(alpha: _c01(fl) * 0.55);
        canvas.drawRect(_view, _p);
      }
    }

    // Kilatan saat kost tertimbun
    final cp = _fxProgress(FxType.collapse, 1500);
    if (cp != null && cp < 0.15) {
      _p
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: (1 - cp / 0.15) * 0.5);
      canvas.drawRect(_view, _p);
    }
  }

  // ----------------------------------------------- abu, kabut, suasana

  void _drawAsh(Canvas canvas, double t, double p) {
    if (p < 0.55 && !d.smog) return;
    final n = _lite ? 8 : 34;
    final spanX = _vr - _vl;
    final spanY = _gy - _vt;
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF424242).withValues(alpha: 0.45);
    for (var i = 0; i < n; i++) {
      final h = _hh(i + 50);
      final x = _vl + (h % 1000) / 1000 * spanX + math.sin(t + i) * 6;
      final y = _vt + ((t * (14 + h % 18) + h % 300) % spanY);
      canvas.drawCircle(Offset(x, y), (0.9 + (h % 3) * 0.4) * _fxScale, _p);
    }
  }

  void _drawHaze(Canvas canvas, double p) {
    final a = p * 0.32 + (d.smog ? 0.28 : 0);
    if (a <= 0.01) return;
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF6B5E4C).withValues(alpha: a.clamp(0.0, 0.7));
    canvas.drawRect(_view, _p);
  }
}

/// Adegan pembajakan truk.
extension KostPainterHijack on KostPainter {
  // ===================================================================
  //  ADEGAN PEMBAJAKAN TRUK (satu adegan utuh di koordinat dunia)
  //
  //  1) Van pembajak berangkat dari sisi RUMAH PEMBAJAK, melaju ke truk
  //     korban yang sedang bekerja, mengerem (jejak ban & asap).
  //  2) Maling lari dari van, melompat ke kabin, sopir terlempar, truk
  //     bergetar lalu putar balik (bila perlu) menghadap rumah pembajak.
  //  3) Van & truk rampasan kabur BERSAMA menuju rumah pembajak (van di
  //     depan), menambah lalu mengurangi kecepatan, parkir di sana.
  //  4) Maling turun merayakan, kendaraan masuk garasi sambil memudar.
  //
  //  Durasi mengikuti jarak rumah (lihat [hijackDurationMs]). Semua posisi
  //  dihitung dari waktu adegan, jadi kedua rumah melihat hal yang sama.
  // ===================================================================

  double _easeIn(double x) {
    x = _c01(x);
    return x * x * x;
  }

  void _hijackWorld(
      Canvas canvas,
      double t,
      KostFx fx, {
        required double victimX,
        required double thiefX,
        required double vl,
        required double vr,
        bool thiefHauling = false,
      }) {
    final tl = _hijackTimes(fx);
    final aMs = tl.a, gMs = tl.g, eMs = tl.e, sMs = tl.s;
    final ms = fx.age.toDouble();
    final tG = ms - aMs; // waktu sejak perebutan
    final tE = tG - gMs; // waktu sejak kabur
    final tS = tE - eMs; // waktu sejak tiba di rumah pembajak
    final dir = thiefX >= victimX ? 1.0 : -1.0; // arah kabur
    const gy = _roadY;
    final span = (thiefX - victimX).abs();
    // Bila truk pembajak sendiri sedang parkir di rumahnya, berhenti lebih awal.
    final parkT = thiefX - (thiefHauling ? dir * 110.0 : 0.0);

    // ------------------------------------------------ jalur kendaraan
    final vanStop = victimX + (dir > 0 ? 112.0 : -104.0);
    final vanStart = victimX + dir * math.max(math.min(span, 900.0), 420.0);
    final vanEnd = parkT + dir * 118.0;
    final vanEscStart = aMs + gMs * 0.92;
    final vanEscLen = eMs - 100.0;

    double vanXAt(double m) {
      if (m < aMs) return _lerp(vanStart, vanStop, _easeOut3(m / aMs));
      if (m < vanEscStart) return vanStop;
      return _lerp(
          vanStop, vanEnd, _easeInOut3((m - vanEscStart) / vanEscLen));
    }

    double truckXAt(double m) {
      final e = m - aMs - gMs;
      if (e <= 0) return victimX;
      return _lerp(victimX, parkT, _easeInOut3(e / eMs));
    }

    // Masuk garasi: maju sedikit sambil memudar (akhir adegan).
    final garage = _ease((tS - sMs * 0.5) / (sMs * 0.5));
    final roll = dir * 70.0 * garage;
    final vehAlpha = 1 - garage;

    final vanInView = vanStart > vl - 60 && vanStart < vr + 60;
    final vanA = (vanInView ? _ease(ms / 450.0) : 1.0) * vehAlpha;

    final truckPure = truckXAt(ms);
    final truckX = truckPure + roll;
    final vanPure = vanXAt(ms);
    final vanX = vanPure + roll;

    // kecepatan (px/ms) untuk garis kecepatan, rem & kemiringan bodi
    final vT = (truckPure - truckXAt(ms - 50)) / 50.0;
    final vV = (vanPure - vanXAt(ms - 50)) / 50.0;
    final spNow = (truckPure - truckXAt(ms - 40)).abs() / 40.0;
    final spPrev = (truckXAt(ms - 60) - truckXAt(ms - 100)).abs() / 40.0;
    final truckLean = ((spNow - spPrev) * 0.35).clamp(-0.04, 0.04).toDouble();
    final truckBraking = tE > 0 && (spNow - spPrev) < -0.02;

    // ------------------------------------------------ jejak ban & asap rem
    final vanSkidFrom = _lerp(vanStart, vanStop, _easeOut3(0.55));
    if (ms > aMs * 0.55) {
      final cur = vanXAt(math.min(ms, aMs));
      final fade = 1 - _c01(tE / (eMs * 0.8));
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: 0.35 * fade);
      canvas.drawLine(Offset(vanSkidFrom, gy - 1), Offset(cur, gy - 1), _p);
      canvas.drawLine(Offset(vanSkidFrom, gy + 2), Offset(cur, gy + 2), _p);
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt;
      for (var k = 0; k < 5; k++) {
        final tk = aMs * (0.55 + 0.45 * k / 4.0);
        final ph = _c01((ms - tk) / 800.0);
        if (ph <= 0 || ph >= 1) continue;
        _p.color = const Color(0xFFD7CCC8).withValues(alpha: (1 - ph) * 0.55);
        canvas.drawCircle(
          Offset(_lerp(vanSkidFrom, vanStop, k / 4.0), gy - 4 - ph * 16),
          4 + ph * 10,
          _p,
        );
      }
    }

    // ------------------------------------------------ truk korban
    final truckF = dir > 0 ? _c01((tG - gMs * 0.58) / (gMs * 0.20)) : 0.0;
    var truckSX = dir > 0 ? math.cos(math.pi * truckF) : 1.0;
    if (truckSX.abs() < 0.03) truckSX = truckSX < 0 ? -0.03 : 0.03;
    final truckHop =
    (truckF > 0 && truckF < 1) ? -math.sin(math.pi * truckF) * 8 : 0.0;
    final stolen = tG > gMs * 0.40;
    final revving = tG > gMs * 0.34 && tE < 0;
    final jitter = revving ? math.sin(t * 70) * 0.9 : 0.0;
    final (double, double) lr = tG < 0 ? _workLid(t) : (0.0, 0.0);

    _fadeLayer(
      canvas,
      Rect.fromLTRB(truckX - 140, gy - 90, truckX + 140, gy + 18),
      vehAlpha,
          () {
        canvas.save();
        canvas.translate(truckX + jitter, gy + truckHop);
        canvas.scale(truckSX, 1);
        _truckBody(
          canvas,
          t,
          wheelA: truckPure / 6.5 * (truckSX >= 0 ? 1 : -1),
          lean: truckLean,
          moving: vT.abs() > 0.02 || revving,
          brake: truckBraking,
          lid: lr.$1,
          ram: lr.$2,
          stolen: stolen,
          thiefInCab: tG >= gMs * 0.42 && tS <= 0,
          bob: revving ? math.sin(t * 60) * 0.5 : 0,
        );
        canvas.restore();
      },
    );

    // ------------------------------------------------ van pembajak
    final vanF = _c01((tG - gMs * 0.74) / (gMs * 0.18));
    final vanFaceRaw = (-dir) * math.cos(math.pi * vanF);
    final vanFace = vanFaceRaw.abs() < 0.04
        ? (vanFaceRaw < 0 ? -0.04 : 0.04)
        : vanFaceRaw;
    final vanHop = (vanF > 0 && vanF < 1) ? -math.sin(math.pi * vanF) * 6 : 0.0;
    final vanBraking = ms > aMs * 0.55 && ms < aMs + 220;
    _fadeLayer(
      canvas,
      Rect.fromLTRB(vanX - 110, gy - 80, vanX + 110, gy + 18),
      vanA,
          () {
        _raiderVan(
          canvas,
          vanX,
          gy + vanHop,
          t,
          face: vanFace,
          braking: vanBraking,
          wheelA: vanPure / 5.4 * (vanFace >= 0 ? 1 : -1),
        );
      },
    );

    // ------------------------------------------------ garis kecepatan
    void speedLines(double cx, double v, double reach, double alphaMul) {
      final k = _c01((v.abs() - 0.12) / 0.3) * alphaMul;
      if (k <= 0.02) return;
      final s = v >= 0 ? 1.0 : -1.0; // arah gerak; ekor di sisi berlawanan
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.55 * k);
      for (var i = 0; i < 7; i++) {
        final yy = gy - 6 - i * 5.0;
        final len = 26 + (i % 3) * 14 + k * 40;
        final sx = cx - s * (reach + (i % 2) * 10);
        canvas.drawLine(Offset(sx, yy), Offset(sx - s * len, yy), _p);
      }
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt;
    }

    speedLines(truckX, vT, 52, vehAlpha);
    speedLines(vanX, vV, 40, vanA * 0.7);

    // koin rampasan beterbangan di belakang truk yang kabur
    final spT = _c01((vT.abs() - 0.12) / 0.3) * vehAlpha;
    if (tE > 0 && spT > 0.05) {
      final s = vT >= 0 ? 1.0 : -1.0;
      for (var k = 0; k < 8; k++) {
        final ph = (t * 1.6 + k * 0.125) % 1.0;
        final cx = truckX - s * (50 + ph * 46 + k * 2);
        final cy = gy - 26 - math.sin(ph * math.pi) * 26;
        _p.color =
            const Color(0xFFFFD54F).withValues(alpha: (1 - ph) * 0.95 * spT);
        canvas.drawCircle(Offset(cx, cy), 2.6, _p);
        _p.color =
            const Color(0xFFFFF59D).withValues(alpha: (1 - ph) * 0.95 * spT);
        canvas.drawCircle(Offset(cx - 0.7, cy - 0.7), 0.9, _p);
      }
    }

    // ------------------------------------------------ maling: lari & lompat
    if (tG > 0 && tG < gMs * 0.44) {
      final runEndX = victimX - 46;
      final r = _c01(tG / (gMs * 0.30));
      final j = _c01((tG - gMs * 0.30) / (gMs * 0.12));
      Offset pos;
      var rot = 0.0;
      if (j <= 0) {
        pos = Offset(_lerp(vanStop, runEndX, _ease(r)), gy + 4);
      } else {
        pos = Offset(
          _lerp(runEndX, victimX - 32, _ease(j)),
          _lerp(gy + 4, gy - 20, _ease(j)) - math.sin(j * math.pi) * 18,
        );
        rot = j * 6.28;
      }
      _person(
        canvas,
        pos,
        shirt: const Color(0xFF212121),
        mask: true,
        rot: rot,
        swing: j > 0 ? 3 : math.sin(t * 26) * 3.4,
        alpha: _c01(tG / (gMs * 0.06)),
      );
    }

    // ------------------------------------------------ sopir terlempar
    if (tG >= gMs * 0.34) {
      final td = _c01((tG - gMs * 0.34) / (gMs * 0.22));
      final fadeOut = 1 - _ease((tE - eMs * 0.2) / (eMs * 0.5));
      final walk = -dir * 46 * _easeOut3(tE / (eMs * 0.8));
      final dx = _lerp(victimX - 44, victimX - 68, _ease(td)) + walk;
      // mendarat di jalur dekat kamera supaya tidak tergilas truk yang kabur
      final dy = _lerp(gy - 18, gy + 8, td) - math.sin(td * math.pi) * 16;
      _person(
        canvas,
        Offset(dx, dy),
        shirt: const Color(0xFF43A047),
        hat: true,
        rot: td < 1 ? td * 5.5 : math.sin(t * 3) * 0.08,
        swing: td < 1 ? 3 : 0.6,
        alpha: fadeOut,
      );
      if (td >= 1 && fadeOut > 0.05) {
        for (var k = 0; k < 3; k++) {
          final ang = t * 5 + k * 2.09;
          _star(
            canvas,
            Offset(dx + math.cos(ang) * 7, dy - 19 + math.sin(ang) * 2.5),
            2.6,
            const Color(0xFFFFD54F).withValues(alpha: fadeOut),
          );
        }
      }
      // garis kaget memancar
      if (tG < gMs * 0.95) {
        final e = 1 - (tG - gMs * 0.34) / (gMs * 0.61);
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFFF5252).withValues(alpha: _c01(e));
        for (var k = 0; k < 6; k++) {
          final ang = -math.pi + k * (math.pi / 5);
          canvas.drawLine(
            Offset(dx + math.cos(ang) * 10, dy - 26 + math.sin(ang) * 10),
            Offset(dx + math.cos(ang) * 17, dy - 26 + math.sin(ang) * 17),
            _p,
          );
        }
        _p
          ..style = PaintingStyle.fill
          ..strokeCap = StrokeCap.butt;
      }
    }

    // ------------------------------------------------ petugas angkut
    if (tG < 0) {
      _workers(canvas, t); // masih bekerja seperti biasa sampai van tiba
    } else {
      final walk = _easeOut3(tE / (eMs * 0.9));
      _workers(
        canvas,
        t,
        freezeT: t - tG / 1000.0,
        idle: true,
        shock: _ease(tG / 250.0) * (1 - walk),
        dx: -dir * 60 * walk,
        alpha: 1 - _ease((tE - eMs * 0.1) / (eMs * 0.6)),
      );
    }

    // ------------------------------------------------ tiba di rumah pembajak
    if (tS > 0) {
      final hq = _c01(tS / (sMs * 0.3));
      final pos = Offset(
        _lerp(parkT + dir * 28, parkT + dir * 78, _ease(hq)) + roll,
        _lerp(gy - 18, gy + 4, hq) - math.sin(hq * math.pi) * 20,
      );
      _person(
        canvas,
        pos,
        shirt: const Color(0xFF212121),
        mask: true,
        rot: hq < 1 ? hq * 6.28 : 0,
        swing: hq < 1 ? 3 : math.sin(t * 12) * 3,
        alpha: vehAlpha,
      );
      for (var k = 0; k < 10; k++) {
        final ph = _c01((tS - k * 35) / 900.0);
        if (ph <= 0 || ph >= 1) continue;
        final cx = parkT + dir * 28 + (k - 4.5) * 7.0 * ph;
        final cy = gy - 34 - math.sin(ph * math.pi) * (24 + (k % 3) * 6);
        _p.color = const Color(0xFFFFD54F).withValues(alpha: (1 - ph) * 0.95);
        canvas.drawCircle(Offset(cx, cy), 2.6, _p);
        _p.color = const Color(0xFFFFF59D).withValues(alpha: (1 - ph) * 0.95);
        canvas.drawCircle(Offset(cx - 0.7, cy - 0.7), 0.9, _p);
      }
    }

    // ------------------------------------------------ spanduk
    final bq = _c01((ms - (aMs + gMs * 0.36)) / (gMs * 0.64 + eMs * 0.25));
    if (bq > 0 && bq < 1) {
      final a = bq < 0.75 ? 1.0 : (1 - bq) / 0.25;
      final slam = _easeOutBack(_c01(bq / 0.12));
      _drawBannerText(
        canvas,
        'TRUK DIBAJAK!',
        Offset(victimX - 68, 232 - bq * 20),
        const Color(0xFFFF5252),
        scale: 0.8 + slam * 0.7,
        alpha: a,
      );
    }
    final tq = _c01((ms - (aMs + gMs + eMs * 0.88)) / (eMs * 0.12 + sMs));
    if (tq > 0 && tq < 1) {
      final a = tq < 0.8 ? 1.0 : (1 - tq) / 0.2;
      final slam = _easeOutBack(_c01(tq / 0.15));
      _drawBannerText(
        canvas,
        'BAJAK BERHASIL!',
        Offset(parkT, 216 - tq * 14),
        const Color(0xFFFFD54F),
        scale: 0.8 + slam * 0.55,
        alpha: a,
      );
    }
  }

  /// [face]: +1 menghadap kanan, -1 kiri, di antaranya = sedang putar balik
  /// (bodi memipih lalu membalik). [wheelA] = sudut putar roda.
  void _raiderVan(Canvas canvas, double x, double y, double t,
      {required double face, bool braking = false, double wheelA = 0}) {
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(face, 1);
    if (braking) canvas.rotate(0.045);

    _p
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.25);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 70, height: 5), _p);

    // Sorot lampu depan
    _p.color = const Color(0xFFFFF59D).withValues(alpha: 0.2);
    canvas.drawPath(
      Path()
        ..moveTo(30, -12)
        ..lineTo(78, -3)
        ..lineTo(78, -21)
        ..close(),
      _p,
    );

    _p.color = const Color(0xFF4A148C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-30, -24, 60, 18), const Radius.circular(4)),
      _p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-18, -24)
        ..lineTo(-12, -33)
        ..lineTo(14, -33)
        ..lineTo(22, -24)
        ..close(),
      _p,
    );
    _p.color = const Color(0xFFB3E5FC);
    canvas.drawPath(
      Path()
        ..moveTo(-13, -25)
        ..lineTo(-9, -31)
        ..lineTo(12, -31)
        ..lineTo(18, -25)
        ..close(),
      _p,
    );
    // Wajah bertopeng di balik kaca
    _p.color = const Color(0xFF212121);
    canvas.drawCircle(const Offset(8, -27), 3, _p);
    _p.color = Colors.white;
    canvas.drawCircle(const Offset(7, -27.5), 0.7, _p);
    canvas.drawCircle(const Offset(9.2, -27.5), 0.7, _p);

    // Garis kuning-merah
    _p.color = const Color(0xFFFFD600);
    canvas.drawRect(const Rect.fromLTWH(-30, -15, 60, 2.5), _p);
    _p.color = const Color(0xFFFF1744);
    canvas.drawRect(const Rect.fromLTWH(-30, -12.5, 60, 1.5), _p);

    _p.color = const Color(0xFFFFF176);
    canvas.drawRect(const Rect.fromLTWH(28, -20, 3, 4), _p);
    _p.color = const Color(0xFFEF5350);
    canvas.drawRect(const Rect.fromLTWH(-31, -20, 2, 4), _p);

    // Lampu strobo atap
    final blink = math.sin(t * 16) > 0;
    _p.color = (blink ? const Color(0xFFFF1744) : const Color(0xFF2979FF))
        .withValues(alpha: 0.9);
    canvas.drawRect(const Rect.fromLTWH(-4, -36, 8, 3), _p);

    final wa = wheelA;
    for (final wx in const [-17.0, 17.0]) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF212121);
      canvas.drawCircle(Offset(wx, -5), 5.4, _p);
      _p.color = const Color(0xFFBDBDBD);
      canvas.drawCircle(Offset(wx, -5), 2, _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = const Color(0xFF9E9E9E);
      canvas.drawLine(
        Offset(wx + math.cos(wa) * 4, -5 + math.sin(wa) * 4),
        Offset(wx - math.cos(wa) * 4, -5 - math.sin(wa) * 4),
        _p,
      );
      _p.style = PaintingStyle.fill;
    }
    canvas.restore();
  }

  void _person(
      Canvas canvas,
      Offset feet, {
        required Color shirt,
        bool mask = false,
        bool hat = false,
        double rot = 0,
        double swing = 0,
        double alpha = 1,
      }) {
    final a = _c01(alpha);
    if (a <= 0.02) return;
    if (a < 1) {
      canvas.saveLayer(
        Rect.fromCenter(center: feet, width: 60, height: 60),
        Paint()..color = Color.fromRGBO(0, 0, 0, a),
      );
    }
    canvas.save();
    canvas.translate(feet.dx, feet.dy - 8);
    canvas.rotate(rot);

    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF37474F);
    canvas.drawLine(const Offset(0, 2), Offset(-swing, 8), _p);
    canvas.drawLine(const Offset(0, 2), Offset(swing, 8), _p);
    _p.color = shirt;
    canvas.drawLine(const Offset(0, -3), Offset(-5, -1 + swing * 0.5), _p);
    canvas.drawLine(const Offset(0, -3), Offset(5, -5 - swing * 0.4), _p);

    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt
      ..color = shirt;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3.2, -6, 6.4, 9), const Radius.circular(2)),
      _p,
    );
    _p.color = const Color(0xFFE0AC84);
    canvas.drawCircle(const Offset(0, -9.5), 3.2, _p);
    if (mask) {
      _p.color = const Color(0xFF212121);
      canvas.drawRect(const Rect.fromLTWH(-3.2, -10.6, 6.4, 2.4), _p);
      _p.color = Colors.white;
      canvas.drawCircle(const Offset(-1.3, -9.5), 0.6, _p);
      canvas.drawCircle(const Offset(1.3, -9.5), 0.6, _p);
    }
    if (hat) {
      _p.color = const Color(0xFFFF8F00);
      canvas.drawRect(const Rect.fromLTWH(-3.6, -13.4, 7.2, 2.6), _p);
    }
    canvas.restore();
    if (a < 1) canvas.restore();
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final rr = i.isEven ? r : r * 0.4;
      final ang = i * math.pi / 4 - math.pi / 2;
      final pt = c + Offset(math.cos(ang) * rr, math.sin(ang) * rr);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    _p
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawPath(path, _p);
  }

}
class _IconLife {
  _IconLife(this.first, this.last);
  final double first;
  double last;
}

final Map<int, _IconLife> _iconBorn = {};