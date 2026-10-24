part of 'kost_scene.dart';

// ====================================================================
//  HEWAN PELIHARAAN DI HALAMAN KOST (maks 2). MURNI visual.
//
//  Sama seperti penghuni: perilaku = fungsi waktu + seed rumah, jadi tiap
//  rumah punya ritme sendiri. Posisi diintegrasikan per frame di
//  [KostPetCrew] (state-nya hidup di luar painter, yang dibuat ulang
//  tiap frame, seperti KostOwner).
//
//  Reaksi: serangan masuk -> anjing menyalak, kucing melengkung, ayam
//  mengepak; terkena lemparan / api / hampir tertimbun -> kabur;
//  tangkis berhasil -> bersorak; malam -> tidur; tertimbun -> sedih.
// ====================================================================

enum PetPose { walk, idle, sit, sleep, peck, alert, bark, flee, cheer, sad }

class PetAgent {
  PetAgent(this.slot, this.def, this.x);

  final int slot;
  PetDef def;
  double x;
  final double y = 271;
  double dir = 1;
  PetPose pose = PetPose.idle;
  bool walking = false;
  String? icon;
}

/// Hewan satu rumah: daftar hewan terpasang + state geraknya.
class KostPetCrew {
  KostPetCrew({this.seed = 0});

  final int seed;

  /// Diisi ulang pemanggil tiap kali baris `player_pets` berubah.
  PetLoadout loadout = PetLoadout.empty;

  final Map<int, PetAgent> _agents = {};
  bool visible = true;
  int _lastMs = -1;

  static const double _minX = 112;
  static const double _maxX = 296;
  static const double _doorX = 201;

  List<PetAgent> get agents =>
      (_agents.values.toList()..sort((a, b) => a.slot.compareTo(b.slot)));

  bool hasSpecies(PetSpecies s) =>
      loadout.slots.any((p) => p.def.species == s);

