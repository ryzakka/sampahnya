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

String modeLabel(String? mode) => switch (mode) {
  'coop' => 'Co-op Survival',
  'team2v2' => 'Team 2v2',
  'survival' => 'Kesintasan',
  _ => 'Versus',
};

String modeEmoji(String? mode) => switch (mode) {
  'coop' => '🤝',
  'team2v2' => '👥',
  'survival' => '🏚️',
  _ => '⚔️',
};

String modeDesc(String? mode) => switch (mode) {
  'coop' =>
  '2–4 pemain satu tim melawan tekanan sampah. Saling bantu, bertahan '
      'selama mungkin.',
  'team2v2' =>
  '4 pemain, 2 lawan 2. Timbun kedua kost lawan sebelum timmu tertimbun.',
  _ => '2–4 pemain saling serang. Yang terakhir bertahan menang.',
};