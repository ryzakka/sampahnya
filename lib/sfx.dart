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

  /// Batas lama bunyi (ms) = lama animasinya. Setelah itu suara dipudarkan
  /// dan dihentikan, walau file mp3-nya lebih panjang. Tanpa entri = putar
  /// sampai selesai sendiri.
  static const Map<String, int> _cap = {
    'construct-hammer': 2600, // animasi kamar di lantai yang sama
    'construct-crane': 5200, //  animasi lantai baru
    'fireburn': 4500,
    'upgrade': 3200,
    'collapse': 2800, //         dampak gempa
    'building-collapse': 3500,
    'police': 11800, //          kPoliceTotalMs
    'opening': 12800, //         kIntroMs
    'opening-single-player': 12800,
    'door': 1400,
    'fly1': 2500,
    'fly2': 2500,
    'confirm': 1500,
    'beep-warning': 4000,
    'truck-beep': 2500,
    'werehouse-open': 3000,
  };

  static const int _poolSize = 6;
  final List<AudioPlayer> _pool = [];
  int _next = 0;
  final List<int> _token = List<int>.filled(_poolSize, 0);
  final List<Timer?> _stopTimer = List<Timer?>.filled(_poolSize, null);
  int _epoch = 0; // naik tiap stopAll(): membatalkan playLater yang tertunda
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
  /// [maxMs] memotong bunyi (dengan fade 250 ms) agar berhenti bersamaan
  /// dengan animasinya; bila null dipakai batas bawaan di [_cap].
  Future<void> play(String name,
      {double gain = 1.0, int minGapMs = 150, int? maxMs}) async {
    if (_muted || !_inited) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_lastMs[name] ?? 0) < minGapMs) return;
    _lastMs[name] = now;
    try {
      final slot = _next;
      final p = _pool[slot];
      _next = (_next + 1) % _pool.length;
      final v = ((_vol[name] ?? 0.7) * gain * _master).clamp(0.0, 1.0).toDouble();
      final token = ++_token[slot];
      _stopTimer[slot]?.cancel();
      await p.stop();
      await p.setVolume(v);
      await p.play(AssetSource('$_dir$name.mp3'));
      final cap = maxMs ?? _cap[name];
      if (cap != null && cap > 0) {
        _stopTimer[slot] =
            Timer(Duration(milliseconds: cap), () => _fadeStop(slot, token, v));
      }
    } catch (e) {
      debugPrint('Sfx gagal memutar $name: $e');
    }
  }

  /// Pudarkan lalu hentikan slot [slot], hanya bila masih memutar bunyi yang
  /// sama (token cocok) - bunyi baru di slot itu tidak ikut terpotong.
  void _fadeStop(int slot, int token, double from) {
    const steps = 5;
    var i = 0;
    Timer.periodic(const Duration(milliseconds: 50), (t) async {
      if (_token[slot] != token) {
        t.cancel();
        return;
      }
      i++;
      try {
        if (i >= steps) {
          t.cancel();
          await _pool[slot].stop();
        } else {
          await _pool[slot].setVolume(from * (1 - i / steps));
        }
      } catch (_) {
        t.cancel();
      }
    });
  }

  /// Putar setelah [delayMs]; dibatalkan otomatis bila [stopAll] dipanggil
  /// (mis. pemain keluar dari game) sebelum waktunya.
  void playLater(String name, int delayMs,
      {double gain = 1.0, int minGapMs = 150, int? maxMs}) {
    final e = _epoch;
    Timer(Duration(milliseconds: delayMs), () {
      if (e != _epoch) return;
      play(name, gain: gain, minGapMs: minGapMs, maxMs: maxMs);
    });
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
    _epoch++;
    await rainStop(immediate: true);
    for (var i = 0; i < _pool.length; i++) {
      _token[i]++;
      _stopTimer[i]?.cancel();
    }
    for (final p in _pool) {
      try {
        await p.stop();
      } catch (_) {}
    }
  }
}