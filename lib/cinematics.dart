import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kost_scene.dart';

// ====================================================================
//  SINEMATIK GIM (v1)
//
//  1) Intro pembuka   : fajar -> pagi emas, pan kamera menyusuri jalan kost,
//                       sinar matahari, burung, lalu judul gim
//  2) Rumah tertimbun : hujan, longsoran sampah, lampu padam, penghuni sedih
//  3) Sidak polisi    : telepon -> mobil polisi tiba -> garis polisi -> segel
//
//  Pembagian tugas:
//   - gambar DALAM dunia (mobil, pita, longsoran sampah) ada di kost_scene.dart
//     dan digerakkan lewat KostSceneData.policeAgeMs / buriedAgeMs.
//   - gambar di LAYAR (letterbox, teks, hujan, kilau sirine, kartu telepon,
//     judul) ada di file ini.
//   - [CineDirector] menyimpan jadwal semua adegan + kamera, dipanggil dari
//     game_screen.dart.
// ====================================================================

/// Durasi total tiap adegan (ms).
const int kIntroMs = 12800;

/// Garis waktu intro (ms).
const int kIntroPanMs = 6000; //     pan menyusuri jalan: 0 .. 6000
const int kIntroWideEndMs = 8400; // melebar: 6000 .. 8400, lalu mendarat
const int kIntroTitleMs = 8600; //   judul gim muncul
const int kBuriedMs = 9200;
const int kCallMs = 3000;

double _c01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _lerp(double a, double b, double t) => a + (b - a) * t;
double _ease(double x) {
  x = _c01(x);
  return x * x * (3 - 2 * x);
}

/// Smootherstep (kuintik): start & akhir jauh lebih lembut dari smoothstep.
double _ease5(double x) {
  x = _c01(x);
  return x * x * x * (x * (x * 6 - 15) + 10);
}

double _easeOutCubic(double x) {
  x = _c01(x);
  final y = 1 - x;
  return 1 - y * y * y;
}

double _easeOutBack(double x) {
  x = _c01(x);
  const c1 = 2.1;
  const c3 = c1 + 1;
  final y = x - 1;
  return 1 + c3 * y * y * y + c1 * y * y;
}

/// Amplop 0..1: naik di awal jendela [a, b], turun di akhir.
double _win(double t, double a, double b, [double f = 350]) =>
    _c01(math.min((t - a) / f, (b - t) / f));

// --------------------------------------------------------------- data

class _Intro {
  _Intro(this.start, this.order, this.names, this.myId);

  final int start;
  final List<String> order;
  final Map<String, String> names;
  final String? myId;
  bool haptic = false;
}

class _Buried {
  _Buried(this.id, this.name, this.isMe, this.start, this.camCx0, this.camS0);

  final String id;
  final String name;
  final bool isMe;
  final int start;
  final double camCx0;
  final double camS0;
  bool haptic = false;
}

class _Call {
  _Call(this.start, this.actor, this.target, this.iAmActor, this.iAmTarget);

  final int start;
  final String actor;
  final String target;
  final bool iAmActor;
  final bool iAmTarget;
}

class _Police {
  _Police(this.id, this.name, this.start, this.reflected, this.actorName,
      this.amount, this.iAmTarget, this.camCx0, this.camS0);

  final String id;
  final String name;
  final int start;
  final bool reflected;
  final String actorName;
  final int amount;
  final bool iAmTarget;
  final double camCx0;
  final double camS0;
}

// ------------------------------------------------------------ sutradara

class CineDirector {
  _Intro? _intro;
  _Buried? _buried;
  _Call? _call;
  _Police? _police;
  int _blackFadeStart = -100000;

  final Map<String, int> _policeStart = {};
  final Map<String, int> _buriedStart = {};
  final Set<String> _buriedSeen = {};

  /// Intro sedang tayang: input game dikunci & HUD disembunyikan.
  bool get introActive => _intro != null;
  bool get blocksInput => _intro != null;

  /// Ada rumah yang sedang "tertimbun": kartu hasil akhir & stempel
  /// TERTIMBUN ditahan sampai adegan selesai.
  bool get holdFinish => _buried != null;

  /// Kamera sedang diambil alih sutradara (game_screen tidak boleh
  /// menimpa targetnya).
  bool get takesCamera => _intro != null || _buried != null || _police != null;

  // ------------------------------------------------------------ memulai

  void playIntro({
    required List<String> order,
    required Map<String, String> names,
    required String? myId,
  }) {
    _intro = _Intro(sceneNowMs(), List<String>.of(order),
        Map<String, String>.of(names), myId);
  }

  void skipIntro() {
    if (_intro == null) return;
    _intro = null;
    _blackFadeStart = sceneNowMs(); // potong ke hitam, lalu terang perlahan
  }

  /// Mengembalikan false bila rumah ini sudah pernah diputar (anti-ganda).
  bool playBuried({
    required String id,
    required String name,
    required bool isMe,
    required double camCx,
    required double camScale,
  }) {
    if (!_buriedSeen.add(id)) return false;
    final now = sceneNowMs();
    _buried = _Buried(id, name, isMe, now, camCx, camScale);
    _buriedStart[id] = now;
    return true;
  }

  void playCall({
    required String actorName,
    required String targetName,
    required bool iAmActor,
    required bool iAmTarget,
  }) {
    _call = _Call(sceneNowMs(), actorName, targetName, iAmActor, iAmTarget);
  }

  void endCall() => _call = null;

  void playPolice({
    required String targetId,
    required String targetName,
    required bool reflected,
    required String actorName,
    required int amount,
    required bool iAmTarget,
    required double camCx,
    required double camScale,
  }) {
    final now = sceneNowMs();
    _call = null;
    _police = _Police(targetId, targetName, now, reflected, actorName, amount,
        iAmTarget, camCx, camScale);
    _policeStart[targetId] = now;
  }

  // ------------------------------------------------------------ per frame

