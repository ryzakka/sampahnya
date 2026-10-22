import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.roomId, required this.roomCode});

  final String roomId;
  final String roomCode;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const _maxRooms = 12;
  static const _maxDefense = 3;

  SupabaseClient get _db => Supabase.instance.client;
  String get _me => _db.auth.currentUser?.id ?? '';

  Map<String, dynamic> _room = {};
  final Map<String, Map<String, dynamic>> _states = {};
  final Map<String, String> _names = {};
  final List<Map<String, dynamic>> _events = [];

  Duration _offset = Duration.zero; // jam server - jam klien
  RealtimeChannel? _channel;
  Timer? _uiTimer;
  Timer? _tickTimer;
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _loadAll();
    _tickServer();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
    _tickTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => _tickServer());
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _tickTimer?.cancel();
    if (_channel != null) _db.removeChannel(_channel!);
    super.dispose();
  }

  // ---------------------------------------------------------------- data

  void _subscribe() {
    PostgresChangeFilter roomFilter(String column) => PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: column,
      value: widget.roomId,
    );

    _channel = _db
        .channel('game-${widget.roomId}')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'player_state',
      filter: roomFilter('room_id'),
      callback: (p) {
        final r = p.newRecord;
        if (r.isEmpty || !mounted) return;
        setState(() {
          _states[r['player_id'] as String] = Map<String, dynamic>.from(r);
        });
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'rooms',
      filter: roomFilter('id'),
      callback: (p) {
        final r = p.newRecord;
        if (r.isEmpty || !mounted) return;
        setState(() {
          _room = {..._room, ...r};
        });
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'game_events',
      filter: roomFilter('room_id'),
      callback: (p) {
        final r = p.newRecord;
        if (r.isEmpty || !mounted) return;
        setState(() {
          _events.insert(0, Map<String, dynamic>.from(r));
          if (_events.length > 20) _events.removeLast();
        });
      },
    )
        .subscribe();
  }

  Future<void> _loadAll() async {
    try {
      final room =
      await _db.from('rooms').select().eq('id', widget.roomId).single();
      final st =
      await _db.from('player_state').select().eq('room_id', widget.roomId);
      final names = await _db
          .from('room_players')
          .select('player_id, player_name')
          .eq('room_id', widget.roomId);
      final ev = await _db
          .from('game_events')
          .select()
          .eq('room_id', widget.roomId)
          .order('id', ascending: false)
          .limit(20);
      if (!mounted) return;
      setState(() {
        _room = Map<String, dynamic>.from(room);
        _states.clear();
        for (final s in st) {
          _states[s['player_id'] as String] = Map<String, dynamic>.from(s);
        }
        for (final n in names) {
          _names[n['player_id'] as String] = n['player_name'] as String;
        }
        _events
          ..clear()
          ..addAll(ev.map((e) => Map<String, dynamic>.from(e)));
        _loaded = true;
      });
    } catch (e) {
      _toast('Gagal memuat: $e');
    }
  }

  Future<void> _tickServer() async {
    if (_room['status'] == 'finished') return;
    try {
      final t0 = DateTime.now();
      final res = await _db.rpc('game_tick', params: {'p_room': widget.roomId});
      final t1 = DateTime.now();
      final serverNow = DateTime.parse(res['server_now'] as String);
      final mid = t0.add(t1.difference(t0) ~/ 2);
      _offset = serverNow.difference(mid);
    } catch (_) {
      // abaikan; tick berikutnya akan mencoba lagi
    }
  }

  Future<void> _act(String fn, [Map<String, dynamic> extra = const {}]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _db.rpc(fn, params: {'p_room': widget.roomId, ...extra});
      await _loadAll();
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  // ------------------------------------------------------------- helpers

  DateTime get _serverNow => DateTime.now().add(_offset);

  DateTime? _ts(dynamic v) => v == null ? null : DateTime.parse(v as String);
  double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

  double _remaining(dynamic until) {
    final t = _ts(until);
    if (t == null) return 0;
    final d = t.difference(_serverNow).inMilliseconds / 1000;
    return d > 0 ? d : 0;
  }

  String _name(dynamic id) {
    if (id == null) return '?';
    if (id == _me) return 'Anda';
    return _names[id] ?? 'Pemain';
  }

  /// Nilai uang & sampah "sekarang", diekstrapolasi dari rate server.
  ({double money, double trash}) _live(Map<String, dynamic> s) {
    final cap = _num(s['trash_capacity']);
    if (s['eliminated_at'] != null) return (money: _num(s['money']), trash: cap);
    final updated = _ts(s['updated_at'])!;
    final dt = max(0.0, _serverNow.difference(updated).inMilliseconds / 1000);
    var trash = _num(s['trash']) + _num(s['trash_rate']) * dt;
    final hauled = _num(s['hauler_amount']);
    if (hauled > 0 && _remaining(s['hauler_busy_until']) == 0) {
      trash -= hauled;
    }
    return (
    money: _num(s['money']) + _num(s['income_rate']) * dt,
    trash: trash.clamp(0.0, cap).toDouble(),
    );
  }

  double get _pollution {
    final p = _num(_room['pollution']);
    final t = _ts(_room['pollution_updated_at']);
    if (t == null) return p;
    final dt = max(0.0, _serverNow.difference(t).inMilliseconds / 1000);
    return max(0.0, p - 0.4 * dt);
  }

  // harus sama dengan build_room() di SQL
  int _buildCost(Map<String, dynamic> s) =>
      (100 * pow(1.35, _num(s['rooms_count'])) * (_pollution >= 60 ? 1.5 : 1))
          .round();

  (String, Color) _pollutionLevel(double p) {
    if (p >= 85) return ('Darurat: income -40%, sampah +20%', Colors.red.shade700);
    if (p >= 60) return ('Asap tebal: income -25%', Colors.deepOrange);
    if (p >= 30) return ('Langit kelabu: income -10%', Colors.amber.shade800);
    return ('Udara aman', Colors.green.shade700);
  }

  String _trashStage(double ratio) {
    if (ratio >= 0.9) return 'KRITIS: income -60%';
    if (ratio >= 0.75) return 'Penghuni kabur: income -40%';
    if (ratio >= 0.5) return 'Mulai bau: income -15%';
    return 'Normal';
  }

  Color _trashColor(double ratio) {
    if (ratio >= 0.9) return Colors.red.shade700;
    if (ratio >= 0.75) return Colors.deepOrange;
    if (ratio >= 0.5) return Colors.amber.shade800;
    return Colors.green.shade700;
  }

  String _eventText(Map<String, dynamic> e) {
    final a = _name(e['actor_id']);
    final t = _name(e['target_id']);
    final amt = _num(e['amount']).round();
    switch (e['type']) {
      case 'burn':
        return '$a membakar sampah! Polusi naik.';
      case 'throw':
        return t == 'Anda'
            ? '$a membuang $amt sampah ke kost-mu!'
            : '$a membuang $amt sampah ke kost $t.';
      case 'haul':
        return '$a menyewa tukang sampah.';
      case 'build':
        return '$a membangun kamar baru.';
      case 'defense':
        return '$a memasang pertahanan.';
      case 'eliminated':
        return '$t tertimbun sampah!';
      default:
        return '';
    }
  }

  Widget _meter(double value, double maxValue, Color color) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: LinearProgressIndicator(
      value: (value / maxValue).clamp(0.0, 1.0).toDouble(),
      minHeight: 14,
      color: color,
      backgroundColor: color.withValues(alpha: 0.15),
    ),
  );

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(title: Text('Ruangan ${widget.roomCode}'));
    if (!_loaded) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final me = _states[_me];
    final finished = _room['status'] == 'finished';
    final alive = me != null && me['eliminated_at'] == null;
    final canAct = alive && !finished && !_busy;
    final others = _states.entries.where((e) => e.key != _me).toList()
      ..sort((a, b) => _name(a.key).compareTo(_name(b.key)));

    return Scaffold(
      appBar: appBar,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (finished) _finishedCard(),
              if (!finished && _remaining(_room['smog_until']) > 0)
                _smogBanner(),
              _pollutionCard(),
              const SizedBox(height: 12),
              if (me != null)
                _myCard(me)
              else
                const Card(
                  elevation: 0,
                  child: ListTile(title: Text('Anda penonton di ruangan ini.')),
                ),
              const SizedBox(height: 12),
              if (me != null) _actionsCard(me, canAct),
              const SizedBox(height: 16),
              const Text('Kost lawan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final e in others) _opponentCard(e.key, e.value, canAct, me),
              const SizedBox(height: 12),
              _feedCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _finishedCard() {
    final winner = _room['winner_id'];
    final text = winner == _me
        ? 'Anda menang! Kost Anda paling bertahan.'
        : '${_name(winner)} menang. Kost Anda kalah tertimbun sampah.';
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Permainan selesai',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(text),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Kembali ke beranda'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smogBanner() => Card(
    color: Colors.red.shade700,
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        'KABUT ASAP! Pembakaran diblokir dan income berhenti '
            '(${_remaining(_room['smog_until']).ceil()} dtk).',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget _pollutionCard() {
    final p = _pollution;
    final (label, color) = _pollutionLevel(p);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.cloud),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Polusi bersama',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text('${p.round()}%'),
            ]),
            const SizedBox(height: 8),
            _meter(p, 100, color),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _myCard(Map<String, dynamic> s) {
    final live = _live(s);
    final cap = _num(s['trash_capacity']);
    final ratio = live.trash / cap;
    final out = s['eliminated_at'] != null;
    final penalty = _remaining(s['burn_penalty_until']);
    final stacks = _num(s['burn_stacks']).toInt();
    final critical = ratio >= 0.9 && !out;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: critical ? Colors.red.shade700 : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.home_work),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${_name(_me)} (kost Anda)',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text('${_num(s['rooms_count']).toInt()} kamar'
                  ' · pertahanan ${_num(s['defense']).toInt()}'),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.payments, size: 20),
              const SizedBox(width: 6),
              Text(live.money.floor().toString(),
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              if (!out)
                Text('+${_num(s['income_rate']).toStringAsFixed(1)}/dtk'),
            ]),
            const SizedBox(height: 10),
            _meter(live.trash, cap, _trashColor(ratio)),
            const SizedBox(height: 6),
            Text(
              out
                  ? 'Anda tertimbun sampah.'
                  : 'Sampah ${live.trash.floor()} / ${cap.floor()}'
                  ' · ${_trashStage(ratio)}',
              style: TextStyle(color: _trashColor(ratio)),
            ),
            if (penalty > 0 && !out) ...[
              const SizedBox(height: 8),
              Chip(
                avatar: const Icon(Icons.local_fire_department, size: 18),
                label: Text('Penalti bakar x$stacks (${penalty.ceil()} dtk)'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionsCard(Map<String, dynamic> s, bool canAct) {
    final live = _live(s);
    final rooms = _num(s['rooms_count']).toInt();
    final defense = _num(s['defense']).toInt();
    final cost = _buildCost(s);
    final defCost = 150 * (defense + 1);
    final haulLeft = _remaining(s['hauler_busy_until']);
    final burnLeft = _remaining(s['burn_cooldown_until']);
    final smog = _remaining(_room['smog_until']) > 0;
    final haulCost = (min(live.trash.floorToDouble(), 40.0) * 3).ceil();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Aksi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: canAct && rooms < _maxRooms && live.money >= cost
                      ? () => _act('build_room')
                      : null,
                  icon: const Icon(Icons.add_home_work),
                  label: Text(rooms >= _maxRooms
                      ? 'Kamar penuh'
                      : 'Bangun kamar ($cost)'),
                ),
                FilledButton.tonalIcon(
                  onPressed: canAct &&
                      haulLeft == 0 &&
                      live.trash >= 1 &&
                      live.money >= haulCost
                      ? () => _act('hire_hauler')
                      : null,
                  icon: const Icon(Icons.local_shipping),
                  label: Text(haulLeft > 0
                      ? 'Mengangkut… ${haulLeft.ceil()}s'
                      : 'Tukang sampah (~$haulCost)'),
                ),
                FilledButton.tonalIcon(
                  onPressed: canAct && burnLeft == 0 && !smog && live.trash >= 2
                      ? () => _act('burn')
                      : null,
                  icon: const Icon(Icons.local_fire_department),
                  label: Text(burnLeft > 0
                      ? 'Bakar (${burnLeft.ceil()}s)'
                      : smog
                      ? 'Bakar (terblokir)'
                      : 'Bakar sampah'),
                ),
                FilledButton.tonalIcon(
                  onPressed:
                  canAct && defense < _maxDefense && live.money >= defCost
                      ? () => _act('buy_defense')
                      : null,
                  icon: const Icon(Icons.shield),
                  label: Text(defense >= _maxDefense
                      ? 'Pertahanan maks'
                      : 'Pertahanan ($defCost)'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Bakar menghapus ±50% sampah tapi menaikkan polusi untuk semua '
                  'pemain, dan Anda kena penalti income ekstra.',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _opponentCard(
      String id,
      Map<String, dynamic> s,
      bool canAct,
      Map<String, dynamic>? me,
      ) {
    final live = _live(s);
    final cap = _num(s['trash_capacity']);
    final ratio = live.trash / cap;
    final out = s['eliminated_at'] != null;
    final prot = _remaining(s['protected_until']);
    final throwLeft = me == null ? 0.0 : _remaining(me['throw_cooldown_until']);
    final mine = me == null ? null : _live(me);
    final status = out
        ? 'Tertimbun sampah'
        : prot > 0
        ? 'Dilindungi ${prot.ceil()} dtk'
        : _trashStage(ratio);
    final enabled = canAct &&
        !out &&
        prot == 0 &&
        throwLeft == 0 &&
        mine != null &&
        mine.trash >= 1 &&
        mine.money >= 10;

    return Opacity(
      opacity: out ? 0.5 : 1,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_name(id)} · ${_num(s['rooms_count']).toInt()} kamar'
                          ' · pertahanan ${_num(s['defense']).toInt()}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    _meter(live.trash, cap, _trashColor(ratio)),
                    const SizedBox(height: 4),
                    Text(status,
                        style: TextStyle(
                            fontSize: 12, color: _trashColor(ratio))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed:
                enabled ? () => _act('throw_trash', {'p_target': id}) : null,
                child: Text(throwLeft > 0
                    ? 'Buang (${throwLeft.ceil()}s)'
                    : 'Buang ke sini (10)'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feedCard() {
    final lines =
    _events.map(_eventText).where((t) => t.isNotEmpty).take(8).toList();
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kabar terbaru',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (lines.isEmpty) const Text('Belum ada kejadian.'),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l),
              ),
          ],
        ),
      ),
    );
  }
}