import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  int _previewTier = 0;

  // ruang kostum
  String? _focusId; // pemain yang sedang disorot di panggung
  KostPose _pose = KostPose.wave;
  bool _faceRight = true;
  int _charCat = 0; // kategori kustomisasi karakter

  RealtimeChannel? _channel;
  Timer? _saveTimer;
  Timer? _beat;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    _anim.addListener(() => _cam.step());
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
    setState(() => _draft = f(_draft));
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
              final view = _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_tab == 0 ? _streetView(entries) : _stageView(entries));
              final panel =
              widget.readOnly ? _watchPanel(entries) : _editPanel();
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _topBar(entries),
                    const SizedBox(height: 10),
                    _tabs(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: wide
                          ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: view),
                          const SizedBox(width: 16),
                          SizedBox(width: 380, child: panel),
                        ],
                      )
                          : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 6, child: view),
                          const SizedBox(height: 10),
                          Expanded(flex: 5, child: panel),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _topBar(List<_Entry> entries) {
    final editing = entries.where((e) => e.status == 'editing').length;
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: widget.readOnly ? 'Kembali' : 'Selesai & kembali',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            foregroundColor: Colors.white,
          ),
          onPressed: _leaving ? null : _finish,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.readOnly ? 'Mode menonton' : 'Ruang kustomisasi',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                editing > 0
                    ? '$editing pemain sedang berkustomisasi'
                    : 'Semua pemain sudah selesai',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.roomCode,
            style: const TextStyle(
              color: _amber,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabs() {
    Widget chip(int i, IconData icon, String label) {
      final on = _tab == i;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _tab = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: on ? _amber : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: on ? Colors.black87 : Colors.white70),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: on ? Colors.black87 : Colors.white70,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(0, Icons.home_work_rounded, 'Bangunan'),
        const SizedBox(width: 8),
        chip(1, Icons.face_retouching_natural_rounded, 'Karakter'),
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

  Widget _tag(_Entry e) {
    final (icon, label, color) = _statusInfo(e.status);
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
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
  );

  Widget _streetView(List<_Entry> list) {
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
              color: Colors.white.withValues(alpha: 0.16), width: 1.5),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final size = Size(c.maxWidth, c.maxHeight);
            const insets = EdgeInsets.only(top: 52);
            final stage = _cam.stageFor(size, insets);
            final fit = math.min(
              stage.width * 0.96 / (n * kStreetSlotW),
              stage.height / kStreetSlotH,
            );
            _cam.setTarget(n * kStreetSlotW / 2, math.min(fit, 1.15));
            final backdrop = KostSceneData(
              rooms: 0,
              maxRooms: 12,
              defense: 0,
              trashRatio: 0,
              pollution: 4,
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) => KostStreet(
                      houses: [
                        for (var i = 0; i < n; i++) _house(list[i], i),
                      ],
                      backdrop: backdrop,
                      camera: _cam,
                      repaint: _anim,
                      ids: [for (final e in list) e.id],
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
                        children: _streetTags(list, stage),
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

  List<Widget> _streetTags(List<_Entry> list, Rect stage) {
    final s = _cam.scale;
    final o = _cam.origin(stage);
    final out = <Widget>[];
    for (var i = 0; i < list.length; i++) {
      final cx = o.dx + (i * kStreetSlotW + kStreetSlotW / 2) * s;
      final roofY = o.dy + (236.0 - 50.0) * s;
      final w = (kStreetSlotW * s - 6).clamp(84.0, 190.0).toDouble();
      final top = math.max(4.0, roofY - 47 * s - 54);
      out.add(Positioned(
        left: cx - w / 2,
        top: top,
        width: w,
        child: _tag(list[i]),
      ));
    }
    return out;
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
    final others = [
      for (final e in list)
        if (e.id != hero.id) e,
    ];
    final heroLook = kostLookFor(hero.id, hero.style);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.16), width: 1.5),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _StagePainter(_anim, heroLook.shirt)),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 22, 12, 10),
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
                    _heroBar(hero),
                    if (others.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _roster(others),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBtn(IconData icon, String tip, bool on, VoidCallback onTap) =>
      Tooltip(
        message: tip,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? _amber : Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                color: on ? _amber : Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(icon, size: 18, color: on ? Colors.black87 : Colors.white70),
          ),
        ),
      );

  Widget _heroBar(_Entry e) {
    final (icon, label, color) = _statusInfo(e.status);
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
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
                  size: 30,
                  ring: e.isMe ? _amber : null,
                ),
                const SizedBox(width: 8),
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
                      Row(
                        children: [
                          Icon(icon, size: 12, color: color),
                          const SizedBox(width: 3),
                          Text(
                            label,
                            style: TextStyle(
                              color: color,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _miniBtn(Icons.flip_rounded, 'Balik arah', false,
                () => setState(() => _faceRight = !_faceRight)),
        for (final (pose, pIcon, pLabel) in _poses) ...[
          const SizedBox(width: 6),
          _miniBtn(pIcon, pLabel, _pose == pose,
                  () => setState(() => _pose = pose)),
        ],
      ],
    );
  }

  /// Pemain lain di ruang kostum: ketuk untuk menyorot karakternya.
  Widget _roster(List<_Entry> others) => SizedBox(
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
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: e.isMe
                    ? _amber.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.14),
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
                    Row(
                      children: [
                        Icon(st.$1, size: 11, color: st.$3),
                        const SizedBox(width: 3),
                        Text(
                          st.$2,
                          style: TextStyle(
                            color: st.$3,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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
      padding: const EdgeInsets.all(14),
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

  Widget _doneButton(String label) => FilledButton.icon(
    onPressed: _leaving ? null : _finish,
    style: FilledButton.styleFrom(
      backgroundColor: _amber,
      foregroundColor: Colors.black87,
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    icon: Icon(_leaving ? Icons.hourglass_bottom_rounded : Icons.check_rounded),
    label: Text(
      _leaving ? 'Menyimpan…' : label,
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
    ),
  );

  Widget _editPanel() {
    final chars = _tab == 1;
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
          if (chars) ...[
            _charCatBar(),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: chars ? [_charContent()] : _buildingControls(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _edit((s) => _tab == 0
                        ? s.randomBuilding(_rnd)
                        : s.randomCharacter(_rnd));
                  },
                  style: _outlined,
                  icon: const Icon(Icons.casino_rounded, size: 18),
                  label: const Text('Acak'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _edit((s) =>
                    _tab == 0 ? s.clearBuilding() : s.clearCharacter());
                    if (_tab == 0) _nameCtl.clear();
                  },
                  style: _outlined,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Bawaan'),
                ),
              ),
            ],
          ),
        ],
      ),
      footer: _doneButton('Selesai kustomisasi'),
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
            const Text('Pemain', style: _labelStyle),
            const SizedBox(height: 8),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(_statusInfo(e.status).$1,
                        size: 18, color: _statusInfo(e.status).$3),
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
                    Text(
                      _statusInfo(e.status).$2,
                      style: TextStyle(
                          color: _statusInfo(e.status).$3,
                          fontSize: 12,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Kamu memilih tampilan bawaan, jadi cukup menonton sementara '
                  'pemain lain berkustomisasi. Permainan baru bisa dimulai '
                  'setelah mereka selesai.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65), fontSize: 12.5),
            ),
          ],
        ),
      ),
      footer: _doneButton('Kembali ke lobi'),
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
  }) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 8.0;
        final cols = c.maxWidth >= 300 ? 3 : 2;
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
                      KostHeadIcon(look: lookOf(i), size: 46),
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

  List<Widget> _buildingControls() => [
    _section(
      'Warna dinding',
      _swatches(KostPalette.walls, _draft.wall,
              (i) => _edit((s) => s.copyWith(wall: i))),
    ),
    _section(
      'Warna atap',
      _swatches(KostPalette.roofs, _draft.roof,
              (i) => _edit((s) => s.copyWith(roof: i))),
    ),
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
            color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Kosong = KOST / EKSKLUSIF / SULTAN',
          hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 12,
              letterSpacing: 0),
          counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
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
      _swatches(KostPalette.signs, _draft.sign,
              (i) => _edit((s) => s.copyWith(sign: i))),
    ),
    _section(
      'Warna pintu',
      _swatches(KostPalette.doors, _draft.door,
              (i) => _edit((s) => s.copyWith(door: i))),
    ),
    _section(
      'Pratinjau kelas kost (hanya di layarmu)',
      _choices(_tierNames, _previewTier, (i) => setState(() => _previewTier = i)),
    ),
  ];

  static const List<String> _skinNames = [
    'Terang',
    'Sawo muda',
    'Sawo matang',
    'Cokelat',
    'Gelap',
    'Pucat',
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
    (Icons.content_cut_rounded, 'Rambut'),
    (Icons.palette_rounded, 'Warna'),
    (Icons.auto_awesome_rounded, 'Aksesori'),
  ];

  /// Tampilan karakterku dengan satu opsi diganti (untuk pratinjau kotak).
  KostLook _lookWith({int? hair, int? acc}) {
    final base = kostLookFor(_myId ?? '', _draft);
    return KostLook(
      skin: base.skin,
      shirt: base.shirt,
      hair: hair ?? base.hair,
      hairColor: base.hairColor,
      acc: acc ?? base.acc,
    );
  }

  Widget _catButton(int i) {
    final on = _charCat == i;
    final (icon, label) = _charCats[i];
    return GestureDetector(
      onTap: () => setState(() => _charCat = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: on
              ? _amber.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: on ? _amber : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: on ? _amber : Colors.white70),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: on ? _amber : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _charCatBar() => Row(
    children: [
      for (var i = 0; i < _charCats.length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(child: _catButton(i)),
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
        return _section(
          'Warna baju',
          _swatches(KostPalette.shirts, _draft.shirt,
                  (i) => _edit((s) => s.copyWith(shirt: i)),
              names: _shirtNames),
          value: _draft.shirt == null ? 'Bawaan' : _shirtNames[_draft.shirt!],
        );
      case 2:
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
      case 3:
        return _section(
          'Warna rambut / topi',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _swatches(KostPalette.hairColors, _draft.hairColor,
                      (i) => _edit((s) => s.copyWith(hairColor: i)),
                  names: _hairColorNames),
              if (_draft.hair == 0 && _draft.acc != 4)
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
                              'rambut, topi, atau kumis.',
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