  /// Dipanggil tiap frame. True bila ada adegan yang baru selesai
  /// (supaya layar dibangun ulang).
  bool tick(int now) {
    var changed = false;

    final i = _intro;
    if (i != null) {
      final t = now - i.start;
      if (!i.haptic && t >= kIntroTitleMs) {
        i.haptic = true;
        HapticFeedback.mediumImpact();
      }
      if (t >= kIntroMs) {
        _intro = null;
        changed = true;
      }
    }

    final b = _buried;
    if (b != null) {
      final t = now - b.start;
      if (!b.haptic && t >= kBuriedCollapseMs) {
        b.haptic = true;
        if (b.isMe) HapticFeedback.heavyImpact();
      }
      if (t >= kBuriedMs) {
        _buried = null;
        changed = true;
      }
    }

    final c = _call;
    if (c != null && now - c.start >= kCallMs) _call = null;

    final p = _police;
    if (p != null && now - p.start >= kPoliceTotalMs) {
      _police = null;
      changed = true;
    }

    _policeStart.removeWhere((_, s) => now - s >= kPoliceTotalMs);
    _buriedStart.removeWhere((_, s) => now - s >= kBuriedMs);
    return changed;
  }

  /// Opasitas HUD / bilah aksi (0 saat intro, redup saat rumah tertimbun).
  double hudOpacity() {
    final now = sceneNowMs();
    var o = 1.0;
    final i = _intro;
    if (i != null) {
      final t = (now - i.start).toDouble();
      o = math.min(o, _c01((t - (kIntroMs - 1100)) / 900));
    }
    final b = _buried;
    if (b != null) {
      final t = (now - b.start).toDouble();
      final env = _c01(math.min(t / 500, (kBuriedMs - t) / 700));
      o = math.min(o, 1 - 0.75 * env);
    }
    return o;
  }

  // --------------------------------------------------------------- kamera

  /// Posisi kamera sinematik (null = biarkan game yang mengatur).
  /// [tgtCx]/[tgtScale] adalah kamera normal; sinematik selalu mendarat
  /// mulus ke sana di akhir.
  ({double cx, double scale})? camera({
    required int now,
    required List<String> order,
    required double fitOne,
    required double fitAll,
    required double tgtCx,
    required double tgtScale,
  }) {
    final n = order.length;
    if (n == 0) return null;

    // ---- intro: pan menyusuri jalan -> melebar -> mendarat di rumahku
    final intro = _intro;
    if (intro != null) {
      final t = (now - intro.start).toDouble();
      final sPan = fitOne * 0.82;
      final sWide = math.min(fitAll, fitOne * 0.85);
      final panEndCx = n == 1 ? 250.0 : (n - 1) * 400.0 + 200.0;
      final panStartCx = n == 1 ? 150.0 : 200.0;
      final panEndS = sPan * 1.05;

      // pendaratan memakai smootherstep & selesai sedikit sebelum intro habis
      const landDur = kIntroMs - kIntroWideEndMs - 450;
      final land = _ease5((t - kIntroWideEndMs) / landDur);

      // getar napas kamera (handheld halus) yang hilang saat mendarat
      final calm = 1 - land;
      final dx = math.sin(t / 1900) * 7 * calm;
      final ds = 1 + math.sin(t / 1400) * 0.004 * calm;

      if (t < kIntroPanMs) {
        final u = _ease(t / kIntroPanMs);
        return (
        cx: _lerp(panStartCx, panEndCx, u) + dx,
        scale: sPan * (0.97 + 0.08 * u) * ds,
        );
      }
      if (t < kIntroWideEndMs) {
        final u = _ease5((t - kIntroPanMs) / (kIntroWideEndMs - kIntroPanMs));
        return (
        cx: _lerp(panEndCx, n * 200.0, u) + dx,
        scale: _lerp(panEndS, sWide, u) * ds,
        );
      }
      return (
      cx: _lerp(n * 200.0, tgtCx, land) + dx,
      scale: _lerp(sWide, tgtScale, land) * ds,
      );
    }

    // ---- rumah tertimbun: mendekat pelan ke rumah yang runtuh
    final b = _buried;
    if (b != null) {
      final i = order.indexOf(b.id);
      if (i >= 0) {
        final t = (now - b.start).toDouble();
        final cxH = i * 400.0 + 200.0;
        final sH = fitOne * (1 + 0.14 * _ease(t / 6500));
        var cx = _lerp(b.camCx0, cxH, _ease(t / 900));
        var s = math.exp(_lerp(math.log(b.camS0), math.log(sH), _ease(t / 900)));
        final w = _ease((t - (kBuriedMs - 1000)) / 1000);
        if (w > 0) {
          cx = _lerp(cx, tgtCx, w);
          s = _lerp(s, tgtScale, w);
        }
        return (cx: cx, scale: s);
      }
    }

    // ---- sidak polisi: fokus ke rumah yang disidak
    final p = _police;
    if (p != null) {
      final i = order.indexOf(p.id);
      if (i >= 0) {
        final t = (now - p.start).toDouble();
        final cxH = i * 400.0 + 205.0;
        // dorong masuk pelan, lalu "hantam" kecil tepat saat segel menempel
        final punchT = (t - (kPoliceTapeEndMs + 500)) / 500.0;
        final punch = (punchT > 0 && punchT < 1)
            ? math.sin(punchT * math.pi) * 0.06
            : 0.0;
        final sH = fitOne * (1 + 0.12 * _ease(t / 8000) + punch);
        var cx = _lerp(p.camCx0, cxH, _ease(t / 900));
        var s = math.exp(_lerp(math.log(p.camS0), math.log(sH), _ease(t / 900)));
        final w = _ease((t - (kPoliceTotalMs - 1100)) / 1100);
        if (w > 0) {
          cx = _lerp(cx, tgtCx, w);
          s = _lerp(s, tgtScale, w);
        }
        return (cx: cx, scale: s);
      }
    }
    return null;
  }

