import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'game_screen.dart';

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://tbkoiuydiqvfedjiqlih.supabase.co',
);
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRia29pdXlkaXF2ZmVkamlxbGloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2NTQ1MTgsImV4cCI6MjEwODIzMDUxOH0.JC_xoqEn2YMQnayqbxMtSMPjzdtxsJ7dc0nMj4SwVJQ',
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
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
          seedColor: const Color(0xFF477A62),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F6F2),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const LobbyHome(),
    );
  }
}

class LobbyHome extends StatefulWidget {
  const LobbyHome({super.key});

  @override
  State<LobbyHome> createState() => _LobbyHomeState();
}

class _LobbyHomeState extends State<LobbyHome> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _error;

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
      setState(() => _error = 'Isi nama pemain terlebih dahulu.');
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

      // Try a few codes in case a rare collision occurs.
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
          // A unique-code collision can be retried; other DB errors should surface.
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
            roomCode: room!['code'].toString(),
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
      setState(() => _error = 'Isi nama pemain dan kode ruangan.');
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

      // SQL function join_room_by_code should return the room UUID.
      final result = await _db.rpc(
        'join_room_by_code',
        params: {'p_code': code, 'p_name': name},
      );

      final roomId = _extractRoomId(result);
      if (roomId == null) {
        throw Exception(
          'Fungsi join_room_by_code tidak mengembalikan UUID ruangan. '
              'Periksa bentuk RETURN pada SQL function.',
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
    if (e is PostgrestException) {
      return e.message;
    }
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'SAMPAHNYA',
                      style: TextStyle(
                        fontSize: 13,
                        letterSpacing: 2.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Masuk ke permainan',
                      style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _nameController,
                      maxLength: 18,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nama pemain',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : _createRoom,
                      child: Text(_busy ? 'Memproses…' : 'Buat ruangan'),
                    ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeController,
                      maxLength: 6,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Kode ruangan',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy ? null : _joinRoom,
                      child: const Text('Gabung ruangan'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

class _RoomLobbyState extends State<RoomLobby> {
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
      setState(() {
        _players = List<Map<String, dynamic>>.from(data);
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

  @override
  void dispose() {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lobi permainan'),
        actions: [
          IconButton(
            tooltip: 'Salin kode ruangan',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.roomCode));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kode ruangan disalin')),
                );
              }
            },
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('KODE RUANGAN'),
                        const SizedBox(height: 6),
                        SelectableText(
                          widget.roomCode,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('Bagikan kode ini kepada teman.'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pemain',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text('${_players.length}/4'),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                    itemCount: 4,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index >= _players.length) {
                        return Card(
                          elevation: 0,
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person_outline),
                            ),
                            title: Text('Menunggu pemain ${index + 1}'),
                            subtitle: const Text('Slot kosong'),
                          ),
                        );
                      }
                      final player = _players[index];
                      final isMe = player['player_id'] == userId;
                      final isReady = player['is_ready'] == true;
                      return Card(
                        elevation: 0,
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text('${index + 1}'),
                          ),
                          title: Text(
                            '${player['player_name'] ?? 'Pemain'}'
                                '${isMe ? ' (Anda)' : ''}',
                          ),
                          trailing: Text(
                            isReady ? 'Siap' : 'Belum siap',
                            style: TextStyle(
                              color: isReady
                                  ? const Color(0xFF26734D)
                                  : Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy || me == null ? null : _toggleReady,
                  child: Text(
                    _busy
                        ? 'Memproses…'
                        : ready
                        ? 'Batalkan siap'
                        : 'Saya siap',
                  ),
                ),
                const SizedBox(height: 8),
                if (isHost) ...[
                  FilledButton.tonal(
                    onPressed: _busy ? null : _startGame,
                    child: const Text('Mulai permainan'),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  isHost
                      ? 'Mulai setelah semua pemain siap (minimal 2).'
                      : 'Menunggu host memulai permainan.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}