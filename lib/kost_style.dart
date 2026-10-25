import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Palet & model kustomisasi. Batas indeks di sini HARUS sama dengan
/// `_style_valid` di Supabase (lihat style_valid_update.sql). Indeks lama
/// tidak boleh dipindah, hanya ditambah di belakang, supaya tampilan yang
/// sudah tersimpan tidak berubah.
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
    Color(0xFFE8B4A0), // 6 kemerahan
    Color(0xFFC9A66B), // 7 zaitun
    Color(0xFFE3A857), // 8 madu
    Color(0xFF4A2C17), // 9 eboni
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
    Color(0xFF1A237E), // 12 biru tua
    Color(0xFF7B1F2E), // 13 marun
    Color(0xFFF5E6C8), // 14 krem
    Color(0xFF212121), // 15 hitam
  ];

  /// Model baju (indeks 0 = kaos polos seperti semula).
  static const List<String> topNames = [
    'Kaos',
    'Kaos garis',
    'Kemeja',
    'Hoodie',
    'Rompi',
    'Singlet',
    'Batik',
  ];

  /// Warna celana / rok (indeks 0 = abu gelap seperti semula).
  static const List<Color> pants = [
    Color(0xFF37474F),
    Color(0xFF212121),
    Color(0xFF1A237E),
    Color(0xFF3F6FB5),
    Color(0xFF6D4C41),
    Color(0xFFC2A878),
    Color(0xFFECEFF1),
    Color(0xFFC62828),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFF06292),
    Color(0xFFF9A825),
  ];

  static const List<String> pantsNames = [
    'Abu gelap',
    'Hitam',
    'Navy',
    'Jeans',
    'Cokelat',
    'Khaki',
    'Putih',
    'Merah',
    'Hijau',
    'Ungu',
    'Pink',
    'Kuning',
  ];

  /// Model bawahan (indeks 0 = celana panjang seperti semula).
  static const List<String> pantsStyleNames = [
    'Panjang',
    'Pendek',
    'Rok',
    'Training',
    'Kulot',
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
    'Poni',
    'Kribo',
    'Mohawk',
    'Kuncir',
    'Kuncir dua',
    'Kupluk',
    'Hijab',
    'Peci',
    'Bob',
  ];

  static const List<String> accNames = [
    'Tanpa',
    'Kacamata',
    'Bando',
    'Headphone',
    'Kumis',
    'Kacamata hitam',
    'Masker',
    'Syal',
    'Anting',
    'Jenggot',
    'Pita',
    'Mahkota',
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
    this.top = 0,
    this.pants = 0,
    this.pantsStyle = 0,
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
  final int? shirt; // warna baju
  final int top; // 0..6 model baju
  final int pants; // 0..11 warna celana
  final int pantsStyle; // 0..4 model celana
  final int hair; // 0..14
  final int hairColor; // 0..7
  final int acc; // 0..11

  static const KostStyle empty = KostStyle();

  bool get isEmpty =>
      wall == null &&
          roof == null &&
          sign == null &&
          door == null &&
          name.isEmpty &&
          skin == null &&
          shirt == null &&
          top == 0 &&
          pants == 0 &&
          pantsStyle == 0 &&
          hair == 0 &&
          acc == 0;

  Color? get wallColor => wall == null ? null : KostPalette.walls[wall!];
  Color? get roofColor => roof == null ? null : KostPalette.roofs[roof!];
  Color? get signColor => sign == null ? null : KostPalette.signs[sign!];
  Color? get doorColor => door == null ? null : KostPalette.doors[door!];

  /// Ada kustomisasi karakter? (kalau tidak, penghuni digambar seperti semula)
  bool get hasLook =>
      skin != null ||
          shirt != null ||
          top != 0 ||
          pants != 0 ||
          pantsStyle != 0 ||
          hair != 0 ||
          acc != 0;

  KostLook look({Color fallbackShirt = const Color(0xFF42A5F5)}) => KostLook(
    skin: skin == null
        ? const Color(0xFFE0AC84)
        : KostPalette.skins[skin!],
    shirt: shirt == null ? fallbackShirt : KostPalette.shirts[shirt!],
    shirtStyle: top,
    pants: KostPalette.pants[pants],
    pantsStyle: pantsStyle,
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
      top: _idx(json['top'], KostPalette.topNames.length - 1) ?? 0,
      pants: _idx(json['pants'], KostPalette.pants.length - 1) ?? 0,
      pantsStyle:
      _idx(json['pstyle'], KostPalette.pantsStyleNames.length - 1) ?? 0,
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
    if (top != 0) 'top': top,
    if (pants != 0) 'pants': pants,
    if (pantsStyle != 0) 'pstyle': pantsStyle,
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
    int? top,
    int? pants,
    int? pantsStyle,
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
        top: top ?? this.top,
        pants: pants ?? this.pants,
        pantsStyle: pantsStyle ?? this.pantsStyle,
        hair: hair ?? this.hair,
        hairColor: hairColor ?? this.hairColor,
        acc: acc ?? this.acc,
      );

  /// Bagian bangunan dikembalikan ke bawaan (karakter tetap).
  KostStyle clearBuilding() => KostStyle(
    skin: skin,
    shirt: shirt,
    top: top,
    pants: pants,
    pantsStyle: pantsStyle,
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
    top: r.nextInt(KostPalette.topNames.length),
    pants: r.nextInt(KostPalette.pants.length),
    pantsStyle: r.nextInt(KostPalette.pantsStyleNames.length),
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
    top: top,
    pants: pants,
    pantsStyle: pantsStyle,
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
          other.top == top &&
          other.pants == pants &&
          other.pantsStyle == pantsStyle &&
          other.hair == hair &&
          other.hairColor == hairColor &&
          other.acc == acc;

  @override
  int get hashCode => Object.hash(wall, roof, sign, door, name, skin, shirt,
      top, pants, pantsStyle, hair, hairColor, acc);
}

/// Tampilan karakter yang sudah "dihitung" jadi warna siap gambar.
/// Field baru punya nilai bawaan, jadi kode lama yang membuat KostLook tanpa
/// field itu tetap jalan dan menggambar karakter seperti semula.
@immutable
class KostLook {
  const KostLook({
    required this.skin,
    required this.shirt,
    required this.hair,
    required this.hairColor,
    required this.acc,
    this.shirtStyle = 0,
    this.pants = const Color(0xFF37474F),
    this.pantsStyle = 0,
  });

  final Color skin;
  final Color shirt;
  final int shirtStyle;
  final Color pants;
  final int pantsStyle;
  final int hair;
  final Color hairColor;
  final int acc;

  @override
  bool operator ==(Object other) =>
      other is KostLook &&
          other.skin == skin &&
          other.shirt == shirt &&
          other.shirtStyle == shirtStyle &&
          other.pants == pants &&
          other.pantsStyle == pantsStyle &&
          other.hair == hair &&
          other.hairColor == hairColor &&
          other.acc == acc;

  @override
  int get hashCode => Object.hash(
      skin, shirt, shirtStyle, pants, pantsStyle, hair, hairColor, acc);
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

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// Setengah cakram rambut dengan garis rambut miring (rendah di belakang,
/// tinggi di dahi) supaya mata tetap terlihat. [r] = jari-jari.
Path _capPath(double r) => Path()
  ..moveTo(-r, 0)
  ..arcTo(Rect.fromCircle(center: Offset.zero, radius: r), math.pi,
      math.pi - 0.44, false)
  ..close();

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
      case 6: // poni rata
        canvas.drawPath(_capPath(1.14), p);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(0.0, -0.9, 1.02, -0.4),
              const Radius.circular(0.18)),
          p,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(-1.16, -0.4, -0.75, 0.55),
              const Radius.circular(0.2)),
          p,
        );
        break;
      case 7: // kribo
        canvas.drawPath(_capPath(1.1), p);
        for (final deg in const [
          -55.0, -80.0, -105.0, -130.0, -155.0, -180.0, -205.0
        ]) {
          final a = deg * math.pi / 180;
          canvas.drawCircle(
              Offset(1.12 * math.cos(a), 1.12 * math.sin(a)), 0.52, p);
        }
        break;
      case 8: // mohawk
        const tips = [1.8, 2.05, 2.25, 2.05, 1.75];
        for (var i = 0; i < 5; i++) {
          final x = -0.8 + i * 0.4;
          final yb = -math.sqrt(math.max(0.0, 1 - x * x)) + 0.14;
          canvas.drawPath(
            Path()
              ..moveTo(x - 0.27, yb)
              ..lineTo(x + 0.02, -tips[i])
              ..lineTo(x + 0.27, yb)
              ..close(),
            p,
          );
        }
        break;
      case 9: // kuncir
        canvas.drawPath(_capPath(1.12), p);
        canvas.drawPath(
          Path()
            ..moveTo(-1.0, -0.8)
            ..quadraticBezierTo(-2.3, -0.9, -2.0, 0.9)
            ..quadraticBezierTo(-1.6, 0.0, -0.95, -0.15)
            ..close(),
          p,
        );
        p.color = const Color(0xFFE53935);
        canvas.drawCircle(const Offset(-1.05, -0.5), 0.26, p);
        break;
      case 10: // kuncir dua
        canvas.drawPath(_capPath(1.12), p);
        canvas.drawPath(
          Path()
            ..moveTo(-0.95, -0.95)
            ..quadraticBezierTo(-2.15, -1.35, -2.0, 0.1)
            ..quadraticBezierTo(-1.55, -0.55, -0.85, -0.55)
            ..close(),
          p,
        );
        canvas.drawPath(
          Path()
            ..moveTo(-0.95, -0.4)
            ..quadraticBezierTo(-2.15, -0.35, -1.9, 1.15)
            ..quadraticBezierTo(-1.45, 0.3, -0.8, 0.05)
            ..close(),
          p,
        );
        p.color = const Color(0xFFEC407A);
        canvas.drawCircle(const Offset(-1.0, -0.72), 0.22, p);
        canvas.drawCircle(const Offset(-0.98, -0.22), 0.22, p);
        break;
      case 11: // kupluk
        canvas.drawPath(_capPath(1.26), p);
        p.color = _mix(hc, Colors.black, 0.28);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(-1.32, -0.78, 1.3, -0.36),
              const Radius.circular(0.16)),
          p,
        );
        p.color = _mix(hc, Colors.white, 0.5);
        canvas.drawCircle(const Offset(0, -1.3), 0.36, p);
        break;
      case 12: // hijab (warna mengikuti warna rambut)
        canvas.drawPath(_capPath(1.26), p);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(-1.3, -0.3, 0.2, 1.6),
              const Radius.circular(0.4)),
          p,
        );
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.3
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: 1.06),
            -1.25, 3.1, false, p);
        p.style = PaintingStyle.fill;
        break;
      case 13: // peci
        canvas.drawPath(
          Path()
            ..moveTo(-0.98, -0.5)
            ..lineTo(-0.82, -1.42)
            ..lineTo(0.82, -1.42)
            ..lineTo(0.98, -0.5)
            ..close(),
          p,
        );
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.12
          ..color = _mix(hc, Colors.white, 0.35);
        canvas.drawLine(const Offset(-0.98, -0.55), const Offset(0.98, -0.55), p);
        p.style = PaintingStyle.fill;
        break;
      case 14: // bob
        canvas.drawPath(_capPath(1.14), p);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(-1.22, -0.45, -0.4, 1.0),
              const Radius.circular(0.3)),
          p,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(-0.5, -0.4, 0.0, 0.85),
              const Radius.circular(0.2)),
          p,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTRB(0.15, -0.9, 1.1, -0.4),
              const Radius.circular(0.18)),
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
    case 5: // kacamata hitam
      p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF212121);
      canvas.drawOval(
          Rect.fromCenter(
              center: const Offset(0.3, -0.06), width: 0.74, height: 0.52),
          p);
      canvas.drawOval(
          Rect.fromCenter(
              center: const Offset(0.97, -0.06), width: 0.62, height: 0.5),
          p);
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.14
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(0.62, -0.1), const Offset(0.7, -0.1), p);
      canvas.drawLine(const Offset(-0.07, -0.1), const Offset(-1.0, -0.2), p);
      p.style = PaintingStyle.fill;
      break;
    case 6: // masker
      p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFCFE8F5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTRB(0.0, 0.08, 1.06, 0.64),
            const Radius.circular(0.14)),
        p,
      );
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.07
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF90A4AE);
      canvas.drawLine(const Offset(0.1, 0.24), const Offset(0.96, 0.24), p);
      canvas.drawLine(const Offset(0.1, 0.42), const Offset(0.96, 0.42), p);
      canvas.drawLine(const Offset(0.0, 0.2), const Offset(-0.55, -0.02), p);
      p.style = PaintingStyle.fill;
      break;
    case 7: // syal
      p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFE53935);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTRB(-1.2, 0.92, 1.2, 1.48),
            const Radius.circular(0.24)),
        p,
      );
      p.color = const Color(0xFFB71C1C);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTRB(-0.95, 1.3, -0.35, 2.4),
            const Radius.circular(0.16)),
        p,
      );
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.12
        ..color = Colors.white.withValues(alpha: 0.85);
      canvas.drawLine(const Offset(-0.95, 1.75), const Offset(-0.35, 1.75), p);
      canvas.drawLine(const Offset(-0.95, 2.05), const Offset(-0.35, 2.05), p);
      p.style = PaintingStyle.fill;
      break;
    case 8: // anting
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.08
        ..color = const Color(0xFFFFD54F);
      canvas.drawLine(const Offset(-0.06, 0.34), const Offset(-0.06, 0.5), p);
      p.style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(-0.06, 0.68), 0.21, p);
      break;
    case 9: // jenggot
      p
        ..style = PaintingStyle.fill
        ..color = hc;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTRB(-0.3, 0.46, 1.0, 1.28),
            const Radius.circular(0.5)),
        p,
      );
      break;
    case 10: // pita
      p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFEC407A);
      canvas.drawPath(
        Path()
          ..moveTo(-0.3, -1.12)
          ..lineTo(-1.0, -1.6)
          ..lineTo(-1.0, -0.7)
          ..close(),
        p,
      );
      canvas.drawPath(
        Path()
          ..moveTo(-0.3, -1.12)
          ..lineTo(0.4, -1.6)
          ..lineTo(0.4, -0.7)
          ..close(),
        p,
      );
      p.color = const Color(0xFFC2185B);
      canvas.drawCircle(const Offset(-0.3, -1.12), 0.2, p);
      break;
    case 11: // mahkota
      p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFC107);
      canvas.drawPath(
        Path()
          ..moveTo(-0.72, -0.8)
          ..lineTo(-0.78, -1.78)
          ..lineTo(-0.36, -1.4)
          ..lineTo(0, -1.95)
          ..lineTo(0.36, -1.4)
          ..lineTo(0.78, -1.78)
          ..lineTo(0.72, -0.8)
          ..close(),
        p,
      );
      p.color = const Color(0xFFE53935);
      canvas.drawCircle(const Offset(0, -1.15), 0.14, p);
      p.color = const Color(0xFF42A5F5);
      canvas.drawCircle(const Offset(-0.42, -1.0), 0.1, p);
      canvas.drawCircle(const Offset(0.42, -1.0), 0.1, p);
      break;
  }
}