  // ------------------------------------------------- data adegan per rumah

  /// Menimpa data satu rumah selama adegan berlangsung (lampu menyala
  /// bertahap saat intro, rumah "dipaksa" runtuh perlahan, umur polisi).
  KostSceneData adjustHouse(String id, KostSceneData d, int index, int n) {
    final now = sceneNowMs();
    var out = d;

    final intro = _intro;
    if (intro != null) {
      final t = (now - intro.start).toDouble();
      out = out.copyWith(
        lights: _c01((t - (700 + index * 750)) / 1400),
        clearDayPhase: true, // intro selalu pagi cerah
      );
    }

    final ps = _policeStart[id];
    if (ps != null) {
      final age = now - ps;
      if (age >= 0 && age < kPoliceTotalMs) {
        out = out.copyWith(policeAgeMs: age);
      }
    }

    final bs = _buriedStart[id];
    if (bs != null) {
      final age = now - bs;
      if (age >= 0 && age < kBuriedMs) {
        double lights;
        if (age < 2200) {
          lights = _lerp(1.0, 0.45, age / 2200);
        } else if (age < kBuriedCollapseMs) {
          // lampu berkedip sekarat
          final f = math.sin(age * 0.05) * math.sin(age * 0.131);
          lights = f > 0.2 ? 0.5 : 0.08;
        } else {
          lights = 0.0;
        }
        out = out.copyWith(
          buriedAgeMs: age,
          eliminated: age >= kBuriedCollapseMs,
          trashRatio: age < kBuriedCollapseMs ? 0.95 : 1.0,
          sealedLeft: 0,
          lights: lights,
        );
      }
    }
    return out;
  }

  /// Langit & cuaca bersama: cerah-bersih saat intro, kelabu saat tertimbun.
  KostSceneData adjustBackdrop(KostSceneData d) {
    final now = sceneNowMs();
    var out = d;
    if (_intro != null) {
      out = out.copyWith(
        pollution: math.min(d.pollution, 6.0),
        smog: false,
        clearWorldEvent: true,
        clearDayPhase: true,
      );
    }
    final b = _buried;
    if (b != null) {
      final t = (now - b.start).toDouble();
      final env = _c01(math.min(t / 1500, (kBuriedMs - t) / 1400));
      out = out.copyWith(pollution: _lerp(d.pollution, math.max(d.pollution, 78.0), env));
    }
    return out;
  }
}

// ====================================================================
//  LAPISAN DI BAWAH HUD: pewarnaan, hujan, kilau sirine, kartu telepon
// ====================================================================

class CinematicWorldLayer extends StatelessWidget {
  const CinematicWorldLayer({
    super.key,
    required this.director,
    required this.repaint,
    required this.stage,
  });

