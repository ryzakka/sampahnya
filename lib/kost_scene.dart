import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'kost_style.dart';
import 'kost_traffic.dart';
import 'kost_warehouse.dart';


// ====================================================================
//  Adegan visual kost (v5 - Smart Trash Overflow & Animated Emoji)
// ====================================================================

part 'kost_painter.dart';
part 'kost_painter_events.dart';
part 'kost_painter_life.dart';
part 'kost_street.dart';
part 'kost_painter_warehouse.dart';

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
    this.owner,
    this.dayPhase,
    this.warehouse,
  });

  /// Gudang sampah di sisi kanan kost; null = tidak digambar (lobi dll).
  final WhLive? warehouse;

  /// Fase siang-malam 0..1 (0 = tengah malam, 0.25 = matahari terbit,
  /// 0.5 = tengah hari, 0.75 = matahari terbenam). null = siang tetap
  /// (lobi, ruang kustomisasi, intro).
  final double? dayPhase;

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

  /// Pemilik kost yang hidup di halaman depan; null = tidak digambar.
  final KostOwner? owner;

  /// Salinan dengan sebagian nilai diganti (dipakai sutradara sinematik).
  KostSceneData copyWith({
    double? trashRatio,
    double? pollution,
    bool? eliminated,
    double? lights,
    double? sealedLeft,
    bool? smog,
    bool clearWorldEvent = false,
    bool clearDayPhase = false,
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
        owner: owner,
        dayPhase: clearDayPhase ? null : dayPhase,
        warehouse: warehouse,
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
    owner: owner,
    dayPhase: dayPhase,
    warehouse: warehouse,
  );
}

/// Pemilik kost: karakter kustom pemain yang hidup di halaman depan, ikut
/// beraktivitas dan paling peka pada kondisi kostnya sendiri. MURNI visual.
///
/// State disimpan di sini (bukan di painter, yang dibuat ulang tiap frame).
/// Diperbarui sekali per frame oleh painter rumahnya lewat [update].
class KostOwner {
  KostOwner({this.seed = 0});

  int seed;

  /// Tampilan; diisi ulang pemanggil tiap kali data gaya berubah.
  KostLook look = const KostLook(
    skin: Color(0xFFE0AC84),
    shirt: Color(0xFF42A5F5),
    hair: 0,
    hairColor: Color(0xFF2B2B2B),
    acc: 0,
  );

  /// Mulai dari pintu depan (x 201), lalu berjalan ke tempatnya.
  double x = 201;
  double dir = 1;
  KostPose pose = KostPose.stand;
  bool walking = false;
  int mask = 0;
  String? icon;
  bool visible = true;

  int _lastMs = -1;

  static const double _minX = 116;
  static const double _maxX = 292;

