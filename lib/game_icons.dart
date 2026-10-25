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
  static const String load = '${_d}movebintowerehouse.png'; // kirim sampah ke gudang
  static const String truckLoad = '${_d}truckwerehouse.png'; // buang gudang (truk gudang)
  static const String list = '${_d}list.png'; //           kabar terbaru
  static const String warning = '${_d}warning.png'; //     peringatan
  static const String defence = '${_d}defence.png'; //     tangkis
  static const String virus = '${_d}virus.png'; //         kabut / gas beracun
  static const String disaster = '${_d}disaster.png'; //   cuaca & bencana

  // ---- set ikon baru ----
  static const String nameTag = '${_d}name.png'; //                 kolom nama pemain / karakter
  static const String addHouse = '${_d}addhouse.png'; //            buat ruangan
  static const String joinRoom = '${_d}joinroom.png'; //            gabung ruangan
  static const String play = '${_d}play.png'; //                    mulai / main
  static const String addInvite = '${_d}addinvite.png'; //          slot pemain kosong
  static const String back = '${_d}back.png'; //                    kembali
  static const String survival = '${_d}survival.png'; //            mode kesintasan
  static const String leaderboard = '${_d}leaderboard.png'; //      papan skor
  static const String graphicHigh = '${_d}grafikhigh.png'; //       mode ringan: mati
  static const String graphicMedium = '${_d}grafikmedium.png'; //   mode ringan: ringan
  static const String graphicLow = '${_d}grafiklow.png'; //         mode ringan: sangat ringan
  static const String setting = '${_d}setting.png'; //              pengaturan
  static const String roomCode = '${_d}roomcode.png'; //            kode ruangan
  static const String info = '${_d}info.png'; //                    info
  static const String maps = '${_d}maps.png'; //                    peta / lokasi
  static const String trashSmall = '${_d}sampahkecil.png'; //       lemparan biasa
  static const String trashBig = '${_d}sampahbesar.png'; //         lemparan karung
  static const String houseOwn = '${_d}houseown.png'; //            rumahku
  static const String houseNeighbor = '${_d}houseneighbor.png'; //  rumah tetangga
  static const String toga = '${_d}toga.png'; //                    musim mahasiswa baru
  static const String poison = '${_d}poison.png'; //                lemparan polusi / racun
  static const String bin1 = '${_d}sampah1.png'; //                 level bank sampah
  static const String binPlus = '${_d}sampahplus.png'; //           upgrade kotak / mesin daur ulang
  static const String incineratorPlus = '${_d}inseneratorplus.png'; //       upgrade insinerator polusi
  static const String incineratorEcoPlus = '${_d}inseneratorecoplus.png'; // upgrade insinerator eco

  // ---- set ikon tambahan ----
  static const String copy = '${_d}copy.png'; //                    salin
  static const String player = '${_d}player.png'; //                jumlah / daftar pemain
  static const String alreadyOrSip = '${_d}alreadyorsip.png'; //    sudah siap / selesai
  static const String notYet = '${_d}notyet.png'; //                belum siap
  static const String customization = '${_d}customization.png'; //  kustomisasi
  static const String crown = '${_d}crown.png'; //                  host
  static const String random = '${_d}random.png'; //                acak
  static const String home = '${_d}home.png'; //                    beranda / bangunan
  static const String character = '${_d}character.png'; //          karakter
  static const String timeWait = '${_d}timewait.png'; //            menunggu
  static const String gameMode = '${_d}gamemode.png'; //            mode permainan
  static const String howTo = '${_d}howto.png'; //                  cara main
  static const String appInfo = '${_d}appinfo.png'; //              info aplikasi
  static const String otherGames = '${_d}othergames.png'; //        gim lain
  static const String skip = '${_d}skip.png'; //                    lewati
  static const String left = '${_d}left.png'; //                    sebelumnya
  static const String right = '${_d}right.png'; //                  berikutnya
  static const String crown2 = '${_d}crown2.png'; //                juara / menang
  static const String alert = '${_d}alert.png'; //                  bahaya / kalah

  // ---- set ikon ketiga ----
  static const String offer = '${_d}penawaran.png'; //              tawaran titip sampah
  static const String truckHijack = '${_d}truckbajak.png'; //       truk dibajak / mogok
  static const String policeReport = '${_d}policereport.png'; //    lapor polisi
  static const String defensive = '${_d}defensive.png'; //          pertahanan
  static const String defensiveUp = '${_d}defensiveup.png'; //      pertahanan naik level
  static const String bedroom = '${_d}bedroom.png'; //              kamar tidur
  static const String room = '${_d}room.png'; //                    ruangan
  static const String type = '${_d}type.png'; //                    jenis / tipe
  static const String tier = '${_d}tingkatan.png'; //               tingkatan / level
  static const String waiting = '${_d}waiting.png'; //              menunggu
  static const String win = '${_d}menang.png'; //                   banner menang
  static const String lose = '${_d}kalah.png'; //                   banner kalah
  static const String timePlus = '${_d}timeplus.png'; //            tambah waktu
  static const String recycle = '${_d}recycle.png'; //              daur ulang
  static const String ghost = '${_d}ghost.png'; //                  hantu / penonton
  static const String sound = '${_d}sound.png'; //                  efek suara
  static const String music = '${_d}music.png'; //                  musik
  static const String starts = '${_d}starts.png'; //                banner "Mulai!"

  static const List<String> all = [
    offer, truckHijack, policeReport, defensive, defensiveUp, bedroom, room,
    type, tier, waiting, win, lose, timePlus, recycle, ghost, sound, music,
    starts,
    copy, player, alreadyOrSip, notYet, customization, crown, random, home,
    character, timeWait, gameMode, howTo, appInfo, otherGames, skip, left,
    right, crown2, alert,
    addRoom, addBin, upHouse, callTruck, bin, addFence, addPet, coinBunk,
    emoji, warehouse, binBig, polutan, timer, construct, cancel, accept,
    agree, load, truckLoad, list, warning, defence, virus, disaster,
    nameTag, addHouse, joinRoom, play, addInvite, back, survival, leaderboard,
    graphicHigh, graphicMedium, graphicLow, setting, roomCode, info, maps,
    trashSmall, trashBig, houseOwn, houseNeighbor, toga, poison, bin1, binPlus,
    incineratorPlus, incineratorEcoPlus,
  ];
}

