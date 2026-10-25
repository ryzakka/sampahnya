import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bgm.dart';
import 'customize_screen.dart';
import 'game_screen.dart';
import 'kost_scene.dart';
import 'kost_style.dart';
import 'survival_leaderboard.dart';

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://tbkoiuydiqvfedjiqlih.supabase.co',
);
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRia29pdXlkaXF2ZmVkamlxbGloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2NTQ1MTgsImV4cCI6MjEwODIzMDUxOH0.JC_xoqEn2YMQnayqbxMtSMPjzdtxsJ7dc0nMj4SwVJQ',
);

/// Gim lain buatan Anda, ditampilkan di beranda.
const linguistifyUrl = 'https://linguistify.vercel.app/';

/// Nomor versi yang tampil di layar pembuka dan beranda.
const appVersion = '1.5.0 (2510:5)';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Bgm.instance.init();

  if (supabaseAnonKey.isEmpty) {
    runApp(const MissingKeyApp());
    return;
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const SampahnyaApp());
}

// ====================================================================
//  TOKEN DESAIN
// ====================================================================

/// Palet dan ukuran dipusatkan di sini supaya seluruh layar konsisten.
class _Ui {
  // Warna
  static const bg = Color(0xFF0A140F);
  static const surface = Color(0xFF12221A);
  static const green = Color(0xFF2E7D32);
  static const greenBright = Color(0xFF43A047);
  static const greenSoft = Color(0xFF81C784);
  static const amber = Color(0xFFFFCA28);
  static const danger = Color(0xFFEF5350);
  static const violet = Color(0xFF9FA8FF); // aksen khusus tautan gim lain

  // Titik patah layout
  static const wideBreakpoint = 860.0;

  // Batas lebar konten agar desain tidak melebar di layar besar.
  static const maxNarrow = 480.0; // satu kolom (ponsel / portrait)
  static const maxHome = 980.0; // beranda dua kolom
  static const maxLobby = 1000.0; // lobi dua kolom
  static const sidePanel = 340.0;

  /// Skala nilai mengikuti lebar layar, dibatasi [min]..[max].
  static double fluid(double width, double min, double max,
      {double from = 320, double to = 1100}) {
    final t = ((width - from) / (to - from)).clamp(0.0, 1.0);
    return min + (max - min) * t;
  }

  // Jarak
  static const gap16 = SizedBox(height: 16);
  static const gap24 = SizedBox(height: 24);
  static const gap8 = SizedBox(height: 8);
  static const gap12 = SizedBox(height: 12);

  // Radius
  static const radiusButton = 16.0;
  static const radiusField = 14.0;

  // Skala teks
  static const title = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w900,
    letterSpacing: 2,
    height: 1.05,
    shadows: [Shadow(color: Colors.black87, blurRadius: 16, offset: Offset(0, 5))],
  );
  /// Judul layar pembuka (font Lilita One, tebal dan ceria).
  static TextStyle get splashTitle => GoogleFonts.lilitaOne(
    color: Colors.white,
    letterSpacing: 2.5,
    height: 1.05,
    shadows: const [
      Shadow(color: Colors.black87, blurRadius: 16, offset: Offset(0, 5)),
    ],
  );
  static const heading = TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.w900,
  );
  static const label = TextStyle(
    color: greenSoft,
    fontSize: 12.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
  );
  static TextStyle body([double alpha = 0.78]) => TextStyle(
    color: Colors.white.withValues(alpha: alpha),
    fontSize: 13.5,
    height: 1.4,
  );

  static Future<void> openLink(BuildContext context, String url) async {
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Tidak bisa membuka $url'),
          ),
        );
    }
  }
}


// ====================================================================
//  KOMPONEN UMUM
// ====================================================================

/// Panel kaca: dipakai untuk kartu utama.
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  final Widget child;
  final EdgeInsets padding;
  static const double radius = 24;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _Ui.surface.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.40),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Kartu datar untuk mengelompokkan isi di dalam layar (pemain, tampilan).
class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

/// Label status kecil berwarna.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Garis pemisah dengan teks di tengah.
class _OrDivider extends StatelessWidget {
  const _OrDivider(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.white.withValues(alpha: 0.10),
      ),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// Tombol aksi: utama (terisi) atau sekunder ([outlined]) dengan status sibuk.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.background = _Ui.amber,
    this.foreground = Colors.black87,
    this.busy = false,
    this.outlined = false,
    this.height = 54,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final bool busy;
  final bool outlined;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bg = outlined ? Colors.white.withValues(alpha: 0.07) : background;
    final fg = outlined ? Colors.white : foreground;
    return SizedBox(
      height: height,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
          disabledForegroundColor: Colors.white38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          side: outlined
              ? BorderSide(color: Colors.white.withValues(alpha: 0.16))
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_Ui.radiusButton),
          ),
          textStyle: TextStyle(
            fontSize: outlined ? 14 : 15.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        onPressed: onPressed,
        icon: busy
            ? SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
        )
            : Icon(icon, size: 20),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Ui.danger.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF8A80), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFFCDD2),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tautan ke gim lain (Linguistify), tanpa wadah.
class _MoreGamesCard extends StatelessWidget {
  const _MoreGamesCard({this.center = false});
  final bool center;

