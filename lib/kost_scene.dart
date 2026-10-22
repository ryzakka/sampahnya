import 'dart:math' as math;

import 'package:flutter/material.dart';

// ====================================================================
//  Adegan visual kost (v5 - Smart Trash Overflow & Animated Emoji)
// ====================================================================

final Stopwatch _clock = Stopwatch()..start();

int sceneNowMs() => _clock.elapsedMilliseconds;

enum FxType {
  build,
  burn,
  defense,
  waste,
  tier,
  incoming,
  outgoing,
  inspect,
  hijack,
  collapse,
  emoji,
  parry,
}

const List<String> kEmojiList = [
  '😂', // 1: Ngakak
  '😎', // 2: Santuy / Sultan
  '🔥', // 3: Panas / Bakar
  '😭', // 4: Nangis / Tertimbun
  '😡', // 5: Marah / Diserang
  '🤢', // 6: Bau Sampah
  '😱', // 7: Panik
  '👏', // 8: Tepuk Tangan / GG
];

String emojiFromCode(int code) {
  final idx = (code - 1).clamp(0, kEmojiList.length - 1);
  return kEmojiList[idx];
}

class KostFx {
  /// [delayMs] > 0 menunda efek (age negatif = belum tampil). Dipakai agar
  /// dampak lemparan baru terasa setelah sampah benar-benar mendarat.
  KostFx(this.type, {this.amount = 0, this.peerId, int delayMs = 0})
      : startMs = sceneNowMs() + delayMs;

  final FxType type;
  final int startMs;
  final double amount;

  /// Lawan yang terlibat (penyerang / sasaran). Dipakai mode jalan untuk
  /// menentukan arah lemparan sampah antar rumah bertetangga.
  final String? peerId;

  int get age => sceneNowMs() - startMs;
}

/// Lemparan sampah yang sedang terbang antar rumah (koordinat dunia jalan).
/// Dibuat HANYA setelah jendela Tangkis selesai (tak ditangkis) atau saat
/// ditangkis (pantulan kembali ke pelempar).
class KostShot {
  KostShot({
    required this.fromId,
    required this.toId,
    required this.durMs,
    this.bounce = false,
    this.bags = 4,
  }) : startMs = sceneNowMs();

  /// Rumah pelempar & rumah tujuan.
  final String fromId;
  final String toId;
  final int startMs;

  /// Total durasi (ms). Bila [bounce], paruh pertama = terbang ke perisai
  /// penangkis, paruh kedua = dipantulkan balik ke pelempar.
  final int durMs;
  final bool bounce;
  final int bags;

  int get age => sceneNowMs() - startMs;
}

class KostSceneData {
  const KostSceneData({
    required this.rooms,
    required this.maxRooms,
    required this.defense,
    required this.trashRatio,
    required this.pollution,
    this.wasteLevel = 0,
    this.kostTier = 0,
    this.worldEvent,
    this.sealedLeft = 0,
    this.eliminated = false,
    this.protectedLeft = 0,
    this.haulProgress,
    this.burnPenalty = false,
    this.smog = false,
    this.fx = const <KostFx>[],
    this.wall = const Color(0xFFF0DFB8),
    this.compact = false,
    this.facingRight = true,
    this.isBounty = false,
    this.attackLeft = 0,
    this.seed = 0,
    this.charge = 0,
    this.chargeLeft = 0,
    this.lights = 1.0,
    this.policeAgeMs,
    this.buriedAgeMs,
  });

  final int rooms;
  final int maxRooms;
  final int defense; // 0..3
  final int wasteLevel; // 0..12
  final int kostTier; // 0..2
  final String? worldEvent;
  final double sealedLeft;
  final double trashRatio; // 0..1
  final double pollution; // 0..100
  final bool eliminated;
  final double protectedLeft;
  final double? haulProgress;
  final bool burnPenalty;
  final bool smog;
  final List<KostFx> fx;
  final Color wall;
  final bool compact;
  final bool facingRight;
  final bool isBounty; // "Juragan Teladan": target buruan bernilai bonus
  final double attackLeft; // detik tersisa jendela Tangkis (0 = tidak ada)
  final int seed; // 0..999, pembeda ritme penghuni antar rumah

  /// Rumah ini sedang MENYIAPKAN serangan (menunggu korban Tangkis):
  /// 0 = tidak, 1 = lempar sampah, 2 = sidak dinas.
  final int charge;

  /// Sisa detik jendela Tangkis saat [charge] > 0 (untuk animasi bersiap).
  final double chargeLeft;

  /// Batas terang jendela 0..1 (1 = normal, 0 = semua gelap). Dipakai lobi:
  /// jendela menyala saat pemain menekan SIAP.
  final double lights;

  /// Umur (ms) animasi sidak polisi di rumah ini; null = tidak sedang diputar.
  final int? policeAgeMs;

  /// Umur (ms) adegan "tertimbun" di rumah ini; null = tidak sedang diputar.
  final int? buriedAgeMs;

  /// Salinan dengan sebagian nilai diganti (dipakai sutradara sinematik).
  KostSceneData copyWith({
    double? trashRatio,
    double? pollution,
    bool? eliminated,
    double? lights,
    double? sealedLeft,
    bool? smog,
    bool clearWorldEvent = false,
    int? policeAgeMs,
    int? buriedAgeMs,
  }) =>
      KostSceneData(
        rooms: rooms,
        maxRooms: maxRooms,
        defense: defense,
        trashRatio: trashRatio ?? this.trashRatio,
        pollution: pollution ?? this.pollution,
        wasteLevel: wasteLevel,
        kostTier: kostTier,
        worldEvent: clearWorldEvent ? null : worldEvent,
        sealedLeft: sealedLeft ?? this.sealedLeft,
        eliminated: eliminated ?? this.eliminated,
        protectedLeft: protectedLeft,
        haulProgress: haulProgress,
        burnPenalty: burnPenalty,
        smog: smog ?? this.smog,
        fx: fx,
        wall: wall,
        compact: compact,
        facingRight: facingRight,
        isBounty: isBounty,
        attackLeft: attackLeft,
        seed: seed,
        charge: charge,
        chargeLeft: chargeLeft,
        lights: lights ?? this.lights,
        policeAgeMs: policeAgeMs ?? this.policeAgeMs,
        buriedAgeMs: buriedAgeMs ?? this.buriedAgeMs,
      );

  /// Salinan dengan [compact] / [facingRight] diganti (dipakai mode jalan).
  KostSceneData withView({bool? compact, bool? facingRight}) => KostSceneData(
    rooms: rooms,
    maxRooms: maxRooms,
    defense: defense,
    trashRatio: trashRatio,
    pollution: pollution,
    wasteLevel: wasteLevel,
    kostTier: kostTier,
    worldEvent: worldEvent,
    sealedLeft: sealedLeft,
    eliminated: eliminated,
    protectedLeft: protectedLeft,
    haulProgress: haulProgress,
    burnPenalty: burnPenalty,
    smog: smog,
    fx: fx,
    wall: wall,
    compact: compact ?? this.compact,
    facingRight: facingRight ?? this.facingRight,
    isBounty: isBounty,
    attackLeft: attackLeft,
    seed: seed,
    charge: charge,
    chargeLeft: chargeLeft,
    lights: lights,
    policeAgeMs: policeAgeMs,
    buriedAgeMs: buriedAgeMs,
  );
}

class KostStage extends StatelessWidget {
  const KostStage({
    super.key,
    required this.data,
    required this.repaint,
    this.insets = EdgeInsets.zero,
  });

