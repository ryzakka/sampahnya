import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'kost_style.dart';

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

/// Jenis lemparan: biasa, sekarung besar, gas beracun, atau kembang api
/// (gertakan: selama melayang tampak persis seperti lempar biasa).
enum ShotKind { normal, sack, smog, firework }

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
  KostFx(this.type,
      {this.amount = 0, this.peerId, int delayMs = 0, this.durMs = 0})
      : startMs = sceneNowMs() + delayMs;

  final FxType type;
  final int startMs;
  final double amount;

  /// Lawan yang terlibat (penyerang / sasaran). Dipakai mode jalan untuk
  /// menentukan arah lemparan sampah antar rumah bertetangga.
  final String? peerId;

  /// Durasi total efek (ms) bila efek punya durasi sendiri (adegan bajak
  /// bergantung jarak rumah). 0 = pakai durasi bawaan painter.
  final int durMs;

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
    this.kind = ShotKind.normal,
    this.spark = false,
    this.fizzle = false,
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

  final ShotKind kind;

  /// Kembang api: true bila percikan terjadi saat mendarat.
  final bool spark;

  /// Kembang api yang ditangkis: terbang ke perisai lalu padam di sana.
  final bool fizzle;

  int get age => sceneNowMs() - startMs;
}

/// Arwah pemain yang tertimbun: melayang bebas di jalan. MURNI visual,
/// tidak punya efek gameplay apa pun.
class KostGhost {
  KostGhost({
    required this.id,
    required this.name,
    required this.color,
    required this.x,
    required this.y,
  })  : tx = x,
        ty = y;

  final String id;
  String name;
  Color color;

  /// Posisi & tujuan di koordinat dunia jalan.
  double x, y, tx, ty;

  /// Dorongan sesaat saat terpukul sampah.
  double vx = 0, vy = 0;
  int hitMs = -100000;
  int emojiCode = 0;
  int emojiMs = -100000;
  int _lastMs = sceneNowMs();

  /// Waktu muncul (animasi pop-in), kemiringan badan & arah pandang yang
  /// dihaluskan, serta jejak posisi untuk bayangan samar saat bergerak.
  final int bornMs = sceneNowMs();
  double lean = 0;
  double look = 0;
  final List<Offset> trail = <Offset>[];
  int _trailMs = 0;

  void moveTo(double wx, double wy) {
    tx = wx;
    ty = wy;
  }

  /// Dipanggil tiap frame: mengejar tujuan dengan halus (juga berfungsi
  /// sebagai interpolasi posisi arwah pemain lain yang tiba 5x per detik).
  void step() {
    final now = sceneNowMs();
    final dt = math.min(0.1, math.max(0, now - _lastMs) / 1000.0);
    _lastMs = now;
    final k = 1 - math.exp(-dt * 3.2);
    x += (tx - x) * k + vx * dt;
    y += (ty - y) * k + vy * dt;
    final damp = math.exp(-dt * 4.0);
    vx *= damp;
    vy *= damp;

    // kemiringan & arah pandang mengikuti gerak dengan halus
    final dx = tx - x;
    final leanT = (dx * 0.01 + vx * 0.0015).clamp(-0.32, 0.32).toDouble();
    lean += (leanT - lean) * (1 - math.exp(-dt * 7.0));
    final lookT = (dx / 50).clamp(-1.0, 1.0).toDouble();
    look += (lookT - look) * (1 - math.exp(-dt * 6.0));

    // jejak: bertambah saat bergerak, menyusut saat diam
    if (now - _trailMs > 45) {
      _trailMs = now;
      final moved = trail.isEmpty ||
          (trail.last - Offset(x, y)).distance > 1.5;
      if (moved) {
        trail.add(Offset(x, y));
        if (trail.length > 9) trail.removeAt(0);
      } else if (trail.isNotEmpty) {
        trail.removeAt(0);
      }
    }
  }
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
    this.style,
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

