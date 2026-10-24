import 'dart:ui';

// ====================================================================
//  HEWAN PELIHARAAN (maks 2 slot)
//
//  Katalog & angka di file ini HARUS sama dengan pets.sql
//  (server yang menentukan; klien hanya menampilkan perkiraan).
// ====================================================================

enum PetSpecies { cat, hen, dog }

extension PetSpeciesX on PetSpecies {
  String get label => switch (this) {
    PetSpecies.cat => 'Kucing',
    PetSpecies.hen => 'Ayam',
    PetSpecies.dog => 'Anjing',
  };
  String get emoji => switch (this) {
    PetSpecies.cat => '🐈',
    PetSpecies.hen => '🐔',
    PetSpecies.dog => '🐕',
  };
  String get perkText => switch (this) {
    PetSpecies.cat => 'Menjaga tikus: laju sampah dasar turun.',
    PetSpecies.hen => 'Telur harian: income naik.',
    PetSpecies.dog => 'Penjaga: sampah lemparan yang masuk berkurang.',
  };
}

const List<String> kRarityNames = ['Biasa', 'Langka', 'Legendaris'];

class PetDef {
  const PetDef({
    required this.key,
    required this.species,
    required this.variant,
    required this.rarity,
    required this.price,
    required this.body,
    required this.accent,
    required this.eye,
    this.incBonus = 0,
    this.trReduction = 0,
    this.defBonus = 0,
  });

  final String key; // sama dengan pet_catalog.key
  final PetSpecies species;
  final String variant;
  final int rarity; // 0..2
  final int price;

  /// Palet untuk painter: badan, belang/aksen, mata.
  final Color body;
  final Color accent;
  final Color eye;

  final double incBonus; // +income (0.04 = +4%)
  final double trReduction; // -laju sampah dasar
  final double defBonus; // tambahan pengurang sampah masuk

  String get name => '${species.label} $variant';
  String get rarityName => kRarityNames[rarity];
  int get refund => (price * 0.5).floor();

  /// Teks efek untuk kartu di UI.
  String get perkLine {
    String pct(double v) => '${(v * 100).round()}%';
    if (incBonus > 0) return 'Income +${pct(incBonus)}';
    if (trReduction > 0) return 'Laju sampah -${pct(trReduction)}';
    return 'Sampah masuk -${pct(defBonus)}';
  }
}

abstract final class Pets {
  static const int maxSlots = 2;

  static const List<PetDef> all = [
    PetDef(key: 'cat_orange', species: PetSpecies.cat, variant: 'Oren',
        rarity: 0, price: 180, trReduction: 0.05,
        body: Color(0xFFE8964A), accent: Color(0xFFC46A22), eye: Color(0xFF2E7D32)),
    PetDef(key: 'cat_black', species: PetSpecies.cat, variant: 'Hitam',
        rarity: 1, price: 380, trReduction: 0.08,
        body: Color(0xFF2B2B33), accent: Color(0xFF45454F), eye: Color(0xFFFFD54F)),
    PetDef(key: 'cat_gold', species: PetSpecies.cat, variant: 'Albino Emas',
        rarity: 2, price: 700, trReduction: 0.12,
        body: Color(0xFFF6E7B4), accent: Color(0xFFE0B84C), eye: Color(0xFFE57373)),

    PetDef(key: 'hen_brown', species: PetSpecies.hen, variant: 'Cokelat',
        rarity: 0, price: 180, incBonus: 0.04,
        body: Color(0xFF9C6B3F), accent: Color(0xFFD84315), eye: Color(0xFF111111)),
    PetDef(key: 'hen_white', species: PetSpecies.hen, variant: 'Putih',
        rarity: 1, price: 380, incBonus: 0.07,
        body: Color(0xFFF5F5F0), accent: Color(0xFFE53935), eye: Color(0xFF111111)),
    PetDef(key: 'hen_gold', species: PetSpecies.hen, variant: 'Emas',
        rarity: 2, price: 700, incBonus: 0.10,
        body: Color(0xFFFFC83D), accent: Color(0xFFFF7043), eye: Color(0xFF111111)),

    PetDef(key: 'dog_brown', species: PetSpecies.dog, variant: 'Cokelat',
        rarity: 0, price: 180, defBonus: 0.05,
        body: Color(0xFFA9794C), accent: Color(0xFF7A5230), eye: Color(0xFF111111)),
    PetDef(key: 'dog_dalmatian', species: PetSpecies.dog, variant: 'Belang',
        rarity: 1, price: 380, defBonus: 0.08,
        body: Color(0xFFF2F2F2), accent: Color(0xFF222222), eye: Color(0xFF111111)),
    PetDef(key: 'dog_husky', species: PetSpecies.dog, variant: 'Husky',
        rarity: 2, price: 700, defBonus: 0.12,
        body: Color(0xFF8FA3B5), accent: Color(0xFFF4F7FA), eye: Color(0xFF4FC3F7)),
  ];

