import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'game_screen.dart';
import 'kost_scene.dart';

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://tbkoiuydiqvfedjiqlih.supabase.co',
);
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRia29pdXlkaXF2ZmVkamlxbGloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2NTQ1MTgsImV4cCI6MjEwODIzMDUxOH0.JC_xoqEn2YMQnayqbxMtSMPjzdtxsJ7dc0nMj4SwVJQ',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (supabaseAnonKey.isEmpty) {
    runApp(const MissingKeyApp());
    return;
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const SampahnyaApp());
}

class MissingKeyApp extends StatelessWidget {
  const MissingKeyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'SUPABASE_ANON_KEY belum disetel.\n'
                  'Jalankan Flutter dengan --dart-define=SUPABASE_ANON_KEY=…',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class SampahnyaApp extends StatelessWidget {
  const SampahnyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sampahnya',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
      ),
      home: const LobbyHome(),
    );
  }
}

// ====================================================================
//  LAYAR MASUK / BERANDA
// ====================================================================

class LobbyHome extends StatefulWidget {
  const LobbyHome({super.key});

  @override
  State<LobbyHome> createState() => _LobbyHomeState();
}

class _LobbyHomeState extends State<LobbyHome>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _error;
  int _tab = 0; // 0 = Buat Ruangan, 1 = Gabung Ruangan

  SupabaseClient get _db => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _ensureAnonymousSession();
  }

  Future<void> _ensureAnonymousSession() async {
    try {
      if (_db.auth.currentUser == null) {
        await _db.auth.signInAnonymously();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal membuat sesi: $e');
    }
  }

  String _makeRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _createRoom() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Masukkan nama pemain kost terlebih dahulu!');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _ensureAnonymousSession();
      final user = _db.auth.currentUser;
      if (user == null) throw Exception('Sesi anonim belum tersedia.');

      Map<String, dynamic>? room;
      for (var attempt = 0; attempt < 4; attempt++) {
        final code = _makeRoomCode();
        try {
          room = await _db
              .from('rooms')
              .insert({
            'code': code,
            'status': 'waiting',
            'host_id': user.id,
            'max_players': 4,
          })
              .select('id, code')
              .single();
          break;
        } on PostgrestException catch (e) {
          if (e.code != '23505') rethrow;
        }
      }
      if (room == null) throw Exception('Tidak berhasil membuat kode ruangan.');

      await _db.from('room_players').insert({
        'room_id': room['id'],
        'player_id': user.id,
        'player_name': name,
        'is_ready': false,
      });

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RoomLobby(
            roomId: room!['id'].toString(),
            roomCode: room['code'].toString(),
            playerName: name,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinRoom() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    if (name.isEmpty || code.isEmpty) {
      setState(() => _error = 'Isi nama pemain dan 6 digit kode ruangan!');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _ensureAnonymousSession();
      final user = _db.auth.currentUser;
      if (user == null) throw Exception('Sesi anonim belum tersedia.');

      final result = await _db.rpc(
        'join_room_by_code',
        params: {'p_code': code, 'p_name': name},
      );

      final roomId = _extractRoomId(result);
      if (roomId == null) {
        throw Exception(
          'Fungsi join_room_by_code tidak mengembalikan UUID ruangan.',
        );
      }

      final room = await _db
          .from('rooms')
          .select('id, code')
          .eq('id', roomId)
          .single();

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RoomLobby(
            roomId: room['id'].toString(),
            roomCode: room['code'].toString(),
            playerName: name,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _extractRoomId(dynamic result) {
    if (result is String) return result;
    if (result is Map) {
      final value = result['room_id'] ?? result['id'];
      return value?.toString();
    }
    if (result is List && result.isNotEmpty) {
      return _extractRoomId(result.first);
    }
    return null;
  }

  String _friendlyError(Object e) {
    if (e is PostgrestException) return e.message;
    if (e is AuthException) return e.message;
    return e.toString().replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Latar belakang animasi kost langsung hidup di belakang layar login
          const Positioned.fill(
            child: KostBackdrop(
              rooms: 10,
              defense: 2,
              pollution: 12,
              trashRatio: 0.15,
            ),
          ),
          // Vignette gelap agar panel kaca terlihat kontras dan dramatis
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.1,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    const Color(0xFF0A140F).withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo / Judul Game Bergaya Arkade
                      _buildHeroBadge(),
                      const SizedBox(height: 24),
                      // Panel Glassmorphism Utama
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.all(26),
                            decoration: BoxDecoration(
                              color: const Color(0xFF12221A)
                                  .withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  blurRadius: 30,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Nama Pemain',
                                  style: TextStyle(
                                    color: Color(0xFF81C784),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _nameController,
                                  maxLength: 18,
                                  textCapitalization: TextCapitalization.words,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Mama Kos',
                                    hintStyle: TextStyle(
                                      color:
                                      Colors.white.withValues(alpha: 0.35),
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.badge_outlined,
                                      color: Color(0xFFFFCA28),
                                    ),
                                    counterText: '',
                                    filled: true,
                                    fillColor:
                                    Colors.black.withValues(alpha: 0.28),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFFFCA28),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Pemilih Mode (Buat vs Gabung)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _modeTab(
                                          index: 0,
                                          icon: Icons.add_business_rounded,
                                          label: 'Buat Host',
                                        ),
                                      ),
                                      Expanded(
                                        child: _modeTab(
                                          index: 1,
                                          icon: Icons.meeting_room_rounded,
                                          label: 'Bergabung',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  child: _tab == 0
                                      ? _buildCreateSection()
                                      : _buildJoinSection(),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD32F2F)
                                          .withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFEF5350)
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          color: Color(0xFFFF8A80),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: const TextStyle(
                                              color: Color(0xFFFFCDD2),
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBadge() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFCA28),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFCA28).withValues(alpha: 0.4),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.black87),
              SizedBox(width: 6),
              Text(
                'v1.4.5 (2210:6)',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'SAMPAHNYA!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            height: 1.05,
            shadows: [
              Shadow(
                color: Colors.black87,
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Bangun kamar, kelola limbah, atau timbun kost tetangga!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
          ),
        ),
      ],
    );
  }

  Widget _modeTab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() {
        _tab = index;
        _error = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2E7D32) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : Colors.white60,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white60,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF81C784), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Buat ruangan baru untuk 2–4 pemain dan bagikan kode uniknya ke teman-temanmu.',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFCA28),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            onPressed: _busy ? null : _createRoom,
            icon: _busy
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.black87,
              ),
            )
                : const Icon(Icons.rocket_launch_rounded),
            label: Text(_busy ? 'MEMBUKA LAHAN…' : 'BUAT RUANGAN BARU'),
          ),
        ),
      ],
    );
  }

  Widget _buildJoinSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _codeController,
          maxLength: 6,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
          ],
          style: const TextStyle(
            color: Color(0xFFFFCA28),
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            hintText: 'KODE 6 DIGIT',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 15,
              letterSpacing: 3,
            ),
            counterText: '',
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.35),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF4CAF50),
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF43A047),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            onPressed: _busy ? null : _joinRoom,
            icon: _busy
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.login_rounded),
            label: Text(_busy ? 'MENYAMBUNGKAN…' : 'GABUNG SEKARANG'),
          ),
        ),
      ],
    );
  }
}

