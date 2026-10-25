import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'game_icons.dart';

// ====================================================================
//  PAPAN SKOR KESINTASAN
//  Daftar sederhana: peringkat, pemain, waktu bertahan.
//  Membaca RPC `survival_leaderboard`.
//  Buka dari beranda:
//    Navigator.of(context).push(
//      MaterialPageRoute(builder: (_) => const SurvivalLeaderboardScreen()));
// ====================================================================

String formatSurvivalTime(num sec) {
  final s = sec.floor();
  return '${(s ~/ 60).toString().padLeft(2, '0')}:'
      '${(s % 60).toString().padLeft(2, '0')}';
}

class SurvivalLeaderboardScreen extends StatefulWidget {
  const SurvivalLeaderboardScreen({super.key});

  @override
  State<SurvivalLeaderboardScreen> createState() =>
      _SurvivalLeaderboardScreenState();
}

class _SurvivalLeaderboardScreenState extends State<SurvivalLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  static const _amber = Color(0xFFFFCA28);
  static const _bg = Color(0xFF0A140F);
  static const _surface = Color(0xFF12221A);
  static const _maxWidth = 520.0;

  static const _gold = Color(0xFFFFCA28);
  static const _silver = Color(0xFFCFD8DC);
  static const _bronze = Color(0xFFD7894B);

  late final AnimationController _pulse; // denyut placeholder saat memuat

  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client
          .rpc('survival_leaderboard', params: {'p_limit': 10});
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(
            (res as List).map((e) => Map<String, dynamic>.from(e as Map)));
        _loading = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  // ------------------------------------------------------------ util

  /// Warna angka peringkat: emas, perak, perunggu, lalu abu-abu.
  Color _rankColor(int i) => switch (i) {
    0 => _gold,
    1 => _silver,
    2 => _bronze,
    _ => Colors.white54,
  };

  double _sec(Map<String, dynamic> r) => (r['seconds'] as num).toDouble();

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _body(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          GameIconButton(
            asset: GIcon.back,
            tip: 'Kembali',
            size: 42,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GameIcon(GIcon.survival, size: 38),
                  SizedBox(width: 10),
                  GameIcon(GIcon.leaderboard, size: 38),
                ],
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Segarkan',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              foregroundColor: Colors.white,
              fixedSize: const Size(42, 42),
            ),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return _skeleton();
    if (_error != null) return _errorState();
    if (_rows.isEmpty) return _emptyState();
    return _content();
  }

  // ------------------------------------------------------------ daftar

  Widget _content() {
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.08),
    );
    return RefreshIndicator(
      color: _amber,
      backgroundColor: _surface,
      onRefresh: _load,
      child: ListView(
        key: const ValueKey('content'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _headerRow(),
          divider,
          for (var i = 0; i < _rows.length; i++) ...[
            _row(_rows[i], i),
            if (i != _rows.length - 1) divider,
          ],
        ],
      ),
    );
  }

  Widget _headerRow() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Align(
              alignment: Alignment.centerLeft,
              child: GameIcon(GIcon.tier, size: 24),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: GameIcon(GIcon.player, size: 24),
            ),
          ),
          GameIcon(GIcon.timer, size: 24),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> r, int index) {
    final top = index < 3;
    final color = _rankColor(index);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: color,
                fontSize: top ? 18 : 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r['player_name']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const GameIcon(GIcon.addRoom, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${r['rooms_count']}',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 14),
                    const GameIcon(GIcon.bin1, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      'Lv ${r['waste_level']}',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatSurvivalTime(_sec(r)),
            style: TextStyle(
              color: top ? color : Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ status

  Widget _skeleton() {
    return AnimatedBuilder(
      key: const ValueKey('skeleton'),
      animation: _pulse,
      builder: (context, _) {
        final a = 0.05 + 0.07 * _pulse.value;
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          children: [
            for (var i = 0; i < 6; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: a),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _stateCard({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    Widget? action,
    String? asset,
    Key? key,
  }) {
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            asset != null
                ? GameIcon(asset, size: 110)
                : Icon(icon, size: 44, color: color),
            if (title.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            if (message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 13, height: 1.4),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyState() => _stateCard(
    key: const ValueKey('empty'),
    icon: Icons.emoji_events_outlined,
    asset: GIcon.waiting,
    color: _amber,
    title: '',
    message: '',
    action: GameIconButton(
      asset: GIcon.play,
      tip: 'Main sekarang',
      size: 64,
      ring: _amber,
      onTap: () => Navigator.of(context).maybePop(),
    ),
  );

  Widget _errorState() => _stateCard(
    key: const ValueKey('error'),
    icon: Icons.cloud_off_rounded,
    asset: GIcon.alert,
    color: Colors.redAccent,
    title: '',
    message: _error ?? 'Terjadi kesalahan.',
    action: IconButton.filledTonal(
      tooltip: 'Coba lagi',
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        foregroundColor: Colors.white,
        fixedSize: const Size(56, 56),
      ),
      onPressed: _load,
      icon: const Icon(Icons.refresh_rounded, size: 28),
    ),
  );
}