  final KostSceneData data;
  final Listenable repaint;
  final EdgeInsets insets;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: KostPainter(data, repaint, insets: insets),
        size: Size.infinite,
      ),
    );
  }
}

class KostScene extends StatelessWidget {
  const KostScene({super.key, required this.data, required this.repaint});

  final KostSceneData data;
  final Listenable repaint;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: KostStage(data: data, repaint: repaint),
      ),
    );
  }
}

class KostBackdrop extends StatefulWidget {
  const KostBackdrop({
    super.key,
    this.insets = EdgeInsets.zero,
    this.rooms = 9,
    this.defense = 2,
    this.pollution = 10,
    this.trashRatio = 0.2,
  });

  final EdgeInsets insets;
  final int rooms;
  final int defense;
  final double pollution;
  final double trashRatio;

  @override
  State<KostBackdrop> createState() => _KostBackdropState();
}

class _KostBackdropState extends State<KostBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KostStage(
      repaint: _c,
      insets: widget.insets,
      data: KostSceneData(
        rooms: widget.rooms,
        maxRooms: 12,
        defense: widget.defense,
        trashRatio: widget.trashRatio,
        pollution: widget.pollution,
        wasteLevel: 7,
        kostTier: 1,
      ),
    );
  }
}


// ---------------------------------------------------- emoji reaksi (widget)

const int kEmojiLifeMs = 3600;

/// Tinggi kotak gelembung emoji (dipakai penata letak agar ruangnya dicadangkan).
const double kEmojiBoxH = 58;

/// Reaksi emoji aktif terbaru milik satu rumah (null bila tidak ada).
KostFx? kostActiveEmoji(List<KostFx>? list) {
  if (list == null) return null;
  KostFx? best;
  for (final f in list) {
    if (f.type != FxType.emoji) continue;
    final a = f.age;
    if (a < 0 || a > kEmojiLifeMs) continue;
    if (best == null || a < best.age) best = f;
  }
  return best;
}

/// Gelembung emoji berukuran tetap (tidak ikut mengecil saat kamera menjauh).
/// Ditaruh di lapisan widget, di atas kartu nama, sehingga tidak tertutup UI.
/// Harus dibangun ulang tiap frame (mis. di dalam AnimatedBuilder).
class KostEmojiBubble extends StatelessWidget {
  const KostEmojiBubble({super.key, required this.fx});

  final KostFx fx;