  void update(KostSceneData d, double t) {
    final now = sceneNowMs();
    final dt = _lastMs < 0 ? 0.0 : math.min(0.1, (now - _lastMs) / 1000.0);
    _lastMs = now;

    bool recent(FxType ty, int ms) =>
        d.fx.any((f) => f.type == ty && f.age >= 0 && f.age < ms);
    final hijackVictim = d.fx.any((f) =>
    f.type == FxType.hijack &&
        f.amount.round() != 1 &&
        f.age >= 0 &&
        f.age < (f.durMs > 0 ? f.durMs : 6000));

    visible = !(d.buriedAgeMs != null && d.buriedAgeMs! >= 5000);

    final r = d.eliminated ? 1.0 : d.trashRatio;
    final poll = (d.pollution / 100).clamp(0.0, 1.0).toDouble();
    final ph = seed * 0.37;
    final threat = d.facingRight ? 1.0 : -1.0;

    var m = poll >= 0.85 ? 2 : (poll >= 0.6 ? 1 : 0);
    if (d.smog) m = 2;

    var tx = x;
    var speed = 22.0;
    var p = KostPose.stand;
    String? ic;
    var face = 0.0;

    if (d.eliminated) {
      p = KostPose.sad;
      tx = 200;
      speed = 400;
      ic = '😭';
      m = 0;
    } else if (d.buriedAgeMs != null) {
      p = KostPose.panic;
      tx = 200;
      speed = 50;
      ic = '😱';
      face = threat;
    } else if (d.attackLeft > 0) {
      // jendela Tangkis terbuka: pemilik siaga di tengah halaman
      p = KostPose.guard;
      tx = 200;
      speed = 80;
      ic = '😠';
      face = threat;
    } else if (recent(FxType.parry, 1800)) {
      p = KostPose.cheer;
      ic = '👏';
      speed = 0;
    } else if (recent(FxType.incoming, 1600)) {
      p = KostPose.flinch;
      ic = '😖';
      speed = 0;
    } else if (d.charge == 1) {
      p = KostPose.aim;
      tx = d.facingRight ? 250 : 150;
      speed = 70;
      face = threat;
    } else if (d.charge == 2) {
      p = KostPose.phone;
      ic = '📞';
      speed = 0;
    } else if (d.policeAgeMs != null || d.sealedLeft > 0) {
      p = KostPose.argue;
      tx = 170;
      speed = 50;
      ic = '😤';
    } else if (hijackVictim) {
      p = KostPose.panic;
      tx = _maxX;
      speed = 95;
      ic = '🤬';
      face = 1;
    } else if (recent(FxType.burn, 4500)) {
      p = KostPose.cough;
      ic = '🤧';
      speed = 0;
      m = math.max(m, 1);
    } else if (r >= 0.9) {
      p = KostPose.panic;
      tx = 205 + 78 * math.sin(t * 1.7 + ph);
      speed = 70;
      ic = '😱';
    } else if (r >= 0.75) {
      p = KostPose.argue;
      tx = 205 + 55 * math.sin(t * 0.8 + ph);
      speed = 28;
      ic = ((t * 0.8 + ph) % 2 < 1) ? '💢' : '😡';
    } else if (r >= 0.5) {
      // menatap tumpukan sampah di sisi kotak sampah
      p = KostPose.nose;
      tx = 122;
      speed = 34;
      ic = '🤢';
    } else if (m >= 1) {
      p = KostPose.cough;
      tx = 205 + 40 * math.sin(t * 0.4 + ph);
      speed = 14;
      ic = math.sin(t * 2.2 + ph) > 0.5 ? '🤧' : '😷';
    } else if (recent(FxType.build, 2600) ||
        recent(FxType.tier, 3200) ||
        recent(FxType.defense, 2600) ||
        recent(FxType.waste, 2600)) {
      p = KostPose.proud;
      ic = '😎';
      tx = recent(FxType.waste, 2600)
          ? 125
          : (recent(FxType.defense, 2600) ? 150 : 215);
      speed = 40;
    } else if (d.isBounty) {
      // buruan bernilai bonus: waspada, mondar-mandir sambil melirik
      p = KostPose.guard;
      tx = 205 + 60 * math.sin(t * 0.5 + ph);
      speed = 22;
      ic = math.sin(t * 1.3 + ph) > 0.8 ? '👀' : null;
    } else {
      // keseharian: menyapu, main ponsel, jalan-jalan, melambai
      final cyc = (t + seed * 0.37) % 24.0;
      if (cyc < 9) {
        p = KostPose.sweep;
        tx = 205 + 60 * math.sin(t * 0.45 + ph);
        speed = 14;
      } else if (cyc < 15) {
        p = KostPose.phone;
        tx = 150 + (seed % 5) * 18.0;
        speed = 20;
      } else if (cyc < 20) {
        p = KostPose.stand;
        tx = 130.0 + (((t / 5).floor() * 61 + seed * 7) % 155);
        speed = 18;
      } else {
        p = KostPose.wave;
        speed = 0;
      }
    }

    tx = tx.clamp(_minX, _maxX).toDouble();
    final dx = tx - x;
    final step = speed * dt;
    final moving = speed > 0 && dx.abs() > 0.6;
    if (moving) {
      x += dx.abs() <= step ? dx : step * dx.sign;
      dir = dx.sign;
    }
    walking = moving && p != KostPose.sad;
    if (face != 0) dir = face;

    pose = p;
    mask = m;
    icon = ic;
  }
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