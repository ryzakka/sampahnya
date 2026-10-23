import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Palet & model kustomisasi. Batas indeks di sini HARUS sama dengan
/// `_style_valid` di customization_migration.sql.
abstract final class KostPalette {
  static const List<Color> walls = [
    Color(0xFFF0DFB8), // 0-3: sama dengan warna bawaan per slot
    Color(0xFFCFE6D6),
    Color(0xFFF4CFC4),
    Color(0xFFD1DCF2),
    Color(0xFFFFF3C4),
    Color(0xFFE8D5F2),
    Color(0xFFFFD9B3),
    Color(0xFFC9E7EA),
    Color(0xFFF7E1E8),
    Color(0xFFDDE8B8),
    Color(0xFFEADBC8),
    Color(0xFFCFD8DC),
  ];

  static const List<Color> roofs = [
    Color(0xFF8D4B3B),
    Color(0xFF37474F),
    Color(0xFF1B5E20),
    Color(0xFF0D47A1),
    Color(0xFF6A1B9A),
    Color(0xFFB71C1C),
    Color(0xFFE65100),
    Color(0xFF4E342E),
    Color(0xFF00695C),
    Color(0xFF616161),
  ];

  static const List<Color> signs = [
    Color(0xFF477A62),
    Color(0xFF0D47A1),
    Color(0xFF212121),
    Color(0xFFB71C1C),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00695C),
    Color(0xFF4E342E),
  ];

  static const List<Color> doors = [
    Color(0xFF6D4C41),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFC62828),
    Color(0xFFF9A825),
    Color(0xFF6A1B9A),
    Color(0xFF37474F),
    Color(0xFFEC407A),
  ];

  static const List<Color> skins = [
    Color(0xFFF6D2B3),
    Color(0xFFE0AC84), // bawaan
    Color(0xFFC68B5E),
    Color(0xFF9C6644),
    Color(0xFF6F4426),
    Color(0xFFFFE0C8),
  ];

  static const List<Color> shirts = [
    Color(0xFF42A5F5),
    Color(0xFFEF5350),
    Color(0xFF66BB6A),
    Color(0xFFAB47BC),
    Color(0xFFFFCA28),
    Color(0xFFFF7043),
    Color(0xFF26C6DA),
    Color(0xFFEC407A),
    Color(0xFF8D6E63),
    Color(0xFF37474F),
    Color(0xFFFAFAFA),
    Color(0xFF9CCC65),
  ];

  static const List<Color> hairColors = [
    Color(0xFF2B2B2B),
    Color(0xFF5D4037),
    Color(0xFF3E2723),
    Color(0xFFE6C35C),
    Color(0xFFC2571A),
    Color(0xFF9E9E9E),
    Color(0xFF3F6FD8),
    Color(0xFFE86AA6),
  ];

  static const List<String> hairNames = [
    'Botak',
    'Pendek',
    'Jambul',
    'Cepol',
    'Panjang',
    'Topi',
  ];

  static const List<String> accNames = [
    'Tanpa',
    'Kacamata',
    'Bando',
    'Headphone',
    'Kumis',
  ];

  static const int maxNameLen = 10;
}

/// Gaya bangunan + karakter satu pemain. Properti null = pakai bawaan.
@immutable
class KostStyle {
  const KostStyle({
    this.wall,
    this.roof,
    this.sign,
    this.door,
    this.name = '',
    this.skin,
    this.shirt,
    this.hair = 0,
    this.hairColor = 0,
    this.acc = 0,
  });

  final int? wall;
  final int? roof;
  final int? sign;
  final int? door;

  /// Teks papan nama (A-Z, 0-9, spasi; maks 10). Kosong = teks bawaan kelas.
  final String name;

  final int? skin;
  final int? shirt;
  final int hair; // 0..5
  final int hairColor; // 0..7
  final int acc; // 0..4

  static const KostStyle empty = KostStyle();

  bool get isEmpty =>
      wall == null &&
          roof == null &&
          sign == null &&
          door == null &&
          name.isEmpty &&
          skin == null &&
          shirt == null &&
          hair == 0 &&
          acc == 0;

