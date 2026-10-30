import 'package:flutter/material.dart';

// ====================================================================
//  Pembantu mode tim (Co-op Survival & Team 2v2).
//  Dipakai main.dart (lobi) dan game_screen.dart.
// ====================================================================

const List<Color> kTeamColors = [Color(0xFF42A5F5), Color(0xFFEF5350)];
const List<String> kTeamNames = ['Biru', 'Merah'];
const List<String> kTeamEmoji = ['🔵', '🔴'];

bool _validTeam(int? t) => t == 1 || t == 2;

Color? teamColor(int? t) => _validTeam(t) ? kTeamColors[t! - 1] : null;
String teamName(int? t) => _validTeam(t) ? kTeamNames[t! - 1] : '-';
String teamEmoji(int? t) => _validTeam(t) ? kTeamEmoji[t! - 1] : '';

bool isTeamMode(String? mode) => mode == 'coop' || mode == 'team2v2';

/// Lama pertandingan Main Cepat (detik). Samakan dengan _check_mode_end (SQL).
const int kBlitzSeconds = 300;

/// Mode varian berbasis versus (2-4 pemain, tanpa tim).
const List<String> kVariantModes = [
  'juragan', 'blitz', 'noburn', 'nohaul', 'nobh',
];

bool isVariantMode(String? m) => kVariantModes.contains(m);

/// Bakar sampah dilarang (Dilarang Membakar / Tanpa Bakar & Tanpa Truk).
bool burnBanned(String? m) => m == 'noburn' || m == 'nobh';

/// Truk sampah biasa dilarang (Tukang Sampah Dipecat / Tanpa Bakar & Tanpa Truk).
bool haulBanned(String? m) => m == 'nohaul' || m == 'nobh';

String modeLabel(String? mode) => switch (mode) {
  'coop' => 'Co-op Survival',
  'team2v2' => 'Team 2v2',
  'survival' => 'Kesintasan',
  'juragan' => 'Juragan Pertama',
  'blitz' => 'Main Cepat',
  'noburn' => 'Dilarang Membakar',
  'nohaul' => 'Tukang Sampah Dipecat',
  'nobh' => 'Tanpa Bakar & Tanpa Truk',
  _ => 'Versus',
};

String modeEmoji(String? mode) => switch (mode) {
  'coop' => '🤝',
  'team2v2' => '👥',
  'survival' => '🏚️',
  'juragan' => '👑',
  'blitz' => '⚡',
  'noburn' => '🚭',
  'nohaul' => '🚛',
  'nobh' => '🚫',
  _ => '⚔️',
};

String modeDesc(String? mode) => switch (mode) {
  'coop' =>
  '2–4 pemain satu tim melawan tekanan sampah. Saling bantu, bertahan '
      'selama mungkin.',
  'team2v2' =>
  '4 pemain, 2 lawan 2. Timbun kedua kost lawan sebelum timmu tertimbun.',
  'juragan' =>
  '2–4 pemain berlomba. Yang pertama punya 12 kamar dan Kost Sultan menang.',
  'blitz' =>
  '5 menit, sampah menghimpit, krisis beruntun. Saat waktu habis, kost '
      'paling bersih menang.',
  'noburn' =>
  '2–4 pemain. Membakar sampah dilarang, andalkan Bank Sampah dan gudang.',
  'nohaul' =>
  '2–4 pemain. Tukang sampah dipecat, hanya truk gudang milik sendiri.',
  'nobh' =>
  '2–4 pemain. Tanpa bakar, tanpa truk sampah. Kelola sampah dengan '
      'Bank Sampah dan gudang.',
  _ => '2–4 pemain saling serang. Yang terakhir bertahan menang.',
};