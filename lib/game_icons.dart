import 'package:flutter/material.dart';

// ====================================================================
//  IKON GIM (PNG di assets/icon/)
//
//  Satu tempat untuk semua nama berkas ikon + widget [GameIcon].
//  Bila berkas hilang, [GameIcon] menampilkan kotak kosong (tidak crash).
// ====================================================================

abstract final class GIcon {
  static const String _d = 'assets/icon/';

  static const String addRoom = '${_d}addroom.png'; //     bangun kamar
  static const String addBin = '${_d}addbin.png'; //       upgrade bank sampah
  static const String upHouse = '${_d}uphouse.png'; //     naik kelas kost
  static const String callTruck = '${_d}calltruck.png'; // sewa truk sampah
  static const String bin = '${_d}bin.png'; //             bakar sampah / insinerator
  static const String addFence = '${_d}addfence.png'; //   pertahanan
  static const String addPet = '${_d}addpet.png'; //       hewan peliharaan
  static const String coinBunk = '${_d}coinbunk.png'; //   uang
  static const String emoji = '${_d}emoji.png'; //         reaksi emoji
  static const String warehouse = '${_d}werehouse.png'; // gudang (nama berkas: werehouse)
  static const String binBig = '${_d}binbig.png'; //       isi kotak sampah
  static const String polutan = '${_d}polutan.png'; //     polusi
  static const String timer = '${_d}timer.png'; //         kesintasan / waktu
  static const String construct = '${_d}construct.png'; // buat ruangan
  static const String cancel = '${_d}cancel.png'; //       tolak
  static const String accept = '${_d}accept.png'; //       terima
  static const String agree = '${_d}agree.png'; //         loket sampah / gabung
  static const String load = '${_d}load.png'; //           kirim sampah ke gudang
  static const String truckLoad = '${_d}truckload.png'; // buang gudang (truk gudang)
  static const String list = '${_d}list.png'; //           kabar terbaru
  static const String warning = '${_d}warning.png'; //     peringatan
  static const String defence = '${_d}defence.png'; //     tangkis
  static const String virus = '${_d}virus.png'; //         kabut / gas beracun
  static const String disaster = '${_d}disaster.png'; //   cuaca & bencana

  static const List<String> all = [
    addRoom, addBin, upHouse, callTruck, bin, addFence, addPet, coinBunk,
    emoji, warehouse, binBig, polutan, timer, construct, cancel, accept,
    agree, load, truckLoad, list, warning, defence, virus, disaster,
  ];
}

/// Memuat semua ikon ke cache gambar supaya tidak berkedip saat pertama tampil.
void precacheGameIcons(BuildContext context) {
  for (final a in GIcon.all) {
    precacheImage(AssetImage(a), context, onError: (_, __) {});
  }
}

class GameIcon extends StatelessWidget {
  const GameIcon(this.asset, {super.key, this.size = 24});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
    );
  }
}

/// Ikon Material -> ikon PNG gim (bila ada padanannya), selain itu tetap
/// ikon Material. Dipakai untuk chip status, kabar, dan lembar rincian.
String? assetForIcon(IconData i) {
  if (i == Icons.warning_amber_rounded) return GIcon.warning;
  if (i == Icons.masks) return GIcon.virus;
  if (i == Icons.cloud) return GIcon.polutan;
  if (i == Icons.timer) return GIcon.timer;
  if (i == Icons.storefront) return GIcon.agree;
  if (i == Icons.local_shipping) return GIcon.callTruck;
  if (i == Icons.add_home_work) return GIcon.addRoom;
  if (i == Icons.shield || i == Icons.security) return GIcon.defence;
  if (i == Icons.recycling) return GIcon.addBin;
  if (i == Icons.workspace_premium) return GIcon.upHouse;
  if (i == Icons.local_fire_department || i == Icons.factory) return GIcon.bin;
  if (i == Icons.emoji_emotions) return GIcon.emoji;
  if (i == Icons.thunderstorm ||
      i == Icons.water_drop ||
      i == Icons.air ||
      i == Icons.wb_sunny ||
      i == Icons.power_off ||
      i == Icons.vibration) {
    return GIcon.disaster;
  }
  return null;
}

/// Ikon PNG bila ada padanannya (sedikit lebih besar, karena PNG berbentuk
/// kotak penuh), kalau tidak ikon Material biasa.
Widget gIcon(IconData i, double size, Color color) {
  final a = assetForIcon(i);
  if (a != null) return GameIcon(a, size: size * 1.35);
  return Icon(i, size: size, color: color);
}