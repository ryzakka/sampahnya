import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// Musik latar. Lagu pertama SELALU beach1 (layar pembuka / lobi),
/// sesudahnya diacak dengan "shuffle bag" (semua lagu terputar sekali
/// sebelum ada yang diulang, dan tidak ada lagu sama berturut-turut).
class Bgm with WidgetsBindingObserver {
  Bgm._();
  static final Bgm instance = Bgm._();

  static const String _intro = 'audio/beach1.mp3';
  static const List<String> _all = [
    'audio/beach1.mp3',
    'audio/beach2.mp3',
    'audio/friendly1.mp3',
    'audio/friendly2.mp3',
    'audio/friendly3.mp3',
    'audio/friendly4.mp3',
  ];

  final AudioPlayer _player = AudioPlayer();
  final math.Random _rng = math.Random();
  final List<String> _bag = [];
  String? _last;
  bool _inited = false;
  bool _playing = false; // sudah berhasil memutar minimal satu lagu
  bool _muted = false;
  bool _pausedByApp = false;
  static const double lobbyVolume = 0.5;
  static const double gameVolume = 0.14; // pelan tapi tetap terdengar
  double _volume = lobbyVolume;
  Timer? _fade;

  bool get muted => _muted;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    WidgetsBinding.instance.addObserver(this);
    try {
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.setVolume(_volume);
      _player.onPlayerComplete.listen((_) => _playNext());
    } catch (e) {
      debugPrint('Bgm.init gagal: $e');
    }
  }

  /// Aman dipanggil berulang (splash initState + tombol MULAI). Bila
  /// pemutaran pertama diblokir autoplay (web), panggilan berikutnya
  /// dari gestur pengguna akan mencoba lagi.
  Future<void> startLobby() async {
    if (_playing) return;
    await init();
    _last = _intro;
    await _play(_intro);
  }

  /// Mulai pertandingan: musik dipelankan (mulus) dan lagu diacak ulang;
  /// lagu baru dijamin berbeda dari yang sedang diputar (beach1 di lobi).
  Future<void> enterGame() async {
    await init();
    _fadeTo(gameVolume);
    _bag.clear();
    await _playNext();
  }

  /// Kembali ke lobi: volume normal dan lagu pembuka (beach1) lagi.
  Future<void> enterLobby() async {
    await init();
    _fadeTo(lobbyVolume);
    _bag.clear();
    _last = _intro;
    await _play(_intro);
  }

  void _fadeTo(double target, {int ms = 800}) {
    _fade?.cancel();
    final from = _volume;
    const tick = 50;
    final steps = math.max(1, ms ~/ tick);
    var i = 0;
    _fade = Timer.periodic(const Duration(milliseconds: tick), (t) {
      i++;
      final v = i >= steps ? target : from + (target - from) * i / steps;
      setVolume(v);
      if (i >= steps) t.cancel();
    });
  }

  Future<void> _playNext() async {
    if (_bag.isEmpty) {
      _bag.addAll(_all);
      _bag.shuffle(_rng);
      if (_bag.length > 1 && _bag.first == _last) {
        _bag.add(_bag.removeAt(0));
      }
    }
    final next = _bag.removeAt(0);
    _last = next;
    await _play(next);
  }

  Future<void> _play(String asset) async {
    if (_muted) return;
    try {
      await _player.play(AssetSource(asset));
      _playing = true;
    } catch (e) {
      _playing = false;
      debugPrint('Bgm gagal memutar $asset: $e');
    }
  }

  Future<void> setMuted(bool m) async {
    _muted = m;
    try {
      if (m) {
        await _player.pause();
      } else if (_playing) {
        await _player.resume();
      } else {
        await startLobby();
      }
    } catch (_) {}
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0).toDouble();
    try {
      await _player.setVolume(_volume);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive) {
      if (_player.state == PlayerState.playing) {
        _pausedByApp = true;
        _player.pause();
      }
    } else if (s == AppLifecycleState.resumed && _pausedByApp && !_muted) {
      _pausedByApp = false;
      _player.resume();
    }
  }
}