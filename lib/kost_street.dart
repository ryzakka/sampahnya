part of 'kost_scene.dart';

// ====================================================================
//  MODE JALAN: beberapa kost berderet bertetangga + kamera zoom
// ====================================================================

/// Lebar satu slot rumah pada koordinat dunia (rumah ke-i mulai di i * 400).
const double kStreetSlotW = _w;

/// Tinggi dunia satu adegan.
const double kStreetSlotH = _h;

/// Kamera jalan: titik dunia di tengah panggung ([cx]) dan skala (px / unit).
/// Bergerak halus menuju target sehingga zoom antar rumah terasa mulus.
class KostStreetCamera {
  double cx = _w / 2;
  double scale = 1;
  double _tCx = _w / 2;
  double _tScale = 1;
  bool _ready = false;
  int _lastMs = sceneNowMs();

  double get targetCx => _tCx;
  double get targetScale => _tScale;

  /// Atur tujuan kamera. Panggilan pertama langsung "loncat" (tanpa animasi).
  void setTarget(double cx, double scale) {
    _tCx = cx;
    _tScale = scale;
    if (!_ready) {
      this.cx = cx;
      this.scale = scale;
      _ready = true;
    }
  }

  /// Dipanggil tiap frame (mis. dari listener AnimationController).
  void step() {
    final now = sceneNowMs();
    final dt = math.min(0.1, math.max(0, now - _lastMs) / 1000.0);
    _lastMs = now;
    final k = 1 - math.exp(-dt * 8.0);
    cx += (_tCx - cx) * k;
    scale = math.exp(
      math.log(scale) + (math.log(_tScale) - math.log(scale)) * k,
    );
    if ((_tCx - cx).abs() < 0.05) cx = _tCx;
    if ((scale / _tScale - 1).abs() < 0.0008) scale = _tScale;
  }

  Rect stageFor(Size size, EdgeInsets insets) => Rect.fromLTRB(
    insets.left,
    insets.top,
    math.max(insets.left + 40, size.width - insets.right),
    math.max(insets.top + 40, size.height - insets.bottom),
  );

  /// Titik layar untuk koordinat dunia (0, 0).
  Offset origin(Rect stage) =>
      Offset(stage.center.dx - cx * scale, stage.bottom - _h * scale);

  /// Indeks rumah di bawah koordinat layar [screenX] (null bila di luar deret).
  int? houseAt(double screenX, Rect stage, int count) {
    final wx = cx + (screenX - stage.center.dx) / scale;
    final i = (wx / _w).floor();
    return (i < 0 || i >= count) ? null : i;
  }
}

/// Deret kost: [houses] digambar berdampingan di satu jalan yang sama.
class KostStreet extends StatelessWidget {
  const KostStreet({
    super.key,
    required this.houses,
    required this.backdrop,
    required this.camera,
    required this.repaint,
    this.ids = const <String>[],
    this.shots = const <KostShot>[],
    this.ghosts = const <KostGhost>[],
    this.insets = EdgeInsets.zero,
  });

  final List<KostSceneData> houses;

  /// Arwah pemain yang sudah tertimbun (melayang di jalan).
  final List<KostGhost> ghosts;

  /// id pemain per rumah (urutan sama dengan [houses]) untuk memetakan [shots].
  final List<String> ids;

  /// Lemparan yang sedang terbang antar rumah.
  final List<KostShot> shots;

