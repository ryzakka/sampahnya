import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ====================================================================
//  PAPAN SKOR KESINTASAN (desain ulang)
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
    with TickerProviderStateMixin {
  static const _amber = Color(0xFFFFCA28);
  static const _bg = Color(0xFF0A140F);
  static const _surface = Color(0xFF12221A);
  static const _green = Color(0xFF81C784);
  static const _maxWidth = 520.0;

  static const _gold = Color(0xFFFFCA28);
  static const _silver = Color(0xFFCFD8DC);
  static const _bronze = Color(0xFFD7894B);

  late final AnimationController _enter;
  late final AnimationController _pulse;

  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _enter.dispose();
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
      _enter.forward(from: 0);
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

  Color _medal(int i) => switch (i) {
    0 => _gold,
    1 => _silver,
    2 => _bronze,
    _ => Colors.white38,
  };

  double _sec(Map<String, dynamic> r) => (r['seconds'] as num).toDouble();

  String _initial(Object? name) {
    final s = '${name ?? ''}'.trim();
    return s.isEmpty ? '?' : String.fromCharCode(s.runes.first).toUpperCase();
  }

  /// Muncul bertahap: geser naik + memudar masuk, urutan ke-[i].
  Widget _stag(int i, Widget child) {
    final start = math.min(0.6, i * 0.07);
    final end = math.min(1.0, start + 0.4);
    final anim = CurvedAnimation(
      parent: _enter,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
            .animate(anim),
        child: child,
      ),
    );
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // latar: cahaya emas lembut di atas
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -1.1),
                  radius: 1.1,
                  colors: [
                    _amber.withValues(alpha: 0.16),
                    _bg,
                  ],
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
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
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
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Kembali',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MODE KESINTASAN',
                  style: TextStyle(
                    color: _green,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                Text(
                  'Papan Skor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Segarkan',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
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

  // ------------------------------------------------------------ konten

  Widget _content() {
    final best = _sec(_rows.first);
    final rest = _rows.length > 3 ? _rows.sublist(3) : const [];

    return RefreshIndicator(
      color: _amber,
      backgroundColor: _surface,
      onRefresh: _load,
      child: ListView(
        key: const ValueKey('content'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _stag(0, _recordBanner(best)),
          const SizedBox(height: 18),
          _stag(1, _podium()),
          if (rest.isNotEmpty) ...[
            const SizedBox(height: 22),
            _stag(
              2,
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  'PERINGKAT LAINNYA',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
            for (var i = 0; i < rest.length; i++)
              _stag(
                3 + i,
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _rankTile(rest[i], i + 3, best),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _recordBanner(double best) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            _amber.withValues(alpha: 0.22),
            _amber.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: _amber.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _amber.withValues(alpha: 0.2),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: _amber, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rekor bertahan',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  formatSurvivalTime(best),
                  style: const TextStyle(
                    color: _amber,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_rows.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'pemain',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ podium

  Widget _podium() {
    // urutan tampil: juara 2, juara 1, juara 3
    const order = [1, 0, 2];
    const heights = [96.0, 128.0, 74.0];
    return SizedBox(
      height: 270,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var c = 0; c < 3; c++)
            Expanded(
              child: order[c] < _rows.length
                  ? _podiumColumn(_rows[order[c]], order[c], heights[c])
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  Widget _podiumColumn(Map<String, dynamic> r, int rank, double height) {
    final color = _medal(rank);
    final first = rank == 0;
    final avatar = first ? 62.0 : 52.0;

    final grow = CurvedAnimation(
      parent: _enter,
      curve: Interval(0.15 + rank * 0.1, 0.75 + rank * 0.1,
          curve: Curves.easeOutBack),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (first)
            const Icon(Icons.workspace_premium_rounded,
                color: _gold, size: 30)
          else
            const SizedBox(height: 30),
          const SizedBox(height: 4),
          Container(
            width: avatar,
            height: avatar,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
              border: Border.all(color: color, width: first ? 3 : 2.2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: first ? 0.5 : 0.25),
                  blurRadius: first ? 22 : 12,
                ),
              ],
            ),
            child: Text(
              _initial(r['player_name']),
              style: TextStyle(
                color: color,
                fontSize: first ? 26 : 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${r['player_name']}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatSurvivalTime(_sec(r)),
            style: TextStyle(
              color: color,
              fontSize: first ? 20 : 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '${r['rooms_count']} kamar · Lv ${r['waste_level']}',
            style: const TextStyle(color: Colors.white54, fontSize: 10.5),
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: grow,
            builder: (context, _) {
              final v = grow.value.clamp(0.0, 1.2).toDouble();
              return Container(
                height: height * v,
                width: double.infinity,
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 10),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.5),
                      color.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(color: color.withValues(alpha: 0.6)),
                ),
                child: Text(
                  '${rank + 1}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: first ? 34 : 28,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ daftar

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white60),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _rankTile(Map<String, dynamic> r, int index, double best) {
    final ratio = best <= 0 ? 0.0 : (_sec(r) / best).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _chip(Icons.meeting_room_rounded,
                            '${r['rooms_count']} kamar'),
                        _chip(Icons.recycling_rounded,
                            'Bank Sampah Lv ${r['waste_level']}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatSurvivalTime(_sec(r)),
                style: const TextStyle(
                  color: _amber,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              color: _amber.withValues(alpha: 0.75),
              backgroundColor: Colors.white.withValues(alpha: 0.07),
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
        Widget box(double h, {double? w, double r = 18}) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: a),
            borderRadius: BorderRadius.circular(r),
          ),
        );
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            box(76, r: 20),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: box(170, r: 14)),
                const SizedBox(width: 8),
                Expanded(child: box(210, r: 14)),
                const SizedBox(width: 8),
                Expanded(child: box(140, r: 14)),
              ],
            ),
            const SizedBox(height: 22),
            for (var i = 0; i < 4; i++) ...[
              box(68),
              const SizedBox(height: 8),
            ],
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
    Key? key,
  }) {
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.14),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 13, height: 1.4),
            ),
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
    color: _amber,
    title: 'Belum ada skor',
    message: 'Main mode Kesintasan dan jadilah yang pertama\n'
        'tercatat di papan skor!',
    action: FilledButton.icon(
      onPressed: () => Navigator.of(context).maybePop(),
      style: FilledButton.styleFrom(
        backgroundColor: _amber,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.play_arrow_rounded),
      label: const Text('Main sekarang',
          style: TextStyle(fontWeight: FontWeight.w900)),
    ),
  );

  Widget _errorState() => _stateCard(
    key: const ValueKey('error'),
    icon: Icons.cloud_off_rounded,
    color: Colors.redAccent,
    title: 'Gagal memuat papan skor',
    message: _error ?? 'Terjadi kesalahan.',
    action: OutlinedButton.icon(
      onPressed: _load,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Coba lagi',
          style: TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}