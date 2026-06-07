import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const OnoApp());
}

// ============================================================
// SPLASH SCREEN - Brand loading animation
// ============================================================

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _scaleAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5)),
    );
    _glowAnim = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        widget.onDone();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with scale + glow animation
                Transform.scale(
                  scale: _scaleAnim.value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F4C75), Color(0xFF00FFD1)],
                      ),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FFD1)
                              .withOpacity(_glowAnim.value * 0.5),
                          blurRadius: 40 * _glowAnim.value,
                          spreadRadius: 10 * _glowAnim.value,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'O',
                        style: TextStyle(
                          color: Colors.white.withOpacity(_opacityAnim.value),
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // App name fade-in
                Opacity(
                  opacity: _opacityAnim.value,
                  child: Text(
                    'Ono',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF00FFD1)
                          .withOpacity(_opacityAnim.value),
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Tagline fade-in (delayed)
                FadeTransition(
                  opacity: _glowAnim,
                  child: const Text(
                    'Privacy-first AI assistant',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                // Loading dots
                SizedBox(
                  width: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.3, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        builder: (context, value, _) => Padding(
                          padding: EdgeInsets.only(right: i < 2 ? 4.0 : 0),
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FFD1)
                                  .withOpacity(value),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    }),
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

// ============================================================
// THEME DATA
// ============================================================

final _darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF00FFD1),
  scaffoldBackgroundColor: const Color(0xFF0A0E1A),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF00FFD1),
    secondary: Color(0xFF0F4C75),
    surface: Color(0xFF111827),
  ),
  useMaterial3: true,
);

final _lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFF0F4C75),
  scaffoldBackgroundColor: const Color(0xFFF5F7FA),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF0F4C75),
    secondary: Color(0xFF00FFD1),
    surface: Colors.white,
  ),
  useMaterial3: true,
);

class OnoApp extends StatefulWidget {
  const OnoApp({super.key});

  @override
  State<OnoApp> createState() => _OnoAppState();
}

class _OnoAppState extends State<OnoApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ono',
      debugShowCheckedModeBanner: false,
      theme: _darkTheme,
      darkTheme: _darkTheme,
      themeMode: ThemeMode.dark,
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
  final int? id; // SQLite row id
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