  final CineDirector director;
  final Listenable repaint;
  final Rect stage;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: repaint,
        builder: (context, _) {
          final call = director._call;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GradePainter(director, repaint),
                ),
              ),
              if (call != null) _callCard(call),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------ kartu telepon

  String _typed(String s, double ms, {double cps = 42}) {
    if (ms <= 0) return '';
    final n = (ms / 1000 * cps).floor().clamp(0, s.length).toInt();
    return s.substring(0, n);
  }

  Widget _callCard(_Call c) {
    final t = (sceneNowMs() - c.start).toDouble();
    final slideIn = _easeOutBack(t / 380);
    final slideOut = _c01((t - (kCallMs - 320)) / 320);
    final a = _c01(math.min(t / 220, 1 - slideOut));
    final w = math.min(340.0, stage.width - 24);
    final accent = c.iAmTarget
        ? const Color(0xFFFF5252)
        : (c.iAmActor ? const Color(0xFF69F0AE) : const Color(0xFFFFCA28));

    final String title;
    if (c.iAmTarget) {
      title = '${c.actor.toUpperCase()} MENELEPON POLISI!';
    } else if (c.iAmActor) {
      title = 'KAMU MENELEPON POLISI';
    } else {
      title = '${c.actor.toUpperCase()} MENELEPON POLISI';
    }

    final ringing = t < 1000;
    final secs = math.max(0, ((t - 1000) / 1000).floor());
    final dots = '.' * (1 + (t / 250).floor() % 3);
    final status = ringing ? 'Memanggil 110$dots' : 'Tersambung · 00:0$secs';

    final targetLabel = c.iAmTarget ? 'kostmu' : 'kost ${c.target}';
    final line1 =
        'Halo Pak, $targetLabel buang sampah sembarangan! Tolong disidak!';
    const line2 = 'Siap! Tim Satpol PP meluncur ke lokasi sekarang.';
    final t1 = _typed(line1, t - 1100);
    final t2 = _typed(line2, t - 2300, cps: 50);

    return Positioned(
      left: stage.left + (stage.width - w) / 2,
      top: stage.top + stage.height * 0.14 - (1 - slideIn) * 70,
      width: w,
      child: Opacity(
        opacity: a,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF111B16).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.75), width: 1.6),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.28),
                blurRadius: 22,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _phone(t, accent, ringing),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.local_police_rounded,
                      color: Colors.white.withValues(alpha: 0.55), size: 22),
                ],
              ),
              if (t > 1100) ...[
                _bubble(
                  t1.isEmpty ? '…' : t1,
                  right: true,
                  color: const Color(0xFF2E7D32),
                ),
              ],
              if (t > 2300) ...[
                _bubble(
                  t2.isEmpty ? '…' : t2,
                  right: false,
                  color: const Color(0xFF1565C0),
                  who: 'SATPOL PP',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _phone(double t, Color accent, bool ringing) {
    final shake = ringing ? math.sin(t / 1000 * 2 * math.pi * 7) * 0.22 : 0.0;
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (ringing)
            for (var k = 0; k < 2; k++)
              Builder(builder: (_) {
                final u = ((t / 700) + k * 0.5) % 1.0;
                return Container(
                  width: 38 + u * 24,
                  height: 38 + u * 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withValues(alpha: (1 - u) * 0.65),
                      width: 2,
                    ),
                  ),
                );
              }),
          Transform.rotate(
            angle: shake,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: Icon(
                ringing
                    ? Icons.ring_volume_rounded
                    : Icons.phone_in_talk_rounded,
                color: Colors.black87,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(String text,
      {required bool right, required Color color, String? who}) {
    return Align(
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 262),
        margin: const EdgeInsets.only(top: 7),
        padding: const EdgeInsets.fromLTRB(11, 7, 11, 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.92),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(right ? 14 : 3),
            bottomRight: Radius.circular(right ? 3 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (who != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  who,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ---- pewarnaan intro: fajar -> pagi emas, matahari terbit, sinar, lensa

void _paintIntroGrade(Canvas canvas, Size size, double t) {
  final rect = Offset.zero & size;
  final p = Paint();
  final out = _c01((kIntroMs - t) / 900);
  final u1 = _ease(t / 3200);
  final u2 = _ease((t - 2600) / 3400);
  final u3 = _ease((t - 5600) / 3400);

  // 1) wash warna: biru fajar -> ungu mawar -> emas
  var wash = Color.lerp(const Color(0xFF0A1330), const Color(0xFF47254F), u1)!;
  wash = Color.lerp(wash, const Color(0xFFFFB066), u2)!;
  final washA = _lerp(_lerp(0.62, 0.30, u1), 0.13, u2) * (1 - u3);
  if (washA > 0.001) {
    p.color = wash.withValues(alpha: washA);
    canvas.drawRect(rect, p);
  }

  // 2) matahari terbit di kanan atas: cahaya lembut + sinar + kilau lensa
  final rise = _ease5(t / 7200);
  final sun = Offset(
    size.width * 0.82,
    _lerp(size.height * 0.80, size.height * 0.16, rise),
  );
  final glowA = _c01(t / 1200) * (1 - _ease((t - 8300) / 2800));
  final add = Paint()..blendMode = BlendMode.plus;
  if (glowA > 0.001) {
    final gr = size.longestSide * 0.78;
    add.shader = RadialGradient(
      colors: [
        const Color(0xFFFFD590).withValues(alpha: 0.50 * glowA),
        const Color(0xFFFF8A3C).withValues(alpha: 0.20 * glowA),
        const Color(0xFFFF8A3C).withValues(alpha: 0),
      ],
      stops: const [0.0, 0.34, 1.0],
    ).createShader(Rect.fromCircle(center: sun, radius: gr));
    canvas.drawRect(rect, add);
    add.shader = null;
  }

  // sinar matahari menyapu ke kiri-bawah
  final rayA = _c01((t - 1200) / 1800) * (1 - _ease((t - 8200) / 2800));
  if (rayA > 0.001) {
    final reach = size.longestSide * 1.25;
    for (var i = 0; i < 7; i++) {
      final base = 1.98 + i * 0.15 + math.sin(t / 3200 + i * 1.3) * 0.03;
      final wdt = 0.032 + (i % 3) * 0.015;
      final a0 = base - wdt;
      final a1 = base + wdt;
      final far0 = sun + Offset(math.cos(a0), math.sin(a0)) * reach;
      final far1 = sun + Offset(math.cos(a1), math.sin(a1)) * reach;
      final mid = sun + Offset(math.cos(base), math.sin(base)) * reach;
      final shimmer = 0.6 + 0.4 * math.sin(t / 900 + i * 1.7);
      add.shader = ui.Gradient.linear(
        sun,
        mid,
        [
          const Color(0xFFFFE3A8).withValues(alpha: 0.13 * rayA * shimmer),
          const Color(0xFFFFE3A8).withValues(alpha: 0),
        ],
      );
      final path = Path()
        ..moveTo(sun.dx, sun.dy)
        ..lineTo(far0.dx, far0.dy)
        ..lineTo(far1.dx, far1.dy)
        ..close();
      canvas.drawPath(path, add);
    }
    add.shader = null;

    // garis kilau anamorfik tipis melintang di titik matahari
    final sw = size.width * 0.9;
    add.shader = ui.Gradient.linear(
      Offset(sun.dx - sw / 2, sun.dy),
      Offset(sun.dx + sw / 2, sun.dy),
      [
        const Color(0x00FFE3A8),
        const Color(0xFFFFE3A8).withValues(alpha: 0.45 * rayA),
        const Color(0x00FFE3A8),
      ],
      const [0.0, 0.5, 1.0],
    );
    canvas.drawRect(
      Rect.fromCenter(center: sun, width: sw, height: 2.4),
      add,
    );
    add.shader = null;

    // kilau lensa di sepanjang garis matahari -> tengah layar
    final c = size.center(Offset.zero);
    final k = size.shortestSide / 400;
    const flares = <(double, double, double)>[
      (0.30, 22.0, 0.12),
      (0.55, 12.0, 0.16),
      (0.85, 34.0, 0.08),
      (1.20, 16.0, 0.10),
    ];
    for (final f in flares) {
      final pos = sun + (c - sun) * f.$1;
      final r = f.$2 * k;
      add.shader = RadialGradient(
        colors: [
          const Color(0xFFFFE9B8).withValues(alpha: f.$3 * rayA),
          const Color(0x00FFE9B8),
        ],
      ).createShader(Rect.fromCircle(center: pos, radius: r));
      canvas.drawCircle(pos, r, add);
    }
    add.shader = null;
  }

  // 3) vinyet lembut (menyempit & memudar saat pagi mekar)
  final vig = 0.40 * (1 - 0.55 * u3) * _c01(out + 0.0);
  p.shader = RadialGradient(
    radius: 0.95,
    colors: [
      Colors.black.withValues(alpha: 0),
      Colors.black.withValues(alpha: vig),
    ],
    stops: const [0.5, 1.0],
  ).createShader(rect);
  canvas.drawRect(rect, p);
  p.shader = null;

  // 4) butir film halus
  final rnd = math.Random(t ~/ 70);
  final gp = Paint();
  for (var i = 0; i < 70; i++) {
    final x = rnd.nextDouble() * size.width;
    final y = rnd.nextDouble() * size.height;
    gp.color = (rnd.nextBool() ? Colors.white : Colors.black)
        .withValues(alpha: (0.04 + rnd.nextDouble() * 0.05) * out);
    canvas.drawRect(Rect.fromLTWH(x, y, 1.3, 1.3), gp);
  }
}

class _GradePainter extends CustomPainter {
  _GradePainter(this.d, Listenable repaint) : super(repaint: repaint);

  final CineDirector d;

  @override
  bool shouldRepaint(covariant _GradePainter oldDelegate) => true;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final now = sceneNowMs();
    final rect = Offset.zero & size;
    final p = Paint();

    // ---- intro: fajar biru -> semburat mawar -> pagi emas
    final intro = d._intro;
    if (intro != null) {
      _paintIntroGrade(canvas, size, (now - intro.start).toDouble());
    }

    // ---- rumah tertimbun: biru kelabu, vinyet berat, hujan
    final b = d._buried;
    if (b != null) {
      final t = (now - b.start).toDouble();
      final env = _c01(math.min(t / 1400, (kBuriedMs - t) / 1200));
      p.color = const Color(0xFF0A1722).withValues(alpha: 0.42 * env);
      canvas.drawRect(rect, p);
      p.shader = RadialGradient(
        radius: 0.95,
        colors: [
          Colors.black.withValues(alpha: 0),
          Colors.black.withValues(alpha: 0.72 * env),
        ],
        stops: const [0.4, 1.0],
      ).createShader(rect);
      canvas.drawRect(rect, p);
      p.shader = null;

      final rp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFB3D4FF).withValues(alpha: 0.30 * env);
      const drops = 120;
      final sec = now / 1000.0;
      for (var i = 0; i < drops; i++) {
        final fx = (i * 0.61803398875) % 1.0;
        final speed = 0.9 + (i % 7) * 0.12;
        final fy = ((i * 0.37) + sec * speed) % 1.0;
        final x = fx * (size.width + size.height * 0.3) -
            fy * (size.height + 40) * 0.25 +
            10;
        final y = fy * (size.height + 40) - 20;
        canvas.drawLine(Offset(x, y), Offset(x - 5, y + 20), rp);
      }
    }

    // ---- polisi: kilau sirine merah/biru bergantian di tepi layar
    final pl = d._police;
    if (pl != null) {
      final t = (now - pl.start).toDouble();
      final env = _c01(math.min(t / 500, (kPoliceTotalMs - t) / 900));
      final red = math.sin(now / 1000.0 * 13) > 0;
      final c1 = red ? const Color(0xFFFF1744) : const Color(0xFF2979FF);
      final c2 = red ? const Color(0xFF2979FF) : const Color(0xFFFF1744);
      p.shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          c1.withValues(alpha: 0.30 * env),
          c1.withValues(alpha: 0),
          c2.withValues(alpha: 0),
          c2.withValues(alpha: 0.30 * env),
        ],
        stops: const [0.0, 0.38, 0.62, 1.0],
      ).createShader(rect);
      canvas.drawRect(rect, p);
      p.shader = null;
      p.color = Colors.black.withValues(alpha: 0.16 * env);
      canvas.drawRect(rect, p);
    }
  }
}

// ====================================================================
//  HUD: memudar saat sinematik
// ====================================================================

class CineHudFade extends StatelessWidget {
  const CineHudFade({
    super.key,
    required this.director,
    required this.repaint,
    required this.child,
  });

  final CineDirector director;
  final Listenable repaint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repaint,
      child: child,
      builder: (context, ch) {
        final o = director.hudOpacity();
        return IgnorePointer(
          ignoring: o < 0.05,
          child: Opacity(opacity: o, child: ch),
        );
      },
    );
  }
}

