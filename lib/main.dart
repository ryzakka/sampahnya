import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'customize_screen.dart';
import 'game_screen.dart';
import 'kost_scene.dart';
import 'kost_style.dart';

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Jarak
  static const gap16 = SizedBox(height: 16);
  static const gap24 = SizedBox(height: 24);

  // Skala teks
  static const title = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w900,
    letterSpacing: 2,
    height: 1.05,
    shadows: [Shadow(color: Colors.black87, blurRadius: 16, offset: Offset(0, 5))],
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
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsets padding;
  static const double radius = 28;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _Ui.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Tombol aksi utama / sekunder dengan status sibuk.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.background = _Ui.amber,
    this.foreground = Colors.black87,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final bool busy;
  static const double height = 54;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
          disabledForegroundColor: Colors.white38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        onPressed: onPressed,
        icon: busy
            ? SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: foreground,
          ),
        )
            : Icon(icon),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F).withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Ui.danger.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF8A80), size: 20),
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

/// Kartu tautan ke gim lain (Linguistify).
class _MoreGamesCard extends StatelessWidget {
  const _MoreGamesCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Buka gim Linguistic Hegemony di browser',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _Ui.openLink(context, linguistifyUrl),
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E2350).withValues(alpha: 0.9),
                  const Color(0xFF14283A).withValues(alpha: 0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _Ui.violet.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _Ui.violet.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.translate_rounded,
                      color: _Ui.violet, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gim lain dari kami',
                        style: TextStyle(
                          color: _Ui.violet,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Linguistic Hegemony',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Strategi ala Plague Inc dan Eco Inc, tapi tentang bahasa dan politik.',
                        style: _Ui.body(0.72).copyWith(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _Ui.violet,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Main',
                        style: TextStyle(
                          color: Color(0xFF14183A),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(width: 5),
                      Icon(Icons.open_in_new_rounded,
                          size: 15, color: Color(0xFF14183A)),
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
        fontFamily: 'sans-serif',
      ),
      home: const LobbyHome(),
    );
  }
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
      setState(() => _error = 'Masukkan nama pemain kost terlebih dahulu!');
      return;
    }

    setState(() {
      _busy = true;
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
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinRoom() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    if (name.isEmpty || code.isEmpty) {
      setState(() => _error = 'Isi nama pemain dan 6 digit kode ruangan!');
      return;
    }

    setState(() {
      _busy = true;
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
      if (mounted) setState(() => _busy = false);
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
    super.dispose();
  }

  // ------------------------------------------------------------------
  //  UI
  // ------------------------------------------------------------------

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
          // Vignette agar panel di depan terbaca.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.1,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    _Ui.bg.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= _Ui.wideBreakpoint;
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
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 24,
        vertical: 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 460,
            minHeight: c.maxHeight - 48,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHero(center: true, titleSize: compact ? 34 : 42),
              _Ui.gap24,
              _buildFormPanel(compact: compact),
              _Ui.gap16,
              const _MoreGamesCard(),
              _Ui.gap16,
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  /// Tablet / desktop: judul di kiri, form di kanan.
  Widget _buildWide(BoxConstraints c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 1040,
            minHeight: c.maxHeight - 64,
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
                    _buildHero(center: false, titleSize: 56),
                    const SizedBox(height: 28),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: const _MoreGamesCard(),
                    ),
                    _Ui.gap16,
                    _buildFooter(left: true),
                  ],
                ),
              ),
              const SizedBox(width: 48),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _Ui.amber,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _Ui.amber.withValues(alpha: 0.4),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.black87),
              SizedBox(width: 6),
              Text(
                'Gim multipemain 2–4 orang',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'SAMPAHNYA!',
          textAlign: textAlign,
          style: _Ui.title.copyWith(fontSize: titleSize),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            'Bangun kamar, kelola limbah, atau timbun kost tetangga!',
            textAlign: textAlign,
            style: _Ui.body(0.88).copyWith(
              fontSize: 15,
              shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter({bool left = false}) {
    return Text(
      'Sampahnya! v1.4.6 (2210:1)',
      textAlign: left ? TextAlign.left : TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.4),
        fontSize: 11,
      ),
    );
  }

  /// Panel form: 1) nama → 2) pilih mode → 3) aksi → (error).
  Widget _buildFormPanel({required bool compact}) {
    return _GlassPanel(
      padding: EdgeInsets.all(compact ? 18 : 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Nama pemain', style: _Ui.label),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            maxLength: 18,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            decoration: _inputDecoration(
              hint: 'Mama Kos',
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
          if (_error != null) ...[
            _Ui.gap16,
            _ErrorBanner(_error!),
          ],
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
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
      prefixIcon: Icon(icon, color: _Ui.amber),
      counterText: '',
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.28),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _Ui.amber, width: 2),
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
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
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          _tab = index;
          _error = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _Ui.green : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : Colors.white60),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,
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
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: _Ui.greenSoft, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Buat ruangan baru untuk 2–4 pemain, lalu bagikan kodenya ke teman-temanmu.',
                  style: _Ui.body(0.72).copyWith(fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ActionButton(
          label: _busy ? 'Membuka lahan…' : 'Buat ruangan baru',
          icon: Icons.rocket_launch_rounded,
          busy: _busy,
          onPressed: _busy ? null : _createRoom,
        ),
      ],
    );
  }

  Widget _buildJoinSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _codeController,
          maxLength: 6,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
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
            hintText: 'Kode 6 digit',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.28),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
            counterText: '',
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.35),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ActionButton(
          label: _busy ? 'Menyambungkan…' : 'Gabung sekarang',
          icon: Icons.login_rounded,
          busy: _busy,
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
          Row(
            children: [
              const Icon(Icons.palette_rounded, size: 18, color: _Ui.amber),
              const SizedBox(width: 8),
              const Expanded(child: Text('Tampilan', style: _Ui.label)),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pakai tampilan bawaan, atau ubah karakter & bangunanmu di ruang '
                'kustomisasi bersama pemain lain.',
            style: _Ui.body(0.6),
          ),
          const SizedBox(height: 10),
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
                          : Colors.white.withValues(alpha: 0.3),
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
                    backgroundColor: _Ui.greenBright,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.brush_rounded, size: 18),
                  label: Text(
                    status == 'done' ? 'Ubah lagi' : 'Kustomisasi',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 8),
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
                    style: _Ui.body(0.7),
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
                    _Ui.bg.withValues(alpha: 0.72),
                    _Ui.bg.withValues(alpha: 0.88),
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
                final pad = c.maxWidth < 380 ? 14.0 : 20.0;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 1100 : 620),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(pad, 12, pad, pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTopBar(),
                          const SizedBox(height: 14),
                          Expanded(
                            child: wide
                                ? _buildWideBody(
                                userId, ready, me, isHost, allReady)
                                : _buildNarrowBody(
                                userId, ready, me, isHost, allReady),
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

  /// Ponsel: kode → jalan (mengisi sisa layar) → tombol.
  Widget _buildNarrowBody(
      String? userId, bool ready, Map<String, dynamic>? me, bool isHost,
      bool allReady) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRoomCodeBanner(),
        const SizedBox(height: 14),
        Expanded(child: _buildStreetArea(userId)),
        const SizedBox(height: 12),
        ..._buildControls(ready, me, isHost, allReady),
      ],
    );
  }

  /// Layar lebar: jalan di kiri; kode + tombol di panel kanan.
  Widget _buildWideBody(
      String? userId, bool ready, Map<String, dynamic>? me, bool isHost,
      bool allReady) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildStreetArea(userId)),
        const SizedBox(width: 20),
        SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildRoomCodeBanner(),
                const SizedBox(height: 16),
                _buildPlayerSummary(),
                const SizedBox(height: 16),
                ..._buildControls(ready, me, isHost, allReady),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Kembali',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ruang tunggu', style: _Ui.label),
              Text(
                'Menunggu pemain lain…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _Ui.heading,
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_alt_rounded, size: 16, color: _Ui.amber),
              const SizedBox(width: 6),
              Text(
                '${_players.length}/4',
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

  /// Ringkasan pemain (hanya di layout lebar): siapa host, siapa sudah siap.
  Widget _buildPlayerSummary() {
    final list = _ordered;
    final userId = _db.auth.currentUser?.id;
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
          const Text('Pemain', style: _Ui.label),
          const SizedBox(height: 8),
          if (list.isEmpty)
            Text('Belum ada pemain.', style: _Ui.body(0.6))
          else
            for (final p in list)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      p['style_status'] == 'editing'
                          ? Icons.brush_rounded
                          : (p['is_ready'] == true
                          ? Icons.check_circle_rounded
                          : Icons.hourglass_bottom_rounded),
                      size: 18,
                      color: p['is_ready'] == true
                          ? _Ui.greenSoft
                          : Colors.amber.shade300,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${p['player_name'] ?? 'Pemain'}'
                            '${p['player_id'].toString() == userId ? ' (Anda)' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (p['player_id'].toString() == _hostId)
                      const Icon(Icons.workspace_premium_rounded,
                          size: 16, color: _Ui.amber),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  /// Tombol SIAP + MULAI + status + error. Dipakai di kedua layout.
  List<Widget> _buildControls(
      bool ready, Map<String, dynamic>? me, bool isHost, bool allReady) {
    return [
      if (_error != null) ...[
        _ErrorBanner(_error!),
        const SizedBox(height: 12),
      ],
      _buildStyleCard(me),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, c) {
          final readyBtn = _ActionButton(
            label: _busy
                ? 'Memproses…'
                : ready
                ? 'Batal siap'
                : 'Saya siap!',
            icon:
            ready ? Icons.pause_circle_outline : Icons.check_circle_rounded,
            background: ready ? const Color(0xFF37474F) : _Ui.greenBright,
            foreground: Colors.white,
            onPressed: _busy || me == null ? null : _toggleReady,
          );
          final startBtn = _ActionButton(
            label: 'Mulai game',
            icon: Icons.play_arrow_rounded,
            background: allReady ? _Ui.amber : Colors.white.withValues(alpha: 0.15),
            foreground: allReady ? Colors.black87 : Colors.white54,
            onPressed: _busy ? null : _startGame,
          );
          if (!isHost) return readyBtn;
          // Di ruang sempit tumpuk vertikal agar teks tombol tidak terpotong.
          if (c.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [readyBtn, const SizedBox(height: 10), startBtn],
            );
          }
          return Row(
            children: [
              Expanded(child: readyBtn),
              const SizedBox(width: 12),
              Expanded(child: startBtn),
            ],
          );
        },
      ),
      const SizedBox(height: 8),
      Text(
        _othersEditing.isNotEmpty
            ? 'Menunggu pemain lain selesai kustomisasi…'
            : isHost
            ? (allReady
            ? 'Semua pemain sudah siap! Tekan Mulai game.'
            : 'Menunggu minimal 2 pemain dan semuanya menekan Saya siap.')
            : 'Menunggu host memulai pertandingan…',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.65),
          fontSize: 12,
        ),
      ),
    ];
  }

  Widget _buildStreetArea(String? userId) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _buildStreet(userId);
  }

  Widget _buildRoomCodeBanner() {
    return Semantics(
      button: true,
      label: 'Kode ruangan ${widget.roomCode}, ketuk untuk menyalin',
      child: InkWell(
        onTap: _copyCode,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3C2B), Color(0xFF14281D)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _Ui.amber.withValues(alpha: 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kode ruangan',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
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
                          fontSize: 32,
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
                  color: _Ui.amber.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _Ui.amber.withValues(alpha: 0.4)),
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
    );
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