// ======================================================================
//  BAJU & CELANA (model dan warna)
// ======================================================================

/// Kaki + bawahan (berdiri). Kaki tidak ikut miring.
void _paintLegs(
    Canvas canvas, Paint p, KostLook look, double stance, double sw) {
  const hipL = Offset(-0.6, -6);
  const hipR = Offset(0.6, -6);
  final footL = Offset(-1.2 - stance + sw, 0);
  final footR = Offset(1.2 + stance - sw, 0);
  final pc = look.pants;

  void leg(Offset a, Offset b, double w, Color c) {
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = c;
    canvas.drawLine(a, b, p);
  }

  switch (look.pantsStyle) {
    case 1: // pendek: paha bercelana, betis terlihat
      for (final e in [(hipL, footL), (hipR, footR)]) {
        final knee = Offset.lerp(e.$1, e.$2, 0.45)!;
        leg(knee, e.$2, 1.6, look.skin);
        leg(e.$1, knee, 2.2, pc);
      }
      break;
    case 2: // rok: kaki terlihat, rok menutup pinggul
      leg(hipL, footL, 1.6, look.skin);
      leg(hipR, footR, 1.6, look.skin);
      p
        ..style = PaintingStyle.fill
        ..color = pc;
      canvas.drawPath(
        Path()
          ..moveTo(-3.0, -6.6)
          ..lineTo(3.0, -6.6)
          ..lineTo(4.1, -2.6)
          ..lineTo(-4.1, -2.6)
          ..close(),
        p,
      );
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = _mix(pc, Colors.white, 0.35);
      canvas.drawLine(const Offset(-4.1, -2.75), const Offset(4.1, -2.75), p);
      break;
    case 4: // kulot: celana lebar
      p
        ..style = PaintingStyle.fill
        ..color = pc;
      for (final e in [(hipL, footL), (hipR, footR)]) {
        canvas.drawPath(
          Path()
            ..moveTo(e.$1.dx - 1.1, -6.2)
            ..lineTo(e.$1.dx + 1.1, -6.2)
            ..lineTo(e.$2.dx + 1.7, -0.6)
            ..lineTo(e.$2.dx - 1.7, -0.6)
            ..close(),
          p,
        );
      }
      break;
    case 3: // training: garis putih di sisi
      leg(hipL, footL, 1.8, pc);
      leg(hipR, footR, 1.8, pc);
      leg(hipL + const Offset(-0.45, 0), footL + const Offset(-0.45, 0), 0.4,
          Colors.white.withValues(alpha: 0.85));
      leg(hipR + const Offset(-0.45, 0), footR + const Offset(-0.45, 0), 0.4,
          Colors.white.withValues(alpha: 0.85));
      break;
    default: // panjang
      leg(hipL, footL, 1.8, pc);
      leg(hipR, footR, 1.8, pc);
      break;
  }
}

