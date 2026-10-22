import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'kost_scene.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.roomId, required this.roomCode});

  final String roomId;
  final String roomCode;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  static const _maxRooms = 12;
  static const _maxDefense = 3;
  static const _walls = [
    Color(0xFFF0DFB8),
    Color(0xFFCFE6D6),
    Color(0xFFF4CFC4),
    Color(0xFFD1DCF2),
  ];

  SupabaseClient get _db => Supabase.instance.client;
  String get _me => _db.auth.currentUser?.id ?? '';

  Map<String, dynamic> _room = {};
  final Map<String, Map<String, dynamic>> _states = {};
  final Map<String, String> _names = {};
  final List<Map<String, dynamic>> _events = [];

  // efek visual per pemain (dipicu event realtime) & durasi truk
  final Map<String, List<KostFx>> _fx = {};
  final Map<String, double> _haulTotal = {};

  Duration _offset = Duration.zero; // jam server - jam klien
  RealtimeChannel? _channel;
  Timer? _uiTimer;
  Timer? _tickTimer;
  late final AnimationController _anim; // penggerak animasi adegan
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    _subscribe();
    _loadAll();
    _tickServer();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final now = sceneNowMs();
      for (final l in _fx.values) {
        l.removeWhere((f) => now - f.startMs > 6000);
      }
      setState(() {});
    });
    _tickTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => _tickServer());
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _tickTimer?.cancel();
    _anim.dispose();
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
        final ev = Map<String, dynamic>.from(r);
        _addFx(ev);
        setState(() {
          _events.insert(0, ev);
          if (_events.length > 20) _events.removeLast();
        });
      },
    )
        .subscribe();
  }

  /// Ubah event game menjadi efek visual di kost yang bersangkutan.
  void _addFx(Map<String, dynamic> e) {
    final actor = e['actor_id']?.toString();
    final target = e['target_id']?.toString();
    final amt = _num(e['amount']);
    void add(String? id, FxType t) {
      if (id == null) return;
      (_fx[id] ??= <KostFx>[]).add(KostFx(t, amount: amt));
    }

    switch (e['type']) {
      case 'burn':
        add(actor, FxType.burn);
        break;
      case 'build':
        add(actor, FxType.build);
        break;
      case 'defense':
        add(actor, FxType.defense);
        break;
      case 'throw':
        add(actor, FxType.outgoing);
        add(target, FxType.incoming);
        break;
      case 'eliminated':
        add(target, FxType.collapse);
        break;
      default:
        break; // 'haul' digambar dari status hauler_busy_until
    }
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

  (IconData, Color) _eventIcon(dynamic type) {
    switch (type) {
      case 'burn':
        return (Icons.local_fire_department, Colors.deepOrange);
      case 'throw':
        return (Icons.delete_sweep, Colors.brown);
      case 'haul':
        return (Icons.local_shipping, Colors.green.shade700);
      case 'build':
        return (Icons.add_home_work, Colors.blue.shade700);
      case 'defense':
        return (Icons.shield, Colors.teal);
      case 'eliminated':
        return (Icons.warning_amber_rounded, Colors.red.shade700);
      default:
        return (Icons.info_outline, Colors.grey);
    }
  }

  Color _wallFor(String id) {
    final ids = _states.keys.toList()..sort();
    final i = ids.indexOf(id);
    return _walls[(i < 0 ? 0 : i) % _walls.length];
  }

  /// Progres 0..1 animasi truk sampah, null bila tidak sedang mengangkut.
  double? _haulProgress(String id, Map<String, dynamic> s) {
    final left = _remaining(s['hauler_busy_until']);
    if (left <= 0) {
      _haulTotal.remove(id);
      return null;
    }
    final total = max(_haulTotal[id] ?? 0.0, left);
    _haulTotal[id] = total;
    return (1 - left / total).clamp(0.0, 1.0).toDouble();
  }

  KostSceneData _sceneData(String id, Map<String, dynamic> s,
      {required bool compact}) {
    final live = _live(s);
    final cap = max(1.0, _num(s['trash_capacity']));
    return KostSceneData(
      rooms: _num(s['rooms_count']).toInt(),
      maxRooms: _maxRooms,
      defense: _num(s['defense']).toInt(),
      trashRatio: (live.trash / cap).clamp(0.0, 1.0).toDouble(),
      pollution: _pollution,
      eliminated: s['eliminated_at'] != null,
      protectedLeft: _remaining(s['protected_until']),
      haulProgress: _haulProgress(id, s),
      burnPenalty: _remaining(s['burn_penalty_until']) > 0,
      smog: _remaining(_room['smog_until']) > 0,
      fx: _fx[id] ?? const <KostFx>[],
      wall: _wallFor(id),
      compact: compact,
      facingRight: !compact,
    );
  }

  Widget _meter(double value, double maxValue, Color color,
      {double height = 14}) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: (value / maxValue).clamp(0.0, 1.0).toDouble(),
          minHeight: height,
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
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 820;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 1280 : 640),
              child: wide
                  ? _wideBody(me, others, canAct, finished)
                  : _narrowBody(me, others, canAct, finished),
            ),
          );
        },
      ),
    );
  }

  /// Layar lebar: kiri = kost pemain (besar), kanan = kisi-kisi lawan.
  Widget _wideBody(
      Map<String, dynamic>? me,
      List<MapEntry<String, Map<String, dynamic>>> others,
      bool canAct,
      bool finished,
      ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _topBar(finished),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      // skala adegan agar tombol aksi tetap terlihat
                      final sceneW = min(
                        c.maxWidth,
                        max(340.0, (c.maxHeight - 290) * 4 / 3),
                      );
                      return SingleChildScrollView(
                        child: _myPanel(me, canAct, sceneMaxWidth: sceneW),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: SingleChildScrollView(
                    child: _rightPanel(others, canAct, me),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Layar sempit (HP portrait): ditumpuk ke bawah.
  Widget _narrowBody(
      Map<String, dynamic>? me,
      List<MapEntry<String, Map<String, dynamic>>> others,
      bool canAct,
      bool finished,
      ) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _topBar(finished),
        const SizedBox(height: 12),
        _myPanel(me, canAct),
        const SizedBox(height: 16),
        _rightPanel(others, canAct, me),
      ],
    );
  }

  Widget _topBar(bool finished) {
    return Column(
      children: [
        if (finished) _finishedCard(),
        if (!finished && _remaining(_room['smog_until']) > 0) _smogBanner(),
        _pollutionCard(),
      ],
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
      child: Row(
        children: [
          const Icon(Icons.masks, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'KABUT ASAP! Pembakaran diblokir dan income berhenti '
                  '(${_remaining(_room['smog_until']).ceil()} dtk).',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _pollutionCard() {
    final p = _pollution;
    final (label, color) = _pollutionLevel(p);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.cloud, color: color),
            const SizedBox(width: 10),
            const Text('Polusi bersama',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            Expanded(child: _meter(p, 100, color, height: 10)),
            const SizedBox(width: 10),
            Text('${p.round()}%',
                style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            const SizedBox(width: 10),
            Flexible(
              flex: 2,
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------ panel kiri (pemain)

  Widget _hudChip({
    required IconData icon,
    required String text,
    String? sub,
    Color iconColor = const Color(0xFFFFC107),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          if (sub != null) ...[
            const SizedBox(width: 6),
            Text(sub,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _myPanel(Map<String, dynamic>? s, bool canAct,
      {double? sceneMaxWidth}) {
    if (s == null) {
      return const Card(
        elevation: 0,
        child: ListTile(title: Text('Anda penonton di ruangan ini.')),
      );
    }

    final live = _live(s);
    final cap = max(1.0, _num(s['trash_capacity']));
    final ratio = live.trash / cap;
    final out = s['eliminated_at'] != null;
    final penalty = _remaining(s['burn_penalty_until']);
    final stacks = _num(s['burn_stacks']).toInt();
    final prot = _remaining(s['protected_until']);
    final rooms = _num(s['rooms_count']).toInt();
    final defense = _num(s['defense']).toInt();
    final critical = ratio >= 0.9 && !out;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.home_work),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Kost ${_name(_me)}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            _statChip(Icons.meeting_room, '$rooms/$_maxRooms kamar'),
            const SizedBox(width: 6),
            _statChip(Icons.shield, '$defense/$_maxDefense'),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: ConstrainedBox(
            constraints:
            BoxConstraints(maxWidth: sceneMaxWidth ?? double.infinity),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: critical ? Colors.red.shade700 : Colors.black12,
                  width: critical ? 2.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    KostScene(
                      data: _sceneData(_me, s, compact: false),
                      repaint: _anim,
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _hudChip(
                        icon: Icons.payments,
                        text: live.money.floor().toString(),
                        sub: out
                            ? null
                            : '+${_num(s['income_rate']).toStringAsFixed(1)}/dtk',
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (penalty > 0 && !out)
                            _tag(Icons.local_fire_department,
                                'Penalti bakar x$stacks · ${penalty.ceil()} dtk',
                                Colors.deepOrange),
                          if (prot > 0 && !out) ...[
                            const SizedBox(height: 4),
                            _tag(Icons.shield, 'Dilindungi ${prot.ceil()} dtk',
                                Colors.amber.shade800),
                          ],
                        ],
                      ),
                    ),
                    if (critical)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 8,
                        child: Center(
                          child: _tag(Icons.warning_amber_rounded,
                              'SAMPAH KRITIS!', Colors.red.shade700),
                        ),
                      ),
                    if (out)
                      Positioned.fill(
                        child: Center(
                          child: Transform.rotate(
                            angle: -0.12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.red.shade400, width: 3),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.black.withValues(alpha: 0.45),
                              ),
                              child: Text('TERTIMBUN',
                                  style: TextStyle(
                                      color: Colors.red.shade300,
                                      fontSize: 24,
                                      letterSpacing: 3,
                                      fontWeight: FontWeight.w900)),
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
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: _trashColor(ratio)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        out
                            ? 'Anda tertimbun sampah.'
                            : 'Sampah ${live.trash.floor()} / ${cap.floor()}'
                            ' · ${_trashStage(ratio)}',
                        style: TextStyle(
                            color: _trashColor(ratio),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _meter(live.trash, cap, _trashColor(ratio)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _actionsCard(s, canAct),
      ],
    );
  }

  Widget _statChip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    ),
  );

  Widget _tag(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ],
    ),
  );

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

    final tiles = <Widget>[
      _ActionTile(
        icon: Icons.add_home_work,
        color: Colors.blue.shade700,
        title: rooms >= _maxRooms ? 'Kamar penuh' : 'Bangun kamar',
        subtitle: rooms >= _maxRooms ? 'Maksimal $_maxRooms' : 'Biaya $cost',
        onTap: canAct && rooms < _maxRooms && live.money >= cost
            ? () => _act('build_room')
            : null,
      ),
      _ActionTile(
        icon: Icons.local_shipping,
        color: Colors.green.shade700,
        title: 'Tukang sampah',
        subtitle:
        haulLeft > 0 ? 'Mengangkut… ${haulLeft.ceil()}s' : '~$haulCost',
        onTap: canAct &&
            haulLeft == 0 &&
            live.trash >= 1 &&
            live.money >= haulCost
            ? () => _act('hire_hauler')
            : null,
      ),
      _ActionTile(
        icon: Icons.local_fire_department,
        color: Colors.deepOrange,
        title: 'Bakar sampah',
        subtitle: burnLeft > 0
            ? 'Jeda ${burnLeft.ceil()}s'
            : smog
            ? 'Terblokir kabut'
            : 'Gratis, polusi naik',
        onTap: canAct && burnLeft == 0 && !smog && live.trash >= 2
            ? () => _act('burn')
            : null,
      ),
      _ActionTile(
        icon: Icons.shield,
        color: Colors.teal,
        title: defense >= _maxDefense ? 'Pertahanan maks' : 'Pertahanan',
        subtitle: defense >= _maxDefense
            ? 'Level $_maxDefense/$_maxDefense'
            : 'Lv ${defense + 1} · $defCost',
        onTap: canAct && defense < _maxDefense && live.money >= defCost
            ? () => _act('buy_defense')
            : null,
      ),
    ];

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Aksi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 480 ? 4 : 2;
                final w = (c.maxWidth - 8 * (cols - 1)) / cols;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in tiles) SizedBox(width: w, child: t),
                  ],
                );
              },
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

  // ------------------------------------------------ panel kanan (lawan)

  Widget _rightPanel(
      List<MapEntry<String, Map<String, dynamic>>> others,
      bool canAct,
      Map<String, dynamic>? me,
      ) {
    // 1 lawan -> kartu besar; lebih dari 1 -> kisi 2 kolom
    final cols = others.length > 1 ? 2 : 1;
    final compact = others.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Kost lawan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (others.isEmpty)
          const Card(
            elevation: 0,
            child: ListTile(title: Text('Belum ada lawan.')),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              const gap = 10.0;
              final w = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final e in others)
                    SizedBox(
                      width: w,
                      child:
                      _opponentCard(e.key, e.value, canAct, me, compact),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 12),
        _feedCard(),
      ],
    );
  }

  Widget _opponentCard(
      String id,
      Map<String, dynamic> s,
      bool canAct,
      Map<String, dynamic>? me,
      bool compact,
      ) {
    final live = _live(s);
    final cap = max(1.0, _num(s['trash_capacity']));
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

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              KostScene(
                data: _sceneData(id, s, compact: compact),
                repaint: _anim,
              ),
              Positioned(
                left: 6,
                top: 6,
                right: 6,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _name(id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              if (out)
                Positioned.fill(
                  child: Center(
                    child: Text('TERTIMBUN',
                        style: TextStyle(
                            color: Colors.red.shade300,
                            fontSize: compact ? 13 : 20,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.meeting_room, size: 14),
                    const SizedBox(width: 3),
                    Text('${_num(s['rooms_count']).toInt()}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 10),
                    const Icon(Icons.shield, size: 14),
                    const SizedBox(width: 3),
                    Text('${_num(s['defense']).toInt()}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                _meter(live.trash, cap, _trashColor(ratio), height: 10),
                const SizedBox(height: 4),
                Text(status,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: _trashColor(ratio))),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: enabled
                      ? () => _act('throw_trash', {'p_target': id})
                      : null,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(throwLeft > 0
                        ? 'Buang (${throwLeft.ceil()}s)'
                        : 'Buang ke sini (10)'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _feedCard() {
    final list = _events.where((e) => _eventText(e).isNotEmpty).take(8).toList();
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kabar terbaru',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (list.isEmpty) const Text('Belum ada kejadian.'),
            for (final e in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_eventIcon(e['type']).$1,
                        size: 16, color: _eventIcon(e['type']).$2),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_eventText(e),
                            style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tombol aksi bergaya kartu: ikon berwarna + judul + keterangan biaya/jeda.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final c = enabled ? color : Colors.grey;
    return SizedBox(
      height: 96,
      child: Material(
        color: c.withValues(alpha: enabled ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: c,
                  child: Icon(icon, size: 18, color: Colors.white),
                ),
                const Spacer(),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: enabled ? null : Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        color: enabled
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Colors.grey.shade500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}