  @override
  Widget build(BuildContext context) {
    final align = center ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    return Semantics(
      button: true,
      label: 'Buka gim Linguistic Hegemony di browser',
      child: InkWell(
        onTap: () => _Ui.openLink(context, linguistifyUrl),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
            center ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              const Icon(Icons.translate_rounded, color: _Ui.violet, size: 22),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: align,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Gim lain dari kami',
                      style: TextStyle(
                        color: _Ui.violet,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Linguistic Hegemony',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new_rounded,
                  size: 16, color: _Ui.violet),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
//  APLIKASI
// ====================================================================

class MissingKeyApp extends StatelessWidget {
  const MissingKeyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'SUPABASE_ANON_KEY belum disetel.\n'
                  'Jalankan Flutter dengan --dart-define=SUPABASE_ANON_KEY=…',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class SampahnyaApp extends StatelessWidget {
  const SampahnyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sampahnya',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _Ui.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: _Ui.bg,
        fontFamily: 'sans-serif',
      ),
      // Batasi skala teks sistem agar tata letak tidak pecah/melebar.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.2,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
    );
  }
}

// ====================================================================
//  LAYAR PEMBUKA
// ====================================================================

/// Layar pertama: jalan kost beranimasi (kamera menyusuri jalan, langit
/// berubah dari siang ke senja, penghuni beraktivitas, sampah beterbangan)
/// dengan judul dan tombol MULAI. Menekan MULAI membuka [LobbyHome].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const int _houseCount = 7;
  static const List<int> _rooms = [8, 4, 12, 8, 12, 4, 8];
  static const List<int> _tiers = [0, 1, 0, 2, 0, 1, 0];

  late final AnimationController _anim; // pemicu gambar ulang (1 dtk, berulang)
  late final AnimationController _enter; // animasi masuk judul & tombol
  late final AnimationController _pulse; // denyut tombol MULAI
  final KostStreetCamera _cam = KostStreetCamera();
  final List<KostOwner> _owners = [];
  final FocusNode _focus = FocusNode();
  late final int _t0;
  double _scale = 0.6;
  bool _leaving = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    Bgm.instance.startLobby(); // di web bisa diblokir; dicoba lagi di _start()
    _t0 = sceneNowMs();
    for (var i = 0; i < _houseCount; i++) {
      final id = 'splash$i';
      _owners.add(KostOwner(seed: kostSeedFor(id))
        ..look = kostLookFor(id, null));
    }
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    _anim.addListener(() {
      _cam.setTarget(_panX(_seconds), _scale);
      _cam.step();
    });
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void dispose() {
    _anim.dispose();
    _enter.dispose();
    _pulse.dispose();
    _focus.dispose();
    super.dispose();
  }

  double get _seconds => (sceneNowMs() - _t0) / 1000.0;

  /// Posisi kamera: bolak-balik menyusuri jalan, melambat di kedua ujung.
  double _panX(double t) {
    final u = _reduceMotion ? 0.3 : (1 - cos(t * 2 * pi / 70)) / 2;
    return kStreetSlotW * (0.5 + u * (_houseCount - 1));
  }

  /// Fase hari: tengah hari (0.5) perlahan menuju senja (0.8).
  double _phase(double t) =>
      _reduceMotion ? 0.5 : 0.5 + 0.30 * (1 - cos(t * 2 * pi / 90)) / 2;

  List<KostSceneData> _houses(double phase) => [
    for (var i = 0; i < _houseCount; i++)
      KostSceneData(
        rooms: _rooms[i],
        maxRooms: 12,
        defense: i % 3 == 0 ? 1 : 0,
        wasteLevel: 1,
        kostTier: _tiers[i],
        trashRatio: 0.06 + 0.04 * (i % 3),
        pollution: 4,
        wall: KostPalette.walls[(i * 5 + 1) % KostPalette.walls.length],
        seed: kostSeedFor('splash$i') % 1000,
        lights: 1.0,
        owner: _owners[i],
        dayPhase: phase,
      ),
  ];

  void _start() {
    if (_leaving) return;
    _leaving = true;
    Bgm.instance.startLobby(); // gestur pengguna: aman untuk autoplay web
    HapticFeedback.selectionClick();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 650),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => const LobbyHome(),
        transitionsBuilder: (_, animation, __, child) {
          final c = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: c,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.04, end: 1.0).animate(c),
              child: child,
            ),
          );
        },
      ),
    );
  }

  /// Muncul bertahap: memudar + naik sedikit, pada rentang [a]..[b] animasi masuk.
  Widget _reveal(double a, double b, Widget child) {
    final curve = CurvedAnimation(
      parent: _enter,
      curve: Interval(a, b, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.28),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Ui.bg,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent &&
              (e.logicalKey == LogicalKeyboardKey.enter ||
                  e.logicalKey == LogicalKeyboardKey.numpadEnter ||
                  e.logicalKey == LogicalKeyboardKey.space)) {
            _start();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final h = c.maxHeight;
            // Rumah memenuhi ±40% tinggi layar di bagian bawah; sisanya
            // (langit) dipakai untuk judul dan tombol.
            final scale = min(
              min(w / (kStreetSlotW * 1.5), h * 0.40 / kStreetSlotH),
              1.5,
            ).clamp(0.3, 1.5).toDouble();
            _scale = scale;
            _cam.setTarget(_panX(_seconds), scale);
            final contentH = max(150.0, h - 250 * scale - 8);
            final titleSize = _Ui.fluid(w, 40, 76, from: 320, to: 1100);
            final short = contentH < 300;
            final btnW = min(300.0, max(200.0, w - 64));

            return Stack(
              children: [
                // 1) Jalan kost hidup.
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) {
                      final phase = _phase(_seconds);
                      return KostStreet(
                        houses: _houses(phase),
                        backdrop: KostSceneData(
                          rooms: 0,
                          maxRooms: 12,
                          defense: 0,
                          trashRatio: 0,
                          pollution: 4,
                          dayPhase: phase,
                        ),
                        camera: _cam,
                        repaint: _anim,
                        ids: [for (var i = 0; i < _houseCount; i++) 'splash$i'],
                      );
                    },
                  ),
                ),
                // 2) Penggelap lembut di langit agar judul terbaca.
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.5, 1.0],
                          colors: [
                            _Ui.bg.withValues(alpha: 0.62),
                            _Ui.bg.withValues(alpha: 0.18),
                            _Ui.bg.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 3) Sampah & daun beterbangan di depan.
                if (!_reduceMotion)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _DriftPainter(_anim, _t0)),
                    ),
                  ),
                // 4) Judul + tombol.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: contentH,
                  child: SafeArea(
                    bottom: false,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _reveal(
                                0.0,
                                0.5,
                                Text(
                                  'SAMPAHNYA!',
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  style: _Ui.splashTitle.copyWith(
                                    fontSize: short ? min(titleSize, 48) : titleSize,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _reveal(
                                0.1,
                                0.6,
                                Text(
                                  'VERSI $appVersion',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.8,
                                    shadows: const [
                                      Shadow(color: Colors.black, blurRadius: 8),
                                    ],
                                  ),
                                ),
                              ),
                              if (!short) ...[
                                const SizedBox(height: 12),
                                _reveal(
                                  0.25,
                                  0.75,
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 380),
                                    child: Text(
                                      'Bangun kamar, kelola limbah, atau timbun kost tetangga!',
                                      textAlign: TextAlign.center,
                                      style: _Ui.body(0.9).copyWith(
                                        fontSize: 15.5,
                                        height: 1.45,
                                        shadows: const [
                                          Shadow(color: Colors.black, blurRadius: 10),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              SizedBox(height: short ? 16 : 30),
                              _reveal(
                                0.45,
                                1.0,
                                Semantics(
                                  button: true,
                                  label: 'Mulai bermain',
                                  child: _StartButton(
                                    width: btnW,
                                    pulse: _pulse,
                                    onPressed: _start,
                                  ),
                                ),
                              ),
                              if (!short) ...[
                                const SizedBox(height: 14),
                                _reveal(
                                  0.6,
                                  1.0,
                                  Text(
                                    'Multipemain 2–4 orang, atau main sendiri',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 12.5,
                                      shadows: const [
                                        Shadow(color: Colors.black, blurRadius: 8),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
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
}

/// Tombol MULAI berbentuk pil dengan cahaya yang berdenyut.
class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.onPressed,
    required this.pulse,
    required this.width,
  });

  final VoidCallback onPressed;
  final Animation<double> pulse;
  final double width;

  @override
  Widget build(BuildContext context) {
    const radius = 32.0;
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final p = Curves.easeInOut.transform(pulse.value);
        return Container(
          width: width,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
            ),
            boxShadow: [
              BoxShadow(
                color: _Ui.amber.withValues(alpha: 0.22 + 0.25 * p),
                blurRadius: 18 + 14 * p,
                spreadRadius: 1 + 3 * p,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onPressed,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow_rounded, size: 32, color: Colors.black87),
              SizedBox(width: 6),
              Text(
                'MULAI',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Serpihan sampah (kertas, kaleng, daun, tutup botol) yang melayang pelan
/// dari kanan ke kiri. Murni dekorasi; posisi dihitung dari waktu.
class _DriftPainter extends CustomPainter {
  _DriftPainter(Listenable repaint, this.t0) : super(repaint: repaint);

  final int t0;

  static const List<Color> _cols = [
    Color(0xFFF5F5F5),
    Color(0xFF8BC34A),
    Color(0xFFC49A6C),
    Color(0xFF90A4AE),
    Color(0xFFFFE082),
  ];

  static double _r(int s) => ((s * 9301 + 49297) % 233280) / 233280.0;

  @override
  void paint(Canvas canvas, Size size) {
    final t = (sceneNowMs() - t0) / 1000.0;
    final p = Paint();
    final span = size.width + 80;
    for (var i = 0; i < 20; i++) {
      final r1 = _r(i * 3 + 1);
      final r2 = _r(i * 3 + 2);
      final r3 = _r(i * 3 + 3);
      final speed = 18 + 26 * r1;
      final x = size.width + 40 - ((r2 * span + t * speed) % span);
      final y = size.height * (0.06 + 0.52 * r3) + sin(t * 0.9 + i) * 14;
      final sz = 3.5 + 4 * r1;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * (0.8 + r2 * 1.6) + i);
      p.color = _cols[i % _cols.length].withValues(alpha: 0.30 + 0.25 * r3);
      if (i % 3 == 0) {
        canvas.drawCircle(Offset.zero, sz * 0.55, p);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: sz * 1.8, height: sz),
            const Radius.circular(1.5),
          ),
          p,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _DriftPainter old) => false;
}

// ====================================================================
//  LAYAR MASUK / BERANDA
// ====================================================================

class LobbyHome extends StatefulWidget {
  const LobbyHome({super.key});

  @override
  State<LobbyHome> createState() => _LobbyHomeState();
}

class _LobbyHomeState extends State<LobbyHome>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _error;
  int _tab = 0; // 0 = Buat Ruangan, 1 = Gabung Ruangan

  SupabaseClient get _db => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _ensureAnonymousSession();
  }

  Future<void> _ensureAnonymousSession() async {
    try {
      if (_db.auth.currentUser == null) {
        await _db.auth.signInAnonymously();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal membuat sesi: $e');
    }
  }

  String _makeRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _createRoom() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _nameFocus.requestFocus();
      setState(() => _error = 'Masukkan nama pemain kost terlebih dahulu!');
      return;
    }

    setState(() {
      _busy = true;
      _busyKey = 'create';
      _error = null;
    });

    try {
      await _ensureAnonymousSession();
      final user = _db.auth.currentUser;
      if (user == null) throw Exception('Sesi anonim belum tersedia.');

      Map<String, dynamic>? room;
      for (var attempt = 0; attempt < 4; attempt++) {
        final code = _makeRoomCode();
        try {
          room = await _db
              .from('rooms')
              .insert({
            'code': code,
            'status': 'waiting',
            'host_id': user.id,
            'max_players': 4,
          })
              .select('id, code')
              .single();
          break;
        } on PostgrestException catch (e) {
          if (e.code != '23505') rethrow;
        }
      }
      if (room == null) throw Exception('Tidak berhasil membuat kode ruangan.');

      await _db.from('room_players').insert({
        'room_id': room['id'],
        'player_id': user.id,
        'player_name': name,
        'is_ready': false,
      });

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RoomLobby(
            roomId: room!['id'].toString(),
            roomCode: room['code'].toString(),
            playerName: name,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() {
        _busy = false;
        _busyKey = null;
      });
    }
  }

  /// MODE KESINTASAN (singleplayer): buat ruangan 1 pemain, mulai langsung.
  Future<void> _startSurvival() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _nameFocus.requestFocus();
      setState(() => _error = 'Masukkan nama pemain kost terlebih dahulu!');
      return;
    }

    setState(() {
      _busy = true;
      _busyKey = 'survival';
      _error = null;
    });

    try {
      await _ensureAnonymousSession();
      final user = _db.auth.currentUser;
      if (user == null) throw Exception('Sesi anonim belum tersedia.');

      final id = (await _db
          .rpc('create_survival_room', params: {'p_name': name}))
          .toString();
      await _db.rpc('start_game', params: {'p_room': id});
      final room =
      await _db.from('rooms').select('id, code').eq('id', id).single();

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            roomId: room['id'].toString(),
            roomCode: room['code'].toString(),
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() {
        _busy = false;
        _busyKey = null;
      });
    }
  }

  Future<void> _joinRoom() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    if (name.isEmpty || code.isEmpty) {
      (name.isEmpty ? _nameFocus : _codeFocus).requestFocus();
      setState(() => _error = 'Isi nama pemain dan 6 digit kode ruangan!');
      return;
    }

    setState(() {
      _busy = true;
      _busyKey = 'join';
      _error = null;
    });

    try {
      await _ensureAnonymousSession();
      final user = _db.auth.currentUser;
      if (user == null) throw Exception('Sesi anonim belum tersedia.');

      final result = await _db.rpc(
        'join_room_by_code',
        params: {'p_code': code, 'p_name': name},
      );

      final roomId = _extractRoomId(result);
      if (roomId == null) {
        throw Exception(
          'Fungsi join_room_by_code tidak mengembalikan UUID ruangan.',
        );
      }

      final room = await _db
          .from('rooms')
          .select('id, code')
          .eq('id', roomId)
          .single();

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RoomLobby(
            roomId: room['id'].toString(),
            roomCode: room['code'].toString(),
            playerName: name,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() {
        _busy = false;
        _busyKey = null;
      });
    }
  }

  String? _extractRoomId(dynamic result) {
    if (result is String) return result;
    if (result is Map) {
      final value = result['room_id'] ?? result['id'];
      return value?.toString();
    }
    if (result is List && result.isNotEmpty) {
      return _extractRoomId(result.first);
    }
    return null;
  }

  String _friendlyError(Object e) {
    if (e is PostgrestException) return e.message;
    if (e is AuthException) return e.message;
    return e.toString().replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _nameFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }
  // ------------------------------------------------------------------
  //  UI
  // ------------------------------------------------------------------

  final _nameFocus = FocusNode();
  final _codeFocus = FocusNode();
  String? _busyKey; // 'create' | 'survival' | 'join'

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Latar kost beranimasi di belakang layar masuk.
          const Positioned.fill(
            child: KostBackdrop(
              rooms: 10,
              defense: 2,
              pollution: 12,
              trashRatio: 0.15,
            ),
          ),
          // Penggelap lembut agar judul dan panel selalu terbaca.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _Ui.bg.withValues(alpha: 0.55),
                    _Ui.bg.withValues(alpha: 0.86),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                // Lebar ATAU lanskap ponsel (tinggi pendek) -> dua kolom.
                final wide = c.maxWidth >= _Ui.wideBreakpoint ||
                    (c.maxWidth >= 640 && c.maxWidth > c.maxHeight * 1.3);
                return wide ? _buildWide(c) : _buildNarrow(c);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Ponsel / jendela sempit: satu kolom, urutan = judul → form → gim lain.
  Widget _buildNarrow(BoxConstraints c) {
    final compact = c.maxWidth < 380;
    final hPad = _Ui.fluid(c.maxWidth, 16, 28, to: 600);
    final titleSize = _Ui.fluid(c.maxWidth, 34, 44, to: 480);
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _Ui.maxNarrow,
            minHeight: max(0.0, c.maxHeight - 48),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHero(center: true, titleSize: titleSize),
              const SizedBox(height: 28),
              _buildFormPanel(compact: compact),
              _Ui.gap12,
              const _MoreGamesCard(center: true),
              _Ui.gap16,
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  /// Tablet / desktop / lanskap: judul di kiri, form di kanan.
  /// Lebar konten dikunci agar tidak melebar di monitor besar.
  Widget _buildWide(BoxConstraints c) {
    final hPad = _Ui.fluid(c.maxWidth, 24, 40, from: 640, to: 1100);
    final gap = _Ui.fluid(c.maxWidth, 28, 56, from: 640, to: 1100);
    final titleSize = _Ui.fluid(c.maxWidth, 40, 56, from: 640, to: 1100);
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _Ui.maxHome,
            minHeight: max(0.0, c.maxHeight - 48),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHero(center: false, titleSize: titleSize),
                    const SizedBox(height: 28),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: const _MoreGamesCard(),
                    ),
                    _Ui.gap16,
                    _buildFooter(left: true),
                  ],
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                flex: 4,
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _buildFormPanel(compact: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero({required bool center, required double titleSize}) {
    final align = center ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = center ? TextAlign.center : TextAlign.left;
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: center ? Alignment.center : Alignment.centerLeft,
          child: Text(
            'SAMPAHNYA!',
            maxLines: 1,
            textAlign: textAlign,
            style: _Ui.title.copyWith(fontSize: titleSize),
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(
            'Bangun kamar, kelola limbah, atau timbun kost tetangga!',
            textAlign: textAlign,
            style: _Ui.body(0.86).copyWith(
              fontSize: 15,
              height: 1.45,
              shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter({bool left = false}) {
    return Text(
      'Sampahnya! v$appVersion',
      textAlign: left ? TextAlign.left : TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.35),
        fontSize: 11,
      ),
    );
  }

  /// Panel form: 1) nama → 2) pilih mode → 3) aksi → (error).
  Widget _buildFormPanel({required bool compact}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Nama pemain', style: _Ui.label),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            focusNode: _nameFocus,
            maxLength: 18,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            textInputAction: _tab == 1 ? TextInputAction.next : TextInputAction.done,
            onChanged: (_) => _clearError(),
            onSubmitted: (_) {
              if (_tab == 1) {
                _codeFocus.requestFocus();
              } else {
                _nameFocus.unfocus();
              }
            },
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            decoration: _inputDecoration(
              hint: 'Contoh: Mama Kos',
              icon: Icons.badge_outlined,
            ),
          ),
          const SizedBox(height: 16),
          _buildModeSwitcher(),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _tab == 0 ? _buildCreateSection() : _buildJoinSection(),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _ErrorBanner(_error!),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.32)),
      prefixIcon: Icon(icon, color: _Ui.amber, size: 22),
      counterText: '',
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.07),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_Ui.radiusField),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_Ui.radiusField),
        borderSide: const BorderSide(color: _Ui.amber, width: 2),
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _modeTab(
              index: 0,
              icon: Icons.add_business_rounded,
              label: 'Buat ruangan',
            ),
          ),
          Expanded(
            child: _modeTab(
              index: 1,
              icon: Icons.meeting_room_rounded,
              label: 'Gabung',
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeTab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _tab == index;
    final color = selected ? _Ui.amber : Colors.white60;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _busy
            ? null
            : () => setState(() {
          _tab = index;
          _error = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? _Ui.amber : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Buat ruangan untuk 2–4 pemain, lalu bagikan kodenya ke teman-temanmu.',
          style: _Ui.body(0.62).copyWith(fontSize: 12.5),
        ),
        _Ui.gap12,
        _ActionButton(
          label: _busyKey == 'create' ? 'Membuka lahan…' : 'Buat ruangan baru',
          icon: Icons.rocket_launch_rounded,
          busy: _busyKey == 'create',
          onPressed: _busy ? null : _createRoom,
        ),
        _Ui.gap16,
        const _OrDivider('atau main sendiri'),
        _Ui.gap16,
        LayoutBuilder(
          builder: (context, c) {
            final survival = _ActionButton(
              label: _busyKey == 'survival' ? 'Menyiapkan…' : 'Kesintasan',
              icon: Icons.timer_rounded,
              busy: _busyKey == 'survival',
              outlined: true,
              height: 48,
              onPressed: _busy ? null : _startSurvival,
            );
            final board = _ActionButton(
              label: 'Papan skor',
              icon: Icons.emoji_events_rounded,
              outlined: true,
              height: 48,
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SurvivalLeaderboardScreen(),
                ),
              ),
            );
            if (c.maxWidth < 280) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [survival, _Ui.gap8, board],
              );
            }
            return Row(
              children: [
                Expanded(child: survival),
                const SizedBox(width: 10),
                Expanded(child: board),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildJoinSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Kode ruangan', style: _Ui.label),
        _Ui.gap8,
        TextField(
          controller: _codeController,
          focusNode: _codeFocus,
          maxLength: 6,
          enabled: !_busy,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onChanged: (_) => _clearError(),
          onSubmitted: (_) {
            if (!_busy) _joinRoom();
          },
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
          ],
          style: const TextStyle(
            color: _Ui.amber,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            hintText: '• • • • • •',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.22),
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 4,
            ),
            counterText: '',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.07),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_Ui.radiusField),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_Ui.radiusField),
              borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Minta kode 6 karakter dari pembuat ruangan.',
          textAlign: TextAlign.center,
          style: _Ui.body(0.55).copyWith(fontSize: 12),
        ),
        _Ui.gap16,
        _ActionButton(
          label: _busyKey == 'join' ? 'Menyambungkan…' : 'Gabung sekarang',
          icon: Icons.login_rounded,
          busy: _busyKey == 'join',
          background: _Ui.greenBright,
          foreground: Colors.white,
          onPressed: _busy ? null : _joinRoom,
        ),
      ],
    );
  }
}

