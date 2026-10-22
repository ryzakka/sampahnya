import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kost_scene.dart';

// ====================================================================
//  SINEMATIK GIM (v1)
//
//  1) Intro pembuka   : pan kamera menyusuri jalan kost -> judul gim
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
const int kIntroMs = 11800;
const int kBuriedMs = 9200;
const int kCallMs = 3000;

double _c01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _lerp(double a, double b, double t) => a + (b - a) * t;
double _ease(double x) {
  x = _c01(x);
  return x * x * (3 - 2 * x);
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
      if (!i.haptic && t >= 7900) {
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
      if (t < 5600) {
        final u = _ease(t / 5600);
        return (
        cx: _lerp(panStartCx, panEndCx, u),
        scale: sPan * (1 + 0.05 * u),
        );
      }
      if (t < 7800) {
        final u = _ease((t - 5600) / 2200);
        return (
        cx: _lerp(panEndCx, n * 200.0, u),
        scale: _lerp(panEndS, sWide, u),
        );
      }
      final u = _ease((t - 7800) / 3300);
      return (
      cx: _lerp(n * 200.0, tgtCx, u),
      scale: _lerp(sWide, tgtScale, u),
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
        final sH = fitOne * (1 + 0.08 * _ease(t / 6500));
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
      out = out.copyWith(lights: _c01((t - (700 + index * 750)) / 1400));
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

    // ---- intro: fajar biru -> pagi hangat
    final intro = d._intro;
    if (intro != null) {
      final t = (now - intro.start).toDouble();
      final k = 1 - _ease(t / 6500);
      if (k > 0) {
        p.color = const Color(0xFF0B1636).withValues(alpha: 0.62 * k);
        canvas.drawRect(rect, p);
        p.shader = RadialGradient(
          center: const Alignment(0.7, 0.9),
          radius: 1.1,
          colors: [
            const Color(0xFFFF9A3C).withValues(alpha: 0.38 * k),
            const Color(0xFFFF9A3C).withValues(alpha: 0),
          ],
        ).createShader(rect);
        canvas.drawRect(rect, p);
        p.shader = null;
      }
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

  Widget _caption(String text, {double size = 16, Color color = Colors.white}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: 0.3,
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
      {double fs = 16, Color color = Colors.white}) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: bottom,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _fade(a, _caption(text, size: fs, color: color)),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- INTRO

  static const _introLines = <(double, double, String)>[
    (800.0, 3200.0, 'Di sebuah gang sempit, para juragan kost bertetangga dalam damai…'),
    (3300.0, 5600.0, 'Penghuni datang. Uang mengalir. Tapi sampah… tak pernah berhenti.'),
    (5700.0, 7700.0, 'Hanya satu juragan yang akan tetap berdiri.'),
  ];

  /// Waktu (ms) saat kamera pan tepat di rumah ke-[i] (kebalikan smoothstep).
  double _panTimeFor(int i, int n) {
    if (n <= 1) return 2800;
    final f = i / (n - 1);
    final x = 0.5 - math.sin(math.asin(1 - 2 * f) / 3);
    return 5600 * x;
  }

  List<Widget> _introWidgets(
      BuildContext context, Size size, _Intro intro, int now) {
    final t = (now - intro.start).toDouble();
    final barK = _ease(math.min(t / 900, (kIntroMs - t) / 700));
    final barH = size.height * 0.115 * barK;
    final blackA = 1 - _c01((t - 100) / 1000);
    final out = _c01((kIntroMs - t) / 600);
    final w = <Widget>[];

    // debu cahaya melayang di udara
    w.add(Positioned.fill(
      child: CustomPaint(painter: _MotePainter(t, out)),
    ));

    // narasi
    for (final l in _introLines) {
      final a = _win(t, l.$1, l.$2);
      if (a <= 0) continue;
      w.add(_captionAt(size, barH + 22, a, l.$3, fs: 16.5));
    }

    // papan nama tiap rumah saat kamera melintas
    final n = intro.order.length;
    for (var i = 0; i < n; i++) {
      final ti = _panTimeFor(i, n);
      final a = _win(t, ti - 950, ti + 950);
      if (a <= 0 || t > 6000) continue;
      final id = intro.order[i];
      final name = (intro.names[id] ?? 'Pemain').toUpperCase();
      final me = id == intro.myId;
      w.add(Positioned(
        left: 22,
        top: barH + 16,
        child: _fade(
          a,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCA28),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'JURAGAN KOST #${i + 1}${me ? '  ·  KAMU' : ''}',
                    style: TextStyle(
                      color: me
                          ? const Color(0xFFFFCA28)
                          : const Color(0xFF81C784),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                      shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                    ),
                  ),
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
                ],
              ),
            ],
          ),
          dy: 0,
        ),
      ));
    }

    // judul gim
    final tt = t - 7900;
    if (tt > 0) {
      w.add(Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.75,
                colors: [
                  Colors.black.withValues(alpha: 0.55 * _c01(tt / 700) * out),
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
    if (t > 900 && t < kIntroMs - 900) {
      w.add(Positioned(
        right: 16,
        top: MediaQuery.of(context).padding.top + 10,
        child: Opacity(
          opacity: 0.8 * _c01((t - 900) / 500),
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

  Widget _titleBlock(double tt, double out, double maxW) {
    final fs = (maxW * 0.15).clamp(36.0, 86.0).toDouble();
    final ls = _lerp(26, 4, _ease(tt / 1300));
    final scale = _lerp(1.4, 1.0, _ease(tt / 1000));
    final a = _c01(tt / 420) * out;
    final sx = _lerp(-0.3, 1.3, _c01((tt - 700) / 1500));
    final s1 = (sx - 0.18).clamp(0.0, 1.0).toDouble();
    final s2 = sx.clamp(0.0, 1.0).toDouble();
    final s3 = (sx + 0.18).clamp(0.0, 1.0).toDouble();
    final emblem = _easeOutBack(tt / 650);

    final stroke = Text(
      'SAMPAHNYA!',
      style: TextStyle(
        fontSize: fs,
        fontWeight: FontWeight.w900,
        letterSpacing: ls,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = fs * 0.12
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF0B1A10),
      ),
    );
    final fill = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => LinearGradient(
        colors: const [
          Color(0xFFFFCA28),
          Color(0xFFFFCA28),
          Colors.white,
          Color(0xFFFFCA28),
          Color(0xFFFFA000),
        ],
        stops: [0.0, s1, s2, s3, 1.0],
      ).createShader(r),
      child: Text(
        'SAMPAHNYA!',
        style: TextStyle(
          fontSize: fs,
          fontWeight: FontWeight.w900,
          letterSpacing: ls,
          color: Colors.white,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Opacity(
        opacity: a,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: emblem,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCA28),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFCA28).withValues(alpha: 0.55),
                      blurRadius: 26,
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
            const SizedBox(height: 14),
            Transform.scale(
              scale: scale,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Stack(
                  alignment: Alignment.center,
                  children: [stroke, fill],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: _lerp(0, 230, _ease((tt - 500) / 700)),
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFFFFCA28),
                borderRadius: BorderRadius.circular(2),
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
              opacity: _c01((tt - 1000) / 500),
              child: _caption(
                'Kelola limbah. Sabotase tetangga.\nJangan sampai tertimbun!',
                size: 15,
                color: const Color(0xFFE8F5E9),
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
    final w = <Widget>[];

    final String l1;
    if (p.reflected) {
      l1 = 'Sidak dipantulkan ${p.actorName}! Petugas justru mendatangi kost ${p.name}…';
    } else if (p.iAmTarget) {
      l1 = 'Petugas Satpol PP mendatangi kostmu…';
    } else {
      l1 = 'Petugas Satpol PP tiba di kost ${p.name}…';
    }
    final lines = <(double, double, String)>[
      (300.0, 3000.0, l1),
      (3500.0, 6800.0, 'Garis polisi dipasang. Kost disegel!'),
      if (p.amount > 0) (6900.0, 8300.0, 'Denda ${p.amount} koin dijatuhkan.'),
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

class _MotePainter extends CustomPainter {
  _MotePainter(this.t, this.out);

  final double t;
  final double out;

  @override
  bool shouldRepaint(covariant _MotePainter oldDelegate) => true;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
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
  }
}