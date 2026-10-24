import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ====================================================================
//  PAPAN SKOR KESINTASAN
//  Membaca RPC `survival_leaderboard` (lihat survival_mode.sql).
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

class _SurvivalLeaderboardScreenState extends State<SurvivalLeaderboardScreen> {
  static const _amber = Color(0xFFFFCA28);
  static const _bg = Color(0xFF0F1D16);
  static const _card = Color(0xFF16281F);

  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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

  Color _medal(int i) => switch (i) {
    0 => const Color(0xFFFFCA28),
    1 => const Color(0xFFCFD8DC),
    2 => const Color(0xFFD7894B),
    _ => Colors.white24,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        title: const Text('PAPAN SKOR KESINTASAN',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _amber))
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent)),
        ),
      )
          : _rows.isEmpty
          ? const Center(
          child: Text('Belum ada skor. Jadilah yang pertama!',
              style: TextStyle(color: Colors.white70)))
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final r = _rows[i];
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _medal(i).withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text('${i + 1}',
                      style: TextStyle(
                          color: _medal(i),
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r['player_name']}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                      Text(
                        '${r['rooms_count']} kamar · '
                            'Bank Sampah Lv ${r['waste_level']}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatSurvivalTime(r['seconds'] as num),
                  style: const TextStyle(
                      color: _amber,
                      fontSize: 20,
                      fontWeight: FontWeight.w900),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}