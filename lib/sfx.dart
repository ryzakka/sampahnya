import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Efek suara (assets/soundeffect/*.mp3). Singleton.
///  - [play]       : sekali putar, memakai kolam pemutar (bisa tumpang tindih)
///  - [rainStart]/[rainStop] : hujan berulang (loop) yang DIHENTIKAN manual,
///    jadi panjang file tidak perlu pas dengan lamanya event.
class Sfx {
  Sfx._();
  static final Sfx instance = Sfx._();

  static const String _dir = 'soundeffect/';

  // nama file (tanpa .mp3) -> volume dasar
  static const Map<String, double> _vol = {
    'beep-warning': 0.7,
    'building-collapse': 0.9,
    'collapse': 0.8,
    'confirm': 0.5,
    'construct-crane': 0.8,
    'construct-hammer': 0.8,
    'door': 0.6,
    'fireburn': 0.7,
    'fly1': 0.35,
    'fly2': 0.35,
    'opening': 0.8,
    'opening-single-player': 0.8,
    'game-lose': 0.9,
    'game-win': 0.9,
    'police': 0.8,
    'truck-beep': 0.6,
    'truck-moving': 0.6,
    'upgrade': 0.8,
    'werehouse-open': 0.8, // sesuai nama file (typo "werehouse")
  };

  static const int _poolSize = 6;
  final List<AudioPlayer> _pool = [];
  int _next = 0;
  final Map<String, int> _lastMs = {};
  final math.Random _rng = math.Random();

  final AudioPlayer _rain = AudioPlayer();
  bool _rainOn = false;
  Timer? _rainFade;

  bool _inited = false;
  bool _muted = false;
  double _master = 1.0;

  bool get muted => _muted;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      for (var i = 0; i < _poolSize; i++) {
        final p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.stop);
        _pool.add(p);
      }
      await _rain.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      debugPrint('Sfx.init gagal: $e');
    }
  }

  Future<void> setMuted(bool m) async {
    _muted = m;
    if (m) await rainStop(immediate: true);
  }

  void setMaster(double v) => _master = v.clamp(0.0, 1.0).toDouble();

  /// Putar sekali. [minGapMs] mencegah bunyi yang sama menumpuk.
  Future<void> play(String name, {double gain = 1.0, int minGapMs = 150}) async {
    if (_muted || !_inited) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_lastMs[name] ?? 0) < minGapMs) return;
    _lastMs[name] = now;
    try {
      final p = _pool[_next];
      _next = (_next + 1) % _pool.length;
      final v = ((_vol[name] ?? 0.7) * gain * _master).clamp(0.0, 1.0);
      await p.stop();
      await p.setVolume(v.toDouble());
      await p.play(AssetSource('$_dir$name.mp3'));
    } catch (e) {
      debugPrint('Sfx gagal memutar $name: $e');
    }
  }

  // ------------------------------------------------------ hujan (loop)

  Future<void> rainStart() async {
    if (_muted || !_inited || _rainOn) return;
    _rainOn = true;
    _rainFade?.cancel();
    try {
      await _rain.setVolume(0.55 * _master);
      await _rain.play(AssetSource('${_dir}rain.mp3'));
    } catch (e) {
      _rainOn = false;
      debugPrint('Sfx hujan gagal: $e');
    }
  }

  /// Hentikan hujan. Default: memudar ±1,2 dtk supaya tidak terpotong kasar.
  Future<void> rainStop({bool immediate = false}) async {
    if (!_rainOn) return;
    _rainOn = false;
    _rainFade?.cancel();
    if (immediate) {
      try {
        await _rain.stop();
      } catch (_) {}
      return;
    }
    var v = 0.55 * _master;
    final step = v / 12;
    _rainFade = Timer.periodic(const Duration(milliseconds: 100), (t) async {
      v -= step;
      if (v <= 0.01 || _rainOn) {
        t.cancel();
        if (!_rainOn) {
          try {
            await _rain.stop();
          } catch (_) {}
        }
        return;
      }
      try {
        await _rain.setVolume(v);
      } catch (_) {}
    });
  }

  // ------------------------------------------------------ lalat

  int _nextFlyMs = 0;

  /// Panggil sering (mis. tiap 50 ms) dengan rasio sampah kost sendiri.
  /// Berdengung acak tiap 3–7 dtk saat rasio >= 0.5 (sama dengan lalat visual).
  void fliesTick(double ratio) {
    if (_muted || ratio < 0.5) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < _nextFlyMs) return;
    _nextFlyMs = now + 3000 + _rng.nextInt(4000);
    play(_rng.nextBool() ? 'fly1' : 'fly2',
        gain: 0.6 + 0.4 * ratio, minGapMs: 0);
  }

  Future<void> stopAll() async {
    await rainStop(immediate: true);
    for (final p in _pool) {
      try {
        await p.stop();
      } catch (_) {}
    }
  }
}