import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'game_icons.dart';
import 'kost_scene.dart';
import 'kost_style.dart';

/// Ruang kustomisasi BERSAMA. Semua pemain yang masuk ke sini (atau menonton
/// dari lobi) melihat hasil pilihan pemain lain secara langsung:
///  - tab "Bangunan": jalan berisi rumah semua pemain,
///  - tab "Karakter": ruang kostum berisi karakter semua pemain.
class CustomizeScreen extends StatefulWidget {
  const CustomizeScreen({
    super.key,
    required this.roomId,
    required this.roomCode,
    this.readOnly = false,
  });

  final String roomId;
  final String roomCode;

  /// true = hanya menonton (pemain yang memilih tampilan bawaan).
  final bool readOnly;

  @override
  State<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _Entry {
  const _Entry({
    required this.id,
    required this.name,
    required this.status,
    required this.style,
    required this.isMe,
  });

  final String id;
  final String name;
  final String status; // pending | default | editing | done
  final KostStyle style;
  final bool isMe;
}

class _CustomizeScreenState extends State<CustomizeScreen>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF0A140F);
  static const _surface = Color(0xFF12221A);
  static const _amber = Color(0xFFFFCA28);
  static const _greenSoft = Color(0xFF81C784);

  static const _tierNames = ['Standar', 'Eksklusif', 'Sultan'];

  late final AnimationController _anim;
  final KostStreetCamera _cam = KostStreetCamera();
  final TextEditingController _nameCtl = TextEditingController();
  final math.Random _rnd = math.Random();

  /// Pemilik kost tiap rumah, supaya pratinjau bangunan menampilkan
  /// karakter yang sedang beraktivitas di halaman.
  final Map<String, KostOwner> _owners = {};

  KostOwner _ownerFor(_Entry e) {
    final o = _owners.putIfAbsent(e.id, () => KostOwner(seed: kostSeedFor(e.id)));
    o.look = kostLookFor(e.id, e.style);
    return o;
  }

  SupabaseClient get _db => Supabase.instance.client;
  String? get _myId => _db.auth.currentUser?.id;

  List<Map<String, dynamic>> _players = [];
  KostStyle _draft = KostStyle.empty;
  bool _draftReady = false;
  bool _loading = true;
  bool _leaving = false;
  String? _error;
  int _tab = 0; // 0 bangunan, 1 karakter
  bool _compact = false; // layar sempit/pendek: kontrol dirapatkan
  int _previewTier = 0;

  // ruang kostum
  String? _focusId; // pemain yang sedang disorot di panggung
  KostPose _pose = KostPose.wave;
  bool _faceRight = true;
  int _charCat = 0; // kategori kustomisasi karakter

  // bangunan
  int _bldCat = 0; // kategori kustomisasi bangunan
  bool _night = false;
  double _phase = 0.5; // fase siang-malam yang dihaluskan (0.5 siang, 1.0 malam)
  double _phaseTarget = 0.5;
  int _phaseMs = sceneNowMs();
  int _sparkMs = -100000; // waktu kilau terakhir saat bangunan diubah

  void _stepPhase() {
    final now = sceneNowMs();
    final dt = math.min(0.1, math.max(0, now - _phaseMs) / 1000.0);
    _phaseMs = now;
    _phase += (_phaseTarget - _phase) * (1 - math.exp(-dt * 1.6));
  }

  RealtimeChannel? _channel;
  Timer? _saveTimer;
  Timer? _beat;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    _anim.addListener(() {
      _cam.step();
      _stepPhase();
    });
    _channel = _db
        .channel('customize-${widget.roomId}')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'room_players',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: widget.roomId,
      ),
      callback: (_) => _refresh(),
    )
        .subscribe();
    _boot();
  }

  Future<void> _boot() async {
    await _refresh();
    if (widget.readOnly || !mounted) return;
    await _setStatus('editing');
    // Denyut: server menganggap 'editing' yang diam > 60 dtk sebagai pemain
    // yang sudah pergi, supaya host tidak tertahan selamanya.
    _beat = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_leaving) _setStatus('editing');
    });
  }

  Future<void> _refresh() async {
    try {
      final data = await _db
          .from('room_players')
          .select('player_id, player_name, is_ready, style, style_status')
          .eq('room_id', widget.roomId);
      if (!mounted) return;
      setState(() {
        _players = List<Map<String, dynamic>>.from(data);
        if (!_draftReady) {
          final me = _players.where((p) => p['player_id'] == _myId).firstOrNull;
          _draft = KostStyle.fromJson(me?['style']) ?? KostStyle.empty;
          _nameCtl.text = _draft.name;
          _draftReady = true;
        }
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

  Future<void> _setStatus(String status) async {
    try {
      await _db.rpc('set_style_status',
          params: {'p_room': widget.roomId, 'p_status': status});
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  List<_Entry> get _entries {
    final list = [..._players]..sort((a, b) =>
        a['player_id'].toString().compareTo(b['player_id'].toString()));
    return [
      for (final p in list)
            () {
          final id = p['player_id'].toString();
          final mine = id == _myId && !widget.readOnly;
          return _Entry(
            id: id,
            name: (p['player_name'] ?? 'Pemain').toString(),
            // milik sendiri: draf lokal selalu yang terbaru
            status: mine ? 'editing' : (p['style_status'] ?? 'pending').toString(),
            style: mine
                ? _draft
                : (KostStyle.fromJson(p['style']) ?? KostStyle.empty),
            isMe: id == _myId,
          );
        }(),
    ];
  }

  // ------------------------------------------------------------ edit & simpan

  void _edit(KostStyle Function(KostStyle) f) {
    if (widget.readOnly) return;
    setState(() {
      _draft = f(_draft);
      if (_tab == 0) _sparkMs = sceneNowMs();
    });
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), _push);
  }

  Future<void> _push() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    try {
      await _db.rpc('set_player_style',
          params: {'p_room': widget.roomId, 'p_style': _draft.toJson()});
      if (mounted && _error != null) setState(() => _error = null);
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _finish() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    _saveTimer?.cancel();
    _beat?.cancel();
    if (!widget.readOnly) {
      await _push();
      await _setStatus(_draft.isEmpty ? 'default' : 'done');
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _beat?.cancel();
    _anim.dispose();
    _nameCtl.dispose();
    if (_channel != null) _db.removeChannel(_channel!);
    super.dispose();
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 860 ||
                  (c.maxWidth > c.maxHeight && c.maxWidth >= 640);
              final shortH = c.maxHeight < 520;
              // Layar pendek tapi cukup lebar (lanskap ponsel): tab pindah ke
              // bilah atas agar area kerja tidak habis oleh header.
              final inlineTabs = shortH && c.maxWidth >= 560;
              _compact = !wide || shortH;

              final view = _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_tab == 0 ? _streetView(entries) : _stageView(entries));
              final panel =
              widget.readOnly ? _watchPanel(entries) : _editPanel();

              // Skala jarak & lebar mengikuti ukuran layar; konten dikunci
              // lebarnya supaya tidak melebar di monitor besar.
              final t = ((c.maxWidth - 320) / (1100 - 320)).clamp(0.0, 1.0);
              final pad = 12 + 8 * t;
              final panelW = 320 + 80 * t; // 320..400
              final maxW = wide ? 1200.0 : 560.0;

              Widget body;
              if (wide) {
                body = Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: view),
                    const SizedBox(width: 16),
                    SizedBox(width: panelW, child: panel),
                  ],
                );
              } else {
                // Satu kolom: pratinjau ~40% tinggi, panel mengisi sisanya.
                // Bila sisa terlalu kecil (ponsel pendek / keyboard muncul),
                // seluruh halaman digulir dengan tinggi yang tetap nyaman.
                body = LayoutBuilder(
                  builder: (context, bc) {
                    final h = bc.maxHeight;
                    final viewH = (h * 0.40).clamp(200.0, 360.0).toDouble();
                    final panelH = h - viewH - 10;
                    if (panelH < 300) {
                      return SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: 240, child: view),
                            const SizedBox(height: 10),
                            SizedBox(height: 420, child: panel),
                          ],
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: viewH, child: view),
                        const SizedBox(height: 10),
                        Expanded(child: panel),
                      ],
                    );
                  },
                );
              }

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, 10, pad, pad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _topBar(
                          entries,
                          small: c.maxWidth < 400,
                          tabs: inlineTabs ? _tabs(dense: true) : null,
                        ),
                        if (!inlineTabs) ...[
                          const SizedBox(height: 10),
                          _tabs(),
                        ],
                        const SizedBox(height: 10),
                        Expanded(child: body),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _topBar(List<_Entry> entries, {required bool small, Widget? tabs}) {
    final editing = entries.where((e) => e.status == 'editing').length;
    final title = editing > 0
        ? (small ? '$editing pemain mengedit' : '$editing pemain sedang berkustomisasi')
        : (small ? 'Semua sudah selesai' : 'Semua pemain sudah selesai');
    return Row(
      children: [
        GameIconButton(
          asset: GIcon.back,
          tip: widget.readOnly ? 'Kembali' : 'Selesai & kembali',
          size: 42,
          onTap: _leaving ? null : _finish,
        ),
        SizedBox(width: small ? 8 : 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message: title,
              triggerMode: TooltipTriggerMode.longPress,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GameIcon(
                    widget.readOnly ? GIcon.ghost : GIcon.customization,
                    size: small ? 34 : 40,
                  ),
                  const SizedBox(width: 10),
                  if (editing > 0) ...[
                    const GameIcon(GIcon.player, size: 24),
                    const SizedBox(width: 4),
                    Text(
                      '$editing',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: small ? 15.5 : 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ] else
                    GameIcon(GIcon.alreadyOrSip, size: small ? 28 : 32),
                ],
              ),
            ),
          ),
        ),
        if (tabs != null) ...[
          const SizedBox(width: 10),
          tabs,
        ],
        const SizedBox(width: 10),
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: small ? 10 : 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.roomCode,
            style: TextStyle(
              color: _amber,
              fontWeight: FontWeight.w900,
              fontSize: small ? 13 : 14,
              letterSpacing: small ? 1 : 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabs({bool dense = false}) {
    Widget chip(int i, String asset, String tip) => GameIconButton(
      asset: asset,
      tip: tip,
      size: dense ? 42 : 46,
      selected: _tab == i,
      onTap: () => setState(() => _tab = i),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        chip(0, GIcon.home, 'Bangunan'),
        const SizedBox(width: 8),
        chip(1, GIcon.character, 'Karakter'),
      ],
    );
  }

  // ------------------------------------------------------------ tampilan

  (IconData, String, Color) _statusInfo(String s) {
    switch (s) {
      case 'editing':
        return (Icons.brush_rounded, 'Mengedit…', _amber);
      case 'done':
        return (Icons.check_circle_rounded, 'Selesai', _greenSoft);
      default:
        return (Icons.home_rounded, 'Bawaan', Colors.white60);
    }
  }

  String _statusAsset(String s) => switch (s) {
    'editing' => GIcon.customization,
    'done' => GIcon.alreadyOrSip,
    _ => GIcon.home,
  };

  Widget _tag(_Entry e) {
    final (_, label, _) = _statusInfo(e.status);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: e.isMe
              ? _amber.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.18),
          width: e.isMe ? 1.8 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              KostHeadIcon(
                look: kostLookFor(e.id, e.style),
                size: 18,
                ring: e.isMe ? _amber : null,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  '${e.name}${e.isMe ? ' (Anda)' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: e.isMe ? _amber : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Tooltip(
            message: label,
            child: GameIcon(_statusAsset(e.status), size: 22),
          ),
        ],
      ),
    );
  }

  KostSceneData _house(_Entry e, int i) => KostSceneData(
    rooms: 4,
    maxRooms: 12,
    defense: 0,
    wasteLevel: 0,
    kostTier: _previewTier,
    trashRatio: 0,
    pollution: 4,
    wall: e.style.wallColor ??
        KostPalette.walls[i % 4], // sama dengan warna bawaan di game
    seed: kostSeedFor(e.id),
    lights: 1.0,
    style: e.style.isEmpty ? null : e.style,
    owner: _ownerFor(e),
    dayPhase: _phase,
  );

  Widget _streetView(List<_Entry> list) {
    final n = list.length;
    if (n == 0) {
      return const Center(
        child: Text('Menunggu pemain…', style: TextStyle(color: Colors.white70)),
      );
    }
    final hero = _hero(list);
    final hi = math.max(0, list.indexWhere((e) => e.id == hero.id));
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.16), width: 1.5),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final size = Size(c.maxWidth, c.maxHeight);
            const insets = EdgeInsets.only(top: 58);
            final stage = _cam.stageFor(size, insets);
            // kamera menyorot satu rumah; tetangga tampak di tepi layar
            final fit = math.min(
              stage.width * 0.94 / (kStreetSlotW * 1.15),
              stage.height / kStreetSlotH,
            );
            _cam.setTarget((hi + 0.5) * kStreetSlotW, math.min(fit, 1.5));
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) {
                      final i = _cam.houseAt(d.localPosition.dx, stage, n);
                      if (i != null) setState(() => _focusId = list[i].id);
                    },
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v.abs() < 200) return;
                      final ni = math.min(n - 1, math.max(0, hi + (v < 0 ? 1 : -1)));
                      setState(() => _focusId = list[ni].id);
                    },
                    child: AnimatedBuilder(
                      animation: _anim,
                      builder: (context, _) => KostStreet(
                        houses: [
                          for (var i = 0; i < n; i++) _house(list[i], i),
                        ],
                        backdrop: KostSceneData(
                          rooms: 0,
                          maxRooms: 12,
                          defense: 0,
                          trashRatio: 0,
                          pollution: 4,
                          dayPhase: _phase,
                        ),
                        camera: _cam,
                        repaint: _anim,
                        ids: [for (final e in list) e.id],
                        insets: insets,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _anim,
                      builder: (context, _) => CustomPaint(
                        painter: _SparkPainter(
                          cam: _cam,
                          stage: stage,
                          index: hi,
                          startMs: _sparkMs,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  top: 8,
                  child: _roster(list, selected: hero.id),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: _miniBtn(
                    _night ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    _night ? 'Malam' : 'Siang',
                    _night,
                        () => setState(() {
                      _night = !_night;
                      _phaseTarget = _night ? 1.0 : 0.5;
                    }),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static const List<(KostPose, IconData, String)> _poses = [
    (KostPose.stand, Icons.accessibility_new_rounded, 'Santai'),
    (KostPose.wave, Icons.waving_hand_rounded, 'Lambai'),
    (KostPose.cheer, Icons.celebration_rounded, 'Senang'),
    (KostPose.proud, Icons.emoji_events_rounded, 'Bangga'),
  ];

  _Entry _hero(List<_Entry> list) {
    final f = list.where((e) => e.id == _focusId).firstOrNull;
    if (f != null) return f;
    final me = list.where((e) => e.isMe).firstOrNull;
    return me ?? list.first;
  }

  Widget _stageView(List<_Entry> list) {
    final n = list.length;
    if (n == 0) {
      return const Center(
        child: Text('Menunggu pemain…', style: TextStyle(color: Colors.white70)),
      );
    }
    final hero = _hero(list);
    final heroLook = kostLookFor(hero.id, hero.style);
    final showRoster = n > 1;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.16), width: 1.5),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final tight = c.maxWidth < 440;
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                      painter: _StagePainter(_anim, heroLook.shirt)),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, showRoster ? 62 : 22, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: CustomPaint(
                            painter: _AvatarPainter(
                              look: heroLook,
                              anim: _anim,
                              pose: _pose,
                              phase: 0,
                              faceRight: _faceRight,
                              highlight: hero.isMe,
                              accent: heroLook.shirt,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _heroBar(hero, tight: tight),
                      ],
                    ),
                  ),
                ),
                // Pemilih pemain di atas (sama seperti tampilan jalan).
                if (showRoster)
                  Positioned(
                    left: 10,
                    right: 10,
                    top: 8,
                    child: _roster(list, selected: hero.id),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _miniBtn(IconData icon, String tip, bool on, VoidCallback onTap,
      {double size = 34}) =>
      Tooltip(
        message: tip,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? _amber : Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                color: on ? _amber : Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(icon,
                size: size * 0.53, color: on ? Colors.black87 : Colors.white70),
          ),
        ),
      );

  Widget _heroBar(_Entry e, {bool tight = false}) {
    final (_, label, _) = _statusInfo(e.status);
    final bs = tight ? 30.0 : 34.0;
    final gap = tight ? 4.0 : 6.0;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.fromLTRB(tight ? 6 : 8, 6, tight ? 8 : 12, 6),
            decoration: BoxDecoration(
              color: _surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: e.isMe
                    ? _amber.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.18),
                width: e.isMe ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                KostHeadIcon(
                  look: kostLookFor(e.id, e.style),
                  size: tight ? 26 : 30,
                  ring: e.isMe ? _amber : null,
                ),
                SizedBox(width: tight ? 6 : 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e.name}${e.isMe ? ' (Anda)' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: e.isMe ? _amber : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Tooltip(
                        message: label,
                        child: GameIcon(_statusAsset(e.status), size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: tight ? 6 : 8),
        _miniBtn(Icons.flip_rounded, 'Balik arah', false,
                () => setState(() => _faceRight = !_faceRight),
            size: bs),
        for (final (pose, pIcon, pLabel) in _poses) ...[
          SizedBox(width: gap),
          _miniBtn(pIcon, pLabel, _pose == pose,
                  () => setState(() => _pose = pose),
              size: bs),
        ],
      ],
    );
  }

  /// Pemain lain di ruang kostum: ketuk untuk menyorot karakternya.
  Widget _roster(List<_Entry> others, {String? selected}) => SizedBox(
    height: 46,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: others.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        final e = others[i];
        final st = _statusInfo(e.status);
        return GestureDetector(
          onTap: () => setState(() => _focusId = e.id),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
            decoration: BoxDecoration(
              color: selected == e.id
                  ? _amber.withValues(alpha: 0.2)
                  : _surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected == e.id
                    ? _amber
                    : (e.isMe
                    ? _amber.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.14)),
                width: selected == e.id ? 1.8 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                KostHeadIcon(
                  look: kostLookFor(e.id, e.style),
                  size: 30,
                  ring: e.isMe ? _amber : null,
                ),
                const SizedBox(width: 7),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.isMe ? '${e.name} (Anda)' : e.name,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Tooltip(
                      message: st.$2,
                      child: GameIcon(_statusAsset(e.status), size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  // ------------------------------------------------------------- panel

  Widget _panelShell({required Widget body, required Widget footer}) {
    return Container(
      padding: EdgeInsets.all(_compact ? 10 : 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: body),
          const SizedBox(height: 10),
          footer,
        ],
      ),
    );
  }

  Widget _doneButton(String label) => GameIconButton(
    asset: GIcon.accept,
    tip: _leaving ? 'Menyimpan…' : label,
    size: 56,
    ring: _greenSoft,
    busy: _leaving,
    onTap: _leaving ? null : _finish,
  );

  Widget _editPanel() {
    final chars = _tab == 1;

    void randomize() => _edit((s) =>
    _tab == 0 ? s.randomBuilding(_rnd) : s.randomCharacter(_rnd));
    void reset() {
      _edit((s) => _tab == 0 ? s.clearBuilding() : s.clearCharacter());
      if (_tab == 0) _nameCtl.clear();
    }

    Widget iconAction(String asset, String tip, VoidCallback onTap) =>
        GameIconButton(asset: asset, tip: tip, size: 48, onTap: onTap);

    final footer = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        iconAction(GIcon.random, 'Acak', randomize),
        iconAction(GIcon.cancel, 'Kembali ke bawaan', reset),
        _doneButton('Selesai kustomisasi'),
      ],
    );

    return _panelShell(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          _catBar(
            chars ? _charCats : _bldCats,
            chars ? _charCat : _bldCat,
                (i) => setState(() {
              if (chars) {
                _charCat = i;
              } else {
                _bldCat = i;
              }
            }),
          ),
          SizedBox(height: _compact ? 10 : 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [chars ? _charContent() : _bldContent()],
              ),
            ),
          ),
        ],
      ),
      footer: footer,
    );
  }

  ButtonStyle get _outlined => OutlinedButton.styleFrom(
    foregroundColor: Colors.white,
    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );

  Widget _watchPanel(List<_Entry> entries) {
    return _panelShell(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: GameIcon(GIcon.player, size: 28),
            ),
            const SizedBox(height: 8),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Tooltip(
                      message: _statusInfo(e.status).$2,
                      child: GameIcon(_statusAsset(e.status), size: 28),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${e.name}${e.isMe ? ' (Anda)' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      footer: Center(child: _doneButton('Kembali ke lobi')),
    );
  }

  // ------------------------------------------------------------ kontrol

  static const TextStyle _labelStyle = TextStyle(
    color: Colors.white70,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
  );

  Widget _section(String title, Widget child, {String? value}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: _labelStyle),
            if (value != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );

  Widget _swatches(
      List<Color> colors,
      int? selected,
      void Function(int) pick, {
        List<String>? names,
      }) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < colors.length; i++)
          Tooltip(
            message: names != null && i < names.length ? names[i] : '',
            child: GestureDetector(
              onTap: () => pick(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected == i ? _amber : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                      width: 1.2,
                    ),
                    boxShadow: selected == i
                        ? [
                      BoxShadow(
                        color: colors[i].withValues(alpha: 0.55),
                        blurRadius: 8,
                      ),
                    ]
                        : null,
                  ),
                  child: selected == i
                      ? Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: colors[i].computeLuminance() > 0.5
                        ? Colors.black87
                        : Colors.white,
                  )
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Kisi pilihan bergambar: tiap kotak menampilkan pratinjau kepala
  /// dengan opsi tersebut, jadi tidak perlu menebak dari nama.
  Widget _tileGrid({
    required List<String> labels,
    required int selected,
    required KostLook Function(int) lookOf,
    required void Function(int) pick,
    bool body = false,
  }) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 8.0;
        final cols = ((c.maxWidth + gap) / (92 + gap)).floor().clamp(2, 5);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < labels.length; i++)
              GestureDetector(
                onTap: () => pick(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: w,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selected == i
                        ? _amber.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected == i
                          ? _amber
                          : Colors.white.withValues(alpha: 0.1),
                      width: selected == i ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      body
                          ? KostBodyIcon(look: lookOf(i), size: 58)
                          : KostHeadIcon(look: lookOf(i), size: 46),
                      const SizedBox(height: 5),
                      Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected == i ? _amber : Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _choices(List<String> labels, int selected, void Function(int) pick) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (var i = 0; i < labels.length; i++)
          ChoiceChip(
            label: Text(labels[i]),
            selected: selected == i,
            onSelected: (_) => pick(i),
            selectedColor: _amber,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            side: BorderSide.none,
            labelStyle: TextStyle(
              color: selected == i ? Colors.black87 : Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
            showCheckmark: false,
          ),
      ],
    );
  }

  static const List<String> _wallNames = [
    'Krem', 'Mint', 'Salmon', 'Biru pastel', 'Kuning muda', 'Lavender',
    'Peach', 'Aqua', 'Pink muda', 'Hijau pucat', 'Susu cokelat', 'Abu biru',
  ];
  static const List<String> _roofNames = [
    'Bata', 'Abu gelap', 'Hijau tua', 'Biru tua', 'Ungu', 'Merah',
    'Oranye', 'Cokelat tua', 'Teal', 'Abu',
  ];
  static const List<String> _signNames = [
    'Hijau', 'Biru', 'Hitam', 'Merah', 'Ungu', 'Oranye', 'Teal', 'Cokelat',
  ];
  static const List<String> _doorNames = [
    'Cokelat', 'Biru', 'Hijau', 'Merah', 'Kuning', 'Ungu', 'Abu gelap', 'Pink',
  ];
  static const List<(IconData, String)> _bldCats = [
    (Icons.format_paint_rounded, 'Dinding'),
    (Icons.roofing_rounded, 'Atap'),
    (Icons.sell_rounded, 'Papan'),
    (Icons.door_front_door_rounded, 'Pintu'),
    (Icons.stars_rounded, 'Kelas'),
  ];

  /// Rumah mungil untuk pratinjau pilihan: warna lain tetap dari draf kamu.
  Widget _houseThumb({
    Color? wall,
    Color? roof,
    Color? sign,
    Color? door,
    int? tier,
    double w = 58,
    double h = 46,
  }) {
    final tr = tier ?? _previewTier;
    final wl = wall ?? _draft.wallColor ?? KostPalette.walls[0];
    final rf = roof ??
        _draft.roofColor ??
        (tr == 1
            ? const Color(0xFF37474F)
            : Color.lerp(wl, const Color(0xFF8D4B3B), 0.75)!);
    return SizedBox(
      width: w,
      height: h,
      child: CustomPaint(
        painter: _HouseThumbPainter(
          wall: wl,
          roof: rf,
          sign: sign ?? _draft.signColor ?? const Color(0xFF477A62),
          door: door ?? _draft.doorColor ?? const Color(0xFF6D4C41),
          tier: tr,
        ),
      ),
    );
  }

  Widget _thumbGrid({
    required int count,
    required int? selected,
    required String Function(int) labelOf,
    required Widget Function(int) thumb,
    required void Function(int) pick,
  }) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 8.0;
        final cols = ((c.maxWidth + gap) / (72 + gap)).floor().clamp(3, 6);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < count; i++)
              GestureDetector(
                onTap: () => pick(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: w,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: selected == i
                        ? _amber.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected == i
                          ? _amber
                          : Colors.white.withValues(alpha: 0.1),
                      width: selected == i ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      thumb(i),
                      const SizedBox(height: 4),
                      Text(
                        labelOf(i),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected == i ? _amber : Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _tierCard(int i, String desc, {bool small = false}) {
    final on = _previewTier == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _previewTier = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: EdgeInsets.only(left: i == 0 ? 0 : 8),
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
          decoration: BoxDecoration(
            color: on
                ? _amber.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: on ? _amber : Colors.white.withValues(alpha: 0.1),
              width: on ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              _houseThumb(tier: i, w: small ? 56 : 70, h: small ? 44 : 56),
              const SizedBox(height: 6),
              Text(
                _tierNames[i],
                style: TextStyle(
                  color: on ? _amber : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bldContent() {
    switch (_bldCat) {
      case 0:
        return _section(
          'Warna dinding',
          _thumbGrid(
            count: KostPalette.walls.length,
            selected: _draft.wall,
            labelOf: (i) => _wallNames[i],
            thumb: (i) => _houseThumb(wall: KostPalette.walls[i]),
            pick: (i) => _edit((s) => s.copyWith(wall: i)),
          ),
          value: _draft.wall == null ? 'Bawaan' : _wallNames[_draft.wall!],
        );
      case 1:
        return _section(
          'Warna atap',
          _thumbGrid(
            count: KostPalette.roofs.length,
            selected: _draft.roof,
            labelOf: (i) => _roofNames[i],
            thumb: (i) => _houseThumb(roof: KostPalette.roofs[i]),
            pick: (i) => _edit((s) => s.copyWith(roof: i)),
          ),
          value: _draft.roof == null ? 'Bawaan' : _roofNames[_draft.roof!],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section(
              'Nama kost di papan',
              TextField(
                controller: _nameCtl,
                maxLength: KostPalette.maxNameLen,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
                  _UpperCaseFormatter(),
                ],
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.edit_rounded,
                      size: 18, color: Colors.white54),
                  hintText: 'Kosong = KOST / EKSKLUSIF / SULTAN',
                  hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                      letterSpacing: 0),
                  counterStyle:
                  TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => _edit((s) => s.copyWith(name: v.trim())),
              ),
            ),
            _section(
              'Warna papan',
              _thumbGrid(
                count: KostPalette.signs.length,
                selected: _draft.sign,
                labelOf: (i) => _signNames[i],
                thumb: (i) => _houseThumb(sign: KostPalette.signs[i]),
                pick: (i) => _edit((s) => s.copyWith(sign: i)),
              ),
              value: _draft.sign == null ? 'Bawaan' : _signNames[_draft.sign!],
            ),
          ],
        );
      case 3:
        return _section(
          'Warna pintu',
          _thumbGrid(
            count: KostPalette.doors.length,
            selected: _draft.door,
            labelOf: (i) => _doorNames[i],
            thumb: (i) => _houseThumb(door: KostPalette.doors[i]),
            pick: (i) => _edit((s) => s.copyWith(door: i)),
          ),
          value: _draft.door == null ? 'Bawaan' : _doorNames[_draft.door!],
        );
      default:
        return _section(
          'Pratinjau kelas kost (hanya di layarmu)',
          LayoutBuilder(
            builder: (context, c) {
              final small = c.maxWidth < 290;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _tierCard(0, 'Rumah biasa', small: small),
                  _tierCard(1, 'Jendela biru', small: small),
                  _tierCard(2, 'Atap emas', small: small),
                ],
              );
            },
          ),
        );
    }
  }

  static const List<String> _skinNames = [
    'Terang',
    'Sawo muda',
    'Sawo matang',
    'Cokelat',
    'Gelap',
    'Pucat',
    'Kemerahan',
    'Zaitun',
    'Madu',
    'Eboni',
  ];

  static const List<String> _shirtNames = [
    'Biru',
    'Merah',
    'Hijau',
    'Ungu',
    'Kuning',
    'Oranye',
    'Tosca',
    'Pink',
    'Cokelat',
    'Abu gelap',
    'Putih',
    'Hijau muda',
    'Biru tua',
    'Marun',
    'Krem',
    'Hitam',
  ];

  static const List<String> _hairColorNames = [
    'Hitam',
    'Cokelat',
    'Cokelat tua',
    'Pirang',
    'Jahe',
    'Uban',
    'Biru',
    'Pink',
  ];

  static const List<(IconData, String)> _charCats = [
    (Icons.face_rounded, 'Kulit'),
    (Icons.checkroom_rounded, 'Baju'),
    (Icons.accessibility_new_rounded, 'Celana'),
    (Icons.content_cut_rounded, 'Rambut'),
    (Icons.palette_rounded, 'Warna'),
    (Icons.auto_awesome_rounded, 'Aksesori'),
  ];

  /// Tampilan karakterku dengan satu opsi diganti (untuk pratinjau kotak).
  KostLook _lookWith({int? hair, int? acc, int? top, int? pstyle}) {
    final base = kostLookFor(_myId ?? '', _draft);
    return KostLook(
      skin: base.skin,
      shirt: base.shirt,
      shirtStyle: top ?? base.shirtStyle,
      pants: base.pants,
      pantsStyle: pstyle ?? base.pantsStyle,
      hair: hair ?? base.hair,
      hairColor: base.hairColor,
      acc: acc ?? base.acc,
    );
  }

  Widget _catBtn(List<(IconData, String)> cats, int cur, int i,
      void Function(int) on) {
    final sel = cur == i;
    final (icon, label) = cats[i];
    return GestureDetector(
      onTap: () => on(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(vertical: _compact ? 6 : 8),
        decoration: BoxDecoration(
          color: sel
              ? _amber.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? _amber : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: sel ? _amber : Colors.white70),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: sel ? _amber : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _catBar(List<(IconData, String)> cats, int cur, void Function(int) on) =>
      Row(
        children: [
          for (var i = 0; i < cats.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _catBtn(cats, cur, i, on)),
          ],
        ],
      );

  Widget _charContent() {
    switch (_charCat) {
      case 0:
        {
          final cur = _draft.skin ?? 1;
          return _section(
            'Warna kulit',
            _swatches(KostPalette.skins, cur,
                    (i) => _edit((s) => s.copyWith(skin: i)),
                names: _skinNames),
            value: _skinNames[cur],
          );
        }
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(
              'Model baju',
              _tileGrid(
                labels: KostPalette.topNames,
                selected: _draft.top,
                lookOf: (i) => _lookWith(top: i),
                pick: (i) => _edit((s) => s.copyWith(top: i)),
                body: true,
              ),
              value: KostPalette.topNames[_draft.top],
            ),
            _section(
              'Warna baju',
              _swatches(KostPalette.shirts, _draft.shirt,
                      (i) => _edit((s) => s.copyWith(shirt: i)),
                  names: _shirtNames),
              value:
              _draft.shirt == null ? 'Bawaan' : _shirtNames[_draft.shirt!],
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(
              'Model celana',
              _tileGrid(
                labels: KostPalette.pantsStyleNames,
                selected: _draft.pantsStyle,
                lookOf: (i) => _lookWith(pstyle: i),
                pick: (i) => _edit((s) => s.copyWith(pantsStyle: i)),
                body: true,
              ),
              value: KostPalette.pantsStyleNames[_draft.pantsStyle],
            ),
            _section(
              'Warna celana',
              _swatches(KostPalette.pants, _draft.pants,
                      (i) => _edit((s) => s.copyWith(pants: i)),
                  names: KostPalette.pantsNames),
              value: KostPalette.pantsNames[_draft.pants],
            ),
          ],
        );
      case 3:
        return _section(
          'Gaya rambut',
          _tileGrid(
            labels: KostPalette.hairNames,
            selected: _draft.hair,
            lookOf: (i) => _lookWith(hair: i, acc: 0),
            pick: (i) => _edit((s) => s.copyWith(hair: i)),
          ),
          value: KostPalette.hairNames[_draft.hair],
        );
      case 4:
        return _section(
          'Warna rambut / topi',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _swatches(KostPalette.hairColors, _draft.hairColor,
                      (i) => _edit((s) => s.copyWith(hairColor: i)),
                  names: _hairColorNames),
              if (_draft.hair == 0 && _draft.acc != 4 && _draft.acc != 9)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 14, color: Colors.white.withValues(alpha: 0.55)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Warna ini baru terlihat setelah kamu memilih gaya '
                              'rambut, topi, kumis, atau jenggot.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          value: _hairColorNames[_draft.hairColor],
        );
      default:
        return _section(
          'Aksesori',
          _tileGrid(
            labels: KostPalette.accNames,
            selected: _draft.acc,
            lookOf: (i) => _lookWith(acc: i),
            pick: (i) => _edit((s) => s.copyWith(acc: i)),
          ),
          value: KostPalette.accNames[_draft.acc],
        );
    }
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

// ======================================================================
//  RUANG KOSTUM: latar panggung + podium karakter
// ======================================================================

class _StagePainter extends CustomPainter {
  _StagePainter(this.anim, this.accent) : super(repaint: anim);

  final Animation<double> anim;

  /// Warna cahaya di belakang karakter (mengikuti warna baju).
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final t = sceneNowMs() / 1000.0;
    final p = Paint();

    // latar gradasi
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1B3629), Color(0xFF0B1610)],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, p);

    // cahaya lembut di belakang karakter
    p.shader = RadialGradient(
      colors: [
        accent.withValues(alpha: 0.30),
        accent.withValues(alpha: 0.0),
      ],
    ).createShader(
      Rect.fromCircle(
          center: Offset(w / 2, h * 0.42), radius: math.max(w, h) * 0.5),
    );
    canvas.drawRect(Offset.zero & size, p);

    // vinyet tepi
    p.shader = const RadialGradient(
      radius: 1.0,
      colors: [Color(0x00000000), Color(0x59000000)],
      stops: [0.6, 1.0],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, p);
    p.shader = null;

    // partikel berkilau naik pelan
    for (var i = 0; i < 16; i++) {
      final fx = (i * 0.618034) % 1.0;
      final speed = 0.015 + (i % 4) * 0.008;
      final fy = 1.0 - ((i * 0.381966 + t * speed) % 1.0);
      final tw = 0.5 + 0.5 * math.sin(t * 2.0 + i * 2.1);
      p.color = Colors.white.withValues(alpha: 0.05 + 0.20 * tw);
      canvas.drawCircle(Offset(fx * w, fy * h), 1.0 + (i % 3) * 0.6, p);
    }

    // rel lampu di atas
    p.color = const Color(0xFF263238);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, 8), p);
    final count = math.max(6, (w / 34).floor());
    for (var i = 0; i < count; i++) {
      final x = (i + 0.5) * w / count;
      final tw = 0.55 + 0.45 * math.sin(t * 2.2 + i * 1.7);
      p.color = const Color(0xFFFFE082).withValues(alpha: 0.25 + 0.35 * tw);
      canvas.drawCircle(Offset(x, 14), 6.5, p);
      p.color = const Color(0xFFFFF8E1).withValues(alpha: 0.6 + 0.4 * tw);
      canvas.drawCircle(Offset(x, 14), 2.6, p);
    }
  }

  @override
  bool shouldRepaint(covariant _StagePainter oldDelegate) => true;
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter({
    required this.look,
    required this.anim,
    required this.pose,
    required this.phase,
    required this.faceRight,
    required this.highlight,
    required this.accent,
  }) : super(repaint: anim);

  final KostLook look;
  final Animation<double> anim;
  final KostPose pose;
  final double phase;
  final bool faceRight;
  final bool highlight;
  final Color accent;

  final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 4 || size.height <= 4) return;
    final t = sceneNowMs() / 1000.0;
    final s = math.min(size.width / 20, size.height / 32);
    final fx = size.width / 2;
    final fy = size.height * 0.84;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // sorot lampu
    final spot = Path()
      ..moveTo(fx - 3 * s, 0)
      ..lineTo(fx + 3 * s, 0)
      ..lineTo(fx + 11 * s, fy + 3 * s)
      ..lineTo(fx - 11 * s, fy + 3 * s)
      ..close();
    _p
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00FFF3C4), Color(0x38FFF3C4)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, fy));
    canvas.drawPath(spot, _p);
    _p.shader = null;

    // podium silinder: sisi, lalu permukaan atas
    final pod = Rect.fromCenter(
        center: Offset(fx, fy + 0.9 * s), width: 20 * s, height: 3.4 * s);
    _p.color = const Color(0xFF16291E);
    canvas.drawRect(
        Rect.fromLTRB(
            pod.left, pod.center.dy, pod.right, pod.center.dy + 0.9 * s),
        _p);
    canvas.drawOval(pod.shift(Offset(0, 0.9 * s)), _p);
    _p.color = const Color(0xFF2B4F3D);
    canvas.drawOval(pod, _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = highlight ? 2.4 : 1.4
      ..color = accent.withValues(alpha: highlight ? 0.9 : 0.5);
    canvas.drawOval(pod, _p);
    _p.style = PaintingStyle.fill;

    // bayangan di bawah kaki
    _p.color = Colors.black.withValues(alpha: 0.28);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(fx, fy + 0.25 * s), width: 8 * s, height: 1.8 * s),
        _p);

    // karakter
    canvas.save();
    canvas.translate(fx, fy);
    canvas.scale(faceRight ? s : -s, s);
    paintKostCharacter(canvas, _p, look, t: t, pose: pose, phase: phase);
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) => true;
}