  static final Map<String, PetDef> _byKey = {
    for (final p in all) p.key: p,
  };

  static PetDef? byKey(String? key) => key == null ? null : _byKey[key];

  static List<PetDef> ofSpecies(PetSpecies s) =>
      all.where((p) => p.species == s).toList(growable: false);
}

/// Satu slot terisi (baris `player_pets`).
class PetSlot {
  const PetSlot({required this.slot, required this.def, this.nickname});

  final int slot; // 1 atau 2
  final PetDef def;
  final String? nickname;

  String get displayName =>
      (nickname == null || nickname!.isEmpty) ? def.species.label : nickname!;

  static PetSlot? fromRow(Map<String, dynamic> row) {
    final def = Pets.byKey(row['pet_key'] as String?);
    if (def == null) return null; // katalog klien lebih tua dari server
    return PetSlot(
      slot: (row['slot'] as num).toInt(),
      def: def,
      nickname: row['nickname'] as String?,
    );
  }
}

/// Hewan milik satu pemain + perkiraan perk (cermin pet_mults/pet_defense).
class PetLoadout {
  const PetLoadout(this.slots);

  static const PetLoadout empty = PetLoadout([]);

  final List<PetSlot> slots;

  factory PetLoadout.fromRows(Iterable<Map<String, dynamic>> rows) {
    final list = <PetSlot>[];
    for (final r in rows) {
      final s = PetSlot.fromRow(r);
      if (s != null) list.add(s);
    }
    list.sort((a, b) => a.slot.compareTo(b.slot));
    return PetLoadout(list);
  }

  PetSlot? inSlot(int slot) {
    for (final s in slots) {
      if (s.slot == slot) return s;
    }
    return null;
  }

  double get incomeMul =>
      1 + slots.fold(0.0, (a, s) => a + s.def.incBonus);

  double get trashMul {
    final v = 1 - slots.fold(0.0, (a, s) => a + s.def.trReduction);
    return v < 0.5 ? 0.5 : v.toDouble();
  }

  double get defense {
    final v = slots.fold(0.0, (a, s) => a + s.def.defBonus);
    return v > 0.15 ? 0.15 : v.toDouble();
  }

  /// Cek sisi klien sebelum memanggil `buy_pet` (server tetap yang memutuskan).
  /// Mengembalikan pesan galat, atau null bila boleh.
  String? whyCannotBuy(PetDef def, int slot, double money,
      {double priceMul = 1.0}) {
    if (slot < 1 || slot > Pets.maxSlots) return 'Slot tidak valid.';
    final cur = inSlot(slot);
    if (cur?.def.key == def.key) return 'Sudah ada di slot ini.';
    for (final s in slots) {
      if (s.slot != slot && s.def.species == def.species) {
        return 'Spesies yang sama tidak boleh di dua slot.';
      }
    }
    final net = (def.price * priceMul).floor() - (cur?.def.refund ?? 0);
    if (money < net) return 'Uang belum cukup.';
    return null;
  }
}

// Contoh pemanggilan (supabase_flutter):
//   await supabase.rpc('buy_pet',
//       params: {'p_room': roomId, 'p_pet_key': 'cat_orange', 'p_slot': 1});
//   await supabase.rpc('release_pet', params: {'p_room': roomId, 'p_slot': 2});
//   await supabase.rpc('rename_pet',
//       params: {'p_room': roomId, 'p_slot': 1, 'p_name': 'Mochi'});
//   // baca:  supabase.from('player_pets').stream(primaryKey: [...])
//   //        .eq('room_id', roomId)