  Color? get wallColor => wall == null ? null : KostPalette.walls[wall!];
  Color? get roofColor => roof == null ? null : KostPalette.roofs[roof!];
  Color? get signColor => sign == null ? null : KostPalette.signs[sign!];
  Color? get doorColor => door == null ? null : KostPalette.doors[door!];

  /// Ada kustomisasi karakter? (kalau tidak, penghuni digambar seperti semula)
  bool get hasLook =>
      skin != null || shirt != null || hair != 0 || acc != 0;

  KostLook look({Color fallbackShirt = const Color(0xFF42A5F5)}) => KostLook(
    skin: skin == null
        ? const Color(0xFFE0AC84)
        : KostPalette.skins[skin!],
    shirt: shirt == null ? fallbackShirt : KostPalette.shirts[shirt!],
    hair: hair,
    hairColor: KostPalette.hairColors[hairColor],
    acc: acc,
  );

  static int? _idx(dynamic v, int max) {
    if (v is! num) return null;
    final i = v.toInt();
    return (i < 0 || i > max) ? null : i;
  }

  /// Parser toleran: data rusak/di luar rentang diabaikan (jatuh ke bawaan).
  static KostStyle? fromJson(dynamic json) {
    if (json is! Map) return null;
    final rawName = (json['name'] ?? '').toString().toUpperCase();
    final name = rawName
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), '')
        .trim();
    return KostStyle(
      wall: _idx(json['wall'], KostPalette.walls.length - 1),
      roof: _idx(json['roof'], KostPalette.roofs.length - 1),
      sign: _idx(json['sign'], KostPalette.signs.length - 1),
      door: _idx(json['door'], KostPalette.doors.length - 1),
      name: name.length > KostPalette.maxNameLen
          ? name.substring(0, KostPalette.maxNameLen)
          : name,
      skin: _idx(json['skin'], KostPalette.skins.length - 1),
      shirt: _idx(json['shirt'], KostPalette.shirts.length - 1),
      hair: _idx(json['hair'], KostPalette.hairNames.length - 1) ?? 0,
      hairColor: _idx(json['hairc'], KostPalette.hairColors.length - 1) ?? 0,
      acc: _idx(json['acc'], KostPalette.accNames.length - 1) ?? 0,
    );
  }

  /// Hanya field yang berbeda dari bawaan yang dikirim (payload kecil).
  Map<String, dynamic> toJson() => {
    if (wall != null) 'wall': wall,
    if (roof != null) 'roof': roof,
    if (sign != null) 'sign': sign,
    if (door != null) 'door': door,
    if (name.isNotEmpty) 'name': name,
    if (skin != null) 'skin': skin,
    if (shirt != null) 'shirt': shirt,
    if (hair != 0) 'hair': hair,
    if (hairColor != 0) 'hairc': hairColor,
    if (acc != 0) 'acc': acc,
  };

  KostStyle copyWith({
    int? wall,
    int? roof,
    int? sign,
    int? door,
    String? name,
    int? skin,
    int? shirt,
    int? hair,
    int? hairColor,
    int? acc,
  }) =>
      KostStyle(
        wall: wall ?? this.wall,
        roof: roof ?? this.roof,
        sign: sign ?? this.sign,
        door: door ?? this.door,
        name: name ?? this.name,
        skin: skin ?? this.skin,
        shirt: shirt ?? this.shirt,
        hair: hair ?? this.hair,
        hairColor: hairColor ?? this.hairColor,
        acc: acc ?? this.acc,
      );

  /// Bagian bangunan dikembalikan ke bawaan (karakter tetap).
  KostStyle clearBuilding() => KostStyle(
    skin: skin,
    shirt: shirt,
    hair: hair,
    hairColor: hairColor,
    acc: acc,
  );

  /// Bagian karakter dikembalikan ke bawaan (bangunan tetap).
  KostStyle clearCharacter() => KostStyle(
    wall: wall,
    roof: roof,
    sign: sign,
    door: door,
    name: name,
  );

  KostStyle randomCharacter(math.Random r) => KostStyle(
    wall: wall,
    roof: roof,
    sign: sign,
    door: door,
    name: name,
    skin: r.nextInt(KostPalette.skins.length),
    shirt: r.nextInt(KostPalette.shirts.length),
    hair: r.nextInt(KostPalette.hairNames.length),
    hairColor: r.nextInt(KostPalette.hairColors.length),
    acc: r.nextInt(KostPalette.accNames.length),
  );

  KostStyle randomBuilding(math.Random r) => KostStyle(
    wall: r.nextInt(KostPalette.walls.length),
    roof: r.nextInt(KostPalette.roofs.length),
    sign: r.nextInt(KostPalette.signs.length),
    door: r.nextInt(KostPalette.doors.length),
    name: name,
    skin: skin,
    shirt: shirt,
    hair: hair,
    hairColor: hairColor,
    acc: acc,
  );

  @override
  bool operator ==(Object other) =>
      other is KostStyle &&
          other.wall == wall &&
          other.roof == roof &&
          other.sign == sign &&
          other.door == door &&
          other.name == name &&
          other.skin == skin &&
          other.shirt == shirt &&
          other.hair == hair &&
          other.hairColor == hairColor &&
          other.acc == acc;

  @override
  int get hashCode => Object.hash(
      wall, roof, sign, door, name, skin, shirt, hair, hairColor, acc);
}

