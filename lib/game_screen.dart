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
  static const _maxWaste = 12;
  static const _maxTier = 2;

  static const _walls = [
    Color(0xFFF0DFB8),
    Color(0xFFCFE6D6),
    Color(0xFFF4CFC4),
    Color(0xFFD1DCF2),
  ];
  static const _ink = Color(0xFF14201A);

  static const _wasteNames = [
    'Tanpa Fasilitas',
    'Kotak Kecil',
    'Kotak Sedang',
    'Kotak Besar',
    'Besar + Kecil',
    'Besar + Sedang',
    'Besar + Besar',
    'Mesin Daur Ulang',
    'Insinerator Polusi',
    'Insinerator Besar Polusi',
    'Insinerator Kecil Eco',
    'Insinerator Sedang Eco',
    'Insinerator Besar Eco',
  ];

  static const _wasteCosts = [
    0,
    80,
    130,
    200,
    290,
    400,
    540,
    720,
    950,
    1250,
    1650,
    2150,
    2800,
  ];

  static const _tierNames = ['Reguler', 'Eksklusif', 'Sultan'];

  SupabaseClient get _db => Supabase.instance.client;
  String get _me => _db.auth.currentUser?.id ?? '';

  Map<String, dynamic> _room = {};
  final Map<String, Map<String, dynamic>> _states = {};
  final Map<String, String> _names = {};
  final List<Map<String, dynamic>> _events = [];

  final Map<String, int> _prevRooms = {};
  final Map<String, int> _prevDefense = {};
  final Map<String, int> _prevWaste = {};
  final Map<String, int> _prevTier = {};

  final Map<String, List<KostFx>> _fx = {};
  final Map<String, double> _haulTotal = {};
  int _lastEventMs = -100000;

  Duration _offset = Duration.zero;
  RealtimeChannel? _channel;
  Timer? _uiTimer;
  Timer? _tickTimer;
  late final AnimationController _anim;
  String? _activeRpc;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _anim =
    AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    _subscribe();
    _loadAll();
    _tickServer();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
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
        final pid = r['player_id'] as String;
        final next = Map<String, dynamic>.from(r);

        final newRooms = _num(next['rooms_count']).toInt();
        if (_prevRooms[pid] != null && newRooms > _prevRooms[pid]!) {
          _ensureFx(pid, FxType.build);
        }
        _prevRooms[pid] = newRooms;

        final newDef = _num(next['defense']).toInt();
        if (_prevDefense[pid] != null && newDef > _prevDefense[pid]!) {
          _ensureFx(pid, FxType.defense);
        }
        _prevDefense[pid] = newDef;

        final newWaste = _num(next['waste_level']).toInt();
        if (_prevWaste[pid] != null && newWaste > _prevWaste[pid]!) {
          _ensureFx(pid, FxType.waste);
        }
        _prevWaste[pid] = newWaste;

        final newTier = _num(next['kost_tier']).toInt();
        if (_prevTier[pid] != null && newTier > _prevTier[pid]!) {
          _ensureFx(pid, FxType.tier);
        }
        _prevTier[pid] = newTier;

        setState(() {
          _states[pid] = next;
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
          _lastEventMs = sceneNowMs();
          _events.insert(0, ev);
          if (_events.length > 25) _events.removeLast();
        });
      },
    )
        .subscribe();
  }

  void _ensureFx(String? id, FxType t, {double amount = 0}) {
    if (id == null) return;
    final list = _fx[id] ??= <KostFx>[];
    final hasRecent = list.any((f) => f.type == t && f.age < 750);
    if (!hasRecent) {
      list.add(KostFx(t, amount: amount));
    }
  }

  void _addFx(Map<String, dynamic> e) {
    final actor = e['actor_id']?.toString();
    final target = e['target_id']?.toString();
    final amt = _num(e['amount']);

    switch (e['type']) {
      case 'burn':
        _ensureFx(actor, FxType.burn, amount: amt);
        break;
      case 'build':
        _ensureFx(actor, FxType.build, amount: amt);
        break;
      case 'defense':
        _ensureFx(actor, FxType.defense, amount: amt);
        break;
      case 'waste':
        _ensureFx(actor, FxType.waste, amount: amt);
        break;
      case 'tier':
        _ensureFx(actor, FxType.tier, amount: amt);
        break;
      case 'throw':
        _ensureFx(actor, FxType.outgoing, amount: amt);
        _ensureFx(target, FxType.incoming, amount: amt);
        break;
      case 'inspect':
        _ensureFx(target, FxType.inspect, amount: amt);
        break;
      case 'hijack':
        _ensureFx(actor, FxType.hijack, amount: amt);
        _ensureFx(target, FxType.hijack, amount: amt);
        break;
      case 'eliminated':
        _ensureFx(target, FxType.collapse, amount: amt);
        break;
      default:
        break;
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
          .limit(25);

      if (!mounted) return;
      setState(() {
        _room = Map<String, dynamic>.from(room);
        for (final s in st) {
          final map = Map<String, dynamic>.from(s);
          final pid = map['player_id'] as String;
          _states[pid] = map;
          _prevRooms[pid] = _num(map['rooms_count']).toInt();
          _prevDefense[pid] = _num(map['defense']).toInt();
          _prevWaste[pid] = _num(map['waste_level']).toInt();
          _prevTier[pid] = _num(map['kost_tier']).toInt();
        }
        for (final n in names) {
          _names[n['player_id'] as String] = n['player_name'] as String;
        }
        if (_events.isEmpty) {
          _events.addAll(ev.map((e) => Map<String, dynamic>.from(e)));
        }
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
    } catch (_) {}
  }

  Future<void> _act(String fn, [Map<String, dynamic> extra = const {}]) async {
    if (_activeRpc != null) return;
    setState(() => _activeRpc = fn);

    try {
      await _db.rpc(fn, params: {'p_room': widget.roomId, ...extra});
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _activeRpc = null);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(m),
        ),
      );
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

  String? get _activeWorldEvent {
    final ev = _room['world_event']?.toString();
    if (ev == null || ev.isEmpty) return null;
    if (_remaining(_room['world_event_until']) <= 0) return null;
    return ev;
  }

  String _name(dynamic id) {
    if (id == null) return '?';
    if (id == _me) return 'Anda';
    return _names[id] ?? 'Pemain';
  }

  ({double money, double trash}) _live(Map<String, dynamic> s) {
    final cap = _num(s['trash_capacity']);
    if (s['eliminated_at'] != null) {
      return (money: _num(s['money']), trash: cap);
    }
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
    var delta = _activeWorldEvent == 'eco_subsidy' ? -0.8 : -0.4;
    for (final s in _states.values) {
      if (s['eliminated_at'] != null) continue;
      final wl = _num(s['waste_level']).toInt();
      if (wl == 8) delta += 0.25;
      if (wl == 9) delta += 0.45;
      if (wl == 11) delta -= 0.15;
      if (wl == 12) delta -= 0.35;
    }
    return (p + delta * dt).clamp(0.0, 100.0).toDouble();
  }

  int _buildCost(Map<String, dynamic> s) {
    final base = 100 *
        pow(1.35, _num(s['rooms_count'])) *
        (_pollution >= 60 ? 1.5 : 1.0) *
        (_activeWorldEvent == 'new_semester' ? 0.75 : 1.0);
    return base.round();
  }

  int _wasteCost(int nextLevel) {
    if (nextLevel < 1 || nextLevel > _maxWaste) return 999999;
    final base = _wasteCosts[nextLevel];
    return (_activeWorldEvent == 'eco_subsidy' ? (base * 0.7) : base).round();
  }

  (String, Color) _pollutionLevel(double p) {
    if (p >= 85) {
      return ('Darurat: income -40%, sampah +20%', Colors.red.shade700);
    }
    if (p >= 60) return ('Asap tebal: income -25%', Colors.deepOrange);
    if (p >= 30) return ('Langit kelabu: income -10%', Colors.amber.shade800);
    return ('Udara aman', Colors.green.shade700);
  }

  (String, IconData, Color) _worldEventInfo(String ev) {
    switch (ev) {
      case 'rain_flood':
        return (
        'HUJAN BADAI & BANJIR · Sampah +35%, Truk 1.5x',
        Icons.thunderstorm,
        Colors.indigo.shade600,
        );
      case 'new_semester':
        return (
        'MUSIM MAHASISWA BARU · Income +35%, Kamar -25%',
        Icons.school,
        Colors.teal.shade700,
        );
      case 'hauler_strike':
        return (
        'MOGOK TUKANG SAMPAH · Sewa truk terkunci!',
        Icons.front_hand,
        Colors.deepOrange.shade800,
        );
      case 'eco_subsidy':
        return (
        'SUBSIDI HIJAU · Upgrade Bank Sampah -30%',
        Icons.eco,
        Colors.green.shade700,
        );
      default:
        return (ev, Icons.public, Colors.blueGrey);
    }
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
        return '$a membakar $amt sampah! Polusi naik.';
      case 'throw':
        return t == 'Anda'
            ? '$a melempar $amt sampah ke kost-mu!'
            : '$a melempar $amt sampah ke kost $t.';
      case 'haul':
        return '$a menyewa truk pengangkut sampah.';
      case 'build':
        return '$a membangun kamar ke-$amt!';
      case 'defense':
        return '$a menaikkan pertahanan ke Lv $amt!';
      case 'waste':
        final n = (amt >= 0 && amt < _wasteNames.length)
            ? _wasteNames[amt]
            : 'Lv $amt';
        return '$a memasang $n (Lv $amt)!';
      case 'tier':
        final tn = (amt >= 0 && amt < _tierNames.length)
            ? _tierNames[amt]
            : 'Tier $amt';
        return '$a merenovasi kost menjadi Kelas $tn!';
      case 'inspect':
        return t == 'Anda'
            ? '$a mengirim Sidak Dinas ke kost-mu! Denda $amt & disegel!'
            : '$a mengirim Sidak Dinas ke kost $t (Denda $amt).';
      case 'hijack':
        return t == 'Anda'
            ? '$a membajak truk sampah milikmu!'
            : '$a membajak truk sampah dari kost $t!';
      case 'event_rain_flood':
        return 'CUACA: Hujan Badai & Banjir melanda kawasan kost!';
      case 'event_new_semester':
        return 'EVENT: Musim Mahasiswa Baru! Sewa kost laris manis!';
      case 'event_hauler_strike':
        return 'DARURAT: Tukang sampah mogok kerja massal!';
      case 'event_eco_subsidy':
        return 'PROGRAM: Subsidi Hijau Pemerintah dimulai!';
      case 'eliminated':
        return '$t tertimbun lautan sampah!';
      default:
        return '';
    }
  }

  (IconData, Color) _eventIcon(dynamic type) {
    switch (type) {
      case 'burn':
        return (Icons.local_fire_department, Colors.deepOrange);
      case 'throw':
        return (Icons.rocket_launch, Colors.brown);
      case 'haul':
        return (Icons.local_shipping, Colors.green.shade700);
      case 'build':
        return (Icons.add_home_work, Colors.blue.shade700);
      case 'defense':
        return (Icons.shield, Colors.teal);
      case 'waste':
        return (Icons.recycling, Colors.lightGreen);
      case 'tier':
        return (Icons.workspace_premium, Colors.amber);
      case 'inspect':
        return (Icons.policy, Colors.redAccent);
      case 'hijack':
        return (Icons.u_turn_left, Colors.orange);
      case 'eliminated':
        return (Icons.warning_amber_rounded, Colors.red.shade700);
      default:
        return (Icons.public, Colors.cyanAccent);
    }
  }

  Color _wallFor(String id) {
    final ids = _states.keys.toList()..sort();
    final i = ids.indexOf(id);
    return _walls[(i < 0 ? 0 : i) % _walls.length];
  }

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
      wasteLevel: _num(s['waste_level']).toInt(),
      kostTier: _num(s['kost_tier']).toInt(),
      worldEvent: _activeWorldEvent,
      sealedLeft: _remaining(s['sealed_until']),
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
          backgroundColor: color.withValues(alpha: 0.18),
        ),
      );

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        backgroundColor: const Color(0xFF14201A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFFFCA28)),
              const SizedBox(height: 16),
              Text(
                'Menyiapkan Kost ${widget.roomCode}…',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final me = _states[_me];
    final finished = _room['status'] == 'finished';
    final alive = me != null && me['eliminated_at'] == null;
    final canAct = alive && !finished && _activeRpc == null;
    final others = _states.entries.where((e) => e.key != _me).toList()
      ..sort((a, b) => _name(a.key).compareTo(_name(b.key)));

    final String? mainId =
    me != null ? _me : (others.isNotEmpty ? others.first.key : null);
    final mainState = mainId == null ? null : _states[mainId];
    final rivals = me != null ? others : others.skip(1).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A22),
      body: LayoutBuilder(
        builder: (context, c) {
          final pad = MediaQuery.of(context).padding;
          final short = c.maxHeight < 540;
          final wide = c.maxWidth >= 760 && c.maxWidth >= c.maxHeight * 1.1;

          final hudH = wide ? (short ? 52.0 : 64.0) : 104.0;
          final barH = wide ? (short ? 64.0 : 94.0) : 132.0;
          final rightW = rivals.length > 1
              ? (c.maxWidth * 0.32).clamp(280.0, 390.0).toDouble()
              : (c.maxWidth * 0.24).clamp(220.0, 280.0).toDouble();
          final stripH = (!wide && rivals.isNotEmpty) ? 156.0 : 0.0;
          final hasBar = me != null;

          final topInset =
              pad.top + 8 + hudH + 8 + (stripH > 0 ? stripH + 8 : 0);
          final bottomInset = (hasBar ? barH + 8 : 0.0) + pad.bottom + 8;
          final rightInset = (wide && rivals.isNotEmpty) ? rightW + 24 : 0.0;

          final out = mainState != null && mainState['eliminated_at'] != null;

          return Stack(
            children: [
              // 1) Adegan utama
              Positioned.fill(
                child: mainState == null
                    ? const Center(
                  child: Text('Menunggu pemain…',
                      style: TextStyle(color: Colors.white70)),
                )
                    : KostStage(
                  data: _sceneData(mainId!, mainState, compact: false),
                  repaint: _anim,
                  insets: EdgeInsets.fromLTRB(
                      pad.left, topInset, rightInset, bottomInset),
                ),
              ),

              // 2) Stempel tertimbun
              if (out)
                Positioned(
                  left: 0,
                  right: rightInset,
                  top: topInset,
                  bottom: bottomInset,
                  child: IgnorePointer(child: Center(child: _stamp())),
                ),

              // 3) HUD Atas
              Positioned(
                top: pad.top + 8,
                left: 12 + pad.left,
                right: 12 + pad.right,
                child: _hud(wide, short, mainState),
              ),

              // 4) Tag Status & World Event
              Positioned(
                left: 12 + pad.left,
                top: topInset,
                child: IgnorePointer(
                  child: _statusTags(mainState, me == null),
                ),
              ),

              // 5) Panel Lawan
              if (wide && rivals.isNotEmpty)
                Positioned(
                  right: 12 + pad.right,
                  top: pad.top + 8 + hudH + 10,
                  bottom: pad.bottom + 12,
                  width: rightW,
                  child: _rivalPanel(rivals, canAct, me, rightW),
                ),
              if (!wide && rivals.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  top: pad.top + 8 + hudH + 8,
                  height: stripH,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 12 + pad.left),
                    itemCount: rivals.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: 152,
                        child: _rivalCard(
                            rivals[i].key, rivals[i].value, canAct, me),
                      ),
                    ),
                  ),
                ),

              // 6) Kabar singkat & Bilah Aksi
              if (hasBar) ...[
                Positioned(
                  left: 12 + pad.left,
                  right: (wide ? rightInset : 12) + pad.right,
                  bottom: bottomInset - 2,
                  child: IgnorePointer(child: Center(child: _eventToast())),
                ),
                Positioned(
                  left: 12 + pad.left,
                  right: (wide ? rightInset : 12) + pad.right,
                  bottom: pad.bottom + 8,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: _actionBar(me, canAct, wide: wide, short: short),
                    ),
                  ),
                ),
              ],

              // 7) Layar Selesai
              if (finished)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.65),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: _finishedCard(),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------ elemen HUD

  Widget _glass({
    required Widget child,
    EdgeInsets padding =
    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _hudStat(IconData icon, String text, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: (color ?? Colors.white).withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color ?? Colors.white70),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _moneyChip(Map<String, dynamic> s) {
    final live = _live(s);
    final out = s['eliminated_at'] != null;
    final trRate = _num(s['trash_rate']);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.payments, size: 22, color: Color(0xFFFFC107)),
        const SizedBox(width: 6),
        Text(live.money.floor().toString(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800)),
        if (!out) ...[
          const SizedBox(width: 6),
          Text(
            '+${_num(s['income_rate']).toStringAsFixed(1)}/s · ${trRate >= 0 ? '+' : ''}${trRate.toStringAsFixed(2)}🗑️',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _hudMeter({
    required IconData icon,
    required String label,
    required String value,
    required double v,
    required double maxV,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label,
                      style:
                      const TextStyle(color: Colors.white70, fontSize: 11)),
                  const Spacer(),
                  Text(value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 3),
              _meter(v, maxV, color, height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hud(bool wide, bool short, Map<String, dynamic>? s) {
    final p = _pollution;
    final pc = _pollutionLevel(p).$2;

    final back = IconButton(
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      visualDensity: VisualDensity.compact,
      tooltip: 'Kembali',
    );
    final history = IconButton(
      onPressed: _showFeed,
      icon: const Icon(Icons.history, color: Colors.white),
      visualDensity: VisualDensity.compact,
      tooltip: 'Kabar terbaru',
    );
    final code = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(widget.roomCode,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w800)),
    );

    Widget? trashMeter;
    Widget? stats;
    if (s != null) {
      final live = _live(s);
      final cap = max(1.0, _num(s['trash_capacity']));
      final ratio = live.trash / cap;
      final tier = _num(s['kost_tier']).toInt().clamp(0, 2);
      final wl = _num(s['waste_level']).toInt().clamp(0, 12);

      trashMeter = _hudMeter(
        icon: Icons.delete,
        label: 'Sampah',
        value: '${live.trash.floor()}/${cap.floor()}',
        v: live.trash,
        maxV: cap,
        color: _trashColor(ratio),
      );
      stats = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _hudStat(Icons.meeting_room,
              '${_num(s['rooms_count']).toInt()}/$_maxRooms'),
          const SizedBox(width: 5),
          _hudStat(Icons.recycling, 'Lv $wl', color: const Color(0xFF81C784)),
          const SizedBox(width: 5),
          _hudStat(Icons.workspace_premium, _tierNames[tier],
              color: const Color(0xFFFFCA28)),
          const SizedBox(width: 5),
          _hudStat(Icons.shield, '${_num(s['defense']).toInt()}/$_maxDefense'),
        ],
      );
    }
    final polMeter = _hudMeter(
      icon: Icons.cloud,
      label: 'Polusi',
      value: '${p.round()}%',
      v: p,
      maxV: 100,
      color: pc,
    );

    if (wide) {
      return _glass(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: short ? 4 : 8),
        child: Row(
          children: [
            back,
            code,
            const SizedBox(width: 12),
            if (s != null) ...[
              _moneyChip(s),
              const SizedBox(width: 12),
              stats!,
              const SizedBox(width: 14),
              Expanded(child: trashMeter!),
              const SizedBox(width: 14),
            ],
            Expanded(child: polMeter),
            const SizedBox(width: 4),
            history,
          ],
        ),
      );
    }

    return _glass(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              back,
              code,
              const SizedBox(width: 8),
              Expanded(
                child: s == null
                    ? const SizedBox.shrink()
                    : FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: _moneyChip(s),
                ),
              ),
              history,
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              children: [
                if (trashMeter != null) ...[
                  Expanded(child: trashMeter),
                  const SizedBox(width: 14),
                ],
                Expanded(child: polMeter),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(IconData icon, String text, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 5),
        Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _statusTags(Map<String, dynamic>? s, bool spectator) {
    final tags = <Widget>[];
    if (spectator) {
      tags.add(_tag(Icons.visibility, 'Mode penonton', Colors.blueGrey));
    }
    final ev = _activeWorldEvent;
    if (ev != null) {
      final info = _worldEventInfo(ev);
      final left = _remaining(_room['world_event_until']).ceil();
      tags.add(_tag(info.$2, '${info.$1} (${left}s)', info.$3));
    }
    if (_remaining(_room['smog_until']) > 0) {
      tags.add(_tag(
        Icons.masks,
        'KABUT ASAP! Bakar diblokir · ${_remaining(_room['smog_until']).ceil()} dtk',
        Colors.red.shade700,
      ));
    }
    if (s != null) {
      final live = _live(s);
      final cap = max(1.0, _num(s['trash_capacity']));
      final ratio = live.trash / cap;
      final out = s['eliminated_at'] != null;
      final sealed = _remaining(s['sealed_until']);
      if (!out && sealed > 0) {
        tags.add(_tag(
          Icons.policy,
          'KOST DISEGEL DINAS · Income -50% (${sealed.ceil()} dtk)',
          Colors.redAccent.shade700,
        ));
      }
      if (!out && ratio >= 0.5) {
        tags.add(_tag(
            Icons.warning_amber_rounded, _trashStage(ratio), _trashColor(ratio)));
      }
      final wl = _num(s['waste_level']).toInt();
      if (!out && (wl == 8 || wl == 9)) {
        tags.add(_tag(
          Icons.factory,
          'Insinerator Berpolusi aktif (+Polusi, rawan disidak lawan!)',
          Colors.brown.shade700,
        ));
      }
      final penalty = _remaining(s['burn_penalty_until']);
      if (!out && penalty > 0) {
        tags.add(_tag(
          Icons.local_fire_department,
          'Penalti bakar x${_num(s['burn_stacks']).toInt()} · ${penalty.ceil()} dtk',
          Colors.deepOrange,
        ));
      }
      final prot = _remaining(s['protected_until']);
      if (!out && prot > 0) {
        tags.add(_tag(Icons.shield, 'Dilindungi ${prot.ceil()} dtk',
            Colors.amber.shade800));
      }
    }
    final p = _pollution;
    if (p >= 30) {
      final (label, color) = _pollutionLevel(p);
      tags.add(_tag(Icons.cloud, label, color));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: tags);
  }

  Widget _stamp() => Transform.rotate(
    angle: -0.12,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red.shade400, width: 3),
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withValues(alpha: 0.5),
      ),
      child: Text('TERTIMBUN',
          style: TextStyle(
              color: Colors.red.shade300,
              fontSize: 26,
              letterSpacing: 3,
              fontWeight: FontWeight.w900)),
    ),
  );

  Widget _eventToast() {
    final recent = sceneNowMs() - _lastEventMs < 6000;
    String text = '';
    IconData icon = Icons.info_outline;
    Color color = Colors.grey;
    if (_events.isNotEmpty) {
      text = _eventText(_events.first);
      final ic = _eventIcon(_events.first['type']);
      icon = ic.$1;
      color = ic.$2;
    }
    return AnimatedOpacity(
      opacity: recent && text.isNotEmpty ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _ink.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Color.lerp(color, Colors.white, 0.4)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeed() {
    final list = _events.where((e) => _eventText(e).isNotEmpty).toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 440),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              const Text('Kabar terbaru',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (list.isEmpty) const Text('Belum ada kejadian.'),
              for (final e in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_eventIcon(e['type']).$1,
                          size: 18, color: _eventIcon(e['type']).$2),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_eventText(e))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _finishedCard() {
    final winner = _room['winner_id'];
    final isWin = winner == _me;
    final text = isWin
        ? 'Selamat! Kost Anda paling tangguh dan bersih dari kepungan sampah!'
        : '${_name(winner)} memenangkan pertandingan. Kost Anda telah tertimbun sampah.';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF16281F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isWin ? const Color(0xFFFFCA28) : Colors.redAccent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: (isWin ? const Color(0xFFFFCA28) : Colors.redAccent)
                .withValues(alpha: 0.2),
            child: Icon(
              isWin ? Icons.emoji_events_rounded : Icons.delete_forever_rounded,
              size: 36,
              color: isWin ? const Color(0xFFFFCA28) : Colors.redAccent,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isWin ? 'JURAGAN TERBAIK!' : 'KOST TERTIMBUN!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFCA28),
                foregroundColor: Colors.black87,
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              onPressed: () =>
                  Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('KEMBALI KE BERANDA'),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- bilah aksi (6 tombol)

  Widget _actionBar(Map<String, dynamic>? s, bool canAct,
      {required bool wide, required bool short}) {
    if (s == null) return const SizedBox.shrink();
    final live = _live(s);
    final rooms = _num(s['rooms_count']).toInt();
    final defense = _num(s['defense']).toInt();
    final wasteLv = _num(s['waste_level']).toInt();
    final tier = _num(s['kost_tier']).toInt();
    final sealed = _remaining(s['sealed_until']) > 0;

    final buildCost = _buildCost(s);
    final nextWasteLv = wasteLv + 1;
    final wasteCost = _wasteCost(nextWasteLv);
    final nextTier = tier + 1;
    final tierCost = nextTier == 1 ? 650 : 1600;
    final tierMinRooms = nextTier == 1 ? 4 : 8;
    final defCost = 150 * (defense + 1);

    final haulLeft = _remaining(s['hauler_busy_until']);
    final burnLeft = _remaining(s['burn_cooldown_until']);
    final smog = _remaining(_room['smog_until']) > 0;
    final strike = _activeWorldEvent == 'hauler_strike';
    final flood = _activeWorldEvent == 'rain_flood';
    final haulMax = 45.0 + wasteLv * 4.0;
    final haulCost = (min(live.trash.floorToDouble(), haulMax) *
        3 *
        (flood ? 1.5 : 1.0))
        .ceil();

    final mode = (short || !wide) ? 2 : 0;

    final buttons = <Widget>[
      // 1. Bangun Kamar
      _ActionButton(
        mode: mode,
        icon: Icons.add_home_work,
        color: Colors.lightBlue,
        title: rooms >= _maxRooms ? 'Kamar Penuh' : 'Bangun Kamar',
        subtitle: sealed
            ? 'Disegel!'
            : (rooms >= _maxRooms ? 'Maks $_maxRooms' : 'Biaya $buildCost'),
        busy: _activeRpc == 'build_room',
        onTap: canAct && !sealed && rooms < _maxRooms && live.money >= buildCost
            ? () => _act('build_room')
            : null,
      ),
      // 2. Bank Sampah & Insinerator (Lv 1..12)
      _ActionButton(
        mode: mode,
        icon: wasteLv >= 7 ? Icons.factory : Icons.recycling,
        color: wasteLv == 7 || wasteLv == 8
            ? Colors.amber
            : Colors.lightGreenAccent.shade700,
        title: wasteLv >= _maxWaste
            ? 'Limbah Maks'
            : _wasteNames[nextWasteLv],
        subtitle: wasteLv >= _maxWaste
            ? 'Lv 12/12 Eco'
            : 'Lv $nextWasteLv · $wasteCost',
        busy: _activeRpc == 'upgrade_waste',
        onTap: canAct && wasteLv < _maxWaste && live.money >= wasteCost
            ? () => _act('upgrade_waste')
            : null,
      ),
      // 3. Upgrade Kelas Kost (Reguler -> Eksklusif -> Sultan)
      _ActionButton(
        mode: mode,
        icon: Icons.workspace_premium,
        color: Colors.amber,
        title: tier >= _maxTier
            ? 'Kost Sultan'
            : 'Kost ${_tierNames[nextTier]}',
        subtitle: tier >= _maxTier
            ? 'Kelas Maks'
            : (rooms < tierMinRooms
            ? 'Butuh $tierMinRooms kmr'
            : 'Biaya $tierCost'),
        busy: _activeRpc == 'upgrade_kost_tier',
        onTap: canAct &&
            tier < _maxTier &&
            rooms >= tierMinRooms &&
            live.money >= tierCost
            ? () => _act('upgrade_kost_tier')
            : null,
      ),
      // 4. Sewa Tukang Sampah
      _ActionButton(
        mode: mode,
        icon: Icons.local_shipping,
        color: Colors.green,
        title: 'Truk Sampah',
        subtitle: strike
            ? 'Mogok kerja!'
            : (haulLeft > 0
            ? 'Angkut ${haulLeft.ceil()}s'
            : 'Biaya ~$haulCost'),
        busy: _activeRpc == 'hire_hauler',
        onTap: canAct &&
            !strike &&
            haulLeft == 0 &&
            live.trash >= 1 &&
            live.money >= haulCost
            ? () => _act('hire_hauler')
            : null,
      ),
      // 5. Bakar Sampah
      _ActionButton(
        mode: mode,
        icon: Icons.local_fire_department,
        color: Colors.deepOrangeAccent,
        title: 'Bakar Sampah',
        subtitle: burnLeft > 0
            ? 'Jeda ${burnLeft.ceil()}s'
            : smog
            ? 'Kabut asap!'
            : (wasteLv >= 10 ? 'Rendah polusi' : 'Polusi naik'),
        busy: _activeRpc == 'burn',
        onTap: canAct && burnLeft == 0 && !smog && live.trash >= 2
            ? () => _act('burn')
            : null,
      ),
      // 6. Pertahanan
      _ActionButton(
        mode: mode,
        icon: Icons.shield,
        color: Colors.tealAccent.shade700,
        title: defense >= _maxDefense ? 'Perisai Maks' : 'Pertahanan',
        subtitle: defense >= _maxDefense
            ? 'Lv $_maxDefense/$_maxDefense'
            : 'Lv ${defense + 1} · $defCost',
        busy: _activeRpc == 'buy_defense',
        onTap: canAct && defense < _maxDefense && live.money >= defCost
            ? () => _act('buy_defense')
            : null,
      ),
    ];

    if (wide) {
      final h = short ? 52.0 : 78.0;
      return _glass(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          height: h,
          child: Row(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: buttons[i]),
              ],
            ],
          ),
        ),
      );
    }

    // Pada layar HP (sempit): susun 2 baris x 3 kolom agar semua 6 tombol nyaman ditekan
    return _glass(
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        height: 112,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: buttons[0]),
                  const SizedBox(width: 6),
                  Expanded(child: buttons[1]),
                  const SizedBox(width: 6),
                  Expanded(child: buttons[2]),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: buttons[3]),
                  const SizedBox(width: 6),
                  Expanded(child: buttons[4]),
                  const SizedBox(width: 6),
                  Expanded(child: buttons[5]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------ lawan & 3 tombol sabotase

  Widget _rivalPanel(
      List<MapEntry<String, Map<String, dynamic>>> rivals,
      bool canAct,
      Map<String, dynamic>? me,
      double w,
      ) {
    final cols = rivals.length > 1 ? 2 : 1;
    const gap = 8.0;
    final cw = (w - gap * (cols - 1)) / cols;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'Kost Lawan (Sabotase)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
          ),
          Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final e in rivals)
                SizedBox(
                  width: cw,
                  child: _rivalCard(e.key, e.value, canAct, me),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rivalCard(
      String id,
      Map<String, dynamic> s,
      bool canAct,
      Map<String, dynamic>? me,
      ) {
    final live = _live(s);
    final cap = max(1.0, _num(s['trash_capacity']));
    final ratio = live.trash / cap;
    final out = s['eliminated_at'] != null;
    final prot = _remaining(s['protected_until']);
    final rivalWl = _num(s['waste_level']).toInt();
    final rivalHauling = _remaining(s['hauler_busy_until']) > 0;
    final rivalViolating = _remaining(s['burn_penalty_until']) > 0 ||
        rivalWl == 8 ||
        rivalWl == 9 ||
        ratio >= 0.70;

    final throwLeft = me == null ? 0.0 : _remaining(me['throw_cooldown_until']);
    final sabLeft =
    me == null ? 0.0 : _remaining(me['sabotage_cooldown_until']);
    final mine = me == null ? null : _live(me);

    final canThrow = canAct &&
        !out &&
        prot == 0 &&
        throwLeft == 0 &&
        mine != null &&
        mine.trash >= 1 &&
        mine.money >= 10;

    final canInspect = canAct &&
        !out &&
        sabLeft == 0 &&
        rivalViolating &&
        mine != null &&
        mine.money >= 120;

    final canHijack = canAct &&
        !out &&
        sabLeft == 0 &&
        rivalHauling &&
        mine != null &&
        mine.money >= 90;

    return Material(
      elevation: 5,
      color: const Color(0xFF1A2820),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: KostStage(
                  data: _sceneData(id, s, compact: true),
                  repaint: _anim,
                ),
              ),
              Positioned(
                left: 6,
                top: 6,
                right: 6,
                child: Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _wallFor(id),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                _name(id),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🏠${_num(s['rooms_count']).toInt()} ♻️$rivalWl',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _meter(live.trash, cap, _trashColor(ratio), height: 5),
              ),
              if (out)
                Positioned.fill(
                  child: Center(
                    child: Text('TERTIMBUN',
                        style: TextStyle(
                            color: Colors.red.shade300,
                            fontSize: 12,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w900,
                            shadows: const [
                              Shadow(blurRadius: 4, color: Colors.black)
                            ])),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
            child: Row(
              children: [
                // 1) Lempar Sampah
                Expanded(
                  child: _sabotageBtn(
                    icon: Icons.rocket_launch_rounded,
                    label: throwLeft > 0 ? '${throwLeft.ceil()}s' : '10',
                    tooltip: 'Lempar Sampah (Biaya 10)',
                    color: const Color(0xFFFF7043),
                    enabled: canThrow,
                    onTap: () => _act('throw_trash', {'p_target': id}),
                  ),
                ),
                const SizedBox(width: 4),
                // 2) Sidak RT / Dinas
                Expanded(
                  child: _sabotageBtn(
                    icon: Icons.policy_rounded,
                    label: sabLeft > 0 ? '${sabLeft.ceil()}s' : '120',
                    tooltip:
                    'Kirim Sidak Dinas (Biaya 120 · Aktif bila lawan habis bakar sampah / pakai Insinerator Polusi / sampah >70%)',
                    color: const Color(0xFFE53935),
                    enabled: canInspect,
                    onTap: () => _act('sabotage_inspect', {'p_target': id}),
                  ),
                ),
                const SizedBox(width: 4),
                // 3) Bajak Truk Sampah
                Expanded(
                  child: _sabotageBtn(
                    icon: Icons.u_turn_left_rounded,
                    label: sabLeft > 0 ? '${sabLeft.ceil()}s' : '90',
                    tooltip:
                    'Bajak Truk Sampah Lawan (Biaya 90 · Aktif saat truk lawan sedang mengangkut)',
                    color: const Color(0xFFFFB300),
                    enabled: canHijack,
                    onTap: () => _act('sabotage_hijack', {'p_target': id}),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sabotageBtn({
    required IconData icon,
    required String label,
    required String tooltip,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: 28,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor:
            enabled ? color : Colors.white.withValues(alpha: 0.08),
            foregroundColor: enabled ? Colors.white : Colors.white38,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: enabled ? onTap : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.mode,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.busy = false,
  });

  final int mode;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || busy;
    final c = enabled ? color : Colors.blueGrey;
    final avatarR = mode == 0 ? 15.0 : 12.5;
    final titleSize = mode == 0 ? 12.0 : 11.0;
    final subSize = mode == 0 ? 10.5 : 9.5;

    final avatar = CircleAvatar(
      radius: avatarR,
      backgroundColor: c,
      child: busy
          ? SizedBox(
        width: avatarR,
        height: avatarR,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      )
          : Icon(icon, size: avatarR + 2, color: Colors.white),
    );
    final texts = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
      mode == 2 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(title,
              maxLines: 1,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800)),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(subtitle,
              maxLines: 1,
              style: TextStyle(color: Colors.white70, fontSize: subSize)),
        ),
      ],
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: c.withValues(alpha: 0.22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(color: c.withValues(alpha: 0.55)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: mode == 2 ? 7 : 4, vertical: mode == 2 ? 3 : 5),
            child: mode == 2
                ? Row(
              children: [
                avatar,
                const SizedBox(width: 6),
                Expanded(child: texts),
              ],
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                avatar,
                const SizedBox(height: 4),
                texts,
              ],
            ),
          ),
        ),
      ),
    );
  }
}