// ====================================================================
//  LAPISAN DI ATAS HUD: letterbox, teks, judul, tombol lewati
// ====================================================================

class CinematicTopLayer extends StatelessWidget {
  const CinematicTopLayer({
    super.key,
    required this.director,
    required this.repaint,
    required this.stage,
    required this.onSkip,
  });

  final CineDirector director;
  final Listenable repaint;
  final Rect stage;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return AnimatedBuilder(
          animation: repaint,
          builder: (context, _) => _compose(context, size),
        );
      },
    );
  }

  Widget _compose(BuildContext context, Size size) {
    final now = sceneNowMs();
    final children = <Widget>[];
    var absorb = false;

    final intro = director._intro;
    if (intro != null) {
      absorb = true;
      children.addAll(_introWidgets(context, size, intro, now));
    }
    final b = director._buried;
    if (b != null) children.addAll(_buriedWidgets(size, b, now));
    final p = director._police;
    if (p != null) children.addAll(_policeWidgets(size, p, now));

    // fade-in dari hitam setelah intro dilewati
    final sf = (now - director._blackFadeStart).toDouble();
    if (sf >= 0 && sf < 700) {
      children.add(Positioned.fill(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 1 - _ease(sf / 700)),
        ),
      ));
    }

    if (children.isEmpty) return const SizedBox.shrink();
    final stack = Stack(clipBehavior: Clip.none, children: children);
    if (!absorb) return IgnorePointer(child: stack);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final i = director._intro;
        if (i != null && now - i.start > 500) onSkip();
      },
      child: stack,
    );
  }

  // ------------------------------------------------------------- umum

  Widget _caption(String text,
      {double size = 16, Color color = Colors.white, double ls = 0.3}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: ls,
        shadows: const [
          Shadow(color: Colors.black, blurRadius: 10),
          Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
    );
  }

  Widget _fade(double a, Widget child, {double dy = 10}) => Opacity(
    opacity: _c01(a),
    child: Transform.translate(
      offset: Offset(0, dy * (1 - _c01(a))),
      child: child,
    ),
  );

  Widget _bars(double h) => Stack(
    children: [
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: h,
        child: const ColoredBox(color: Colors.black),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: h,
        child: const ColoredBox(color: Colors.black),
      ),
    ],
  );

  Widget _captionAt(Size size, double bottom, double a, String text,
      {double fs = 16, Color color = Colors.white, double ls = 0.3}) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: bottom,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _fade(a, _caption(text, size: fs, color: color, ls: ls)),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- INTRO

  static const _introLines = <(double, double, String)>[
    (900.0, 3400.0, 'Di sebuah gang sempit, para juragan kost bertetangga dalam damai…'),
    (3600.0, 6000.0, 'Penghuni datang. Uang mengalir. Tapi sampah… tak pernah berhenti.'),
    (6200.0, 8300.0, 'Hanya satu juragan yang akan tetap berdiri.'),
  ];

  /// Waktu (ms) saat kamera pan tepat di rumah ke-[i] (kebalikan smoothstep).
  double _panTimeFor(int i, int n) {
    if (n <= 1) return kIntroPanMs / 2;
    final f = i / (n - 1);
    final x = 0.5 - math.sin(math.asin(1 - 2 * f) / 3);
    return kIntroPanMs * x;
  }

  List<Widget> _introWidgets(
      BuildContext context, Size size, _Intro intro, int now) {
    final t = (now - intro.start).toDouble();
    final barK = _ease5(math.min(t / 1100, (kIntroMs - t) / 800));
    final barH = size.height * 0.12 * barK;
    final blackA = 1 - _ease((t - 150) / 1500);
    final out = _c01((kIntroMs - t) / 600);
    final w = <Widget>[];

    // debu cahaya, bokeh, burung
    w.add(Positioned.fill(
      child: CustomPaint(painter: _MotePainter(t, out)),
    ));

    // narasi (spasi huruf merapat perlahan = terasa "mengendap")
    for (final l in _introLines) {
      final a = _win(t, l.$1, l.$2, 450);
      if (a <= 0) continue;
      final ls = _lerp(1.8, 0.4, _ease5((t - l.$1) / 1500));
      w.add(_captionAt(size, barH + 22, a, l.$3, fs: 16.5, ls: ls));
    }

    // papan nama tiap rumah saat kamera melintas
    final n = intro.order.length;
    for (var i = 0; i < n; i++) {
      final ti = _panTimeFor(i, n);
      final a = _win(t, ti - 1000, ti + 1000, 450);
      if (a <= 0 || t > kIntroPanMs + 400) continue;
      final id = intro.order[i];
      final name = (intro.names[id] ?? 'Pemain').toUpperCase();
      final me = id == intro.myId;
      w.add(Positioned(
        left: 18,
        top: barH + 16,
        child: _namePlate(i, me, name, a),
      ));
    }

    // judul gim
    final tt = t - kIntroTitleMs;
    if (tt > 0) {
      w.add(Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.8,
                colors: [
                  Colors.black.withValues(alpha: 0.58 * _c01(tt / 800) * out),
                  Colors.black.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ));
      w.add(Positioned.fill(
        child: Center(child: _titleBlock(tt, out, size.width)),
      ));
      // kilat cahaya singkat saat judul menghantam
      final fl = 0.38 * (1 - _c01(tt / 380));
      if (fl > 0) {
        w.add(Positioned.fill(
          child: ColoredBox(color: Colors.white.withValues(alpha: fl)),
        ));
      }
    }

    // letterbox
    w.add(_bars(barH));

    // fade dari hitam
    if (blackA > 0) {
      w.add(Positioned.fill(
        child: ColoredBox(color: Colors.black.withValues(alpha: blackA)),
      ));
    }

    // tombol lewati
    if (t > 1200 && t < kIntroMs - 900) {
      w.add(Positioned(
        right: 16,
        top: MediaQuery.of(context).padding.top + 10,
        child: Opacity(
          opacity: 0.8 * _c01((t - 1200) / 600),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'KETUK UNTUK MELEWATI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.skip_next_rounded, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ));
    }
    return w;
  }

  /// Papan nama rumah: lencana nomor + nama, geser masuk dari kiri.
  Widget _namePlate(int i, bool me, String name, double a) {
    final accent = me ? const Color(0xFFFFCA28) : const Color(0xFF81C784);
    final e = _easeOutCubic(a);
    return Opacity(
      opacity: _c01(a * 1.4),
      child: Transform.translate(
        offset: Offset((1 - e) * -28, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 22, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.62),
                Colors.black.withValues(alpha: 0),
              ],
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.16),
                  border: Border.all(color: accent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    me ? 'JURAGAN KOST  ·  KAMU' : 'JURAGAN KOST',
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: _lerp(0, 120, e),
                    height: 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const String _titleWord = 'SAMPAHNYA!';

  /// Satu baris huruf judul; tiap huruf naik & muncul bergantian.
  /// [stroke] true = lapis garis tepi, false = lapis isi (dimasker emas).
  Widget _titleRow(double tt, double fs, bool stroke) {
    final gap = _lerp(fs * 0.20, fs * 0.03, _ease5(tt / 1500));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var k = 0; k < _titleWord.length; k++)
          Builder(builder: (_) {
            final u = _c01((tt - 250 - k * 85) / 520);
            final e = _easeOutBack(u);
            final style = stroke
                ? TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = fs * 0.12
                ..strokeJoin = StrokeJoin.round
                ..color = const Color(0xFF0B1A10),
            )
                : TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            );
            return Opacity(
              opacity: _c01(u * 1.8),
              child: Transform.translate(
                offset: Offset(0, (1 - e) * fs * 0.45),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: gap / 2),
                  child: Text(_titleWord[k], style: style),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _titleBlock(double tt, double out, double maxW) {
    final fs = (maxW * 0.15).clamp(36.0, 86.0).toDouble();
    final a = _c01(tt / 300) * out;
    final sx = _lerp(-0.35, 1.35, _ease5((tt - 1500) / 1700));
    final s1 = (sx - 0.16).clamp(0.0, 1.0).toDouble();
    final s2 = sx.clamp(0.0, 1.0).toDouble();
    final s3 = (sx + 0.16).clamp(0.0, 1.0).toDouble();
    final emblem = _easeOutBack(tt / 700);
    final breathe = 1 + 0.015 * math.sin(tt / 520) * _c01((tt - 1500) / 600);

    final fill = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => LinearGradient(
        colors: const [
          Color(0xFFFFD54F),
          Color(0xFFFFCA28),
          Colors.white,
          Color(0xFFFFCA28),
          Color(0xFFFFA000),
        ],
        stops: [0.0, s1, s2, s3, 1.0],
      ).createShader(r),
      child: _titleRow(tt, fs, false),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Opacity(
        opacity: a,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _EmblemFxPainter(tt, out)),
                  ),
                  Transform.scale(
                    scale: emblem,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                            const Color(0xFFFFCA28).withValues(alpha: 0.6),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.delete_sweep_rounded,
                        size: 38,
                        color: Color(0xFF14201A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Transform.scale(
              scale: breathe,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Stack(
                  alignment: Alignment.center,
                  children: [_titleRow(tt, fs, true), fill],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: _lerp(0, 240, _ease5((tt - 900) / 900)),
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(
                  colors: [
                    Color(0x00FFCA28),
                    Color(0xFFFFCA28),
                    Color(0x00FFCA28),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFCA28).withValues(alpha: 0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: _c01((tt - 1700) / 600),
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - _easeOutCubic((tt - 1700) / 700))),
                child: _caption(
                  'Kelola limbah. Sabotase tetangga.\nJangan sampai tertimbun!',
                  size: 15,
                  color: const Color(0xFFE8F5E9),
                  ls: _lerp(2.0, 0.4, _ease5((tt - 1700) / 1300)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------- RUMAH TERTIMBUN

  List<Widget> _buriedWidgets(Size size, _Buried b, int now) {
    final t = (now - b.start).toDouble();
    final barK = _ease(math.min(t / 800, (kBuriedMs - t) / 800));
    final barH = size.height * 0.07 * barK;
    final name = b.name;
    final me = b.isMe;
    final w = <Widget>[_bars(barH)];

    w.add(_captionAt(
      size,
      barH + 14,
      _win(t, 700, 3400),
      me
          ? 'Sampah terus berdatangan… tak ada lagi tempat untuk menaruhnya.'
          : 'Sampah terus menumpuk di kost $name… tak ada lagi tempat.',
      fs: 15.5,
      color: const Color(0xFFCFD8DC),
    ));
    w.add(_captionAt(
      size,
      barH + 14,
      _win(t, 5200, 8100),
      me
          ? 'Kost-mu… tak sanggup lagi menahannya.'
          : 'Kost $name tak sanggup lagi menahannya.',
      fs: 16.5,
      color: const Color(0xFFECEFF1),
    ));

    final la = _win(t, 5900, 8700, 450);
    if (la > 0) {
      w.add(Positioned(
        left: 20,
        right: 20,
        bottom: barH + 66,
        child: Center(
          child: _fade(
            la,
            Container(
              padding: const EdgeInsets.fromLTRB(16, 9, 16, 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFEF5350).withValues(alpha: 0.7),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '😢  ${(me ? 'KOST-MU' : name).toUpperCase()} TERELIMINASI',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFF8A80),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Semua kerja kerasnya… tertimbun begitu saja.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
    }
    return w;
  }

  // ------------------------------------------------------------- POLISI

  List<Widget> _policeWidgets(Size size, _Police p, int now) {
    final t = (now - p.start).toDouble();
    final barK = _ease(math.min(t / 700, (kPoliceTotalMs - t) / 700));
    final w = <Widget>[_bars(size.height * 0.045 * barK)];

    final String l1;
    if (p.reflected) {
      l1 = 'Sidak dipantulkan ${p.actorName}! Petugas justru mendatangi kost ${p.name}…';
    } else if (p.iAmTarget) {
      l1 = 'Petugas Satpol PP mendatangi kostmu…';
    } else {
      l1 = 'Petugas Satpol PP tiba di kost ${p.name}…';
    }
    const tapeA = kPoliceTapeStartMs - 200.0;
    const tapeEnd = kPoliceTapeEndMs + 0.0;
    final lines = <(double, double, String)>[
      (300.0, kPoliceDriveMs + 1500.0, l1),
      (tapeA, tapeEnd - 300, 'Garis polisi dipasang. Kost diperiksa…'),
      (tapeEnd + 350, tapeEnd + 2000, 'Segel dipasang di pintu. Kost disegel!'),
      if (p.amount > 0)
        (tapeEnd + 2100, tapeEnd + 3600, 'Denda ${p.amount} koin dijatuhkan.'),
    ];
    for (final l in lines) {
      final a = _win(t, l.$1, l.$2);
      if (a <= 0) continue;
      w.add(Positioned(
        left: 24,
        right: 24,
        top: stage.top + stage.height * 0.14,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: _fade(
              a,
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFFD600).withValues(alpha: 0.55),
                  ),
                ),
                child: _caption(l.$3, size: 14, color: Colors.white),
              ),
              dy: -10,
            ),
          ),
        ),
      ));
    }
    return w;
  }
}

/// Debu cahaya + bokeh hangat + kawanan burung melintas (khusus intro).
class _MotePainter extends CustomPainter {
  _MotePainter(this.t, this.out);

  final double t;
  final double out;

  @override
  bool shouldRepaint(covariant _MotePainter oldDelegate) => true;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final k = size.shortestSide / 400;

    // ---- bokeh hangat melayang pelan (muncul seiring matahari naik)
    final bokehEnv = _c01((t - 2200) / 2200) * out;
    if (bokehEnv > 0.001) {
      final bp = Paint()..blendMode = BlendMode.plus;
      for (var i = 0; i < 9; i++) {
        final fx = (i * 0.618034) % 1.0;
        final fy = (i * 0.414214 + 0.1) % 1.0;
        final r = (14 + (i % 4) * 9) * k;
        final x = ((fx * size.width + t / 1000 * (5 + i % 3 * 3)) %
            (size.width + 2 * r)) -
            r;
        final y = fy * size.height + math.sin(t / 1800 + i * 1.9) * 10;
        final tw = 0.55 + 0.45 * math.sin(t / 1100 + i * 2.3);
        final c = Offset(x, y);
        bp.shader = RadialGradient(
          colors: [
            const Color(0xFFFFD9A0).withValues(alpha: 0.11 * tw * bokehEnv),
            const Color(0xFFFFD9A0).withValues(alpha: 0.05 * tw * bokehEnv),
            const Color(0x00FFD9A0),
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r));
        canvas.drawCircle(c, r, bp);
      }
    }

    // ---- debu cahaya
    final p = Paint()..style = PaintingStyle.fill;
    final env = _c01(t / 1500) * out;
    for (var i = 0; i < 42; i++) {
      final fx = (i * 0.754877666) % 1.0;
      final fy = (i * 0.569840296) % 1.0;
      final sp = 6 + (i % 5) * 3.0;
      final x = ((fx * size.width + t / 1000 * sp * 2) % (size.width + 20)) - 10;
      final y = ((fy * size.height - t / 1000 * sp) % size.height + size.height) %
          size.height;
      final r = 0.8 + (i % 4) * 0.45;
      final tw = 0.5 + 0.5 * math.sin(t / 700 + i);
      p.color = const Color(0xFFFFE9B0).withValues(alpha: 0.35 * tw * env);
      canvas.drawCircle(Offset(x, y), r, p);
    }

    // ---- burung melintas di langit pagi
    final bird = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < 6; i++) {
      final v = (t - 1000 - i * 330) / 5600;
      if (v <= 0 || v >= 1) continue;
      final x = _lerp(-0.08, 1.08, v) * size.width;
      final y = size.height * (0.13 + (i % 3) * 0.055) +
          math.sin(v * 6 + i) * 8 * k +
          i * 3.0;
      final s = (5 + (i % 3) * 1.6) * k;
      final flap = 0.5 + 0.5 * math.sin(t / 1000 * 2 * math.pi * (2.0 + i * 0.15) + i);
      final a = 0.55 * _c01(math.min(v / 0.1, (1 - v) / 0.1)) * out;
      bird
        ..strokeWidth = 1.5 * k + 0.3
        ..color = const Color(0xFF1B2433).withValues(alpha: a);
      final lift = s * (0.15 + 0.85 * flap);
      final path = Path()
        ..moveTo(x - s * 1.5, y - lift * 0.9)
        ..quadraticBezierTo(x - s * 0.7, y - lift * 1.4, x, y)
        ..quadraticBezierTo(x + s * 0.7, y - lift * 1.4, x + s * 1.5, y - lift * 0.9);
      canvas.drawPath(path, bird);
    }
  }
}

/// Efek di belakang lambang judul: sinar berputar, cincin kejut, kilau.
class _EmblemFxPainter extends CustomPainter {
  _EmblemFxPainter(this.tt, this.out);

  final double tt;
  final double out;

  @override
  bool shouldRepaint(covariant _EmblemFxPainter oldDelegate) => true;

  void _star(Canvas c, Offset o, double r, Paint p) {
    final path = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
      ..close();
    c.drawPath(path, p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const gold = Color(0xFFFFCA28);

    // sinar berputar
    final env = _c01((tt - 100) / 700) * out;
    if (env > 0.001) {
      const reach = 150.0;
      final rp = Paint()..blendMode = BlendMode.plus;
      rp.shader = ui.Gradient.radial(
        c,
        reach,
        [
          gold.withValues(alpha: 0.30 * env),
          gold.withValues(alpha: 0),
        ],
      );
      final spin = tt / 1000 * 0.28;
      for (var i = 0; i < 12; i++) {
        final a = spin + i * 2 * math.pi / 12;
        const w = 0.085;
        final path = Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + math.cos(a - w) * reach, c.dy + math.sin(a - w) * reach)
          ..lineTo(c.dx + math.cos(a + w) * reach, c.dy + math.sin(a + w) * reach)
          ..close();
        canvas.drawPath(path, rp);
      }
    }

    // cincin kejut
    final u = _c01(tt / 1000);
    if (u > 0 && u < 1) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1 - u) + 0.5
        ..color = gold.withValues(alpha: (1 - u) * 0.7 * out);
      canvas.drawCircle(c, 30 + _easeOutCubic(u) * 150, ring);
    }

    // kilau meletup keluar lalu berkelap-kelip
    final sp = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < 14; i++) {
      final life = _c01((tt - 80 - i * 40) / 1900);
      if (life <= 0 || life >= 1) continue;
      final ang = i * 2.399963 + 0.4;
      final dist = (26 + (60 + (i % 4) * 22) * _easeOutCubic(life * 1.4));
      final o = c + Offset(math.cos(ang), math.sin(ang)) * dist;
      final tw = 0.5 + 0.5 * math.sin(tt / 110 + i * 1.7);
      final fade = math.min(life / 0.15, (1 - life) / 0.5).clamp(0.0, 1.0);
      sp.color = const Color(0xFFFFF3C4)
          .withValues(alpha: 0.9 * tw * fade * out);
      _star(canvas, o, 3.5 + (i % 3) * 1.8, sp);
    }
  }
}