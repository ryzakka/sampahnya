import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mode Ringan bertingkat untuk perangkat rendah.
///
///  0 = Normal
///  1 = Ringan        : adegan ±30 fps, partikel dikurangi, lalu lintas &
///                      pejalan kaki ~60%, tanpa berkas cahaya/gagak/blur kaca,
///                      UI diperbarui 10 Hz
///  2 = Sangat Ringan : adegan 20 fps, tanpa pejalan kaki & cakrawala kota,
///                      lalu lintas ~35%, tanpa lalat/bau, tikus, isi jendela
///                      malam disederhanakan, UI ~7 Hz
class KostPerf {
  KostPerf._();

  static final ValueNotifier<int> level = ValueNotifier<int>(0);
  static bool get on => level.value >= 1;
  static bool get ultra => level.value >= 2;

  /// Jeda minimum antar gambar ulang adegan (ms). 0 = tanpa batas (normal).
  static int get frameMs => ultra ? 50 : (on ? 33 : 0);

  /// UI game diperbarui tiap N tick timer 50 ms.
  static int get uiEvery => ultra ? 3 : (on ? 2 : 1);

  static const List<String> names = ['Mati', 'Ringan', 'Sangat Ringan'];
  static String get name => names[level.value.clamp(0, 2).toInt()];

  /// Diisi layar game: dipanggil saat tingkat dinaikkan otomatis.
  static void Function(int newLevel)? onAutoRaised;

  static const String _kLevel = 'perf_level';
  static const String _kLegacy = 'perf_lite'; // versi lama (bool)
  static const String _kUser = 'perf_user'; // pemain sudah memilih sendiri
  static bool _userDecided = false;
  static bool _watching = false;

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      level.value = p.getInt(_kLevel) ?? ((p.getBool(_kLegacy) ?? false) ? 1 : 0);
      _userDecided = p.getBool(_kUser) ?? false;
    } catch (e) {
      debugPrint('KostPerf.load gagal: $e');
    }
  }

  /// [byUser] true = pilihan manual; deteksi otomatis tidak menimpanya.
  static Future<void> setLevel(int v, {bool byUser = true}) async {
    level.value = v.clamp(0, 2).toInt();
    if (byUser) {
      _userDecided = true;
      _stopWatching();
    }
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kLevel, level.value);
      if (byUser) await p.setBool(_kUser, true);
    } catch (_) {}
  }

  /// Mati -> Ringan -> Sangat Ringan -> Mati.
  static Future<void> cycle() => setLevel((level.value + 1) % 3);

  // ------------------------------------------------- deteksi otomatis

  static const int _warmup = 120; // abaikan frame awal (memuat aset, dll.)
  static const int _window = 120; // frame per penilaian
  static const int _slowMs = 24; //  frame > 24 ms = patah-patah
  static int _seen = 0;
  static int _inWindow = 0;
  static int _slow = 0;

  /// Mulai memantau waktu frame. Aman dipanggil berulang. Bila masih patah-
  /// patah di tingkat Ringan, otomatis naik ke Sangat Ringan.
  static void startAutoDetect() {
    if (_watching || _userDecided || ultra) return;
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
          final next = level.value + 1;
          setLevel(next, byUser: false);
          onAutoRaised?.call(next);
          if (next >= 2) {
            _stopWatching();
          } else {
            _seen = 0; // beri pemanasan lagi sebelum menilai tingkat baru
          }
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