  @override
  Widget build(BuildContext context) {
    final p = _c01(fx.age / kEmojiLifeMs);
    final pop = p < 0.14
        ? _easeOutBack(p / 0.14)
        : (p > 0.82 ? _c01((1 - p) / 0.18) : 1.0);
    final alpha = p > 0.8 ? _c01((1 - p) / 0.2) : 1.0;
    final sway = math.sin(p * math.pi * 3.5) * 6;
    final rise = -p * 12;
    return SizedBox(
      height: kEmojiBoxH,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Transform.translate(
          offset: Offset(sway, rise),
          child: Opacity(
            opacity: alpha,
            child: Transform.scale(
              scale: pop,
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      shape: BoxShape.circle,
                      border:
                      Border.all(color: const Color(0xFFFFCA28), width: 2.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      emojiFromCode(fx.amount.round()),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  ClipPath(
                    clipper: _TailClipper(),
                    child: Container(
                      width: 12,
                      height: 8,
                      color: Colors.white.withValues(alpha: 0.96),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TailClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width / 2, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ---------------------------------------------------------------- util

const double _w = 400;
const double _h = 300;
const double _gy = 236;
const double _bl = 105;
const double _cw = 47.5;
const double _fh = 50;

// ---- Garis waktu sinematik (ms) - dipakai painter ini DAN cinematics.dart.
// Sidak polisi: mobil masuk -> petugas turun -> pita dipasang -> stempel
// "DISEGEL" -> (bila tidak disegel) petugas pergi.
const int kPoliceDriveMs = 2400;
const int kPoliceTapeStartMs = 3300;
const int kPoliceTapeMs = 3600;
const int kPoliceTapeEndMs = kPoliceTapeStartMs + kPoliceTapeMs; // 6900
const int kPoliceTotalMs = 9000;

// Rumah tertimbun: longsoran sampah -> runtuh -> penghuni sedih + papan DIJUAL.
const int kBuriedCollapseMs = 4600;

const List<Color> _bagColors = [
  Color(0xFF263238),
  Color(0xFF37474F),
  Color(0xFF1B2A22),
  Color(0xFF455A64),
];

const List<Color> _carColors = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFFFDD835),
  Color(0xFF8E24AA),
  Color(0xFFEEEEEE),
];

double _c01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _lerp(double a, double b, double t) => a + (b - a) * t;
double _ease(double x) {
  x = _c01(x);
  return x * x * (3 - 2 * x);
}

double _easeOutBack(double x) {
  x = _c01(x);
  const c1 = 2.1;
  const c3 = c1 + 1;
  final y = x - 1;
  return 1 + c3 * y * y * y + c1 * y * y;
}

int _hh(int n) => ((n * 7919 + 104729) * 15485863) % 1000003;
Color _mix(Color a, Color b, double t) => Color.lerp(a, b, _c01(t))!;

// ------------------------------------------------------------- painter

typedef _Res = ({int k, double x, double y, double m, bool walking, double dir});

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
  int _streetCars = 3;
  double _sunX = 334;
  double _fxScale = 1.0; // pembesar partikel cuaca saat kamera menjauh

  static final TextPainter _signReg = _makeSign('KOST', Colors.white);
  static final TextPainter _signExc =
  _makeSign('EKSKLUSIF', const Color(0xFF80D8FF));
  static final TextPainter _signSul =
  _makeSign('SULTAN', const Color(0xFFFFD54F));

  static TextPainter _makeSign(String text, Color color) => TextPainter(
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
  static final List<Offset> _slots = _buildSlots();

  // Gundukan sampah di ATAP (dx, dy relatif terhadap garis atap). Hanya
  // tampil di rumah yang tertimbun - dan jadi sasaran longsoran sinematik.
  static final List<Offset> _roofSlots = _buildRoofSlots();

  static List<Offset> _buildRoofSlots() {
    final s = <Offset>[];
    for (var r = 0; r < 5; r++) {
      final n = 17 - r * 2;
      for (var i = 0; i < n; i++) {
        s.add(Offset(112.0 + r * 9.0 + i * 10.8, -5.0 - r * 7.5));
      }
    }
    return s;
  }

  static List<Offset> _buildSlots() {
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

  double get _litFactor {
    final r = d.trashRatio;
    final base = r >= 0.9 ? 0.3 : (r >= 0.75 ? 0.6 : (r >= 0.5 ? 0.85 : 1.0));
    return math.min(base, d.lights);
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
    final buildP = _fxProgress(FxType.build, 2600);
    final incomingP = _fxProgress(FxType.incoming, 1600);
    final tierP = _fxProgress(FxType.tier, 2400);

    double shakeX = 0, shakeY = 0;
    if (collapseShake != null) {
      shakeX += math.sin(collapseShake * 65) * 5 * (1 - collapseShake);
      shakeY += math.cos(collapseShake * 50) * 3 * (1 - collapseShake);
    }
    if (buildP != null && buildP > 0.32 && buildP < 0.55) {
      final q = 1 - (buildP - 0.32) / 0.23;
      shakeY += math.sin(buildP * 120) * 3.5 * q;
      shakeX += math.cos(buildP * 90) * 2.0 * q;
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
    final hj = _fxActive(FxType.hijack, _hijackMs);
    if (hj != null && hj.amount.round() != 1) {
      final hp = hj.age / _hijackMs;
      if (hp > 0.2 && hp < 0.55) {
        final q = 1 - (hp - 0.2) / 0.35;
        shakeX += math.sin(hp * 220) * 3.0 * q;
        shakeY += math.cos(hp * 180) * 2.2 * q;
      }
    }
    // Rumah bergetar makin keras sebelum runtuh
    final bAge = d.buriedAgeMs;
    if (bAge != null && bAge < kBuriedCollapseMs) {
      final q = _c01((bAge - 1200) / 3400.0);
      shakeX += math.sin(bAge * 0.09) * 2.6 * q;
      shakeY += math.cos(bAge * 0.13) * 1.7 * q;
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
        required int cars,
        required double fxScale,
      }) {
    _street = true;
    _streetW = worldW;
    _streetCars = cars;
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
    _drawCars(canvas, t);
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
    // Emoji reaksi digambar sebagai widget (KostEmojiBubble) di atas semua
    // kartu UI agar tidak tertutup.
    _drawCinematic(canvas, t);
    _drawStateFrames(canvas, t);
  }

  // ----------------------------------------------------------- langit

  void _drawSky(Canvas canvas, double t, double p) {
    final isRain = d.worldEvent == 'rain_flood';
    final heavy = _c01(p * 1.2 + (d.smog ? 0.25 : 0) + (isRain ? 0.35 : 0));
    final top = _mix(const Color(0xFF4CA8E0), const Color(0xFF5D666B), heavy);
    final bottom =
    _mix(const Color(0xFFE3F5FB), const Color(0xFFA09C94), heavy);
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

    final sunA =
    ((1 - p * 1.1) * (isRain ? 0.2 : 1.0)).clamp(0.1, 1.0).toDouble();
    final sun = Offset(_sunX, 46);
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
    final cloudColor = _mix(
      Colors.white,
      const Color(0xFF54595E),
      _c01(p * 1.15 + (isRain ? 0.55 : 0)),
    );
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

    if (p < 0.4 && !isRain && !d.compact) {
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
        _p.color = Colors.white.withValues(alpha: 0.2);
        for (var yy = _gy - bh + 6; yy < _gy - 8; yy += 12) {
          for (var xx = x + 4; xx < x + bw - 4; xx += 8) {
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
    if (_street) {
      // Jalan panjang: mobil melaju di koordinat dunia sepanjang seluruh deret rumah.
      final span = _streetW + 700;
      for (var k = 0; k < _streetCars; k++) {
        final right = k % 2 == 0;
        final speed = 36.0 + (k % 3) * 11;
        final x = (t * speed + k * (span / _streetCars)) % span;
        final cx = right ? -350 + x : _streetW + 350 - x;
        _car(canvas, cx, right ? 296 : 281, k, right);
      }
      return;
    }
    final span = _vr - _vl + 220;
    final n = d.compact ? 1 : 3;
    for (var k = 0; k < n; k++) {
      final right = k % 2 == 0;
      final speed = 36.0 + k * 11;
      final x = (t * speed + k * 190) % span;
      final cx = right ? _vl - 110 + x : _vr + 110 - x;
      _car(canvas, cx, right ? 296 : 281, k, right);
    }
  }

  void _car(Canvas canvas, double x, double y, int k, bool right) {
    canvas.save();
    canvas.translate(x, y);
    if (!right) canvas.scale(-1, 1);
    _p
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.22);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 40, height: 4), _p);
    _p.color = _carColors[k % _carColors.length];
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-17, -11, 34, 8), const Radius.circular(3)),
      _p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-9, -11)
        ..lineTo(-5, -18)
        ..lineTo(7, -18)
        ..lineTo(11, -11)
        ..close(),
      _p,
    );
    _p.color = const Color(0xFFB3E5FC);
    canvas.drawPath(
      Path()
        ..moveTo(-6.5, -11)
        ..lineTo(-3.5, -16.5)
        ..lineTo(0, -16.5)
        ..lineTo(0, -11)
        ..close(),
      _p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(2, -11)
        ..lineTo(2, -16.5)
        ..lineTo(6, -16.5)
        ..lineTo(8.5, -11)
        ..close(),
      _p,
    );
    _p.color = const Color(0xFFFFF59D);
    canvas.drawRect(const Rect.fromLTWH(15, -9, 3, 3), _p);
    _p.color = const Color(0xFFEF5350);
    canvas.drawRect(const Rect.fromLTWH(-18, -9, 2, 3), _p);
    for (final wx in const [-9.0, 9.0]) {
      _p.color = const Color(0xFF212121);
      canvas.drawCircle(Offset(wx, -3), 3.6, _p);
      _p.color = const Color(0xFFBDBDBD);
      canvas.drawCircle(Offset(wx, -3), 1.4, _p);
    }
    canvas.restore();
  }

  // ---------------------------------------- bangunan & kelas kost (tier 0..2)

  void _drawBuilding(Canvas canvas, double t) {
    final floors = _floors;
    final roofY = _roofY;
    final buildP = _fxProgress(FxType.build, 2600);
    final tierP = _fxProgress(FxType.tier, 2400);
    final newest = d.rooms - 1;
    _planResidents(t);

    _p
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.18);
    canvas.drawOval(Rect.fromLTWH(_bl - 12, _gy + 1, 214, 11), _p);

    if (d.kostTier >= 2) {
      _p.color = const Color(0xFFFFD54F);
      canvas.drawRect(Rect.fromLTWH(_bl - 5, roofY, 5, _gy - roofY), _p);
      canvas.drawRect(Rect.fromLTWH(_bl + 190, roofY, 5, _gy - roofY), _p);
    }

    for (var idx = 0; idx < floors * 4; idx++) {
      final r = _cell(idx);
      if (idx >= d.rooms) {
        _scaffold(canvas, r);
        continue;
      }
      double scaleX = 1, scaleY = 1;
      double glow = 0;
      if (buildP != null && idx == newest) {
        if (buildP < 0.34) {
          _scaffold(canvas, r);
          continue;
        }
        final local = _c01((buildP - 0.34) / 0.32);
        final pop = _easeOutBack(local);
        scaleY = pop;
        scaleX = 1 + (1 - local) * math.sin(local * math.pi * 2) * 0.16;
        glow = (1 - _c01((buildP - 0.34) / 0.55));
      }
      canvas.save();
      if (scaleX != 1 || scaleY != 1) {
        canvas.translate(r.center.dx, r.bottom);
        canvas.scale(scaleX, scaleY);
        canvas.translate(-r.center.dx, -r.bottom);
      }
      _drawRoom(canvas, r, idx, t);
      if (glow > 0) {
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..color = const Color(0xFFFFEA00).withValues(alpha: glow * 0.85);
        canvas.drawRect(r.inflate(1.5), _p);
        _p.style = PaintingStyle.fill;
      }
      canvas.restore();
    }

    if (!d.compact && !d.eliminated && d.trashRatio < 0.9) {
      for (var idx = 0; idx < math.min(d.rooms, floors * 4); idx++) {
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

    if (d.kostTier == 2) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF263238);
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
      final roofColor = d.kostTier == 1
          ? const Color(0xFF37474F)
          : _mix(d.wall, const Color(0xFF8D4B3B), 0.75);
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

    final signBg = d.kostTier == 2
        ? const Color(0xFF212121)
        : (d.kostTier == 1 ? const Color(0xFF0D47A1) : const Color(0xFF477A62));
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

    final tp = d.kostTier == 2
        ? _signSul
        : (d.kostTier == 1 ? _signExc : _signReg);
    tp.paint(canvas, Offset(150 - tp.width / 2, roofY - 36));

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
    final flicker = _critical && math.sin(t * 17 + idx * 2.3) > 0.82;
    final lit =
        !d.eliminated && !flicker && ((_hh(idx) % 100) / 100) < _litFactor;
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

  // ------------------------- sidak RT/dinas & segel kost

  // ====================================================================
  //  SIDAK POLISI & RUMAH TERTIMBUN (adegan sinematik per rumah)
  // ====================================================================

  static final TextPainter _tapeText = TextPainter(
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

  static final TextPainter _saleText = TextPainter(
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

  /// Petugas Satpol PP: seragam biru + topi.
  void _officer(Canvas canvas, Offset feet,
      {double swing = 0, double alpha = 1, double dir = 1}) {
    if (alpha <= 0.02) return;
    _person(canvas, feet,
        shirt: const Color(0xFF1E4FA3), swing: swing, alpha: alpha);
    final a = _c01(alpha);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF0D2547).withValues(alpha: a);
    canvas.drawRect(Rect.fromLTWH(feet.dx - 3.8, feet.dy - 21.8, 7.6, 3.2), _p);
    canvas.drawRect(
      Rect.fromLTWH(feet.dx - 3.8 + (dir >= 0 ? 2.2 : -2.2), feet.dy - 19.2, 7.6, 1.2),
      _p,
    );
    _p.color = const Color(0xFFFFD600).withValues(alpha: a);
    canvas.drawCircle(Offset(feet.dx, feet.dy - 20.2), 0.9, _p);
  }

  void _policeCar(Canvas canvas, double cx, double cy, double t) {
    _p
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.22);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy + 0.5), width: 48, height: 6), _p);
    _p.color = const Color(0xFF263238);
    canvas.drawCircle(Offset(cx - 12, cy - 2), 3.8, _p);
    canvas.drawCircle(Offset(cx + 12, cy - 2), 3.8, _p);
    _p.color = const Color(0xFFECEFF1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 20, cy - 12, 40, 9), const Radius.circular(3)),
      _p,
    );
    _p.color = const Color(0xFF1565C0);
    canvas.drawRect(Rect.fromLTWH(cx - 20, cy - 8, 40, 3), _p);
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

    // sirine berkedip merah / biru
    final redOn = math.sin(t * 18) > 0;
    final glow = redOn ? const Color(0xFFFF1744) : const Color(0xFF2979FF);
    final lc = Offset(cx + 1, cy - 21);
    _p.shader = RadialGradient(
      colors: [glow.withValues(alpha: 0.42), glow.withValues(alpha: 0)],
    ).createShader(Rect.fromCircle(center: lc, radius: 34));
    canvas.drawCircle(lc, 34, _p);
    _p.shader = null;
    _p.color = redOn ? const Color(0xFFFF1744) : const Color(0xFF7F0D22);
    canvas.drawRect(Rect.fromLTWH(cx - 5, cy - 22.6, 5.4, 3.4), _p);
    _p.color = redOn ? const Color(0xFF14316B) : const Color(0xFF2979FF);
    canvas.drawRect(Rect.fromLTWH(cx + 0.4, cy - 22.6, 5.4, 3.4), _p);
  }

  /// Sidak polisi: mobil masuk -> petugas turun -> pita dipasang -> segel.
  /// Saat [KostSceneData.policeAgeMs] null tetapi kost masih disegel, yang
  /// tampil adalah keadaan AKHIR animasi (sehingga serah-terimanya mulus).
  void _drawInspectAndSeal(Canvas canvas, double t) {
    if (d.eliminated) return;
    final age = d.policeAgeMs;
    final sealed = d.sealedLeft > 0;
    if (age == null && !sealed) return;

    final done = age == null;
    final a = age ?? 1000000;
    // Tidak disegel -> setelah selesai petugas membereskan pita & pergi.
    final leaveU = (!sealed && !done) ? _c01((a - 7800) / 1200.0) : 0.0;
    final tapeA = 1 - leaveU;
    final tp = _c01((a - kPoliceTapeStartMs) / kPoliceTapeMs);
    const cy = 278.0;

    // ---- posisi mobil
    var carX = 152.0;
    var driveU = 1.0;
    if (a < kPoliceDriveMs) {
      driveU = a / kPoliceDriveMs;
      carX = _lerp(-70, 152, 1 - math.pow(1 - driveU, 3).toDouble());
    }
    carX += leaveU * leaveU * 520;

    // debu ban saat mobil mengerem
    if (driveU < 1) {
      for (var k = 0; k < 4; k++) {
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFBDBDBD)
              .withValues(alpha: _c01((1 - driveU) * (0.28 - k * 0.05)));
        canvas.drawCircle(
            Offset(carX - 26 - k * 8, cy - 2 - k * 1.5), 2.5 + k * 1.2, _p);
      }
    }

    // kilau sirine menyapu dinding rumah
    if (carX > 60 && leaveU < 0.6) {
      final redOn = math.sin(t * 18) > 0;
      _p
        ..style = PaintingStyle.fill
        ..color = (redOn ? const Color(0xFFFF1744) : const Color(0xFF2979FF))
            .withValues(alpha: 0.07);
      canvas.drawRect(
        Rect.fromLTWH(_bl - 10, _roofY - 6, 210, _gy - _roofY + 8),
        _p,
      );
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
      _tapeStrip(canvas, tapes[i].$1, tapes[i].$2, tp * 4 - i, tapeA);
    }

    // ---- mobil (digambar setelah pita agar tidak tertutup)
    if (carX > -60 && carX < 460) _policeCar(canvas, carX, cy, t);

    // ---- petugas
    final offA = _c01(1 - leaveU * 3);
    final walk = math.sin(t * 16) * 3.2;
    // Petugas B: pengawas dengan papan catatan, berdiri dekat mobil
    if (a >= kPoliceDriveMs && offA > 0) {
      final u = _c01((a - kPoliceDriveMs) / 700.0);
      final e = _ease(u);
      _officer(
        canvas,
        Offset(_lerp(158, 196, e), _lerp(274, 264, e)),
        swing: u < 1 ? walk : 0,
        alpha: offA,
        dir: 1,
      );
    }
    // Petugas A: turun dari mobil lalu membentangkan pita satu per satu
    if (a >= kPoliceDriveMs && offA > 0) {
      Offset feet;
      var swing = 0.0;
      var dir = -1.0;
      if (a < kPoliceTapeStartMs) {
        final u = _ease((a - kPoliceDriveMs) /
            (kPoliceTapeStartMs - kPoliceDriveMs).toDouble());
        feet = Offset(_lerp(146, 96, u), _lerp(274, 250, u));
        swing = walk;
      } else if (tp < 1) {
        final seg = math.min(3, (tp * 4).floor());
        final su = tp * 4 - seg;
        final tt = tapes[seg];
        feet = Offset(_lerp(tt.$1.dx, tt.$2.dx, su), 250);
        dir = tt.$2.dx >= tt.$1.dx ? 1.0 : -1.0;
        swing = walk;
      } else {
        feet = const Offset(98, 250);
      }
      _officer(canvas, feet, swing: swing, alpha: offA, dir: dir);
    }

    // ---- teks
    const bannerPos = Offset(200, _gy - 56);
    if (!done) {
      if (a >= 600 && a < 2900) {
        final env = _c01(math.min((a - 600) / 300.0, (2900 - a) / 400.0));
        _drawBannerText(canvas, 'SIDAK DINAS TIBA!', bannerPos,
            const Color(0xFFFF5252),
            scale: 1.15 + 0.1 * math.sin(t * 14), alpha: env);
      }
      if (a >= kPoliceTapeEndMs && a < kPoliceTapeEndMs + 1200) {
        final q = (a - kPoliceTapeEndMs) / 1200.0;
        final env = _c01(math.min(q * 6, (1 - q) * 4));
        _drawBannerText(canvas, 'DISEGEL!', bannerPos,
            const Color(0xFFFFD600),
            scale: 0.8 + 0.55 * _easeOutBack(math.min(1.0, q * 3)),
            alpha: env);
      }
    }
    if (sealed && (done || a >= kPoliceTapeEndMs + 1200)) {
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

  // ------------------------------------------------------- penghuni kost
  //
  // Penghuni keluar-masuk lewat pintu depan sesuai kondisi kost:
  //   sampah >=50% menutup hidung, >=75% marah-marah, >=90% demo ramai (papan),
  //   polusi >=60% bermasker & batuk, >=85% masker gas, tertimbun duduk lesu.
  // Jadwal murni fungsi waktu + seed rumah (tanpa state/timer), jadi tiap rumah
  // punya ritme sendiri dan semua pemain melihat hal yang sama. Ekspresi hanya
  // lewat ikon agar tetap terbaca saat kamera menjauh.

  static const List<Color> _shirts = [
    Color(0xFF42A5F5),
    Color(0xFFEF5350),
    Color(0xFF66BB6A),
    Color(0xFFAB47BC),
  ];
  static const List<double> _spotX = [150.0, 252.0, 120.0, 284.0];
  static const List<double> _spotY = [265.0, 268.0, 270.0, 264.0];
  static const double _doorX = 201;
  static final Map<String, TextPainter> _iconCache = <String, TextPainter>{};

  List<_Res> _resOut = <_Res>[];
  final Set<int> _resOutRooms = <int>{};
  int _resMode = 0; // 0 tenang, 1 marah, 2 bau, 3 batuk, 4 tertimbun
  int _resMask = 0; // 0 tanpa, 1 masker, 2 masker gas
  bool _resSign = false;

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

  void _drawDoor(Canvas canvas, double open) {
    if (d.compact) return;
    const door = Rect.fromLTWH(195, 214, 12, 22);
    _p
      ..style = PaintingStyle.fill
      ..color = _mix(const Color(0xFF2B1F18), const Color(0xFFFFC860), open * 0.6);
    canvas.drawRect(door, _p);
    _p.color = const Color(0xFF6D4C41);
    canvas.drawRect(
      Rect.fromLTWH(door.left, door.top, door.width * (1 - 0.75 * open), door.height),
      _p,
    );
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
  }

  /// Gelembung ikon kecil di atas kepala penghuni.
  void _resIcon(
      Canvas canvas, double x, double y, String e, double t, int k) {
    final tp = _icon(e);
    final pop = 0.9 + 0.14 * math.sin(t * 6 + k * 2);
    canvas.save();
    canvas.translate(x, y + math.sin(t * 3 + k) * 0.8);
    canvas.scale(pop);
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
    final cough = !walking && pose == 3 && math.sin(t * 2.2 + k) > 0.5;
    final hop = (!walking && pose == 1) ? -math.sin(ph).abs() * 2.6 : 0.0;
    var lean = 0.0;
    if (cough) lean = 0.32;
    if (walking && mask == 2) lean = 0.16;
    final sw = walking ? math.sin(ph) * 3.0 : 0.0;
    const skin = Color(0xFFE0AC84);

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
    if (d.compact || !(d.trashRatio >= 0.75 || d.eliminated)) return;
    for (var k = 0; k < 4; k++) {
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
    if (d.compact || !(_critical || d.eliminated)) return;
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
    if (!(d.trashRatio >= 0.5 || d.eliminated)) return;
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

  // ------------------------------------------------------ truk sampah

  void _drawTruck(Canvas canvas, double t) {
    // Adegan pembajakan: bila kita korban, truk normal digantikan adegan ini
    if (_drawHijackScene(canvas, t)) return;

    final hp = d.haulProgress;
    if (hp == null) return;

    double x;
    var facingLeft = true;
    var moving = false;
    if (hp < 0.15) {
      x = _lerp(470, 318, _ease(hp / 0.15));
      moving = hp < 0.14;
    } else if (hp < 0.85) {
      x = 318;
    } else {
      x = _lerp(318, 470, _ease((hp - 0.85) / 0.15));
      facingLeft = false;
      moving = true;
    }

    canvas.save();
    canvas.translate(x, 297);
    if (!facingLeft) canvas.scale(-1, 1);
    if (moving) canvas.translate(0, math.sin(t * 24) * 0.7);

    _p
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.25);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 88, height: 6), _p);

    _p.color = const Color(0xFFFFF59D).withValues(alpha: 0.22);
    canvas.drawPath(
      Path()
        ..moveTo(-40, -15)
        ..lineTo(-88, -3)
        ..lineTo(-88, -24)
        ..close(),
      _p,
    );

    if (moving) {
      for (var k = 0; k < 4; k++) {
        final ph = (t * 1.6 + k * 0.25) % 1.0;
        _p.color = const Color(0xFFBDBDBD).withValues(alpha: (1 - ph) * 0.5);
        canvas.drawCircle(
            Offset(44 + ph * 24, -6 - ph * 10), 3 + ph * 6.5, _p);
      }
    }

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

    _p.color = const Color(0xFF2E5E3A);
    canvas.drawRect(const Rect.fromLTWH(32, -36, 8, 11), _p);
    if (!moving) {
      final open = 0.5 + 0.5 * math.sin(t * 3);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF1B3B25);
      canvas.drawLine(const Offset(40, -36),
          Offset(40 + 7 * open, -36 - 6 * open), _p);
      _p.style = PaintingStyle.fill;
    }

    _p.color = const Color(0xFF2E9E5B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-40, -30, 24, 24), const Radius.circular(4)),
      _p,
    );
    _p.color = const Color(0xFFB3E5FC);
    canvas.drawRect(const Rect.fromLTWH(-38, -27, 12, 10), _p);
    _p.color = Colors.white.withValues(alpha: 0.35);
    canvas.drawRect(const Rect.fromLTWH(-37, -26, 4, 8), _p);
    _p.color = const Color(0xFF212121);
    canvas.drawRect(const Rect.fromLTWH(-42, -22, 3, 2), _p);
    _p.color = const Color(0xFFFFF176);
    canvas.drawRect(const Rect.fromLTWH(-41, -15, 3, 4), _p);
    final siren = 0.5 + 0.5 * math.sin(t * 14);
    _p.color = const Color(0xFFFFA000).withValues(alpha: 0.3 + 0.5 * siren);
    canvas.drawCircle(const Offset(-29, -33), 6 + siren * 4, _p);
    _p.color = const Color(0xFFFFCA28);
    canvas.drawRect(const Rect.fromLTWH(-32, -33, 6, 3), _p);

    for (final wx in const [-26.0, 18.0]) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF212121);
      canvas.drawCircle(Offset(wx, -6), 6.5, _p);
      _p.color = const Color(0xFF9E9E9E);
      canvas.drawCircle(Offset(wx, -6), 2.6, _p);
    }
    canvas.restore();

    if (hp >= 0.15 && hp < 0.85) _drawWorkers(canvas, t);
  }

  void _drawWorkers(Canvas canvas, double t) {
    for (var i = 0; i < 2; i++) {
      final phase = (t * 0.9 + i * 0.5) % 1.0;
      final tri = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
      final x = _lerp(382, 352, tri);
      const y = 270.0;
      final carrying = phase < 0.5;
      final swing = math.sin(t * 10 + i) * 2;

      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFF37474F);
      canvas.drawLine(Offset(x, y - 11), Offset(x, y - 4), _p);
      canvas.drawLine(Offset(x, y - 4), Offset(x - swing, y), _p);
      canvas.drawLine(Offset(x, y - 4), Offset(x + swing, y), _p);
      _p.color = const Color(0xFFFF8F00);
      canvas.drawLine(
          Offset(x, y - 10), Offset(x + (carrying ? 4 : 3), y - 15), _p);
      _p.style = PaintingStyle.fill;
      _p.color = const Color(0xFFE0AC84);
      canvas.drawCircle(Offset(x, y - 14), 3, _p);
      _p.color = const Color(0xFFFF8F00);
      canvas.drawRect(Rect.fromLTWH(x - 3.5, y - 18, 7, 2.5), _p);
      if (carrying) _bag(canvas, Offset(x + 4, y - 20), 900 + i, scale: 0.7);
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

  // ---------------------------------------- derek & konstruksi dramatis

  void _drawCrane(Canvas canvas, double t) {
    final p = _fxProgress(FxType.build, 2600);
    if (p == null) return;
    final idx = math.max(0, math.min(d.rooms - 1, _floors * 4 - 1));
    final cell = _cell(idx);
    final mastTop = _roofY - 54;
    final a = p > 0.85 ? (1 - p) / 0.15 : 1.0;

    if (p < 0.75) {
      final beamA = (1 - p / 0.75) * 0.28;
      final beam = Path()
        ..moveTo(cell.center.dx - 12, mastTop)
        ..lineTo(cell.center.dx + 12, mastTop)
        ..lineTo(cell.right + 18, cell.bottom)
        ..lineTo(cell.left - 18, cell.bottom)
        ..close();
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFF59D).withValues(alpha: beamA);
      canvas.drawPath(beam, _p);
    }

    canvas.saveLayer(
      _view,
      Paint()..color = Color.fromRGBO(0, 0, 0, a.clamp(0.0, 1.0)),
    );

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
    _p.style = PaintingStyle.fill;
    _p.color = yellow;
    canvas.drawRect(Rect.fromLTWH(80, mastTop, 230, 4.5), _p);
    _p.color = const Color(0xFF424242);
    canvas.drawRect(Rect.fromLTWH(78, mastTop - 3, 14, 11), _p);
    _p.color = const Color(0xFFFFCA28);
    canvas.drawRect(Rect.fromLTWH(99, mastTop - 10, 12, 10), _p);
    _p.color = const Color(0xFFB3E5FC);
    canvas.drawRect(Rect.fromLTWH(101, mastTop - 8, 6, 5), _p);

    final hx = cell.center.dx;
    final restY = mastTop + 6;
    final dropY = cell.top - 8;
    final hookY = p < 0.34
        ? _lerp(restY, dropY, _ease(p / 0.34))
        : _lerp(dropY, restY, _ease((p - 0.34) / 0.45));

    _p.color = const Color(0xFFE65100);
    canvas.drawRect(Rect.fromLTWH(hx - 6, mastTop - 1, 12, 6), _p);

    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFF212121);
    canvas.drawLine(Offset(hx - 2, mastTop + 5), Offset(hx - 2, hookY), _p);
    canvas.drawLine(Offset(hx + 2, mastTop + 5), Offset(hx + 2, hookY), _p);

    _p.style = PaintingStyle.fill;
    _p.color = const Color(0xFFFF6F00);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(hx - 5, hookY, 10, 7), const Radius.circular(2)),
      _p,
    );

    if (p < 0.34) {
      final swing = math.sin(p * 30) * 0.06 * (1 - p / 0.34);
      final modRect = Rect.fromCenter(
          center: Offset(hx, hookY + 26),
          width: _cw * 0.88,
          height: _fh * 0.88);
      canvas.save();
      canvas.translate(hx, hookY + 6);
      canvas.rotate(swing);
      canvas.translate(-hx, -(hookY + 6));

      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFF424242);
      canvas.drawLine(Offset(hx, hookY + 6), modRect.topLeft, _p);
      canvas.drawLine(Offset(hx, hookY + 6), modRect.topRight, _p);

      _p
        ..style = PaintingStyle.fill
        ..color = d.wall;
      canvas.drawRect(modRect, _p);
      _p.color = const Color(0xFFFFDD7A);
      canvas.drawRect(modRect.deflate(8), _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _mix(d.wall, Colors.black, 0.35);
      canvas.drawRect(modRect, _p);
      _p.style = PaintingStyle.fill;
      canvas.restore();
    }
    canvas.restore();

    if (p >= 0.34) {
      final q = _c01((p - 0.34) / 0.66);

      if (q < 0.65) {
        final rq = q / 0.65;
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * (1 - rq)
          ..color = const Color(0xFFFFEE58).withValues(alpha: (1 - rq) * 0.9);
        canvas.drawCircle(cell.center, 12 + rq * 54, _p);
        _p.style = PaintingStyle.fill;
      }

      for (var k = 0; k < 8; k++) {
        final dir = k % 2 == 0 ? 1.0 : -1.0;
        final spread = (k ~/ 2 + 1) * 8.0;
        final dx = cell.center.dx + dir * (10 + spread * _ease(q));
        final dy = cell.bottom - 2 - q * (8 + (k % 3) * 5);
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFD7CCC8).withValues(alpha: (1 - q) * 0.65);
        canvas.drawCircle(Offset(dx, dy), 5 + q * 11, _p);
      }

      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 14; k++) {
        final ang = -math.pi * 0.9 + (k / 13) * math.pi * 0.8 + (k % 3) * 0.1;
        final dist = 10 + _ease(q) * (32 + (k % 4) * 10);
        final gravity = q * q * 28;
        final sx = cell.center.dx + math.cos(ang) * dist;
        final sy = cell.center.dy + math.sin(ang) * dist + gravity;
        _p.color = (k % 2 == 0
            ? const Color(0xFFFFEA00)
            : const Color(0xFFFF6D00))
            .withValues(alpha: (1 - q));
        canvas.drawLine(
          Offset(sx, sy),
          Offset(sx - math.cos(ang) * 4, sy - math.sin(ang) * 4 - 2),
          _p,
        );
      }
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt;

      _drawBannerText(
        canvas,
        'KAMAR BARU! +INCOME',
        Offset(cell.center.dx, cell.top - 10 - q * 28),
        const Color(0xFFFFEE58),
        scale: 0.95 + math.sin(q * math.pi) * 0.25,
        alpha: 1 - q,
      );
    }
  }

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

  // ===================================================================
  //  ADEGAN PEMBAJAKAN TRUK
  //  amount == 1 -> sisi PEMBAJAK (kabur membawa truk rampasan)
  //  amount != 1 -> sisi KORBAN (truk disergap & dibawa kabur)
  // ===================================================================

  static const int _hijackMs = 3600;

  KostFx? _fxActive(FxType type, int durMs) {
    KostFx? best;
    for (final f in d.fx) {
      if (f.type != type) continue;
      final a = f.age;
      if (a < 0 || a > durMs) continue;
      if (best == null || a < best.age) best = f;
    }
    return best;
  }

  double _easeIn(double x) {
    x = _c01(x);
    return x * x * x;
  }

  /// Mengembalikan true bila adegan sisi KORBAN sedang tampil
  /// (truk haul normal tidak perlu digambar lagi).
  bool _drawHijackScene(Canvas canvas, double t) {
    final fx = _fxActive(FxType.hijack, _hijackMs);
    if (fx == null) return false;
    final p = fx.age / _hijackMs;
    if (fx.amount.round() == 1) {
      _hijackThiefView(canvas, t, p);
      return false;
    }
    _hijackVictimView(canvas, t, p);
    return true;
  }

  void _hijackVictimView(Canvas canvas, double t, double p) {
    const gy = 297.0;
    final escQ = _c01((p - 0.5) / 0.5);
    final truckRight = p >= 0.46;
    final truckX = p < 0.5 ? 318.0 : _lerp(318, 560, _easeIn(escQ));
    final vanIn = _ease(p / 0.22);
    final vanRight = p < 0.5;
    final vanX =
    p < 0.5 ? _lerp(-90, 214, vanIn) : _lerp(214, -150, _easeIn(escQ));

    // Jejak ban hitam di aspal saat van mengerem mendadak
    if (p > 0.14) {
      final len = _c01((p - 0.14) / 0.08) * 80;
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: 0.35 * (1 - p * 0.6));
      canvas.drawLine(Offset(214 - len - 8, gy - 1), Offset(206, gy - 1), _p);
      canvas.drawLine(Offset(214 - len - 8, gy + 2), Offset(206, gy + 2), _p);
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt;
    }

    // Asap rem
    if (p > 0.14 && p < 0.42) {
      for (var k = 0; k < 5; k++) {
        final ph = _c01((p - 0.14 - k * 0.012) / 0.26);
        _p.color = const Color(0xFFD7CCC8).withValues(alpha: (1 - ph) * 0.6);
        canvas.drawCircle(
            Offset(190 - ph * 26 - k * 5, gy - 4 - ph * 16), 4 + ph * 10, _p);
      }
    }

    // Van pembajak
    _raiderVan(canvas, vanX, gy, t, right: vanRight, braking: p > 0.14 && p < 0.3);

    // Garis kecepatan di belakang truk yang kabur
    if (p > 0.52) {
      final a = _c01((p - 0.52) / 0.1) * (1 - _c01((p - 0.92) / 0.08));
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.55 * a);
      for (var k = 0; k < 7; k++) {
        final yy = gy - 6 - k * 5.0;
        final len = 26 + (k % 3) * 14 + escQ * 40;
        final sx = truckX - 52 - (k % 2) * 10;
        canvas.drawLine(Offset(sx - len, yy), Offset(sx, yy), _p);
      }
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt;
      // Knalpot ngebul hitam
      for (var k = 0; k < 5; k++) {
        final ph = (t * 2.2 + k * 0.2) % 1.0;
        _p.color = const Color(0xFF424242).withValues(alpha: (1 - ph) * 0.6 * a);
        canvas.drawCircle(
            Offset(truckX - 50 - ph * 34, gy - 8 - ph * 10), 3 + ph * 8, _p);
      }
    }

    // Truk (bergetar -> loncat putar balik -> tancap gas)
    final hop = (p > 0.44 && p < 0.54)
        ? -math.sin((p - 0.44) / 0.1 * math.pi) * 7
        : 0.0;
    final jitter = (p > 0.22 && p < 0.46) ? math.sin(t * 70) * 0.9 : 0.0;
    canvas.save();
    canvas.translate(truckX + jitter, gy + hop);
    if (truckRight) canvas.scale(-1, 1);
    _hijackTruck(canvas, t, moving: p >= 0.5, stolen: p >= 0.34);
    canvas.restore();

    // Maling melompat dari van ke kabin truk
    if (p >= 0.22 && p < 0.42) {
      final q = _c01((p - 0.22) / 0.2);
      final from = Offset(vanX + 6, gy - 30);
      const to = Offset(284, gy - 18);
      final pos = Offset(
        _lerp(from.dx, to.dx, q),
        _lerp(from.dy, to.dy, q) - math.sin(q * math.pi) * 38,
      );
      _person(canvas, pos,
          shirt: const Color(0xFF212121), mask: true, rot: q * 6.28, swing: 3);
    } else if (p >= 0.42) {
      // Kepala maling bertopeng mengintip dari jendela kabin
      final hx = truckRight ? truckX + 32 : truckX - 32;
      final hy = gy - 22 + hop;
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF212121);
      canvas.drawCircle(Offset(hx, hy), 3.8, _p);
      _p.color = Colors.white;
      canvas.drawCircle(Offset(hx - 1.4, hy - 0.5), 0.8, _p);
      canvas.drawCircle(Offset(hx + 1.4, hy - 0.5), 0.8, _p);
    }

    // Sopir terlempar keluar & pusing
    if (p >= 0.34) {
      final td = _c01((p - 0.34) / 0.14);
      final dx = _lerp(282, 250, _ease(td));
      final dy = gy - (1 - td) * 10 - math.sin(td * math.pi) * 16;
      final fade = 1 - _c01((p - 0.9) / 0.1);
      _person(
        canvas,
        Offset(dx, dy),
        shirt: const Color(0xFF43A047),
        hat: true,
        rot: td < 1 ? td * 5.5 : math.sin(t * 3) * 0.08,
        swing: td < 1 ? 3 : 0.6,
        alpha: fade,
      );
      if (td >= 1) {
        for (var k = 0; k < 3; k++) {
          final ang = t * 5 + k * 2.09;
          _star(
            canvas,
            Offset(dx + math.cos(ang) * 7, dy - 19 + math.sin(ang) * 2.5),
            2.6,
            const Color(0xFFFFD54F).withValues(alpha: fade),
          );
        }
      }
      // Garis kaget memancar
      if (p < 0.62) {
        final e = 1 - (p - 0.34) / 0.28;
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

    // Kantong sampah berjatuhan dari bak truk yang kabur
    if (p > 0.52) {
      for (var j = 0; j < 4; j++) {
        final dp = 0.56 + j * 0.07;
        if (p < dp) continue;
        final lq = _c01((p - dp) / 0.14);
        final dxp = _lerp(318, 560, _easeIn(_c01((dp - 0.5) / 0.5)));
        final bx = dxp - 36 + lq * 18;
        final by = gy - 22 + lq * 20 - math.sin(lq * math.pi) * 14;
        canvas.save();
        canvas.translate(bx, by);
        canvas.rotate(lq * 6);
        _bag(canvas, Offset.zero, 800 + j, scale: 0.85);
        canvas.restore();
      }
    }

    // Banner besar "slam"
    if (p > 0.36) {
      final q = _c01((p - 0.36) / 0.64);
      final a = q < 0.75 ? 1.0 : (1 - q) / 0.25;
      final slam = _easeOutBack(_c01(q / 0.18));
      _drawBannerText(
        canvas,
        'TRUK DIBAJAK!',
        Offset(250, 232 - q * 20),
        const Color(0xFFFF5252),
        scale: 0.8 + slam * 0.7,
        alpha: a,
      );
    }
  }

  void _hijackThiefView(Canvas canvas, double t, double p) {
    const gy = 297.0;
    final m = _ease(p);
    final vanX = _lerp(560, -190, m);
    final truckX = vanX + 112;

    // Garis kecepatan
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.4);
    for (var k = 0; k < 7; k++) {
      final yy = gy - 6 - k * 5.0;
      final sx = truckX + 52 + (k % 2) * 10;
      canvas.drawLine(Offset(sx, yy), Offset(sx + 30 + (k % 3) * 14, yy), _p);
    }
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;

    _raiderVan(canvas, vanX, gy, t, right: false);
    canvas.save();
    canvas.translate(truckX, gy);
    _hijackTruck(canvas, t, moving: true, stolen: true);
    canvas.restore();

    // Koin rampasan beterbangan
    for (var k = 0; k < 8; k++) {
      final ph = (t * 1.6 + k * 0.125) % 1.0;
      final x = truckX + 50 + ph * 46 + k * 2;
      final y = gy - 26 - math.sin(ph * math.pi) * 26;
      _p.color = const Color(0xFFFFD54F).withValues(alpha: (1 - ph) * 0.95);
      canvas.drawCircle(Offset(x, y), 2.6, _p);
      _p.color = const Color(0xFFFFF59D).withValues(alpha: (1 - ph) * 0.95);
      canvas.drawCircle(Offset(x - 0.7, y - 0.7), 0.9, _p);
    }

    if (p > 0.15 && p < 0.95) {
      final q = _c01((p - 0.15) / 0.8);
      final a = q < 0.8 ? 1.0 : (1 - q) / 0.2;
      final slam = _easeOutBack(_c01(q / 0.15));
      _drawBannerText(
        canvas,
        'BAJAK BERHASIL!',
        Offset(200, 220 - q * 14),
        const Color(0xFFFFD54F),
        scale: 0.8 + slam * 0.55,
        alpha: a,
      );
    }
  }

  void _hijackTruck(Canvas canvas, double t,
      {required bool moving, required bool stolen}) {
    _p
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.25);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 88, height: 6), _p);

    _p.color = const Color(0xFF43A047);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-16, -36, 56, 30), const Radius.circular(3)),
      _p,
    );
    _p.color = Colors.white.withValues(alpha: 0.5);
    canvas.drawRect(const Rect.fromLTWH(-16, -22, 56, 4), _p);

    _p.color = stolen ? const Color(0xFFB71C1C) : const Color(0xFF2E9E5B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-40, -30, 24, 24), const Radius.circular(4)),
      _p,
    );
    _p.color = const Color(0xFFB3E5FC);
    canvas.drawRect(const Rect.fromLTWH(-38, -27, 12, 10), _p);
    _p.color = const Color(0xFFFFF176);
    canvas.drawRect(const Rect.fromLTWH(-41, -15, 3, 4), _p);

    // Lampu strobo merah-biru saat dibajak
    final blink = math.sin(t * 18) > 0;
    final sirenC = stolen
        ? (blink ? const Color(0xFFFF1744) : const Color(0xFF2979FF))
        : const Color(0xFFFFA000);
    _p.color = sirenC.withValues(alpha: 0.35);
    canvas.drawCircle(const Offset(-29, -33), 10, _p);
    _p.color = sirenC;
    canvas.drawRect(const Rect.fromLTWH(-32, -33, 6, 3), _p);

    final wa = moving ? t * 30 : 0.0;
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
        ..color = const Color(0xFF9E9E9E);
      canvas.drawLine(
        Offset(wx + math.cos(wa) * 5, -6 + math.sin(wa) * 5),
        Offset(wx - math.cos(wa) * 5, -6 - math.sin(wa) * 5),
        _p,
      );
      _p.style = PaintingStyle.fill;
    }
  }

  void _raiderVan(Canvas canvas, double x, double y, double t,
      {required bool right, bool braking = false}) {
    canvas.save();
    canvas.translate(x, y);
    if (!right) canvas.scale(-1, 1);
    if (braking) canvas.rotate(-0.04);

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

    final wa = t * 28;
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

  // ------------------------------------------- efek sinematik & dramatis

  void _drawGodRays(Canvas canvas, double t, double p) {
    if (d.compact || p > 0.45 || d.eliminated || d.worldEvent == 'rain_flood') {
      return;
    }
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
    final buildP = _fxProgress(FxType.build, 2600);
    if (buildP != null && buildP > 0.34) {
      final idx = math.max(0, math.min(d.rooms - 1, _floors * 4 - 1));
      _confettiBurst(
          canvas, _cell(idx).center, (buildP - 0.34) / 0.66, 26, 5000);
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
    final fx = _fxActive(FxType.hijack, _hijackMs);
    if (fx != null && fx.amount.round() != 1) {
      final p = fx.age / _hijackMs;
      final env = p < 0.08 ? p / 0.08 : (p > 0.9 ? (1 - p) / 0.1 : 1.0);
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
      final fl = 1 - (p - 0.40).abs() / 0.06;
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
    final n = d.compact ? 8 : 34;
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
    this.insets = EdgeInsets.zero,
  });

  final List<KostSceneData> houses;

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

  double _roofOf(int i) {
    final floors = math.min(3, math.max(1, (houses[i].rooms / 4).ceil()));
    return _gy - floors * _fh;
  }

  /// Gambar kantong sampah terbang antar rumah. Lambungan & durasi mengikuti
  /// jarak. Lemparan "bounce" (ditangkis): terbang ke perisai penangkis lalu
  /// memantul balik ke pelempar (biru), bukan teleport.
  void _paintShots(Canvas canvas, double fxScale, KostPainter painter) {
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
      const stagger = 80.0;
      final flight = math.max(400.0, sh.durMs - stagger * (sh.bags - 1));
      final fxs = math.min(fxScale, 2.2);

      for (var j = 0; j < sh.bags; j++) {
        final q = (age - j * stagger) / flight;
        if (q < 0 || q > 1) continue;

        Offset p0, p1;
        double lq;
        var back = false;
        if (!sh.bounce) {
          p0 = launch;
          p1 = landB;
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
        Offset at(double u) => Offset(
          _lerp(p0.dx, p1.dx, u) + (j - 1.5) * 3,
          _lerp(p0.dy, p1.dy, u) - 4 * peak * u * (1 - u),
        );
        final tint =
        back ? const Color(0xFF40C4FF) : const Color(0xFF78909C);

        // jejak asap mengikuti lintasan
        for (var tr = 1; tr <= 4; tr++) {
          final pt = at((lq - tr * 0.045).clamp(0.0, 1.0));
          painter._p
            ..style = PaintingStyle.fill
            ..color = tint.withValues(alpha: 0.32 / tr);
          canvas.drawCircle(pt, (5.0 - tr) * math.min(fxs, 2.0), painter._p);
        }
        final pos = at(lq);
        if (back) {
          painter._p
            ..style = PaintingStyle.fill
            ..color = const Color(0xFF40C4FF).withValues(alpha: 0.3);
          canvas.drawCircle(pos, 10 * math.min(fxs, 2.0), painter._p);
        }
        // kantong berputar searah terbang
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate((toRight ^ back ? 1 : -1) * (lq * 9 + j));
        painter._bag(canvas, Offset.zero, 500 + j, scale: 1.15 * fxs);
        canvas.restore();
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
      cars: 2 + houses.length,
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