/// Tampilan karakter yang sudah "dihitung" jadi warna siap gambar.
@immutable
class KostLook {
  const KostLook({
    required this.skin,
    required this.shirt,
    required this.hair,
    required this.hairColor,
    required this.acc,
  });

  final Color skin;
  final Color shirt;
  final int hair;
  final Color hairColor;
  final int acc;

  @override
  bool operator ==(Object other) =>
      other is KostLook &&
          other.skin == skin &&
          other.shirt == shirt &&
          other.hair == hair &&
          other.hairColor == hairColor &&
          other.acc == acc;

  @override
  int get hashCode => Object.hash(skin, shirt, hair, hairColor, acc);
}

/// Seed stabil per pemain (sama di semua perangkat; tanpa hashCode Dart).
int kostSeedFor(String id) =>
    id.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) % 1000);

/// Tampilan karakter satu pemain; baju bawaan ditentukan seed pemain.
KostLook kostLookFor(String id, KostStyle? style) =>
    (style ?? KostStyle.empty)
        .look(fallbackShirt: KostPalette.shirts[kostSeedFor(id) % 4]);

// ======================================================================
//  PAINTER KARAKTER (dipakai penghuni di scene DAN ruang kostum)
// ======================================================================

/// Menggambar rambut + aksesori. Titik asal = pusat kepala, jari-jari
/// kepala = 1 satuan, menghadap +x. Pemanggil yang mengatur translate/scale
/// (penghuni: translate(0,-17.5) scale(3.2)).
void paintKostHeadGear(Canvas canvas, Paint p, KostLook look) {
  final hc = look.hairColor;

  // ---- rambut ----
  if (look.hair != 0) {
    p
      ..style = PaintingStyle.fill
      ..color = hc;
    final cap = Rect.fromCircle(center: Offset.zero, radius: 1.12);
    switch (look.hair) {
      case 1: // pendek
        canvas.drawArc(cap, math.pi, math.pi, true, p);
        canvas.drawRect(const Rect.fromLTRB(-1.1, -0.1, -0.7, 0.35), p);
        break;
      case 2: // jambul
        canvas.drawArc(cap, math.pi, math.pi, true, p);
        for (var i = 0; i < 3; i++) {
          final x = -0.65 + i * 0.65;
          canvas.drawPath(
            Path()
              ..moveTo(x - 0.35, -0.95)
              ..lineTo(x + 0.05, -1.75 - (i == 1 ? 0.25 : 0))
              ..lineTo(x + 0.35, -0.95)
              ..close(),
            p,
          );
        }
        break;
      case 3: // cepol
        canvas.drawArc(cap, math.pi, math.pi, true, p);
        canvas.drawCircle(const Offset(-0.2, -1.4), 0.5, p);
        break;
      case 4: // panjang (jatuh di belakang kepala)
        canvas.drawArc(cap, math.pi, math.pi, true, p);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(-1.18, -0.3, -0.5, 1.7),
              const Radius.circular(0.3)),
          p,
        );
        break;
      case 5: // topi dengan lidah
        canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: 1.2),
            math.pi, math.pi, true, p);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(0.3, -0.45, 1.9, -0.1),
              const Radius.circular(0.15)),
          p,
        );
        break;
    }
  }

  // ---- aksesori ----
  switch (look.acc) {
    case 1: // kacamata
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.16
        ..color = const Color(0xFF263238);
      canvas.drawCircle(const Offset(0.25, -0.08), 0.34, p);
      canvas.drawCircle(const Offset(0.95, -0.08), 0.3, p);
      canvas.drawLine(const Offset(0.59, -0.08), const Offset(0.65, -0.08), p);
      canvas.drawLine(const Offset(-0.05, -0.1), const Offset(-1.0, -0.2), p);
      p.style = PaintingStyle.fill;
      break;
    case 2: // bando
      p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFE53935);
      canvas.drawRect(const Rect.fromLTRB(-1.12, -0.62, 1.12, -0.34), p);
      break;
    case 3: // headphone
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.22
        ..color = const Color(0xFF212121);
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: 1.22),
          math.pi, math.pi, false, p);
      p.style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTRB(-1.5, -0.35, -0.95, 0.5),
            const Radius.circular(0.18)),
        p,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTRB(0.95, -0.35, 1.5, 0.5),
            const Radius.circular(0.18)),
        p,
      );
      break;
    case 4: // kumis
      p
        ..style = PaintingStyle.fill
        ..color = hc;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTRB(0.15, 0.32, 1.0, 0.58),
            const Radius.circular(0.12)),
        p,
      );
      break;
  }
}