// ====================================================================
//  LAYAR LOBI RUANGAN
// ====================================================================

class RoomLobby extends StatefulWidget {
  const RoomLobby({
    super.key,
    required this.roomId,
    required this.roomCode,
    required this.playerName,
  });

  final String roomId;
  final String roomCode;
  final String playerName;

  @override
  State<RoomLobby> createState() => _RoomLobbyState();
}

class _RoomLobbyState extends State<RoomLobby>
    with SingleTickerProviderStateMixin {
  // Sama dengan warna dinding di game agar rumah terlihat konsisten.
  static const _walls = [
    Color(0xFFF0DFB8),
    Color(0xFFCFE6D6),
    Color(0xFFF4CFC4),
    Color(0xFFD1DCF2),
  ];

  late final AnimationController _anim;
  final KostStreetCamera _cam = KostStreetCamera();
  final Map<String, List<KostFx>> _fx = {};
  final Map<String, bool> _prevReady = {};
  bool _playersLoaded = false;
  final Map<String, double> _lightLv = {}; // 0..1 per pemain, menyala bertahap
  int _lastLightMs = sceneNowMs();

  SupabaseClient get _db => Supabase.instance.client;
  List<Map<String, dynamic>> _players = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  RealtimeChannel? _channel;
  String? _hostId;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    _anim.addListener(() {
      _cam.step();
      final now = sceneNowMs();
      // Jendela menyala/redup bertahap (bukan seketika) saat SIAP berubah.
      final dt = min(0.1, max(0, now - _lastLightMs) / 1000.0);
      _lastLightMs = now;
      final k = 1 - exp(-dt * 2.2);
      for (final p in _players) {
        final pid = p['player_id'].toString();
        final target = p['is_ready'] == true ? 1.0 : 0.0;
        final cur = _lightLv[pid] ?? 0.0;
        _lightLv[pid] = cur + (target - cur) * k;
      }
      for (final l in _fx.values) {
        l.removeWhere((f) => now - f.startMs > 5000);
      }
    });
    _refreshPlayers();
    _refreshRoom();
    _channel = _db
        .channel('lobby-${widget.roomId}')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'room_players',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: widget.roomId,
      ),
      callback: (_) => _refreshPlayers(),
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'rooms',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: widget.roomId,
      ),
      callback: (_) => _refreshRoom(),
    )
        .subscribe();
  }

  Future<void> _refreshPlayers() async {
    try {
      final data = await _db
          .from('room_players')
          .select('player_id, player_name, is_ready')
          .eq('room_id', widget.roomId)
          .order('player_name');

      if (!mounted) return;
      final list = List<Map<String, dynamic>>.from(data);
      // Reaksi visual: 😎 saat ada yang bergabung, 👏 saat seseorang SIAP.
      final ids = <String>{};
      for (final p in list) {
        final pid = p['player_id'].toString();
        final ready = p['is_ready'] == true;
        ids.add(pid);
        if (_playersLoaded) {
          if (!_prevReady.containsKey(pid)) {
            _addFx(pid, 2);
          } else if (ready && _prevReady[pid] == false) {
            _addFx(pid, 8);
          }
        }
        _prevReady[pid] = ready;
      }
      _prevReady.removeWhere((k, _) => !ids.contains(k));
      _playersLoaded = true;
      setState(() {
        _players = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _addFx(String pid, int emojiCode) {
    (_fx[pid] ??= <KostFx>[])
        .add(KostFx(FxType.emoji, amount: emojiCode.toDouble()));
  }

  /// Urutan rumah di jalan: diurutkan berdasarkan id (sama dengan layar game).
  List<Map<String, dynamic>> get _ordered => [..._players]..sort((a, b) =>
      a['player_id'].toString().compareTo(b['player_id'].toString()));

  Future<void> _refreshRoom() async {
    try {
      final room = await _db
          .from('rooms')
          .select('host_id, status')
          .eq('id', widget.roomId)
          .single();
      if (!mounted) return;
      setState(() => _hostId = room['host_id']?.toString());
      if (room['status'] == 'playing' && !_navigated) {
        _navigated = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GameScreen(
              roomId: widget.roomId,
              roomCode: widget.roomCode,
            ),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _startGame() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _db.rpc('start_game', params: {'p_room': widget.roomId});
      await _refreshRoom();
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleReady() async {
    final user = _db.auth.currentUser;
    if (user == null) return;

    final me = _players.where((p) => p['player_id'] == user.id).firstOrNull;
    if (me == null) {
      setState(() => _error = 'Data pemain Anda belum muncul di lobi.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _db
          .from('room_players')
          .update({'is_ready': !(me['is_ready'] == true)})
          .eq('room_id', widget.roomId)
          .eq('player_id', user.id);
      await _refreshPlayers();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.roomCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2E7D32),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Kode ruangan ${widget.roomCode} berhasil disalin!'),
            ],
          ),
        ),
      );
  }

  @override
  void dispose() {
    _anim.dispose();
    if (_channel != null) {
      _db.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = _db.auth.currentUser?.id;
    final me = _players.where((p) => p['player_id'] == userId).firstOrNull;
    final ready = me?['is_ready'] == true;
    final isHost = _hostId != null && _hostId == userId;
    final readyCount = _players.where((p) => p['is_ready'] == true).length;
    final allReady = _players.length >= 2 && readyCount == _players.length;

    return Scaffold(
      body: Stack(
        children: [
          // Jumlah kamar di latar belakang bertambah mengikuti jumlah pemain yang siap
          Positioned.fill(
            child: KostBackdrop(
              rooms: 4 + _players.length * 2,
              defense: readyCount.clamp(0, 3),
              pollution: 5,
              trashRatio: 0.08,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A140F).withValues(alpha: 0.72),
                    const Color(0xFF0A140F).withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Baris Atas (Tombol Kembali + Status Lobi)
                      Row(
                        children: [
                          IconButton.filledTonal(
                            style: IconButton.styleFrom(
                              backgroundColor:
                              Colors.white.withValues(alpha: 0.12),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ruang Tunggu',
                                  style: TextStyle(
                                    color: Color(0xFF81C784),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                                Text(
                                  'Menunggu Pemain Lain...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.people_alt_rounded,
                                  size: 16,
                                  color: Color(0xFFFFCA28),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_players.length}/4',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Kartu Tiket Kode Ruangan
                      _buildRoomCodeBanner(),
                      const SizedBox(height: 18),

                      // Jalan kost: satu rumah per pemain yang bergabung.
                      // Jendela menyala saat pemain menekan SIAP.
                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : _buildStreet(userId),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Bilah Tombol Bawah
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 54,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: ready
                                      ? const Color(0xFF37474F)
                                      : const Color(0xFF43A047),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                onPressed:
                                _busy || me == null ? null : _toggleReady,
                                icon: Icon(
                                  ready
                                      ? Icons.pause_circle_outline
                                      : Icons.check_circle_rounded,
                                ),
                                label: Text(
                                  _busy
                                      ? 'MEMPROSES…'
                                      : ready
                                      ? 'BATAL SIAP'
                                      : 'SAYA SIAP!',
                                ),
                              ),
                            ),
                          ),
                          if (isHost) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 54,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: allReady
                                        ? const Color(0xFFFFCA28)
                                        : Colors.white.withValues(alpha: 0.15),
                                    foregroundColor: allReady
                                        ? Colors.black87
                                        : Colors.white54,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  onPressed: _busy ? null : _startGame,
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('MULAI GAME'),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isHost
                            ? (allReady
                            ? 'Semua pemain sudah siap! Tekan MULAI GAME.'
                            : 'Menunggu minimal 2 pemain & semuanya menekan SAYA SIAP.')
                            : 'Menunggu Host memulai pertandingan…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCodeBanner() {
    return InkWell(
      onTap: _copyCode,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3C2B), Color(0xFF14281D)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFFFCA28).withValues(alpha: 0.45),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KODE RUANGAN (KETUK UNTUK SALIN)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.roomCode,
                    style: const TextStyle(
                      color: Color(0xFFFFCA28),
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFCA28).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFFCA28).withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded, color: Color(0xFFFFCA28), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'SALIN',
                    style: TextStyle(
                      color: Color(0xFFFFCA28),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  KostSceneData _houseFor(Map<String, dynamic> p, int i) {
    final pid = p['player_id'].toString();
    final ready = p['is_ready'] == true;
    return KostSceneData(
      rooms: 4,
      maxRooms: 12,
      defense: ready ? 1 : 0,
      wasteLevel: 1,
      trashRatio: 0,
      pollution: 4,
      wall: _walls[i % _walls.length],
      fx: _fx[pid] ?? const <KostFx>[],
      seed: pid.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) % 1000),
      // SIAP -> jendela menyala; belum siap -> gelap.
      lights: _lightLv[pid] ?? (ready ? 1.0 : 0.0),
    );
  }

  Widget _buildStreet(String? userId) {
    final list = _ordered;
    final n = list.length;
    if (n == 0) {
      return const Center(
        child: Text('Menunggu pemain…', style: TextStyle(color: Colors.white70)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            width: 1.5,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final size = Size(c.maxWidth, c.maxHeight);
            const insets = EdgeInsets.only(top: 52);
            final stage = _cam.stageFor(size, insets);
            final fit = min(
              stage.width * 0.96 / (n * kStreetSlotW),
              stage.height / kStreetSlotH,
            );
            _cam.setTarget(n * kStreetSlotW / 2, min(fit, 1.15));

            final backdrop = KostSceneData(
              rooms: 0,
              maxRooms: 12,
              defense: 0,
              trashRatio: 0,
              pollution: 4,
            );
            final ids = [for (final p in list) p['player_id'].toString()];

            return Stack(
              children: [
                Positioned.fill(
                  // dibangun ulang tiap frame agar cahaya jendela & efek halus
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) => KostStreet(
                      houses: [
                        for (var i = 0; i < n; i++) _houseFor(list[i], i),
                      ],
                      backdrop: backdrop,
                      camera: _cam,
                      repaint: _anim,
                      ids: ids,
                      insets: insets,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _anim,
                      builder: (context, _) => Stack(
                        clipBehavior: Clip.none,
                        children: _nameTags(list, stage, userId),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Kartu nama + status SIAP di atas atap tiap rumah, mengikuti kamera.
  List<Widget> _nameTags(
      List<Map<String, dynamic>> list, Rect stage, String? userId) {
    final s = _cam.scale;
    final o = _cam.origin(stage);
    final out = <Widget>[];
    for (var i = 0; i < list.length; i++) {
      final p = list[i];
      final pid = p['player_id'].toString();
      final cx = o.dx + (i * kStreetSlotW + kStreetSlotW / 2) * s;
      final roofY = o.dy + (236.0 - 50.0) * s;
      final w = (kStreetSlotW * s - 6).clamp(84.0, 190.0).toDouble();
      final emoji = kostActiveEmoji(_fx[pid]);
      final top = max(
          4.0, roofY - 47 * s - 54 - (emoji != null ? kEmojiBoxH : 0.0));
      out.add(Positioned(
        left: cx - w / 2,
        top: top,
        width: w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) KostEmojiBubble(fx: emoji),
            _nameTag(p, pid == userId, pid == _hostId),
          ],
        ),
      ));
    }
    return out;
  }

  Widget _nameTag(Map<String, dynamic> p, bool isMe, bool isHost) {
    final ready = p['is_ready'] == true;
    final accent = ready ? const Color(0xFF81C784) : Colors.amber.shade300;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: const Color(0xFF12221A).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ready
              ? const Color(0xFF66BB6A)
              : (isMe
              ? const Color(0xFFFFCA28).withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.18)),
          width: ready || isMe ? 1.8 : 1,
        ),
        boxShadow: [
          if (ready)
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.35),
              blurRadius: 12,
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isHost)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.workspace_premium_rounded,
                      size: 13, color: Color(0xFFFFCA28)),
                ),
              Flexible(
                child: Text(
                  '${p['player_name'] ?? 'Pemain'}${isMe ? ' (Anda)' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isMe ? const Color(0xFFFFCA28) : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ready ? Icons.lightbulb_rounded : Icons.lightbulb_outline,
                size: 12,
                color: accent,
              ),
              const SizedBox(width: 3),
              Text(
                ready ? 'SIAP' : 'Belum siap',
                style: TextStyle(
                  color: accent,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}