class OnoDatabase {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'ono.db');
    return await openDatabase(path, version: 1, onCreate: (db, version) async {
      // Sessions table
      await db.execute('''
        CREATE TABLE sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL DEFAULT ''
        )
      ''');
      // Messages table
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

  static Future<void> deleteSession(int sessionId) async {
    final d = await db;
    await d.delete('messages', where: 'session_id = ?', whereArgs: [sessionId]);
    await d.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
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
  bool _isPro = true; // Default pro for now
  bool _ollamaRunning = false;

  // Settings
  double _fontSize = 15.0;
  ThemeMode _themeMode = ThemeMode.dark;
  bool _showSidebar = false;

  // All available models
  static const List<Map<String, String>> _allModels = [
    {'id': 'qwen2.5:3b', 'name': 'qwen2.5:3b', 'tier': 'free'},
    {'id': 'qwen2.5:7b', 'name': 'qwen2.5:7b', 'tier': 'pro'},
    {'id': 'llama3.2:3b', 'name': 'llama3.2:3b', 'tier': 'pro'},
    {'id': 'mistral:7b', 'name': 'mistral:7b', 'tier': 'pro'},
    {'id': 'gemma2:9b', 'name': 'gemma2:9b', 'tier': 'pro'},
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
    setState(() {
      _isPro = prefs.getBool('is_pro') ?? true;
      _selectedModel = prefs.getString('selected_model') ?? 'qwen2.5:3b';
      _fontSize = prefs.getDouble('font_size') ?? 15.0;
      final tm = prefs.getInt('theme_mode') ?? 0;
      _themeMode = ThemeMode.values[tm];
    });
  }

  Future<void> _loadSessions() async {
    final sessions = await OnoDatabase.getSessions();
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
  }

  Future<void> _newSession() async {
    final id = await OnoDatabase.createSession('New Chat ${DateTime.now().hour}:${DateTime.now().minute}');
    final sessions = await OnoDatabase.getSessions();
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
    final msgs = await OnoDatabase.getMessages(sessionId);
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
      print('[Ono] Ollama already running on port 11434');
      setState(() => _ollamaRunning = true);
      return;
    }
    final ollamaPaths = [
      '/usr/local/bin/ollama',
      '/opt/homebrew/bin/ollama',
      '/usr/bin/ollama',
    ];
    String? ollamaPath;
    for (final p in ollamaPaths) {
      if (await File(p).exists()) { ollamaPath = p; break; }
    }
    if (ollamaPath == null) {
      print('[Ono] Ollama not found.');
      return;
    }
    try {
      print('[Ono] Starting Ollama...');
      final proc = await Process.start(ollamaPath!, ['serve']);
      proc.stdout.listen((_) {});
      proc.stderr.listen((_) {});
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (await _isPortOpen(11434)) {
          print('[Ono] Ollama ready');
          setState(() => _ollamaRunning = true);
          return;
        }
      }
      setState(() => _ollamaRunning = true);
    } catch (e) { print('[Ono] Failed to start Ollama: $e'); }
  }

  Future<void> _autoStartBackend() async {
    if (await _isPortOpen(8000)) {
      print('[Ono] Backend already running');
      return;
    }
    try {
      final executable = Platform.resolvedExecutable;
      final bundleDir = File(executable).parent.path;
      final backendPath = '$bundleDir/ono_backend';
      if (await File(backendPath).exists()) {
        print('[Ono] Starting bundled backend...');
        final proc = await Process.start(backendPath, []);
        proc.stdout.listen((_) {});
        proc.stderr.listen((_) {});
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(seconds: 1));
          if (await _isPortOpen(8000)) {
            print('[Ono] Backend ready');
            return;
          }
        }
      } else {
        print('[Ono] Bundled backend not found at $backendPath');
      }
    } catch (e) { print('[Ono] Failed to start backend: $e'); }
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
    await OnoDatabase.addMessage(userMsg);
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
        await OnoDatabase.addMessage(assistantMsg);
        setState(() => _messages.add(assistantMsg));

        // Auto-update session title from first user message
        if (_messages.where((m) => m.isUser).length <= 1) {
          final shortTitle = text.length > 30 ? '${text.substring(0, 30)}...' : text;
          final d = await OnoDatabase.db;
          await d.update('sessions', {'title': shortTitle},
              where: 'id = ?', whereArgs: [_currentSessionId]);
          _loadSessions(); // refresh sidebar
        }
      } else {
        final errMsg = ChatMessage(
          content: 'Error: ${response.statusCode}',
          isUser: false,
          timestamp: DateTime.now().toIso8601String(),
          sessionId: _currentSessionId,
        );
        await OnoDatabase.addMessage(errMsg);
        setState(() => _messages.add(errMsg));
      }
    } catch (e) {
      final errMsg = ChatMessage(
        content: 'Cannot connect to Ono backend. Is it running?',
        isUser: false,
        timestamp: DateTime.now().toIso8601String(),
        sessionId: _currentSessionId,
      );
      await OnoDatabase.addMessage(errMsg);
      setState(() => _messages.add(errMsg));
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _clearCurrentChat() async {
    final d = await OnoDatabase.db;
    await d.delete('messages', where: 'session_id = ?', whereArgs: [_currentSessionId]);
    setState(() => _messages.clear());
  }

  void _deleteSession(int sessionId) async {
    await OnoDatabase.deleteSession(sessionId);
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

  // Get current colors based on theme mode
  Color get _bgColor => _themeMode == ThemeMode.dark
      ? const Color(0xFF0A0E1A)
      : const Color(0xFFF5F7FA);
  Color get _surfaceColor => _themeMode == ThemeMode.dark
      ? const Color(0xFF111827)
      : Colors.white;
  Color get _inputBgColor => _themeMode == ThemeMode.dark
      ? const Color(0xFF0A0E1A)
      : const Color(0xFFE8ECF0);
  Color get _borderColor => _themeMode == ThemeMode.dark
      ? const Color(0xFF1A1F36)
      : const Color(0xFFD0D5DD);
  Color get _textColor => _themeMode == ThemeMode.dark
      ? Colors.white : const Color(0xFF111827);
  Color get _textSecondaryColor => _themeMode == ThemeMode.dark
      ? Colors.white54 : const Color(0xFF6B7280);
  Color get _hintTextColor => _themeMode == ThemeMode.dark
      ? Colors.white38 : const Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _themeMode == ThemeMode.dark ? _darkTheme : _lightTheme,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
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
                ),
                child: Center(child: Text('O',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
              ),
              const SizedBox(width: 8),
              Text('Ono', style: TextStyle(color: const Color(0xFF00FFD1), fontSize: 20, fontWeight: FontWeight.bold)),
              if (_isPro) ...[
                const SizedBox(width: 4),
                Container(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.amber, Colors.orange]), borderRadius: BorderRadius.circular(6)),
                  child: Text('PRO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
              ],
              const Spacer(),
              Container(width: 7, height: 7, decoration: BoxDecoration(color: _backendConnected ? Colors.green : Colors.red, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(_backendConnected ? 'Connected' : 'Offline', style: TextStyle(color: _backendConnected ? Colors.green : Colors.red, fontSize: 11)),
              const SizedBox(width: 6),
              IconButton(icon: Icon(Icons.delete_outline, color: _textSecondaryColor.withOpacity(0.5), size: 18),
                  onPressed: _messages.isEmpty ? null : _clearCurrentChat, tooltip: 'Clear chat'),
              IconButton(icon: Icon(Icons.settings, color: const Color(0xFF00FFD1)), onPressed: () => _showSettings()),
            ],
          ),
        ),
        body: Stack(children: [
          Column(children: [
            Expanded(child: _buildChatArea()),
            _buildInputArea(),
          ]),
          if (_showSidebar) _buildSidebar(),
        ]),
      ),
    );
  }

  Widget _buildChatArea() {
    if (_messages.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 72, height: 72, decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F4C75), Color(0xFF00FFD1)]),
        borderRadius: BorderRadius.circular(36)),
      child: Center(child: Text('O', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)))),
      const SizedBox(height: 16),
      Text('Ask me anything — I am fully local and private', style: TextStyle(color: const Color(0xFF00FFD1), fontSize: _fontSize + 3)),
      const SizedBox(height: 6),
      Text('Privacy-first AI agent with computer control', style: TextStyle(color: _hintTextColor, fontSize: _fontSize - 1)),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: _ollamaRunning ? Colors.green : Colors.orange, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(_ollamaRunning ? 'Ollama Ready' : 'Ollama Starting...', style: TextStyle(color: _ollamaRunning ? Colors.green : Colors.orange, fontSize: 11)),
      ]),
    ]));

    return ListView.builder(controller: _scrollController, padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) return _buildTypingIndicator();
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          gradient: msg.isUser ? const LinearGradient(colors: [Color(0xFF0F4C75), Color(0xFF0F4C75)])
              : LinearGradient(colors: [_surfaceColor, _surfaceColor]),
          borderRadius: BorderRadius.circular(18),
          border: msg.isUser ? null : Border.all(color: const Color(0xFF00FFD1).withOpacity(0.2))),
        child: Text(msg.content, style: TextStyle(color: msg.isUser ? Colors.white : _textColor.withOpacity(0.9), fontSize: _fontSize))));
  }

  Widget _buildTypingIndicator() {
    return Align(alignment: Alignment.centerLeft, child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF00FFD1).withOpacity(0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _dot(), const SizedBox(width: 4), _dot(delayMs: 150), const SizedBox(width: 4), _dot(delayMs:300)])));
  }

  Widget _dot({int delayMs = 0}) {
    return TweenAnimationBuilder<double>(tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, _) => Opacity(opacity: value,
        child: Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFF00FFD1), borderRadius: BorderRadius.circular(4)))));
  }

  Widget _buildInputArea() {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: _surfaceColor, border: Border(top: BorderSide(color: _borderColor))),
      child: Row(children: [
        Expanded(child: TextField(controller: _controller, style: TextStyle(color: _textColor, fontSize: _fontSize),
          decoration: InputDecoration(hintText: 'Ask Ono anything... or type a command like "open Safari"',
            hintStyle: TextStyle(color: _hintTextColor, fontSize: _fontSize),
            filled: true, fillColor: _inputBgColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          onSubmitted: (_) => _sendMessage())),
        const SizedBox(width: 8),
        Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F4C75), Color(0xFF00FFD1)]), borderRadius: BorderRadius.circular(28)),
          child: IconButton(icon: _isLoading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Icon(Icons.send, color: Colors.white), onPressed: _isLoading ? null : _sendMessage)),
      ]));
  }

  // ==================== SIDEBAR (Session History) ====================

  Widget _buildSidebar() {
    return Positioned.fill(child: GestureDetector(onTap: () => setState(() => _showSidebar = false),
      child: Container(color: Colors.black54, child: Align(alignment: Alignment.centerLeft, child:
        Container(width: 280, height: double.infinity, color: _surfaceColor,
          child: Column(children: [
            Container(padding: const EdgeInsets.all(16),
              child: Row(children: [
                Text('Chats', style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: Icon(Icons.add_circle_outline, color: const Color(0xFF00FFD1)), onPressed: () { _newSession(); setState(() => _showSidebar = false); }),
              ])),
            Divider(color: _borderColor),
            Expanded(child: _sessions.isEmpty
                ? Center(child: Text('No chats yet', style: TextStyle(color: _textSecondaryColor)))
                : ListView.builder(itemCount: _sessions.length, itemBuilder: (ctx, idx) {
                    final s = _sessions[idx];
                    final isActive = s.id == _currentSessionId;
                    return ListTile(dense: true, selected: isActive,
                      selectedTileColor: const Color(0xFF00FFD1).withOpacity(0.08),
                      leading: Icon(Icons.chat_bubble_outline, size: 18, color: isActive ? const Color(0xFF00FFD1) : _textSecondaryColor),
                      title: Text(s.title, style: TextStyle(color: _textColor, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(s.createdAt.substring(0, 16), style: TextStyle(color: _textSecondaryColor, fontSize: 10)),
                      trailing: IconButton(icon: Icon(Icons.close, size: 14, color: _textSecondaryColor.withOpacity(0.5)), onPressed: () => _deleteSession(s.id!)),
                      onTap: () { _switchSession(s.id!); setState(() => _showSidebar = false); });
                  })),
          ]))))));
  }

  // ==================== SETTINGS PAGE ====================

  void _showSettings() {
    showModalBottomSheet(context: context, backgroundColor: _surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(builder: (context, setModalState) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [

          // --- General ---
          _sectionHeader('General'),
          const SizedBox(height: 12),

          // Font Size
          Row(children: [
            Icon(Icons.text_fields, color: _textSecondaryColor, size: 18),
            const SizedBox(width: 10),
            Text('Font Size', style: TextStyle(color: _textColor, fontSize: 14)),
            const Spacer(),
            Text('${_fontSize.toInt()}px', style: TextStyle(color: const Color(0xFF00FFD1), fontSize: 13)),
          ]),
          Slider(value: _fontSize, min: 12, max: 22, divisions: 10,
            activeColor: const Color(0xFF00FFD1), inactiveColor: _textSecondaryColor.withOpacity(0.2),
            onChanged: (v) async {
              setModalState(() => _fontSize = v);
              setState(() => _fontSize = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('font_size', v);
            }),
          const SizedBox(height: 16),

          // --- Appearance ---
          _sectionHeader('Appearance'),
          const SizedBox(height: 12),

          // Theme Mode
          ...[ThemeMode.dark, ThemeMode.light, ThemeMode.system].map((tm) {
            final labels = {ThemeMode.dark: 'Dark', ThemeMode.light: 'Light', ThemeMode.system: 'System'};
            final icons = {ThemeMode.dark: Icons.dark_mode, ThemeMode.light: Icons.light_mode, ThemeMode.system: Icons.settings_brightness};
            final isSelected = _themeMode == tm;
            return ListTile(dense: true, contentPadding: EdgeInsets.zero,
              leading: Icon(icons[tm], size: 20, color: isSelected ? const Color(0xFF00FFD1) : _textSecondaryColor),
              title: Text(labels[tm] ?? '', style: TextStyle(color: _textColor, fontSize: 14)),
              trailing: isSelected ? Icon(Icons.check, color: const Color(0xFF00FFD1), size: 18) : null,
              onTap: () async {
                setModalState(() => _themeMode = tm);
                setState(() => _themeMode = tm);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('theme_mode', tm.index);
              });
          }),
          const SizedBox(height: 16),

          // --- Model ---
          _sectionHeader('Model'),
          const SizedBox(height: 8),
          ..._allModels.map((model) {
            final isProModel = model['tier'] == 'pro';
            final isLocked = isProModel && !_isPro;
            final isSelected = _selectedModel == model['id'];
            return ListTile(dense: true, contentPadding: EdgeInsets.zero,
              leading: Icon(isLocked ? Icons.lock_outline : Icons.check_circle_outline, size: 20,
                color: isSelected ? const Color(0xFF00FFD1) : (isLocked ? Colors.white24 : _textSecondaryColor)),
              title: Row(children: [
                Text(model['name'] ?? '', style: TextStyle(color: isLocked ? Colors.white38 : _textColor, fontSize: 14)),
                if (isProModel) ...[
                  const SizedBox(width: 6),
                  Container(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.amber, Colors.orange]), borderRadius: BorderRadius.circular(4)),
                    child: Text('PRO', style: TextStyle(color: Colors.white, fontSize: 8))),
                ],
              ]),
              trailing: isSelected ? Text('Active', style: TextStyle(color: const Color(0xFF00FFD1), fontSize: 12)) : null,
              onTap: isLocked ? null : () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('selected_model', model['id'] ?? '');
                setState(() => _selectedModel = model['id'] ?? 'qwen2.5:3b');
                setModalState(() => _selectedModel = model['id'] ?? 'qwen2.5:3b');
              },
            );
          }),
          const SizedBox(height: 16),

          // --- System Status ---
          _sectionHeader('System'),
          const SizedBox(height: 8),

          // Backend status
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: _backendConnected ? Colors.green : Colors.red, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(_backendConnected ? 'Backend Connected' : 'Backend Offline', style: TextStyle(color: _backendConnected ? Colors.green : Colors.redAccent, fontSize: 13)),
            const Spacer(),
            TextButton(onPressed: () async { await _checkBackend(); setModalState(() {}); }, child: Text('Reconnect', style: TextStyle(color: const Color(0xFF00FFD1)))),
          ]),
          const SizedBox(height: 8),

          // Ollama status
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: _ollamaRunning ? Colors.green : Colors.orange, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(_ollamaRunning ? 'Ollama Running' : 'Ollama Not Detected', style: TextStyle(color: _ollamaRunning ? Colors.green : Colors.orange, fontSize: 13)),
          ]),
          const SizedBox(height: 20),
        ]),
      )));
  }

  Widget _sectionHeader(String title) {
    return Text(title, style: TextStyle(color: _textSecondaryColor, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5));
  }
}