  void update(KostSceneData d, KostOwner? owner, double t) {
    final now = sceneNowMs();
    final dt = _lastMs < 0 ? 0.0 : math.min(0.1, (now - _lastMs) / 1000.0);
    _lastMs = now;

    visible = !(d.buriedAgeMs != null && d.buriedAgeMs! >= 5000);

    // sinkronkan agen dengan slot terisi
    for (var s = 1; s <= Pets.maxSlots; s++) {
      final ps = loadout.inSlot(s);
      if (ps == null) {
        _agents.remove(s);
        continue;
      }
      final a = _agents[s];
      if (a == null) {
        _agents[s] = PetAgent(s, ps.def, _doorX + (s == 1 ? -9 : 11));
      } else {
        a.def = ps.def;
      }
    }

    bool recent(FxType ty, int ms) =>
        d.fx.any((f) => f.type == ty && f.age >= 0 && f.age < ms);

    final r = d.eliminated ? 1.0 : d.trashRatio;
    final threat = d.facingRight ? 1.0 : -1.0;
    final night = d.dayPhase != null && (d.dayPhase! < 0.2 || d.dayPhase! > 0.88);
    final alert = d.attackLeft > 0 || d.charge == 1;
    final hit = recent(FxType.incoming, 1600);
    final cheer = recent(FxType.parry, 1800);
    final fire = recent(FxType.burn, 4500);

    for (final a in _agents.values) {
      final sp = a.def.species;
      final h = _hh(seed * 13 + a.slot * 101);
      var tx = a.x;
      var speed = 0.0;
      var pose = PetPose.idle;
      String? ic;
      double? face;

      if (d.eliminated) {
        pose = PetPose.sad;
        tx = 150.0 + a.slot * 40;
        speed = 300;
        ic = '😢';
      } else if (d.buriedAgeMs != null) {
        pose = PetPose.flee;
        tx = threat > 0 ? _minX : _maxX;
        speed = 95;
        ic = '😱';
      } else if (hit) {
        pose = PetPose.flee;
        tx = threat > 0 ? _minX + a.slot * 14 : _maxX - a.slot * 14;
        speed = 110;
        ic = '💦';
      } else if (alert) {
        speed = 75;
        face = threat;
        switch (sp) {
          case PetSpecies.dog:
            pose = PetPose.bark;
            tx = _doorX + threat * 22;
            ic = '❗';
          case PetSpecies.cat:
            pose = PetPose.alert;
            tx = _doorX - threat * 16;
          case PetSpecies.hen:
            pose = PetPose.alert;
            tx = _doorX - threat * 40;
            ic = '‼️';
        }
      } else if (cheer) {
        pose = PetPose.cheer;
        ic = '❤️';
      } else if (fire || r >= 0.9) {
        pose = PetPose.flee;
        tx = 204 + 80 * math.sin(t * 1.9 + a.slot * 2 + h % 7);
        speed = 80;
      } else if (night) {
        pose = PetPose.sleep;
        tx = sp == PetSpecies.hen ? 236.0 : (sp == PetSpecies.cat ? 168 : 190);
        tx += a.slot * 6;
        speed = 24;
        ic = (a.x - tx).abs() < 1.5 && math.sin(t * 1.1 + a.slot) > 0.2
            ? '💤'
            : null;
      } else if (r >= 0.5) {
        // bau sampah: menjauh dari kotak sampah (kiri), diam sambil lesu
        pose = PetPose.sit;
        tx = 232.0 + a.slot * 22;
        speed = 36;
        ic = r >= 0.75 && math.sin(t * 2 + a.slot) > 0.6 ? '🤢' : null;
      } else {
        switch (sp) {
          case PetSpecies.dog:
            {
              // anjing setia: membuntuti pemilik
              final ox = owner?.x ?? _doorX;
              final od = owner?.dir ?? 1;
              tx = ox - od * (16.0 + a.slot * 6);
              final far = (tx - a.x).abs() > 8;
              speed = far ? 46 : 0;
              pose = far ? PetPose.walk : PetPose.sit;
            }
          case PetSpecies.cat:
            {
              final b = (t / 8).floor();
              final stay = _hh(seed * 7 + a.slot * 31 + b) % 3 == 0;
              tx = 124.0 + _hh(seed * 13 + a.slot * 101 + b) % 164;
              speed = stay ? 0 : 20;
              pose = stay ? PetPose.sit : PetPose.walk;
            }
          case PetSpecies.hen:
            {
              final b = (t / 4).floor();
              final stay = _hh(seed * 5 + a.slot * 53 + b) % 3 != 0;
              tx = 124.0 + _hh(seed * 11 + a.slot * 67 + b) % 164;
              speed = stay ? 0 : 16;
              pose = stay ? PetPose.peck : PetPose.walk;
            }
        }
      }

      tx = tx.clamp(_minX, _maxX).toDouble();
      final dx = tx - a.x;
      final step = speed * dt;
      final moving = speed > 0 && dx.abs() > 0.8;
      if (moving) {
        a.x += dx.abs() <= step ? dx : step * dx.sign;
        a.dir = dx.sign;
      }
      a.walking = moving && pose != PetPose.sad;
      if (a.walking && pose == PetPose.idle) pose = PetPose.walk;
      if (face != null) a.dir = face;
      if (moving && (pose == PetPose.sit || pose == PetPose.peck)) {
        pose = PetPose.walk;
      }
      a.pose = pose;
      a.icon = ic;
    }
  }
}