// ======================================================================
//  KILAU saat bangunan diubah + RUMAH MUNGIL untuk pratinjau pilihan
// ======================================================================

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.cam,
    required this.stage,
    required this.index,
    required this.startMs,
  });

  final KostStreetCamera cam;
  final Rect stage;
  final int index;
  final int startMs;

  @override
  void paint(Canvas canvas, Size size) {
    final age = sceneNowMs() - startMs;
    const dur = 750;
    if (age < 0 || age > dur) return;
    final q = age / dur;
    final e = 1 - math.pow(1 - q, 3).toDouble();
    final s = cam.scale;
    final o = cam.origin(stage);
    final c = Offset(
      o.dx + (index * kStreetSlotW + kStreetSlotW / 2) * s,
      o.dy + 150 * s,
    );
    final p = Paint();
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * (1 - q)
      ..color = const Color(0xFFFFCA28).withValues(alpha: 0.7 * (1 - q));
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 260 * s * e, height: 150 * s * e),
      p,
    );
    p.style = PaintingStyle.fill;
    for (var i = 0; i < 14; i++) {
      final ang = i * math.pi * 2 / 14 + i * 0.7;
      final dist = (60 + (i % 4) * 22) * s * e;
      final pos = c + Offset(math.cos(ang) * dist * 1.3, math.sin(ang) * dist * 0.8);
      p.color = (i.isEven ? const Color(0xFFFFE082) : Colors.white)
          .withValues(alpha: (1 - q) * 0.9);
      canvas.drawCircle(pos, (1 + (i % 3) * 0.8) * (1 - q * 0.5) * math.max(1.0, s * 1.6), p);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => true;
}