  /// Kustomisasi bangunan & karakter pemain; null = tampilan bawaan.
  final KostStyle? style;

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
        style: style,
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
    style: style,
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
// Urutan baru: mobil masuk (0..2600) -> petugas turun & pengumuman megafon
// (2600..4400) -> pita dibentang (4400..8000) -> stempel segel di pintu
// (8000..9600) -> (bila tidak disegel) pita dibereskan & petugas pergi.
const int kPoliceDriveMs = 2600;
const int kPoliceTapeStartMs = 4400;
const int kPoliceTapeMs = 3600;
const int kPoliceTapeEndMs = kPoliceTapeStartMs + kPoliceTapeMs; // 8000
const int kPoliceSealMs = 1600; // stempel segel + dampaknya
const int kPoliceLeaveStartMs = kPoliceTapeEndMs + kPoliceSealMs + 600; // 10200
const int kPoliceTotalMs = 11800;

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

double _easeOut3(double x) {
  x = _c01(x);
  final y = 1 - x;
  return 1 - y * y * y;
}

double _easeInOut3(double x) {
  x = _c01(x);
  if (x < 0.5) return 4 * x * x * x;
  final y = -2 * x + 2;
  return 1 - y * y * y / 2;
}

/// Durasi total adegan pembajakan (ms). [dist] = selisih urutan rumah korban
/// dan pembajak (min 1): makin jauh, makin lama kendaraan menempuh jalan.
int hijackDurationMs(int dist) {
  final extra = (dist < 1 ? 0 : dist - 1).clamp(0, 5).toInt();
  return 6000 + 1000 * extra;
}

class _HjTimes {
  const _HjTimes(this.a, this.g, this.e, this.s);
  final double a; // van menyusul truk korban
  final double g; // perebutan truk
  final double e; // kabur ke rumah pembajak
  final double s; // tiba & masuk garasi
}

_HjTimes _hijackTimes(KostFx fx) {
  final dur = fx.durMs > 0 ? fx.durMs : hijackDurationMs(1);
  final extra = ((dur - 6000) / 1000).round().clamp(0, 5).toDouble();
  return _HjTimes(1500 + 500 * extra, 1700, 1900 + 500 * extra, 900);
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

  /// Papan nama buatan pemain (di-cache: teks sama = TextPainter sama).
  static final Map<String, TextPainter> _signCache = <String, TextPainter>{};
  static TextPainter _customSign(String text) => _signCache.putIfAbsent(
      text, () => _makeSign(text, Colors.white));

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

  static final TextPainter _sealText = TextPainter(
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

  /// Petugas Satpol PP. [role]: 0 = biasa, 1 = komandan bermegafon,
  /// 2 = pemeriksa dengan papan catatan & senter. Menghadap +x lalu dibalik
  /// oleh [dir]. Detail: topi + lencana, rompi reflektif, ikat pinggang, sepatu.
  void _officer(Canvas canvas, Offset feet,
      {double swing = 0,
        double alpha = 1,
        double dir = 1,
        int role = 0,
        double t = 0}) {
    final a = _c01(alpha);
    if (a <= 0.02) return;
    if (a < 1) {
      canvas.saveLayer(
        Rect.fromCenter(center: feet.translate(0, -14), width: 70, height: 60),
        Paint()..color = Color.fromRGBO(0, 0, 0, a),
      );
    }
    const navy = Color(0xFF1E4FA3);
    const dark = Color(0xFF0D2547);
    const skin = Color(0xFFE0AC84);
    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.scale(dir >= 0 ? 1.0 : -1.0, 1.0);

    // bayangan
    _p
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.2);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 0.5), width: 12, height: 2.6), _p);

    // kaki + sepatu
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF16233D);
    canvas.drawLine(const Offset(0, -9), Offset(-swing, -0.8), _p);
    canvas.drawLine(const Offset(0, -9), Offset(swing, -0.8), _p);
    _p
      ..strokeWidth = 2.4
      ..color = Colors.black;
    canvas.drawLine(Offset(-swing, -0.5), Offset(-swing + 1.4, -0.5), _p);
    canvas.drawLine(Offset(swing, -0.5), Offset(swing + 1.4, -0.5), _p);

    // lengan belakang (selalu mengayun / bertolak pinggang)
    _p
      ..strokeWidth = 1.9
      ..color = navy;
    if (role == 0) {
      canvas.drawLine(const Offset(0, -16), Offset(-swing * 0.9, -10.5), _p);
    } else {
      canvas.drawLine(const Offset(0, -16), const Offset(-3.4, -11.5), _p); // tolak pinggang
    }

    // badan
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt
      ..color = navy;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3.7, -18, 7.4, 10), const Radius.circular(2.2)),
      _p,
    );
    // rompi reflektif + ikat pinggang + lencana
    _p.color = const Color(0xFFFFD600).withValues(alpha: 0.9);
    canvas.drawRect(const Rect.fromLTWH(-3.7, -14.4, 7.4, 1.1), _p);
    _p.color = const Color(0xFF212121);
    canvas.drawRect(const Rect.fromLTWH(-3.7, -10.2, 7.4, 1.4), _p);
    _p.color = const Color(0xFFFFD54F);
    canvas.drawRect(const Rect.fromLTWH(-0.6, -10.1, 1.5, 1.2), _p);
    canvas.drawCircle(const Offset(1.9, -16.3), 0.9, _p);

    // kepala + topi
    _p.color = skin;
    canvas.drawCircle(const Offset(0, -21.5), 3.3, _p);
    _p.color = dark;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3.9, -25.4, 7.8, 3.6), const Radius.circular(1.6)),
      _p,
    );
    canvas.drawRect(const Rect.fromLTWH(0.8, -22.2, 5.2, 1.2), _p); // pet
    _p.color = const Color(0xFFFFD600);
    canvas.drawCircle(const Offset(0.6, -23.6), 0.8, _p);

    // lengan depan menurut peran
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..color = navy;
    if (role == 0) {
      canvas.drawLine(const Offset(0, -16), Offset(swing * 0.9, -10.5), _p);
    } else if (role == 1) {
      // megafon: lengan terangkat & sedikit bergerak mengikuti ucapan
      final bob = math.sin(t * 9) * 0.7;
      final hand = Offset(5.4, -19.0 + bob);
      canvas.drawLine(const Offset(0, -16), hand, _p);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFE0E0E0);
      canvas.drawPath(
        Path()
          ..moveTo(hand.dx - 0.5, hand.dy - 1.4)
          ..lineTo(hand.dx + 6.4, hand.dy - 3.4)
          ..lineTo(hand.dx + 6.4, hand.dy + 2.4)
          ..lineTo(hand.dx - 0.5, hand.dy + 1.4)
          ..close(),
        _p,
      );
      _p.color = const Color(0xFFE53935);
      canvas.drawRect(Rect.fromLTWH(hand.dx + 5.2, hand.dy - 3.4, 1.2, 5.8), _p);
      _p.color = skin;
      canvas.drawCircle(hand, 1.2, _p);
    } else {
      // papan catatan di depan dada + senter di tangan belakang
      canvas.drawLine(const Offset(0, -16), const Offset(4.2, -13.4), _p);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF6D4C41);
      canvas.drawRect(const Rect.fromLTWH(3.4, -18.2, 5.4, 7), _p);
      _p.color = const Color(0xFFFFF8E1);
      canvas.drawRect(const Rect.fromLTWH(3.9, -17.5, 4.4, 5.6), _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = const Color(0xFF90A4AE);
      for (var k = 0; k < 3; k++) {
        canvas.drawLine(Offset(4.3, -16.4 + k * 1.7), Offset(7.9, -16.4 + k * 1.7), _p);
      }
      // pena menulis
      final wr = math.sin(t * 14) * 0.9;
      _p
        ..strokeWidth = 0.9
        ..color = const Color(0xFFD32F2F);
      canvas.drawLine(Offset(6.4 + wr, -14.2), Offset(7.6 + wr, -13), _p);
    }
    canvas.restore();
    if (a < 1) canvas.restore();
  }

  /// Berkas sirine merah/biru berputar yang menyapu dinding rumah.
  void _policeBeams(Canvas canvas, Offset src, double t, double k) {
    if (k <= 0.02) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(_vl, _vt, _vr, _gy + 8));
    for (var s = 0; s < 2; s++) {
      final red = s == 0;
      final ang = -0.78 + (red ? 1 : -1) * 0.62 * math.sin(t * 3.4);
      const len = 190.0;
      const w = 0.13;
      final c = red ? const Color(0xFFFF1744) : const Color(0xFF2979FF);
      final path = Path()
        ..moveTo(src.dx, src.dy)
        ..lineTo(src.dx + math.cos(ang - w) * len, src.dy + math.sin(ang - w) * len)
        ..lineTo(src.dx + math.cos(ang + w) * len, src.dy + math.sin(ang + w) * len)
        ..close();
      _p
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [c.withValues(alpha: 0.30 * k), c.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: src, radius: len));
      canvas.drawPath(path, _p);
      _p.shader = null;
    }
    canvas.restore();
  }

  /// Gelombang suara dari megafon.
  void _megaWaves(Canvas canvas, Offset tip, double dir, double t, double k) {
    if (k <= 0.02) return;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final u = ((t * 1.7) + i / 3) % 1.0;
      final r = 5 + u * 26;
      _p.color = Colors.white.withValues(alpha: (1 - u) * 0.65 * k);
      canvas.drawArc(
        Rect.fromCircle(center: tip, radius: r),
        dir >= 0 ? -0.62 : math.pi - 0.62,
        1.24,
        false,
        _p,
      );
    }
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }

  /// Segel di pintu: pita silang merah + kertas "DISEGEL". [u] 0..1 = tahap
  /// stempel (menghantam lalu memantul), [t] untuk kibaran kecil.
  void _doorSeal(Canvas canvas, double u, double t) {
    if (u <= 0 || d.compact) return;
    const door = Rect.fromLTWH(195, 214, 12, 22);
    final pop = _easeOutBack(u);
    // pita silang
    canvas.save();
    canvas.clipRect(door.inflate(1.4));
    for (final s in const [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(door.center.dx, door.center.dy);
      canvas.rotate(s * 0.95);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFD32F2F).withValues(alpha: _c01(u * 3));
      canvas.drawRect(Rect.fromLTWH(-16 * pop, -1.7, 32 * pop, 3.4), _p);
      _p.color = Colors.white.withValues(alpha: 0.6 * _c01(u * 3));
      canvas.drawRect(Rect.fromLTWH(-16 * pop, -0.4, 32 * pop, 0.8), _p);
      canvas.restore();
    }
    canvas.restore();
    // kertas segel
    final sc = 0.2 + 0.8 * pop;
    canvas.save();
    canvas.translate(door.center.dx, door.center.dy - 2 + math.sin(t * 2.3) * 0.15);
    canvas.rotate(-0.1);
    canvas.scale(sc);
    _p.color = const Color(0xFFFFF8E1);
    canvas.drawRect(const Rect.fromLTWH(-9, -5.4, 18, 10.8), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFB71C1C);
    canvas.drawRect(const Rect.fromLTWH(-8, -4.4, 16, 8.8), _p);
    _p.style = PaintingStyle.fill;
    _sealText.paint(canvas, Offset(-_sealText.width / 2, -_sealText.height / 2 - 0.6));
    _p.color = const Color(0xFFB71C1C);
    canvas.drawRect(const Rect.fromLTWH(-6, 1.8, 12, 0.7), _p);
    canvas.restore();
  }

  void _policeCar(Canvas canvas, double cx, double cy, double t,
      {bool lights = true}) {
    _p
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.22);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy + 0.5), width: 48, height: 6), _p);
    _p.color = const Color(0xFF263238);
    canvas.drawCircle(Offset(cx - 12, cy - 2), 3.8, _p);
    canvas.drawCircle(Offset(cx + 12, cy - 2), 3.8, _p);
    _p.color = const Color(0xFFBDBDBD);
    canvas.drawCircle(Offset(cx - 12, cy - 2), 1.4, _p);
    canvas.drawCircle(Offset(cx + 12, cy - 2), 1.4, _p);
    _p.color = const Color(0xFFECEFF1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 20, cy - 12, 40, 9), const Radius.circular(3)),
      _p,
    );
    _p.color = const Color(0xFF1565C0);
    canvas.drawRect(Rect.fromLTWH(cx - 20, cy - 8, 40, 3), _p);
    // pintu & tulisan samping
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0xFF78909C);
    canvas.drawLine(Offset(cx - 2, cy - 12), Offset(cx - 2, cy - 3.2), _p);
    canvas.drawLine(Offset(cx + 8, cy - 12), Offset(cx + 8, cy - 3.2), _p);
    _p.style = PaintingStyle.fill;
    _p.color = Colors.white.withValues(alpha: 0.9);
    canvas.drawRect(Rect.fromLTWH(cx - 17, cy - 7.4, 12, 1.6), _p);
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
    _p.color = const Color(0xFFEF5350);
    canvas.drawRect(Rect.fromLTWH(cx - 20.5, cy - 9.5, 1.6, 2.6), _p);

    // sirine berkedip merah / biru (strobo ganda)
    final redOn = lights ? math.sin(t * 18) > 0 : false;
    final glow = redOn ? const Color(0xFFFF1744) : const Color(0xFF2979FF);
    final lc = Offset(cx + 1, cy - 21);
    if (lights) {
      _p.shader = RadialGradient(
        colors: [glow.withValues(alpha: 0.5), glow.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: lc, radius: 38));
      canvas.drawCircle(lc, 38, _p);
      _p.shader = null;
    }
    _p.color = redOn ? const Color(0xFFFF1744) : const Color(0xFF7F0D22);
    canvas.drawRect(Rect.fromLTWH(cx - 5, cy - 22.6, 5.4, 3.4), _p);
    _p.color = redOn || !lights ? const Color(0xFF14316B) : const Color(0xFF2979FF);
    canvas.drawRect(Rect.fromLTWH(cx + 0.4, cy - 22.6, 5.4, 3.4), _p);
  }

  /// Sidak polisi (versi dramatis):
  ///   0 .. 2600     mobil meluncur, mengerem (jejak ban, debu, bodi menunduk),
  ///                 berkas sirine berputar menyapu dinding
  ///   2600 .. 4400  petugas turun; komandan berpidato lewat megafon, pemeriksa
  ///                 menyorot tumpukan sampah dengan senter & mencatat
  ///   4400 .. 8000  garis polisi dibentang satu per satu
  ///   8000 .. 9600  pemeriksa menempel segel di pintu: hantaman, kilat, guncangan
  ///   (bila tidak disegel) pita dibereskan, petugas pergi, mobil melaju.
  /// Saat [KostSceneData.policeAgeMs] null tetapi kost masih disegel, yang
  /// tampil adalah keadaan AKHIR animasi (sehingga serah-terimanya mulus).
  void _drawInspectAndSeal(Canvas canvas, double t) {
    if (d.eliminated) return;
    final age = d.policeAgeMs;
    final sealed = d.sealedLeft > 0;
    if (age == null && !sealed) return;

    final done = age == null;
    final a = age ?? 1000000;
    final leaveU = (!sealed && !done)
        ? _c01((a - kPoliceLeaveStartMs) / (kPoliceTotalMs - 200 - kPoliceLeaveStartMs))
        : 0.0;
    final tapeA = 1 - leaveU;
    final tp = _c01((a - kPoliceTapeStartMs) / kPoliceTapeMs);
    const cy = 278.0;
    final sealImpact = kPoliceTapeEndMs + 500;
    final sealU = done ? 1.0 : _c01((a - sealImpact) / 420.0);
    final dark = done
        ? 1.0
        : _c01((a - kPoliceTapeEndMs) / 900.0) * (1 - leaveU);

    // ---- posisi mobil + gaya mengerem
    var carX = 152.0;
    var driveU = 1.0;
    var pitch = 0.0;
    if (a < kPoliceDriveMs) {
      driveU = a / kPoliceDriveMs;
      carX = _lerp(-90, 152, 1 - math.pow(1 - driveU, 3).toDouble());
      if (driveU > 0.7) {
        pitch = math.sin(_c01((driveU - 0.7) / 0.3) * math.pi) * 0.045;
      }
    }
    carX += leaveU * leaveU * 520;
    final carHere = carX > -70 && carX < 470;

    // ---- sorot sirine di tanah + berkas yang menyapu dinding
    final lightsOn = !done && leaveU < 0.9;
    final redOn = math.sin(t * 18) > 0;
    if (lightsOn && carHere) {
      _p
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [
            (redOn ? const Color(0xFFFF1744) : const Color(0xFF2979FF))
                .withValues(alpha: 0.34),
            (redOn ? const Color(0xFFFF1744) : const Color(0xFF2979FF))
                .withValues(alpha: 0),
          ],
        ).createShader(
            Rect.fromCenter(center: Offset(carX, cy + 2), width: 150, height: 34));
      canvas.drawOval(
          Rect.fromCenter(center: Offset(carX, cy + 2), width: 150, height: 34), _p);
      _p.shader = null;
      _policeBeams(canvas, Offset(carX + 1, cy - 21), t, _c01(1 - leaveU * 1.2));
    }

    // kilau sirine menyapu fasad rumah
    if (carX > 40 && leaveU < 0.7 && !done) {
      _p
        ..style = PaintingStyle.fill
        ..color = (redOn ? const Color(0xFFFF1744) : const Color(0xFF2979FF))
            .withValues(alpha: 0.10);
      canvas.drawRect(
        Rect.fromLTWH(_bl - 10, _roofY - 6, 210, _gy - _roofY + 8),
        _p,
      );
    }

    // fasad meredup setelah disegel (rumah "dimatikan")
    if (dark > 0.01) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF0B1220).withValues(alpha: 0.2 * dark);
      canvas.drawRect(
        Rect.fromLTWH(_bl - 8, _roofY - 24, 206, _gy - _roofY + 26),
        _p,
      );
    }

    // ---- jejak ban & debu saat mengerem
    if (!done && a < kPoliceLeaveStartMs) {
      final ta = _c01((driveU - 0.55) / 0.3) * 0.38;
      if (ta > 0.01) {
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = Colors.black.withValues(alpha: ta);
        final x0 = _lerp(-90, 152, 1 - math.pow(1 - 0.55, 3).toDouble());
        canvas.drawLine(Offset(x0, cy - 1.2), Offset(carX - 13, cy - 1.2), _p);
        canvas.drawLine(Offset(x0, cy + 2.2), Offset(carX + 11, cy + 2.2), _p);
        _p
          ..style = PaintingStyle.fill
          ..strokeCap = StrokeCap.butt;
      }
    }
    if (driveU < 1) {
      for (var k = 0; k < 7; k++) {
        final ph = _c01((driveU - 0.5 - k * 0.02) / 0.5);
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFCFD8DC)
              .withValues(alpha: _c01((1 - ph) * ph * 2.2) * 0.55);
        canvas.drawCircle(
            Offset(carX - 24 - k * 6 - ph * 10, cy - 2 - k * 1.8 - ph * 6),
            2.4 + k * 1.0 + ph * 3,
            _p);
      }
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
      // pita bergoyang halus ditiup angin setelah terpasang
      _tapeStrip(canvas, tapes[i].$1, tapes[i].$2, tp * 4 - i, tapeA);
    }

    // ---- segel di pintu
    _doorSeal(canvas, sealU, t);

    // ---- mobil (menunduk saat mengerem)
    if (carHere) {
      canvas.save();
      canvas.translate(carX, cy);
      canvas.rotate(pitch);
      canvas.translate(-carX, -cy);
      _policeCar(canvas, carX, cy, t, lights: lightsOn);
      canvas.restore();
    }

    // ---- petugas
    final offA = _c01(1 - leaveU * 3);
    final walk = math.sin(t * 16) * 3.2;
    final emerge = (a - kPoliceDriveMs) / 700.0;

    if (offA > 0 && (a >= kPoliceDriveMs || done)) {
      // Pemeriksa (peran 2): turun, menyorot sampah, lalu menuju pintu
      Offset f2;
      var sw2 = 0.0;
      var dir2 = 1.0;
      if (done) {
        f2 = const Offset(188, 254);
      } else if (a < kPoliceDriveMs + 700) {
        final u = _ease(_c01(emerge));
        f2 = Offset(_lerp(160, 226, u), _lerp(274, 262, u));
        sw2 = walk;
        dir2 = 1.0;
      } else if (a < kPoliceTapeStartMs) {
        // menyorot tumpukan sampah kiri-kanan sambil mencatat
        f2 = const Offset(226, 262);
        dir2 = math.sin(t * 1.3) > 0 ? 1.0 : -1.0;
      } else if (a < sealImpact - 600) {
        final u = _ease((a - kPoliceTapeStartMs) / (sealImpact - 600 - kPoliceTapeStartMs));
        f2 = Offset(_lerp(226, 188, u), _lerp(262, 254, u));
        sw2 = u < 1 ? walk : 0;
        dir2 = u < 1 ? -1.0 : 1.0;
      } else {
        f2 = const Offset(188, 254);
      }
      _officer(canvas, f2, swing: sw2, alpha: offA, dir: dir2, role: 2, t: t);

      // senter: berkas ke tanah saat memeriksa (tidak di keadaan akhir)
      if (!done && a >= kPoliceDriveMs + 700 && a < kPoliceTapeStartMs) {
        final tip = f2.translate(dir2 * 7, -12.5);
        final sweep = math.sin(t * 2.6);
        final target = Offset(f2.dx + dir2 * (40 + 38 * sweep.abs()), 256);
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFFF59D).withValues(alpha: 0.22 * offA);
        canvas.drawPath(
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(target.dx - 7, target.dy + 4)
            ..lineTo(target.dx + 7, target.dy + 4)
            ..close(),
          _p,
        );
        _p.color = const Color(0xFFFFF59D).withValues(alpha: 0.35 * offA);
        canvas.drawOval(
            Rect.fromCenter(center: Offset(target.dx, target.dy + 3), width: 16, height: 4),
            _p);
      }

      // Komandan (peran 1): pidato megafon lalu membentang pita
      Offset f1;
      var sw1 = 0.0;
      var dir1 = 1.0;
      var role1 = 1;
      if (done) {
        f1 = const Offset(98, 250);
        role1 = 0;
      } else if (a < kPoliceDriveMs + 700) {
        final u = _ease(_c01(emerge));
        f1 = Offset(_lerp(146, 118, u), _lerp(274, 264, u));
        sw1 = walk;
        dir1 = 1.0;
      } else if (a < kPoliceTapeStartMs) {
        f1 = const Offset(118, 264); // berdiri berpidato menghadap rumah
        dir1 = 1.0;
      } else if (tp < 1) {
        final seg = math.min(3, (tp * 4).floor());
        final su = tp * 4 - seg;
        final tt = tapes[seg];
        final fromX = seg == 0 ? 118.0 : tt.$1.dx;
        f1 = Offset(_lerp(fromX, tt.$2.dx, _ease(su)), 250);
        dir1 = tt.$2.dx >= tt.$1.dx ? 1.0 : -1.0;
        sw1 = walk;
        role1 = 0;
      } else {
        f1 = const Offset(98, 250);
        dir1 = 1.0;
        role1 = 0;
      }
      _officer(canvas, f1, swing: sw1, alpha: offA, dir: dir1, role: role1, t: t);

      // gelombang suara megafon
      if (!done && a >= kPoliceDriveMs + 700 && a < kPoliceTapeStartMs) {
        final k = _c01(math.min((a - kPoliceDriveMs - 700) / 250.0,
            (kPoliceTapeStartMs - a) / 300.0));
        _megaWaves(canvas, f1.translate(dir1 * 17, -19.2), dir1, t, k);
      }
    }

    // ---- hantaman segel: kilat, cincin kejut, serpihan kertas
    if (!done && a >= sealImpact && a < sealImpact + 700) {
      final q = (a - sealImpact) / 700.0;
      final c = const Offset(201, 224);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * (1 - q)
        ..color = const Color(0xFFFFD600).withValues(alpha: (1 - q) * 0.9);
      canvas.drawCircle(c, 6 + q * 46, _p);
      _p
        ..strokeWidth = 1.6 * (1 - q)
        ..color = Colors.white.withValues(alpha: (1 - q) * 0.8);
      canvas.drawCircle(c, 3 + q * 30, _p);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFF8E1).withValues(alpha: (1 - q) * 0.9);
      for (var k = 0; k < 9; k++) {
        final ang = -math.pi + k * (math.pi * 2 / 9) + 0.3;
        final dist = 8 + q * (22 + (k % 3) * 9);
        canvas.save();
        canvas.translate(c.dx + math.cos(ang) * dist, c.dy + math.sin(ang) * dist + q * q * 14);
        canvas.rotate(q * 8 + k);
        canvas.drawRect(const Rect.fromLTWH(-1.4, -0.9, 2.8, 1.8), _p);
        canvas.restore();
      }
      if (q < 0.18) {
        _p.color = Colors.white.withValues(alpha: (1 - q / 0.18) * 0.42);
        canvas.drawRect(_view, _p);
      }
    }

    // ---- teks
    const bannerPos = Offset(200, _gy - 56);
    if (!done) {
      if (a >= 500 && a < 2500) {
        final env = _c01(math.min((a - 500) / 300.0, (2500 - a) / 400.0));
        _drawBannerText(canvas, 'SIDAK DINAS TIBA!', bannerPos,
            const Color(0xFFFF5252),
            scale: 1.15 + 0.1 * math.sin(t * 14), alpha: env);
      }
      if (a >= kPoliceDriveMs + 900 && a < kPoliceTapeStartMs) {
        final env = _c01(math.min((a - kPoliceDriveMs - 900) / 300.0,
            (kPoliceTapeStartMs - a) / 350.0));
        _drawBannerText(canvas, 'HARAP KELUAR! KOST DISIDAK!', bannerPos,
            const Color(0xFF80D8FF),
            scale: 1.0 + 0.08 * math.sin(t * 16), alpha: env);
      }
      if (a >= sealImpact && a < sealImpact + 1300) {
        final q = (a - sealImpact) / 1300.0;
        final env = _c01(math.min(q * 8, (1 - q) * 3.5));
        _drawBannerText(canvas, 'DISEGEL!', bannerPos,
            const Color(0xFFFFD600),
            scale: 0.8 + 0.75 * _easeOutBack(math.min(1.0, q * 4)),
            alpha: env);
      }
    }
    if (sealed && (done || a >= sealImpact + 1300)) {
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
        _sitter(canvas, xs[k], 271, k, t, _shirts[(k + 1) % _shirts.length], dir,
            look: _resLook(_shirts[(k + 1) % _shirts.length]));
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
        look: _resLook(_shirts[_hh(_resRoom(k) + 3) % _shirts.length]),
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
    _p.color = d.style?.doorColor ?? const Color(0xFF6D4C41);
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

  /// Tampilan penghuni rumah ini: kustomisasi pemain, atau null (bawaan).
  KostLook? _resLook(Color fallbackShirt) {
    final st = d.style;
    if (st == null || !st.hasLook) return null;
    return st.look(fallbackShirt: fallbackShirt);
  }

  void _resident(
      Canvas canvas,
      double x,
      double y, {
        required Color shirt,
        KostLook? look,
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
    final skin = look?.skin ?? const Color(0xFFE0AC84);
    if (look != null) shirt = look.shirt;

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
    if (look != null) {
      canvas.save();
      canvas.translate(0, -17.5);
      canvas.scale(3.2);
      paintKostHeadGear(canvas, _p, look);
      canvas.restore();
      _p.style = PaintingStyle.fill;
    }

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
      double dir, {KostLook? look}) {
    if (look != null) shirt = look.shirt;
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
    _p.color = look?.skin ?? const Color(0xFFE0AC84);
    canvas.drawCircle(const Offset(1.2, -14.2), 3.2, _p);
    if (look != null) {
      canvas.save();
      canvas.translate(1.2, -14.2);
      canvas.scale(3.2);
      paintKostHeadGear(canvas, _p, look);
      canvas.restore();
      _p.style = PaintingStyle.fill;
    }
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
  //
  // Semua kendaraan digambar di "lapisan dunia" (di atas semua rumah) supaya
  // bisa melintasi batas rumah dan tidak tertutup bangunan tetangga. Truk
  // selalu MASUK dari luar layar dan KELUAR ke luar layar: tidak ada lagi
  // muncul / hilang mendadak. Mode satu rumah memakai jalur yang sama lewat
  // [_drawTruck]; mode jalan lewat [paintStreetTruck].

  static const double _roadY = 297.0; // garis jalan (koordinat rumah)
  static const double _parkX = 318.0; // titik parkir truk angkut

  /// Mode satu rumah. (Mode jalan: digambar oleh [paintStreetTruck].)
  void _drawTruck(Canvas canvas, double t) {
    if (_street) return;
    _truckLayer(canvas, t, _vl, _vr);
  }

  /// Dipanggil KostStreetPainter SETELAH semua rumah digambar.
  /// [view] = jangkauan layar dalam koordinat rumah ini. [thiefDx] = selisih
  /// posisi dunia rumah pembajak terhadap rumah ini (null bila tak diketahui).
  void paintStreetTruck(Canvas canvas, double t, Rect view,
      {double? thiefDx, bool thiefHauling = false}) {
    final sl = _vl, sr = _vr, st = _vt, sb = _vb;
    _street = true;
    _setView(view);
    _truckLayer(canvas, t, view.left, view.right,
        thiefDx: thiefDx, thiefHauling: thiefHauling);
    _vl = sl;
    _vr = sr;
    _vt = st;
    _vb = sb;
  }

  /// Id pembajak dari adegan bajak sisi KORBAN yang sedang aktif (atau null).
  String? activeHijackThief() {
    final f = _hijackFx();
    if (f == null || f.amount.round() == 1) return null;
    return f.peerId;
  }

  KostFx? _hijackFx() {
    KostFx? best;
    for (final f in d.fx) {
      if (f.type != FxType.hijack) continue;
      final a = f.age;
      final dur = f.durMs > 0 ? f.durMs : hijackDurationMs(1);
      if (a < 0 || a > dur) continue;
      if (best == null || a < best.age) best = f;
    }
    return best;
  }

  void _truckLayer(Canvas canvas, double t, double vl, double vr,
      {double? thiefDx, bool thiefHauling = false}) {
    final hj = _hijackFx();
    final hp = d.haulProgress;
    if (hj != null) {
      final victim = hj.amount.round() != 1;
      if (victim) {
        // Korban: seluruh adegan (van datang, truk direbut, kabur ke rumah
        // pembajak) digambar dari sini; truk angkut biasa digantikan.
        _hijackWorld(
          canvas,
          t,
          hj,
          victimX: _parkX,
          thiefX: _parkX + (thiefDx ?? (_street ? -1400.0 : -1500.0)),
          vl: vl,
          vr: vr,
          thiefHauling: thiefHauling,
        );
        return;
      }
      // Pembajak: mode jalan sudah digambar oleh adegan rumah korban. Mode
      // satu rumah: gambar kedatangan truk rampasan dari arah korban.
      if (!_street) {
        _hijackWorld(
          canvas,
          t,
          hj,
          victimX: _parkX + 1500,
          thiefX: _parkX,
          vl: vl,
          vr: vr,
          thiefHauling: hp != null,
        );
      }
    }
    if (hp == null) return;
    _haulTruck(canvas, t, hp, vl, vr);
  }

  /// Siklus truk angkut (hp 0..1):
  ///  0.00-0.20  datang dari luar layar, melambat & mengerem (hidung menunduk)
  ///  0.20-0.28  parkir, pegas bodi reda, petugas turun dari bak belakang
  ///  0.28-0.76  bekerja: pungut -> lempar ke hopper -> pemadat bekerja
  ///  0.76-0.82  petugas naik lagi
  ///  0.82-1.00  siap jalan, tancap gas, melaju keluar layar (arah rute sama)
  void _haulTruck(Canvas canvas, double t, double hp, double vl, double vr) {
    const arriveEnd = 0.20;
    const leaveStart = 0.82;
    // Truk masuk dari kanan dan terus ke kiri: titik awal/akhir ada di luar
    // jangkauan layar (maks 1000 satuan agar kecepatan tetap wajar).
    final inX = math.min(math.max(vr + 110, _parkX + 220), _parkX + 1000);
    final outX = math.max(math.min(vl - 110, _parkX - 220), _parkX - 1000);
    // Kamera sangat jauh: ujung rute masih terlihat -> pudar, bukan pop.
    final inVisible = inX < vr + 40;
    final outVisible = outX > vl - 40;

    var x = _parkX;
    var alpha = 1.0;
    var lean = 0.0;
    var brake = false;
    var moving = false;

    if (hp < arriveEnd) {
      final u = hp / arriveEnd;
      x = _lerp(inX, _parkX, _easeOut3(u));
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
      x = _lerp(_parkX, outX, _easeIn(go));
      if (outVisible) alpha = 1 - _ease((go - 0.7) / 0.3);
      lean = 0.03 * _ease(go / 0.2) * (1 - _ease((go - 0.2) / 0.4));
      moving = go > 0.02;
    }

    final vis = _ease((hp - 0.215) / 0.06) * (1 - _ease((hp - 0.755) / 0.06));
    final (double, double) lr = vis > 0.6 ? _workLid(t) : (0.0, 0.0);
    final bob = moving ? math.sin(t * 24) * 0.7 : math.sin(t * 38) * 0.22;

    _fadeLayer(
      canvas,
      Rect.fromLTRB(x - 130, _roadY - 90, x + 130, _roadY + 16),
      alpha,
          () {
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
      },
    );

    if (vis > 0.01) _workers(canvas, t, vis: vis);
  }

  /// (bukaan tutup hopper, gerak pelat pemadat) mengikuti ritme petugas.
  (double, double) _workLid(double t) {
    var lid = 0.0, ram = 0.0;
    for (var i = 0; i < 2; i++) {
      final ph = (t * 0.9 + i * 0.5) % 1.0;
      if (ph >= 0.5 && ph < 0.66) {
        lid = math.max(lid, math.sin((ph - 0.5) / 0.16 * math.pi));
      }
      if (ph >= 0.6 && ph < 0.86) {
        ram = math.max(ram, math.sin((ph - 0.6) / 0.26 * math.pi));
      }
    }
    return (lid, ram);
  }

  /// Gambar [draw] dengan transparansi [a] (tanpa layer bila a >= 1).
  void _fadeLayer(Canvas canvas, Rect bounds, double a, void Function() draw) {
    final al = _c01(a);
    if (al <= 0.02) return;
    if (al < 1) {
      canvas.saveLayer(bounds, Paint()..color = Color.fromRGBO(0, 0, 0, al));
    }
    draw();
    if (al < 1) canvas.restore();
  }

  /// Bodi truk sampah, titik asal = tengah bawah (di tanah), menghadap KIRI.
  /// Pemanggil mengatur translate / scale (mirror) dan transparansi.
  void _truckBody(
      Canvas canvas,
      double t, {
        double wheelA = 0,
        double lean = 0,
        bool moving = false,
        bool brake = false,
        double lid = 0,
        double ram = 0,
        bool stolen = false,
        bool thiefInCab = false,
        double bob = 0,
      }) {
    // bayangan menempel di tanah
    _p
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.25);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 88, height: 6), _p);

    canvas.save();
    canvas.translate(0, bob);
    canvas.rotate(lean);

    // sorot lampu depan
    _p.color = const Color(0xFFFFF59D).withValues(alpha: 0.22);
    canvas.drawPath(
      Path()
        ..moveTo(-40, -15)
        ..lineTo(-88, -3)
        ..lineTo(-88, -24)
        ..close(),
      _p,
    );

    // asap knalpot (kecil saat diam, tebal saat melaju)
    final puffs = moving ? 4 : 2;
    for (var k = 0; k < puffs; k++) {
      final ph = (t * (moving ? 1.6 : 0.8) + k / puffs) % 1.0;
      final base = stolen ? const Color(0xFF424242) : const Color(0xFFBDBDBD);
      _p.color = base.withValues(alpha: (1 - ph) * (moving ? 0.5 : 0.22));
      canvas.drawCircle(
          Offset(44 + ph * 24, -6 - ph * 10), 3 + ph * (moving ? 6.5 : 4), _p);
    }

    // bak
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

    // pelat pemadat bergeser saat memadatkan sampah
    if (ram > 0.01) {
      _p.color = const Color(0xFF1B5E20).withValues(alpha: 0.75);
      canvas.drawRect(Rect.fromLTWH(_lerp(31, 21, ram), -34, 3, 24), _p);
    }

    // hopper + tutupnya (engsel di sisi belakang)
    _p.color = const Color(0xFF2E5E3A);
    canvas.drawRect(const Rect.fromLTWH(32, -36, 8, 11), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF1B3B25);
    canvas.drawLine(const Offset(40, -36),
        Offset(40 - 8 * math.cos(lid), -36 - 8 * math.sin(lid)), _p);
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;

    // kabin
    _p.color = stolen ? const Color(0xFFB71C1C) : const Color(0xFF2E9E5B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-40, -30, 24, 24), const Radius.circular(4)),
      _p,
    );
    _p.color = const Color(0xFFB3E5FC);
    canvas.drawRect(const Rect.fromLTWH(-38, -27, 12, 10), _p);
    _p.color = Colors.white.withValues(alpha: 0.35);
    canvas.drawRect(const Rect.fromLTWH(-37, -26, 4, 8), _p);
    if (thiefInCab) {
      _p.color = const Color(0xFF212121);
      canvas.drawCircle(const Offset(-32, -22), 3.8, _p);
      _p.color = Colors.white;
      canvas.drawCircle(const Offset(-33.4, -22.5), 0.8, _p);
      canvas.drawCircle(const Offset(-30.6, -22.5), 0.8, _p);
    }
    _p.color = const Color(0xFF212121);
    canvas.drawRect(const Rect.fromLTWH(-42, -22, 3, 2), _p);
    _p.color = const Color(0xFFFFF176);
    canvas.drawRect(const Rect.fromLTWH(-41, -15, 3, 4), _p);

    // lampu rem belakang
    _p.color = brake ? const Color(0xFFFF1744) : const Color(0xFF8E1B1B);
    canvas.drawRect(const Rect.fromLTWH(40, -17, 2.5, 5), _p);
    if (brake) {
      _p.color = const Color(0xFFFF1744).withValues(alpha: 0.28);
      canvas.drawCircle(const Offset(43, -14.5), 6, _p);
    }

    // sirene: oranye saat dinas, strobo merah-biru saat dibajak
    if (stolen) {
      final blink = math.sin(t * 18) > 0;
      final c = blink ? const Color(0xFFFF1744) : const Color(0xFF2979FF);
      _p.color = c.withValues(alpha: 0.35);
      canvas.drawCircle(const Offset(-29, -33), 10, _p);
      _p.color = c;
      canvas.drawRect(const Rect.fromLTWH(-32, -33, 6, 3), _p);
    } else {
      final siren = 0.5 + 0.5 * math.sin(t * 14);
      _p.color = const Color(0xFFFFA000).withValues(alpha: 0.3 + 0.5 * siren);
      canvas.drawCircle(const Offset(-29, -33), 6 + siren * 4, _p);
      _p.color = const Color(0xFFFFCA28);
      canvas.drawRect(const Rect.fromLTWH(-32, -33, 6, 3), _p);
    }

    // roda (berputar sesuai jarak tempuh)
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
        ..strokeCap = StrokeCap.butt
        ..color = const Color(0xFF9E9E9E);
      for (var s = 0; s < 2; s++) {
        final a = wheelA + s * math.pi / 2;
        canvas.drawLine(
          Offset(wx + math.cos(a) * 5.2, -6 + math.sin(a) * 5.2),
          Offset(wx - math.cos(a) * 5.2, -6 - math.sin(a) * 5.2),
          _p,
        );
      }
      _p.style = PaintingStyle.fill;
    }
    canvas.restore();
  }

  /// Dua petugas angkut. [vis] 0..1: keluar/masuk lewat bak belakang truk
  /// (muncul sambil berjalan, bukan tiba-tiba). [freezeT] membekukan langkah
  /// pada waktu tertentu, [shock] = pose kaget, [idle] = tak membawa kantong,
  /// [dx] = pergeseran (berjalan menjauh), [alpha] = pudar.
  void _workers(
      Canvas canvas,
      double t, {
        double vis = 1,
        double alpha = 1,
        double? freezeT,
        double shock = 0,
        bool idle = false,
        double dx = 0,
      }) {
    final a = vis * alpha;
    if (a <= 0.02) return;
    final tt = freezeT ?? t;
    for (var i = 0; i < 2; i++) {
      final phase = (tt * 0.9 + i * 0.5) % 1.0;
      final tri = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
      final baseX = _lerp(382, 352, tri) + dx;
      final x = vis < 1 ? _lerp(_parkX + 38, baseX, vis) : baseX;
      const y = 270.0;
      final carrying = !idle && phase < 0.5;
      final swing = shock > 0.05
          ? math.sin(t * 22 + i) * 2.5 * shock
          : (idle ? 0.0 : math.sin(tt * 10 + i) * 2);

      if (a < 1) {
        canvas.saveLayer(
          Rect.fromCenter(center: Offset(x, y - 14), width: 56, height: 60),
          Paint()..color = Color.fromRGBO(0, 0, 0, _c01(a)),
        );
      }

      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFF37474F);
      canvas.drawLine(Offset(x, y - 11), Offset(x, y - 4), _p);
      canvas.drawLine(Offset(x, y - 4), Offset(x - swing, y), _p);
      canvas.drawLine(Offset(x, y - 4), Offset(x + swing, y), _p);
      _p.color = const Color(0xFFFF8F00);
      if (shock > 0.2) {
        canvas.drawLine(Offset(x, y - 10), Offset(x - 4, y - 17), _p);
        canvas.drawLine(Offset(x, y - 10), Offset(x + 4, y - 17), _p);
      } else {
        canvas.drawLine(
            Offset(x, y - 10), Offset(x + (carrying ? 4 : 3), y - 15), _p);
      }
      _p.style = PaintingStyle.fill;
      _p.color = const Color(0xFFE0AC84);
      canvas.drawCircle(Offset(x, y - 14), 3, _p);
      _p.color = const Color(0xFFFF8F00);
      canvas.drawRect(Rect.fromLTWH(x - 3.5, y - 18, 7, 2.5), _p);

      if (shock > 0.2) {
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = const Color(0xFFFF5252).withValues(alpha: _c01(shock));
        canvas.drawLine(Offset(x, y - 31), Offset(x, y - 25), _p);
        _p.style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y - 22.5), 1.1, _p);
      }

      if (carrying) {
        // mengangkat kantong dari tumpukan
        final lift = _ease(phase / 0.08);
        _bag(canvas, Offset(x + 4, _lerp(y - 5, y - 20, lift)), 900 + i,
            scale: 0.7);
      } else if (!idle && phase >= 0.5 && phase < 0.64) {
        // melempar kantong ke mulut hopper (tidak lenyap begitu saja)
        final q = (phase - 0.5) / 0.14;
        _bag(
          canvas,
          Offset(
            _lerp(x + 4, _parkX + 35, q),
            _lerp(y - 20, 263, q) - math.sin(q * math.pi) * 9,
          ),
          900 + i,
          scale: 0.7 * (1 - 0.4 * q),
        );
      }

      if (a < 1) canvas.restore();
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

  // ======================================================================
  //  RENOVASI
  //  - Tambah kamar : perancah + tukang (bata -> plester -> cat -> jadi)
  //  - Tambah lantai: atap diangkat derek, rangka beton tumbuh, dinding naik,
  //                   lalu atap diturunkan kembali (debu & guncangan)
  // ======================================================================

  /// Kamar baru yang dibangun adalah kamar pertama di lantai berikutnya.
  bool get _isFloorBuild {
    final n = d.rooms - 1;
    return n > 0 && n % 4 == 0 && n < 12;
  }

  int get _buildDurMs => _isFloorBuild ? 5200 : 2600;
  double? get _buildP => _fxProgress(FxType.build, _buildDurMs);

  static const double _roofHover = 30;

  /// Selisih tinggi atap (relatif posisi akhir) selama tambah lantai.
  double _roofDy(double fp) {
    if (fp < 0.05) return _fh;
    if (fp < 0.17) return _lerp(_fh, -_roofHover, _ease((fp - 0.05) / 0.12));
    if (fp < 0.72) return -_roofHover;
    if (fp < 0.85) {
      final u = (fp - 0.72) / 0.13;
      return _lerp(-_roofHover, 0, u * u);
    }
    final u = (fp - 0.85) / 0.09;
    if (u >= 1) return 0;
    return -3.2 * (1 - u) * math.sin(u * math.pi * 2.5).abs();
  }

  /// Ayunan atap yang tergantung di kait derek (radian).
  double _roofSway(double fp, double t) {
    if (fp < 0.05 || fp >= 0.85) return 0;
    final amp = math.min(1.0, (fp - 0.05) / 0.08) *
        math.min(1.0, (0.85 - fp) / 0.10);
    return math.sin(t * 2.3) * 0.03 * amp;
  }

  /// Titik pada atap (koordinat akhir) setelah terangkat & berayun.
  Offset _roofPt(Offset local, double fp, double t) {
    final dy = _roofDy(fp);
    final sw = _roofSway(fp, t);
    final pivot = Offset(200, _roofY - 90);
    final p = Offset(local.dx, local.dy + dy) - pivot;
    final c = math.cos(sw), s = math.sin(sw);
    return pivot + Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c);
  }

  void _sparkle(Canvas canvas, Offset c, double r, Color col, double rot) {
    if (r <= 0.2) return;
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final rr = i.isEven ? r : r * 0.28;
      final a = rot - math.pi / 2 + i * math.pi / 4;
      final x = c.dx + math.cos(a) * rr;
      final y = c.dy + math.sin(a) * rr;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    _p
      ..style = PaintingStyle.fill
      ..color = col;
    canvas.drawPath(path, _p);
  }

  // ------------------------------------------------ kamar sedang direnovasi

  /// Dinding bata yang naik lapis demi lapis (jendela tetap dibiarkan terbuka).
  void _renovBrickWall(Canvas canvas, Rect r, double frac, int idx) {
    final wall =
    Rect.fromLTRB(r.left + 3.5, r.top + 3, r.right - 3.5, r.bottom - 3);
    final topY = wall.bottom - wall.height * frac;
    final win = Rect.fromLTWH(r.left + 9, r.top + 9, r.width - 18, 26);
    canvas.save();
    canvas.clipPath(Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTRB(wall.left, topY, wall.right, wall.bottom)),
      Path()..addRect(win.inflate(1.4)),
    ));
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFB4654A);
    canvas.drawRect(wall, _p);
    const bh = 4.2;
    var row = 0;
    for (var y = wall.bottom; y > topY - bh; y -= bh, row++) {
      for (var x = wall.left + (row.isOdd ? 4.0 : 0.0); x < wall.right; x += 8) {
        final tone = _hh(idx * 131 + row * 17 + x.toInt()) % 5;
        _p.color = tone == 0
            ? const Color(0xFF9E5540)
            : (tone == 1 ? const Color(0xFFC77455) : const Color(0xFFB4654A));
        canvas.drawRect(Rect.fromLTWH(x + 0.4, y - bh + 0.4, 7.2, bh - 0.8), _p);
      }
    }
    canvas.restore();
    // adukan basah di barisan teratas
    if (frac < 1) {
      _p.color = const Color(0xFF9E9E9E);
      canvas.drawRect(
          Rect.fromLTWH(wall.left, topY - 1.4, wall.width, 2.0), _p);
    }
  }

  /// Tahap akhir: plester kelabu menyapu -> cat/tampilan kamar jadi menyapu ->
  /// jendela berkilau. Sama dipakai tambah kamar & tambah lantai.
  void _renovFinish(Canvas canvas, Rect r, int idx, double t,
      {required double plaster, required double paint, required double fin}) {
    final win = Rect.fromLTWH(r.left + 9, r.top + 9, r.width - 18, 26);
    if (plaster > 0) {
      final x = math.min(r.left + r.width * plaster, r.right - 3.5);
      canvas.save();
      canvas.clipPath(Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTRB(r.left + 3.5, r.top + 3, x, r.bottom - 3)),
        Path()..addRect(win.inflate(1.4)),
      ));
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFCFC9BD);
      canvas.drawRect(r, _p);
      _p.color = Colors.white.withValues(alpha: 0.2);
      for (var k = 0; k < 4; k++) {
        canvas.drawRect(
            Rect.fromLTWH(r.left + 4, r.top + 8 + k * 9.0, r.width - 8, 2.2), _p);
      }
      canvas.restore();
    }
    if (paint > 0) {
      final x = r.left + (r.width + 2) * paint;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(r.left - 1, r.top - 1, x, r.bottom + 1));
      _drawRoom(canvas, r, idx, t);
      canvas.restore();
      if (paint < 1) {
        _p
          ..style = PaintingStyle.fill
          ..color = Colors.white.withValues(alpha: 0.32);
        canvas.drawRect(Rect.fromLTWH(x - 3, r.top, 3, r.height), _p);
      }
    }
    if (fin > 0 && fin < 1) {
      final a = math.sin(fin * math.pi);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFF59D).withValues(alpha: a * 0.28);
      canvas.drawRect(win.inflate(4), _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFEA00).withValues(alpha: a * 0.8);
      canvas.drawRect(r.inflate(1.5), _p);
      _p.style = PaintingStyle.fill;
      final sc = const Color(0xFFFFFDE7).withValues(alpha: a);
      _sparkle(canvas, win.topLeft + const Offset(4, 4), 5 * a, sc, fin * 2);
      _sparkle(canvas, win.topRight + const Offset(-5, 6), 4 * a, sc, -fin * 2);
      _sparkle(canvas, win.center + const Offset(2, 3), 3.2 * a, sc, fin);
    }
  }

  /// Kamar baru (lantai yang sama): rangka mentah -> bata -> plester -> cat.
  void _drawRoomUnderRenovation(
      Canvas canvas, Rect r, int idx, double t, double p) {
    final pulse = (p > 0.72 && p < 0.88)
        ? 0.035 * math.sin((p - 0.72) / 0.16 * math.pi)
        : 0.0;
    canvas.save();
    if (pulse != 0) {
      canvas.translate(r.center.dx, r.bottom);
      canvas.scale(1 + pulse, 1 + pulse * 1.4);
      canvas.translate(-r.center.dx, -r.bottom);
    }
    _emptyShell(canvas, r, idx, t);
    if (p < 0.12) _scaffold(canvas, r);
    final brick = _ease(_c01((p - 0.08) / 0.30));
    if (brick > 0) _renovBrickWall(canvas, r, brick, idx);
    _renovFinish(
      canvas,
      r,
      idx,
      t,
      plaster: _ease(_c01((p - 0.38) / 0.12)),
      paint: _ease(_c01((p - 0.50) / 0.22)),
      fin: _c01((p - 0.72) / 0.16),
    );
    canvas.restore();
  }

  // ----------------------------------------------- lantai baru dibangun

  /// Satu sel di lantai baru: kolom beton tumbuh, balok menyusul, dinding naik
  /// dari bawah; kamar baru lalu diplester & dicat. Keadaan akhirnya identik
  /// dengan gambar normal (kamar jadi / rangka mentah).
  void _newFloorCell(Canvas canvas, Rect r, int idx, double t, double fp) {
    final col = idx % 4;
    final newest = idx == d.rooms - 1;
    final wallP = _ease(_c01((fp - 0.38) / 0.20));
    if (wallP > 0) {
      canvas.save();
      canvas.clipRect(
          Rect.fromLTRB(r.left, r.bottom - r.height * wallP, r.right, r.bottom));
      _emptyShell(canvas, r, idx, t);
      canvas.restore();
      if (wallP < 1) {
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF9E9E9E);
        canvas.drawRect(
            Rect.fromLTWH(
                r.left + 4, r.bottom - r.height * wallP - 1.6, r.width - 8, 2.2),
            _p);
      }
    }
    if (newest) {
      _renovFinish(
        canvas,
        r,
        idx,
        t,
        plaster: _ease(_c01((fp - 0.58) / 0.07)),
        paint: _ease(_c01((fp - 0.64) / 0.10)),
        fin: _c01((fp - 0.74) / 0.12),
      );
    }
    // kolom beton tumbuh + besi tulangan
    final cp = _ease(_c01((fp - 0.17 - col * 0.028) / 0.15));
    if (cp > 0) {
      for (final cx in [r.left, r.right - 4.0]) {
        final h = r.height * cp;
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFB5B2AB);
        canvas.drawRect(Rect.fromLTWH(cx, r.bottom - h, 4, h), _p);
        _p.color = Colors.black.withValues(alpha: 0.18);
        canvas.drawRect(
            Rect.fromLTWH(cx + (cx == r.left ? 3.2 : 0), r.bottom - h, 0.8, h), _p);
        if (cp < 1) {
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9
            ..color = const Color(0xFF6D4C41);
          canvas.drawLine(Offset(cx + 1, r.bottom - h - 7),
              Offset(cx + 1, r.bottom - h), _p);
          canvas.drawLine(Offset(cx + 3, r.bottom - h - 5),
              Offset(cx + 3, r.bottom - h), _p);
          _p.style = PaintingStyle.fill;
        }
      }
    }
    // balok/pelat atas menyusul dari kiri ke kanan
    final slab = _ease(_c01((fp - 0.30 - col * 0.025) / 0.10));
    if (slab > 0 && cp > 0.9) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF7A7A7A);
      canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width * slab, 3.2), _p);
    }
  }

  // -------------------------------------------------- peralatan & tukang

  /// Perancah pipa baja: tiang, palang silang, dek papan, pagar & jaring.
  void _scaffoldRig(
      Canvas canvas, double xL, double xR, double yTop, double deckY) {
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFB0BEC5);
    canvas.drawLine(Offset(xL, _gy), Offset(xL, yTop), _p);
    canvas.drawLine(Offset(xR, _gy), Offset(xR, yTop), _p);
    _p.strokeWidth = 1.0;
    for (var y = _gy; y - _fh >= yTop - 1; y -= _fh) {
      final up = ((_gy - y) / _fh).round().isEven;
      canvas.drawLine(Offset(xL, up ? y : y - _fh), Offset(xR, up ? y - _fh : y), _p);
      canvas.drawLine(Offset(xL, y), Offset(xR, y), _p);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFF8F00);
      canvas.drawCircle(Offset(xL, y), 1.5, _p);
      canvas.drawCircle(Offset(xR, y), 1.5, _p);
      _p
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFFB0BEC5);
    }
    _p.style = PaintingStyle.fill;
    if (deckY < _gy - 2) {
      // jaring pengaman
      _p.color = const Color(0xFF43A047).withValues(alpha: 0.16);
      canvas.drawRect(Rect.fromLTRB(xL, deckY - 17, xR, deckY), _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = const Color(0xFF2E7D32).withValues(alpha: 0.35);
      for (var x = xL + 5; x < xR; x += 5) {
        canvas.drawLine(Offset(x, deckY - 17), Offset(x, deckY), _p);
      }
      for (var y = deckY - 13; y < deckY; y += 4) {
        canvas.drawLine(Offset(xL, y), Offset(xR, y), _p);
      }
      _p
        ..strokeWidth = 1.1
        ..color = const Color(0xFFB0BEC5);
      canvas.drawLine(Offset(xL, deckY - 17), Offset(xR, deckY - 17), _p);
      // dek papan kayu
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF8D6E4B);
      canvas.drawRect(Rect.fromLTRB(xL - 3, deckY, xR + 3, deckY + 3.2), _p);
      _p
        ..color = const Color(0xFF5D4037)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6;
      for (var x = xL; x < xR; x += 9) {
        canvas.drawLine(Offset(x, deckY), Offset(x, deckY + 3.2), _p);
      }
      _p.style = PaintingStyle.fill;
    }
  }

  /// Katrol material: ember bata naik-turun dari tanah ke dek kerja.
  void _hoist(Canvas canvas, double x, double topY, double deckTop, double t) {
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF90A4AE);
    canvas.drawLine(Offset(x - 10, topY + 3), Offset(x, topY + 3), _p);
    canvas.drawLine(Offset(x - 10, topY + 3), Offset(x - 10, topY + 9), _p);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF455A64);
    canvas.drawCircle(Offset(x, topY + 3), 3, _p);
    final u = (t * 0.45) % 1.0;
    final k = u < 0.5 ? _ease(u / 0.5) : 1 - _ease((u - 0.5) / 0.5);
    final by = _lerp(_gy - 9, deckTop, k);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = const Color(0xFF212121);
    canvas.drawLine(Offset(x, topY + 6), Offset(x, by - 5), _p);
    canvas.drawLine(Offset(x - 10, topY + 9), Offset(x - 5, by - 3), _p);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF78909C);
    canvas.drawPath(
      Path()
        ..moveTo(x - 6, by - 4)
        ..lineTo(x + 6, by - 4)
        ..lineTo(x + 4.5, by + 4)
        ..lineTo(x - 4.5, by + 4)
        ..close(),
      _p,
    );
    if (u < 0.5) {
      _p.color = const Color(0xFFB4654A);
      canvas.drawRect(Rect.fromLTWH(x - 4.5, by - 7, 9, 3.4), _p);
    }
  }

  /// Tukang berhelm: 0 = diam, 1 = bata, 2 = sendok plester, 3 = rol cat,
  /// 4 = palu. [arm] sudut lengan (rad, 0 = lurus ke depan, negatif = ke atas).
  void _worker(Canvas canvas, Offset foot, double dir,
      {double arm = 0.7,
        int tool = 0,
        bool cheer = false,
        double t = 0,
        Color vest = const Color(0xFFFF8F00)}) {
    canvas.save();
    canvas.translate(foot.dx, foot.dy);
    canvas.scale(dir, 1);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF37474F);
    canvas.drawRect(const Rect.fromLTWH(-3.2, -6, 2.6, 6), _p);
    canvas.drawRect(const Rect.fromLTWH(0.6, -6, 2.6, 6), _p);
    _p.color = const Color(0xFF212121);
    canvas.drawRect(const Rect.fromLTWH(-3.6, -1.4, 3.4, 1.4), _p);
    canvas.drawRect(const Rect.fromLTWH(0.6, -1.4, 3.4, 1.4), _p);
    _p.color = vest;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3.6, -14, 7.2, 8.4), const Radius.circular(1.6)),
      _p,
    );
    _p.color = Colors.white.withValues(alpha: 0.8);
    canvas.drawRect(const Rect.fromLTWH(-3.6, -10.5, 7.2, 1.2), _p);
    _p.color = const Color(0xFFFFCCBC);
    canvas.drawCircle(const Offset(0.4, -17.2), 3.0, _p);
    _p.color = const Color(0xFFFFD600);
    canvas.drawArc(
        Rect.fromCircle(center: const Offset(0.4, -17.6), radius: 3.5),
        math.pi,
        math.pi,
        true,
        _p);
    canvas.drawRect(const Rect.fromLTWH(-3.8, -17.8, 8.6, 1.1), _p);

    final ang = cheer ? -2.35 + math.sin(t * 12) * 0.35 : arm;
    canvas.save();
    canvas.translate(0.5, -12.6);
    canvas.rotate(ang);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round
      ..color = vest;
    canvas.drawLine(Offset.zero, const Offset(6.5, 0), _p);
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xFFFFCCBC);
    canvas.drawCircle(const Offset(6.5, 0), 1.5, _p);
    if (!cheer) {
      switch (tool) {
        case 1:
          _p.color = const Color(0xFFB4654A);
          canvas.drawRect(const Rect.fromLTWH(6.0, -2.6, 3.8, 2.4), _p);
          break;
        case 2:
          _p.color = const Color(0xFF6D4C41);
          canvas.drawRect(const Rect.fromLTWH(6.0, -0.6, 2.6, 1.2), _p);
          _p.color = const Color(0xFFCFD8DC);
          canvas.drawPath(
            Path()
              ..moveTo(8.4, -1.6)
              ..lineTo(12.4, 0)
              ..lineTo(8.4, 1.6)
              ..close(),
            _p,
          );
          break;
        case 3:
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9
            ..color = const Color(0xFF616161);
          canvas.drawLine(const Offset(6.5, 0), const Offset(9, -1.5), _p);
          _p
            ..style = PaintingStyle.fill
            ..color = _mix(d.wall, Colors.white, 0.25);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(8.2, -7.2, 3.2, 7.4), const Radius.circular(1.4)),
            _p,
          );
          break;
        case 4:
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = const Color(0xFF8D6E63);
          canvas.drawLine(const Offset(6.5, 0), const Offset(11, -3), _p);
          _p
            ..style = PaintingStyle.fill
            ..color = const Color(0xFF455A64);
          canvas.drawRect(const Rect.fromLTWH(9.6, -5.4, 4, 3), _p);
          break;
        default:
          break;
      }
    }
    canvas.restore();
    canvas.restore();
  }

  /// Debu halus yang naik dari titik kerja.
  void _siteDust(Canvas canvas, Offset o, double t, double k) {
    if (k <= 0) return;
    for (var i = 0; i < 4; i++) {
      final ph = (t * 1.1 + i * 0.25) % 1.0;
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFD7CCC8).withValues(alpha: 0.42 * k * (1 - ph));
      canvas.drawCircle(
          o + Offset(math.sin(i * 2.3 + ph * 3) * 7, -ph * 14), 2.5 + ph * 4, _p);
    }
  }

  /// Perlengkapan proyek di tanah: gerobak, tumpukan bata, pasir, semen, kerucut.
  void _siteProps(Canvas canvas, double t, bool big) {
    // tumpukan bata
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFB4654A);
    final bx = big ? 60.0 : 70.0;
    for (var row = 0; row < 3; row++) {
      canvas.drawRect(
          Rect.fromLTWH(bx + row * 1.5, _gy - 4 - row * 3.6, 22 - row * 3, 3.4), _p);
    }
    _p.color = const Color(0xFFE6DCCB).withValues(alpha: 0.7);
    for (var row = 0; row < 3; row++) {
      canvas.drawRect(
          Rect.fromLTWH(bx + row * 1.5, _gy - 4 - row * 3.6 + 1.6, 22 - row * 3, 0.5),
          _p);
    }
    // gerobak dorong
    final gx = bx - 26;
    _p.color = const Color(0xFFFB8C00);
    canvas.drawPath(
      Path()
        ..moveTo(gx, _gy - 11)
        ..lineTo(gx + 17, _gy - 11)
        ..lineTo(gx + 14, _gy - 4)
        ..lineTo(gx + 3, _gy - 4)
        ..close(),
      _p,
    );
    _p.color = const Color(0xFFC9B79C);
    canvas.drawOval(Rect.fromLTWH(gx + 2, _gy - 14, 13, 5), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF6D4C41);
    canvas.drawLine(Offset(gx + 14, _gy - 8), Offset(gx + 24, _gy - 14), _p);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF212121);
    canvas.drawCircle(Offset(gx + 6, _gy - 2.6), 2.6, _p);

    // pasir, kantong semen, kerucut pengaman (kanan)
    final rx = big ? 312.0 : 306.0;
    _p.color = const Color(0xFFD7C08A);
    canvas.drawPath(
      Path()
        ..moveTo(rx, _gy)
        ..quadraticBezierTo(rx + 12, _gy - 20, rx + 26, _gy)
        ..close(),
      _p,
    );
    _p.color = const Color(0xFFD7CCC8);
    canvas.drawRect(Rect.fromLTWH(rx + 30, _gy - 6, 12, 6), _p);
    canvas.drawRect(Rect.fromLTWH(rx + 32, _gy - 11.5, 10, 5.5), _p);
    _p.color = const Color(0xFF8D6E63);
    canvas.drawRect(Rect.fromLTWH(rx + 34, _gy - 4.4, 5, 1.4), _p);
    for (final cx in [_bl - 16.0, _bl + 206.0]) {
      _p.color = const Color(0xFFFF6D00);
      canvas.drawPath(
        Path()
          ..moveTo(cx - 4.5, _gy)
          ..lineTo(cx + 4.5, _gy)
          ..lineTo(cx + 1.4, _gy - 11)
          ..lineTo(cx - 1.4, _gy - 11)
          ..close(),
        _p,
      );
      _p.color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(cx - 3, _gy - 6, 6, 1.8), _p);
    }
  }

  // -------------------------------------------------------- tambah kamar

  void _drawRoomSite(Canvas canvas, double t, double p) {
    final idx = math.max(0, d.rooms - 1);
    final r = _cell(idx);
    final sa = _c01(p / 0.06) * (1 - _ease(_c01((p - 0.80) / 0.12)));
    if (sa > 0.01) {
      canvas.saveLayer(_view, Paint()..color = Color.fromRGBO(0, 0, 0, sa));
      _siteProps(canvas, t, false);
      _scaffoldRig(canvas, r.left - 5, r.right + 5, r.top - 8, r.bottom);
      if (r.bottom < _gy - 20) {
        _hoist(canvas, r.right + 11, r.top - 6, r.bottom - 9, t);
      }
      if (!d.compact) _roomCrew(canvas, r, t, p);
      canvas.restore();
    }

    // debu di titik kerja
    final brick = _ease(_c01((p - 0.08) / 0.30));
    if (p > 0.08 && p < 0.38) {
      _siteDust(canvas,
          Offset(r.center.dx, r.bottom - 3 - (r.height - 6) * brick), t, 1);
    } else if (p >= 0.38 && p < 0.72) {
      final edge = p < 0.50
          ? r.left + r.width * _ease(_c01((p - 0.38) / 0.12))
          : r.left + r.width * _ease(_c01((p - 0.50) / 0.22));
      _siteDust(canvas, Offset(edge, r.center.dy), t, p < 0.50 ? 1 : 0.5);
    }

    if (p > 0.76) {
      final q = _c01((p - 0.76) / 0.24);
      _drawBannerText(
        canvas,
        'KAMAR BARU! +INCOME',
        Offset(r.center.dx, r.top - 10 - q * 28),
        const Color(0xFFFFEE58),
        scale: 0.95 + math.sin(q * math.pi) * 0.25,
        alpha: 1 - q,
      );
    }
  }

  void _roomCrew(Canvas canvas, Rect r, double t, double p) {
    final foot = r.bottom - 0.5;
    final cheer = p > 0.76;
    final plasterP = _ease(_c01((p - 0.38) / 0.12));
    final paintP = _ease(_c01((p - 0.50) / 0.22));

    // tumpukan bata di dek selama pemasangan
    if (p < 0.42) {
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFB4654A);
      canvas.drawRect(Rect.fromLTWH(r.left + 26, foot - 3.4, 9, 3.4), _p);
      canvas.drawRect(Rect.fromLTWH(r.left + 27, foot - 6.8, 7, 3.4), _p);
    }

    // tukang utama: bata -> plester -> cat -> bersorak
    if (cheer) {
      _worker(canvas, Offset(r.left + 14, foot), 1, cheer: true, t: t);
    } else if (p < 0.38) {
      _worker(canvas, Offset(r.left + 13, foot), 1,
          arm: -0.2 + math.sin(t * 7) * 0.5, tool: 1);
    } else if (p < 0.50) {
      final x = r.left + 6 + (r.width - 12) * plasterP;
      _worker(canvas, Offset(x, foot), 1,
          arm: -0.55 + math.sin(t * 6) * 0.4, tool: 2);
    } else {
      final x = r.left + 5 + (r.width - 10) * paintP;
      _worker(canvas, Offset(x, foot), 1,
          arm: -0.7 + math.sin(t * 5) * 0.55, tool: 3);
    }

    // pembantu di sisi kanan: memalu bekisting / mengaduk lalu bersorak
    if (cheer) {
      _worker(canvas, Offset(r.right - 9, foot), -1,
          cheer: true, t: t + 0.4, vest: const Color(0xFF00ACC1));
    } else {
      final swing = math.sin(t * 9);
      _worker(canvas, Offset(r.right - 9, foot), -1,
          arm: p < 0.5 ? -1.0 + swing.abs() * 1.4 : 0.6,
          tool: p < 0.5 ? 4 : 0,
          vest: const Color(0xFF00ACC1));
      if (p < 0.5 && swing > 0.92) {
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = const Color(0xFFFFEE58);
        final o = Offset(r.right - 18, foot - 9);
        canvas.drawLine(o, o + const Offset(-3, -2), _p);
        canvas.drawLine(o, o + const Offset(-3, 1.5), _p);
        _p.style = PaintingStyle.fill;
      }
    }
  }

  // ------------------------------------------------------- tambah lantai

  void _towerCrane(Canvas canvas, double t, double p, double mastTop) {
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
    // jib + jib belakang + penahan
    _p
      ..style = PaintingStyle.fill
      ..color = yellow;
    canvas.drawRect(Rect.fromLTWH(60, mastTop, 252, 4.5), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF5D4037);
    canvas.drawLine(Offset(95, mastTop - 22),
        Offset(310, mastTop), _p);
    canvas.drawLine(Offset(95, mastTop - 22),
        Offset(62, mastTop), _p);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF616161);
    canvas.drawRect(Rect.fromLTWH(60, mastTop + 4.5, 16, 10), _p);
    _p.color = const Color(0xFF424242);
    canvas.drawRect(Rect.fromLTWH(62, mastTop + 5, 12, 3), _p);
    // kabin operator + lampu peringatan
    _p.color = const Color(0xFFFFCA28);
    canvas.drawRect(Rect.fromLTWH(99, mastTop - 10, 12, 10), _p);
    _p.color = const Color(0xFFB3E5FC);
    canvas.drawRect(Rect.fromLTWH(101, mastTop - 8, 6, 5), _p);
    final blink = math.sin(t * 6) > 0 ? 1.0 : 0.25;
    _p.color = const Color(0xFFFF1744).withValues(alpha: blink);
    canvas.drawCircle(Offset(95, mastTop - 24), 2.2, _p);

    // troli & kait
    const hx = 200.0;
    _p.color = const Color(0xFFE65100);
    canvas.drawRect(Rect.fromLTWH(hx - 6, mastTop - 1, 12, 6), _p);
    Offset hook;
    if (p < 0.05) {
      final apex0 = Offset(hx, _roofY - 2);
      hook = Offset(hx, _lerp(mastTop + 6, apex0.dy, _ease(p / 0.05)));
    } else if (p < 0.88) {
      hook = _roofPt(Offset(hx, _roofY - 52), p, t);
    } else {
      hook = Offset(hx,
          _lerp(_roofY - 52, mastTop + 6, _ease((p - 0.88) / 0.08)));
    }
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFF212121);
    canvas.drawLine(Offset(hx - 2, mastTop + 5), Offset(hook.dx - 2, hook.dy), _p);
    canvas.drawLine(Offset(hx + 2, mastTop + 5), Offset(hook.dx + 2, hook.dy), _p);
    // sling baja ke dua sudut atap
    if (p >= 0.0 && p < 0.86) {
      final l = _roofPt(Offset(_bl + 10, _roofY - 22), p, t);
      final rr = _roofPt(Offset(_bl + 180, _roofY - 22), p, t);
      _p
        ..strokeWidth = 1.0
        ..color = const Color(0xFF37474F);
      canvas.drawLine(hook.translate(0, 6), l, _p);
      canvas.drawLine(hook.translate(0, 6), rr, _p);
    }
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFF6F00);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(hook.dx - 5, hook.dy, 10, 7), const Radius.circular(2)),
      _p,
    );
  }

  void _drawFloorSite(Canvas canvas, double t, double p) {
    final baseY = _roofY + _fh;
    final mastTop = _roofY - 92;
    final wallP = _ease(_c01((p - 0.38) / 0.20));
    final deckY = baseY - (_fh - 26) * wallP;
    final a = (p < 0.04 ? p / 0.04 : 1.0) * (p > 0.90 ? (1 - p) / 0.10 : 1.0);
    final sa = _c01(p / 0.05) * (1 - _ease(_c01((p - 0.82) / 0.10)));

    // derek + perlengkapan tanah
    canvas.saveLayer(_view, Paint()..color = Color.fromRGBO(0, 0, 0, _c01(a)));
    _siteProps(canvas, t, true);
    _towerCrane(canvas, t, p, mastTop);
    if (!d.compact && p > 0.02 && p < 0.86) {
      // juru isyarat di tanah mengarahkan derek
      _worker(canvas, const Offset(172, _gy), -1,
          arm: -1.45 + math.sin(t * 6) * 0.5,
          vest: const Color(0xFFC6FF00),
          cheer: p > 0.86,
          t: t);
    }
    canvas.restore();

    // perancah + dek kerja yang naik + tukang
    if (sa > 0.01) {
      canvas.saveLayer(_view, Paint()..color = Color.fromRGBO(0, 0, 0, sa));
      _scaffoldRig(canvas, _bl - 7, _bl + 197, _roofY + 4, deckY);
      _hoist(canvas, _bl + 207, _roofY - 4, deckY - 9, t);
      if (!d.compact) _floorCrew(canvas, t, p, deckY);
      canvas.restore();
    }

    // percikan las di kolom
    if (p > 0.17 && p < 0.40 && !d.compact) {
      final wk = _c01((p - 0.17) / 0.20) * 3.9;
      final col = wk.floor();
      final cp = _ease(_c01((p - 0.17 - col * 0.028) / 0.15));
      final w = Offset(_bl + (wk) * _cw + 2, baseY - _fh * cp);
      if (math.sin(t * 38) > -0.2) {
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFE1F5FE).withValues(alpha: 0.9);
        canvas.drawCircle(w, 2.6, _p);
        _p.color = const Color(0xFF40C4FF).withValues(alpha: 0.35);
        canvas.drawCircle(w, 6.5, _p);
      }
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 7; k++) {
        final ph = (t * 3 + k * 0.17) % 1.0;
        final ang = -math.pi * (0.1 + 0.8 * ((k * 37) % 10) / 10);
        final dx = math.cos(ang) * 18 * ph;
        final dy = math.sin(ang) * 18 * ph + 26 * ph * ph;
        _p.color = const Color(0xFFFFD54F).withValues(alpha: 1 - ph);
        canvas.drawLine(w + Offset(dx, dy), w + Offset(dx + 1.6, dy + 1.6), _p);
      }
      _p
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.butt;
    }

    // atap mendarat: debu menyebar di sepanjang tepi atas lantai
    if (p > 0.85 && p < 0.97) {
      final q = _c01((p - 0.85) / 0.12);
      for (var k = 0; k < 10; k++) {
        final side = k.isEven ? -1.0 : 1.0;
        final spread = (k ~/ 2 + 1) * 10.0;
        final x = 200 + side * (spread + 38 * _ease(q) * (0.4 + k * 0.08));
        final y = _roofY - 2 - q * (6 + (k % 3) * 6);
        _p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFD7CCC8).withValues(alpha: (1 - q) * 0.6);
        canvas.drawCircle(Offset(x.clamp(_bl - 20, _bl + 210).toDouble(), y),
            4 + q * 9, _p);
      }
    }

    if (p > 0.88) {
      final q = _c01((p - 0.88) / 0.12);
      _drawBannerText(
        canvas,
        'LANTAI BARU! +INCOME',
        Offset(200, _roofY - 62 - q * 26),
        const Color(0xFFFFEE58),
        scale: 0.95 + math.sin(q * math.pi) * 0.25,
        alpha: 1 - q,
      );
    }
  }

  void _floorCrew(Canvas canvas, double t, double p, double deckY) {
    final foot = deckY - 0.5;
    final cheer = p > 0.80;
    final weldK = _c01((p - 0.17) / 0.20) * 3.9;

    // tukang besi / las: berpindah dari kolom ke kolom
    if (cheer) {
      _worker(canvas, Offset(_bl + 20, foot), 1, cheer: true, t: t);
    } else if (p >= 0.17 && p < 0.40) {
      _worker(canvas, Offset(_bl + weldK * _cw - 8, foot), 1,
          arm: -0.9 + math.sin(t * 10).abs() * 1.3, tool: 4);
    } else if (p >= 0.58 && p < 0.80) {
      // pengaci: plester lalu cat kamar baru (kolom pertama lantai ini)
      final plasterP = _ease(_c01((p - 0.58) / 0.07));
      final paintP = _ease(_c01((p - 0.64) / 0.10));
      if (p < 0.64) {
        _worker(canvas, Offset(_bl + 6 + (_cw - 12) * plasterP, foot), 1,
            arm: -0.55 + math.sin(t * 6) * 0.4, tool: 2);
      } else {
        _worker(canvas, Offset(_bl + 5 + (_cw - 10) * paintP, foot), 1,
            arm: -0.7 + math.sin(t * 5) * 0.55, tool: 3);
      }
    } else {
      _worker(canvas, Offset(_bl + 20, foot), 1, arm: 0.7);
    }

    // dua tukang bata: memasang dinding sambil mengikuti tinggi dek
    final laying = p >= 0.38 && p < 0.58;
    for (var k = 0; k < 2; k++) {
      final x = _bl + (k == 0 ? 112.0 : 165.0);
      final dir = k == 0 ? 1.0 : -1.0;
      if (cheer) {
        _worker(canvas, Offset(x, foot), dir,
            cheer: true, t: t + k * 0.5, vest: const Color(0xFF00ACC1));
      } else {
        _worker(canvas, Offset(x, foot), dir,
            arm: laying ? -0.2 + math.sin(t * 7 + k * 1.7) * 0.5 : 0.7,
            tool: laying ? 1 : 0,
            vest: const Color(0xFF00ACC1));
      }
    }
    // debu pekerjaan dinding
    if (laying) {
      for (var k = 0; k < 4; k++) {
        _siteDust(canvas, Offset(_bl + 24 + k * 48.0, foot - 24), t + k * 0.3, 0.8);
      }
    }
  }

  /// Titik masuk gambar renovasi (tambah kamar / tambah lantai). Dipanggil
  /// dari kedua mode (rumah tunggal & jalan).
  void _drawCrane(Canvas canvas, double t) {
    final p = _buildP;
    if (p == null) return;
    if (_isFloorBuild) {
      _drawFloorSite(canvas, t, p);
    } else {
      _drawRoomSite(canvas, t, p);
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

    // 2a) truk sampah & adegan pembajakan: lapisan dunia (di atas semua rumah)
    // supaya truk melintasi batas rumah dan masuk/keluar dari luar layar.
    for (var i = 0; i < houses.length; i++) {
      final hd = houses[i];
      final hauling = hd.haulProgress != null;
      final hjVictim = hd.fx.any((f) =>
      f.type == FxType.hijack && f.amount.round() != 1 && f.age >= 0);
      if (!hauling && !hjVictim) continue;
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