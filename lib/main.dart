import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:desktop_drop/desktop_drop.dart';

const String _currentVersion = '2.0.0';
const String _repoOwner = 'zechengccc-alt';
const String _repoName = 'oko';

void main() {
  runApp(const OkoApp());
}

// ============================================================
// SPLASH SCREEN
// ============================================================

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;

  // Phase timings (ms)
  static const int _totalMs = 2200;
  static const int _kAppearStart = 300;
  static const int _kAppearEnd = 700;
  static const int _splitStart = 700;
  static const int _splitEnd = 1200;
  static const int _auroraStart = 1200;
  static const int _auroraEnd = 1700;
  static const int _fadeStart = 1700;
  static const int _fadeEnd = 2200;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    );
    _mainController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        widget.onDone();
      });
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  double _progress(int startMs, int endMs) {
    final t = _mainController.value * _totalMs;
    if (t <= startMs) return 0.0;
    if (t >= endMs) return 1.0;
    return (t - startMs) / (endMs - startMs);
  }

  double _easeOut(double t) => 1 - (1 - t) * (1 - t);
  double _easeInOut(double t) => t < 0.5 ? 2 * t * t : 1 - (-2 * t + 2) * (-2 * t + 2) / 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: AnimatedBuilder(
        animation: _mainController,
        builder: (context, _) {
          final breathProgress = _progress(0, _kAppearEnd);
          final kProgress = _easeOut(_progress(_kAppearStart, _kAppearEnd));
          final splitProgress = _easeInOut(_progress(_splitStart, _splitEnd));
          final auroraProgress = _easeOut(_progress(_auroraStart, _auroraEnd));
          final fadeOutProgress = _easeOut(_progress(_fadeStart, _fadeEnd));
          final scaleUp = 1.0 + fadeOutProgress * 0.15;

          return Transform.scale(
            scale: scaleUp,
            child: Opacity(
              opacity: 1.0 - fadeOutProgress,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // --- Breathing aurora glow ---
                  if (breathProgress > 0)
                    Container(
                      width: 280 + breathProgress * 40,
                      height: 280 + breathProgress * 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF00FFD1).withOpacity(0.08 * breathProgress),
                            const Color(0xFF7B2FF7).withOpacity(0.06 * breathProgress),
                            const Color(0xFF00B4D8).withOpacity(0.03 * breathProgress),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.4, 0.7, 1.0],
                        ),
                      ),
                    ),

                  // --- Aurora flow sweep (left to right) ---
                  if (auroraProgress > 0)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 240,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-1.0 + auroraProgress * 2.0, 0),
                            end: Alignment(-1.0 + auroraProgress * 2.0 + 0.6, 0),
                            colors: [
                              Colors.transparent,
                              const Color(0xFF00FFD1).withOpacity(0.4 * auroraProgress),
                              const Color(0xFF7B2FF7).withOpacity(0.35 * auroraProgress),
                              const Color(0xFF00B4D8).withOpacity(0.3 * auroraProgress),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                          ),
                        ),
                      ),
                    ),

                  // --- Particles ---
                  if (auroraProgress > 0)
                    ...List.generate(8, (i) {
                      final angle = (i / 8) * 3.14159 * 2;
                      final dist = 40.0 + auroraProgress * 60.0;
                      final dx = cos(angle) * dist;
                      final dy = sin(angle) * dist;
                      return Transform.translate(
                        offset: Offset(dx, dy),
                        child: Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: [
                              const Color(0xFF00FFD1),
                              const Color(0xFF7B2FF7),
                              const Color(0xFF00B4D8),
                            ][i % 3].withOpacity(0.7 * auroraProgress),
                          ),
                        ),
                      );
                    }),

                  // --- Letters: O k O ---
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Left O (splits from center)
                      _LetterWidget(
                        letter: 'O',
                        opacity: splitProgress,
                        offsetX: -splitProgress * 52,
                        scale: 0.5 + splitProgress * 0.5,
                      ),
                      // Center K
                      _LetterWidget(
                        letter: 'k',
                        opacity: kProgress,
                        offsetX: 0,
                        scale: 0.8 + kProgress * 0.2,
                      ),
                      // Right O (splits from center)
                      _LetterWidget(
                        letter: 'o',
                        opacity: splitProgress,
                        offsetX: splitProgress * 52,
                        scale: 0.5 + splitProgress * 0.5,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LetterWidget extends StatelessWidget {
  final String letter;
  final double opacity;
  final double offsetX;
  final double scale;

  const _LetterWidget({
    required this.letter,
    required this.opacity,
    required this.offsetX,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(offsetX, 0),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Text(
            letter,
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              color: Color(0xFF00FFD1),
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// THEME DATA
// ============================================================

final _darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF00FFD1),
  scaffoldBackgroundColor: const Color(0xFF070B18),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF00FFD1),
    secondary: Color(0xFF0F4C75),
    surface: Color(0xFF0D1225),
    surfaceContainerHighest: Color(0xFF141B33),
  ),
  useMaterial3: true,
);

final _lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFF0F4C75),
  scaffoldBackgroundColor: const Color(0xFFF0F4FA),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF0F4C75),
    secondary: Color(0xFF00FFD1),
    surface: Colors.white,
  ),
  useMaterial3: true,
);

class OkoApp extends StatefulWidget {
  const OkoApp({super.key});

  @override
  State<OkoApp> createState() => _OkoAppState();
}

class _OkoAppState extends State<OkoApp> {
  bool _showSplash = true;
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final tm = prefs.getInt('theme_mode') ?? 0;
    if (mounted) setState(() => _themeMode = ThemeMode.values[tm]);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oko',
      debugShowCheckedModeBanner: false,
      theme: _darkTheme,
      darkTheme: _darkTheme,
      themeMode: _themeMode,
      home: _showSplash
          ? SplashScreen(onDone: () => setState(() => _showSplash = false))
          : const ChatPage(),
    );
  }
}

// ============================================================
// CHAT MESSAGE
// ============================================================

class ChatMessage {
  final int? id;
  final String content;
  final bool isUser;
  final String timestamp;
  final int sessionId;

  ChatMessage({
    this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    required this.sessionId,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id!,
        'content': content,
        'is_user': isUser ? 1 : 0,
        'timestamp': timestamp,
        'session_id': sessionId,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as int?,
        content: m['content'] as String,
        isUser: (m['is_user'] as int) == 1,
        timestamp: m['timestamp'] as String,
        sessionId: m['session_id'] as int,
      );

  Map<String, dynamic> toJson() => {
        'content': content,
        'isUser': isUser,
        'timestamp': timestamp,
      };
}

// ============================================================
// SESSION
// ============================================================

class ChatSession {
  final int? id;
  final String title;
  final String createdAt;