  /// Data untuk latar bersama (polusi, kabut, event dunia).
  final KostSceneData backdrop;
  final KostStreetCamera camera;
  final Listenable repaint;
  final EdgeInsets insets;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: KostStreetPainter(
          houses,
          backdrop,
          camera,
          repaint,
          ids: ids,
          shots: shots,
          ghosts: ghosts,
          insets: insets,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class KostStreetPainter extends CustomPainter {
  KostStreetPainter(
      this.houses,
      this.backdrop,
      this.camera,
      Listenable repaint, {
        this.ids = const <String>[],
        this.shots = const <KostShot>[],
        this.ghosts = const <KostGhost>[],
        this.insets = EdgeInsets.zero,
      })  : _repaint = repaint,
        super(repaint: repaint);

  final List<KostSceneData> houses;
  final KostSceneData backdrop;
  final KostStreetCamera camera;
  final EdgeInsets insets;
  final Listenable _repaint;
  final List<String> ids;
  final List<KostShot> shots;
  final List<KostGhost> ghosts;

  double _roofOf(int i) {
    final floors = math.min(3, math.max(1, (houses[i].rooms / 4).ceil()));
    return _gy - floors * _fh;
  }

  // ====================================================================
  //  EFEK LEMPARAN & ARWAH (v6: tumble, bayangan, debu, ledakan, hantu)
  // ====================================================================

  final Paint _pt = Paint();

  /// Acak deterministik 0..1 dari seed (tanpa state, aman dipanggil tiap frame).
  static double _rn(int seed) {
    var x = seed & 0x7fffffff;
    x = (x * 1103515245 + 12345) & 0x7fffffff;
    x = (x * 1103515245 + 12345) & 0x7fffffff;
    return (x >> 8) / 8388608.0;
  }

  static double _eo3(double x) {
    final k = 1 - _c01(x);
    return 1 - k * k * k;
  }

  /// Satu-satunya Paint yang dipakai ulang: semua properti di-reset tiap
  /// pemanggilan supaya tidak "bocor" antar gambar.
  Paint _pn(Color c,
      {PaintingStyle style = PaintingStyle.fill,
        double w = 1,
        bool add = false}) {
    return _pt
      ..style = style
      ..color = c
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..blendMode = add ? BlendMode.plus : BlendMode.srcOver
      ..maskFilter = null
      ..shader = null;
  }

  /// Cahaya lembut berlapis (aditif) tanpa blur mahal.
  void _glow(Canvas canvas, Offset at, double r, Color col, double a) {
    if (a <= 0.01 || r <= 0.5) return;
    for (var i = 0; i < 3; i++) {
      final k = 1 - i * 0.3;
      canvas.drawCircle(
        at,
        r * k,
        _pn(col.withValues(alpha: _c01(a * (0.16 + i * 0.14))), add: true),
      );
    }
  }

  Path _starPath(double r, int pts, double inner) {
    final p = Path();
    for (var i = 0; i < pts * 2; i++) {
      final rr = i.isEven ? r : r * inner;
      final ang = -math.pi / 2 + i * math.pi / pts;
      final x = math.cos(ang) * rr;
      final y = math.sin(ang) * rr;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    p.close();
    return p;
  }

  /// Bayangan di tanah: mengecil & memudar makin tinggi benda terbang.
  void _groundShadow(Canvas canvas, Offset pos, double size, double a) {
    const gy = 241.0;
    final h = math.max(0.0, gy - pos.dy);
    final k = 1 / (1 + h / 80);
    final w = size * (0.55 + 0.6 * k);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(pos.dx, gy), width: w, height: w * 0.24),
      _pn(Colors.black.withValues(alpha: a * k * 0.5)),
    );
  }

  /// Gelombang kejut berbentuk elips (perspektif tanah) atau lingkaran.
  void _ring(Canvas canvas, Offset at, double q, double r, Color col,
      double w, double a,
      {double flat = 0.34}) {
    if (q <= 0 || q >= 1) return;
    final e = _eo3(q);
    canvas.drawOval(
      Rect.fromCenter(
          center: at, width: r * 2 * e, height: math.max(1.0, r * 2 * e * flat)),
      _pn(col.withValues(alpha: a * (1 - q)),
          style: PaintingStyle.stroke, w: w * (1 - q * 0.6), add: true),
    );
  }

  void _dust(Canvas canvas, Offset at, double q, double fxs, int seed,
      {double size = 1,
        Color tone = const Color(0xFFBDB5A6),
        double alpha = 0.42}) {
    if (q <= 0 || q >= 1) return;
    final e = _eo3(q);
    for (var i = 0; i < 8; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final r = _rn(seed + i * 13);
      final spread = 0.35 + (i ~/ 2) * 0.22;
      final dx = side * spread * (16 + 14 * r) * e * size * fxs;
      final dy = -(3 + 9 * r) * math.sin(q * math.pi * 0.8) * size * fxs;
      final rad = (3.5 + 4 * r + q * 7) * size * fxs;
      final a = alpha * (1 - q) * (1 - q);
      canvas.drawCircle(at + Offset(dx, dy), rad, _pn(tone.withValues(alpha: a)));
      canvas.drawCircle(at + Offset(dx - rad * 0.2, dy - rad * 0.25), rad * 0.6,
          _pn(Colors.white.withValues(alpha: a * 0.35)));
    }
  }

  static const List<Color> _scrapCols = [
    Color(0xFFECEFF1),
    Color(0xFFC49A6C),
    Color(0xFF455A64),
    Color(0xFFFFE082),
    Color(0xFF90A4AE),
    Color(0xFF8BC34A),
  ];

  /// Serpihan sampah (kertas, kardus, kulit) yang terlontar & jatuh ke tanah.
  void _scraps(Canvas canvas, Offset at, double q, double fxs, int seed, int n,
      double power) {
    if (q <= 0 || q >= 1) return;
    for (var i = 0; i < n; i++) {
      final r1 = _rn(seed + i * 7 + 1);
      final r2 = _rn(seed + i * 11 + 2);
      final r3 = _rn(seed + i * 17 + 3);
      final ang = -math.pi * (0.12 + 0.76 * r1);
      final sp = (34 + 46 * r2) * power;
      final x = math.cos(ang) * sp * q;
      var y = math.sin(ang) * sp * q + 95 * power * q * q;
      if (y > 0) y = 0;
      final a = q < 0.65 ? 1.0 : (1 - q) / 0.35;
      final sz = (2.2 + 2.4 * r3) * fxs * math.sqrt(power);
      canvas.save();
      canvas.translate(at.dx + x * fxs, at.dy + y * fxs);
      canvas.rotate(q * (6 + 8 * r2) * (r1 > 0.5 ? 1 : -1) + r3 * 6);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: sz * 1.7, height: sz),
        _pn(_scrapCols[(seed + i) % _scrapCols.length]
            .withValues(alpha: a)),
      );
      canvas.restore();
    }
  }

  // ---------------------------------------------------------- lemparan

  /// Gambar kantong sampah terbang antar rumah. Lambungan & durasi mengikuti
  /// jarak. Lemparan "bounce" (ditangkis): terbang ke perisai penangkis lalu
  /// memantul balik ke pelempar (biru), bukan teleport.
  /// Jenis: karung (besar), polusi (kepulan gas), kembang api (terbang persis
  /// seperti lemparan biasa, lalu meledak / mati saat tiba).
  void _paintShots(Canvas canvas, double fxScale, KostPainter painter) {
    const cyan = Color(0xFF40C4FF);
    for (final sh in shots) {
      final a = ids.indexOf(sh.fromId);
      final b = ids.indexOf(sh.toId);
      if (a < 0 || b < 0 || a == b) continue;
      final age = sh.age.toDouble();
      if (age < 0) continue;
      final dist = (a - b).abs();
      final toRight = b > a;
      final launch = Offset(a * _w + (toRight ? 250.0 : 150.0), _roofOf(a) - 24);
      final landB = Offset(b * _w + (toRight ? 50.0 : 350.0), 238.0);
      final landA = Offset(a * _w + (toRight ? 350.0 : 50.0), 238.0);
      final shield = Offset(b * _w + (toRight ? 130.0 : 270.0), 190.0);
      final peak = (64.0 + 38.0 * dist) * (sh.bounce ? 0.8 : 1.0);
      final stagger = sh.kind == ShotKind.sack ? 110.0 : 80.0;
      final flight = math.max(400.0, sh.durMs - stagger * (sh.bags - 1));
      final fxs = math.min(fxScale, 2.2);
      final fs = math.min(fxs, 2.0);
      final end = sh.fizzle ? shield : landB;
      final seed = sh.startMs.abs();
      final isSmog = sh.kind == ShotKind.smog;
      final isFw = sh.kind == ShotKind.firework;
      final isSack = sh.kind == ShotKind.sack;

      // awan gas beracun yang menetap (sekali per lemparan)
      final afterGas = (age - flight) / 1300.0;
      if (isSmog && afterGas > 0 && afterGas < 1) {
        _paintGasCloud(
            canvas, sh.bounce ? landA : landB, afterGas, fxs, sh.bounce, seed);
      }

      for (var j = 0; j < sh.bags; j++) {
        final q = (age - j * stagger) / flight;
        if (q < 0) continue;
        final wob = (j - (sh.bags - 1) / 2) * 3.0;
        final bseed = seed + j * 101;

        Offset arc(Offset p0, Offset p1, double u, double pk) => Offset(
          _lerp(p0.dx, p1.dx, u) + wob,
          _lerp(p0.dy, p1.dy, u) - 4 * pk * u * (1 - u),
        );

        // kilatan perisai saat kantong menyentuh penangkis
        if (sh.bounce && q > 0.5) {
          final pq = (q - 0.5) * flight / 480.0;
          _parryFlash(canvas, shield.translate(wob, 0), pq, fxs,
              j == 0 ? 1.0 : 0.65);
        }

        // dampak setelah mendarat
        if (q > 1) {
          final spot = (sh.bounce ? landA : end).translate(wob, 0);
          final fwLive = isFw && sh.spark && !sh.fizzle;
          final dur = isFw ? (fwLive ? 1000.0 : 650.0) : 700.0;
          final iq = (q - 1) * flight / dur;
          if (iq > 0 && iq < 1) {
            if (isFw) {
              if (sh.fizzle) {
                _paintFizzle(canvas, spot, iq, fxs, bseed);
              } else if (sh.spark) {
                _paintFireKiss(canvas, spot, iq, fxs, bseed);
                _paintBurst(canvas, spot, iq, fxs, bseed);
              } else {
                _paintDud(canvas, spot, iq, fxs, bseed);
              }
            } else if (!isSmog) {
              _paintBagImpact(canvas, painter, spot, iq, fxs, bseed, isSack);
            }
          }
          continue;
        }

        Offset p0, p1;
        double lq;
        var back = false;
        if (!sh.bounce) {
          p0 = launch;
          p1 = end;
          lq = q;
        } else if (q < 0.5) {
          p0 = launch;
          p1 = shield;
          lq = q * 2;
        } else {
          p0 = shield;
          p1 = landA;
          lq = (q - 0.5) * 2;
          back = true;
        }
        Offset at(double u) => arc(p0, p1, _c01(u), peak);

        final pos = at(lq);
        final ahead = at(lq + 0.02);
        final behind = at(lq - 0.02);
        final heading =
        math.atan2(ahead.dy - behind.dy, ahead.dx - behind.dx);
        final dir = (toRight ^ back) ? 1.0 : -1.0;
        final tint = back
            ? cyan
            : (isSmog ? const Color(0xFF6D8B3A) : const Color(0xFF78909C));

        // kepulan "whoosh" di titik lempar
        if (!back && q < 0.16 && j < 2) {
          _dust(canvas, launch.translate(0, 8 * fxs), q / 0.16, fxs, bseed,
              size: isSack ? 0.8 : 0.5,
              tone: const Color(0xFFE0E0E0),
              alpha: 0.3);
        }

        // bayangan di tanah
        _groundShadow(canvas, pos, (isSack ? 30.0 : 17.0) * fxs, 0.9);

        // jejak
        if (isSmog) {
          for (var tr = 1; tr <= 6; tr++) {
            final pt = at(lq - tr * 0.05);
            final k = 1 - tr / 7;
            canvas.drawCircle(
              pt + Offset(0, tr * 1.6 * fxs),
              (4 + tr * 2.2) * fs,
              _pn((tr.isEven ? const Color(0xFF2E3B1F) : tint)
                  .withValues(alpha: 0.30 * k)),
            );
          }
        } else {
          for (var tr = 0; tr < 7; tr++) {
            final pa = at(lq - tr * 0.032);
            final pb = at(lq - (tr + 1) * 0.032);
            final k = 1 - tr / 7;
            canvas.drawLine(
              pa,
              pb,
              _pn(tint.withValues(alpha: 0.30 * k),
                  style: PaintingStyle.stroke,
                  w: (isSack ? 9.0 : 6.0) * k * fs),
            );
          }
          // serpihan kecil yang rontok dari kantong
          for (var m = 0; m < 3; m++) {
            final lag = 0.07 * (m + 1);
            if (lq - lag < 0) continue;
            final r = _rn(bseed + m * 31);
            final pp = at(lq - lag) +
                Offset((r - 0.5) * 8 * fxs, lag * 90 * fxs * (0.5 + r));
            canvas.drawCircle(pp, (1.2 + r) * fs,
                _pn(tint.withValues(alpha: 0.55 * (1 - m / 3))));
          }
        }

        _bonkGhosts(pos, dir);

        // pantulan: aura biru + kilau yang mengikuti
        if (back) {
          _glow(canvas, pos, 17 * fs, cyan, 0.55);
          for (var m = 0; m < 3; m++) {
            final r = _rn(bseed + m * 7);
            final pp = at(lq - 0.05 * (m + 1)) +
                Offset((r - 0.5) * 10 * fxs, (r - 0.5) * 8 * fxs);
            canvas.save();
            canvas.translate(pp.dx, pp.dy);
            canvas.rotate(lq * 6 + m);
            canvas.drawPath(
              _starPath((2.6 - m * 0.5) * fs, 4, 0.3),
              _pn(Colors.white.withValues(alpha: 0.8 - m * 0.2), add: true),
            );
            canvas.restore();
          }
        }

        if (isSmog) {
          _paintGasPuff(canvas, pos, lq, j, fxs, back, bseed);
        } else {
          // meregang searah laju di awal lemparan, lalu berputar saat melayang
          final stretch = 0.22 * (1 - _c01(lq / 0.18));
          final spin =
              dir * (lq * (isSack ? 5.0 : 9.0) + j + _rn(bseed) * 3);
          final sc = (isSack ? 2.2 : 1.15) * fxs;
          canvas.save();
          canvas.translate(pos.dx, pos.dy);
          canvas.rotate(heading);
          canvas.scale(1 + stretch, 1 / (1 + stretch));
          canvas.rotate(spin - heading);
          painter._bag(canvas, Offset.zero, 500 + j, scale: sc);
          canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: 13 * sc, height: 11 * sc),
            _pn(Colors.white.withValues(alpha: 0.2),
                style: PaintingStyle.stroke, w: 1.0 * fxs),
          );
          canvas.restore();
        }
      }
    }
  }

  /// Arwah terpentok sampah yang lewat: hanya terpental & bintang-bintang.
  void _bonkGhosts(Offset pos, double dir) {
    if (ghosts.isEmpty) return;
    final now = sceneNowMs();
    for (final g in ghosts) {
      if (now - g.hitMs < 900) continue;
      final dx = pos.dx - g.x;
      final dy = pos.dy - g.y;
      if (dx * dx + dy * dy < 30 * 30) {
        g.hitMs = now;
        g.vx = (dx >= 0 ? -150.0 : 150.0) + dir * 40;
        g.vy = -80;
      }
    }
  }

  /// Kantong/karung menghantam tanah: gepeng, debu, gelombang kejut, serpihan.
  void _paintBagImpact(Canvas canvas, KostPainter painter, Offset at, double iq,
      double fxs, int seed, bool sack) {
    final sz = sack ? 1.7 : 1.0;
    final ground = at.translate(0, 3 * fxs);

    // kantong gepeng sesaat lalu pecah jadi serpihan
    if (iq < 0.24) {
      final s = iq / 0.24;
      final m = 1 - s * s;
      canvas.save();
      canvas.translate(at.dx, at.dy + 2 * fxs);
      canvas.scale((1.3 + 0.2 * s) * m, (0.62 - 0.2 * s) * m);
      painter._bag(canvas, Offset.zero, 500, scale: (sack ? 2.2 : 1.15) * fxs);
      canvas.restore();
    }
    if (iq < 0.2) {
      _glow(canvas, ground, 30 * sz * fxs, const Color(0xFFFFE0B2),
          0.45 * (1 - iq / 0.2));
    }
    _dust(canvas, ground, iq, fxs, seed, size: sz);
    _ring(canvas, ground, iq, (sack ? 46.0 : 26.0) * fxs,
        const Color(0xFFE0D8C8), sack ? 3 : 2, 0.6);
    _scraps(canvas, at, iq, fxs, seed, sack ? 9 : 5, sack ? 1.5 : 1.0);

    // sekarung sampah: bau menguap
    if (sack && iq > 0.25) {
      final s = (iq - 0.25) / 0.75;
      for (var k = 0; k < 3; k++) {
        final bx = at.dx + (k - 1) * 11 * fxs;
        final path = Path()..moveTo(bx, at.dy - 4 * fxs);
        for (var m = 1; m <= 8; m++) {
          final u = m / 8 * s;
          path.lineTo(
            bx + math.sin(u * 9 + k * 2 + iq * 6) * 4 * fxs,
            at.dy - 4 * fxs - u * 34 * fxs,
          );
        }
        canvas.drawPath(
          path,
          _pn(const Color(0xFF9CCC65).withValues(alpha: 0.5 * (1 - s)),
              style: PaintingStyle.stroke, w: 1.6 * fxs),
        );
      }
    }
  }

  /// Kilatan perisai biru saat sampah menumbuk penangkis.
  void _parryFlash(
      Canvas canvas, Offset at, double q, double fxs, double power) {
    if (q <= 0 || q >= 1) return;
    const cy = Color(0xFF40C4FF);
    _glow(canvas, at, 36 * fxs * power * (0.6 + 0.4 * _eo3(q)), cy,
        0.7 * (1 - q));
    _ring(canvas, at, q, 30 * fxs * power, cy, 3, 0.9, flat: 1.0);
    for (var i = 0; i < 8; i++) {
      final ang = i * math.pi / 4 + 0.2;
      final d0 = (10 + 22 * _eo3(q)) * fxs * power;
      final d1 = d0 + 7 * (1 - q) * fxs;
      canvas.drawLine(
        at + Offset(math.cos(ang), math.sin(ang)) * d0,
        at + Offset(math.cos(ang), math.sin(ang)) * d1,
        _pn(Colors.white.withValues(alpha: 1 - q),
            style: PaintingStyle.stroke, w: 2 * fxs, add: true),
      );
    }
  }

  // --------------------------------------------------------- gas racun

  void _paintGasPuff(Canvas canvas, Offset pos, double lq, int j, double fxs,
      bool back, int seed) {
    final base = back ? const Color(0xFF40C4FF) : const Color(0xFF8BC34A);
    const dark = Color(0xFF2E3B1F);
    final r = 9.0 * fxs;
    _glow(canvas, pos, r * 2.4, base, 0.5);
    for (var k = 0; k < 6; k++) {
      final ang = lq * 7 + j * 1.3 + k * 1.2566;
      final rad = (0.55 + 0.25 * math.sin(lq * 12 + k)) * r;
      final off = Offset(math.cos(ang) * r * 0.55, math.sin(ang) * r * 0.45);
      canvas.drawCircle(pos + off, rad,
          _pn((k.isEven ? dark : base).withValues(alpha: 0.6)));
    }
    canvas.drawCircle(pos, r * 0.55, _pn(dark.withValues(alpha: 0.85)));
    canvas.drawCircle(pos.translate(-r * 0.15, -r * 0.2), r * 0.28,
        _pn(Colors.white.withValues(alpha: 0.3)));
    // gelembung beracun naik
    for (var m = 0; m < 3; m++) {
      final rr = _rn(seed + m * 9);
      final phase = (lq * 3 + rr) % 1.0;
      canvas.drawCircle(
        pos + Offset((rr - 0.5) * r * 2.2, -phase * r * 2.4),
        (1.6 + 1.4 * rr) * fxs,
        _pn(Colors.white.withValues(alpha: 0.6 * (1 - phase)),
            style: PaintingStyle.stroke, w: 1.0 * fxs),
      );
    }
  }

  void _paintGasCloud(Canvas canvas, Offset at, double q, double fxs,
      bool back, int seed) {
    final c = back ? const Color(0xFF40C4FF) : const Color(0xFF7CB342);
    const dark = Color(0xFF33411F);
    final fade = q < 0.15 ? q / 0.15 : (1 - q) / 0.85;
    final e = _eo3(q);
    if (q < 0.18) {
      _glow(canvas, at.translate(0, -6 * fxs), 40 * fxs * (0.5 + q * 3), c,
          0.6 * (1 - q / 0.18));
    }
    // genangan gas di tanah
    canvas.drawOval(
      Rect.fromCenter(
          center: at.translate(0, 3 * fxs),
          width: 90 * fxs * e,
          height: 14 * fxs * e),
      _pn(c.withValues(alpha: 0.22 * fade)),
    );
    for (var k = 0; k < 9; k++) {
      final r = _rn(seed + k * 19);
      final swirl = q * (1.4 + r) * (k.isEven ? 1 : -1) + k;
      final spread = (10 + 24 * r) * e * fxs;
      final ox = math.cos(swirl) * spread;
      final oy = -(4 + 26 * r) * e * fxs + math.sin(swirl) * 4 * fxs - q * 14 * fxs;
      final rad = (11 + 16 * r + q * 16) * fxs;
      final col = k % 3 == 0 ? dark : c;
      canvas.drawCircle(
          at + Offset(ox, oy), rad, _pn(col.withValues(alpha: 0.42 * fade)));
      canvas.drawCircle(
        at + Offset(ox - rad * 0.25, oy - rad * 0.3),
        rad * 0.55,
        _pn(const Color(0xFFDCEDC8).withValues(alpha: 0.12 * fade)),
      );
    }
    // spora / gelembung yang naik
    for (var m = 0; m < 7; m++) {
      final r = _rn(seed + m * 23 + 5);
      final px = at.dx + (r - 0.5) * 70 * fxs * e;
      final py = at.dy - (q * (30 + 40 * r) + 6) * fxs;
      canvas.drawCircle(
        Offset(px, py),
        (1.4 + 1.8 * r) * fxs,
        _pn(Colors.white.withValues(alpha: 0.6 * fade),
            style: PaintingStyle.stroke, w: 1.0 * fxs),
      );
    }
  }

  // ------------------------------------------------------- kembang api

  static const List<List<Color>> _fwPalettes = [
    [Color(0xFFFFD54F), Color(0xFFFF8F00), Color(0xFFFFF8E1)],
    [Color(0xFFFF5252), Color(0xFFFF8A80), Color(0xFFFFD54F)],
    [Color(0xFF69F0AE), Color(0xFF00E5FF), Color(0xFFFFFFFF)],
    [Color(0xFFE040FB), Color(0xFF40C4FF), Color(0xFFFFFFFF)],
  ];

  /// Ledakan kembang api sungguhan (percikan terjadi): kilat, garis bunga api
  /// berekor yang melengkung jatuh, kerlip, bara, dan asap.
  void _paintBurst(Canvas canvas, Offset at, double q, double fxs, int seed) {
    if (q <= 0 || q >= 1) return;
    final pal = _fwPalettes[seed % _fwPalettes.length];
    final ctr = at.translate(0, -24 * fxs);

    if (q < 0.14) {
      _glow(canvas, ctr, 46 * fxs * (0.4 + q * 5), const Color(0xFFFFF3C4),
          1 - q / 0.14);
    }
    _glow(canvas, ctr, 34 * fxs, pal[0], 0.45 * (1 - q));

    const n = 18;
    final fade = _c01((1 - q) * 1.25);
    for (var i = 0; i < n; i++) {
      final r1 = _rn(seed + i * 5 + 1);
      final r2 = _rn(seed + i * 9 + 2);
      final ang = i * math.pi * 2 / n + r1 * 0.35;
      final v = 46 + 26 * r2;
      Offset posAt(double qq) {
        final e = _eo3(qq * 1.15);
        return ctr +
            Offset(math.cos(ang) * v * e * fxs,
                (math.sin(ang) * v * e + 60 * qq * qq) * fxs);
      }

      final col = pal[i % pal.length];
      final head = posAt(q);
      final tail = posAt(math.max(0.0, q - 0.12));
      canvas.drawLine(
        tail,
        head,
        _pn(col.withValues(alpha: fade),
            style: PaintingStyle.stroke,
            w: 2.8 * (1 - q * 0.7) * fxs,
            add: true),
      );
      canvas.drawCircle(head, (1.8 * (1 - q) + 0.6) * fxs,
          _pn(Colors.white.withValues(alpha: fade), add: true));
      // kerlip di ujung bunga api
      if (q > 0.35 && math.sin(q * 46 + i * 2.3) > 0.55) {
        canvas.save();
        canvas.translate(head.dx + (r1 - 0.5) * 5 * fxs, head.dy + 4 * fxs);
        canvas.drawPath(_starPath(2.6 * fxs, 4, 0.3),
            _pn(col.withValues(alpha: fade), add: true));
        canvas.restore();
      }
    }

    // bara berjatuhan
    for (var i = 0; i < 7; i++) {
      final r1 = _rn(seed + i * 41 + 7);
      final r2 = _rn(seed + i * 43 + 9);
      final ang = -math.pi * (0.1 + 0.8 * r1);
      final sp = 26 + 24 * r2;
      final x = math.cos(ang) * sp * q;
      var y = math.sin(ang) * sp * q + 110 * q * q;
      final maxY = (at.dy + 2 * fxs - ctr.dy) / fxs;
      if (y > maxY) y = maxY;
      final p = ctr + Offset(x * fxs, y * fxs);
      _glow(canvas, p, 5 * fxs, const Color(0xFFFF9100), 0.7 * (1 - q));
      canvas.drawCircle(p, 1.5 * fxs,
          _pn(const Color(0xFFFFD180).withValues(alpha: 1 - q)));
    }

    // asap tipis
    for (var k = 0; k < 3; k++) {
      final s = _c01((q - 0.18 - k * 0.08) / 0.7);
      if (s <= 0) continue;
      canvas.drawCircle(
        ctr +
            Offset((k - 1) * 8 * fxs + math.sin(s * 5 + k) * 4 * fxs,
                -s * 30 * fxs),
        (7 + 10 * s) * fxs,
        _pn(const Color(0xFF546E7A).withValues(alpha: 0.28 * (1 - s))),
      );
    }
  }

  void _flame(Canvas canvas, double fx, double baseY, double w, double h,
      double sway, Color col) {
    final path = Path()
      ..moveTo(fx - w, baseY)
      ..quadraticBezierTo(fx - w * 0.9, baseY - h * 0.5, fx + sway, baseY - h)
      ..quadraticBezierTo(fx + w * 0.9, baseY - h * 0.5, fx + w, baseY)
      ..close();
    canvas.drawPath(path, _pn(col));
  }

  /// Percikan membakar tumpukan sampah: lidah api & jelaga (hanya bila spark).
  void _paintFireKiss(
      Canvas canvas, Offset at, double q, double fxs, int seed) {
    final s = _c01((q - 0.08) / 0.8);
    if (s <= 0 || s >= 1) return;
    final env = math.sin(s * math.pi);
    _glow(canvas, at.translate(0, -8 * fxs), 30 * fxs * env,
        const Color(0xFFFF9100), 0.5);
    for (var i = 0; i < 3; i++) {
      final fx = at.dx + (i - 1) * 9 * fxs;
      final flick = 0.85 + 0.15 * math.sin(q * 60 + i * 2);
      final h = (16 + 8 * _rn(seed + i)) * env * fxs * flick;
      final w = 6.5 * fxs * env;
      final sway = math.sin(q * 40 + i) * 2 * fxs;
      _flame(canvas, fx, at.dy + 2 * fxs, w, h, sway,
          const Color(0xFFFF6D00).withValues(alpha: 0.85 * env));
      _flame(canvas, fx, at.dy + 2 * fxs, w * 0.5, h * 0.6, sway * 0.6,
          const Color(0xFFFFD740).withValues(alpha: 0.9 * env));
    }
    // jelaga naik
    for (var k = 0; k < 2; k++) {
      final u = _c01((s - k * 0.15) / 0.85);
      canvas.drawCircle(
        at + Offset((k - 0.5) * 12 * fxs + math.sin(u * 4 + k) * 3 * fxs,
            -10 * fxs - u * 28 * fxs),
        (5 + 8 * u) * fxs,
        _pn(const Color(0xFF263238).withValues(alpha: 0.35 * (1 - u))),
      );
    }
  }

  /// Kembang api zonk (gertakan): "pfft" kecil, beberapa percik loyo, asap.
  void _paintDud(Canvas canvas, Offset at, double q, double fxs, int seed) {
    if (q <= 0 || q >= 1) return;
    final ctr = at.translate(0, -8 * fxs);
    if (q < 0.15) {
      _glow(canvas, ctr, 14 * fxs, const Color(0xFFFFE082), 0.7 * (1 - q / 0.15));
    }
    for (var i = 0; i < 7; i++) {
      final r1 = _rn(seed + i * 5 + 1);
      final r2 = _rn(seed + i * 9 + 2);
      final ang = -math.pi * (0.1 + 0.8 * r1);
      final v = 18 + 10 * r2;
      Offset posAt(double qq) =>
          ctr +
              Offset(math.cos(ang) * v * _eo3(qq) * fxs,
                  (math.sin(ang) * v * _eo3(qq) + 70 * qq * qq) * fxs);
      final head = posAt(q);
      final tail = posAt(math.max(0.0, q - 0.1));
      final a = math.pow(1 - q, 1.5).toDouble();
      canvas.drawLine(
        tail,
        head,
        _pn((i.isEven ? const Color(0xFFFFD54F) : const Color(0xFFFFFFFF))
            .withValues(alpha: a),
            style: PaintingStyle.stroke,
            w: 1.8 * fxs,
            add: true),
      );
    }
    for (var k = 0; k < 3; k++) {
      final s = _c01((q - k * 0.1) / 0.8);
      if (s <= 0) continue;
      canvas.drawCircle(
        ctr + Offset((k - 1) * 6 * fxs, -s * 16 * fxs),
        (5 + 8 * s) * fxs,
        _pn(const Color(0xFF90A4AE).withValues(alpha: 0.3 * (1 - s))),
      );
    }
    _scraps(canvas, at, q, fxs, seed, 4, 0.6);
  }

  /// Kembang api ditangkis: bunga api mati menabrak perisai, uap mengepul.
  void _paintFizzle(Canvas canvas, Offset at, double q, double fxs, int seed) {
    if (q <= 0 || q >= 1) return;
    const cy = Color(0xFF40C4FF);
    _glow(canvas, at, 22 * fxs, cy, 0.55 * (1 - q));
    _ring(canvas, at, q, 20 * fxs, cy, 2, 0.8, flat: 1.0);
    for (var i = 0; i < 8; i++) {
      final ang = i * math.pi / 4 + _rn(seed + i) * 0.4;
      final d0 = (6 + 16 * _eo3(q)) * fxs;
      canvas.drawLine(
        at + Offset(math.cos(ang), math.sin(ang)) * d0,
        at + Offset(math.cos(ang), math.sin(ang)) * (d0 + 5 * (1 - q) * fxs),
        _pn((i.isEven ? const Color(0xFFFFD54F) : cy)
            .withValues(alpha: 1 - q),
            style: PaintingStyle.stroke,
            w: 1.8 * fxs,
            add: true),
      );
    }
    for (var k = 0; k < 3; k++) {
      final s = _c01((q - 0.1 - k * 0.1) / 0.7);
      if (s <= 0) continue;
      canvas.drawCircle(
        at + Offset((k - 1) * 6 * fxs, -s * 14 * fxs),
        (5 + 9 * s) * fxs,
        _pn(const Color(0xFFB0BEC5).withValues(alpha: 0.35 * (1 - s))),
      );
    }
  }

  // -------------------------------------------------------------- hantu

  TextPainter _ghostText(String text, double size, Color color,
      {bool bold = true}) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  /// Badan hantu: kubah kepala halus + tepi bawah bergelombang yang mengalir.
  Path _ghostBody(double t, double ph, double sp) {
    final path = Path()..moveTo(-16, 6);
    path.cubicTo(-17, -12, -10, -25, 0, -25);
    path.cubicTo(10, -25, 17, -12, 16, 6);
    path.cubicTo(16.5, 12, 16, 16, 15, 19);
    const n = 28;
    for (var i = 1; i <= n; i++) {
      final u = i / n;
      final x = 15 - 30 * u;
      final wave = math.sin(u * math.pi * 6 + t * 5.0 + ph);
      final y = 19 + 4.2 * wave * (0.55 + 0.45 * math.sin(u * math.pi)) + sp * 3;
      path.lineTo(x, y);
    }
    path.cubicTo(-16, 16, -16.5, 12, -16, 6);
    path.close();
    return path;
  }

  /// Arwah melayang di atas jalan: badan transparan bergradasi, ekor
  /// mengalir, lengan melambai, mata berkedip, bisa terpentok sampah
  /// (bintang-bintang) dan menyeru lewat emoji.
  void _paintGhosts(Canvas canvas, double fxScale, double t) {
    final now = sceneNowMs();
    final gs = math.min(fxScale, 1.8);
    for (final g in ghosts) {
      final ph = (g.id.hashCode & 0xff) * 0.07;
      final ap = _c01((now - g.bornMs) / 800.0);
      if (ap <= 0) continue;
      final apS = _easeOutBack(ap);
      final bob = (math.sin(t * 2.2 + ph) * 5 + math.sin(t * 1.3 + ph * 2) * 1.6) * gs;
      final hitAge = (now - g.hitMs) / 1000.0;
      final hit = hitAge >= 0 && hitAge < 0.9;
      final hk = hit ? 1 - hitAge / 0.9 : 0.0;
      final squash = hit ? 1 + 0.28 * math.sin(hitAge * 20) * hk : 1.0;
      final ddx = g.tx - g.x;
      final ddy = g.ty - g.y;
      final sp = math.min(1.0, math.sqrt(ddx * ddx + ddy * ddy) / 90);
      final c = Offset(g.x, g.y + bob);
      final tintC = Color.lerp(Colors.white, g.color, 0.55)!;
      final ea = now - g.emojiMs;
      final calling = g.emojiCode > 0 && ea >= 0 && ea < kEmojiLifeMs;

      // jejak samar saat bergerak
      for (var i = 0; i < g.trail.length; i++) {
        final k = (i + 1) / (g.trail.length + 1);
        final p = g.trail[i];
        canvas.drawCircle(
          Offset(p.dx, p.dy + bob),
          12 * gs * k,
          _pn(tintC.withValues(alpha: 0.13 * k * ap)),
        );
      }

      // aura
      _glow(canvas, c.translate(0, -2 * gs),
          36 * gs * (0.92 + 0.08 * math.sin(t * 3 + ph)), tintC, 0.3 * ap);

      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(g.lean + math.sin(t * 1.6 + ph) * 0.04);
      canvas.scale(gs * apS / squash, gs * apS * squash * (1 + 0.05 * sp));

      // lengan kecil yang melambai (di belakang badan)
      for (final side in const [-1.0, 1.0]) {
        final flap = 0.95 +
            0.35 * math.sin(t * 3.2 + ph + (side > 0 ? 1.4 : 0)) +
            (calling ? 0.5 * math.sin(t * 14) : 0) -
            g.lean * 0.6;
        canvas.save();
        canvas.translate(side * 14.5, 2);
        canvas.rotate(side * flap);
        final arm = Rect.fromCenter(center: const Offset(0, 5), width: 6.5, height: 13);
        canvas.drawOval(arm, _pn(tintC.withValues(alpha: 0.78 * ap)));
        canvas.drawOval(
            arm,
            _pn(Colors.white.withValues(alpha: 0.7 * ap),
                style: PaintingStyle.stroke, w: 1.0));
        canvas.restore();
      }

      // badan: gradasi putih -> warna pemain
      final body = _ghostBody(t, ph, sp);
      final fillA = (hit ? 0.97 : 0.84) * ap;
      final top = Color.lerp(Colors.white, g.color, 0.1)!;
      final bot = Color.lerp(Colors.white, g.color, 0.55)!;
      final shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          top.withValues(alpha: fillA),
          bot.withValues(alpha: fillA * 0.6),
        ],
      ).createShader(const Rect.fromLTRB(-17, -25, 17, 24));
      canvas.drawPath(body, _pn(Colors.white)..shader = shader);
      if (hit) {
        canvas.drawPath(
            body, _pn(Colors.white.withValues(alpha: 0.55 * hk), add: true));
      }
      // tepi bercahaya
      canvas.drawPath(
          body,
          _pn(Colors.white.withValues(alpha: 0.2 * ap),
              style: PaintingStyle.stroke, w: 4.2, add: true));
      canvas.drawPath(
          body,
          _pn(Colors.white.withValues(alpha: 0.92 * ap),
              style: PaintingStyle.stroke, w: 1.4));

      // kilau di kepala
      canvas.save();
      canvas.translate(-6, -15);
      canvas.rotate(-0.5);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 11, height: 6.5),
          _pn(Colors.white.withValues(alpha: 0.4 * ap)));
      canvas.restore();

      // pipi merona
      for (final side in const [-1.0, 1.0]) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(side * 9.5, 4.5), width: 6.5, height: 3.6),
          _pn(const Color(0xFFFF8A80).withValues(alpha: 0.38 * ap)),
        );
      }

      // wajah
      const ink = Color(0xFF263238);
      final lx = g.look * 1.8;
      if (hit) {
        // mata ">  <" & mulut menganga
        final eyeP = _pn(ink.withValues(alpha: ap),
            style: PaintingStyle.stroke, w: 1.7);
        final l = Path()
          ..moveTo(-8.5, -7)
          ..lineTo(-3.5, -3.5)
          ..lineTo(-8.5, -0.5);
        canvas.drawPath(l, eyeP);
        final r = Path()
          ..moveTo(8.5, -7)
          ..lineTo(3.5, -3.5)
          ..lineTo(8.5, -0.5);
        canvas.drawPath(r, _pn(ink.withValues(alpha: ap),
            style: PaintingStyle.stroke, w: 1.7));
        canvas.drawOval(
            Rect.fromCenter(center: const Offset(0, 6.5), width: 6.5, height: 8),
            _pn(ink.withValues(alpha: ap)));
        canvas.drawOval(
            Rect.fromCenter(center: const Offset(0, 8.2), width: 3.6, height: 3),
            _pn(const Color(0xFFFF8A80).withValues(alpha: ap)));
      } else {
        final cyc = (t + ph * 1.7) % 3.6;
        final bl = cyc > 3.42 ? math.sin((cyc - 3.42) / 0.18 * math.pi).abs() : 0.0;
        final eh = 8.0 * (1 - 0.9 * bl);
        for (final side in const [-1.0, 1.0]) {
          final ec = Offset(side * 5.6 + lx, -3.5);
          canvas.drawOval(Rect.fromCenter(center: ec, width: 5.6, height: eh),
              _pn(ink.withValues(alpha: ap)));
          if (bl < 0.5) {
            canvas.drawCircle(ec.translate(1.0, -1.7), 1.25,
                _pn(Colors.white.withValues(alpha: 0.95 * ap)));
            canvas.drawCircle(ec.translate(-0.9, 1.5), 0.65,
                _pn(Colors.white.withValues(alpha: 0.7 * ap)));
          }
        }
        if (calling) {
          // mulut terbuka riang
          final m = Rect.fromCenter(center: Offset(lx, 5.5), width: 7, height: 6);
          canvas.drawArc(m, 0, math.pi, true, _pn(ink.withValues(alpha: ap)));
          canvas.drawArc(
              Rect.fromCenter(center: Offset(lx, 7.4), width: 3.6, height: 3),
              0,
              math.pi,
              true,
              _pn(const Color(0xFFFF8A80).withValues(alpha: ap)));
        } else {
          canvas.drawArc(
            Rect.fromCenter(center: Offset(lx, 3.8), width: 7, height: 5),
            0.25,
            math.pi - 0.5,
            false,
            _pn(ink.withValues(alpha: ap),
                style: PaintingStyle.stroke, w: 1.4),
          );
        }
      }
      canvas.restore();

      // gelombang kejut + bintang pusing saat terpukul
      if (hit) {
        if (hitAge < 0.35) {
          _ring(canvas, c, hitAge / 0.35, 30 * gs, Colors.white, 2, 0.7,
              flat: 1.0);
        }
        for (var i = 0; i < 3; i++) {
          final ang = hitAge * 9 + i * 2.094;
          final p = c + Offset(math.cos(ang) * 17, -34 + math.sin(ang) * 5) * gs;
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(ang * 2);
          final star = _starPath((3.8 + (math.sin(ang) > 0 ? 1.0 : 0.0)) * gs, 5, 0.45);
          canvas.drawPath(
              star, _pn(const Color(0xFFFFD54F).withValues(alpha: _c01(hk * 1.6))));
          canvas.drawPath(
              star,
              _pn(Colors.white.withValues(alpha: _c01(hk * 1.6)),
                  style: PaintingStyle.stroke, w: 0.8));
          canvas.restore();
        }
      }

      // kerlip yang mengorbit
      for (var i = 0; i < 3; i++) {
        final ang = t * 1.3 + ph + i * 2.094;
        final p = c + Offset(math.cos(ang) * 24, math.sin(ang) * 18 - 4) * gs;
        final tw = 0.5 + 0.5 * math.sin(t * 5 + i * 2 + ph);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.drawPath(_starPath((2.2 + 1.8 * tw) * gs, 4, 0.28),
            _pn(tintC.withValues(alpha: 0.75 * tw * ap), add: true));
        canvas.restore();
      }

      // papan nama (pil)
      final name = _ghostText('👻 ${g.name}', 10 * gs,
          Colors.white.withValues(alpha: ap));
      final pill = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy + 36 * gs),
          width: name.width + 12 * gs,
          height: name.height + 4 * gs,
        ),
        Radius.circular((name.height + 4 * gs) / 2),
      );
      canvas.drawRRect(pill, _pn(Colors.black.withValues(alpha: 0.42 * ap)));
      canvas.drawRRect(
          pill,
          _pn(g.color.withValues(alpha: 0.85 * ap),
              style: PaintingStyle.stroke, w: 1.2 * gs));
      name.paint(canvas, Offset(c.dx - name.width / 2, c.dy + 36 * gs - name.height / 2));

      // seruan emoji arwah (gelembung pikiran yang membal)
      if (calling) {
        final ep = ea / kEmojiLifeMs;
        final alpha = ep > 0.8 ? (1 - ep) / 0.2 : 1.0;
        final pop = _easeOutBack(ep / 0.14);
        final sway = math.sin(ep * 9) * 4;
        final ctr = c + Offset(sway, -52 * gs - ep * 10);
        canvas.drawCircle(c + Offset(sway * 0.3 + 6 * gs, -36 * gs - ep * 3),
            2.6 * gs * pop,
            _pn(Colors.white.withValues(alpha: 0.9 * alpha)));
        canvas.drawCircle(c + Offset(sway * 0.6 + 3 * gs, -43 * gs - ep * 6),
            4 * gs * pop,
            _pn(Colors.white.withValues(alpha: 0.92 * alpha)));
        canvas.drawCircle(ctr.translate(0, 2), 17 * gs * pop,
            _pn(Colors.black.withValues(alpha: 0.18 * alpha)));
        canvas.drawCircle(ctr, 17 * gs * pop,
            _pn(Colors.white.withValues(alpha: 0.97 * alpha)));
        canvas.drawCircle(
            ctr,
            17 * gs * pop,
            _pn(const Color(0xFFFFCA28).withValues(alpha: alpha),
                style: PaintingStyle.stroke, w: 2));
        final tp = _ghostText(emojiFromCode(g.emojiCode), 20 * gs * pop,
            Colors.white.withValues(alpha: alpha));
        tp.paint(canvas, ctr - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant KostStreetPainter oldDelegate) => true;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || houses.isEmpty) return;
    final t = sceneNowMs() / 1000.0;

    final stage = camera.stageFor(size, insets);
    final s = camera.scale;
    final o = camera.origin(stage);
    final vl = -o.dx / s - 24;
    final vr = (size.width - o.dx) / s + 24;
    final vt = -o.dy / s - 24;
    final vb = (size.height - o.dy) / s + 24;
    final view = Rect.fromLTRB(vl, vt, vr, vb);
    final worldW = houses.length * _w;
    final fxScale = math.max(1.0, 0.8 / s);
    // Saat kamera jauh, detail halus dimatikan agar tetap ringan.
    final compact = s < 0.42;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(o.dx, o.dy);
    canvas.scale(s);

    // 1) latar bersama: langit, bukit, pohon, tanah, mobil
    KostPainter(backdrop, _repaint).paintStreetBackdrop(
      canvas,
      view,
      t,
      worldW: worldW,
      fxScale: fxScale,
    );

    // 2) rumah-rumah berderet
    final painters = <int, KostPainter>{};
    for (var i = 0; i < houses.length; i++) {
      final x0 = i * _w;
      if (x0 + _w + 140 < vl || x0 - 140 > vr) continue; // di luar layar
      final kp = KostPainter(houses[i].withView(compact: compact), _repaint);
      painters[i] = kp;
      canvas.save();
      canvas.translate(x0, 0);
      kp.paintStreetHouse(canvas, Rect.fromLTRB(0, vt, _w, vb), t);
      canvas.restore();
    }

    // 2a) truk sampah & adegan pembajakan: lapisan dunia (di atas semua rumah)
    // supaya truk melintasi batas rumah dan masuk/keluar dari luar layar.
    for (var i = 0; i < houses.length; i++) {
      final hd = houses[i];
      final hauling = hd.haulProgress != null;
      // Truk khusus gudang juga digambar lewat lapisan ini (_whTruckLayer di
      // dalam _truckLayer), jadi rumah dengan truk gudang aktif tidak boleh
      // dilewati walau truk angkut biasa sedang tidak jalan.
      final whTruck = hd.warehouse?.truckProgress != null;
      final hjVictim = hd.fx.any((f) =>
      f.type == FxType.hijack && f.amount.round() != 1 && f.age >= 0);
      if (!hauling && !hjVictim && !whTruck) continue;
      final x0 = i * _w;
      final kp =
          painters[i] ?? KostPainter(hd.withView(compact: compact), _repaint);
      double? thiefDx;
      var thiefHauling = false;
      final peer = kp.activeHijackThief();
      if (peer != null) {
        final ti = ids.indexOf(peer);
        if (ti >= 0 && ti != i) {
          thiefDx = (ti - i) * _w;
          thiefHauling = houses[ti].haulProgress != null;
        }
      }
      canvas.save();
      canvas.translate(x0, 0);
      kp.paintStreetTruck(
        canvas,
        t,
        Rect.fromLTRB(vl - x0, vt, vr - x0, vb),
        thiefDx: thiefDx,
        thiefHauling: thiefHauling,
      );
      canvas.restore();
    }

    // 2b) lemparan sampah terbang antar rumah (koordinat dunia)
    _paintShots(
      canvas,
      fxScale,
      KostPainter(
        const KostSceneData(
            rooms: 0, maxRooms: 12, defense: 0, trashRatio: 0, pollution: 0),
        _repaint,
      ),
    );

    // 2b2) arwah pemain yang tertimbun melayang di atas jalan
    _paintGhosts(canvas, fxScale, t);

    // 3) hujan / abu / kabut / vinyet, sekali untuk seluruh layar
    KostPainter(backdrop, _repaint).paintStreetAtmosphere(
      canvas,
      view,
      t,
      worldW: worldW,
      fxScale: fxScale,
    );

    // 4) emoji, sorotan & bingkai peringatan tiap rumah
    for (final e in painters.entries) {
      canvas.save();
      canvas.translate(e.key * _w, 0);
      e.value.paintStreetOverlay(canvas, Rect.fromLTRB(0, vt, _w, vb), t);
      canvas.restore();
    }

    canvas.restore();
  }
}