/// Ikon Mode Ringan menurut tingkat: 0 Mati = grafik tinggi,
/// 1 Ringan = sedang, 2 Sangat Ringan = rendah.
String perfIcon(int level) => switch (level) {
  0 => GIcon.graphicHigh,
  1 => GIcon.graphicMedium,
  _ => GIcon.graphicLow,
};

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

/// Ikon PNG dalam bingkai bulat berwarna + bayangan, sama seperti tombol
/// mengambang di layar game. Dipakai di lobi supaya ikon tidak "menyatu"
/// dengan latar tombol dan ukurannya seragam.
class GameIconBadge extends StatelessWidget {
  const GameIconBadge(
      this.asset, {
        super.key,
        this.size = 30,
        this.ring = Colors.white,
        this.ringWidth = 2.0,
      });

  final String asset;
  final double size;
  final Color ring;
  final double ringWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: ringWidth),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: ClipOval(child: GameIcon(asset, size: size)),
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
  if (i == Icons.visibility) return GIcon.ghost;
  if (i == Icons.school) return GIcon.toga;
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

/// Tombol kotak berisi ikon PNG penuh (tanpa teks). Keterangan muncul saat
/// ditahan (layar sentuh) atau kursor diarahkan (desktop/web).
class GameIconButton extends StatefulWidget {
  const GameIconButton({
    super.key,
    required this.asset,
    required this.tip,
    required this.onTap,
    this.size = 48,
    this.ring = Colors.white54,
    this.selected = false,
    this.busy = false,
  });

  final String asset;
  final String tip;
  final VoidCallback? onTap;
  final double size;
  final Color ring;
  final bool selected;
  final bool busy;

  @override
  State<GameIconButton> createState() => _GameIconButtonState();
}

class _GameIconButtonState extends State<GameIconButton> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final size = widget.size;
    final ring = widget.selected ? const Color(0xFFFFCA28) : widget.ring;
    return Tooltip(
      message: widget.tip,
      waitDuration: const Duration(milliseconds: 300),
      triggerMode: TooltipTriggerMode.longPress,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.tip,
        child: MouseRegion(
          cursor:
          enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => _setDown(true) : null,
            onTapUp: (_) => _setDown(false),
            onTapCancel: () => _setDown(false),
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: _down ? 0.92 : 1,
              duration: const Duration(milliseconds: 90),
              child: Opacity(
                opacity: (enabled || widget.busy) ? 1 : 0.45,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.26),
                    border: Border.all(
                        color: ring, width: widget.selected ? 3 : 2),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black45,
                          blurRadius: 8,
                          offset: Offset(0, 3)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(size * 0.2),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        GameIcon(widget.asset, size: size),
                        if (widget.busy)
                          Container(
                            color: Colors.black54,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: size * 0.38,
                              height: size * 0.38,
                              child: const CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Color(0xFFFFCA28),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}