  ChatSession({
    this.id,
    required this.title,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id!,
        'title': title,
        'created_at': createdAt,
      };

  factory ChatSession.fromMap(Map<String, dynamic> m) => ChatSession(
        id: m['id'] as int?,
        title: m['title'] as String,
        createdAt: m['created_at'] as String,
      );
}

// ============================================================
// DATABASE HELPER
// ============================================================

class OkoDatabase {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'oko.db');
    return await openDatabase(path, version: 2,
      onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL DEFAULT ''
        )
      ''');
      await db.execute('''
        CREATE TABLE messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          content TEXT NOT NULL,
          is_user INTEGER NOT NULL DEFAULT 0,
          timestamp TEXT NOT NULL DEFAULT '',
          session_id INTEGER NOT NULL,
          FOREIGN KEY (session_id) REFERENCES sessions(id)
        )
      ''');
      await db.execute('''
        CREATE TABLE system_config (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL DEFAULT ''
        )
      ''');
    },
      onUpgrade: (db, oldVer, newVer) async {
        if (oldVer < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS system_config (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL DEFAULT ''
            )
          ''');
        }
      });
  }

  static Future<int> createSession(String title) async {
    final d = await db;
    return await d.insert('sessions', {
      'title': title,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<ChatSession>> getSessions() async {
    final d = await db;
    final maps = await d.query('sessions', orderBy: 'id DESC');
    return maps.map(ChatSession.fromMap).toList();
  }

  static Future<int> addMessage(ChatMessage msg) async {
    final d = await db;
    return await d.insert('messages', msg.toMap());
  }

  static Future<List<ChatMessage>> getMessages(int sessionId) async {
    final d = await db;
    final maps = await d.query('messages',
        where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'id ASC');
    return maps.map(ChatMessage.fromMap).toList();
  }

  // ===== LICENSE MANAGEMENT =====
  static Future<String?> getConfig(String key) async {
    final d = await db;
    final results = await d.query('system_config',
        where: 'key = ?', whereArgs: [key]);
    return results.isEmpty ? null : results.first['value'] as String?;
  }

  static Future<void> setConfig(String key, String value) async {
    final d = await db;
    await d.insert('system_config',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<DateTime?> getFirstLaunchTime() async {
    final raw = await getConfig('first_launch_time');
    if (raw == null) {
      final now = DateTime.now().toUtc().toIso8601String();
      await setConfig('first_launch_time', now);
      return DateTime.now().toUtc();
    }
    return DateTime.tryParse(raw);
  }

  static Future<void> saveLicenseKey(String key) async {
    await setConfig('license_key', key);
  }

  static Future<String?> getLicenseKey() async {
    return getConfig('license_key');
  }

  static Future<void> deleteSession(int sessionId) async {
    final d = await db;
    await d.delete('messages', where: 'session_id = ?', whereArgs: [sessionId]);
    await d.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
  }
}

// ============================================================
// AUTO-UPDATE CHECKER
// ============================================================

class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;

  UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

/// Compare semver strings. Returns true if remote > local.
bool _isNewerVersion(String remote, String local) {
  final r = remote.replaceFirst('v', '').split('.').map(int.parse).toList();
  final l = local.replaceFirst('v', '').split('.').map(int.parse).toList();
  for (int i = 0; i < 3; i++) {
    if ((i < r.length ? r[i] : 0) > (i < l.length ? l[i] : 0)) return true;
    if ((i < r.length ? r[i] : 0) < (i < l.length ? l[i] : 0)) return false;
  }
  return false;
}

Future<UpdateInfo?> checkForUpdate() async {
  try {
    final url = Uri.parse(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest');
    final response = await http.get(url, headers: {
      'Accept': 'application/vnd.github+json',
    }).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    final tag = data['tag_name'] as String? ?? '';
    if (!_isNewerVersion(tag, _currentVersion)) return null;

    // Find the macOS zip asset
    String downloadUrl = '';
    for (final asset in (data['assets'] as List)) {
      final name = (asset['name'] as String?) ?? '';
      if (name.contains('macOS') && name.endsWith('.zip')) {
        downloadUrl = asset['browser_download_url'] as String? ?? '';
        break;
      }
    }

    return UpdateInfo(
      latestVersion: tag,
      downloadUrl: downloadUrl,
      releaseNotes: (data['body'] as String?) ?? '',
    );
  } catch (_) {
    return null;
  }
}

// ============================================================
// MAIN CHAT PAGE
// ============================================================

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  List<ChatSession> _sessions = [];
  int _currentSessionId = -1;
  bool _isLoading = false;
  String _selectedModel = 'qwen2.5:3b';
  bool _backendConnected = false;
  // ===== LICENSE STATE MACHINE =====
  // STATUS_STANDARD: Free tier, Pro features sleep
  // STATUS_PRO_TRIAL: 21-day full access, no card needed
  // STATUS_PRO_LICENSE: Permanently unlocked via license key
  String _licenseStatus = 'STATUS_STANDARD';
  DateTime? _firstLaunchTime;
  String _licenseKey = '';
  static const int _trialDays = 21;

  bool get _isPro {
    return _licenseStatus == 'STATUS_PRO_TRIAL' ||
           _licenseStatus == 'STATUS_PRO_LICENSE';
  }

  int get _trialDaysRemaining {
    if (_firstLaunchTime == null) return 0;
    final remaining = _trialDays -
        DateTime.now().difference(_firstLaunchTime!).inDays;
    return remaining.clamp(0, _trialDays);
  }

  bool get _isTrialActive {
    return _licenseStatus == 'STATUS_PRO_TRIAL' && _trialDaysRemaining > 0;
  }
  bool _ollamaRunning = false;

  // Settings
  double _fontSize = 15.0;
  ThemeMode _themeMode = ThemeMode.dark;
  bool _showSidebar = false;

  // Privacy permissions
  bool _permMessages = false;
  bool _permGmail = false;
  bool _permFiles = false;
  bool _permCamera = false;
  bool _permContacts = false;
  bool _permCalendar = false;
  bool _permClipboard = true;
  bool _permTerminal = false;
  bool _permBrowser = false;

  // Language & username
  String _language = 'en';
  String _username = 'User';

  // Drag & drop state
  bool _isDragOver = false;

  // Task progress card state
  bool _showTaskCard = false;
  String _taskTitle = '';
  List<_TaskStep> _taskSteps = [];

  // System prompt (Pro customizable)
  String _systemPrompt = 'You are Oko, a privacy-first local AI assistant. Help the user with any task.';
  final _systemPromptController = TextEditingController();

  // All available models
  static const List<Map<String, String>> _allModels = [
    {'id': 'qwen2.5:3b', 'name': 'qwen2.5:3b', 'tier': 'free'},
    {'id': 'qwen2.5:7b', 'name': 'qwen2.5:7b', 'tier': 'pro'},
    {'id': 'llama3.2:3b', 'name': 'llama3.2:3b', 'tier': 'pro'},
    {'id': 'mistral:7b', 'name': 'mistral:7b', 'tier': 'pro'},
    {'id': 'gemma2:9b', 'name': 'gemma2:9b', 'tier': 'pro'},
    {'id': 'qwen2.5:14b', 'name': 'qwen2.5:14b', 'tier': 'pro'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadSessions();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // ===== LICENSE STATE MACHINE INIT =====
    await _initLicenseState();

    setState(() {
      _selectedModel = prefs.getString('selected_model') ?? 'qwen2.5:3b';
      _fontSize = prefs.getDouble('font_size') ?? 15.0;
      final tm = prefs.getInt('theme_mode') ?? 0;
      _themeMode = ThemeMode.values[tm];
      _language = prefs.getString('language') ?? 'en';
      _username = prefs.getString('username') ?? 'User';
      _permMessages = prefs.getBool('perm_messages') ?? false;
      _permGmail = prefs.getBool('perm_gmail') ?? false;
      _permFiles = prefs.getBool('perm_files') ?? false;
      _permCamera = prefs.getBool('perm_camera') ?? false;
      _permContacts = prefs.getBool('perm_contacts') ?? false;
      _permCalendar = prefs.getBool('perm_calendar') ?? false;
      _permClipboard = prefs.getBool('perm_clipboard') ?? true;
      _permTerminal = prefs.getBool('perm_terminal') ?? false;
      _permBrowser = prefs.getBool('perm_browser') ?? false;
      _systemPrompt = prefs.getString('system_prompt') ??
          'You are Oko, a privacy-first local AI assistant. Help the user with any task.';
      _systemPromptController.text = _systemPrompt;
    });
  }

  /// Core license state machine — pure local, zero network dependency
  Future<void> _initLicenseState() async {
    final db = await OkoDatabase.db;

    // 1. Check for existing license key
    final savedKey = await OkoDatabase.getLicenseKey();
    if (savedKey != null && savedKey.isNotEmpty) {
      // Validate key format: OKO-XXXX-XXXX-XXXX (16 hex chars)
      if (_isValidLicenseKey(savedKey)) {
        setState(() {
          _licenseStatus = 'STATUS_PRO_LICENSE';
          _licenseKey = savedKey;
        });
        return;
      }
    }

    // 2. No valid license — check trial
    final firstLaunch = await OkoDatabase.getFirstLaunchTime();
    setState(() => _firstLaunchTime = firstLaunch);

    if (firstLaunch != null) {
      final daysUsed = DateTime.now().toUtc().difference(firstLaunch).inDays;
      if (daysUsed <= _trialDays) {
        setState(() => _licenseStatus = 'STATUS_PRO_TRIAL');
        return;
      }
    }

    // 3. Trial expired, no license → Standard
    setState(() => _licenseStatus = 'STATUS_STANDARD');
  }

  /// License key validation: OKO-XXXX-XXXX-XXXX (case-insensitive hex)
  bool _isValidLicenseKey(String key) {
    final normalized = key.trim().toUpperCase();
    if (!RegExp(r'^OKO-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}$').hasMatch(normalized)) {
      return false;
    }
    // Simple checksum: last char of each group XOR must equal 0x5
    final groups = normalized.replaceAll('OKO-', '').split('-');
    if (groups.length != 3) return false;
    int checksum = 0;
    for (final g in groups) {
      final lastChar = g.substring(g.length - 1);
      checksum ^= int.parse(lastChar, radix: 16);
    }
    return checksum == 0x5;
  }

  /// Activate a license key
  Future<bool> _activateLicense(String key) async {
    final normalized = key.trim().toUpperCase();
    if (!_isValidLicenseKey(normalized)) return false;

    await OkoDatabase.saveLicenseKey(normalized);
    setState(() {
      _licenseStatus = 'STATUS_PRO_LICENSE';
      _licenseKey = normalized;
    });
    // Migrate away from legacy SharedPreferences flag
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_pro');
    return true;
  }

  Future<void> _loadSessions() async {
    final sessions = await OkoDatabase.getSessions();
    setState(() => _sessions = sessions);
    if (_currentSessionId < 0 && sessions.isNotEmpty) {
      _switchSession(sessions.first.id!);
    } else if (sessions.isEmpty) {
      _newSession();
    } else {
      _loadMessages(_currentSessionId);
    }
    // Auto-start services
    await _autoStartAll();
    _checkBackend();
    _checkOllama();
    // Check for updates (non-blocking)
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final update = await checkForUpdate();
    if (update == null || !mounted) return;

    // Don't remind more than once per version
    final prefs = await SharedPreferences.getInstance();
    final skipped = prefs.getString('skipped_version') ?? '';
    if (skipped == update.latestVersion) return;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF00FFD1), width: 1)),
        title: Text('Update Available',
            style: TextStyle(color: const Color(0xFF00FFD1))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Oko ${update.latestVersion} is available (you have v$_currentVersion).',
                style: TextStyle(color: Colors.white70)),
            if (update.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(update.releaseNotes,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              prefs.setString('skipped_version', update.latestVersion);
              Navigator.pop(ctx);
            },
            child: Text('Skip This Version',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _launchUrl(update.downloadUrl);
            },
            child: Text('Download Update',
                style: TextStyle(color: const Color(0xFF00FFD1))),
          ),
        ],
      ),
    );
  }

  void _launchUrl(String url) async {
    if (url.isEmpty) return;
    try {
      await Process.run('open', [url]);
    } catch (_) {}
  }

  Future<void> _newSession() async {
    final id = await OkoDatabase.createSession(
        'New Chat ${DateTime.now().hour}:${DateTime.now().minute}');
    final sessions = await OkoDatabase.getSessions();
    setState(() {
      _sessions = sessions;
      _currentSessionId = id;
      _messages.clear();
    });
  }

  Future<void> _switchSession(int sessionId) async {
    setState(() => _currentSessionId = sessionId);
    await _loadMessages(sessionId);
  }

  Future<void> _loadMessages(int sessionId) async {
    final msgs = await OkoDatabase.getMessages(sessionId);
    setState(() => _messages = msgs);
  }

  /// Auto-start Ollama and backend
  Future<void> _autoStartAll() async {
    await _autoStartOllama();
    await Future.delayed(const Duration(seconds: 2));
    await _autoStartBackend();
  }

  Future<bool> _isPortOpen(int port) async {
    try {
      final socket = await Socket.connect('localhost', port,
          timeout: const Duration(seconds: 1));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _autoStartOllama() async {
    if (await _isPortOpen(11434)) {
      setState(() => _ollamaRunning = true);
      return;
    }
    final ollamaPaths = [
      '/usr/local/bin/ollama',
      '/opt/homebrew/bin/ollama',
      '/usr/bin/ollama',
    ];
    String? ollamaPath;
    for (final path in ollamaPaths) {
      if (await File(path).exists()) {
        ollamaPath = path;
        break;
      }
    }
    if (ollamaPath == null) return;
    try {
      final proc = await Process.start(ollamaPath, ['serve']);
      proc.stdout.listen((_) {});
      proc.stderr.listen((_) {});
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (await _isPortOpen(11434)) {
          setState(() => _ollamaRunning = true);
          return;
        }
      }
      setState(() => _ollamaRunning = true);
    } catch (_) {}
  }

  Future<void> _autoStartBackend() async {
    if (await _isPortOpen(8000)) return;
    try {
      final executable = Platform.resolvedExecutable;
      final bundleDir = File(executable).parent.path;
      final backendPath = '$bundleDir/oko_backend';
      if (await File(backendPath).exists()) {
        final proc = await Process.start(backendPath, []);
        proc.stdout.listen((_) {});
        proc.stderr.listen((_) {});
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(seconds: 1));
          if (await _isPortOpen(8000)) return;
        }
      }
    } catch (_) {}
  }

  Future<void> _checkBackend() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:8000/health'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        setState(() => _backendConnected = true);
      }
    } catch (_) {
      setState(() => _backendConnected = false);
    }
  }

  Future<void> _checkOllama() async {
    final running = await _isPortOpen(11434);
    setState(() => _ollamaRunning = running);
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();
    final now = DateTime.now().toIso8601String();
    final userMsg = ChatMessage(
      content: text,
      isUser: true,
      timestamp: now,
      sessionId: _currentSessionId,
    );
    await OkoDatabase.addMessage(userMsg);
    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final history = _messages
          .where((m) => !m.isUser || m.content != text)
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList();

      final response = await http
          .post(
            Uri.parse('http://localhost:8000/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': text,
              'model': _selectedModel,
              'history': history,
              'system_prompt': _systemPrompt,
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final assistantMsg = ChatMessage(
          content: data['response'] ?? 'No response',
          isUser: false,
          timestamp: data['timestamp'] ?? DateTime.now().toIso8601String(),
          sessionId: _currentSessionId,
        );
        await OkoDatabase.addMessage(assistantMsg);
        setState(() => _messages.add(assistantMsg));

        // Auto-update session title from first user message
        if (_messages.where((m) => m.isUser).length <= 1) {
          final shortTitle =
              text.length > 30 ? '${text.substring(0, 30)}...' : text;
          final d = await OkoDatabase.db;
          await d.update('sessions', {'title': shortTitle},
              where: 'id = ?', whereArgs: [_currentSessionId]);
          _loadSessions();
        }
      } else {
        final errMsg = ChatMessage(
          content: 'Error: ${response.statusCode}',
          isUser: false,
          timestamp: DateTime.now().toIso8601String(),
          sessionId: _currentSessionId,
        );
        await OkoDatabase.addMessage(errMsg);
        setState(() => _messages.add(errMsg));
      }
    } catch (_) {
      final errMsg = ChatMessage(
        content: 'Cannot connect to Oko backend. Is it running?',
        isUser: false,
        timestamp: DateTime.now().toIso8601String(),
        sessionId: _currentSessionId,
      );
      await OkoDatabase.addMessage(errMsg);
      setState(() => _messages.add(errMsg));
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _clearCurrentChat() async {
    final d = await OkoDatabase.db;
    await d.delete('messages',
        where: 'session_id = ?', whereArgs: [_currentSessionId]);
    setState(() => _messages.clear());
  }

  void _deleteSession(int sessionId) async {
    await OkoDatabase.deleteSession(sessionId);
    _loadSessions();
    if (_currentSessionId == sessionId && _sessions.isNotEmpty) {
      _switchSession(_sessions.first.id!);
    } else if (_sessions.isEmpty) {
      _newSession();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color get _bgColor =>
      _themeMode == ThemeMode.dark
          ? const Color(0xFF070B18)
          : const Color(0xFFF0F4FA);
  Color get _surfaceColor =>
      _themeMode == ThemeMode.dark ? const Color(0xFF0D1225) : Colors.white;
  Color get _inputBgColor =>
      _themeMode == ThemeMode.dark
          ? const Color(0xFF0A0E1A)
          : const Color(0xFFE8ECF0);
  Color get _borderColor =>
      _themeMode == ThemeMode.dark
          ? const Color(0xFF1A1F36)
          : const Color(0xFFD0D5DD);
  Color get _textColor =>
      _themeMode == ThemeMode.dark ? Colors.white : const Color(0xFF111827);
  Color get _textSecondaryColor =>
      _themeMode == ThemeMode.dark ? Colors.white54 : const Color(0xFF6B7280);
  Color get _hintTextColor =>
      _themeMode == ThemeMode.dark ? Colors.white38 : const Color(0xFF9CA3AF);

  ui.ImageFilter get _uiBlur => ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _themeMode == ThemeMode.dark ? _darkTheme : _lightTheme,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: _buildAppBar(),
        body: Stack(children: [
          if (_themeMode == ThemeMode.dark) _buildAuroraBackground(),
          _buildDropTarget(
            Column(children: [
              if (_showTaskCard) _buildTaskCard(),
              Expanded(child: _buildChatArea()),
              _buildInputArea(),
            ]),
          ),
          if (_showSidebar) _buildSidebar(),
        ]),
      ),
    );
  }


  /// Renders a gray 'sleep mode' card when Pro feature is triggered on Standard
  Widget _buildProSleepCard(String featureName) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bedtime, color: const Color(0xFF6B7280), size: 20),
          const SizedBox(width: 10),
          Text(featureName, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        const Text(
          'This feature is in sleep mode on Standard Core.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F4C75).withOpacity(0.5),
              foregroundColor: const Color(0xFF9CA3AF),
              elevation: 0,
            ),
            onPressed: () => _showProUpgradeDialog(context),
            child: const Text('Enter License Key to Wake', style: TextStyle(fontSize: 12)),
          ),
        ),
      ]),
    );
  }

  /// Trigger a Pro feature — returns true if feature should proceed
  bool _canUseProFeature(String featureName) {
    if (_isPro) return true;
    // Show sleep card instead of error
    setState(() {
      _messages.add(ChatMessage(
        content: 'PRO_SLEEP:$featureName',
        isUser: false,
        timestamp: DateTime.now().toIso8601String(),
        sessionId: _currentSessionId,
      ));
    });
    return false;
  }

  Future<void> _pickFile() async {
    if (!_isPro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('File parsing requires Pro'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Drop a PDF or image file onto the chat to parse it'),
        backgroundColor: const Color(0xFF0F4C75),
      ));
    }
  }

  Future<void> _handleDroppedFile(String filePath) async {
    if (!_canUseProFeature('File Parsing')) {
      _scrollToBottom();
      return;
    }
    final fileName = filePath.split('/').last;
    final userMsg = ChatMessage(
      content: '[File: $fileName] - Parsing...',
      isUser: true,
      timestamp: DateTime.now().toIso8601String(),
      sessionId: _currentSessionId,
    );
    await OkoDatabase.addMessage(userMsg);
    setState(() {
      _messages.add(userMsg);
      _showTaskCard = true;
      _taskTitle = 'Parsing $fileName';
      _taskSteps = [
        _TaskStep('Reading file', _TaskStatus.running),
        _TaskStep('Extracting content (OCR)', _TaskStatus.pending),
        _TaskStep('Analyzing data', _TaskStatus.pending),
      ];
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/api/parse-file'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'file_path': filePath, 'model': _selectedModel}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _taskSteps[0].status = _TaskStatus.done;
          _taskSteps[1].status = _TaskStatus.done;
          _taskSteps[2].status = _TaskStatus.done;
        });
        final assistantMsg = ChatMessage(
          content: data['response'] ?? 'File parsed successfully',
          isUser: false,
          timestamp: DateTime.now().toIso8601String(),
          sessionId: _currentSessionId,
        );
        await OkoDatabase.addMessage(assistantMsg);
        setState(() => _messages.add(assistantMsg));
      } else {
        throw Exception('Parse failed');
      }
    } catch (e) {
      setState(() {
        _taskSteps[0].status = _TaskStatus.done;
        _taskSteps[1].status = _TaskStatus.done;
        _taskSteps[2].status = _TaskStatus.done;
      });
      final errMsg = ChatMessage(
        content: 'Could not parse file. Backend /api/parse-file endpoint not available yet.',
        isUser: false,
        timestamp: DateTime.now().toIso8601String(),
        sessionId: _currentSessionId,
      );
      await OkoDatabase.addMessage(errMsg);
      setState(() => _messages.add(errMsg));
    }
    _scrollToBottom();
  }

  Widget _buildDropTarget(Widget child) {
    return DropTarget(
      onDragEntered: (details) => setState(() => _isDragOver = true),
      onDragExited: (details) => setState(() => _isDragOver = false),
      onDragDone: (details) {
        setState(() => _isDragOver = false);
        for (final file in details.files) {
          _handleDroppedFile(file.path);
          break; // Process first file only
        }
      },
      child: Stack(children: [
        child,
        if (_isDragOver)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF00FFD1).withOpacity(0.05),
                  border: Border.all(color: const Color(0xFF00FFD1).withOpacity(0.4), width: 3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: _surfaceColor.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00FFD1), width: 1),
                      boxShadow: [BoxShadow(color: const Color(0xFF00FFD1).withOpacity(0.2), blurRadius: 20)],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.upload_file, color: const Color(0xFF00FFD1), size: 28),
                      const SizedBox(width: 12),
                      Text('Drop file to parse', style: TextStyle(color: const Color(0xFF00FFD1), fontSize: 16, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.menu, color: const Color(0xFF00FFD1)),
        onPressed: () => setState(() => _showSidebar = !_showSidebar),
      ),
      title: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0F4C75), Color(0xFF00FFD1)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: const Color(0xFF00FFD1).withOpacity(0.3), blurRadius: 12)],
            ),
            child: Center(child: Text('O', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
          ),
          const SizedBox(width: 8),
          Text('Oko', style: TextStyle(color: const Color(0xFF00FFD1), fontSize: 20, fontWeight: FontWeight.bold)),
          if (_isPro) ...[
            const SizedBox(width: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.amber, Colors.orange]), borderRadius: BorderRadius.circular(6)),
              child: Text('PRO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
          const Spacer(),
          Container(width: 7, height: 7, decoration: BoxDecoration(color: _backendConnected ? Colors.green : Colors.red, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(_backendConnected ? 'Connected' : 'Offline', style: TextStyle(color: _backendConnected ? Colors.green : Colors.red, fontSize: 11)),
          const SizedBox(width: 6),
          IconButton(icon: Icon(Icons.delete_outline, color: _textSecondaryColor.withOpacity(0.5), size: 18), onPressed: _messages.isEmpty ? null : _clearCurrentChat),
          IconButton(icon: Icon(Icons.settings, color: const Color(0xFF00FFD1)), onPressed: () => _showSettings()),
        ],
      ),
    );
  }

  Widget _buildAuroraBackground() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.3 + (DateTime.now().millisecond % 10000) / 10000 * 0.6, -0.2 + (DateTime.now().second % 8) / 8 * 0.4),
              radius: 0.9,
              colors: [
                const Color(0xFF0F4C75).withOpacity(0.10),
                const Color(0xFF00FFD1).withOpacity(0.05),
                const Color(0xFF7B2FF7).withOpacity(0.07),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3, 0.6, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceColor.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00FFD1).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(Icons.auto_awesome, color: const Color(0xFF00FFD1), size: 16),
            const SizedBox(width: 8),
            Text(_taskTitle, style: TextStyle(color: _textColor, fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(onTap: () => setState(() => _showTaskCard = false), child: Icon(Icons.close, color: _textSecondaryColor, size: 16)),
          ]),
          const SizedBox(height: 10),
          ..._taskSteps.map((step) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              if (step.status == _TaskStatus.done)
                Icon(Icons.check_circle, color: const Color(0xFF00FFD1), size: 16)
              else if (step.status == _TaskStatus.running)
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: const Color(0xFF00FFD1), strokeWidth: 2))
              else
                Icon(Icons.circle_outlined, color: _textSecondaryColor, size: 16),
              const SizedBox(width: 10),
              Text(step.label, style: TextStyle(color: step.status == _TaskStatus.pending ? _textSecondaryColor : _textColor, fontSize: 12)),
            ]),
          )),
        ],
      ),
    );
  }



  Widget _buildChatArea() {
    if (_messages.isEmpty)
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF0F4C75), Color(0xFF00FFD1)]),
                    borderRadius: BorderRadius.circular(36)),
                child: Center(
                    child: Text('O',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold)))),
            const SizedBox(height: 16),
            Text('Ask me anything -- I am fully local and private',
                style: TextStyle(
                    color: const Color(0xFF00FFD1), fontSize: _fontSize + 3)),
            const SizedBox(height: 6),
            Text('Privacy-first AI agent with computer control',
                style: TextStyle(color: _hintTextColor, fontSize: _fontSize - 1)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: _ollamaRunning ? Colors.green : Colors.orange,
                      shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(
                  _ollamaRunning ? 'Ollama Ready' : 'Ollama Starting...',
                  style: TextStyle(
                      color: _ollamaRunning ? Colors.green : Colors.orange,
                      fontSize: 11)),
            ]),
          ]));

    return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _messages.length) return _buildTypingIndicator();
          final msg = _messages[index];
          if (!msg.isUser && _looksLikeTable(msg.content)) return _buildTablePreview(msg);
          return _buildMessageBubble(msg);
        });
  }

  bool _looksLikeTable(String content) {
    final lines = content.split('\n');
    int tableLines = 0;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.contains('|') || trimmed.split(',').length >= 3) tableLines++;
    }
    return tableLines >= 2;
  }

  Widget _buildTablePreview(ChatMessage msg) {
    final lines = msg.content.split('\n');
    final rows = <List<String>>[];
    for (final line in lines) {
      final t = line.trim();
      if (t.contains('|')) {
        rows.add(t.split('|').map((c) => c.trim()).toList());
      } else if (t.split(',').length >= 3) {
        rows.add(t.split(',').map((c) => c.trim()).toList());
      }
    }
    if (rows.length < 2) return _buildMessageBubble(msg);
    final display = rows.take(6).toList();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: _surfaceColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF00FFD1).withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFF0F4C75).withOpacity(0.4), const Color(0xFF00FFD1).withOpacity(0.2)]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                Icon(Icons.table_chart, color: const Color(0xFF00FFD1), size: 16),
                const SizedBox(width: 8),
                Text('Data Preview', style: TextStyle(color: const Color(0xFF00FFD1), fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Table(
                columnWidths: {for (int i = 0; i < display[0].length; i++) i: const IntrinsicColumnWidth()},
                border: TableBorder(horizontalInside: BorderSide(color: _borderColor, width: 0.5)),
                children: display.asMap().entries.map((entry) {
                  final isH = entry.key == 0;
                  return TableRow(
                    decoration: isH ? BoxDecoration(color: const Color(0xFF00FFD1).withOpacity(0.06)) : null,
                    children: entry.value.map((cell) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(cell, style: TextStyle(color: isH ? const Color(0xFF00FFD1) : _textColor, fontSize: 11, fontWeight: isH ? FontWeight.w600 : FontWeight.normal)),
                    )).toList(),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.open_in_new, size: 16),
                  label: Text('Open Full Table'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFD1), foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    // Render Pro sleep card for special sleep messages
    if (msg.content.startsWith('PRO_SLEEP:')) {
      final feature = msg.content.replaceFirst('PRO_SLEEP:', '');
      final featureLabels = {
        'Vision Pipeline': 'Multimodal Vision Pipeline',
        'Smart Data Mapping': 'Smart Data Mapping',
        'System Capture': 'System-Level Silent Capture',
        'File Parsing': 'Drag & Drop File Parsing',
      };
      return _buildProSleepCard(featureLabels[feature] ?? feature);
    }
    return Align(
        alignment:
            msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
                gradient: msg.isUser
                    ? const LinearGradient(
                        colors: [Color(0xFF0F4C75), Color(0xFF0F4C75)])
                    : LinearGradient(
                        colors: [_surfaceColor, _surfaceColor]),
                borderRadius: BorderRadius.circular(18),
                border: msg.isUser
                    ? null
                    : Border.all(
                        color: const Color(0xFF00FFD1).withOpacity(0.2))),
            child: Text(msg.content,
                style: TextStyle(
                    color: msg.isUser
                        ? Colors.white
                        : _textColor.withOpacity(0.9),
                    fontSize: _fontSize))));
  }

  Widget _buildTypingIndicator() {
    return Align(
        alignment: Alignment.centerLeft,
        child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: const Color(0xFF00FFD1).withOpacity(0.2))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _dot(),
              const SizedBox(width: 4),
              _dot(),
              const SizedBox(width: 4),
              _dot()
            ])));
  }

  Widget _dot() {
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.3, end: 1.0),
        duration: const Duration(milliseconds: 600),
        builder: (context, value, _) => Opacity(
            opacity: value,
            child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: const Color(0xFF00FFD1),
                    borderRadius: BorderRadius.circular(4)))));
  }

  Widget _buildInputArea() {
    return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: _surfaceColor,
            border: Border(top: BorderSide(color: _borderColor))),
        child: Row(children: [
          Expanded(
              child: TextField(
                  controller: _controller,
                  style: TextStyle(color: _textColor, fontSize: _fontSize),
                  decoration: InputDecoration(
                      hintText:
                          'Ask oko anything... or type a command like "open Safari"',
                      hintStyle:
                          TextStyle(color: _hintTextColor, fontSize: _fontSize),
                      filled: true,
                      fillColor: _inputBgColor,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12)),
                  onSubmitted: (_) => _sendMessage())),
          const SizedBox(width: 8),
          Container(
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF0F4C75), Color(0xFF00FFD1)]),
                  borderRadius: BorderRadius.circular(28)),
              child: IconButton(
                  icon: _isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Icon(Icons.send, color: Colors.white),
                  onPressed: _isLoading ? null : _sendMessage)),
        ]));
  }

  // ==================== SIDEBAR ====================

  Widget _buildSidebar() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showSidebar = false),
        child: Container(
          color: Colors.black54,
          child: Align(
            alignment: Alignment.centerLeft,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
              child: BackdropFilter(
                filter: _uiBlur,
                child: Container(
                  width: 280,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: _surfaceColor.withOpacity(0.75),
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                    border: Border.all(color: const Color(0xFF00FFD1).withOpacity(0.12)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30)],
                  ),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Text('Chats', style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline, color: const Color(0xFF00FFD1)),
                          onPressed: () { _newSession(); setState(() => _showSidebar = false); },
                        ),
                      ]),
                    ),
                    Divider(color: _borderColor, height: 1),
                    Expanded(
                      child: _sessions.isEmpty
                          ? Center(child: Text('No chats yet', style: TextStyle(color: _textSecondaryColor)))
                          : ListView.builder(
                              itemCount: _sessions.length,
                              itemBuilder: (ctx, idx) {
                                final s = _sessions[idx];
                                final isActive = s.id == _currentSessionId;
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: isActive
                                      ? BoxDecoration(
                                          gradient: LinearGradient(colors: [const Color(0xFF00FFD1).withOpacity(0.12), const Color(0xFF0F4C75).withOpacity(0.08)]),
                                          borderRadius: BorderRadius.circular(12),
                                        )
                                      : null,
                                  child: ListTile(
                                    dense: true,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    selected: isActive,
                                    selectedTileColor: Colors.transparent,
                                    leading: Icon(Icons.chat_bubble_outline, size: 18, color: isActive ? const Color(0xFF00FFD1) : _textSecondaryColor),
                                    title: Text(s.title, style: TextStyle(color: _textColor, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    subtitle: Text(s.createdAt.substring(0, 16), style: TextStyle(color: _textSecondaryColor, fontSize: 10)),
                                    trailing: IconButton(icon: Icon(Icons.close, size: 14, color: _textSecondaryColor.withOpacity(0.5)), onPressed: () => _deleteSession(s.id!)),
                                    onTap: () { _switchSession(s.id!); setState(() => _showSidebar = false); },
                                  ),
                                );
                              }),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  // ==================== SETTINGS ====================

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: _surfaceColor.withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: const Color(0xFF00FFD1).withOpacity(0.1)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: _uiBlur,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _textSecondaryColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    Row(children: [
                      Icon(Icons.tune, color: const Color(0xFF00FFD1), size: 22),
                      const SizedBox(width: 10),
                      Text('Settings', style: TextStyle(color: _textColor, fontSize: 22, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 20),

                    // Profile
                    _sCard('Profile', Icons.person, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(children: [
                          Icon(Icons.badge, size: 18, color: _textSecondaryColor),
                          const SizedBox(width: 12),
                          Text('Username', style: TextStyle(color: _textColor, fontSize: 14)),
                          const Spacer(),
                          SizedBox(width: 150, child: TextField(
                            textAlign: TextAlign.end,
                            style: TextStyle(color: const Color(0xFF00FFD1), fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Enter name',
                              hintStyle: TextStyle(color: _hintTextColor, fontSize: 13),
                              border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true,
                            ),
                            controller: TextEditingController(text: _username),
                            onChanged: (v) async { setState(() => _username = v); final p = await SharedPreferences.getInstance(); await p.setString('username', v); },
                          )),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Language
                    _sCard('Language', Icons.translate, children: [
                      ...['en', 'zh', 'es'].map((lang) {
                        final labels = {'en': 'English', 'zh': '中文', 'es': 'Español'};
                        final flags = {'en': '🇺🇸', 'zh': '🇨🇳', 'es': '🇪🇸'};
                        final sel = _language == lang;
                        return _sRow(label: '${flags[lang]}  ${labels[lang]}',
                          trailing: sel ? Icon(Icons.check_circle, color: const Color(0xFF00FFD1), size: 20) : const SizedBox(width: 20),
                          selected: sel,
                          onTap: () async { setState(() => _language = lang); setModalState(() {}); final p = await SharedPreferences.getInstance(); await p.setString('language', lang); },
                        );
                      }),
                    ]),
                    const SizedBox(height: 16),

                    // Privacy & Permissions
                    _sCard('Privacy & Permissions', Icons.shield, children: [
                      _permSwitch('Messages (SMS/iMessage)', Icons.message, _permMessages, (v) => setState(() => _permMessages = v), 'perm_messages'),
                      _permSwitch('Gmail Access', Icons.email, _permGmail, (v) => setState(() => _permGmail = v), 'perm_gmail'),
                      _permSwitch('File System', Icons.folder_open, _permFiles, (v) => setState(() => _permFiles = v), 'perm_files'),
                      _permSwitch('Camera', Icons.camera_alt, _permCamera, (v) => setState(() => _permCamera = v), 'perm_camera'),
                      _permSwitch('Contacts', Icons.contacts, _permContacts, (v) => setState(() => _permContacts = v), 'perm_contacts'),
                      _permSwitch('Calendar', Icons.calendar_today, _permCalendar, (v) => setState(() => _permCalendar = v), 'perm_calendar'),
                      _permSwitch('Clipboard', Icons.content_paste, _permClipboard, (v) => setState(() => _permClipboard = v), 'perm_clipboard'),
                      _permSwitch('Terminal Access', Icons.terminal, _permTerminal, (v) => setState(() => _permTerminal = v), 'perm_terminal'),
                      _permSwitch('Browser Control', Icons.language, _permBrowser, (v) => setState(() => _permBrowser = v), 'perm_browser'),
                    ]),
                    const SizedBox(height: 16),

                    // General
                    _sCard('General', Icons.tune, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(children: [
                          Icon(Icons.text_fields, size: 18, color: _textSecondaryColor),
                          const SizedBox(width: 12),
                          Text('Font Size', style: TextStyle(color: _textColor, fontSize: 14)),
                          const Spacer(),
                          Text('${_fontSize.toInt()}px', style: TextStyle(color: const Color(0xFF00FFD1), fontSize: 13)),
                        ]),
                      ),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Slider(
                        value: _fontSize, min: 12, max: 22, divisions: 10,
                        activeColor: const Color(0xFF00FFD1),
                        onChanged: _isPro ? (v) async {
                          setModalState(() => _fontSize = v);
                          setState(() => _fontSize = v);
                          final p = await SharedPreferences.getInstance();
                          await p.setDouble('font_size', v);
                        } : null,
                      )),
                      if (!_isPro) Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('Upgrade to Pro to customize font size', style: TextStyle(color: Colors.amber.withOpacity(0.8), fontSize: 11))),
                      const SizedBox(height: 8),
                      ...[ThemeMode.dark, ThemeMode.light, ThemeMode.system].map((tm) {
                        final labels = {ThemeMode.dark: 'Dark', ThemeMode.light: 'Light', ThemeMode.system: 'System'};
                        final icons = {ThemeMode.dark: Icons.dark_mode, ThemeMode.light: Icons.light_mode, ThemeMode.system: Icons.settings_brightness};
                        return _sRow(label: labels[tm] ?? '', icon: icons[tm],
                          trailing: _themeMode == tm ? Icon(Icons.check, color: const Color(0xFF00FFD1), size: 18) : const SizedBox(width: 18),
                          selected: _themeMode == tm,
                          onTap: () async { setModalState(() {}); setState(() => _themeMode = tm); final p = await SharedPreferences.getInstance(); await p.setInt('theme_mode', tm.index); },
                        );
                      }),
                    ]),
                    const SizedBox(height: 16),

                    // Pro
                    if (!_isPro) _sCard('Pro', Icons.workspace_premium, children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.amber.withOpacity(0.15), Colors.orange.withOpacity(0.1)]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Column(children: [
                          Text('A: Multimodal Vision Pipeline — parse handwritten receipts & invoices.\nB: Smart Data Mapping — custom Excel templates with auto-append.\nC: System Capture — global hotkey silent screen grab + automation.\nChain Agent + Incremental DB + AI Playground + Drag & Drop.', style: TextStyle(color: _textSecondaryColor, fontSize: 11)),
                          const SizedBox(height: 10),
                          SizedBox(width: double.infinity, child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            onPressed: () => _showProUpgradeDialog(context),
                            child: Text('Upgrade Now'),
                          )),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // AI Playground (Pro)
                    _sCard('AI Playground', Icons.auto_awesome, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(Icons.psychology, size: 18, color: _isPro ? const Color(0xFF00FFD1) : Colors.white24),
                            const SizedBox(width: 12),
                            Text('Custom System Prompt', style: TextStyle(color: _isPro ? _textColor : Colors.white38, fontSize: 14)),
                          ]),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _systemPromptController,
                            enabled: _isPro,
                            maxLines: 3,
                            style: TextStyle(color: _isPro ? _textColor : Colors.white38, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'E.g. "Classify all Uber charges as travel"',
                              hintStyle: TextStyle(color: _hintTextColor, fontSize: 12),
                              filled: true,
                              fillColor: _bgColor,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _borderColor)),
                              contentPadding: const EdgeInsets.all(10),
                            ),
                            onChanged: (v) async {
                              setState(() => _systemPrompt = v);
                              final p = await SharedPreferences.getInstance();
                              await p.setString('system_prompt', v);
                            },
                          ),
                          if (!_isPro) Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('Upgrade to Pro to customize system prompt', style: TextStyle(color: Colors.amber.withOpacity(0.8), fontSize: 11)),
                          ),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Model
                    _sCard('Model', Icons.psychology, children: [
                      ..._allModels.map((model) {
                        final isProModel = model['tier'] == 'pro';
                        final isLocked = isProModel && !_isPro;
                        final isSelected = _selectedModel == model['id'];
                        return _sRow(label: '${model['name']}${isProModel ? '  PRO' : ''}',
                          icon: isLocked ? Icons.lock_outline : Icons.check_circle_outline,
                          iconColor: isSelected ? const Color(0xFF00FFD1) : (isLocked ? Colors.white24 : _textSecondaryColor),
                          trailing: isSelected ? Text('Active', style: TextStyle(color: const Color(0xFF00FFD1), fontSize: 12)) : const SizedBox(width: 40),
                          selected: isSelected,
                          locked: isLocked,
                          onTap: isLocked ? null : () async {
                            final p = await SharedPreferences.getInstance();
                            await p.setString('selected_model', model['id'] ?? '');
                            setState(() => _selectedModel = model['id'] ?? 'qwen2.5:3b');
                            setModalState(() {});
                          },
                        );
                      }),
                    ]),
                    const SizedBox(height: 16),

                    // System
                    _sCard('System', Icons.info_outline, children: [
                      _sRow(label: _backendConnected ? 'Backend Connected' : 'Backend Offline',
                        labelColor: _backendConnected ? Colors.green : Colors.redAccent,
                        icon: _backendConnected ? Icons.cloud_done : Icons.cloud_off,
                        iconColor: _backendConnected ? Colors.green : Colors.red,
                        trailing: TextButton(onPressed: () async { await _checkBackend(); setModalState(() {}); }, child: Text('Reconnect', style: TextStyle(color: const Color(0xFF00FFD1)))),
                      ),
                      _sRow(label: _ollamaRunning ? 'Ollama Running' : 'Ollama Starting...',
                        labelColor: _ollamaRunning ? Colors.green : Colors.orange,
                        icon: _ollamaRunning ? Icons.check_circle : Icons.radio_button_unchecked,
                        iconColor: _ollamaRunning ? Colors.green : Colors.orange,
                        trailing: const SizedBox(width: 40),
                      ),
                      _sRow(label: 'Menu Bar Mode',
                        icon: Icons.minimize,
                        iconColor: _isPro ? const Color(0xFF00FFD1) : Colors.white24,
                        trailing: Switch(
                          value: false,
                          activeColor: const Color(0xFF00FFD1),
                          onChanged: _isPro ? (v) {
                            // Menu bar mode would use system_tray package
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Menu bar mode coming soon'),
                              backgroundColor: const Color(0xFF0F4C75),
                            ));
                          } : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        child: Row(children: [
                          Text('v$_currentVersion', style: TextStyle(color: _textSecondaryColor, fontSize: 12)),
                          const Spacer(),
                          TextButton(onPressed: () async {
                            final update = await checkForUpdate();
                            if (update == null) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You are on the latest version'), backgroundColor: Colors.green));
                            } else { _checkForUpdate(); }
                          }, child: Text('Check for Updates', style: TextStyle(color: const Color(0xFF00FFD1), fontSize: 12))),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sCard(String title, IconData icon, {required List<Widget> children}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: const Color(0xFF00FFD1), size: 16),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: _textSecondaryColor, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      ]),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: _bgColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
        ),
        child: Column(children: children),
      ),
    ]);
  }

  Widget _sRow({required String label, IconData? icon, Color? labelColor, Color? iconColor, Widget? trailing, bool selected = false, bool locked = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: locked ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: selected ? BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF00FFD1).withOpacity(0.06), Colors.transparent]), borderRadius: BorderRadius.circular(12)) : null,
        child: Row(children: [
          if (icon != null) ...[Icon(icon, size: 18, color: iconColor ?? (selected ? const Color(0xFF00FFD1) : _textSecondaryColor)), const SizedBox(width: 12)],
          Expanded(child: Text(label, style: TextStyle(color: labelColor ?? (locked ? Colors.white38 : _textColor), fontSize: 14))),
          if (trailing != null) trailing,
        ]),
      ),
    );
  }

  Widget _permSwitch(String label, IconData icon, bool value, Function(bool) onChange, String key) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: value ? const Color(0xFF00FFD1) : _textSecondaryColor),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: _textColor, fontSize: 14)),
          Text(value ? 'Granted' : 'Denied', style: TextStyle(color: value ? const Color(0xFF00FFD1) : Colors.redAccent.withOpacity(0.8), fontSize: 11)),
        ])),
        Switch(
          value: value,
          activeColor: const Color(0xFF00FFD1),
          inactiveThumbColor: Colors.white38,
          inactiveTrackColor: Colors.white10,
          onChanged: (v) async { onChange(v); final p = await SharedPreferences.getInstance(); await p.setBool(key, v); },
        ),
      ]),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(title,
        style: TextStyle(
            color: _textSecondaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5));
  }

  String _buildSovereignStatusText() {
    final now = DateTime.now().toUtc();
    if (_licenseStatus == 'STATUS_PRO_LICENSE') {
      return 'Local Node Status: Pro (License Key)\n'
          'Cloud Sandbox Status: Fully Detached (0B Leaked)\n'
          'License: \${_licenseKey.substring(0, 9)}...\${_licenseKey.substring(_licenseKey.length - 4)}';
    } else if (_isTrialActive) {
      return 'Local Node Status: Pro Trial (\${_trialDaysRemaining} days remaining)\n'
          'Cloud Sandbox Status: Fully Detached (0B Leaked)';
    } else {
      return 'Pro features sleep mode activated.\n'
          'Custom mapping and system automation are paused.\n'
          'Oko is running on Standard Core.';
    }
  }

  void _showProUpgradeDialog(BuildContext ctx) {
    final codeController = TextEditingController();
    showDialog(
        context: ctx,
        builder: (ctx) => AlertDialog(
              backgroundColor: _surfaceColor,
              title: Text('Upgrade to Pro',
                  style: TextStyle(color: _textColor)),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Pro unlocks:\n- Multi-App Chain Agent\n- Smart Incremental DB\n- Advanced AI Playground (models + prompts)\n- Drag & Drop file parsing\n- Menu Bar Mode\nEnter your activation code:',
                        style: TextStyle(
                            color: _textSecondaryColor, fontSize: 12)),
                    const SizedBox(height: 12),
                    TextField(
                        controller: codeController,
                        style: TextStyle(color: _textColor),
                        decoration: InputDecoration(
                            hintText: 'XXXX-XXXX-XXXX',
                            hintStyle: TextStyle(color: _hintTextColor),
                            filled: true,
                            fillColor: _inputBgColor,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10))),
                    const SizedBox(height: 12),
                    Text('Demo code: ONO-PRO-2026',
                        style: TextStyle(
                            color: _textSecondaryColor.withOpacity(0.6),
                            fontSize: 11)),
                  ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel',
                        style: TextStyle(color: _textSecondaryColor))),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FFD1),
                        foregroundColor: Colors.black),
                    onPressed: () async {
                      final code = codeController.text.trim().toUpperCase();
                      final success = await _activateLicense(code);
                      if (success) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('License activated. Oko is fully unlocked.'),
                            backgroundColor: const Color(0xFF0F4C75)));
                      } else {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('Invalid format. Expected: OKO-XXXX-XXXX-XXXX'),
                            backgroundColor: Colors.red));
                      }
                    },
                    child: Text('Activate')),
              ],
            ));
  }
}

enum _TaskStatus { pending, running, done }

class _TaskStep {
  final String label;
  _TaskStatus status;
  _TaskStep(this.label, this.status);
}