/// Kaki saat duduk (pose sedih).
void _paintSeatedLegs(Canvas canvas, Paint p, KostLook look, bool onBox) {
  final bare = look.pantsStyle == 1 || look.pantsStyle == 2;
  void seg(Offset a, Offset b, bool lower) {
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = (bare && lower) ? look.skin : look.pants;
    canvas.drawLine(a, b, p);
  }

  if (onBox) {
    const a0 = Offset(-1, 0), a1 = Offset(-6, 11);
    const b0 = Offset(2, 0), b1 = Offset(4, 11);
    final ak = Offset.lerp(a0, a1, 0.45)!;
    final bk = Offset.lerp(b0, b1, 0.45)!;
    seg(a0, ak, false);
    seg(ak, a1, true);
    seg(b0, bk, false);
    seg(bk, b1, true);
  } else {
    seg(const Offset(0, 0), const Offset(5.6, -0.4), false);
    seg(const Offset(5.6, -0.4), const Offset(6.2, 3.4), true);
    seg(const Offset(-0.4, 0.6), const Offset(4.8, 0.4), false);
    seg(const Offset(4.8, 0.4), const Offset(5.4, 3.4), true);
  }
}

/// Lengan: warna dan panjang lengan mengikuti model baju.
void _paintArm(
    Canvas canvas, Paint p, KostLook look, Offset from, Offset to) {
  p
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round;
  switch (look.shirtStyle) {
    case 4: // rompi: lengan kemeja putih
      p.color = const Color(0xFFF1F1F1);
      canvas.drawLine(from, to, p);
      break;
    case 5: // singlet: lengan terbuka
      final mid = Offset.lerp(from, to, 0.28)!;
      p.color = look.shirt;
      canvas.drawLine(from, mid, p);
      p.color = look.skin;
      canvas.drawLine(mid, to, p);
      break;
    default:
      p.color = look.shirt;
      canvas.drawLine(from, to, p);
  }
}

