import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mode Ringan untuk perangkat rendah.
///  - gambar adegan dibatasi ±30 fps (bukan 60/120)
///  - partikel cuaca/efek dikurangi, berkas cahaya & gagak dimatikan
///  - rebuild UI game diperlambat (20 Hz -> 10 Hz)
///  - tanpa blur kaca di menu
/// Bisa dinyalakan manual, atau otomatis bila perangkat terdeteksi patah-patah.
class KostPerf {
  KostPerf._();

  static final ValueNotifier<bool> lite = ValueNotifier<bool>(false);
  static bool get on => lite.value;

  /// Jeda minimum antar gambar ulang adegan (ms). 0 = tanpa batas (normal).
  static int get frameMs => on ? 33 : 0;

  /// Diisi layar game agar bisa memberi tahu pemain saat mode ringan
  /// dinyalakan otomatis.
  static VoidCallback? onAutoEnabled;

  static const String _kLite = 'perf_lite';
  static const String _kUser = 'perf_user'; // pemain sudah memilih sendiri
  static bool _userDecided = false;
  static bool _watching = false;

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      lite.value = p.getBool(_kLite) ?? false;
      _userDecided = p.getBool(_kUser) ?? false;
    } catch (e) {
      debugPrint('KostPerf.load gagal: $e');
    }
  }

  /// [byUser] true = pilihan manual; deteksi otomatis tidak akan menimpanya.
  static Future<void> set(bool v, {bool byUser = true}) async {
    lite.value = v;
    if (byUser) {
      _userDecided = true;
      _stopWatching();
    }
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kLite, v);
      if (byUser) await p.setBool(_kUser, true);
    } catch (_) {}
  }

  // ------------------------------------------------- deteksi otomatis

  static const int _warmup = 120; // abaikan frame awal (memuat aset, dll.)
  static const int _window = 120; // frame per penilaian
  static const int _slowMs = 24; //  frame > 24 ms = patah-patah
  static int _seen = 0;
  static int _inWindow = 0;
  static int _slow = 0;

  /// Mulai memantau waktu frame. Aman dipanggil berulang.
  static void startAutoDetect() {
    if (_watching || _userDecided || on) return;
    _watching = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static void _stopWatching() {
    if (!_watching) return;
    _watching = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _seen++;
      if (_seen <= _warmup) continue;
      _inWindow++;
      if (t.totalSpan.inMilliseconds > _slowMs) _slow++;
      if (_inWindow >= _window) {
        final bad = _slow / _inWindow;
        _inWindow = 0;
        _slow = 0;
        if (bad > 0.4) {
          _stopWatching();
          set(true, byUser: false);
          onAutoEnabled?.call();
          return;
        }
      }
    }
  }
}

/// Meneruskan notifikasi [source] (mis. AnimationController) ke pendengarnya,
/// tetapi paling sering sekali per [KostPerf.frameMs]. Dalam mode normal
/// (frameMs = 0) semua tick diteruskan apa adanya.
class ThrottledListenable extends ChangeNotifier {
  ThrottledListenable(this._source) {
    _source.addListener(_tick);
  }

  final Listenable _source;
  final Stopwatch _sw = Stopwatch()..start();
  int _last = -100000;

  void _tick() {
    final gap = KostPerf.frameMs;
    final now = _sw.elapsedMilliseconds;
    if (gap > 0 && now - _last < gap - 2) return;
    _last = now;
    notifyListeners();
  }

  @override
  void dispose() {
    _source.removeListener(_tick);
    super.dispose();
  }
}