extension KostPainterPets on KostPainter {
  void _drawPets(Canvas canvas, double t) {
    final crew = d.pets;
    if (crew == null || d.compact) return;
    crew.update(d, d.owner, t);
    if (!crew.visible) return;

    for (final a in crew.agents) {
      final def = a.def;
      _drawEgg(canvas, crew, a, t);

      canvas.save();
      canvas.translate(a.x, a.y);

      // bayangan
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF000000).withValues(alpha: 0.16);
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, 0.8), width: 15, height: 3.6),
          _p);

      canvas.scale(a.dir, 1);
      switch (def.species) {
        case PetSpecies.cat:
          _petCat(canvas, def, a, t);
        case PetSpecies.hen:
          _petHen(canvas, def, a, t);
        case PetSpecies.dog:
          _petDog(canvas, def, a, t);
      }
      canvas.restore();

      if (def.rarity == 2 && a.pose != PetPose.sleep) {
        final ph = (t * 0.9 + a.slot * 0.5) % 1.0;
        _star(
          canvas,
          Offset(a.x + math.sin(t * 2 + a.slot) * 6, a.y - 12 - ph * 12),
          1.7 * (1 - ph),
          const Color(0xFFFFE082).withValues(alpha: 0.9 * (1 - ph)),
        );
      }
      if (a.icon != null) {
        _resIcon(canvas, a.x, a.y - 24, a.icon!, t, a.slot + crew.seed);
      }
    }
  }

  /// Ayam bertelur: telur muncul sebentar di tempat acak halaman tiap ~40 dtk.
  void _drawEgg(Canvas canvas, KostPetCrew crew, PetAgent a, double t) {
    if (a.def.species != PetSpecies.hen || d.eliminated) return;
    const cycle = 40.0;
    final tt = t + crew.seed * 0.9 + a.slot * 5.0;
    final ph = tt % cycle;
    if (ph > 8) return;
    final idx = (tt / cycle).floor();
    final ex = 124.0 + _hh(crew.seed * 3 + a.slot * 17 + idx) % 164;
    final pop = _easeOutBack(ph / 0.5);
    final fade = ph > 7 ? _c01(8 - ph) : 1.0;
    final gold = a.def.rarity == 2;
    canvas.save();
    canvas.translate(ex, 271);
    canvas.scale(pop, pop);
    _p
      ..style = PaintingStyle.fill
      ..color = (gold ? const Color(0xFFFFD54F) : const Color(0xFFFFF3E0))
          .withValues(alpha: fade);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -2.4), width: 4.2, height: 5.4),
        _p);
    _p.color = Colors.white.withValues(alpha: 0.7 * fade);
    canvas.drawCircle(const Offset(-0.7, -3.6), 0.7, _p);
    canvas.restore();
  }

  // -------------------------------------------------------------- kucing
  void _petCat(Canvas c, PetDef def, PetAgent a, double t) {
    final body = def.body;
    final acc = def.accent;
    final ph = t * (a.walking ? 13 : 5) + a.slot * 1.7;
    final pose = a.pose;
    final blink = ((t * 0.7 + a.slot * 3) % 4.0) < 0.12;

    void eye(Offset p) {
      if (blink || pose == PetPose.sleep) {
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = const Color(0xFF212121);
        c.drawLine(p + const Offset(-0.8, 0), p + const Offset(0.8, 0), _p);
        _p.style = PaintingStyle.fill;
      } else {
        _p
          ..style = PaintingStyle.fill
          ..color = def.eye;
        c.drawCircle(p, 0.85, _p);
        _p.color = const Color(0xFF101010);
        c.drawCircle(p, 0.4, _p);
      }
    }

    void ears(Offset h, {double up = 0}) {
      _p
        ..style = PaintingStyle.fill
        ..color = body;
      for (final sx in const [-1.8, 1.4]) {
        final p = Path()
          ..moveTo(h.dx + sx - 1.3, h.dy - 2)
          ..lineTo(h.dx + sx, h.dy - 5 - up)
          ..lineTo(h.dx + sx + 1.3, h.dy - 2)
          ..close();
        c.drawPath(p, _p);
      }
    }

    void tail(Offset from, double sway, {bool up = false}) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = body;
      final path = Path()..moveTo(from.dx, from.dy);
      if (up) {
        path.quadraticBezierTo(
            from.dx - 3, from.dy - 7, from.dx - 1 + sway * 0.4, from.dy - 11);
      } else {
        path.quadraticBezierTo(from.dx - 5, from.dy - 3 + sway,
            from.dx - 7, from.dy - 7 + sway * 0.6);
      }
      c.drawPath(path, _p);
      _p.strokeCap = StrokeCap.butt;
      _p.style = PaintingStyle.fill;
    }

    if (pose == PetPose.sleep) {
      _p
        ..style = PaintingStyle.fill
        ..color = body;
      c.drawOval(
          Rect.fromCenter(center: const Offset(0, -3), width: 14, height: 6.5),
          _p);
      c.drawCircle(const Offset(5.2, -3.6), 2.7, _p);
      ears(const Offset(5.4, -3.6));
      eye(const Offset(6.4, -3.6));
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = body;
      c.drawArc(Rect.fromCenter(center: const Offset(-1, -2), width: 14, height: 6),
          math.pi * 0.55, math.pi * 0.9, false, _p);
      _p
        ..strokeCap = StrokeCap.butt
        ..style = PaintingStyle.fill;
      // belang
      _p.color = acc.withValues(alpha: 0.7);
      for (var i = -1; i <= 1; i++) {
        c.drawRect(Rect.fromLTWH(i * 3.0 - 0.4, -6.2, 0.9, 2.2), _p);
      }
      return;
    }

    final sit = pose == PetPose.sit || pose == PetPose.sad;
    final arch = pose == PetPose.alert;
    final jump = pose == PetPose.cheer ? -math.sin(t * 9 + a.slot).abs() * 3.2 : 0.0;
    final bob = (a.walking ? math.sin(ph * 2).abs() * -0.7 : 0.0) + jump;
    c.save();
    c.translate(0, bob);

    // kaki
    if (!sit) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..color = body;
      final sw = a.walking ? math.sin(ph) * 2.6 : 0.0;
      c.drawLine(Offset(-3.2, -4.2), Offset(-3.2 + sw, 0), _p);
      c.drawLine(Offset(-1.6, -4.2), Offset(-1.6 - sw, 0), _p);
      c.drawLine(Offset(2.6, -4.2), Offset(2.6 - sw, 0), _p);
      c.drawLine(Offset(4.2, -4.2), Offset(4.2 + sw, 0), _p);
      _p
        ..strokeCap = StrokeCap.butt
        ..style = PaintingStyle.fill;
    }

    // badan
    _p
      ..style = PaintingStyle.fill
      ..color = body;
    late final Offset head;
    if (sit) {
      c.drawOval(
          Rect.fromCenter(center: const Offset(-0.5, -5), width: 7.5, height: 10),
          _p);
      c.drawOval(
          Rect.fromCenter(center: const Offset(-1.5, -1.8), width: 9, height: 3.4),
          _p);
      head = const Offset(1.8, -11.8);
      tail(const Offset(-4, -2.5), math.sin(t * 2 + a.slot) * 1.5);
    } else if (arch) {
      c.drawOval(
          Rect.fromCenter(center: const Offset(0, -8), width: 10, height: 8),
          _p);
      head = const Offset(5.8, -9.4);
      tail(const Offset(-4.2, -9), 0, up: true);
      // bulu berdiri
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = body;
      for (var i = -2; i <= 2; i++) {
        c.drawLine(Offset(i * 1.9, -11.6), Offset(i * 1.9 + 0.4, -13.6), _p);
      }
      _p.style = PaintingStyle.fill;
    } else {
      c.drawOval(
          Rect.fromCenter(center: const Offset(0, -6.6), width: 11.5, height: 6),
          _p);
      head = const Offset(6.2, -9.2);
      tail(const Offset(-5.3, -7.4), math.sin(ph * 0.6) * 2.2,
          up: pose == PetPose.cheer);
    }
    // belang punggung
    _p.color = acc.withValues(alpha: 0.75);
    if (!sit) {
      for (var i = -1; i <= 1; i++) {
        c.drawRect(
            Rect.fromLTWH(i * 3.0 - 0.4, arch ? -11.6 : -9.5, 0.9, 2.6), _p);
      }
    } else {
      for (var i = 0; i < 2; i++) {
        c.drawRect(Rect.fromLTWH(-3.4, -8.6 + i * 2.6, 2.2, 0.8), _p);
      }
    }

    // kepala
    _p.color = body;
    c.drawCircle(head, 3.2, _p);
    ears(head, up: arch ? 0.8 : 0);
    eye(head + const Offset(1.3, -0.4));
    _p
      ..color = const Color(0xFFE57373)
      ..style = PaintingStyle.fill;
    c.drawCircle(head + const Offset(2.9, 0.5), 0.5, _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4
      ..color = const Color(0xFFEEEEEE).withValues(alpha: 0.8);
    c.drawLine(head + const Offset(2.4, 0.9), head + const Offset(5.4, 0.2), _p);
    c.drawLine(head + const Offset(2.4, 1.3), head + const Offset(5.4, 1.8), _p);
    _p.style = PaintingStyle.fill;
    c.restore();
  }

  // --------------------------------------------------------------- ayam
  void _petHen(Canvas c, PetDef def, PetAgent a, double t) {
    final body = def.body;
    final acc = def.accent;
    final ph = t * (a.walking ? 12 : 5) + a.slot * 1.3;
    final pose = a.pose;
    const beak = Color(0xFFFFB300);
    const leg = Color(0xFFE08A1E);

    if (pose == PetPose.sleep) {
      _p
        ..style = PaintingStyle.fill
        ..color = body;
      c.drawOval(
          Rect.fromCenter(center: const Offset(0, -4.2), width: 12, height: 8.4),
          _p);
      _p.color = acc.withValues(alpha: 0.55);
      c.drawOval(
          Rect.fromCenter(center: const Offset(-1, -4), width: 6.5, height: 4),
          _p);
      _p.color = acc;
      c.drawCircle(const Offset(3.6, -8.2), 1.0, _p);
      return;
    }

    final flap = pose == PetPose.alert || pose == PetPose.flee;
    final hop = (flap || pose == PetPose.cheer)
        ? -math.sin(t * 14 + a.slot).abs() * 2.8
        : (a.walking ? math.sin(ph * 2).abs() * -0.5 : 0.0);
    c.save();
    c.translate(0, hop);

    // kaki
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..color = leg;
    final sw = a.walking ? math.sin(ph) * 2.2 : 0.0;
    c.drawLine(const Offset(-0.8, -2.6), Offset(-0.8 + sw, 0), _p);
    c.drawLine(const Offset(1.2, -2.6), Offset(1.2 - sw, 0), _p);
    _p
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.fill;

    // ekor
    _p.color = acc.withValues(alpha: 0.85);
    for (var i = 0; i < 3; i++) {
      final ang = -2.5 + i * 0.35;
      c.drawLine(
          const Offset(-4.2, -7.2),
          Offset(-4.2 + math.cos(ang) * 5, -7.2 + math.sin(ang) * 5),
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round);
    }
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;

    // badan + sayap
    _p.color = body;
    c.drawOval(
        Rect.fromCenter(center: const Offset(0, -6), width: 10.5, height: 8.4),
        _p);
    _p.color = Color.lerp(body, const Color(0xFF000000), 0.14)!;
    if (flap) {
      final w = math.sin(t * 18 + a.slot) * 3;
      c.drawLine(
          const Offset(-1, -7),
          Offset(-4, -11 + w),
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round);
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt;
    } else {
      c.drawOval(
          Rect.fromCenter(center: const Offset(-0.8, -5.8), width: 6.2, height: 3.8),
          _p);
    }

    // kepala (mematuk: menunduk berkala)
    final peck = pose == PetPose.peck
        ? (math.sin(t * 7 + a.slot * 2) > 0.2 ? 1.0 : 0.0)
        : 0.0;
    final head = Offset(4.4 + peck * 2.6, -11.2 + peck * 6.6);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = body;
    c.drawLine(const Offset(3, -8.6), head, _p);
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt
      ..color = body;
    c.drawCircle(head, 2.5, _p);
    // jengger & paruh
    _p.color = acc;
    c.drawCircle(head + const Offset(-0.4, -2.4), 0.9, _p);
    c.drawCircle(head + const Offset(0.7, -2.5), 0.8, _p);
    _p.color = beak;
    c.drawPath(
        Path()
          ..moveTo(head.dx + 2.1, head.dy - 0.5)
          ..lineTo(head.dx + 4.4, head.dy + 0.2)
          ..lineTo(head.dx + 2.1, head.dy + 1.0)
          ..close(),
        _p);
    _p.color = def.eye;
    c.drawCircle(head + const Offset(0.9, -0.4), 0.5, _p);
    c.restore();
  }

  // ------------------------------------------------------------- anjing
  void _petDog(Canvas c, PetDef def, PetAgent a, double t) {
    final body = def.body;
    final acc = def.accent;
    final husky = def.key == 'dog_husky';
    final dalmatian = def.key == 'dog_dalmatian';
    final ph = t * (a.walking ? 12 : 5) + a.slot * 1.9;
    final pose = a.pose;
    final bark = pose == PetPose.bark;
    final happy = pose == PetPose.cheer;

    if (pose == PetPose.sleep) {
      _p
        ..style = PaintingStyle.fill
        ..color = body;
      c.drawOval(
          Rect.fromCenter(center: const Offset(0, -3.4), width: 16, height: 6.8),
          _p);
      c.drawCircle(const Offset(7, -3.6), 3.2, _p);
      _p.color = husky ? body : acc;
      c.drawOval(
          Rect.fromCenter(center: const Offset(5.2, -4.6), width: 2.6, height: 4.4),
          _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = const Color(0xFF212121);
      c.drawLine(const Offset(7.6, -4.2), const Offset(9, -4.2), _p);
      _p.style = PaintingStyle.fill;
      return;
    }

    final sit = pose == PetPose.sit || pose == PetPose.sad;
    final jump = happy ? -math.sin(t * 10 + a.slot).abs() * 3.6 : 0.0;
    final bob = (a.walking ? math.sin(ph * 2).abs() * -0.8 : 0.0) + jump;
    c.save();
    c.translate(0, bob);

    final legC = Color.lerp(body, const Color(0xFF000000), 0.12)!;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..color = legC;
    final sw = a.walking ? math.sin(ph) * 3 : 0.0;
    if (sit) {
      c.drawLine(const Offset(3.2, -6), const Offset(3.4, 0), _p);
      c.drawLine(const Offset(1.6, -6), const Offset(1.8, 0), _p);
    } else {
      c.drawLine(const Offset(-4.6, -5.4), Offset(-4.6 + sw, 0), _p);
      c.drawLine(const Offset(-2.8, -5.4), Offset(-2.8 - sw, 0), _p);
      c.drawLine(const Offset(3.4, -5.4), Offset(3.4 - sw, 0), _p);
      c.drawLine(const Offset(5.2, -5.4), Offset(5.2 + sw, 0), _p);
    }
    _p.strokeCap = StrokeCap.butt;

    // ekor (kibas cepat saat senang / siaga)
    final wag = math.sin(t * (happy || bark ? 22 : 7) + a.slot) * (happy ? 3 : 1.6);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = husky ? acc : body;
    final tailBase = sit ? const Offset(-5, -3) : const Offset(-7, -9);
    c.drawLine(tailBase, tailBase + Offset(-3 + wag * 0.4, -5 + wag * 0.3), _p);
    _p
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.fill;

    // badan
    _p.color = body;
    late final Offset head;
    if (sit) {
      c.drawOval(
          Rect.fromCenter(center: const Offset(-0.8, -6.4), width: 9, height: 12.5),
          _p);
      head = const Offset(3, -14.6);
    } else {
      c.drawOval(
          Rect.fromCenter(center: const Offset(0, -8.2), width: 15, height: 7.6),
          _p);
      head = Offset(8.2, -12.6 - (bark ? 1.2 : 0));
    }
    if (husky) {
      _p.color = acc;
      c.drawOval(
          Rect.fromCenter(
              center: sit ? const Offset(0.2, -5.4) : const Offset(0.4, -5.8),
              width: sit ? 4.6 : 9,
              height: sit ? 8 : 3.4),
          _p);
    }
    if (dalmatian) {
      _p.color = acc;
      for (final s in const [
        Offset(-3.5, -9.5),
        Offset(-0.6, -6.6),
        Offset(2.4, -9.8),
        Offset(5, -7.4),
      ]) {
        if (sit && s.dx > 2) continue;
        c.drawCircle(s, 0.95, _p);
      }
    }

    // kepala
    _p.color = body;
    c.drawCircle(head, 3.9, _p);
    if (husky) {
      _p.color = acc;
      c.drawCircle(head + const Offset(1.2, 1.0), 2.4, _p);
    }
    // moncong
    _p.color = husky ? acc : Color.lerp(body, const Color(0xFFFFFFFF), 0.3)!;
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(head.dx + 1.8, head.dy - 0.2, 4.6, 3.0),
            const Radius.circular(1.4)),
        _p);
    _p.color = const Color(0xFF212121);
    c.drawCircle(head + const Offset(6.2, 0.6), 0.9, _p);
    if (bark) {
      c.drawPath(
          Path()
            ..moveTo(head.dx + 3, head.dy + 2.8)
            ..lineTo(head.dx + 6.2, head.dy + 2.6)
            ..lineTo(head.dx + 4.6, head.dy + 4.8)
            ..close(),
          _p..color = const Color(0xFFB71C1C));
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = Colors.white.withValues(alpha: 0.8);
      for (var i = 0; i < 2; i++) {
        c.drawArc(
            Rect.fromCenter(
                center: head + Offset(8.2 + i * 2.6, 0.4),
                width: 3 + i * 2.6,
                height: 6 + i * 3),
            -0.9, 1.8, false, _p);
      }
      _p.style = PaintingStyle.fill;
    }
    // telinga terkulai
    _p.color = husky ? body : acc;
    c.save();
    c.translate(head.dx - 1.2, head.dy - 2.2);
    c.rotate(husky ? 0 : 0.45 + math.sin(ph * 0.7) * (a.walking ? 0.12 : 0.03));
    if (husky) {
      c.drawPath(
          Path()
            ..moveTo(-1.6, 0)
            ..lineTo(0, -3.6)
            ..lineTo(1.6, 0)
            ..close(),
          _p);
    } else {
      c.drawOval(
          Rect.fromCenter(center: const Offset(-0.4, 1.6), width: 2.8, height: 5),
          _p);
    }
    c.restore();
    // mata
    final blink = ((t * 0.6 + a.slot * 2) % 5.0) < 0.12;
    if (blink) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = const Color(0xFF212121);
      c.drawLine(head + const Offset(1.4, -1.2), head + const Offset(2.8, -1.2), _p);
      _p.style = PaintingStyle.fill;
    } else {
      _p.color = def.eye;
      c.drawCircle(head + const Offset(2.1, -1.2), 0.85, _p);
      if (husky) {
        _p.color = const Color(0xFF101010);
        c.drawCircle(head + const Offset(2.1, -1.2), 0.38, _p);
      }
    }
    c.restore();
  }
}