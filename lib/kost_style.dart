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
}

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

/// Karakter utuh berdiri (kaki di titik asal, menghadap +x), dalam satuan
/// yang sama dengan penghuni di scene: tinggi sekitar 21.
/// [pose] 0 = berdiri, 1 = melambai.
void paintKostCharacter(Canvas canvas, Paint p, KostLook look,
    {double t = 0, int pose = 0, double phase = 0}) {
  final bob = math.sin(t * 2.4 + phase) * 0.35;
  canvas.save();
  canvas.translate(0, bob);

  p
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF37474F);
  canvas.drawLine(const Offset(-0.6, -6), const Offset(-1.2, 0), p);
  canvas.drawLine(const Offset(0.6, -6), const Offset(1.2, 0), p);

  p.color = look.shirt;
  // lengan belakang
  canvas.drawLine(const Offset(0, -12), const Offset(-3.6, -7.2), p);
  // lengan depan: melambai atau turun
  if (pose == 1) {
    final w = math.sin(t * 9 + phase) * 1.4;
    final hand = Offset(4.6 + w * 0.3, -19.2 + w * 0.5);
    canvas.drawLine(const Offset(0, -12), hand, p);
    p
      ..style = PaintingStyle.fill
      ..color = look.skin;
    canvas.drawCircle(hand, 1.35, p);
  } else {
    canvas.drawLine(const Offset(0, -12), const Offset(3.4, -7.4), p);
    p
      ..style = PaintingStyle.fill
      ..color = look.skin;
    canvas.drawCircle(const Offset(3.4, -7.4), 1.1, p);
  }

  p
    ..style = PaintingStyle.fill
    ..strokeCap = StrokeCap.butt
    ..color = look.shirt;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3.2, -14, 6.4, 9), const Radius.circular(2)),
    p,
  );

  p.color = look.skin;
  canvas.drawCircle(const Offset(0, -17.5), 3.2, p);

  // mata + senyum kecil
  p.color = const Color(0xFF3E2723);
  canvas.drawCircle(const Offset(1.4, -17.9), 0.45, p);
  p
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.35
    ..strokeCap = StrokeCap.round;
  canvas.drawArc(Rect.fromCenter(center: const Offset(1.5, -16.5), width: 1.6, height: 1.0),
      0.2, math.pi - 0.4, false, p);
  p
    ..style = PaintingStyle.fill
    ..strokeCap = StrokeCap.butt;

  canvas.save();
  canvas.translate(0, -17.5);
  canvas.scale(3.2);
  paintKostHeadGear(canvas, p, look);
  canvas.restore();

  canvas.restore();
}