import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cinematics.dart';
import 'kost_scene.dart';
import 'kost_style.dart';
import 'kost_warehouse.dart';
import 'kost_pets.dart';
import 'sfx.dart';

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

  /// Tinggi kartu sasaran yang ditempel di atas layar saat zoom ke rumah lawan.
  static const _dockH = 52.0;

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

  /// Kustomisasi bangunan & karakter tiap pemain (diatur di lobi, tetap
  /// selama permainan). Kosong = tampilan bawaan.
  final Map<String, KostStyle> _styles = {};

  /// Pemilik kost tiap rumah (state gerak & mood; digambar painter rumah).
  final Map<String, KostOwner> _owners = {};

  KostOwner _ownerFor(String id) {
    final o = _owners.putIfAbsent(id, () => KostOwner(seed: kostSeedFor(id)));
    o.look = kostLookFor(id, _styles[id]);
    return o;
  }
  final List<Map<String, dynamic>> _events = [];

  final Map<String, int> _prevRooms = {};
  final Map<String, int> _prevDefense = {};
  final Map<String, int> _prevWaste = {};
  final Map<String, int> _prevTier = {};

  final Map<String, List<KostFx>> _fx = {};
  final List<KostShot> _shots = []; // lemparan yang sedang terbang antar rumah
  double _atkTotal = 0; // total jendela Tangkis serangan masuk (untuk cincin)
  final Map<String, double> _haulTotal = {};
  // Pemberitahuan singkat (kabar, galat, info). Satu slot di atas layar,
  // hilang sendiri; riwayat lengkap tetap ada di tombol "Kabar terbaru".
  _Notice? _notice;
  Timer? _noticeTimer;
  int _noticeSeq = 0;
  int _lastEmojiSentMs = -10000;
  bool _emojiBarOpen = false;
  bool _tangkisBusy = false;
  // kunci "pemilik|waktu" serangan tertunda yang sudah memicu tick penyelesaian
  final Set<String> _tickedPending = {};

  // --- arwah (pemain tertimbun melayang di jalan; murni visual) ---
  final Map<String, KostGhost> _ghosts = {};
  int _lastGhostSendMs = -10000;

  // --- loket sampah ---
  Map<String, dynamic>? _incomingOffer; // tawaran masuk yang menunggu jawaban
  final Set<int> _seenOffers = {};
  bool _offerBusy = false;

  // --- gudang sampah (sisi kanan kost) ---
  /// Baris `player_warehouse` per pemain (tabel dari warehouse.sql).
  final Map<String, Map<String, dynamic>> _wh = {};

  // --- hewan peliharaan ---
  /// Baris `player_pets`: pemain -> (slot -> baris).
  final Map<String, Map<int, Map<String, dynamic>>> _petRows = {};
  final Map<String, KostPetCrew> _petCrews = {};
  int _petSlotSel = 1;

  KostPetCrew _petsFor(String id) {
    final c =
    _petCrews.putIfAbsent(id, () => KostPetCrew(seed: kostSeedFor(id)));
    c.loadout = PetLoadout.fromRows((_petRows[id] ?? const {}).values);
    return c;
  }

  // --- jalan (kost berderet) & kamera zoom ---
  final KostStreetCamera _cam = KostStreetCamera();
  String? _focusId; // rumah yang di-zoom; null = lihat semua tetangga
  bool _focusInit = false;
  double _pinch = 1.0;
  Offset _pinchFocal = Offset.zero;
  int _lastWheelMs = -10000;

  Duration _offset = Duration.zero;
  RealtimeChannel? _channel;
  Timer? _uiTimer;
  Timer? _tickTimer;
  late final AnimationController _anim;
  String? _activeRpc;
  bool _loaded = false;

  // --- sinematik (intro, rumah tertimbun, sidak polisi) ---
  final CineDirector _cine = CineDirector();
  bool _introChecked = false;
  // tata letak kamera terakhir (dipakai listener per-frame sutradara)
  Rect _lastStage = Rect.zero;
  List<String> _lastOrder = const <String>[];
  double _lastFitOne = 1;
  double _lastFitAll = 1;
  double _lastTgtCx = 200;
  double _lastTgtScale = 1;

  @override
  void initState() {
    super.initState();
    _anim =
    AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    // Kamera jalan bergerak halus menuju targetnya di setiap frame.
    _anim.addListener(_cam.step);
    _anim.addListener(_cineStep);
    _anim.addListener(_ghostStep);
    kostDoorHook = _onDoor;
    _subscribe();
    _loadAll();
    _tickServer();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      final now = sceneNowMs();
      for (final l in _fx.values) {
        l.removeWhere((f) =>
        now - f.startMs > (f.durMs > 0 ? f.durMs + 800 : 6000));
      }
      _shots.removeWhere((sh) => sh.age > sh.durMs + 1500);
      // dengung lalat saat sampah kost sendiri >= 50% (sama dengan visualnya)
      final myS = _states[_me];
      if (myS != null &&
          myS['eliminated_at'] == null &&
          _room['status'] != 'finished') {
        final cap = _num(myS['trash_capacity']);
        if (cap > 0) {
          Sfx.instance.fliesTick(
              (_live(myS).trash / cap).clamp(0.0, 1.0).toDouble());
        }
      }
      if (_incomingOffer != null &&
          _remaining(_incomingOffer!['expires_at']) <= 0) {
        _incomingOffer = null;
      }
      // Jendela Tangkis habis -> minta server menyelesaikan serangan segera
      // (tanpa menunggu tick 4 detik), supaya dampak terasa tepat waktu.
      for (final s in _states.values) {
        final u = s['pending_attack_until'];
        if (u == null) continue;
        final over = _serverNow.difference(_ts(u)!).inMilliseconds;
        if (over > 250 && _tickedPending.add('${s['player_id']}|$u')) {
          _tickServer();
        }
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
    _noticeTimer?.cancel();
    Sfx.instance.rainStop(immediate: true);
    if (kostDoorHook == _onDoor) kostDoorHook = null;
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
          if (pid == _me) {
            // lantai = ceil(kamar/4) (maks 3): lantai bertambah -> derek,
            // kamar baru di lantai yang sama -> palu
            int fl(int r) => min(3, max(1, (r / 4).ceil()));
            Sfx.instance.play(fl(newRooms) > fl(_prevRooms[pid]!)
                ? 'construct-crane'
                : 'construct-hammer');
          }
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
          if (pid == _me) Sfx.instance.play('upgrade');
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
          _events.insert(0, ev);
          if (_events.length > 25) _events.removeLast();
        });
        final txt = _eventText(ev);
        if (txt.isNotEmpty) {
          final ic = _eventIcon(ev['type']);
          _showNotice(txt, icon: ic.$1, color: ic.$2);
        }
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'trash_offers',
      filter: roomFilter('room_id'),
      callback: _onOfferChange,
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'player_warehouse',
      filter: roomFilter('room_id'),
      callback: (p) {
        final r = p.newRecord;
        if (r.isEmpty || !mounted) return;
        final row = Map<String, dynamic>.from(r);
        final pid = row['player_id'] as String;
        final before = _num(_wh[pid]?['tier']).toInt();
        final after = _num(row['tier']).toInt();
        setState(() => _wh[pid] = row);
        if (pid == _me && before == 0 && after > 0) {
          Sfx.instance.play('werehouse-open');
        }
        if (pid == _me && after > before && before > 0) {
          _showNotice('Gudang naik jadi ${Wh.tierNames[after.clamp(0, Wh.maxTier).toInt()]}!',
              icon: Icons.warehouse_rounded, color: const Color(0xFFFB8C00));
        }
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'player_pets',
      filter: roomFilter('room_id'),
      callback: (p) {
        if (!mounted) return;
        final del = p.eventType == PostgresChangeEvent.delete;
        final r = del ? p.oldRecord : p.newRecord;
        final pid = r['player_id'] as String?;
        final slot = (r['slot'] as num?)?.toInt();
        if (pid == null || slot == null) return;
        final before = _petRows[pid]?[slot]?['pet_key'];
        setState(() {
          if (del) {
            _petRows[pid]?.remove(slot);
          } else {
            (_petRows[pid] ??= {})[slot] = Map<String, dynamic>.from(r);
          }
        });
        final key = r['pet_key'] as String?;
        if (!del && pid == _me && key != null && key != before) {
          final def = Pets.byKey(key);
          if (def != null) {
            _showNotice('${def.name} bergabung di kost Anda!',
                icon: Icons.pets, color: const Color(0xFFEC407A));
          }
        }
      },
    )
        .onBroadcast(
      event: 'ghost',
      callback: _onGhostBroadcast,
    )
        .subscribe();
  }

  // ------------------------------------------------------- loket sampah

  void _onOfferChange(PostgresChangePayload p) {
    final r = p.newRecord;
    if (r.isEmpty || !mounted) return;
    final offer = Map<String, dynamic>.from(r);
    final id = (offer['id'] as num).toInt();
    final status = offer['status']?.toString();
    if (offer['receiver_id']?.toString() == _me) {
      setState(() {
        if (status == 'pending') {
          if (_seenOffers.add(id) && _remaining(offer['expires_at']) > 0) {
            _incomingOffer = offer;
          }
        } else if (_incomingOffer != null &&
            (_incomingOffer!['id'] as num).toInt() == id) {
          _incomingOffer = null;
        }
      });
    }
    if (offer['sender_id']?.toString() == _me &&
        p.eventType == PostgresChangeEvent.update) {
      final who = _name(offer['receiver_id']);
      if (status == 'accepted') _toast('$who menerima tawaran sampahmu.');
      if (status == 'declined') _toast('$who menolak tawaran sampahmu.');
    }
  }

  Future<void> _respondOffer(bool accept) async {
    final o = _incomingOffer;
    if (o == null || _offerBusy) return;
    setState(() => _offerBusy = true);
    try {
      final res = await _db.rpc('respond_trash_offer',
          params: {'p_offer': o['id'], 'p_accept': accept});
      if (!mounted) return;
      setState(() => _incomingOffer = null);
      if (res == 'accepted') {
        _toast(
            'Kamu menampung ${_num(o['trash_amount']).round()} sampah dan menerima ${_num(o['price']).round()} uang.');
      } else if (res == 'expired') {
        _toast('Tawaran sudah kedaluwarsa.');
      }
    } on PostgrestException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('$e', error: true);
    } finally {
      if (mounted) setState(() => _offerBusy = false);
    }
  }

  Future<void> _sendOffer(String target, int amount, int price) async {
    if (_offerBusy) return;
    setState(() => _offerBusy = true);
    try {
      await _db.rpc('offer_trash', params: {
        'p_room': widget.roomId,
        'p_target': target,
        'p_amount': amount,
        'p_price': price,
      });
      _toast('Tawaran dikirim ke ${_name(target)} (berlaku 10 dtk).');
    } on PostgrestException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('$e', error: true);
    } finally {
      if (mounted) setState(() => _offerBusy = false);
    }
  }

  // --------------------------------------------------------------- arwah

  bool get _iAmGhost {
    final s = _states[_me];
    return s != null && s['eliminated_at'] != null;
  }

  /// Pastikan tiap pemain tertimbun punya arwah (muncul dari atap rumahnya)
  /// dan arwah pemain yang hidup lagi (ronde baru) dihapus.
  void _syncGhosts() {
    final order = _order;
    for (final e in _states.entries) {
      final id = e.key;
      final out = e.value['eliminated_at'] != null;
      if (!out) {
        _ghosts.remove(id);
        continue;
      }
      final g = _ghosts[id];
      if (g == null) {
        final idx = max(0, order.indexOf(id));
        final jitter = (id.codeUnits.fold<int>(0, (a, b) => a + b) % 5 - 2) * 18.0;
        _ghosts[id] = KostGhost(
          id: id,
          name: _names[id] ?? 'Pemain',
          color: _wallFor(id),
          x: idx * kStreetSlotW + kStreetSlotW / 2 + jitter,
          y: 110,
        );
      } else {
        g.name = _names[id] ?? g.name;
      }
    }
  }

  void _ghostStep() {
    _syncGhosts();
    for (final g in _ghosts.values) {
      g.step();
    }
  }

  void _moveMyGhost(Offset local, Rect stage, {bool force = false}) {
    final g = _ghosts[_me];
    if (g == null) return;
    final sc = _cam.scale;
    final o = _cam.origin(stage);
    final maxX = max(20.0, _order.length * kStreetSlotW - 10.0);
    final wx = ((local.dx - o.dx) / sc).clamp(10.0, maxX).toDouble();
    final wy = ((local.dy - o.dy) / sc).clamp(30.0, 215.0).toDouble();
    g.moveTo(wx, wy);
    _broadcastGhost(g, force: force);
  }

  void _broadcastGhost(KostGhost g, {bool force = false}) {
    final now = sceneNowMs();
    if (!force && now - _lastGhostSendMs < 200) return; // maks ~5x per detik
    _lastGhostSendMs = now;
    try {
      _channel
          ?.sendBroadcastMessage(
          event: 'ghost', payload: {'id': _me, 'x': g.tx, 'y': g.ty})
          .then((_) {}, onError: (_) {});
    } catch (_) {}
  }

  void _onGhostBroadcast(Map<String, dynamic> raw) {
    final inner = raw['payload'];
    final p = inner is Map ? Map<String, dynamic>.from(inner) : raw;
    final id = p['id']?.toString();
    if (id == null || id == _me) return;
    _syncGhosts();
    _ghosts[id]?.moveTo(_num(p['x']), _num(p['y']));
  }

  // ------------------------------------------------------------ sinematik

  /// Listener per-frame: menjalankan jadwal sutradara & mengatur kamera
  /// sinematik secara halus (60 fps, bukan per-rebuild 20 Hz).
  void _cineStep() {
    final now = sceneNowMs();
    final ended = _cine.tick(now);
    if (_lastOrder.isNotEmpty && _lastStage != Rect.zero) {
      final ov = _cine.camera(
        now: now,
        order: _lastOrder,
        fitOne: _lastFitOne,
        fitAll: _lastFitAll,
        tgtCx: _lastTgtCx,
        tgtScale: _lastTgtScale,
      );
      if (ov != null) {
        _cam.setTarget(ov.cx, ov.scale);
        _cam.cx = ov.cx;
        _cam.scale = ov.scale;
      }
    }
    if (ended && mounted) setState(() {});
  }

  /// Intro hanya diputar di awal pertandingan (bukan saat masuk ulang di
  /// tengah permainan atau setelah selesai).
  void _maybePlayIntro() {
    if (_introChecked) return;
    _introChecked = true;
    if (_room['status'] == 'finished') return;
    if (_room['started_at'] != null && _elapsedSec > 40) return;
    final order = _order;
    if (order.isEmpty) return;
    Sfx.instance.play(_isSurvival ? 'opening-single-player' : 'opening',
        minGapMs: 0);
    _cine.playIntro(
      order: order,
      names: {for (final id in order) id: _names[id] ?? 'Pemain'},
      myId: _states.containsKey(_me) ? _me : null,
    );
  }

  void _playPolice(String? targetId, String? actorId, int amount,
      {required bool reflected}) {
    if (targetId == null) return;
    Sfx.instance.play('police', minGapMs: 800);
    _cine.playPolice(
      targetId: targetId,
      targetName: _names[targetId] ?? 'Pemain',
      reflected: reflected,
      actorName: _names[actorId] ?? 'Pemain',
      amount: amount,
      iAmTarget: targetId == _me,
      camCx: _cam.cx,
      camScale: _cam.scale,
    );
  }

  void _ensureFx(String? id, FxType t,
      {double amount = 0, String? peer, int durMs = 0}) {
    if (id == null) return;
    final list = _fx[id] ??= <KostFx>[];
    final hasRecent =
    list.any((f) => f.type == t && f.amount == amount && f.age < 650);
    if (!hasRecent) {
      list.add(KostFx(t, amount: amount, peerId: peer, durMs: durMs));
    }
  }

  void _addFx(Map<String, dynamic> e) {
    final actor = e['actor_id']?.toString();
    final target = e['target_id']?.toString();
    final amt = _num(e['amount']);

    // Peringatan: jendela Tangkis terbuka untuk saya
    const launches = {
      'throw_launch',
      'sack_launch',
      'smog_launch',
      'inspect_launch',
    };
    if (launches.contains(e['type']) && target == _me) {
      Sfx.instance.play('beep-warning', minGapMs: 400);
    }

    switch (e['type']) {
      case 'burn':
        _ensureFx(actor, FxType.burn, amount: amt);
        Sfx.instance.play('fireburn', gain: actor == _me ? 1.0 : 0.6);
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
      case 'throw_launch':
      // Jendela Tangkis dibuka. Animasi lempar BELUM jalan: korban melihat
      // cincin Tangkis, penyerang hanya bersiap (wind-up dari player_state).
        break;
      case 'throw':
      // Tak ditangkis -> sekarang baru dilempar, terbang ke korban.
        _launchShot(actor, target, amount: amt);
        break;
      case 'parry':
      // actor = penangkis, target = pelempar: sampah dipantulkan balik.
      // Alur: pelempar melempar -> kena perisai penangkis -> memantul balik.
        _launchShot(target, actor, amount: amt, bounce: true);
        break;
      case 'sack_launch':
      case 'smog_launch':
      // Jendela Tangkis dibuka (sama seperti throw_launch).
        break;
      case 'sack':
        _launchShot(actor, target, amount: amt, kind: ShotKind.sack);
        break;
      case 'parry_sack':
        _launchShot(target, actor,
            amount: amt, bounce: true, kind: ShotKind.sack);
        break;
      case 'smog':
        _launchShot(actor, target, amount: 0, kind: ShotKind.smog);
        break;
      case 'parry_smog':
        _launchShot(target, actor,
            amount: 0, bounce: true, kind: ShotKind.smog);
        break;
      case 'firework':
      // amount 1 = percikan terjadi (sampah -1, polusi +15), 0 = zonk
        _launchShot(actor, target,
            amount: 0, kind: ShotKind.firework, spark: amt > 0);
        break;
      case 'parry_firework':
      // actor = penangkis, target = pelempar: kembang api padam di perisai
        _launchShot(target, actor,
            amount: 0, kind: ShotKind.firework, fizzle: true);
        break;
      case 'inspect_launch':
      // Penyerang "menelepon polisi": kartu telepon tampil selama jendela
      // Tangkis (tidak menghalangi tombol Tangkis).
        _cine.playCall(
          actorName: _names[actor] ?? 'Pemain',
          targetName: _names[target] ?? 'Pemain',
          iAmActor: actor == _me,
          iAmTarget: target == _me,
        );
        break;
      case 'inspect':
        _ensureFx(target, FxType.inspect, amount: amt);
        _playPolice(target, actor, amt.round(), reflected: false);
        break;
      case 'parry_inspect':
      // actor = penangkis, target = penyerang: polisi malah mendatangi penyerang
        _ensureFx(actor, FxType.parry, amount: amt);
        _ensureFx(target, FxType.inspect, amount: amt);
        _playPolice(target, actor, amt.round(), reflected: true);
        break;
      case 'hijack':
      // amount 1 = sisi pembajak (truk rampasan tiba), 2 = sisi korban
      // (disergap). peer = lawannya, supaya truk bergerak antar kedua rumah;
      // durasi mengikuti jarak rumah (sama untuk kedua sisi).
        final ha = _order.indexOf(actor ?? '');
        final hb = _order.indexOf(target ?? '');
        final hDist = (ha < 0 || hb < 0) ? 1 : max(1, (ha - hb).abs());
        final hDur = hijackDurationMs(hDist);
        _ensureFx(actor, FxType.hijack, amount: 1, peer: target, durMs: hDur);
        if (actor == _me || target == _me) {
          Sfx.instance.play('truck-beep');
          Future<void>.delayed(const Duration(milliseconds: 700),
                  () => Sfx.instance.play('truck-moving'));
        }
        _ensureFx(target, FxType.hijack, amount: 2, peer: actor, durMs: hDur);
        break;
      case 'emoji':
        _syncGhosts();
        final eg = actor == null ? null : _ghosts[actor];
        if (eg != null) {
          // arwah berseru: gelembung muncul di arwahnya, bukan di rumah
          if (!(eg.emojiCode == amt.round() &&
              sceneNowMs() - eg.emojiMs < 900)) {
            eg.emojiCode = amt.round();
            eg.emojiMs = sceneNowMs();
          }
        } else {
          _ensureFx(actor, FxType.emoji, amount: amt);
        }
        break;
      case 'quake_hit':
      // dampak gempa di kost target (sampah tumpah, gudang retak)
        _ensureFx(target, FxType.quake, amount: amt);
        Sfx.instance.play('collapse', gain: target == _me ? 1.0 : 0.6);
        break;
      case 'eliminated':
        if (target != null &&
            _cine.playBuried(
              id: target,
              name: _names[target] ?? 'Pemain',
              isMe: target == _me,
              camCx: _cam.cx,
              camScale: _cam.scale,
            )) {
          // debu runtuh baru muncul tepat di puncak adegan
          (_fx[target] ??= <KostFx>[]).add(KostFx(
            FxType.collapse,
            amount: amt,
            delayMs: kBuriedCollapseMs,
          ));
          Future<void>.delayed(Duration(milliseconds: kBuriedCollapseMs),
                  () => Sfx.instance.play('building-collapse', minGapMs: 0));
        } else {
          _ensureFx(target, FxType.collapse, amount: amt);
          Sfx.instance.play('building-collapse', minGapMs: 0);
        }
        break;
      default:
        break;
    }
  }

  /// Mulai lemparan sampah dari rumah [from] ke rumah [to]. Durasi terbang &
  /// lambungan mengikuti jarak (jumlah rumah di antara keduanya); dampak di
  /// rumah tujuan ditunda agar pas saat sampah mendarat.
  void _launchShot(String? from, String? to,
      {required double amount,
        bool bounce = false,
        ShotKind kind = ShotKind.normal,
        bool spark = false,
        bool fizzle = false}) {
    if (from == null || to == null) return;
    final order = _order;
    final a = order.indexOf(from);
    final b = order.indexOf(to);
    final dist = (a < 0 || b < 0) ? 1 : max(1, (a - b).abs());
    final base = min(2600, 1100 + 380 * (dist - 1));
    // Pantulan = dua ruas lintasan (pergi + balik), jadi durasinya lebih panjang.
    final dur = bounce ? (base * 1.6).round() : base;
    _shots.add(KostShot(
      fromId: from,
      toId: to,
      durMs: dur,
      bounce: bounce,
      kind: kind,
      spark: spark,
      fizzle: fizzle,
      bags: kind == ShotKind.sack ? 3 : (kind == ShotKind.smog ? 5 : 4),
    ));
    _ensureFx(from, FxType.outgoing, amount: amount, peer: to);
    // Hanya lemparan yang membawa sampah meninggalkan efek "kena sampah".
    final lands = kind == ShotKind.normal || kind == ShotKind.sack;

    // Kantong ke-j mendarat/menyentuh di (dur - 240) + 80j - ... ; dampak
    // dijadwalkan agar pas dengan itu (lihat KostStreetPainter._paintShots).
    final flight = dur - 240;
    if (bounce) {
      // kantong pertama menyentuh perisai di pertengahan lintasan
      (_fx[to] ??= <KostFx>[]).add(KostFx(
        FxType.parry,
        amount: amount,
        delayMs: max(0, flight ~/ 2 - 60),
      ));
      // lalu mendarat di pelempar
      if (lands) {
        (_fx[from] ??= <KostFx>[]).add(KostFx(
          FxType.incoming,
          amount: amount,
          peerId: to,
          delayMs: max(0, flight - 730),
        ));
      }
    } else if (fizzle) {
      // kembang api ditangkis: padam di perisai penangkis
      (_fx[to] ??= <KostFx>[]).add(KostFx(
        FxType.parry,
        amount: amount,
        delayMs: max(0, flight - 300),
      ));
    } else if (lands) {
      (_fx[to] ??= <KostFx>[]).add(KostFx(
        FxType.incoming,
        amount: amount,
        peerId: from,
        delayMs: max(0, flight - 730),
      ));
    }
  }

  Future<void> _sendEmoji(int code) async {
    final now = sceneNowMs();
    final ghost = _iAmGhost;
    // Sama dengan server: pemain hidup 1,5 dtk, arwah 5 dtk.
    if (now - _lastEmojiSentMs < (ghost ? 5000 : 1500)) {
      if (ghost) _toast('Arwah perlu 5 detik untuk berseru lagi.');
      return;
    }
    _lastEmojiSentMs = now;

    // Tampilkan langsung di layar sendiri secara instan (optimistic UI)
    if (ghost) {
      _syncGhosts();
      final g = _ghosts[_me];
      if (g != null) {
        g.emojiCode = code;
        g.emojiMs = sceneNowMs();
      }
    } else {
      _ensureFx(_me, FxType.emoji, amount: code.toDouble());
    }
    setState(() => _emojiBarOpen = false);

    try {
      await _db.rpc('send_emoji', params: {
        'p_room': widget.roomId,
        'p_code': code,
      });
    } catch (e) {
      _toast('Gagal mengirim reaksi: $e', error: true);
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
          .select('player_id, player_name, style')
          .eq('room_id', widget.roomId);
      // Tabel gudang bisa saja belum dibuat (warehouse.sql): jangan gagalkan load.
      List<dynamic> whRows = const [];
      try {
        whRows = await _db
            .from('player_warehouse')
            .select()
            .eq('room_id', widget.roomId);
      } catch (_) {}
      List<dynamic> petRows = const [];
      try {
        petRows = await _db
            .from('player_pets')
            .select()
            .eq('room_id', widget.roomId);
      } catch (_) {}
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
        for (final r in whRows) {
          final m = Map<String, dynamic>.from(r as Map);
          _wh[m['player_id'] as String] = m;
        }
        _petRows.clear();
        for (final r in petRows) {
          final m = Map<String, dynamic>.from(r as Map);
          (_petRows[m['player_id'] as String] ??= {})[(m['slot'] as num).toInt()] = m;
        }
        for (final n in names) {
          _names[n['player_id'] as String] = n['player_name'] as String;
          final st = KostStyle.fromJson(n['style']);
          if (st != null && !st.isEmpty) {
            _styles[n['player_id'] as String] = st;
          } else {
            _styles.remove(n['player_id'] as String);
          }
        }
        if (_events.isEmpty) {
          _events.addAll(ev.map((e) => Map<String, dynamic>.from(e)));
        }
        if (!_focusInit) {
          _focusInit = true;
          // Pemain langsung zoom ke rumahnya; penonton melihat semua tetangga.
          _focusId = _states.containsKey(_me) ? _me : null;
        }
        _loaded = true;
      });
      _maybePlayIntro();
    } catch (e) {
      _toast('Gagal memuat: $e', error: true);
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
      // Gudang: bayar hasil pemrosesan ke kas & muat truk yang sudah tiba.
      final mine = _states[_me];
      if (_num(_wh[_me]?['tier']) > 0 &&
          mine != null &&
          mine['eliminated_at'] == null) {
        _whSettle();
      }
    } catch (_) {}
  }

  Future<void> _whSettle() async {
    try {
      await _db.rpc('warehouse_settle', params: {'p_room': widget.roomId});
    } catch (_) {}
  }

  /// Suara konfirmasi untuk aksi yang BERHASIL. Aksi yang sudah punya suara
  /// sendiri (build_room, upgrade_kost_tier, burn, lemparan, sabotase,
  /// warehouse_pour) tidak ikut di sini.
  void _sfxForAction(String fn) {
    switch (fn) {
      case 'warehouse_call_truck':
        Sfx.instance.play('truck-beep');
        Future<void>.delayed(const Duration(milliseconds: 700),
                () => Sfx.instance.play('truck-moving'));
      case 'upgrade_waste':
      case 'hire_hauler':
      case 'buy_defense':
      case 'buy_pet':
      case 'release_pet':
      case 'rename_pet':
      case 'warehouse_upgrade_tier':
      case 'warehouse_buy_comp':
      case 'open_trash_booth':
        Sfx.instance.play('confirm');
    }
  }

  Future<void> _act(String fn, [Map<String, dynamic> extra = const {}]) async {
    if (_activeRpc != null) return;
    setState(() => _activeRpc = fn);

    try {
      await _db.rpc(fn, params: {'p_room': widget.roomId, ...extra});
      _sfxForAction(fn);
    } on PostgrestException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('$e', error: true);
    } finally {
      if (mounted) setState(() => _activeRpc = null);
    }
  }

  /// Semua pesan singkat lewat sini (tidak lagi SnackBar yang menutupi bilah
  /// aksi). Tampil sebagai pil kecil di bawah HUD.
  void _toast(String m, {bool error = false}) {
    if (!mounted) return;
    _showNotice(
      m.replaceFirst(RegExp(r'^Exception:\s*'), ''),
      icon: error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
      color: error ? const Color(0xFFE53935) : const Color(0xFF546E7A),
      ms: error ? 4200 : 3200,
    );
  }

  void _showNotice(
      String text, {
        IconData icon = Icons.info_outline_rounded,
        Color color = const Color(0xFF546E7A),
        int ms = 3600,
      }) {
    if (!mounted) return;
    _noticeTimer?.cancel();
    setState(() => _notice = _Notice(++_noticeSeq, text, icon, color));
    _noticeTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  void _dismissNotice() {
    _noticeTimer?.cancel();
    if (mounted) setState(() => _notice = null);
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

  // ---- visual event: durasi (cermin _event_duration di server), fade & rantai
  static const Map<String, double> _evDurTable = {
    'heavy_rain': 12,
    'strong_wind': 20,
    'drought': 25,
    'blackout': 18,
    'rat_plague': 22,
    'earthquake': 8,
    'night_market': 20,
  };
  static const double _evFadeSec = 1.6;

  String? _evSeen; // event aktif terakhir yang terlihat
  String? _evLinger; // event yang baru berakhir (masih memudar)
  int _evEndMs = 0;
  bool _evChained = false; // hujan deras -> banjir langsung berlanjut

  String? _pendSeen;
  bool _endSfxDone = false;

  // ---- suara pintu: penghuni keluar/masuk (deteksi tepi "baru terbuka")
  final Map<int, bool> _doorWasOpen = {};

  /// Harus sama dengan seed pada KostSceneData (lihat _sceneFor).
  int _sceneSeed(String id) =>
      id.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) % 1000);

  void _onDoor(int seed, bool open) {
    final was = _doorWasOpen[seed] ?? false;
    _doorWasOpen[seed] = open;
    if (!open || was || !mounted) return;
    // rumah saya: jelas; rumah lawan: pelan supaya tidak ramai
    final mine = seed == _sceneSeed(_me);
    Sfx.instance.play('door', gain: mine ? 1.0 : 0.25, minGapMs: mine ? 300 : 700);
  }

  void _trackWorldEvent() {
    // peringatan ±4 dtk sebelum event dunia dimulai
    final pend = _pendingWorldEvent;
    if (pend != _pendSeen) {
      _pendSeen = pend;
      if (pend != null) Sfx.instance.play('beep-warning', minGapMs: 400);
    }
    final ev = _activeWorldEvent;
    if (ev == _evSeen) return;
    final prev = _evSeen;
    _evChained = prev == 'heavy_rain' && ev == 'rain_flood';
    if (ev == null) {
      _evLinger = prev;
      _evEndMs = sceneNowMs();
    } else {
      _evLinger = null;
    }
    _evSeen = ev;
    // Hujan berulang (loop) selama event hujan; berhenti saat event berakhir
    // (hujan deras -> banjir menyambung tanpa putus).
    if (ev == 'rain_flood' || ev == 'heavy_rain') {
      Sfx.instance.rainStart();
    } else {
      Sfx.instance.rainStop();
    }
  }

  double get _evSinceEnd => (sceneNowMs() - _evEndMs) / 1000.0;

  /// Event untuk VISUAL saja: yang aktif, atau yang baru berakhir (memudar).
  /// Logika UI (blokir tombol dll) tetap memakai [_activeWorldEvent].
  String? get _visualWorldEvent {
    _trackWorldEvent();
    final ev = _activeWorldEvent;
    if (ev != null) return ev;
    if (_evLinger != null && _evSinceEnd < _evFadeSec) return _evLinger;
    return null;
  }

  double get _visualEventAge {
    final ev = _activeWorldEvent;
    if (ev == null) return 99;
    final left = _remaining(_room['world_event_until']);
    return max(0.0, (_evDurTable[ev] ?? 22.0) - left);
  }

  /// Sisa detik event; negatif = sudah selesai & sedang memudar.
  double get _visualEventLeft {
    if (_activeWorldEvent != null) {
      return _remaining(_room['world_event_until']);
    }
    if (_evLinger != null && _evSinceEnd < _evFadeSec) return -_evSinceEnd;
    return 99;
  }

  /// Event yang sudah diumumkan (peringatan ±4 dtk) tapi belum aktif.
  String? get _pendingWorldEvent {
    final ev = _room['pending_event']?.toString();
    if (ev == null || ev.isEmpty) return null;
    if (_remaining(_room['pending_event_at']) <= 0) return null;
    return ev;
  }

  String _name(dynamic id) {
    if (id == null) return '?';
    if (id == _me) return 'Anda';
    return _names[id] ?? 'Pemain';
  }

  // ---------------------------------------------- v2: bounty, dendam, tekanan

  String? get _bountyId => _room['bounty_id']?.toString();

  double get _elapsedSec {
    final t = _ts(_room['started_at']);
    if (t == null) return 0;
    return max(0.0, _serverNow.difference(t).inMilliseconds / 1000);
  }

  /// Pengali laju sampah: +20% tiap 2 menit (harus sama dengan sync_room_state).
  /// Mode Kesintasan (singleplayer): bertahan selama mungkin.
  bool get _isSurvival => _room['mode'] == 'survival';

  /// Pengali laju sampah. HARUS sama dengan public._pressure_for() di SQL.
  ///   versus   : +20% tiap 2 menit
  ///   survival : 1 + 0.12*m + 0.01*m^2  (m = menit, mulus & mempercepat)
  double get _pressure {
    if (_isSurvival) {
      final m = _elapsedSec / 60;
      return 1.0 + 0.12 * m + 0.01 * m * m;
    }
    return 1.0 + 0.2 * (_elapsedSec / 120).floor();
  }

  /// Survival masih berjalan & pemain masih hidup (untuk konfirmasi menyerah).
  bool get _survivalLive {
    if (!_isSurvival || _room['status'] != 'playing') return false;
    final me = _states[_me];
    return me != null && me['eliminated_at'] == null;
  }

  String _fmtDur(num sec) {
    final s = sec.floor();
    return '${(s ~/ 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toString().padLeft(2, '0')}';
  }

  /// Dialog konfirmasi menyerah; skor tetap tercatat (lama bertahan sampai kini).
  Future<void> _confirmQuitSurvival() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16281F),
        title: const Text('Menyerah?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: Text(
          'Kost dianggap tertimbun. Waktu bertahan ${_fmtDur(_elapsedSec)} '
              'tetap dicatat di papan skor.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Lanjut main'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Menyerah'),
          ),
        ],
      ),
    );
    if (ok == true) await _quitSurvival();
  }

  Future<void> _quitSurvival() async {
    try {
      await _db.rpc('survival_quit', params: {'p_room': widget.roomId});
    } catch (_) {}
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Siklus siang-malam: satu hari penuh = [_dayCycleSec] detik. Diturunkan
  /// dari waktu server (started_at) sehingga SAMA di semua pemain. Murni visual.
  static const double _dayCycleSec = 300;

  /// Mulai di pagi hari (0.25 = matahari terbit, 0.5 = tengah hari).
  static const double _dayStartPhase = 0.30;

  /// 0..1 (0 = tengah malam, 0.5 = tengah hari); null sebelum ronde dimulai.
  double? get _dayPhase {
    if (_room['started_at'] == null) return null;
    return (_dayStartPhase + _elapsedSec / _dayCycleSec) % 1.0;
  }

  String _clock(double sec) {
    final s = sec.floor();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  bool _hasRevenge(Map<String, dynamic>? me, String rivalId) =>
      me != null &&
          me['revenge_target']?.toString() == rivalId &&
          _remaining(me['revenge_until']) > 0;

  // Sama dengan SQL: dasar 90, bounty 63 (-30%), dendam dibagi dua (pembulatan ke atas)
  int _inspectCost(String rivalId, Map<String, dynamic>? me) {
    var c = rivalId == _bountyId ? 63 : 90;
    if (_hasRevenge(me, rivalId)) c = (c + 1) ~/ 2;
    return c;
  }

  int _hijackCost(String rivalId, Map<String, dynamic>? me) =>
      _hasRevenge(me, rivalId) ? 35 : 70;

  Future<void> _tangkis() async {
    if (_tangkisBusy) return;
    setState(() => _tangkisBusy = true);
    try {
      await _db.rpc('tangkis', params: {'p_room': widget.roomId});
    } on PostgrestException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('$e', error: true);
    } finally {
      if (mounted) setState(() => _tangkisBusy = false);
    }
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
    var delta = switch (_activeWorldEvent) {
      'eco_subsidy' || 'heavy_rain' => -0.8,
      'strong_wind' => -1.2,
      'drought' => -0.1,
      _ => -0.4,
    };
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
      case 'heavy_rain':
        return (
        'HUJAN DERAS · Polusi cepat turun, Sampah +15%',
        Icons.water_drop,
        Colors.blue.shade700,
        );
      case 'strong_wind':
        return (
        'ANGIN KENCANG · Bakar diblokir, Polusi cepat hilang, Lemparan meleset',
        Icons.air,
        Colors.blueGrey.shade600,
        );
      case 'drought':
        return (
        'KEMARAU · Polusi susah turun, Bakar +50% polusi, Sampah menumpuk bau',
        Icons.wb_sunny,
        Colors.orange.shade800,
        );
      case 'blackout':
        return (
        'MATI LISTRIK · Income -40%, Sensor IoT mati, Tangkis lebih lambat',
        Icons.power_off,
        Colors.grey.shade800,
        );
      case 'rat_plague':
        return (
        'WABAH TIKUS · Sampah +30%, Kucing 2x lebih ampuh',
        Icons.bug_report,
        Colors.brown.shade600,
        );
      case 'earthquake':
        return (
        'GEMPA BUMI · Sampah tumpah, Bangun & Tuang diblokir',
        Icons.vibration,
        Colors.brown.shade800,
        );
      case 'night_market':
        return (
        'PASAR MALAM · Income +20%, Hewan -20%',
        Icons.festival,
        Colors.pink.shade600,
        );
      default:
        return (ev, Icons.public, Colors.blueGrey);
    }
  }

  String _trashStage(double ratio, int wasteLevel) {
    if (ratio >= 0.9) return 'KRITIS: income -60%';
    if (ratio >= 0.75) return 'Penghuni kabur: income -40%';
    if (ratio >= 0.5) return 'Mulai bau: income -15%';
    if (wasteLevel > 0 && ratio > 1.0 / 3.0) {
      return 'Kotak penuh! Sampah mulai meluber ke luar';
    }
    return 'Tertampung di kotak sampah';
  }

  Color _trashColor(double ratio) {
    if (ratio >= 0.9) return Colors.red.shade700;
    if (ratio >= 0.75) return Colors.deepOrange;
    if (ratio >= 0.5) return Colors.amber.shade800;
    if (ratio > 1.0 / 3.0) return Colors.lightGreen.shade600;
    return Colors.green.shade700;
  }

  String _warnText(String ev) {
    switch (ev) {
      case 'heavy_rain':
        return 'PERINGATAN: Awan gelap menggulung, hujan deras segera turun!';
      case 'strong_wind':
        return 'PERINGATAN: Angin kencang mendekat! Jangan bakar sampah.';
      case 'drought':
        return 'PERINGATAN: Cuaca makin terik, kemarau segera tiba.';
      case 'blackout':
        return 'PERINGATAN: Lampu berkedip, mati listrik segera terjadi!';
      case 'rat_plague':
        return 'PERINGATAN: Tikus berdatangan dari selokan!';
      case 'earthquake':
        return 'PERINGATAN: TANAH MULAI BERGETAR! Gempa sebentar lagi!';
      case 'night_market':
        return 'KABAR: Lampion dipasang, pasar malam segera dibuka.';
      case 'rain_flood':
        return 'PERINGATAN: Banjir segera datang, siapkan truk!';
      case 'hauler_strike':
        return 'KABAR: Tukang sampah berencana mogok, sewa truk sekarang!';
      case 'new_semester':
        return 'KABAR: Mahasiswa baru mulai berdatangan.';
      case 'eco_subsidy':
        return 'KABAR: Pemerintah akan menggelar Subsidi Hijau.';
      default:
        return '';
    }
  }

  String _eventText(Map<String, dynamic> e) {
    final a = _name(e['actor_id']);
    final t = _name(e['target_id']);
    final amt = _num(e['amount']).round();
    final type = e['type']?.toString() ?? '';
    if (type.startsWith('event_warn_')) {
      return _warnText(type.substring('event_warn_'.length));
    }
    switch (e['type']) {
      case 'quake_hit':
        return e['target_id']?.toString() == _me
            ? 'GEMPA! Sampah tumpah +$amt di kost-mu.'
            : '';
      case 'event_heavy_rain':
        return 'CUACA: Hujan deras mengguyur kawasan kost!';
      case 'event_strong_wind':
        return 'CUACA: Angin kencang! Pembakaran sampah dilarang.';
      case 'event_drought':
        return 'CUACA: Musim kemarau, udara panas dan kering.';
      case 'event_blackout':
        return 'DARURAT: Mati listrik! Income turun.';
      case 'event_rat_plague':
        return 'WABAH: Tikus menyerbu kawasan kost!';
      case 'event_earthquake':
        return 'BENCANA: GEMPA BUMI! Pegangan yang kuat!';
      case 'event_night_market':
        return 'EVENT: Pasar Malam dibuka! Hewan diskon 20%.';
      case 'burn':
        return '$a membakar $amt sampah! Polusi naik.';
      case 'throw_launch':
        return t == 'Anda'
            ? 'AWAS! $a melempar sampah ke kost-mu. TANGKIS sekarang!'
            : '$a bersiap melempar sampah ke kost $t…';
      case 'throw':
        return t == 'Anda'
            ? '$a melempar $amt sampah ke kost-mu!'
            : '$a melempar $amt sampah ke kost $t.';
      case 'inspect_launch':
        return t == 'Anda'
            ? 'AWAS! $a mengirim Sidak Dinas ke kost-mu. TANGKIS sekarang!'
            : '$a mengirim Sidak Dinas ke kost $t…';
      case 'parry':
        return '$a menangkis & memantulkan $amt sampah ke $t!';
      case 'parry_inspect':
        return '$a memantulkan Sidak Dinas! Denda $amt menimpa $t.';
      case 'sack_launch':
        return t == 'Anda'
            ? 'AWAS! $a melempar SEKARUNG sampah ke kost-mu. TANGKIS sekarang!'
            : '$a menyiapkan sekarung sampah untuk kost $t…';
      case 'sack':
        return t == 'Anda'
            ? '$a menimpakan sekarung $amt sampah ke kost-mu!'
            : '$a menimpakan sekarung $amt sampah ke kost $t.';
      case 'parry_sack':
        return '$a menangkis & memantulkan sekarung $amt sampah ke $t!';
      case 'smog_launch':
        return t == 'Anda'
            ? 'AWAS! $a melempar sampah beracun ke kost-mu. TANGKIS sekarang!'
            : '$a menyiapkan sampah beracun untuk kost $t…';
      case 'smog':
        return t == 'Anda'
            ? '$a menebar gas beracun ke kost-mu! Income turun sementara.'
            : '$a menebar gas beracun ke kost $t. Polusi naik.';
      case 'parry_smog':
        return '$a memantulkan gas beracun! Asapnya menimpa $t.';
      case 'firework':
        return amt > 0
            ? '$a melempar kembang api ke $t. Percikan membakar sampah & polusi naik!'
            : '$a melempar kembang api ke $t. Cuma gertakan!';
      case 'parry_firework':
        return '$a menangkis… ternyata kembang api gertakan dari $t!';
      case 'booth_open':
        return '$a membuka Loket Sampah.';
      case 'offer_made':
        return t == 'Anda'
            ? '$a menawarimu $amt uang untuk menampung sampahnya.'
            : '$a menawar $t: titip sampah, bayar $amt.';
      case 'offer_accept':
        return '$a menerima titipan $amt sampah dari $t.';
      case 'offer_decline':
        return '$a menolak tawaran Loket dari $t.';
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
      case 'emoji':
        return '$a bereaksi ${emojiFromCode(amt)}';
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
    if (type is String) {
      if (type.startsWith('event_warn_')) {
        return (Icons.warning_amber_rounded, Colors.amber);
      }
      if (type == 'quake_hit') return (Icons.vibration, Colors.brown);
      if (type.startsWith('event_')) {
        final i = _worldEventInfo(type.substring('event_'.length));
        return (i.$2, i.$3);
      }
    }
    switch (type) {
      case 'burn':
        return (Icons.local_fire_department, Colors.deepOrange);
      case 'throw':
      case 'throw_launch':
        return (Icons.rocket_launch, Colors.brown);
      case 'inspect_launch':
        return (Icons.policy, Colors.redAccent);
      case 'parry':
      case 'parry_inspect':
        return (Icons.security, Colors.lightBlueAccent);
      case 'sack':
      case 'sack_launch':
      case 'parry_sack':
        return (Icons.shopping_bag, Colors.brown);
      case 'smog':
      case 'smog_launch':
      case 'parry_smog':
        return (Icons.cloud, Colors.lightGreen.shade700);
      case 'firework':
      case 'parry_firework':
        return (Icons.celebration, Colors.amber);
      case 'booth_open':
      case 'offer_made':
      case 'offer_accept':
      case 'offer_decline':
        return (Icons.storefront, Colors.teal);
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
      case 'emoji':
        return (Icons.emoji_emotions, Colors.amberAccent);
      case 'eliminated':
        return (Icons.warning_amber_rounded, Colors.red.shade700);
      default:
        return (Icons.public, Colors.cyanAccent);
    }
  }

  Color _wallFor(String id) {
    final custom = _styles[id]?.wallColor;
    if (custom != null) return custom;
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

  /// (jenis, sisa detik) persiapan serangan rumah [id]:
  /// jenis 0 = tidak, 1 = bersiap melempar, 2 = bersiap sidak.
  (int, double) _chargeInfo(String id) {
    for (final s in _states.values) {
      if (s['pending_attack_from']?.toString() != id) continue;
      final left = _remaining(s['pending_attack_until']);
      if (left > 0) {
        return (s['pending_attack_type'] == 'inspect' ? 2 : 1, left);
      }
    }
    return (0, 0.0);
  }

  KostSceneData _sceneData(String id, Map<String, dynamic> s,
      {required bool compact, bool? facingRight}) {
    final live = _live(s);
    final cap = max(1.0, _num(s['trash_capacity']));
    final wh = _whLive(id);
    // Selama gerobak memuat isi kotak, kotak kiri masih tampak penuh.
    var shownTrash = live.trash;
    final pa = wh.pourAgeMs;
    if (pa != null && pa < Wh.pourPickupMs) shownTrash += wh.lastPourAmount;
    return KostSceneData(
      rooms: _num(s['rooms_count']).toInt(),
      maxRooms: _maxRooms,
      defense: _num(s['defense']).toInt(),
      wasteLevel: _num(s['waste_level']).toInt(),
      kostTier: _num(s['kost_tier']).toInt(),
      worldEvent: _visualWorldEvent,
      pendingEvent: _pendingWorldEvent,
      pendingLeft: _remaining(_room['pending_event_at']),
      eventAge: _visualEventAge,
      eventLeft: _visualEventLeft,
      eventChained: _evChained,
      sealedLeft: _remaining(s['sealed_until']),
      trashRatio: (shownTrash / cap).clamp(0.0, 1.0).toDouble(),
      pollution: _pollution,
      eliminated: s['eliminated_at'] != null,
      protectedLeft: _remaining(s['protected_until']),
      haulProgress: _haulProgress(id, s),
      burnPenalty: _remaining(s['burn_penalty_until']) > 0,
      smog: _remaining(_room['smog_until']) > 0,
      fx: _fx[id] ?? const <KostFx>[],
      wall: _wallFor(id),
      style: _styles[id],
      owner: compact ? null : _ownerFor(id),
      compact: compact,
      facingRight: facingRight ?? !compact,
      isBounty: id == _bountyId,
      attackLeft: _remaining(s['pending_attack_until']),
      charge: _chargeInfo(id).$1,
      chargeLeft: _chargeInfo(id).$2,
      // 0..999, stabil di semua perangkat (tanpa hashCode bawaan Dart)
      seed: id.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) % 1000),
      dayPhase: _dayPhase,
      warehouse: wh,
      pets: compact ? null : _petsFor(id),
      biome: KostBiome.forRoom(widget.roomId),
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

  // ------------------------------------------------- jalan & kamera zoom

  /// Urutan rumah dari kiri ke kanan. Diurutkan berdasarkan id pemain sehingga
  /// semua pemain melihat tetangga yang sama di posisi yang sama.
  List<String> get _order => _states.keys.toList()..sort();

  void _zoomHome() =>
      setState(() => _focusId = _states.containsKey(_me) ? _me : null);

  void _zoomAll() => setState(() => _focusId = null);

  void _zoomTo(String id) => setState(() => _focusId = id);

  void _stepFocus(int dir) {
    final order = _order;
    if (order.isEmpty) return;
    final cur = _focusId == null ? -1 : order.indexOf(_focusId!);
    final next = cur < 0
        ? (dir > 0 ? 0 : order.length - 1)
        : (cur + dir).clamp(0, order.length - 1).toInt();
    setState(() => _focusId = order[next]);
  }

  /// Arah lemparan: rumah menghadap ke tetangga yang sedang terlibat serangan.
  bool _facingRightFor(String id, List<String> order) {
    final mine = order.indexOf(id);
    // Sedang menyiapkan serangan: hadap ke korban yang punya jendela Tangkis.
    for (final s in _states.values) {
      if (s['pending_attack_from']?.toString() == id &&
          _remaining(s['pending_attack_until']) > 0) {
        final other = order.indexOf(s['player_id'].toString());
        if (other >= 0 && mine >= 0 && other != mine) return other > mine;
      }
    }
    final list = _fx[id];
    if (list == null || mine < 0) return true;
    for (var i = list.length - 1; i >= 0; i--) {
      final f = list[i];
      if ((f.type == FxType.outgoing || f.type == FxType.incoming) &&
          f.peerId != null) {
        final other = order.indexOf(f.peerId!);
        if (other >= 0 && other != mine) return other > mine;
      }
    }
    return true;
  }

  void _onWheel(
      PointerSignalEvent e, Rect stage, List<String> order, String? focusId) {
    if (e is! PointerScrollEvent) return;
    final now = sceneNowMs();
    if (now - _lastWheelMs < 320) return;
    _lastWheelMs = now;
    if (e.scrollDelta.dy > 0) {
      _zoomAll();
    } else if (e.scrollDelta.dy < 0 && focusId == null) {
      final i = _cam.houseAt(e.localPosition.dx, stage, order.length);
      if (i != null) {
        _zoomTo(order[i]);
      } else {
        _zoomHome();
      }
    }
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    // Survival: tombol kembali (HUD & sistem) meminta konfirmasi menyerah.
    return PopScope(
      canPop: !_survivalLive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuitSurvival();
      },
      child: _buildGame(context),
    );
  }

  Widget _buildGame(BuildContext context) {
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
    final canAct =
        alive && !finished && _activeRpc == null && !_cine.blocksInput;
    final myAttackLeft = (me != null && alive && !finished)
        ? _remaining(me['pending_attack_until'])
        : 0.0;
    if (myAttackLeft <= 0) _atkTotal = 0;

    // Semua rumah (termasuk milik sendiri) berderet bertetangga di satu jalan.
    final order = _order;
    final n = order.length;
    final focusId =
    (_focusId != null && _states.containsKey(_focusId)) ? _focusId : null;
    final focusState = focusId == null ? null : _states[focusId];
    // Zoom ke rumah LAWAN: kartu sasaran ditempel di atas layar (bukan di atas
    // atap) supaya tidak menutupi efek/emoji rumah itu.
    final dockedShown = focusId != null && focusId != _me && focusState != null;
    // HUD & tag status menampilkan data pemain sendiri (penonton: rumah yang di-zoom).
    final tagState = me ?? focusState ?? (n > 0 ? _states[order.first] : null);

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A22),
      body: LayoutBuilder(
        builder: (context, c) {
          final pad = MediaQuery.of(context).padding;
          final short = c.maxHeight < 540;
          final wide = c.maxWidth >= 700 && c.maxWidth >= c.maxHeight * 1.1;
          // Bilah aksi selalu SATU baris; HP sempit memakai tombol ringkas.
          final compactBar = c.maxWidth < 520;
          final showStats = c.maxWidth >= 980;
          final showRate = c.maxWidth >= 860;

          final hudH = wide ? (short ? 50.0 : 58.0) : 78.0;
          final barH = compactBar ? 72.0 : (short ? 58.0 : 88.0);
          final hasBar = me != null;
          final offerShown = _incomingOffer != null && alive && !finished;

          final topInset = pad.top + 8 + hudH + 8;
          final bottomInset = (hasBar ? barH + 8 : 0.0) + pad.bottom + 8;
          final insets =
          EdgeInsets.fromLTRB(pad.left, topInset, pad.right, bottomInset);
          final screen = Size(c.maxWidth, c.maxHeight);
          final stage = _cam.stageFor(screen, insets);

          // --- tujuan kamera: zoom ke satu rumah, atau muat semua tetangga ---
          final count = max(1, n);
          final fitOne =
          min(stage.width / kStreetSlotW, stage.height / kStreetSlotH);
          final fitAll = min(
            stage.width * 0.96 / (count * kStreetSlotW),
            stage.height / kStreetSlotH,
          );
          final fi = focusId == null ? -1 : order.indexOf(focusId);
          var camCx = fi >= 0
              ? fi * kStreetSlotW + kStreetSlotW / 2
              : count * kStreetSlotW / 2;
          var camScale = fi >= 0 ? fitOne : min(fitAll, fitOne);
          // Lemparan yang melibatkan rumah yang sedang di-zoom: kamera melebar
          // sebentar agar pelempar & sasaran terlihat, lalu kembali sendiri.
          if (fi >= 0) {
            var lo = fi, hi = fi;
            for (final sh in _shots) {
              if (sh.age > sh.durMs + 250) continue;
              final ia = order.indexOf(sh.fromId);
              final ib = order.indexOf(sh.toId);
              if (ia < 0 || ib < 0 || (ia != fi && ib != fi)) continue;
              lo = min(lo, min(ia, ib));
              hi = max(hi, max(ia, ib));
            }
            if (hi > lo) {
              camCx = (lo + hi + 1) * kStreetSlotW / 2;
              camScale = min(
                fitOne,
                min(
                  stage.width * 0.96 / ((hi - lo + 1) * kStreetSlotW),
                  stage.height / kStreetSlotH,
                ),
              );
            }
          }
          _lastStage = stage;
          _lastOrder = order;
          _lastFitOne = fitOne;
          _lastFitAll = min(fitAll, fitOne);
          _lastTgtCx = camCx;
          _lastTgtScale = camScale;
          // Saat sinematik, kamera digerakkan listener per-frame (_cineStep).
          if (!_cine.takesCamera) _cam.setTarget(camCx, camScale);

          final houses = <KostSceneData>[
            for (var hi = 0; hi < order.length; hi++)
              _cine.adjustHouse(
                order[hi],
                _sceneData(
                  order[hi],
                  _states[order[hi]]!,
                  compact: false,
                  facingRight: _facingRightFor(order[hi], order),
                ),
                hi,
                order.length,
              ),
          ];
          final backdrop = _cine.adjustBackdrop(KostSceneData(
            rooms: 0,
            maxRooms: _maxRooms,
            defense: 0,
            trashRatio: 0,
            pollution: _pollution,
            worldEvent: _visualWorldEvent,
            pendingEvent: _pendingWorldEvent,
            pendingLeft: _remaining(_room['pending_event_at']),
            eventAge: _visualEventAge,
            eventLeft: _visualEventLeft,
            eventChained: _evChained,
            smog: _remaining(_room['smog_until']) > 0,
            dayPhase: _dayPhase,
            biome: KostBiome.forRoom(widget.roomId),
          ));

          final focusOut =
              focusState != null && focusState['eliminated_at'] != null;

          return Stack(
            children: [
              // 1) Jalan: seluruh kost berderet. Ketuk rumah = zoom, cubit/scroll = zoom.
              Positioned.fill(
                child: n == 0
                    ? const Center(
                  child: Text('Menunggu pemain…',
                      style: TextStyle(color: Colors.white70)),
                )
                    : Listener(
                  onPointerSignal: (e) =>
                      _onWheel(e, stage, order, focusId),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPressStart: (d) {
                      if (_iAmGhost) return;
                      final mine = _states[_me];
                      if (mine == null || mine['eliminated_at'] != null) return;
                      final i = _cam.houseAt(d.localPosition.dx, stage, n);
                      if (i == null) return;
                      final id = order[i];
                      if (id == _me) return;
                      if (_states[id]?['eliminated_at'] != null) return;
                      setState(() => _throwFor = id);
                    },
                    onTapUp: (d) {
                      if (_iAmGhost) {
                        // Arwah: ketukan menggerakkan arwahmu melayang ke sana.
                        _moveMyGhost(d.localPosition, stage, force: true);
                        return;
                      }
                      final i = _cam.houseAt(d.localPosition.dx, stage, n);
                      if (i != null && order[i] != focusId) {
                        _zoomTo(order[i]);
                      }
                    },
                    onScaleStart: (_) => _pinch = 1.0,
                    onScaleUpdate: (d) {
                      if (d.pointerCount >= 2) {
                        _pinch = d.scale;
                        _pinchFocal = d.localFocalPoint;
                      } else if (_iAmGhost) {
                        _moveMyGhost(d.localFocalPoint, stage);
                      }
                    },
                    onScaleEnd: (_) {
                      if (_pinch < 0.8) {
                        _zoomAll();
                      } else if (_pinch > 1.25 && focusId == null) {
                        final i = _cam.houseAt(_pinchFocal.dx, stage, n);
                        if (i != null) {
                          _zoomTo(order[i]);
                        } else {
                          _zoomHome();
                        }
                      }
                      _pinch = 1.0;
                    },
                    child: KostStreet(
                      houses: houses,
                      ids: order,
                      shots: _shots,
                      ghosts: _ghosts.values.toList(),
                      backdrop: backdrop,
                      camera: _cam,
                      repaint: _anim,
                      insets: insets,
                    ),
                  ),
                ),
              ),

              // 2) Stempel tertimbun untuk rumah yang sedang di-zoom
              if (focusOut && !_cine.holdFinish)
                Positioned(
                  left: pad.left,
                  right: pad.right,
                  top: topInset,
                  bottom: bottomInset,
                  child: IgnorePointer(child: Center(child: _stamp())),
                ),

              // 2b) Sinematik (di bawah HUD): pewarnaan, hujan, sirine, kartu telepon
              Positioned.fill(
                child: CinematicWorldLayer(
                  director: _cine,
                  repaint: _anim,
                  stage: stage,
                ),
              ),

              // 2c) HUD, tag, tombol & bilah aksi: memudar saat sinematik
              Positioned.fill(
                child: CineHudFade(
                  director: _cine,
                  repaint: _anim,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 3) HUD Atas
                      Positioned(
                        top: pad.top + 8,
                        left: 12 + pad.left,
                        right: 12 + pad.right,
                        child: _hud(wide, short, tagState,
                            showStats: showStats, showRate: showRate),
                      ),

                      // 5) Kartu nama + sabotase menempel di atas atap tiap rumah.
                      //    Dibangun ulang tiap frame agar mengikuti kamera saat zoom.
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _anim,
                          builder: (context, _) => Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ..._houseTags(
                                order,
                                stage,
                                screen,
                                canAct,
                                me,
                                focusId,
                                topInset,
                              ),
                              ..._throwPopup(order, stage, screen, me, topInset),
                              if (myAttackLeft > 0 && me != null)
                                _parryRing(me, myAttackLeft, order, stage, focusId,
                                    topInset, dockedShown,
                                    reserve: 30.0 + (offerShown ? 80.0 : 0.0)),
                            ],
                          ),
                        ),
                      ),

                      // 4) TUMPUKAN ATAS (satu kolom, urutan prioritas):
                      //    tawaran loket → pemberitahuan singkat → chip status.
                      //    Semua di bawah HUD, bukan di tengah/bawah layar.
                      //    Pemberitahuan disembunyikan saat ada serangan masuk
                      //    supaya cincin TANGKIS tidak tertutup.
                      Positioned(
                        left: 12 + pad.left,
                        right: 12 + pad.right,
                        top: topInset - 4 + (dockedShown ? _dockH + 12 : 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (offerShown)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _offerCard(me),
                              ),
                            _noticeSlot(myAttackLeft <= 0),
                            _statusStrip(tagState, me == null),
                          ],
                        ),
                      ),

                      // 5b) DOK BAWAH: hanya yang bersifat kontrol (emoji, zoom),
                      //     ditumpuk dalam SATU kolom di atas bilah aksi.
                      //     Saat ada serangan masuk, emoji disembunyikan
                      //     supaya cincin TANGKIS tidak tertutup.
                      if (n > 0 || hasBar)
                        Positioned(
                          left: 12 + pad.left,
                          right: 12 + pad.right,
                          bottom: bottomInset - 2,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasBar && myAttackLeft <= 0 && _emojiBarOpen)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: _emojiPickerBar(),
                                ),
                              if (n > 0)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _zoomPanel(
                                    hasHome: me != null,
                                    focusId: focusId,
                                    count: n,
                                  ),
                                ),
                            ],
                          ),
                        ),

                      // 5c) Tombol mengambang di dua sisi, di atas dok zoom:
                      //     kiri = Loket & Emoji, kanan = Hewan, Pertahanan, Gudang.
                      //     Naik sedikit saat bilah emoji terbuka.
                      if (hasBar)
                        Positioned(
                          left: 12 + pad.left,
                          top: topInset + 40,
                          bottom: bottomInset +
                              52 +
                              (myAttackLeft <= 0 && _emojiBarOpen ? 54 : 0),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.bottomLeft,
                              child: _socialTools(me),
                            ),
                          ),
                        ),
                      if (hasBar && me != null && me['eliminated_at'] == null)
                        Positioned(
                          right: 12 + pad.right,
                          top: topInset + 40,
                          bottom: bottomInset +
                              52 +
                              (myAttackLeft <= 0 && _emojiBarOpen ? 54 : 0),
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.bottomRight,
                              child: _floatingTools(me, canAct),
                            ),
                          ),
                        ),

                      // 5d) Gelembung peringatan: Lapor Polisi / Bajak Truk, hanya
                      //     saat tersedia, di sisi layar menurut letak rumah lawan.
                      if (hasBar)
                        ..._rivalAlerts(order, me, canAct, pad, screen),

                      // 6) Bilah Aksi
                      if (hasBar) ...[
                        Positioned(
                          left: 12 + pad.left,
                          right: 12 + pad.right,
                          bottom: pad.bottom + 8,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 820),
                              child: _actionBar(me, canAct, compact: compactBar, short: short),
                            ),
                          ),
                        ),
                      ],

                    ],
                  ),
                ),
              ),

              // 6b) Sinematik (di atas HUD): letterbox, narasi, judul, lewati
              Positioned.fill(
                child: CinematicTopLayer(
                  director: _cine,
                  repaint: _anim,
                  stage: stage,
                  onSkip: _cine.skipIntro,
                ),
              ),

              // 7) Layar Selesai (ditahan sampai adegan tertimbun selesai)
              if (finished && !_cine.holdFinish)
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

  /// Cincin TANGKIS di atas rumah korban. Muncul begitu penyerang menekan
  /// serang; mengikuti kamera. Animasi lempar baru jalan setelah cincin ini
  /// diketuk atau waktunya habis.
  Widget _parryRing(
      Map<String, dynamic> me,
      double left,
      List<String> order,
      Rect stage,
      String? focusId,
      double topInset,
      bool docked, {
        double reserve = 0,
      }) {
    final i = order.indexOf(_me);
    if (i < 0) return const SizedBox.shrink();
    const d = 84.0;
    const boxW = 150.0;
    const boxH = d + 40 + 26;

    final sc = _cam.scale;
    final o = _cam.origin(stage);
    final rooms = _num(_states[_me]!['rooms_count']).toInt();
    final floors = min(3, max(1, (rooms / 4).ceil()));
    final roofY = o.dy + (236.0 - floors * 50.0) * sc;
    final rawCx = o.dx + (i * kStreetSlotW + kStreetSlotW / 2) * sc;
    final cx = rawCx
        .clamp(stage.left + boxW / 2 + 6, stage.right - boxW / 2 - 6)
        .toDouble();
    final tagRoom = focusId == _me ? 0.0 : 58.0;
    var top = roofY - 34 * sc - tagRoom - boxH + 10;
    // Ada emoji di rumah sendiri: naikkan cincin agar tidak saling menimpa.
    if (kostActiveEmoji(_fx[_me]) != null) top -= kEmojiBoxH + 4;
    top = max(top, topInset + (docked ? _dockH + 12 : 4) + reserve);
    top = min(top, stage.bottom - boxH - 70);

    final cd = _remaining(me['parry_cooldown_until']);
    final ready = cd == 0 && !_tangkisBusy;
    final isInspect = me['pending_attack_type'] == 'inspect';
    final from = _name(me['pending_attack_from']);
    _atkTotal = max(_atkTotal, left);
    final frac = _atkTotal <= 0 ? 0.0 : (left / _atkTotal).clamp(0.0, 1.0);
    final t = sceneNowMs() / 1000.0;
    final pulse = 0.5 + 0.5 * sin(t * 9);
    final ripple = (t * 1.5) % 1.0;
    final base = ready ? const Color(0xFFE53935) : Colors.blueGrey.shade700;

    return Positioned(
      left: cx - boxW / 2,
      top: top,
      width: boxW,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: d + 40,
            height: d + 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (ready)
                  IgnorePointer(
                    child: Container(
                      width: d + ripple * 36,
                      height: d + ripple * 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFF5252)
                              .withValues(alpha: (1 - ripple) * 0.7),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                Transform.scale(
                  scale: ready ? 1 + 0.06 * pulse : 1,
                  child: Material(
                    color: base,
                    elevation: 10,
                    shadowColor: Colors.black,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: ready ? _tangkis : null,
                      child: SizedBox(
                        width: d,
                        height: d,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: d - 8,
                              height: d - 8,
                              child: CircularProgressIndicator(
                                value: frac,
                                strokeWidth: 5,
                                color: Colors.white
                                    .withValues(alpha: ready ? 0.9 : 0.4),
                                backgroundColor:
                                Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  ready ? Icons.security : Icons.hourglass_bottom,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                Text(
                                  ready ? 'TANGKIS' : '${cd.ceil()}s',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: _ink.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF5252).withValues(alpha: 0.6),
              ),
            ),
            child: Text(
              '${isInspect ? 'Sidak' : 'Lemparan'} dari $from · ${left.toStringAsFixed(1)} dtk',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emojiPickerBar() {
    return _glass(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < kEmojiList.length; i++)
              InkWell(
                onTap: () => _sendEmoji(i + 1),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    kEmojiList[i],
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
          ],
        ),
      ),
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

  Widget _moneyChip(Map<String, dynamic> s,
      {bool stacked = false, bool showRate = true}) {
    final live = _live(s);
    final out = s['eliminated_at'] != null;
    final trRate = _num(s['trash_rate']);
    final amount = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.payments, size: 20, color: Color(0xFFFFC107)),
        const SizedBox(width: 6),
        Text(live.money.floor().toString(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800)),
      ],
    );
    final rate = Text(
      '+${_num(s['income_rate']).toStringAsFixed(1)}/s · ${trRate >= 0 ? '+' : ''}${trRate.toStringAsFixed(2)}🗑️',
      style: const TextStyle(color: Colors.white70, fontSize: 10.5),
    );
    if (stacked) {
      // Potret: angka uang besar, laju di bawahnya (tidak ikut mengecil).
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [amount, if (!out) rate],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        amount,
        if (!out && showRate) ...[
          const SizedBox(width: 6),
          rate,
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
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label,
                      style:
                      const TextStyle(color: Colors.white70, fontSize: 10.5)),
                  const Spacer(),
                  Text(value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 2),
              _meter(v, maxV, color, height: 6),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hudIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) =>
      IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: color),
        iconSize: 20,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        visualDensity: VisualDensity.compact,
        tooltip: tooltip,
      );

  Widget _hud(bool wide, bool short, Map<String, dynamic>? s,
      {required bool showStats, required bool showRate}) {
    final p = _pollution;
    final pc = _pollutionLevel(p).$2;

    final back = _hudIcon(
      icon: Icons.arrow_back,
      tooltip: 'Kembali',
      onTap: () => Navigator.of(context).maybePop(),
    );
    final history = _hudIcon(
      icon: Icons.history,
      tooltip: 'Kabar terbaru',
      onTap: _showFeed,
    );
    final code = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
          _isSurvival
              ? '${_fmtDur(_elapsedSec)} · ×${_pressure.toStringAsFixed(1)}'
              : widget.roomCode,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              letterSpacing: 1.2,
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
      final inBin = wl > 0 && ratio <= 1.0 / 3.0;

      trashMeter = _hudMeter(
        icon: inBin ? Icons.delete_outline : Icons.delete_forever,
        label: inBin ? 'Di Kotak' : (wl > 0 ? 'Meluber!' : 'Sampah'),
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

    // Lebar: SATU baris (kembali · kode · uang · [status] · meter · tombol).
    if (wide) {
      return _glass(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: short ? 3 : 6),
        child: Row(
          children: [
            back,
            code,
            const SizedBox(width: 10),
            if (s != null) ...[
              _moneyChip(s, showRate: showRate),
              const SizedBox(width: 12),
              if (showStats) ...[
                stats!,
                const SizedBox(width: 12),
              ],
              Expanded(child: trashMeter!),
              const SizedBox(width: 12),
            ],
            Expanded(child: polMeter),
            const SizedBox(width: 2),
            history,
          ],
        ),
      );
    }

    // Sempit/potret: baris 1 = identitas & tombol, baris 2 = dua meter ramping.
    return _glass(
      padding: const EdgeInsets.fromLTRB(2, 3, 8, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              back,
              Expanded(
                child: s == null
                    ? const SizedBox.shrink()
                    : FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _moneyChip(s, stacked: true),
                ),
              ),
              const SizedBox(width: 6),
              code,
              const SizedBox(width: 2),
              history,
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              children: [
                if (trashMeter != null) ...[
                  Expanded(child: trashMeter),
                  const SizedBox(width: 12),
                ],
                Expanded(child: polMeter),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Daftar status aktif, urut dari yang paling mendesak. `short` dipakai di
  /// chip (ringkas), `long` dipakai di lembar rincian.
  List<_StatusItem> _statusItems(Map<String, dynamic>? s, bool spectator) {
    final items = <_StatusItem>[];
    _StatusItem? timer;
    if (spectator) {
      items.add(_StatusItem(Icons.visibility, 'Penonton', 'Mode penonton',
          Colors.blueGrey));
    }
    if (_room['started_at'] != null && _room['status'] == 'playing') {
      final el = _elapsedSec;
      final pr = _pressure;
      final next = 120 - (el % 120);
      timer = _StatusItem(
        Icons.timer,
        pr > 1.0 ? '${_clock(el)} · ×${pr.toStringAsFixed(1)}' : _clock(el),
        pr > 1.0
            ? '${_clock(el)} · Tekanan sampah ×${pr.toStringAsFixed(1)} (naik lagi ${_clock(next)})'
            : '${_clock(el)} · Tekanan sampah naik tiap 2 menit (${_clock(next)})',
        pr > 1.0 ? Colors.deepOrange.shade800 : Colors.blueGrey.shade700,
      );
    }
    final ev = _activeWorldEvent;
    if (ev != null) {
      final info = _worldEventInfo(ev);
      final left = _remaining(_room['world_event_until']).ceil();
      items.add(_StatusItem(info.$2, '${info.$1} ${left}s',
          '${info.$1} (${left}s)', info.$3));
    }
    final pend = _pendingWorldEvent;
    if (pend != null) {
      final pl = _remaining(_room['pending_event_at']).ceil();
      final nm = _worldEventInfo(pend).$1.split(' · ').first;
      items.add(_StatusItem(Icons.warning_amber_rounded, 'Awas: $nm ${pl}s',
          'PERINGATAN: $nm dalam $pl dtk', Colors.amber.shade800));
    }
    final smog = _remaining(_room['smog_until']);
    if (smog > 0) {
      items.add(_StatusItem(
        Icons.masks,
        'Kabut ${smog.ceil()}s',
        'KABUT ASAP! Bakar diblokir · ${smog.ceil()} dtk',
        Colors.red.shade700,
      ));
    }
    if (s != null) {
      final live = _live(s);
      final cap = max(1.0, _num(s['trash_capacity']));
      final ratio = live.trash / cap;
      final out = s['eliminated_at'] != null;
      final wl = _num(s['waste_level']).toInt();
      final sealed = _remaining(s['sealed_until']);
      if (!out && sealed > 0) {
        items.add(_StatusItem(
          Icons.policy,
          'Disegel ${sealed.ceil()}s',
          'KOST DISEGEL DINAS · Income -50% (${sealed.ceil()} dtk)',
          Colors.redAccent.shade700,
        ));
      }
      if (out) {
        items.add(_StatusItem(
          Icons.blur_on,
          'Arwah',
          'ARWAH · Ketuk layar untuk melayang · emoji tiap 5 dtk',
          Colors.deepPurple.shade300,
        ));
      }
      final smoked = _remaining(s['smoked_until']);
      if (!out && smoked > 0) {
        items.add(_StatusItem(
          Icons.cloud,
          'Gas −35% ${smoked.ceil()}s',
          'GAS BERACUN · Income -35% (${smoked.ceil()} dtk)',
          Colors.green.shade800,
        ));
      }
      final booth = _remaining(s['booth_until']);
      if (!out && booth > 0) {
        items.add(_StatusItem(Icons.storefront, 'Loket ${booth.ceil()}s',
            'Loket Sampah buka · ${booth.ceil()} dtk', Colors.teal.shade700));
      }
      if (!out && (ratio >= 0.5 || (wl > 0 && ratio > 1.0 / 3.0))) {
        final t = _trashStage(ratio, wl);
        items.add(_StatusItem(
            Icons.warning_amber_rounded, t, t, _trashColor(ratio)));
      }
      if (!out && (wl == 8 || wl == 9)) {
        items.add(_StatusItem(
          Icons.factory,
          'Insinerator',
          'Insinerator Berpolusi aktif (+Polusi, rawan disidak lawan!)',
          Colors.brown.shade700,
        ));
      }
      final penalty = _remaining(s['burn_penalty_until']);
      if (!out && penalty > 0) {
        final st = _num(s['burn_stacks']).toInt();
        items.add(_StatusItem(
          Icons.local_fire_department,
          'Bakar ×$st ${penalty.ceil()}s',
          'Penalti bakar x$st · ${penalty.ceil()} dtk',
          Colors.deepOrange,
        ));
      }
      final prot = _remaining(s['protected_until']);
      if (!out && prot > 0) {
        items.add(_StatusItem(Icons.shield, 'Lindung ${prot.ceil()}s',
            'Dilindungi ${prot.ceil()} dtk', Colors.amber.shade800));
      }
      if (!out && s['player_id']?.toString() == _bountyId) {
        items.add(_StatusItem(
          Icons.my_location,
          'Buronan',
          'BURONAN! Lawan dapat +40 & Sidak murah bila menyerangmu',
          Colors.amber.shade900,
        ));
      }
      final revT = s['revenge_target']?.toString();
      final revLeft = _remaining(s['revenge_until']);
      if (!out && revT != null && revLeft > 0) {
        items.add(_StatusItem(
          Icons.whatshot,
          'Dendam ${revLeft.ceil()}s',
          'DENDAM! Balas ${_name(revT)}: sabotase 50% & tanpa jeda · ${revLeft.ceil()} dtk',
          Colors.red.shade800,
        ));
      }
    }
    final p = _pollution;
    if (p >= 30) {
      final (label, color) = _pollutionLevel(p);
      items.add(_StatusItem(Icons.cloud, label, label, color));
    }
    // Penghitung waktu paling tidak mendesak: taruh paling akhir.
    if (timer != null) items.add(timer);
    return items;
  }

  /// Satu baris chip kecil di bawah HUD (maks 3 + "+N"). Ketuk = rincian.
  Widget _statusStrip(Map<String, dynamic>? s, bool spectator) {
    final items = _statusItems(s, spectator);
    if (items.isEmpty) return const SizedBox.shrink();
    const maxChips = 3;
    final shown = items.take(maxChips).toList();
    final extra = items.length - shown.length;

    Widget chip(IconData icon, String text, Color color) => Padding(
      padding: const EdgeInsets.only(right: 5),
      child: Material(
        color: color.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: _showStatusSheet,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 24, maxWidth: 190),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      height: 26,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final it in shown) chip(it.icon, it.short, it.color),
            if (extra > 0)
              chip(Icons.more_horiz, '+$extra', Colors.blueGrey.shade700),
          ],
        ),
      ),
    );
  }

  void _showStatusSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (ctx) => SafeArea(
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, __) {
            final me = _states[_me];
            final fid = _focusId;
            final st = me ??
                (fid != null
                    ? _states[fid]
                    : (_order.isNotEmpty ? _states[_order.first] : null));
            final items = _statusItems(st, me == null);
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 440),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  const Text('Status saat ini',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (items.isEmpty) const Text('Tidak ada status aktif.'),
                  for (final it in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: it.color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(it.icon, size: 15, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(it.long),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
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

  /// Slot pemberitahuan di bawah HUD. Mengecil jadi 0 tinggi saat kosong,
  /// jadi tidak memakan tempat. Ketuk pil untuk menutupnya.
  Widget _noticeSlot(bool allowed) {
    final n = allowed ? _notice : null;
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.35),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: n == null
            ? const SizedBox.shrink(key: ValueKey('notice-none'))
            : _noticePill(n),
      ),
    );
  }

  Widget _noticePill(_Notice n) {
    return Padding(
      key: ValueKey('notice-${n.id}'),
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismissNotice,
            child: Container(
              padding: const EdgeInsets.fromLTRB(7, 6, 12, 6),
              decoration: BoxDecoration(
                color: _ink.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: n.color.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: n.color.withValues(alpha: 0.28),
                    ),
                    child: Icon(n.icon,
                        size: 14, color: Color.lerp(n.color, Colors.white, 0.5)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      n.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFeed() {
    final list = _events.where((e) => _eventText(e).isNotEmpty).toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 520),
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

  Widget _survivalFinishedCard() {
    final secs = _num(_room['survival_seconds']);
    final s = _states[_me];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF16281F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFCA28), width: 2),
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
          const Icon(Icons.timer_rounded, size: 40, color: Color(0xFFFFCA28)),
          const SizedBox(height: 12),
          const Text(
            'KOST TERTIMBUN!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bertahan ${_fmtDur(secs)}',
            style: const TextStyle(
              color: Color(0xFFFFCA28),
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_num(s?['rooms_count']).toInt()} kamar · '
                'Bank Sampah Lv ${_num(s?['waste_level']).toInt()}',
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

  Widget _finishedCard() {
    if (!_endSfxDone) {
      _endSfxDone = true;
      final win = !_isSurvival && _room['winner_id'] == _me;
      Sfx.instance.rainStop();
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          Sfx.instance.play(win ? 'game-win' : 'game-lose', minGapMs: 0));
    }
    if (_isSurvival) return _survivalFinishedCard();
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

  // ------------------------------------------------------- bilah aksi (7 tombol)

  Widget _actionBar(Map<String, dynamic>? s, bool canAct,
      {required bool compact, required bool short}) {
    if (s == null) return const SizedBox.shrink();
    final live = _live(s);
    final rooms = _num(s['rooms_count']).toInt();
    final wasteLv = _num(s['waste_level']).toInt();
    final tier = _num(s['kost_tier']).toInt();
    final sealed = _remaining(s['sealed_until']) > 0;

    final buildCost = _buildCost(s);
    final nextWasteLv = wasteLv + 1;
    final wasteCost = _wasteCost(nextWasteLv);
    final nextTier = tier + 1;
    final tierCost = nextTier == 1 ? 650 : 1600;
    final tierMinRooms = nextTier == 1 ? 4 : 8;

    final haulLeft = _remaining(s['hauler_busy_until']);
    final burnLeft = _remaining(s['burn_cooldown_until']);
    final smog = _remaining(_room['smog_until']) > 0;
    final strike = _activeWorldEvent == 'hauler_strike';
    final flood = _activeWorldEvent == 'rain_flood';
    final quake = _activeWorldEvent == 'earthquake';
    final wind = _activeWorldEvent == 'strong_wind';
    final haulMax = 45.0 + wasteLv * 4.0;
    final haulCost = (min(live.trash.floorToDouble(), haulMax) *
        3 *
        (flood ? 1.5 : 1.0))
        .ceil();

    // 1 = ringkas vertikal (HP), 2 = baris (landscape pendek), 0 = lega.
    final mode = compact ? 1 : (short ? 2 : 0);

    final buttons = <Widget>[
      _ActionButton(
        mode: mode,
        icon: Icons.add_home_work,
        color: Colors.lightBlue,
        title: rooms >= _maxRooms ? 'Kamar Penuh' : 'Bangun Kamar',
        shortTitle: 'Kamar',
        shortSub: sealed
            ? 'Disegel'
            : quake
            ? 'Gempa'
            : (rooms >= _maxRooms ? 'Penuh' : '$buildCost'),
        subtitle: sealed
            ? 'Disegel!'
            : quake
            ? 'Gempa bumi!'
            : (rooms >= _maxRooms ? 'Maks $_maxRooms' : 'Biaya $buildCost'),
        busy: _activeRpc == 'build_room',
        onTap: canAct && !sealed && !quake && rooms < _maxRooms && live.money >= buildCost
            ? () => _act('build_room')
            : null,
      ),
      _ActionButton(
        mode: mode,
        icon: wasteLv >= 7 ? Icons.factory : Icons.recycling,
        color: wasteLv == 7 || wasteLv == 8
            ? Colors.amber
            : Colors.lightGreenAccent.shade700,
        title:
        wasteLv >= _maxWaste ? 'Limbah Maks' : _wasteNames[nextWasteLv],
        shortTitle: 'Limbah',
        shortSub: wasteLv >= _maxWaste ? 'Maks' : '$wasteCost',
        subtitle: wasteLv >= _maxWaste
            ? 'Lv 12/12 Eco'
            : 'Lv $nextWasteLv · $wasteCost',
        busy: _activeRpc == 'upgrade_waste',
        onTap: canAct && wasteLv < _maxWaste && live.money >= wasteCost
            ? () => _act('upgrade_waste')
            : null,
      ),
      _ActionButton(
        mode: mode,
        icon: Icons.workspace_premium,
        color: Colors.amber,
        title:
        tier >= _maxTier ? 'Kost Sultan' : 'Kost ${_tierNames[nextTier]}',
        shortTitle: 'Kelas',
        shortSub: tier >= _maxTier
            ? 'Maks'
            : (rooms < tierMinRooms ? '$tierMinRooms kmr' : '$tierCost'),
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
      _ActionButton(
        mode: mode,
        icon: Icons.local_shipping,
        color: Colors.green,
        title: 'Truk Sampah',
        shortTitle: 'Truk',
        shortSub: strike
            ? 'Mogok'
            : (haulLeft > 0 ? '${haulLeft.ceil()}s' : '~$haulCost'),
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
      _ActionButton(
        mode: mode,
        icon: Icons.local_fire_department,
        color: Colors.deepOrangeAccent,
        title: 'Bakar Sampah',
        shortTitle: 'Bakar',
        shortSub: burnLeft > 0
            ? '${burnLeft.ceil()}s'
            : (wind ? 'Angin' : smog ? 'Kabut' : (wasteLv >= 10 ? 'Eco' : 'Polusi')),
        subtitle: burnLeft > 0
            ? 'Jeda ${burnLeft.ceil()}s'
            : wind
            ? 'Angin kencang!'
            : smog
            ? 'Kabut asap!'
            : (wasteLv >= 10 ? 'Rendah polusi' : 'Polusi naik'),
        busy: _activeRpc == 'burn',
        onTap: canAct && burnLeft == 0 && !smog && !wind && live.trash >= 2
            ? () => _act('burn')
            : null,
      ),
    ];

    // Selalu satu baris tujuh tombol; tinggi mengikuti mode.
    final h = mode == 1 ? 60.0 : (short ? 46.0 : 76.0);
    final gap = mode == 1 ? 4.0 : 6.0;
    return _glass(
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        height: h,
        child: Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(child: buttons[i]),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------- kartu rumah (nama + 3 tombol sabotase)

  /// Kartu di atas atap tiap rumah yang terlihat. Posisinya dihitung dari kamera
  /// yang sedang berjalan sehingga ikut bergerak mulus saat zoom.
  List<Widget> _houseTags(
      List<String> order,
      Rect stage,
      Size screen,
      bool canAct,
      Map<String, dynamic>? me,
      String? focusId,
      double topInset,
      ) {
    final s = _cam.scale;
    final o = _cam.origin(stage);
    final out = <Widget>[];
    Widget? docked;
    for (var i = 0; i < order.length; i++) {
      final id = order[i];
      final st = _states[id];
      if (st == null) continue;

      final houseW = kStreetSlotW * s;
      final cx = o.dx + (i * kStreetSlotW + kStreetSlotW / 2) * s;
      // hanya rumah yang bagian tengahnya terlihat di layar
      if (cx < stage.left + 24 || cx > stage.right - 24) continue;

      final rooms = _num(st['rooms_count']).toInt();
      final floors = min(3, max(1, (rooms / 4).ceil()));
      final roofY = o.dy + (236.0 - floors * 50.0) * s;
      final emoji = kostActiveEmoji(_fx[id]);
      final focused = id == focusId;

      if (focused) {
        final dockedRival = id != _me;
        // Rumah yang di-zoom: kartu sasaran (lawan) ditempel di atas layar.
        if (dockedRival) {
          final w = min(stage.width - 24, 280.0);
          docked = Positioned(
            left: stage.left + (stage.width - w) / 2,
            top: topInset + 6,
            width: w,
            child: _houseTag(id, st, w, canAct, me,
                focused: true, docked: true),
          );
        }
        // Emoji tampil di atas atap sebagai widget (tidak tertutup apa pun).
        if (emoji != null) {
          final minBottom = topInset +
              kEmojiBoxH +
              (dockedRival ? _dockH + 12 : 4);
          final bottom = max(roofY - 50 * s - 4, minBottom);
          out.add(Positioned(
            left: cx - 34,
            bottom: screen.height - bottom,
            width: 68,
            child: IgnorePointer(child: KostEmojiBubble(fx: emoji)),
          ));
        }
        continue;
      }

      final w = (houseW - 8).clamp(88.0, 236.0).toDouble();
      // Kartu + emoji ditumpuk dalam satu kolom: emoji selalu tepat di atas
      // kartu sehingga tidak pernah tertimpa.
      final bubbleH = emoji != null ? kEmojiBoxH : 0.0;
      // Rumah sempit (banyak pemain di layar kecil): kartu tetangga akan saling
      // menimpa, jadi disusun zig-zag pada 2-3 tingkat ketinggian.
      final rows = ((w + 4) / houseW).ceil().clamp(1, 3).toInt();
      final lift = (i % rows) * 54.0;
      final bottom =
      max(topInset + 70.0 + bubbleH, roofY - 34 * s - 6 - lift);

      out.add(
        Positioned(
          left: cx - w / 2,
          bottom: screen.height - bottom,
          width: w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null)
                IgnorePointer(child: KostEmojiBubble(fx: emoji)),
              _houseTag(id, st, w, canAct, me, focused: false),
            ],
          ),
        ),
      );
    }
    if (docked != null) out.add(docked);
    return out;
  }

  Widget _houseTag(
      String id,
      Map<String, dynamic> s,
      double w,
      bool canAct,
      Map<String, dynamic>? me, {
        required bool focused,
        bool docked = false,
      }) {
    final isMe = id == _me;
    final live = _live(s);
    final cap = max(1.0, _num(s['trash_capacity']));
    final ratio = live.trash / cap;
    // Bar lawan dibulatkan kelipatan 10% supaya gertakan kembang api (yang
    // hanya membuang ~3 sampah) tidak bocor lewat penurunan bar.
    final shownRatio = isMe ? ratio : (ratio * 10).round() / 10.0;
    final shownTrash = shownRatio * cap;
    final out = s['eliminated_at'] != null;
    final wl = _num(s['waste_level']).toInt();
    final rooms = _num(s['rooms_count']).toInt();
    final isBounty = id == _bountyId;
    final revenge = _hasRevenge(me, id);
    final narrow = w < 130;

    final header = InkWell(
      onTap: focused ? null : () => _zoomTo(id),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            // ikon kepala pemilik kost (terbaca walau kamera menjauh)
            KostHeadIcon(
              look: kostLookFor(id, _styles[id]),
              size: 20,
              ring: isMe ? const Color(0xFFFFCA28) : _wallFor(id),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${isBounty ? '👑 ' : ''}${revenge ? '🔥 ' : ''}${_name(id)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isMe ? const Color(0xFFFFCA28) : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (!narrow) ...[
              const SizedBox(width: 6),
              Text(
                '🏠$rooms ♻️$wl',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (docked) {
      return Material(
        elevation: 6,
        color: const Color(0xFF1A2820).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFFCA28).withValues(alpha: 0.7),
              width: 1.6,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: 4),
                    _meter(shownTrash, cap, _trashColor(shownRatio), height: 5),
                  ],
                ),
              ),
              if (!isMe && out) ...[
                const SizedBox(width: 10),
                Text(
                  'TERTIMBUN',
                  style: TextStyle(
                    color: Colors.red.shade300,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Material(
      elevation: 5,
      color: const Color(0xFF1A2820).withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: focused
                ? const Color(0xFFFFCA28).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.14),
            width: focused ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 3),
            _meter(shownTrash, cap, _trashColor(shownRatio), height: 4),
            if (!isMe && out) ...[
              const SizedBox(height: 5),
              Center(
                child: Text(
                  'TERTIMBUN',
                  style: TextStyle(
                    color: Colors.red.shade300,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------ menu lemparan

  // ----------------------------------------- popup lemparan (tekan lama rumah)

  /// Rumah lawan yang sedang ditahan lama: popup pilihan lemparan muncul di atasnya.
  String? _throwFor;

  List<({String kind, String icon, String label, int cost, bool ok})>
  _throwKinds(Map<String, dynamic> me) {
    final mine = _live(me);
    final fwLeft = _remaining(me['firework_cooldown_until']);
    return [
      (
      kind: 'normal',
      icon: '🗑️',
      label: 'Biasa',
      cost: 10,
      ok: mine.money >= 10 && mine.trash >= 1,
      ),
      (
      kind: 'sack',
      icon: '🛍️',
      label: 'Karung',
      cost: 40,
      ok: mine.money >= 40 && mine.trash >= 1,
      ),
      (
      kind: 'smog',
      icon: '☣️',
      label: 'Polusi',
      cost: 50,
      ok: mine.money >= 50,
      ),
      (
      kind: 'firework',
      icon: '🎆',
      label: 'Gertak',
      cost: 10,
      ok: mine.money >= 10 && mine.trash >= 1 && fwLeft == 0,
      ),
    ];
  }

  /// Alasan semua lemparan ke [id] sedang terkunci (null = boleh).
  String? _throwBlockReason(String id, Map<String, dynamic> me) {
    final st = _states[id];
    if (st == null || st['eliminated_at'] != null) return 'Sudah tertimbun';
    final prot = _remaining(st['protected_until']);
    if (prot > 0) return 'Dilindungi ${prot.ceil()}s';
    if (_remaining(st['pending_attack_until']) > 0) {
      return 'Sedang diserang orang lain';
    }
    final left = _remaining(me['throw_cooldown_until']);
    if (left > 0) return 'Jeda lempar ${left.ceil()}s';
    return null;
  }

  static const _throwDesc = {
    'normal': 'Lempar Biasa · jeda 4 dtk · Tangkis 2,5 dtk',
    'sack': 'Sekarung Besar ×2,5 · jeda 10 dtk · Tangkis 3,5 dtk',
    'smog': 'Polusi: income lawan -35% selama 12 dtk. Bila ditangkis, asap berbalik ke kamu.',
    'firework': 'Kembang Api: tampak seperti lempar biasa. 30% membakar sampah lawan.',
  };

  /// Barrier + gelembung pilihan lemparan beranimasi di atas rumah [_throwFor].
  List<Widget> _throwPopup(
      List<String> order,
      Rect stage,
      Size screen,
      Map<String, dynamic>? me,
      double topInset,
      ) {
    final id = _throwFor;
    if (id == null || me == null || me['eliminated_at'] != null) {
      return const [];
    }
    final i = order.indexOf(id);
    final st = _states[id];
    if (i < 0 || st == null || st['eliminated_at'] != null) return const [];

    final sc = _cam.scale;
    final o = _cam.origin(stage);
    final cx = o.dx + (i * kStreetSlotW + kStreetSlotW / 2) * sc;
    final rooms = _num(st['rooms_count']).toInt();
    final floors = min(3, max(1, (rooms / 4).ceil()));
    final roofY = o.dy + (236.0 - floors * 50.0) * sc;

    const bubble = 56.0;
    const gap = 8.0;
    const w = 4 * bubble + 3 * gap;
    final left = (cx - w / 2)
        .clamp(8.0, max(8.0, screen.width - w - 8))
        .toDouble();
    final bottomY = max(topInset + 118.0, roofY - 34 * sc - 62);

    final block = _throwBlockReason(id, me);
    final kinds = _throwKinds(me);

    Widget one(int idx) {
      final k = kinds[idx];
      final ok = block == null && k.ok;
      return TweenAnimationBuilder<double>(
        key: ValueKey('throw-${k.kind}'),
        tween: Tween<double>(begin: 0, end: 1),
        duration: Duration(milliseconds: 240 + idx * 70),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Opacity(
          opacity: v.clamp(0.0, 1.0).toDouble(),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 26),
            child: Transform.scale(scale: 0.4 + 0.6 * v, child: child),
          ),
        ),
        child: SizedBox(
          width: bubble,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: _throwDesc[k.kind] ?? '',
                child: Opacity(
                  opacity: ok ? 1 : 0.45,
                  child: Material(
                    color: const Color(0xFF1A2820),
                    elevation: 6,
                    shape: CircleBorder(
                      side: BorderSide(
                          color: const Color(0xFFFF7043)
                              .withValues(alpha: ok ? 0.95 : 0.4),
                          width: 2),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        if (block != null) {
                          _toast(block, error: true);
                        } else if (!k.ok) {
                          _toast(
                              k.kind == 'firework' &&
                                  _remaining(me['firework_cooldown_until']) >
                                      0
                                  ? 'Kembang api sedang isi ulang.'
                                  : 'Uang atau sampah belum cukup.',
                              error: true);
                        } else if (_canActNow) {
                          setState(() => _throwFor = null);
                          _act('throw_trash',
                              {'p_target': id, 'p_kind': k.kind});
                        }
                      },
                      child: SizedBox(
                        width: bubble - 6,
                        height: bubble - 6,
                        child: Center(
                          child: Text(k.icon,
                              style: const TextStyle(fontSize: 26)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(k.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
              Text('${k.cost}',
                  style: const TextStyle(
                      color: Color(0xFFFFCA28),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
            ],
          ),
        ),
      );
    }

    return [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _throwFor = null),
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
        ),
      ),
      Positioned(
        left: left,
        bottom: screen.height - bottomY,
        width: w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2820).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFFF7043).withValues(alpha: 0.8)),
              ),
              child: Text(
                block == null
                    ? 'Lempar ke ${_name(id)}'
                    : '${_name(id)} · $block',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: block == null ? Colors.white : Colors.red.shade200,
                    fontSize: 12,
                    fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (var k = 0; k < kinds.length; k++) one(k)],
            ),
          ],
        ),
      ),
    ];
  }

  // ------------------------------- gelembung peringatan (lapor / bajak)

  /// Gelembung di sisi layar yang HANYA muncul bila Sidak Dinas atau Bajak
  /// Truk terhadap seorang lawan sedang tersedia. Sisi kiri/kanan mengikuti
  /// letak rumah lawan relatif terhadap rumah sendiri.
  List<Widget> _rivalAlerts(
      List<String> order,
      Map<String, dynamic>? me,
      bool canAct,
      EdgeInsets pad,
      Size screen,
      ) {
    if (me == null || me['eliminated_at'] != null || !canAct) return const [];
    final mine = _live(me);
    final myIdx = order.indexOf(_me);
    final sabLeft = _remaining(me['sabotage_cooldown_until']);

    final lefts = <({int dist, Widget w})>[];
    final rights = <({int dist, Widget w})>[];
    for (var i = 0; i < order.length; i++) {
      final id = order[i];
      if (id == _me) continue;
      final st = _states[id];
      if (st == null || st['eliminated_at'] != null) continue;

      final cap = max(1.0, _num(st['trash_capacity']));
      final ratio = _live(st).trash / cap;
      final rivalWl = _num(st['waste_level']).toInt();
      final violating = _remaining(st['burn_penalty_until']) > 0 ||
          rivalWl == 8 ||
          rivalWl == 9 ||
          ratio >= 0.70;
      final hauling = _remaining(st['hauler_busy_until']) > 0;
      final pending = _remaining(st['pending_attack_until']) > 0;
      final revenge = _hasRevenge(me, id);
      final ready = sabLeft == 0 || revenge;
      final inspectCost = _inspectCost(id, me);
      final hijackCost = _hijackCost(id, me);
      final isLeft = myIdx >= 0 ? i < myIdx : i < order.length / 2;
      final dist = myIdx >= 0 ? (i - myIdx).abs() : i;

      void add(Widget w) =>
          (isLeft ? lefts : rights).add((dist: dist, w: w));

      if (ready && !pending && violating && mine.money >= inspectCost) {
        add(_alertBubble(
          key: 'inspect-$id',
          icon: Icons.policy_rounded,
          color: const Color(0xFFE53935),
          title: 'Lapor ${_name(id)}',
          cost: inspectCost,
          left: isLeft,
          tip:
          'Sidak Dinas ke ${_name(id)} (bisa ditangkis). Lawan melanggar: habis bakar sampah / insinerator polusi / sampah >70%.',
          onTap: () => _act('sabotage_inspect', {'p_target': id}),
        ));
      }
      if (ready && hauling && mine.money >= hijackCost) {
        add(_alertBubble(
          key: 'hijack-$id',
          icon: Icons.u_turn_left_rounded,
          color: const Color(0xFFFFB300),
          title: 'Bajak truk ${_name(id)}',
          cost: hijackCost,
          left: isLeft,
          tip:
          'Bajak truk sampah ${_name(id)} yang sedang mengangkut (tidak bisa ditangkis).',
          onTap: () => _act('sabotage_hijack', {'p_target': id}),
        ));
      }
    }
    if (lefts.isEmpty && rights.isEmpty) return const [];

    List<Widget> top3(List<({int dist, Widget w})> l) {
      l.sort((a, b) => a.dist.compareTo(b.dist));
      return [for (final e in l.take(3)) e.w];
    }

    Widget column(List<Widget> items, CrossAxisAlignment al) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: al,
      children: [
        for (final w in items)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: w),
      ],
    );

    // Digeser ke dalam supaya tidak menimpa kolom tombol mengambang.
    const inset = 12.0 + 46 + 8;
    return [
      if (lefts.isNotEmpty)
        Positioned(
          left: inset + pad.left,
          top: screen.height * 0.30,
          child: column(top3(lefts), CrossAxisAlignment.start),
        ),
      if (rights.isNotEmpty)
        Positioned(
          right: inset + pad.right,
          top: screen.height * 0.30,
          child: column(top3(rights), CrossAxisAlignment.end),
        ),
    ];
  }

  Widget _alertBubble({
    required String key,
    required IconData icon,
    required Color color,
    required String title,
    required int cost,
    required bool left,
    required String tip,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('alert-$key'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(
          offset: Offset((left ? -1 : 1) * (1 - v) * 60, 0),
          child: child,
        ),
      ),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) => Transform.scale(
          scale: 1 + 0.045 * sin(_anim.value * 2 * pi),
          child: child,
        ),
        child: Tooltip(
          message: tip,
          child: Material(
            color: const Color(0xFF1A2820).withValues(alpha: 0.94),
            elevation: 6,
            shape: StadiumBorder(
                side: BorderSide(color: color.withValues(alpha: 0.9), width: 2)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (left)
                        Icon(Icons.chevron_left, size: 16, color: color),
                      Container(
                        width: 26,
                        height: 26,
                        decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                        child: Icon(icon, size: 16, color: Colors.black87),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800)),
                            Text('$cost',
                                style: const TextStyle(
                                    color: Color(0xFFFFCA28),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                      if (!left)
                        Icon(Icons.chevron_right, size: 16, color: color),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------- gudang sampah

  /// Keadaan gudang pemain [pid] yang dihitung dari baris server + waktu server.
  WhLive _whLive(String pid) {
    final r = _wh[pid];
    if (r == null) return WhLive.none;
    final tier = _num(r['tier']).toInt();
    if (tier <= 0) return WhLive.none;
    final comps = _num(r['comps']).toInt();
    final now = _serverNow;
    final upd = _ts(r['updated_at']) ?? now;
    final dt = max(0.0, now.difference(upd).inMilliseconds / 1000);

    // Pemrosesan (hanya sampah yang belum dipesan truk), lalu pemuatan truk.
    var stored = _num(r['stored']);
    final reserved = _num(r['truck_amount']);
    stored -= min(Wh.procRate(tier, comps) * dt, max(0.0, stored - reserved));
    final loadAt = _ts(r['truck_load_at']);
    if (reserved > 0 && loadAt != null && !now.isBefore(loadAt)) {
      stored = max(0.0, stored - reserved);
    }

    double? prog;
    var left = 0.0;
    final t0 = _ts(r['truck_started_at']);
    final t1 = _ts(r['truck_until']);
    if (t0 != null && t1 != null && now.isBefore(t1)) {
      final total = max(1, t1.difference(t0).inMilliseconds);
      prog = (now.difference(t0).inMilliseconds / total)
          .clamp(0.0, 1.0)
          .toDouble();
      left = t1.difference(now).inMilliseconds / 1000;
    }

    int? pourAge;
    final lp = _ts(r['last_pour_at']);
    if (lp != null) {
      final a = now.difference(lp).inMilliseconds;
      if (a >= 0 && a <= Wh.pourAnimMs) pourAge = a;
    }

    return WhLive(
      tier: tier,
      comps: comps,
      stored: max(0.0, stored),
      truckAmount: reserved,
      truckProgress: prog,
      truckLeft: left,
      truckReadyLeft: _remaining(r['truck_ready_at']),
      pourLeft: _remaining(r['pour_ready_at']),
      pourAgeMs: pourAge,
      lastPourAmount: _num(r['last_pour_amount']),
    );
  }

  // ------------------------------------------------ tombol mengambang

  Widget _fab({
    required IconData icon,
    required Color color,
    required String tip,
    String? badge,
    required VoidCallback onTap,
    bool dim = false,
    double size = 46,
  }) {
    return Tooltip(
      message: tip,
      child: Opacity(
        opacity: dim ? 0.55 : 1,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Material(
                  color: _ink.withValues(alpha: 0.82),
                  shape: CircleBorder(
                      side: BorderSide(color: color.withValues(alpha: 0.8))),
                  elevation: 3,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onTap,
                    child: Icon(icon, size: size * 0.48, color: color),
                  ),
                ),
              ),
              if (badge != null)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(badge,
                        style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


  /// Tombol bulat di sisi kiri: Loket Sampah (jual-beli antar pemain) & Emoji.
  Widget _socialTools(Map<String, dynamic>? me) {
    final alive = me != null && me['eliminated_at'] == null;
    final boothLeft = alive ? _remaining(me['booth_until']) : 0.0;
    final boothOpen = boothLeft > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (alive && !_isSurvival) ...[
          _fab(
            icon: boothOpen ? Icons.storefront : Icons.storefront_outlined,
            color: boothOpen ? const Color(0xFF69F0AE) : Colors.white,
            tip: 'Loket Sampah',
            badge: boothOpen ? '${boothLeft.ceil()}s' : null,
            onTap: _openBooth,
          ),
          const SizedBox(height: 10),
        ],
        _fab(
          icon: _emojiBarOpen
              ? Icons.emoji_emotions
              : Icons.emoji_emotions_outlined,
          color: const Color(0xFFFFCA28),
          tip: 'Kirim Emoji Reaksi',
          onTap: () => setState(() => _emojiBarOpen = !_emojiBarOpen),
        ),
      ],
    );
  }

  /// Tombol bulat kecil di sisi kanan: Hewan, Pertahanan & Gudang.
  Widget _floatingTools(Map<String, dynamic> me, bool canAct) {
    final defense = _num(me['defense']).toInt();
    final maxed = defense >= _maxDefense;
    final defCost = 150 * (defense + 1);
    final money = _live(me).money;
    final pets = _petRows[_me]?.length ?? 0;
    final w = _whLive(_me);
    final pourAmt = _pourAmt(me, w);

    final fab = _fab;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        fab(
          icon: Icons.pets,
          color: Colors.pinkAccent,
          tip: 'Hewan peliharaan',
          badge: '$pets/${Pets.maxSlots}',
          onTap: _openPets,
        ),
        const SizedBox(height: 10),
        fab(
          icon: Icons.shield,
          color: Colors.lightBlueAccent,
          tip: maxed ? 'Pertahanan maksimal' : 'Pertahanan · $defCost',
          badge: maxed ? 'Maks' : '$defense/$_maxDefense',
          dim: maxed || money < defCost,
          onTap: () {
            if (maxed) {
              _toast('Pertahanan sudah maksimal.');
            } else if (money < defCost) {
              _toast('Uang kurang: pertahanan butuh $defCost.', error: true);
            } else if (canAct) {
              _act('buy_defense');
            }
          },
        ),
        // Anak tombol gudang: meluncur ke atas dari tombol Gudang begitu
        // gudang berdiri, dan meluncur turun lagi bila belum/tidak ada.
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: w.built ? 1 : 0),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) {
            if (v <= 0.001) return const SizedBox.shrink();
            return ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: v,
                child: Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, (1 - v) * 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        fab(
                          icon: Icons.local_shipping_rounded,
                          color: Colors.orangeAccent,
                          tip: 'Buang gudang (panggil truk)',
                          size: 40,
                          badge: w.truckProgress != null
                              ? '${w.truckLeft.ceil()}s'
                              : (w.truckReadyLeft > 0
                              ? '${w.truckReadyLeft.ceil()}s'
                              : '${w.stored.floor()}'),
                          dim: w.truckProgress != null ||
                              w.truckReadyLeft > 0 ||
                              w.stored < 1,
                          onTap: _callWarehouseTruck,
                        ),
                        const SizedBox(height: 8),
                        fab(
                          icon: Icons.move_down_rounded,
                          color: Colors.lightGreenAccent,
                          tip: 'Kirim sampah ke gudang',
                          size: 40,
                          badge: w.pourLeft > 0
                              ? '${w.pourLeft.ceil()}s'
                              : '~$pourAmt',
                          dim: w.pourLeft > 0 || pourAmt < 1,
                          onTap: _pourToWarehouse,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        fab(
          icon: Icons.warehouse_rounded,
          color: Colors.orange,
          tip: w.built ? 'Upgrade gudang' : 'Bangun gudang',
          badge: w.built
              ? '${w.stored.floor()}/${w.cap.floor()}'
              : '${Wh.tierCost[1]}',
          dim: !w.built && money < Wh.tierCost[1],
          onTap: _openWarehouse,
        ),
      ],
    );
  }

  /// Popup hewan: langkah 1 pilih jenis, langkah 2 pilih warna/varian.
  void _openPets() {
    final pick = ValueNotifier<PetSpecies?>(null);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A2820),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 580),
          child: AnimatedBuilder(
            animation: Listenable.merge([_anim, pick]),
            builder: (ctx, _) => _petsDialogBody(ctx, pick),
          ),
        ),
      ),
    );
  }

  Future<void> _renamePet(PetSlot p) async {
    final ctl = TextEditingController(text: p.nickname ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nama ${p.def.species.label}'),
        content: TextField(
          controller: ctl,
          maxLength: 14,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Huruf/angka, maks 14'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: const Text('Simpan')),
        ],
      ),
    );
    ctl.dispose();
    if (name != null) {
      await _act('rename_pet', {'p_slot': p.slot, 'p_name': name});
    }
  }

  Widget _petsDialogBody(BuildContext ctx, ValueNotifier<PetSpecies?> pick) {
    final me = _states[_me];
    if (me == null || me['eliminated_at'] != null) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('Hewan hanya untuk pemain yang masih hidup.',
              style: TextStyle(color: Colors.white70)),
        ),
      );
    }
    final money = _live(me).money;
    final canAct = _canActNow;
    final loadout = _petsFor(_me).loadout;
    final sp = pick.value;
    const gold = Color(0xFFFFCA28);
    const rc = [Color(0xFF90A4AE), Color(0xFF64B5F6), Color(0xFFFFCA28)];

    Widget header(String title) => Row(
      children: [
        if (sp != null)
          IconButton(
            onPressed: () => pick.value = null,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            visualDensity: VisualDensity.compact,
          )
        else
          const Padding(
            padding: EdgeInsets.only(right: 8, left: 4),
            child: Icon(Icons.pets, color: Color(0xFFF48FB1)),
          ),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
        ),
        Text('Uang ${money.floor()}',
            style: const TextStyle(
                color: gold, fontWeight: FontWeight.w800, fontSize: 12.5)),
        IconButton(
          onPressed: () => Navigator.pop(ctx),
          icon: const Icon(Icons.close, color: Colors.white70),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );

    // ---------------- langkah 1: pilih jenis hewan
    if (sp == null) {
      Widget speciesCard(PetSpecies s) {
        PetSlot? own;
        for (final x in loadout.slots) {
          if (x.def.species == s) own = x;
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.white.withValues(alpha: 0.07),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                  color: own != null ? gold : Colors.white24,
                  width: own != null ? 2 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => pick.value = s,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text(s.emoji, style: const TextStyle(fontSize: 34)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.label,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15)),
                          Text(s.perkText,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          if (own != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                  'Dimiliki: ${own.displayName} · ${own.def.variant}',
                                  style: const TextStyle(
                                      color: gold,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800)),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header('Pilih Hewan'),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 2, 4, 10),
              child: Text('Maks ${Pets.maxSlots} hewan, tiap jenis hanya satu.',
                  style: TextStyle(color: Colors.white60, fontSize: 11.5)),
            ),
            for (final s in PetSpecies.values) speciesCard(s),
          ],
        ),
      );
    }

    // ---------------- langkah 2: pilih warna / varian
    PetSlot? owned;
    for (final x in loadout.slots) {
      if (x.def.species == sp) owned = x;
    }
    int? empty;
    for (var i = 1; i <= Pets.maxSlots; i++) {
      if (loadout.inSlot(i) == null) {
        empty = i;
        break;
      }
    }
    final full = owned == null && empty == null;
    final target = owned?.slot ??
        empty ??
        (_petSlotSel >= 1 && _petSlotSel <= Pets.maxSlots ? _petSlotSel : 1);
    final cur = loadout.inSlot(target);

    Widget variantCard(PetDef def) {
      final pm = _activeWorldEvent == 'night_market' ? 0.8 : 1.0;
      final why = loadout.whyCannotBuy(def, target, money, priceMul: pm);
      final isCur = cur?.def.key == def.key;
      final net = (def.price * pm).floor() - (cur?.def.refund ?? 0);
      final ok = why == null && canAct;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: (ok || isCur) ? 1 : 0.5,
            child: Material(
              color: rc[def.rarity].withValues(alpha: 0.16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: rc[def.rarity].withValues(alpha: isCur ? 1 : 0.55),
                    width: isCur ? 2 : 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: isCur
                    ? null
                    : ok
                    ? () {
                  Navigator.pop(ctx);
                  _act('buy_pet',
                      {'p_pet_key': def.key, 'p_slot': target});
                }
                    : (why == null ? null : () => _toast(why, error: true)),
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final c in [def.body, def.accent])
                            Container(
                              width: 18,
                              height: 18,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white54)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(def.variant,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5)),
                      Text(def.rarityName,
                          style: TextStyle(
                              color: rc[def.rarity],
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(def.perkLine,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10.5)),
                      const SizedBox(height: 6),
                      Text(isCur ? 'Terpasang' : '$net',
                          style: const TextStyle(
                              color: gold,
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header('${sp.emoji} ${sp.label}: pilih warna'),
          const SizedBox(height: 6),
          if (full) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Text('Slot penuh. Hewan mana yang diganti?',
                  style: TextStyle(color: Colors.white60, fontSize: 11.5)),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 1; i <= Pets.maxSlots; i++)
                  ChoiceChip(
                    selected: target == i,
                    onSelected: (_) => setState(() => _petSlotSel = i),
                    label: Text(loadout.inSlot(i)?.displayName ?? 'Slot $i'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(children: [
            for (final def in Pets.ofSpecies(sp)) variantCard(def),
          ]),
          if (owned != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canAct ? () => _renamePet(owned!) : null,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Beri nama'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canAct
                      ? () {
                    Navigator.pop(ctx);
                    _act('release_pet', {'p_slot': owned!.slot});
                  }
                      : null,
                  icon: const Icon(Icons.logout, size: 16),
                  label: Text('Lepas (+${owned.def.refund})'),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  /// Perkiraan jumlah sampah yang akan dituang ke gudang saat ini.
  int _pourAmt(Map<String, dynamic> me, WhLive w) {
    if (!w.built) return 0;
    return Wh.pourAmount(
      liveTrash: _live(me).trash,
      trashCapacity: _num(me['trash_capacity']),
      stored: w.stored,
      tier: w.tier,
      comps: w.comps,
    );
  }

  bool get _canActNow =>
      _room['status'] != 'finished' && _activeRpc == null && !_cine.blocksInput;

  void _pourToWarehouse() {
    final me = _states[_me];
    if (me == null) return;
    final w = _whLive(_me);
    if (!w.built) {
      _toast('Bangun gudang dulu lewat tombol Gudang.', error: true);
      return;
    }
    final wasteLv = _num(me['waste_level']).toInt();
    if (wasteLv <= 0) {
      _toast('Butuh kotak sampah dulu.', error: true);
      return;
    }
    if (_activeWorldEvent == 'earthquake') {
      _toast('Gempa bumi! Gerobak tidak bisa jalan.', error: true);
      return;
    }
    if (w.pourLeft > 0) {
      _toast('Gerobak masih jeda ${w.pourLeft.ceil()}s.', error: true);
      return;
    }
    final amt = _pourAmt(me, w);
    if (amt < 1) {
      _toast(w.cap - w.stored < 1 ? 'Gudang penuh.' : 'Kotak sampah kosong.',
          error: true);
      return;
    }
    if (!_canActNow) return;
    _act('warehouse_pour');
  }

  void _callWarehouseTruck() {
    final me = _states[_me];
    if (me == null) return;
    final w = _whLive(_me);
    if (!w.built) {
      _toast('Gudang belum dibangun.', error: true);
      return;
    }
    if (_activeWorldEvent == 'hauler_strike') {
      _toast('Petugas truk sedang mogok kerja!', error: true);
      return;
    }
    if (w.truckProgress != null) {
      _toast('Truk sedang mengangkut.', error: true);
      return;
    }
    if (w.truckReadyLeft > 0) {
      _toast('Truk masih jeda ${w.truckReadyLeft.ceil()}s.', error: true);
      return;
    }
    if (w.stored < 1) {
      _toast('Gudang kosong.', error: true);
      return;
    }
    final cost = Wh.truckCost(w.stored.floorToDouble(), w.comps);
    if (_live(me).money < cost) {
      _toast('Uang kurang: truk butuh $cost.', error: true);
      return;
    }
    if (!_canActNow) return;
    _act('warehouse_call_truck');
  }

  void _openWarehouse() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A2820),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
          child: AnimatedBuilder(
            animation: _anim,
            builder: (ctx, _) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              child: _warehousePanel(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _warehousePanel() {
    final me = _states[_me];
    if (me == null || me['eliminated_at'] != null) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('Gudang hanya untuk pemain yang masih hidup.',
              style: TextStyle(color: Colors.white70)),
        ),
      );
    }
    final w = _whLive(_me);
    final live = _live(me);
    final finished = _room['status'] == 'finished';
    final canAct = !finished && _activeRpc == null && !_cine.blocksInput;
    const gold = Color(0xFFFFCA28);

    Widget tile({
      required String emoji,
      required String title,
      required String sub,
      required String trailing,
      required bool ok,
      required VoidCallback? onTap,
    }) =>
        ListTile(
          enabled: ok,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6),
          leading: Text(emoji, style: const TextStyle(fontSize: 26)),
          title: Text(title,
              style: TextStyle(
                  color: ok ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.w800)),
          subtitle: Text(sub,
              style: TextStyle(
                  color: ok ? Colors.white70 : Colors.white30, fontSize: 12)),
          trailing: Text(trailing,
              style: TextStyle(
                  color: ok ? gold : Colors.white38,
                  fontWeight: FontWeight.w900,
                  fontSize: 15)),
          onTap: ok ? onTap : null,
        );

    final children = <Widget>[
      Row(
        children: [
          const Icon(Icons.warehouse_rounded, color: Color(0xFFFFB74D)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              Wh.tierNames[w.tier],
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900),
            ),
          ),
          Text('Uang ${live.money.floor()}',
              style: const TextStyle(
                  color: gold, fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
      const SizedBox(height: 8),
    ];

    if (!w.built) {
      final cost = Wh.tierCost[1];
      children.addAll([
        const Text(
          'Lahan kosong di sisi kanan kost. Gudang punya kapasitas sendiri, '
              'terpisah dari kotak sampah. Setelah dibangun, muncul tombol '
              'kirim sampah dan buang gudang di atas tombol Gudang.',
          style: TextStyle(color: Colors.white70, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        tile(
          emoji: '🏗️',
          title: 'Bangun ${Wh.tierNames[1]}',
          sub: 'Kapasitas ${Wh.cap(1).floor()} · proses '
              '${Wh.procRate(1, 0).toStringAsFixed(2)}/dtk',
          trailing: '$cost',
          ok: canAct && live.money >= cost,
          onTap: () => _act('warehouse_upgrade_tier'),
        ),
      ]);
      return Column(mainAxisSize: MainAxisSize.min, children: children);
    }

    // --- status ---
    final rate = Wh.procRate(w.tier, w.comps);
    children.addAll([
      _meter(w.stored, w.cap,
          w.fill < 0.6 ? Colors.lightGreen : (w.fill < 0.85 ? gold : Colors.redAccent),
          height: 10),
      const SizedBox(height: 4),
      Text(
        'Isi ${w.stored.floor()}/${w.cap.floor()} · diproses ${rate.toStringAsFixed(2)}/dtk '
            '· ${Wh.coinPerUnit(w.comps).toStringAsFixed(1)} koin/sampah',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      const SizedBox(height: 10),
    ]);

    children.add(const Text(
      'Tombol kecil di atas tombol Gudang: kirim sampah ke gudang '
          'dan buang gudang (panggil truk).',
      style: TextStyle(color: Colors.white54, fontSize: 11.5),
    ));
    children.add(const SizedBox(height: 8));

    // --- naik tier (berurutan) ---
    if (w.tier < Wh.maxTier) {
      final nt = w.tier + 1;
      final cost = Wh.tierCost[nt];
      children.add(tile(
        emoji: '🏗️',
        title: 'Naik ke ${Wh.tierNames[nt]}',
        sub: 'Kapasitas ${Wh.cap(nt).floor()} · proses dasar '
            '${Wh.tierProc[nt].toStringAsFixed(2)}/dtk',
        trailing: '$cost',
        ok: canAct && live.money >= cost,
        onTap: () => _act('warehouse_upgrade_tier'),
      ));
    } else {
      children.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text('Gudang sudah di tingkat tertinggi.',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
      ));
    }

    // --- komponen (bebas urutan) ---
    children.add(const Divider(color: Colors.white12, height: 14));
    children.add(const Padding(
      padding: EdgeInsets.only(bottom: 2),
      child: Text('Komponen · beli bebas urutan',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
    ));
    for (final c in kWhComps) {
      final owned = Wh.has(w.comps, c.bit);
      children.add(tile(
        emoji: c.emoji,
        title: owned ? '${c.name} ✓' : c.name,
        sub: c.desc,
        trailing: owned ? 'Terpasang' : '${c.cost}',
        ok: !owned && canAct && live.money >= c.cost,
        onTap: () => _act('warehouse_buy_comp', {'p_comp': c.bit}),
      ));
    }

    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  // ------------------------------------------------------- loket sampah

  void _openBooth() {
    var amount = 20.0;
    var price = 40.0;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 520),
      backgroundColor: const Color(0xFF1A2820),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => AnimatedBuilder(
          animation: _anim,
          builder: (ctx, _) {
            final me = _states[_me];
            if (me == null || me['eliminated_at'] != null) {
              return const SizedBox(
                height: 120,
                child: Center(
                  child: Text('Loket hanya untuk pemain yang masih hidup.',
                      style: TextStyle(color: Colors.white70)),
                ),
              );
            }
            final mine = _live(me);
            final left = _remaining(me['booth_until']);
            final open = left > 0;
            final maxAmt = max(1.0, min(50.0, mine.trash.floorToDouble()));
            if (amount > maxAmt) amount = maxAmt;
            final rivals = [
              for (final e in _states.entries)
                if (e.key != _me && e.value['eliminated_at'] == null) e.key
            ];

            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('🏪 ', style: TextStyle(fontSize: 22)),
                          const Expanded(
                            child: Text(
                              'Loket Sampah',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (open)
                            Text('buka ${left.ceil()} dtk',
                                style: const TextStyle(
                                  color: Color(0xFF69F0AE),
                                  fontWeight: FontWeight.w800,
                                )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!open) ...[
                        const Text(
                          'Buka loket (30 uang, aktif 40 detik) untuk menawar uang kepada pemain lain agar mau menampung sampahmu. Mereka boleh menolak.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: (mine.money >= 30 && _activeRpc == null)
                                ? () => _act('open_trash_booth')
                                : null,
                            child: Text(mine.money >= 30
                                ? 'Buka Loket · 30'
                                : 'Uang belum cukup (30)'),
                          ),
                        ),
                      ] else if (rivals.isEmpty) ...[
                        const Text('Tidak ada pemain lain yang bisa ditawari.',
                            style: TextStyle(color: Colors.white70)),
                      ] else ...[
                        Text('Jumlah sampah: ${amount.round()}',
                            style: const TextStyle(color: Colors.white)),
                        Slider(
                          value: amount,
                          min: 1,
                          max: maxAmt,
                          divisions: maxAmt > 1 ? (maxAmt - 1).round() : null,
                          onChanged: mine.trash >= 2
                              ? (v) => setSheet(() => amount = v)
                              : null,
                        ),
                        Text('Kamu bayar: ${price.round()} uang',
                            style: const TextStyle(color: Colors.white)),
                        Slider(
                          value: price,
                          min: 0,
                          max: 300,
                          divisions: 60,
                          onChanged: (v) => setSheet(() => price = v),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final r in rivals)
                              FilledButton.icon(
                                icon: const Icon(Icons.send, size: 16),
                                label: Text('Tawar ${_name(r)}'),
                                onPressed: (!_offerBusy &&
                                    mine.trash >= amount &&
                                    mine.money >= price)
                                    ? () => _sendOffer(
                                    r, amount.round(), price.round())
                                    : null,
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tawaran berlaku 10 detik. Uang berpindah hanya bila lawan menerima.',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _offerCard(Map<String, dynamic>? me) {
    final o = _incomingOffer!;
    final amt = _num(o['trash_amount']).round();
    final price = _num(o['price']).round();
    final left = _remaining(o['expires_at']);
    final live = me == null ? null : _live(me);
    final cap = me == null ? 1.0 : _num(me['trash_capacity']);
    final fatal = live != null && live.trash + amt >= cap;
    final btnPad = ButtonStyle(
      padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 12)),
      minimumSize: WidgetStateProperty.all(const Size(0, 34)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
    return Align(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: _glass(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🏪 ${_name(o['sender_id'])} menitip $amt sampah',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          fatal ? 'Akan menimbun kostmu!' : 'Dibayar $price uang',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fatal
                                ? Colors.red.shade300
                                : const Color(0xFFFFCA28),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: btnPad,
                    onPressed: _offerBusy ? null : () => _respondOffer(false),
                    child: const Text('Tolak'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    style: btnPad,
                    onPressed:
                    (_offerBusy || fatal) ? null : () => _respondOffer(true),
                    child: Text('+$price'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _meter(left, 10, const Color(0xFF69F0AE), height: 3),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------- kontrol zoom

  Widget _zoomPanel({
    required bool hasHome,
    required String? focusId,
    required int count,
  }) {
    final overview = focusId == null;
    final atHome = focusId != null && focusId == _me;

    Widget btn(IconData icon, String tip, bool active, VoidCallback? onTap) {
      return Tooltip(
        message: tip,
        child: Material(
          color: active ? const Color(0xFFFFCA28) : Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                icon,
                size: 20,
                color: active
                    ? Colors.black87
                    : (onTap == null ? Colors.white30 : Colors.white),
              ),
            ),
          ),
        ),
      );
    }

    return _glass(
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasHome) btn(Icons.home_rounded, 'Zoom ke rumahku', atHome, _zoomHome),
          btn(
            Icons.holiday_village_rounded,
            'Lihat semua tetangga',
            overview,
            count > 1 ? _zoomAll : null,
          ),
          if (count > 1) ...[
            const SizedBox(width: 2),
            btn(
              Icons.chevron_left_rounded,
              'Rumah sebelumnya',
              false,
              overview ? null : () => _stepFocus(-1),
            ),
            btn(
              Icons.chevron_right_rounded,
              'Rumah berikutnya',
              false,
              overview ? null : () => _stepFocus(1),
            ),
          ],
        ],
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
    this.shortTitle,
    this.shortSub,
    this.busy = false,
  });

  final String? shortTitle;
  final String? shortSub;
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
    final avatarR = mode == 0 ? 15.0 : (mode == 1 ? 11.0 : 12.5);
    final titleSize = mode == 0 ? 12.0 : (mode == 1 ? 10.5 : 11.0);
    final subSize = mode == 0 ? 10.5 : (mode == 1 ? 9.5 : 9.5);
    final titleText = mode == 1 ? (shortTitle ?? title) : title;
    final subText = mode == 1 ? (shortSub ?? subtitle) : subtitle;

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
          child: Text(titleText,
              maxLines: 1,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800)),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(subText,
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
                horizontal: mode == 2 ? 7 : 3, vertical: mode == 2 ? 3 : 4),
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
                SizedBox(height: mode == 1 ? 2 : 4),
                texts,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu pemberitahuan singkat (kabar, info, galat) di bawah HUD.
class _Notice {
  const _Notice(this.id, this.text, this.icon, this.color);
  final int id;
  final String text;
  final IconData icon;
  final Color color;
}

/// Satu status aktif: ringkas untuk chip, lengkap untuk lembar rincian.
class _StatusItem {
  const _StatusItem(this.icon, this.short, this.long, this.color);
  final IconData icon;
  final String short;
  final String long;
  final Color color;
}