// ====================================================================
//  LAYAR LOBI RUANGAN
// ====================================================================

class RoomLobby extends StatefulWidget {
  const RoomLobby({
    super.key,
    required this.roomId,
    required this.roomCode,
    required this.playerName,
  });

  final String roomId;
  final String roomCode;
  final String playerName;

  @override
  State<RoomLobby> createState() => _RoomLobbyState();
}

class _RoomLobbyState extends State<RoomLobby>
    with SingleTickerProviderStateMixin {
  // Sama dengan warna dinding di game agar rumah terlihat konsisten.
  static const _walls = [
    Color(0xFFF0DFB8),
    Color(0xFFCFE6D6),
    Color(0xFFF4CFC4),
    Color(0xFFD1DCF2),
  ];

  late final AnimationController _anim;
  final KostStreetCamera _cam = KostStreetCamera();
  final Map<String, List<KostFx>> _fx = {};
  final Map<String, bool> _prevReady = {};
  bool _playersLoaded = false;
  final Map<String, double> _lightLv = {}; // 0..1 per pemain, menyala bertahap
  int _lastLightMs = sceneNowMs();

  SupabaseClient get _db => Supabase.instance.client;
  List<Map<String, dynamic>> _players = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  RealtimeChannel? _channel;
  String? _hostId;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    _anim.addListener(() {
      _cam.step();
      final now = sceneNowMs();
      // Jendela menyala/redup bertahap (bukan seketika) saat SIAP berubah.
      final dt = min(0.1, max(0, now - _lastLightMs) / 1000.0);
      _lastLightMs = now;
      final k = 1 - exp(-dt * 2.2);
      for (final p in _players) {
        final pid = p['player_id'].toString();
        final target = p['is_ready'] == true ? 1.0 : 0.0;
        final cur = _lightLv[pid] ?? 0.0;
        _lightLv[pid] = cur + (target - cur) * k;
      }
      for (final l in _fx.values) {
        l.removeWhere((f) => now - f.startMs > 5000);
      }
    });
    _refreshPlayers();
    _refreshRoom();
    _channel = _db
        .channel('lobby-${widget.roomId}')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'room_players',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: widget.roomId,
      ),
      callback: (_) => _refreshPlayers(),
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'rooms',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: widget.roomId,
      ),
      callback: (_) => _refreshRoom(),
    )
        .subscribe();
  }

  Future<void> _refreshPlayers() async {
    try {
      final data = await _db
          .from('room_players')
          .select('player_id, player_name, is_ready, style, style_status')
          .eq('room_id', widget.roomId)
          .order('player_name');

      if (!mounted) return;
      final list = List<Map<String, dynamic>>.from(data);
      // Reaksi visual: 😎 saat ada yang bergabung, 👏 saat seseorang SIAP.
      final ids = <String>{};
      for (final p in list) {
        final pid = p['player_id'].toString();
        final ready = p['is_ready'] == true;
        ids.add(pid);
        if (_playersLoaded) {
          if (!_prevReady.containsKey(pid)) {
            _addFx(pid, 2);
          } else if (ready && _prevReady[pid] == false) {
            _addFx(pid, 8);
          }
        }
        _prevReady[pid] = ready;
      }
      _prevReady.removeWhere((k, _) => !ids.contains(k));
      _playersLoaded = true;
      setState(() {
        _players = list;
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

  void _addFx(String pid, int emojiCode) {
    (_fx[pid] ??= <KostFx>[])
        .add(KostFx(FxType.emoji, amount: emojiCode.toDouble()));
  }

  /// Urutan rumah di jalan: diurutkan berdasarkan id (sama dengan layar game).
  List<Map<String, dynamic>> get _ordered => [..._players]..sort((a, b) =>
      a['player_id'].toString().compareTo(b['player_id'].toString()));

  Future<void> _refreshRoom() async {
    try {
      final room = await _db
          .from('rooms')
          .select('host_id, status')
          .eq('id', widget.roomId)
          .single();
      if (!mounted) return;
      setState(() => _hostId = room['host_id']?.toString());
      if (room['status'] == 'playing' && !_navigated) {
        _navigated = true;
        // pushAndRemoveUntil: lobi DAN layar kustomisasi (bila sedang terbuka
        // di atasnya) sama-sama dibuang; halaman awal tetap di bawah.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => GameScreen(
              roomId: widget.roomId,
              roomCode: widget.roomCode,
            ),
          ),
              (route) => route.isFirst,
        );
      }
    } catch (_) {}
  }

  Future<void> _startGame() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _db.rpc('start_game', params: {'p_room': widget.roomId});
      await _refreshRoom();
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleReady() async {
    final user = _db.auth.currentUser;
    if (user == null) return;

    final me = _players.where((p) => p['player_id'] == user.id).firstOrNull;
    if (me == null) {
      setState(() => _error = 'Data pemain Anda belum muncul di lobi.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _db
          .from('room_players')
          .update({'is_ready': !(me['is_ready'] == true)})
          .eq('room_id', widget.roomId)
          .eq('player_id', user.id);
      await _refreshPlayers();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Pemain lain (bukan saya) yang sedang berkustomisasi.
  List<Map<String, dynamic>> get _othersEditing {
    final uid = _db.auth.currentUser?.id;
    return _players
        .where((p) =>
    p['player_id'] != uid && p['style_status'] == 'editing')
        .toList();
  }

  Future<void> _chooseDefaultStyle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _db.rpc('set_style_status',
          params: {'p_room': widget.roomId, 'p_status': 'default'});
      await _refreshPlayers();
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openCustomize({bool readOnly = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomizeScreen(
          roomId: widget.roomId,
          roomCode: widget.roomCode,
          readOnly: readOnly,
        ),
      ),
    );
    if (mounted) _refreshPlayers();
  }

  /// Kartu pilihan tampilan: bawaan atau masuk ruang kustomisasi bersama.
  Widget _buildStyleCard(Map<String, dynamic>? me) {
    final status = (me?['style_status'] ?? 'pending').toString();
    final others = _othersEditing;
    final (label, color) = switch (status) {
      'done' => ('Kustom', _Ui.greenSoft),
      'default' => ('Bawaan', Colors.white70),
      'editing' => ('Mengedit', _Ui.amber),
      _ => ('Belum dipilih', Colors.white54),
    };
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.palette_rounded, size: 18, color: _Ui.amber),
              const SizedBox(width: 8),
              const Expanded(child: Text('Tampilan', style: _Ui.label)),
              _Pill(label: label, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pakai tampilan bawaan, atau ubah karakter & bangunanmu bersama pemain lain.',
            style: _Ui.body(0.58).copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _chooseDefaultStyle,
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                    status == 'default' ? _Ui.amber : Colors.white,
                    side: BorderSide(
                      color: status == 'default'
                          ? _Ui.amber
                          : Colors.white.withValues(alpha: 0.22),
                      width: status == 'default' ? 2 : 1,
                    ),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Bawaan',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy || me == null ? null : _openCustomize,
                  style: FilledButton.styleFrom(
                    backgroundColor: _Ui.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.brush_rounded, size: 18),
                  label: Text(
                    status == 'done' ? 'Ubah lagi' : 'Kustomisasi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Menunggu ${others.map((p) => p['player_name']).join(', ')} '
                        'selesai kustomisasi…',
                    style: _Ui.body(0.7).copyWith(fontSize: 12.5),
                  ),
                ),
                TextButton(
                  onPressed: () => _openCustomize(readOnly: true),
                  child: const Text('Lihat'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.roomCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _Ui.green,
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Kode ruangan ${widget.roomCode} berhasil disalin!'),
              ),
            ],
          ),
        ),
      );
  }

  @override
  void dispose() {
    _anim.dispose();
    if (_channel != null) {
      _db.removeChannel(_channel!);
    }
    super.dispose();
  }


  // ------------------------------------------------------------------
  //  UI
  // ------------------------------------------------------------------

  static const int _maxPlayers = 4;

  @override
  Widget build(BuildContext context) {
    final userId = _db.auth.currentUser?.id;
    final me = _players.where((p) => p['player_id'] == userId).firstOrNull;
    final ready = me?['is_ready'] == true;
    final isHost = _hostId != null && _hostId == userId;
    final readyCount = _players.where((p) => p['is_ready'] == true).length;
    final allReady = _players.length >= 2 && readyCount == _players.length;

    return Scaffold(
      body: Stack(
        children: [
          // Jumlah kamar di latar belakang bertambah mengikuti jumlah pemain.
          Positioned.fill(
            child: KostBackdrop(
              rooms: 4 + _players.length * 2,
              defense: readyCount.clamp(0, 3),
              pollution: 5,
              trashRatio: 0.08,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _Ui.bg.withValues(alpha: 0.74),
                    _Ui.bg.withValues(alpha: 0.90),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                // Lebar, atau lanskap ponsel: jalan di kiri, kontrol di kanan.
                final wide = c.maxWidth >= _Ui.wideBreakpoint ||
                    (c.maxWidth > c.maxHeight && c.maxWidth >= 640);
                final pad = _Ui.fluid(c.maxWidth, 14, 24, to: 900);
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: wide ? _Ui.maxLobby : _Ui.maxNarrow + 80,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(pad, 12, pad, pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTopBar(allReady),
                          _Ui.gap12,
                          Expanded(
                            child: wide
                                ? _buildWideBody(
                                userId, ready, me, isHost, allReady, c)
                                : _buildNarrowBody(
                                userId, ready, me, isHost, allReady, c),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Ponsel: konten bisa digulir (kode → jalan → pemain → tampilan),
  /// sedangkan bar aksi (Siap / Mulai) selalu menempel di bawah.
  Widget _buildNarrowBody(
      String? userId, bool ready, Map<String, dynamic>? me, bool isHost,
      bool allReady, BoxConstraints c) {
    final streetH = (c.maxHeight * 0.34).clamp(200.0, 320.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildRoomCodeBanner(),
                _Ui.gap12,
                SizedBox(height: streetH, child: _buildStreetArea(userId)),
                _Ui.gap12,
                _buildPlayerSummary(columns: 2),
                _Ui.gap12,
                _buildStyleCard(me),
                _Ui.gap8,
              ],
            ),
          ),
        ),
        _Ui.gap8,
        _buildActionBar(ready, me, isHost, allReady),
      ],
    );
  }

  /// Layar lebar: jalan di kiri; panel kanan berisi kode, pemain, tampilan,
  /// dengan bar aksi menempel di dasar panel.
  Widget _buildWideBody(
      String? userId, bool ready, Map<String, dynamic>? me, bool isHost,
      bool allReady, BoxConstraints c) {
    final panelW =
    _Ui.fluid(c.maxWidth, 300, _Ui.sidePanel, from: 640, to: 1000);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildStreetArea(userId)),
        const SizedBox(width: 20),
        SizedBox(
          width: panelW,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildRoomCodeBanner(),
                      _Ui.gap12,
                      _buildPlayerSummary(columns: 1),
                      _Ui.gap12,
                      _buildStyleCard(me),
                    ],
                  ),
                ),
              ),
              _Ui.gap12,
              _buildActionBar(ready, me, isHost, allReady),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(bool allReady) {
    final title = allReady
        ? 'Semua pemain siap!'
        : (_players.length < 2
        ? 'Menunggu pemain lain…'
        : 'Menunggu semua siap…');
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Kembali',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ruang tunggu', style: _Ui.label),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _Ui.heading.copyWith(fontSize: 19),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_alt_rounded, size: 16, color: _Ui.amber),
              const SizedBox(width: 6),
              Text(
                '${_players.length}/$_maxPlayers',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoomCodeBanner() {
    return Semantics(
      button: true,
      label: 'Kode ruangan ${widget.roomCode}, ketuk untuk menyalin',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _copyCode,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3C2B), Color(0xFF14281D)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _Ui.amber.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kode ruangan · bagikan ke teman',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.roomCode,
                          style: const TextStyle(
                            color: _Ui.amber,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _Ui.amber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, color: _Ui.amber, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Salin',
                        style: TextStyle(
                          color: _Ui.amber,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Daftar slot pemain (selalu [_maxPlayers] slot; yang kosong diberi
  /// penanda "Menunggu…").
  Widget _buildPlayerSummary({required int columns}) {
    final list = _ordered;
    final userId = _db.auth.currentUser?.id;
    final readyCount = list.where((p) => p['is_ready'] == true).length;
    final slots = <Map<String, dynamic>?>[
      for (var i = 0; i < _maxPlayers; i++) i < list.length ? list[i] : null,
    ];
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Pemain', style: _Ui.label)),
              Text(
                '$readyCount/${list.length} siap',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              const gap = 8.0;
              final w = columns == 1 ? c.maxWidth : (c.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final p in slots)
                    SizedBox(width: w, child: _slotChip(p, userId)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _slotChip(Map<String, dynamic>? p, String? userId) {
    if (p == null) {
      return Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded,
                size: 16, color: Colors.white.withValues(alpha: 0.28)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Menunggu…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final pid = p['player_id'].toString();
    final ready = p['is_ready'] == true;
    final editing = p['style_status'] == 'editing';
    final isMe = pid == userId;
    final isHost = pid == _hostId;
    final accent = ready ? _Ui.greenSoft : Colors.amber.shade300;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: ready
            ? const Color(0xFF43A047).withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ready
              ? const Color(0xFF66BB6A).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          KostHeadIcon(
            look: kostLookFor(pid, KostStyle.fromJson(p['style'])),
            size: 24,
            ring: isMe ? _Ui.amber : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${p['player_name'] ?? 'Pemain'}${isMe ? ' (Anda)' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMe ? _Ui.amber : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          if (isHost)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.workspace_premium_rounded,
                  size: 15, color: _Ui.amber),
            ),
          const SizedBox(width: 6),
          Icon(
            editing
                ? Icons.brush_rounded
                : (ready
                ? Icons.check_circle_rounded
                : Icons.hourglass_bottom_rounded),
            size: 16,
            color: accent,
          ),
        ],
      ),
    );
  }

  /// Bar aksi tetap di bawah: pesan status, error, lalu tombol Siap / Mulai.
  Widget _buildActionBar(
      bool ready, Map<String, dynamic>? me, bool isHost, bool allReady) {
    final (IconData hintIcon, String hint, Color hintColor) = _othersEditing.isNotEmpty
        ? (
    Icons.brush_rounded,
    'Menunggu pemain lain selesai kustomisasi…',
    _Ui.amber
    )
        : isHost
        ? (allReady
        ? (
    Icons.check_circle_rounded,
    'Semua pemain sudah siap! Tekan Mulai game.',
    _Ui.greenSoft
    )
        : (
    Icons.hourglass_bottom_rounded,
    'Butuh minimal 2 pemain, dan semuanya menekan Saya siap.',
    Colors.white70
    ))
        : (
    Icons.hourglass_bottom_rounded,
    'Menunggu host memulai pertandingan…',
    Colors.white70
    );

    final readyBtn = _ActionButton(
      label: _busy
          ? 'Memproses…'
          : ready
          ? 'Batal siap'
          : 'Saya siap!',
      icon: ready ? Icons.pause_circle_outline : Icons.check_circle_rounded,
      background: ready ? const Color(0xFF37474F) : _Ui.greenBright,
      foreground: Colors.white,
      onPressed: _busy || me == null ? null : _toggleReady,
    );
    final startBtn = _ActionButton(
      label: 'Mulai game',
      icon: Icons.play_arrow_rounded,
      background: _Ui.amber,
      foreground: Colors.black87,
      onPressed: _busy || !allReady ? null : _startGame,
    );

    return _GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            _ErrorBanner(_error!),
            _Ui.gap12,
          ],
          Row(
            children: [
              Icon(hintIcon, size: 16, color: hintColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hint,
                  style: TextStyle(
                    color: hintColor == Colors.white70
                        ? Colors.white.withValues(alpha: 0.65)
                        : hintColor,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          _Ui.gap12,
          LayoutBuilder(
            builder: (context, c) {
              if (!isHost) return readyBtn;
              // Di ruang sempit tumpuk vertikal agar teks tombol tidak terpotong.
              if (c.maxWidth < 300) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [readyBtn, _Ui.gap8, startBtn],
                );
              }
              return Row(
                children: [
                  Expanded(child: readyBtn),
                  const SizedBox(width: 10),
                  Expanded(child: startBtn),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStreetArea(String? userId) {
    if (_loading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return _buildStreet(userId);
  }

  KostSceneData _houseFor(Map<String, dynamic> p, int i) {
    final pid = p['player_id'].toString();
    final ready = p['is_ready'] == true;
    final style = KostStyle.fromJson(p['style']);
    return KostSceneData(
      rooms: 4,
      maxRooms: 12,
      defense: ready ? 1 : 0,
      wasteLevel: 1,
      trashRatio: 0,
      pollution: 4,
      wall: style?.wallColor ?? _walls[i % _walls.length],
      style: (style == null || style.isEmpty) ? null : style,
      fx: _fx[pid] ?? const <KostFx>[],
      seed: pid.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) % 1000),
      // SIAP -> jendela menyala; belum siap -> gelap.
      lights: _lightLv[pid] ?? (ready ? 1.0 : 0.0),
    );
  }

  Widget _buildStreet(String? userId) {
    final list = _ordered;
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
            color: Colors.white.withValues(alpha: 0.16),
            width: 1.5,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final size = Size(c.maxWidth, c.maxHeight);
            const insets = EdgeInsets.only(top: 52);
            final stage = _cam.stageFor(size, insets);
            final fit = min(
              stage.width * 0.96 / (n * kStreetSlotW),
              stage.height / kStreetSlotH,
            );
            _cam.setTarget(n * kStreetSlotW / 2, min(fit, 1.15));

            final backdrop = KostSceneData(
              rooms: 0,
              maxRooms: 12,
              defense: 0,
              trashRatio: 0,
              pollution: 4,
            );
            final ids = [for (final p in list) p['player_id'].toString()];

            return Stack(
              children: [
                Positioned.fill(
                  // dibangun ulang tiap frame agar cahaya jendela & efek halus
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) => KostStreet(
                      houses: [
                        for (var i = 0; i < n; i++) _houseFor(list[i], i),
                      ],
                      backdrop: backdrop,
                      camera: _cam,
                      repaint: _anim,
                      ids: ids,
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
                        children: _nameTags(list, stage, userId),
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

  /// Kartu nama + status SIAP di atas atap tiap rumah, mengikuti kamera.
  List<Widget> _nameTags(
      List<Map<String, dynamic>> list, Rect stage, String? userId) {
    final s = _cam.scale;
    final o = _cam.origin(stage);
    final out = <Widget>[];
    for (var i = 0; i < list.length; i++) {
      final p = list[i];
      final pid = p['player_id'].toString();
      final cx = o.dx + (i * kStreetSlotW + kStreetSlotW / 2) * s;
      final roofY = o.dy + (236.0 - 50.0) * s;
      final w = (kStreetSlotW * s - 6).clamp(84.0, 190.0).toDouble();
      final emoji = kostActiveEmoji(_fx[pid]);
      final top = max(
          4.0, roofY - 47 * s - 54 - (emoji != null ? kEmojiBoxH : 0.0));
      out.add(Positioned(
        left: cx - w / 2,
        top: top,
        width: w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) KostEmojiBubble(fx: emoji),
            _nameTag(p, pid == userId, pid == _hostId),
          ],
        ),
      ));
    }
    return out;
  }

  Widget _nameTag(Map<String, dynamic> p, bool isMe, bool isHost) {
    final ready = p['is_ready'] == true;
    final editing = p['style_status'] == 'editing';
    final accent = ready ? _Ui.greenSoft : Colors.amber.shade300;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: _Ui.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ready
              ? const Color(0xFF66BB6A)
              : (isMe
              ? _Ui.amber.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.18)),
          width: ready || isMe ? 1.8 : 1,
        ),
        boxShadow: [
          if (ready)
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.35),
              blurRadius: 12,
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              KostHeadIcon(
                look: kostLookFor(
                    p['player_id'].toString(), KostStyle.fromJson(p['style'])),
                size: 18,
                ring: isMe ? _Ui.amber : null,
              ),
              const SizedBox(width: 5),
              if (isHost)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.workspace_premium_rounded,
                      size: 13, color: _Ui.amber),
                ),
              Flexible(
                child: Text(
                  '${p['player_name'] ?? 'Pemain'}${isMe ? ' (Anda)' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isMe ? _Ui.amber : Colors.white,
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
              Icon(
                editing
                    ? Icons.brush_rounded
                    : (ready ? Icons.lightbulb_rounded : Icons.lightbulb_outline),
                size: 12,
                color: accent,
              ),
              const SizedBox(width: 3),
              Text(
                editing ? 'Kustomisasi…' : (ready ? 'Siap' : 'Belum siap'),
                style: TextStyle(
                  color: accent,
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
}