/// Pose karakter. Dipakai pemilik kost di game DAN karakter di ruang
/// kostum/podium, jadi semua gambar karakter lewat satu fungsi.
enum KostPose {
  stand,
  wave,
  cheer,
  guard,
  panic,
  nose,
  cough,
  aim,
  argue,
  sweep,
  phone,
  proud,
  flinch,
  sad,
}

/// Karakter utuh (kaki di titik asal, menghadap +x), dalam satuan yang sama
/// dengan penghuni di scene: tinggi sekitar 21.
///
/// [walking] mengayunkan kaki; [mask] 0 tanpa, 1 masker, 2 masker gas;
/// [onBox] hanya untuk [KostPose.sad]: duduk di atas koper (tinggi 12).
void paintKostCharacter(
    Canvas canvas,
    Paint p,
    KostLook look, {
      double t = 0,
      KostPose pose = KostPose.stand,
      double phase = 0,
      bool walking = false,
      int mask = 0,
      bool onBox = false,
      bool tears = true,
    }) {
  if (pose == KostPose.sad) {
    _paintSeated(canvas, p, look,
        t: t, phase: phase, onBox: onBox, tears: tears);
    return;
  }

  final ph = t * 10 + phase;
  final sw = walking ? math.sin(ph) * 2.6 : 0.0;
  var lift = walking
      ? -math.sin(ph * 2).abs() * 0.7
      : math.sin(t * 2.4 + phase) * 0.35;
  var lean = 0.0;
  var shake = 0.0;
  switch (pose) {
    case KostPose.cheer:
      lift -= math.sin(t * 8 + phase).abs() * 2.4;
      break;
    case KostPose.panic:
      shake = math.sin(t * 32) * 0.5;
      lean = math.sin(t * 6 + phase) * 0.06;
      break;
    case KostPose.flinch:
      lean = -0.3;
      shake = math.sin(t * 40) * 0.4;
      break;
    case KostPose.cough:
      lean = 0.1 + 0.22 * math.max(0.0, math.sin(t * 6 + phase));
      break;
    case KostPose.nose:
      lean = -0.1;
      break;
    case KostPose.phone:
      lean = 0.07;
      break;
    case KostPose.aim:
      lean = -0.14;
      break;
    case KostPose.guard:
      lean = 0.1;
      break;
    default:
      break;
  }

  canvas.save();
  canvas.translate(shake, lift);

  // ---- kaki (tidak ikut miring) ----
  final stance = pose == KostPose.guard
      ? 2.2
      : (pose == KostPose.aim ? 1.6 : 0.0);
  p
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF37474F);
  canvas.drawLine(
      const Offset(-0.6, -6), Offset(-1.2 - stance + sw, 0), p);
  canvas.drawLine(
      const Offset(0.6, -6), Offset(1.2 + stance - sw, 0), p);
  // sepatu
  p
    ..style = PaintingStyle.fill
    ..color = const Color(0xFF263238);
  canvas.drawOval(
      Rect.fromCenter(
          center: Offset(-0.5 - stance + sw, -0.2), width: 2.8, height: 1.3),
      p);
  canvas.drawOval(
      Rect.fromCenter(
          center: Offset(2.0 + stance - sw, -0.2), width: 2.8, height: 1.3),
      p);

  // ---- badan atas (miring di pinggul) ----
  canvas.save();
  canvas.translate(0, -6);
  canvas.rotate(lean);
  canvas.translate(0, 6);

  var hf = const Offset(3.4, -7.4);
  var hb = const Offset(-3.6, -7.2);
  Offset? stickTop;
  Offset? stickBot;
  switch (pose) {
    case KostPose.wave:
      final w = math.sin(t * 9 + phase) * 1.4;
      hf = Offset(4.6 + w * 0.3, -19.2 + w * 0.5);
      break;
    case KostPose.cheer:
      final b = math.sin(t * 8 + phase) * 0.8;
      hf = Offset(4.4, -22.5 + b);
      hb = Offset(-4.4, -22.5 - b);
      break;
    case KostPose.guard:
      hf = const Offset(6.8, -13.8);
      hb = const Offset(4.8, -9.6);
      break;
    case KostPose.panic:
      hf = const Offset(2.8, -21.2);
      hb = const Offset(-2.8, -21.2);
      break;
    case KostPose.nose:
      hf = const Offset(2.9, -16.4);
      hb = const Offset(-3.4, -8.2);
      break;
    case KostPose.cough:
      hf = const Offset(2.6, -16.0);
      hb = const Offset(-3.4, -8.0);
      break;
    case KostPose.aim:
      hf = const Offset(-2.6, -23.0);
      hb = const Offset(5.2, -16.6);
      break;
    case KostPose.argue:
      hf = Offset(5.4, -14.5 + math.sin(t * 7 + phase) * 3);
      hb = Offset(-5.0, -13.0 + math.cos(t * 6 + phase) * 2.6);
      break;
    case KostPose.sweep:
      final s = math.sin(t * 3.2 + phase) * 3.2;
      stickTop = const Offset(1.4, -14.5);
      stickBot = Offset(8.5 + s, -0.4);
      hf = Offset.lerp(stickTop, stickBot, 0.52)!;
      hb = Offset.lerp(stickTop, stickBot, 0.3)!;
      break;
    case KostPose.phone:
      hf = const Offset(3.4, -15.2);
      hb = const Offset(-3.5, -7.6);
      break;
    case KostPose.proud:
      hf = const Offset(4.8, -8.8);
      hb = const Offset(-4.8, -8.8);
      break;
    case KostPose.flinch:
      hf = const Offset(2.4, -20.4);
      hb = const Offset(-1.8, -20.0);
      break;
    default:
      if (walking) {
        hf = Offset(1.4 + sw * 0.9, -7.4);
        hb = Offset(-1.4 - sw * 0.9, -7.4);
      }
      break;
  }

  // lengan belakang
  p
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round
    ..color = look.shirt;
  canvas.drawLine(const Offset(0, -12), hb, p);
  p
    ..style = PaintingStyle.fill
    ..color = look.skin;
  canvas.drawCircle(hb, 1.0, p);

  // badan
  p
    ..strokeCap = StrokeCap.butt
    ..color = look.shirt;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3.2, -14, 6.4, 9), const Radius.circular(2)),
    p,
  );

  // kepala
  p.color = look.skin;
  canvas.drawCircle(const Offset(0, -17.5), 3.2, p);
  // pipi merona
  p
    ..style = PaintingStyle.fill
    ..color = const Color(0xFFFF8A80).withValues(alpha: 0.35);
  canvas.drawCircle(const Offset(2.35, -16.9), 0.55, p);
  _paintFace(canvas, p, pose, mask);

  canvas.save();
  canvas.translate(0, -17.5);
  canvas.scale(3.2);
  paintKostHeadGear(canvas, p, look);
  canvas.restore();

  // alat peraga di tangan
  if (stickTop != null && stickBot != null) {
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8D6E63);
    canvas.drawLine(stickTop, stickBot, p);
    p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFD4A64A);
    canvas.drawPath(
      Path()
        ..moveTo(stickBot.dx - 1.6, stickBot.dy - 1.8)
        ..lineTo(stickBot.dx + 1.6, stickBot.dy - 1.8)
        ..lineTo(stickBot.dx + 2.8, stickBot.dy + 0.3)
        ..lineTo(stickBot.dx - 2.8, stickBot.dy + 0.3)
        ..close(),
      p,
    );
  }

  // lengan depan (di atas badan & kepala)
  p
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round
    ..color = look.shirt;
  canvas.drawLine(const Offset(0, -12), hf, p);

  if (pose == KostPose.aim) {
    // kantong sampah siap dilempar
    p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF37474F);
    canvas.drawCircle(hf + const Offset(0, -2.0), 2.6, p);
    canvas.drawPath(
      Path()
        ..moveTo(hf.dx - 0.8, hf.dy - 4.2)
        ..lineTo(hf.dx, hf.dy - 5.6)
        ..lineTo(hf.dx + 0.8, hf.dy - 4.2)
        ..close(),
      p,
    );
  }
  p
    ..style = PaintingStyle.fill
    ..color = look.skin;
  canvas.drawCircle(hf, 1.1, p);
  if (pose == KostPose.phone) {
    p.color = const Color(0xFF263238);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(hf.dx - 0.2, hf.dy - 3.2, 1.9, 3.2),
          const Radius.circular(0.4)),
      p,
    );
    p.color = const Color(0xFF4FC3F7)
        .withValues(alpha: 0.7 + 0.3 * math.sin(t * 5));
    canvas.drawRect(Rect.fromLTWH(hf.dx, hf.dy - 2.8, 1.5, 2.3), p);
  }

  // efek kecil per pose
  switch (pose) {
    case KostPose.panic:
    case KostPose.flinch:
      for (var k = 0; k < 2; k++) {
        final u = (t * 1.6 + k * 0.5) % 1.0;
        p.color = const Color(0xFF81D4FA).withValues(alpha: (1 - u) * 0.9);
        canvas.drawCircle(Offset(-3.0 + k * 6.4, -21.0 + u * 5), 0.7, p);
      }
      break;
    case KostPose.cough:
      for (var k = 0; k < 3; k++) {
        final u = (t * 1.4 + k * 0.33) % 1.0;
        p.color = const Color(0xFFB0BEC5).withValues(alpha: (1 - u) * 0.65);
        canvas.drawCircle(
            Offset(4.6 + u * 3.6, -16.4 - u * 2.6), 0.6 + u * 0.9, p);
      }
      break;
    case KostPose.nose:
      for (var k = 0; k < 2; k++) {
        final u = (t * 1.1 + k * 0.5) % 1.0;
        p.color = const Color(0xFF9CCC65).withValues(alpha: (1 - u) * 0.8);
        canvas.drawCircle(
            Offset(5.0 + k * 1.4, -15.5 - u * 4.5), 0.8 + u * 0.4, p);
      }
      break;
    case KostPose.proud:
      final sp = 1.0 + 0.3 * math.sin(t * 5 + phase);
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFD54F);
      canvas.drawLine(Offset(6.5 - 1.6 * sp, -24.5),
          Offset(6.5 + 1.6 * sp, -24.5), p);
      canvas.drawLine(Offset(6.5, -24.5 - 1.6 * sp),
          Offset(6.5, -24.5 + 1.6 * sp), p);
      p.style = PaintingStyle.fill;
      break;
    default:
      break;
  }

  p
    ..style = PaintingStyle.fill
    ..strokeCap = StrokeCap.butt;
  canvas.restore(); // badan atas
  canvas.restore(); // geser/hop
}