/// Kapuci hoodie di belakang kepala (digambar sebelum kepala).
void _paintHood(Canvas canvas, Paint p, KostLook look, Offset c) {
  if (look.shirtStyle != 3) return;
  p
    ..style = PaintingStyle.fill
    ..color = _mix(look.shirt, Colors.black, 0.2);
  canvas.drawOval(Rect.fromCenter(center: c, width: 5.6, height: 4.2), p);
}

/// Badan + hiasan model baju di dalam persegi [r].
void _paintTop(
    Canvas canvas, Paint p, KostLook look, Rect r, double radius) {
  final body = RRect.fromRectAndRadius(r, Radius.circular(radius));
  Offset at(double fx, double fy) =>
      Offset(r.left + fx * r.width, r.top + fy * r.height);
  final u = r.width / 6.4;

  p
    ..style = PaintingStyle.fill
    ..strokeCap = StrokeCap.butt
    ..color = look.shirt;
  canvas.drawRRect(body, p);

  final light = _mix(look.shirt, Colors.white, 0.55);
  final dark = _mix(look.shirt, Colors.black, 0.3);
  final accent = look.shirt.computeLuminance() > 0.55 ? dark : light;

  switch (look.shirtStyle) {
    case 1: // kaos garis
      canvas.save();
      canvas.clipRRect(body);
      p.color = accent.withValues(alpha: 0.8);
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(
          Rect.fromLTWH(r.left, r.top + r.height * (0.14 + i * 0.22),
              r.width, r.height * 0.09),
          p,
        );
      }
      canvas.restore();
      break;
    case 2: // kemeja: kerah + kancing
      p.color = look.shirt.computeLuminance() > 0.7
          ? _mix(look.shirt, Colors.black, 0.12)
          : _mix(look.shirt, Colors.white, 0.8);
      canvas.drawPath(
        Path()
          ..moveTo(at(0.12, 0).dx, at(0.12, 0).dy)
          ..lineTo(at(0.5, 0.28).dx, at(0.5, 0.28).dy)
          ..lineTo(at(0.88, 0).dx, at(0.88, 0).dy)
          ..close(),
        p,
      );
      p.color = dark;
      for (var k = 0; k < 3; k++) {
        canvas.drawCircle(at(0.5, 0.45 + k * 0.2), 0.3 * u, p);
      }
      break;
    case 3: // hoodie: kantong + tali
      p.color = _mix(look.shirt, Colors.black, 0.2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromPoints(at(0.2, 0.62), at(0.8, 0.9)),
            Radius.circular(0.6 * u)),
        p,
      );
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.35 * u
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.85);
      canvas.drawLine(at(0.4, 0.08), at(0.4, 0.38), p);
      canvas.drawLine(at(0.6, 0.08), at(0.6, 0.38), p);
      p.style = PaintingStyle.fill;
      break;
    case 4: // rompi: kemeja putih di tengah
      p.color = const Color(0xFFF1F1F1);
      canvas.drawPath(
        Path()
          ..moveTo(at(0.22, 0).dx, at(0.22, 0).dy)
          ..lineTo(at(0.5, 0.62).dx, at(0.5, 0.62).dy)
          ..lineTo(at(0.78, 0).dx, at(0.78, 0).dy)
          ..close(),
        p,
      );
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.3 * u
        ..strokeJoin = StrokeJoin.round
        ..color = dark;
      canvas.drawPath(
        Path()
          ..moveTo(at(0.22, 0).dx, at(0.22, 0).dy)
          ..lineTo(at(0.5, 0.62).dx, at(0.5, 0.62).dy)
          ..lineTo(at(0.78, 0).dx, at(0.78, 0).dy),
        p,
      );
      p.style = PaintingStyle.fill;
      break;
    case 5: // singlet: bahu terbuka
      canvas.save();
      canvas.clipRRect(body);
      p.color = look.skin;
      canvas.drawPath(
        Path()
          ..moveTo(r.left, r.top)
          ..lineTo(r.left + r.width * 0.26, r.top)
          ..lineTo(r.left, r.top + r.height * 0.42)
          ..close(),
        p,
      );
      canvas.drawPath(
        Path()
          ..moveTo(r.right, r.top)
          ..lineTo(r.right - r.width * 0.26, r.top)
          ..lineTo(r.right, r.top + r.height * 0.42)
          ..close(),
        p,
      );
      canvas.restore();
      break;
    case 6: // batik: motif belah ketupat
      const rows = [
        (0.18, [0.22, 0.5, 0.78]),
        (0.45, [0.36, 0.64]),
        (0.72, [0.22, 0.5, 0.78]),
      ];
      final sz = r.width * 0.125;
      for (final row in rows) {
        for (final fx in row.$2) {
          final c = at(fx, row.$1);
          p.color = accent.withValues(alpha: 0.85);
          canvas.drawPath(
            Path()
              ..moveTo(c.dx, c.dy - sz)
              ..lineTo(c.dx + sz, c.dy)
              ..lineTo(c.dx, c.dy + sz)
              ..lineTo(c.dx - sz, c.dy)
              ..close(),
            p,
          );
          p.color = dark;
          canvas.drawCircle(c, sz * 0.3, p);
        }
      }
      break;
  }
  p
    ..style = PaintingStyle.fill
    ..strokeCap = StrokeCap.butt;
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
  _paintLegs(canvas, p, look, stance, sw);
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
  _paintArm(canvas, p, look, const Offset(0, -12), hb);
  p
    ..style = PaintingStyle.fill
    ..color = look.skin;
  canvas.drawCircle(hb, 1.0, p);

  // badan (model baju mengikuti pilihan)
  _paintTop(canvas, p, look, const Rect.fromLTWH(-3.2, -14, 6.4, 9), 2.0);
  _paintHood(canvas, p, look, const Offset(-1.7, -15.2));

  // kepala
  p
    ..style = PaintingStyle.fill
    ..color = look.skin;
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
  _paintArm(canvas, p, look, const Offset(0, -12), hf);

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

  _paintSeatedLegs(canvas, p, look, onBox);

  canvas.save();
  canvas.rotate(0.3);
  _paintTop(canvas, p, look, const Rect.fromLTWH(-3.4, -11.5, 6.8, 11.5), 2.4);
  _paintHood(canvas, p, look, const Offset(0.0, -12.3));
  p
    ..style = PaintingStyle.fill
    ..color = look.skin;
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
  _paintArm(canvas, p, look, const Offset(0, -9), const Offset(4.4, -4.6));
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

// ======================================================================
//  IKON BADAN (pratinjau baju & celana di ruang kustomisasi)
// ======================================================================

class KostBodyIcon extends StatelessWidget {
  const KostBodyIcon({super.key, required this.look, this.size = 56});

  final KostLook look;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _BodyIconPainter(look)),
  );
}

class _BodyIconPainter extends CustomPainter {
  _BodyIconPainter(this.look);

  final KostLook look;
  final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height / 28;
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.97);
    canvas.scale(s);
    paintKostCharacter(canvas, _p, look);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BodyIconPainter old) => old.look != look;
}