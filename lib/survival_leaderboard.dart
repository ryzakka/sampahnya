import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'game_icons.dart';

// ====================================================================
//  PAPAN SKOR KESINTASAN
//  Podium 3 besar + daftar peringkat 4..10. Membaca RPC
//  `survival_leaderboard` (kolom: player_name, seconds, rooms_count,
//  waste_level).
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
  static const _green = Color(0xFF81C784);
  static const _maxWidth = 560.0;

  static const _gold = Color(0xFFFFCA28);
  static const _silver = Color(0xFFCFD8DC);
  static const _bronze = Color(0xFFD7894B);

  late final AnimationController _pulse; // denyut placeholder saat memuat

  List<Map<String, dynamic>> _rows = const [];
  String _board = 'solo'; // 'solo' | 'coop'
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
      final res = await Supabase.instance.client.rpc(
          _board == 'coop' ? 'coop_leaderboard' : 'survival_leaderboard',
          params: {'p_limit': 10});
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

  Color _rankColor(int i) => switch (i) {
    0 => _gold,
    1 => _silver,
    2 => _bronze,
    _ => Colors.white54,
  };

  double _sec(Map<String, dynamic> r) => (r['seconds'] as num).toDouble();

  /// Solo: nama pemain. Co-op: nama anggota tim digabung.
  String _title(Map<String, dynamic> r) =>
      '${_board == 'coop' ? r['team_names'] : r['player_name']}';

  Object? _rooms(Map<String, dynamic> r) =>
      _board == 'coop' ? r['total_rooms'] : r['rooms_count'];

  /// Statistik kedua: Solo = Bank Sampah, Co-op = ukuran tim.
  Widget _stat2(Map<String, dynamic> r, {double icon = 20}) =>
      _board == 'coop'
          ? _stat(GIcon.player, '${r['team_size']} pemain', icon: icon)
          : _stat(GIcon.bin1, 'Bank Lv ${r['waste_level']}', icon: icon);

  Widget _boardSwitch() {
    Widget chip(String id, String label) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: SizedBox(
            width: double.infinity,
            child: Text(label, textAlign: TextAlign.center),
          ),
          selected: _board == id,
          selectedColor: _amber,
          backgroundColor: _surface,
          labelStyle: TextStyle(
            color: _board == id ? Colors.black87 : Colors.white70,
            fontWeight: FontWeight.w800,
          ),
          onSelected: _loading
              ? null
              : (_) {
            if (_board == id) return;
            setState(() => _board = id);
            _load();
          },
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(children: [chip('solo', 'Solo'), chip('coop', 'Co-op')]),
    );
  }

  static const _tabular = [FontFeature.tabularFigures()];

  /// Muncul pelan dari bawah; [index] menunda sedikit agar berurutan.
  Widget _enter(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: c),
      ),
      child: child,
    );
  }

  /// Ikon + keterangan pendek ("3 kamar", "Bank Lv 2").
  Widget _stat(String asset, String text, {double icon = 20}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameIcon(asset, size: icon),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // cahaya hangat di atas, supaya podium terasa "disorot"
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.85),
                    radius: 1.0,
                    colors: [
                      _amber.withValues(alpha: 0.13),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: Column(
                  children: [
                    _topBar(),
                    _boardSwitch(),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _body(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          GameIconButton(
            asset: GIcon.back,
            tip: 'Kembali',
            size: 42,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          const GameIcon(GIcon.leaderboard, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _board == 'coop' ? 'MODE CO-OP' : 'MODE KESINTASAN',
                  style: const TextStyle(
                    color: _green,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                Text(
                  'Papan Skor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
    return RefreshIndicator(
      color: _amber,
      backgroundColor: _surface,
      onRefresh: _load,
      child: ListView(
        key: const ValueKey('content'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          _podium(),
          if (_rows.length > 3) ...[
            const SizedBox(height: 20),
            for (var i = 3; i < _rows.length; i++) ...[
              _enter(i, _rankCard(i)),
              if (i != _rows.length - 1) const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  /// Podium: juara 2 – juara 1 (tengah, lebih besar) – juara 3.
  Widget _podium() {
    final order = [1, 0, 2].where((i) => i < _rows.length).toList();
    if (order.length == 1) {
      return Center(
        child: SizedBox(width: 230, child: _enter(0, _podiumCard(0))),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var k = 0; k < order.length; k++) ...[
          if (k > 0) const SizedBox(width: 10),
          Expanded(
            flex: order[k] == 0 ? 11 : 10,
            child: _enter(order[k], _podiumCard(order[k])),
          ),
        ],
      ],
    );
  }

  Widget _podiumCard(int i) {
    final r = _rows[i];
    final color = _rankColor(i);
    final first = i == 0;
    return Container(
      padding: EdgeInsets.fromLTRB(8, first ? 12 : 10, 8, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.24), _surface],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.75),
          width: first ? 2.5 : 1.5,
        ),
        boxShadow: first
            ? [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 20)]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon(first ? GIcon.crown2 : GIcon.crown, size: first ? 54 : 42),
          const SizedBox(height: 4),
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              '${i + 1}',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _title(r),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: first ? 15 : 13.5,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(GIcon.timer, size: first ? 22 : 18),
              const SizedBox(width: 4),
              Text(
                formatSurvivalTime(_sec(r)),
                style: TextStyle(
                  color: color,
                  fontSize: first ? 21 : 17,
                  fontWeight: FontWeight.w900,
                  fontFeatures: _tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 2,
            children: [
              _stat(GIcon.addRoom, '${_rooms(r)} kamar', icon: 18),
              _stat2(r, icon: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rankCard(int i) {
    final r = _rows[i];
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 14, 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              '${i + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(r),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    _stat(GIcon.addRoom, '${_rooms(r)} kamar'),
                    _stat2(r),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const GameIcon(GIcon.timer, size: 22),
          const SizedBox(width: 4),
          Text(
            formatSurvivalTime(_sec(r)),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFeatures: _tabular,
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
        Widget box(double h, {double? w}) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: a),
            borderRadius: BorderRadius.circular(18),
          ),
        );
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: box(170)),
                const SizedBox(width: 10),
                Expanded(flex: 11, child: box(200)),
                const SizedBox(width: 10),
                Expanded(child: box(160)),
              ],
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < 4; i++) ...[
              box(64),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  Widget _stateCard({
    required String asset,
    required String title,
    required String message,
    required Widget action,
    Key? key,
  }) {
    return Center(
      key: key,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameIcon(asset, size: 120),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 22),
            action,
          ],
        ),
      ),
    );
  }

  Widget _emptyState() => _stateCard(
    key: const ValueKey('empty'),
    asset: GIcon.waiting,
    title: 'Belum ada skor',
    message: _board == 'coop'
        ? 'Main Co-op bersama temanmu dan jadilah tim pertama\n'
        'tercatat di papan skor!'
        : 'Main mode Kesintasan dan jadilah yang pertama\n'
        'tercatat di papan skor!',
    action: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameIconButton(
          asset: GIcon.play,
          tip: 'Main sekarang',
          size: 68,
          ring: _amber,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(height: 6),
        const Text(
          'Main',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _errorState() => _stateCard(
    key: const ValueKey('error'),
    asset: GIcon.alert,
    title: 'Gagal memuat papan skor',
    message: _error ?? 'Terjadi kesalahan.',
    action: FilledButton.tonalIcon(
      onPressed: _load,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Coba lagi',
          style: TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}