/// Mata, alis, mulut, dan masker (kepala berpusat di (0,-17.5)).
void _paintFace(Canvas canvas, Paint p, KostPose pose, int mask) {
  var mouth = 0; // 0 senyum, 1 datar, 2 cemberut, 3 terbuka
  var wide = false;
  var brow = false;
  switch (pose) {
    case KostPose.panic:
    case KostPose.flinch:
      mouth = 3;
      wide = true;
      break;
    case KostPose.argue:
      mouth = 3;
      brow = true;
      break;
    case KostPose.nose:
      mouth = 2;
      break;
    case KostPose.cough:
      mouth = 1;
      break;
    case KostPose.guard:
    case KostPose.aim:
      mouth = 1;
      brow = true;
      break;
    default:
      break;
  }

  const eye = Offset(1.4, -17.9);
  p.style = PaintingStyle.fill;
  if (wide) {
    p.color = Colors.white;
    canvas.drawCircle(eye, 0.95, p);
    p.color = const Color(0xFF3E2723);
    canvas.drawCircle(eye + const Offset(0.2, 0), 0.42, p);
  } else {
    p.color = const Color(0xFF3E2723);
    canvas.drawCircle(eye, 0.45, p);
  }
  p
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 0.4
    ..color = const Color(0xFF3E2723);
  if (brow) {
    canvas.drawLine(const Offset(0.2, -19.7), const Offset(2.5, -18.9), p);
  }
  if (mask == 0) {
    switch (mouth) {
      case 0:
        p.strokeWidth = 0.35;
        canvas.drawArc(
            Rect.fromCenter(
                center: const Offset(1.5, -16.5), width: 1.6, height: 1.0),
            0.2,
            math.pi - 0.4,
            false,
            p);
        break;
      case 1:
        canvas.drawLine(const Offset(0.8, -16.1), const Offset(2.3, -16.1), p);
        break;
      case 2:
        canvas.drawArc(
            Rect.fromCenter(
                center: const Offset(1.5, -15.7), width: 1.5, height: 1.0),
            math.pi + 0.3,
            math.pi - 0.6,
            false,
            p);
        break;
      default:
        p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF5D1F1F);
        canvas.drawOval(
            Rect.fromCenter(
                center: const Offset(1.6, -16.0), width: 1.1, height: 1.5),
            p);
        break;
    }
  } else if (mask == 1) {
    p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFCFE8F5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTRB(0.0, -17.0, 3.5, -14.9),
          const Radius.circular(0.6)),
      p,
    );
  } else {
    p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF78909C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTRB(-0.2, -17.6, 3.6, -14.5),
          const Radius.circular(0.8)),
      p,
    );
    p.color = const Color(0xFF455A64);
    canvas.drawCircle(const Offset(3.3, -15.8), 1.1, p);
  }
  p
    ..style = PaintingStyle.fill
    ..strokeCap = StrokeCap.butt;
}

