import 'dart:math' as math;

// ====================================================================
//  GUDANG SAMPAH (sisi kanan kost)
//
//  Penyimpanan TERPISAH dari kapasitas sampah kost. Alur:
//    sampah -> kotak sampah kiri -> (tombol TUANG) -> gudang kanan
//    gudang kanan -> diproses perlahan jadi koin / diangkut TRUK GUDANG
//
//  Angka di file ini HARUS sama dengan warehouse.sql (server yang
//  menentukan; klien hanya menampilkan perkiraan).
// ====================================================================

/// Satu komponen tambahan gudang (dibeli bebas urutan setelah Gudang Kecil).
class WhComp {
  const WhComp(this.bit, this.name, this.emoji, this.desc, this.cost);
  final int bit; // posisi bit di kolom `comps`
  final String name;
  final String emoji;
  final String desc;
  final int cost;
}

const int kWhPenyortir = 0;
const int kWhPencacah = 1;
const int kWhPenggilingan = 2;
const int kWhIoT = 3;
const int kWhKonveyor = 4;
const int kWhTimbang = 5;

const List<WhComp> kWhComps = [
  WhComp(kWhPenyortir, 'Penyortir', '🗂️',
      'Truk gudang 40% lebih cepat (datang, angkut, dan jeda panggil ulang).', 400),
  WhComp(kWhPencacah, 'Pencacah', '⚙️',
      'Sampah dicacah saat dituang: volume -30%, gudang muat lebih banyak.', 450),
  WhComp(kWhPenggilingan, 'Penggilingan', '🏭',
      'Sampah olahan digiling jadi pelet: nilai koin hasil proses ×2.', 600),
  WhComp(kWhIoT, 'Sensor IoT', '📡',
      'Otomasi & pemantauan: laju pemrosesan gudang ×1,8.', 700),
  WhComp(kWhKonveyor, 'Ban Berjalan', '🛤️',
      'Jeda tombol Tuang turun dari 20 dtk menjadi 8 dtk.', 350),
  WhComp(kWhTimbang, 'Jembatan Timbang', '⚖️',
      'Biaya truk gudang -40% (ditimbang akurat, tanpa bocor).', 300),
];

/// Konstanta & rumus gudang.
abstract final class Wh {
  static const List<String> tierNames = [
    'Belum Dibangun',
    'Gudang Kecil',
    'Gudang Sedang',
    'Gudang Besar',
  ];
  static const int maxTier = 3;

  /// Biaya membangun / menaikkan ke tier [i].
  static const List<int> tierCost = [0, 250, 550, 1000];

  /// Kapasitas (satuan sampah) per tier.
  static const List<double> tierCap = [0, 60, 140, 260];

  /// Laju pemrosesan dasar (satuan/detik) per tier.
  static const List<double> tierProc = [0, 0.10, 0.16, 0.24];

  /// Koin per satuan sampah yang selesai diproses (sebelum penggilingan).
  static const double unitValue = 0.5;

  static const double truckBaseSec = 26; // lama satu perjalanan truk (adegan)
  static const double truckBaseCdSec = 75; // jeda setelah truk selesai
  static const double truckCostPerUnit = 1.5; // truk biasa: 3 per satuan
  static const double pourBaseCdSec = 20;
  static const double pourFastCdSec = 8;

  /// Lama animasi gerobak tuang (ms). Dipakai painter & klien.
  static const int pourAnimMs = 8000;

  /// Selama [pourPickupMs] pertama animasi, kotak kiri masih tampak penuh
  /// (gerobak sedang memuat) sebelum isinya "hilang".
  static const int pourPickupMs = 1800;

  static bool has(int comps, int bit) => ((comps >> bit) & 1) == 1;

  static double cap(int tier) => tierCap[tier.clamp(0, maxTier).toInt()];

  static double procRate(int tier, int comps) =>
      tierProc[tier.clamp(0, maxTier).toInt()] * (has(comps, kWhIoT) ? 1.8 : 1.0);

  static double coinPerUnit(int comps) =>
      unitValue * (has(comps, kWhPenggilingan) ? 2.0 : 1.0);

  /// Pengali volume saat menuang (pencacah memampatkan).
  static double volume(int comps) => has(comps, kWhPencacah) ? 0.7 : 1.0;

  static double truckSec(int comps) =>
      truckBaseSec * (has(comps, kWhPenyortir) ? 0.6 : 1.0);

  static double truckCdSec(int comps) =>
      truckBaseCdSec * (has(comps, kWhPenyortir) ? 0.6 : 1.0);

  static double pourCdSec(int comps) =>
      has(comps, kWhKonveyor) ? pourFastCdSec : pourBaseCdSec;

  static int truckCost(double amount, int comps) =>
      (amount * truckCostPerUnit * (has(comps, kWhTimbang) ? 0.6 : 1.0))
          .ceil();

  /// Berapa satuan isi kotak sampah kiri yang bisa dituang sekarang.
  /// Isi kotak = 1/3 kapasitas sampah kost (sama dengan gambar kotak penuh).
  static int pourAmount({
    required double liveTrash,
    required double trashCapacity,
    required double stored,
    required int tier,
    required int comps,
  }) {
    final inBin = math.min(liveTrash, trashCapacity / 3.0).floor();
    final free = cap(tier) - stored;
    final fit = (free / volume(comps)).floor();
    return math.max(0, math.min(inBin, fit));
  }
}

/// Keadaan gudang yang dihitung klien dari baris `player_warehouse`.
class WhLive {
  const WhLive({
    required this.tier,
    required this.comps,
    required this.stored,
    required this.truckAmount,
    required this.truckProgress,
    required this.truckLeft,
    required this.truckReadyLeft,
    required this.pourLeft,
    required this.pourAgeMs,
    required this.lastPourAmount,
  });

  static const WhLive none = WhLive(
    tier: 0,
    comps: 0,
    stored: 0,
    truckAmount: 0,
    truckProgress: null,
    truckLeft: 0,
    truckReadyLeft: 0,
    pourLeft: 0,
    pourAgeMs: null,
    lastPourAmount: 0,
  );

  final int tier;
  final int comps;
  final double stored;

  /// Muatan yang sudah dipesan truk (belum dimuat), 0 bila tidak ada.
  final double truckAmount;

  /// 0..1 selama adegan truk gudang berjalan; null bila tidak ada truk.
  final double? truckProgress;
  final double truckLeft; // detik sisa perjalanan truk
  final double truckReadyLeft; // detik sampai truk boleh dipanggil lagi
  final double pourLeft; // detik jeda tombol Tuang
  final int? pourAgeMs; // umur animasi gerobak; null = tidak diputar
  final double lastPourAmount;

  bool get built => tier > 0;
  double get cap => Wh.cap(tier);
  double get fill => cap <= 0 ? 0 : (stored / cap).clamp(0.0, 1.0).toDouble();
}