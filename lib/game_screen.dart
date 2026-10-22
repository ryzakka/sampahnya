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
  static const _ink = Color(0xFF14201A); // warna kaca gelap HUD

  SupabaseClient get _db => Supabase.instance.client;
  String get _me => _db.auth.currentUser?.id ?? '';

  Map<String, dynamic> _room = {};
  final Map<String, Map<String, dynamic>> _states = {};
  final Map<String, String> _names = {};
  final List<Map<String, dynamic>> _events = [];

  // efek visual per pemain (dipicu event realtime) & durasi truk
  final Map<String, List<KostFx>> _fx = {};
  final Map<String, double> _haulTotal = {};
  int _lastEventMs = -100000;

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
          _lastEventMs = sceneNowMs();
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
          backgroundColor: color.withValues(alpha: 0.18),
        ),
      );

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: Text('Ruangan ${widget.roomCode}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final me = _states[_me];
    final finished = _room['status'] == 'finished';
    final alive = me != null && me['eliminated_at'] == null;
    final canAct = alive && !finished && !_busy;
    final others = _states.entries.where((e) => e.key != _me).toList()
      ..sort((a, b) => _name(a.key).compareTo(_name(b.key)));

    // penonton: lawan pertama dijadikan sorotan utama
    final String? mainId =
    me != null ? _me : (others.isNotEmpty ? others.first.key : null);
    final mainState = mainId == null ? null : _states[mainId];
    final rivals = me != null ? others : others.skip(1).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A22),
      body: LayoutBuilder(
        builder: (context, c) {
          final pad = MediaQuery.of(context).padding;
          final short = c.maxHeight < 520;
          final wide = c.maxWidth >= 760 && c.maxWidth >= c.maxHeight * 1.1;

          final hudH = wide ? (short ? 50.0 : 62.0) : 100.0;
          final barH = wide ? (short ? 60.0 : 100.0) : 84.0;
          final rightW = rivals.length > 1
              ? (c.maxWidth * 0.3).clamp(270.0, 380.0).toDouble()
              : (c.maxWidth * 0.22).clamp(210.0, 270.0).toDouble();
          final stripH = (!wide && rivals.isNotEmpty) ? 146.0 : 0.0;
          final hasBar = me != null;

          final topInset =
              pad.top + 8 + hudH + 8 + (stripH > 0 ? stripH + 8 : 0);
          final bottomInset = (hasBar ? barH + 8 : 0.0) + pad.bottom + 8;
          final rightInset = (wide && rivals.isNotEmpty) ? rightW + 24 : 0.0;

          final out = mainState != null && mainState['eliminated_at'] != null;

          return Stack(
            children: [
              // 1) adegan memenuhi layar
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

              // 2) stempel tertimbun
              if (out)
                Positioned(
                  left: 0,
                  right: rightInset,
                  top: topInset,
                  bottom: bottomInset,
                  child: IgnorePointer(child: Center(child: _stamp())),
                ),

              // 3) HUD
              Positioned(
                top: pad.top + 8,
                left: 12 + pad.left,
                right: 12 + pad.right,
                child: _hud(wide, short, mainState),
              ),

              // 4) status / peringatan
              Positioned(
                left: 12 + pad.left,
                top: topInset,
                child: IgnorePointer(
                  child: _statusTags(mainState, me == null),
                ),
              ),

              // 5) lawan: kisi kecil di kanan (lebar) / strip atas (sempit)
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
                        width: 128,
                        child: _rivalCard(
                            rivals[i].key, rivals[i].value, canAct, me),
                      ),
                    ),
                  ),
                ),

              // 6) kabar singkat + bilah aksi
              if (hasBar) ...[
                Positioned(
                  left: 12 + pad.left,
                  right: (wide ? rightInset : 12) + pad.right,
                  bottom: bottomInset - 4,
                  child: IgnorePointer(child: Center(child: _eventToast())),
                ),
                Positioned(
                  left: 12 + pad.left,
                  right: (wide ? rightInset : 12) + pad.right,
                  bottom: pad.bottom + 8,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: _actionBar(me, canAct,
                          wide: wide, short: short),
                    ),
                  ),
                ),
              ],

              // 7) permainan selesai
              if (finished)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
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
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }

  Widget _hudStat(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _moneyChip(Map<String, dynamic> s) {
    final live = _live(s);
    final out = s['eliminated_at'] != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.payments, size: 22, color: Color(0xFFFFC107)),
        const SizedBox(width: 6),
        Text(live.money.floor().toString(),
            style: const TextStyle(
                color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
        if (!out) ...[
          const SizedBox(width: 6),
          Text('+${_num(s['income_rate']).toStringAsFixed(1)}/dtk',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
          const SizedBox(width: 6),
          _hudStat(Icons.shield,
              '${_num(s['defense']).toInt()}/$_maxDefense'),
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
            const SizedBox(width: 14),
            if (s != null) ...[
              _moneyChip(s),
              const SizedBox(width: 14),
              stats!,
              const SizedBox(width: 18),
              Expanded(child: trashMeter!),
              const SizedBox(width: 18),
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
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _statusTags(Map<String, dynamic>? s, bool spectator) {
    final tags = <Widget>[];
    if (spectator) {
      tags.add(_tag(Icons.visibility, 'Mode penonton', Colors.blueGrey));
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
      if (!out && ratio >= 0.5) {
        tags.add(_tag(Icons.warning_amber_rounded, _trashStage(ratio),
            _trashColor(ratio)));
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
          color: _ink.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(20),
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
                  style: const TextStyle(color: Colors.white, fontSize: 12.5)),
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
    final text = winner == _me
        ? 'Anda menang! Kost Anda paling bertahan.'
        : '${_name(winner)} menang. Kost Anda kalah tertimbun sampah.';
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(winner == _me ? Icons.emoji_events : Icons.delete_forever,
                    size: 28),
                const SizedBox(width: 10),
                const Text('Permainan selesai',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            Text(text),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Kembali ke beranda'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------- bilah aksi

  Widget _actionBar(Map<String, dynamic>? s, bool canAct,
      {required bool wide, required bool short}) {
    if (s == null) return const SizedBox.shrink();
    final live = _live(s);
    final rooms = _num(s['rooms_count']).toInt();
    final defense = _num(s['defense']).toInt();
    final cost = _buildCost(s);
    final defCost = 150 * (defense + 1);
    final haulLeft = _remaining(s['hauler_busy_until']);
    final burnLeft = _remaining(s['burn_cooldown_until']);
    final smog = _remaining(_room['smog_until']) > 0;
    final haulCost = (min(live.trash.floorToDouble(), 40.0) * 3).ceil();

    final mode = short && wide ? 2 : (wide ? 0 : 1);

    final buttons = <Widget>[
      _ActionButton(
        mode: mode,
        icon: Icons.add_home_work,
        color: Colors.lightBlue,
        title: rooms >= _maxRooms ? 'Kamar penuh' : 'Bangun kamar',
        subtitle: rooms >= _maxRooms ? 'Maksimal $_maxRooms' : 'Biaya $cost',
        onTap: canAct && rooms < _maxRooms && live.money >= cost
            ? () => _act('build_room')
            : null,
      ),
      _ActionButton(
        mode: mode,
        icon: Icons.local_shipping,
        color: Colors.lightGreen,
        title: 'Tukang sampah',
        subtitle: haulLeft > 0 ? 'Mengangkut ${haulLeft.ceil()}s' : '~$haulCost',
        onTap: canAct &&
            haulLeft == 0 &&
            live.trash >= 1 &&
            live.money >= haulCost
            ? () => _act('hire_hauler')
            : null,
      ),
      _ActionButton(
        mode: mode,
        icon: Icons.local_fire_department,
        color: Colors.deepOrangeAccent,
        title: 'Bakar sampah',
        subtitle: burnLeft > 0
            ? 'Jeda ${burnLeft.ceil()}s'
            : smog
            ? 'Terblokir kabut'
            : 'Polusi naik',
        onTap: canAct && burnLeft == 0 && !smog && live.trash >= 2
            ? () => _act('burn')
            : null,
      ),
      _ActionButton(
        mode: mode,
        icon: Icons.shield,
        color: Colors.tealAccent,
        title: defense >= _maxDefense ? 'Pertahanan maks' : 'Pertahanan',
        subtitle: defense >= _maxDefense
            ? 'Level $_maxDefense/$_maxDefense'
            : 'Lv ${defense + 1} · $defCost',
        onTap: canAct && defense < _maxDefense && live.money >= defCost
            ? () => _act('buy_defense')
            : null,
      ),
    ];

    final h = mode == 0 ? 84.0 : (mode == 1 ? 68.0 : 44.0);
    return _glass(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        height: h,
        child: Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: buttons[i]),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------ lawan (kisi kecil)

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
              'Kost lawan',
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
    final throwLeft = me == null ? 0.0 : _remaining(me['throw_cooldown_until']);
    final mine = me == null ? null : _live(me);
    final enabled = canAct &&
        !out &&
        prot == 0 &&
        throwLeft == 0 &&
        mine != null &&
        mine.trash >= 1 &&
        mine.money >= 10;

    String? btnText;
    if (out) {
      btnText = 'Out';
    } else if (prot > 0) {
      btnText = '${prot.ceil()}s';
    } else if (throwLeft > 0) {
      btnText = '${throwLeft.ceil()}s';
    }

    return Material(
      elevation: 5,
      color: Theme.of(context).colorScheme.surface,
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
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
            padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
            child: Row(
              children: [
                const Icon(Icons.meeting_room, size: 14),
                const SizedBox(width: 3),
                Text('${_num(s['rooms_count']).toInt()}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                const Icon(Icons.shield, size: 14),
                const SizedBox(width: 3),
                Text('${_num(s['defense']).toInt()}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                const Spacer(),
                Tooltip(
                  message: 'Buang sampah ke ${_name(id)} (10)',
                  child: SizedBox(
                    width: 36,
                    height: 30,
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                      ),
                      onPressed: enabled
                          ? () => _act('throw_trash', {'p_target': id})
                          : null,
                      child: btnText == null
                          ? const Icon(Icons.delete_sweep, size: 18)
                          : Text(btnText,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol aksi di bilah bawah.
/// mode 0 = besar, 1 = sedang (HP), 2 = padat (layar pendek).
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.mode,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final int mode;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final c = enabled ? color : Colors.blueGrey;
    final avatarR = mode == 0 ? 16.0 : (mode == 1 ? 13.0 : 14.0);
    final titleSize = mode == 0 ? 13.0 : 11.5;
    final subSize = mode == 0 ? 11.0 : 9.5;

    final avatar = CircleAvatar(
      radius: avatarR,
      backgroundColor: c,
      child: Icon(icon, size: avatarR + 2, color: Colors.white),
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

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: c.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: c.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: mode == 2 ? 8 : 4, vertical: mode == 2 ? 4 : 6),
            child: mode == 2
                ? Row(
              children: [
                avatar,
                const SizedBox(width: 8),
                Expanded(child: texts),
              ],
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                avatar,
                SizedBox(height: mode == 0 ? 5 : 3),
                texts,
              ],
            ),
          ),
        ),
      ),
    );
  }
}