/// Duduk lesu (pemilik yang kostnya tertimbun / juara terakhir).
void _paintSeated(
    Canvas canvas,
    Paint p,
    KostLook look, {
      required double t,
      required double phase,
      required bool onBox,
      required bool tears,
    }) {
  final hy = onBox ? -12.0 : -3.4;
  canvas.save();
  canvas.translate(0, hy);

  p
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF37474F);
  if (onBox) {
    canvas.drawLine(const Offset(-1, 0), const Offset(-6, 11), p);
    canvas.drawLine(const Offset(2, 0), const Offset(4, 11), p);
  } else {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(5.6, -0.4)
        ..lineTo(6.2, 3.4),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-0.4, 0.6)
        ..lineTo(4.8, 0.4)
        ..lineTo(5.4, 3.4),
      p,
    );
  }

  canvas.save();
  canvas.rotate(0.3);
  p
    ..style = PaintingStyle.fill
    ..strokeCap = StrokeCap.butt
    ..color = look.shirt;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3.4, -11.5, 6.8, 11.5),
        const Radius.circular(2.4)),
    p,
  );
  p.color = look.skin;
  canvas.drawCircle(const Offset(1.6, -14.6), 3.2, p);

  p
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 0.4
    ..color = const Color(0xFF3E2723);
  canvas.drawArc(
      Rect.fromCenter(
          center: const Offset(2.5, -14.9), width: 1.5, height: 1.0),
      0,
      math.pi,
      false,
      p);
  canvas.drawArc(
      Rect.fromCenter(
          center: const Offset(2.6, -12.9), width: 1.4, height: 1.0),
      math.pi + 0.3,
      math.pi - 0.6,
      false,
      p);

  canvas.save();
  canvas.translate(1.6, -14.6);
  canvas.scale(3.2);
  paintKostHeadGear(canvas, p, look);
  canvas.restore();

  // tangan memeluk lutut
  p
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round
    ..color = look.shirt;
  canvas.drawLine(const Offset(0, -9), const Offset(4.4, -4.6), p);
  p
    ..style = PaintingStyle.fill
    ..color = look.skin;
  canvas.drawCircle(const Offset(4.8, -4.2), 1.1, p);
  canvas.restore();

  if (tears) {
    for (var k = 0; k < 3; k++) {
      final u = (t * 1.3 + k * 0.33 + phase) % 1.0;
      p.color = const Color(0xFF81D4FA).withValues(alpha: (1 - u) * 0.85);
      canvas.drawCircle(Offset(6.2 + k * 0.8, -13.0 + u * 13), 0.95, p);
    }
  }
  p
    ..style = PaintingStyle.fill
    ..strokeCap = StrokeCap.butt;
  canvas.restore();
}