class _HouseThumbPainter extends CustomPainter {
  _HouseThumbPainter({
    required this.wall,
    required this.roof,
    required this.sign,
    required this.door,
    required this.tier,
  });

  final Color wall;
  final Color roof;
  final Color sign;
  final Color door;
  final int tier;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 58, size.height / 46);
    final p = Paint();

    // bayangan
    p.color = Colors.black.withValues(alpha: 0.25);
    canvas.drawOval(const Rect.fromLTWH(3, 39, 52, 6), p);

    // dinding
    final w = tier == 2
        ? Color.lerp(wall, const Color(0xFFFFF8E1), 0.55)!
        : (tier == 1 ? Color.lerp(wall, const Color(0xFFECEFF1), 0.45)! : wall);
    const body = Rect.fromLTRB(7, 18, 51, 41);
    p
      ..style = PaintingStyle.fill
      ..color = w;
    canvas.drawRect(body, p);
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Color.lerp(w, Colors.black, 0.3)!;
    canvas.drawRect(body, p);
    p
      ..style = PaintingStyle.fill
      ..color = tier == 2
          ? const Color(0xFFFFB300)
          : Color.lerp(w, Colors.black, 0.22)!;
    canvas.drawRect(const Rect.fromLTWH(7, 38.5, 44, 2.5), p);

    // jendela
    final glass = tier == 2 ? const Color(0xFFFFE57F) : const Color(0xFFFFDD7A);
    final frame = tier == 2
        ? const Color(0xFFFFB300)
        : (tier == 1 ? const Color(0xFF455A64) : const Color(0xFF6B5843));
    for (final x in const [11.0, 38.0]) {
      p
        ..style = PaintingStyle.fill
        ..color = glass;
      canvas.drawRect(Rect.fromLTWH(x, 23, 9, 8), p);
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = frame;
      canvas.drawRect(Rect.fromLTWH(x, 23, 9, 8), p);
      canvas.drawLine(Offset(x + 4.5, 23), Offset(x + 4.5, 31), p);
    }

    // pintu
    p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF3E2723);
    canvas.drawRect(const Rect.fromLTWH(25.4, 27.4, 8.2, 13.6), p);
    p.color = door;
    canvas.drawRect(const Rect.fromLTWH(26, 28, 7, 13), p);
    p.color = const Color(0xFFFFCA28);
    canvas.drawCircle(const Offset(31.6, 35), 0.7, p);

    // atap
    if (tier == 2) {
      p.color = roof;
      canvas.drawRect(const Rect.fromLTRB(4, 12, 54, 18), p);
      p.color = const Color(0xFFFFD54F);
      canvas.drawRect(const Rect.fromLTRB(4, 11, 54, 12.8), p);
    } else {
      final path = Path()
        ..moveTo(3, 18)
        ..lineTo(11, 9)
        ..lineTo(47, 9)
        ..lineTo(55, 18)
        ..close();
      p.color = roof;
      canvas.drawPath(path, p);
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(roof, Colors.white, 0.4)!.withValues(alpha: 0.8);
      canvas.drawLine(const Offset(11.5, 9.6), const Offset(46.5, 9.6), p);
      p
        ..style = PaintingStyle.fill
        ..color = Color.lerp(roof, Colors.black, 0.3)!;
      canvas.drawRect(const Rect.fromLTWH(3, 16.4, 52, 1.6), p);
    }

    // papan nama
    final sg = RRect.fromRectAndRadius(
        const Rect.fromLTWH(19, 1, 20, 8), const Radius.circular(1.6));
    p
      ..style = PaintingStyle.fill
      ..color = sign;
    canvas.drawRRect(sg, p);
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = tier == 2
          ? const Color(0xFFFFD54F)
          : Colors.white.withValues(alpha: 0.75);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(19.7, 1.7, 18.6, 6.6), const Radius.circular(1.2)),
        p);
    p
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(23, 4, 12, 1.8), const Radius.circular(0.9)),
        p);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HouseThumbPainter old) =>
      old.wall != wall ||
          old.roof != roof ||
          old.sign != sign ||
          old.door != door ||
          old.tier != tier;
}