// ======================================================================
//  IKON KEPALA (kartu nama di game, lobi, ruang kustomisasi)
// ======================================================================

class KostHeadIcon extends StatelessWidget {
  const KostHeadIcon({
    super.key,
    required this.look,
    this.size = 20,
    this.ring,
  });

  final KostLook look;
  final double size;

  /// Warna lingkaran tepi (mis. emas untuk pemain sendiri).
  final Color? ring;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _HeadIconPainter(look, ring)),
  );
}

class _HeadIconPainter extends CustomPainter {
  _HeadIconPainter(this.look, this.ring);

  final KostLook look;
  final Color? ring;
  final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    _p
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.16);
    canvas.drawCircle(Offset(r, r), r, _p);

    canvas.save();
    canvas.clipPath(Path()
      ..addOval(Rect.fromCircle(center: Offset(r, r), radius: r - 0.4)));
    canvas.translate(r, size.height * 0.56);
    canvas.scale(size.width * 0.26);

    _p.color = look.shirt;
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 2.3), width: 4.4, height: 2.6),
        _p);
    _p.color = look.skin;
    canvas.drawCircle(Offset.zero, 1, _p);
    _p.color = const Color(0xFF3E2723);
    canvas.drawCircle(const Offset(0.45, -0.12), 0.16, _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.1
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCenter(center: const Offset(0.5, 0.34), width: 0.5, height: 0.32),
        0.2,
        math.pi - 0.4,
        false,
        _p);
    _p.style = PaintingStyle.fill;
    paintKostHeadGear(canvas, _p, look);
    canvas.restore();

    if (ring != null) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = ring!;
      canvas.drawCircle(Offset(r, r), r - 0.7, _p);
    }
  }

  @override
  bool shouldRepaint(covariant _HeadIconPainter old) =>
      old.look != look || old.ring != ring;
}