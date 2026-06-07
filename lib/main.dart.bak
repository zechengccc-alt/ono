import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const OnoApp());
}

class OnoApp extends StatelessWidget {
  const OnoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ono',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00FFD1),
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFD1),
          secondary: Color(0xFF0F4C75),
          surface: Color(0xFF111827),
        ),
        useMaterial3: true,
      ),
      home: const ChatPage(),
    );
  }
}

class ChatMessage {
  final String content;
  final bool isUser;
  final String timestamp;

  ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'content': content,
        'isUser': isUser,
        'timestamp': timestamp,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        content: json['content'] as String,
        isUser: json['isUser'] as bool,
        timestamp: json['timestamp'] as String,
      );
}

// Pro feature gate
class ProFeature {
  static const String multiModel = 'multi_model';
  static const String customTheme = 'custom_theme';
  static const String advancedSettings = 'advanced_settings';
  static const String cloudSync = 'cloud_sync';
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String _selectedModel = 'qwen2.5:3b';
  bool _backendConnected = false;
  bool _isPro = false;

  // All available models
  static const List<Map<String, String>> _allModels = [
    {'id': 'qwen2.5:3b', 'name': 'qwen2.5:3b', 'tier': 'free'},
    {'id': 'qwen2.5:7b', 'name': 'qwen2.5:7b', 'tier': 'pro'},
    {'id': 'llama3.2:3b', 'name': 'llama3.2:3b', 'tier': 'pro'},
    {'id': 'mistral:7b', 'name': 'mistral:7b', 'tier': 'pro'},
    {'id': 'gemma2:9b', 'name': 'gemma2:9b', 'tier': 'pro'},
  ];

  List<Map<String, String>> get _availableModels =>
      _isPro ? _allModels : _allModels.where((m) => m['tier'] == 'free').toList();

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPro = prefs.getBool('is_pro') ?? false;
      _selectedModel = prefs.getString('selected_model') ?? 'qwen2.5:3b';
    });
    await _loadMessages();
    _checkBackend();
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('chat_messages') ?? [];
    setState(() {
      _messages = saved
          .map((s) {
            try {
              return ChatMessage.fromJson(jsonDecode(s));
            } catch (_) {
              return null;
            }
          })
          .whereType<ChatMessage>()
          .toList();
    });
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        _messages.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList('chat_messages', encoded);
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(
        content: text,
        isUser: true,
        timestamp: DateTime.now().toIso8601String(),
      ));
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
        setState(() {
          _messages.add(ChatMessage(
            content: data['response'] ?? 'No response',
            isUser: false,
            timestamp: data['timestamp'] ?? DateTime.now().toIso8601String(),
          ));
        });
      } else {
        setState(() {
          _messages.add(ChatMessage(
            content: 'Error: ${response.statusCode}',
            isUser: false,
            timestamp: DateTime.now().toIso8601String(),
          ));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          content: 'Cannot connect to Ono backend. Is it running?',
          isUser: false,
          timestamp: DateTime.now().toIso8601String(),
        ));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
      _saveMessages();
    }
  }

  void _clearChat() async {
    setState(() => _messages.clear());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_messages');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F4C75), Color(0xFF00FFD1)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: _isPro
                    ? const Icon(Icons.star, color: Colors.amber, size: 18)
                    : const Text('O',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Ono',
                style: TextStyle(
                    color: Color(0xFF00FFD1),
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            if (_isPro) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Colors.amber, Colors.orange]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('PRO',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
            const Spacer(),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _backendConnected ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _backendConnected ? 'Connected' : 'Offline',
              style: TextStyle(
                color: _backendConnected ? Colors.green : Colors.red,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
              onPressed: _messages.isEmpty ? null : _clearChat,
              tooltip: 'Clear chat',
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Color(0xFF00FFD1)),
              onPressed: () => _showSettings(),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F4C75), Color(0xFF00FFD1)],
                            ),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Center(
                            child: _isPro
                                ? const Icon(Icons.star,
                                    color: Colors.amber, size: 40)
                                : const Text('O',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Ask me anything, I am fully local and private',
                          style: TextStyle(
                            color: Color(0xFF00FFD1),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Privacy-first AI assistant',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: msg.isUser
              ? const LinearGradient(
                  colors: [Color(0xFF0F4C75), Color(0xFF0F4C75)])
              : const LinearGradient(
                  colors: [Color(0xFF1A1F36), Color(0xFF1A1F36)]),
          borderRadius: BorderRadius.circular(18),
          border: msg.isUser
              ? null
              : Border.all(color: const Color(0xFF00FFD1).withOpacity(0.2)),
        ),
        child: Text(
          msg.content,
          style: TextStyle(
            color: msg.isUser ? Colors.white : Colors.white.withOpacity(0.9),
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F36),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF00FFD1).withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(0),
            const SizedBox(width: 4),
            _dot(150),
            const SizedBox(width: 4),
            _dot(300),
          ],
        ),
      ),
    );
  }

  Widget _dot(int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF00FFD1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        border: Border(
          top: BorderSide(color: Color(0xFF1A1F36)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ask Ono anything...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF0A0E1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F4C75), Color(0xFF00FFD1)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pro badge
              if (_isPro)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Colors.amber, Colors.orange]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.star, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Ono Pro Active',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.amber.withOpacity(0.4), width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_outline, color: Colors.amber),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Upgrade to Pro',
                                style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                            Text('Multi-model, themes, and more',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showProPage();
                        },
                        child: const Text('Learn More',
                            style: TextStyle(color: Colors.amber)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Model section
              const Text('Model',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              ..._allModels.map((model) {
                final isProModel = model['tier'] == 'pro';
                final isLocked = isProModel && !_isPro;
                final isSelected = _selectedModel == model['id'];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isLocked ? Icons.lock_outline : Icons.check_circle_outline,
                    color: isSelected
                        ? const Color(0xFF00FFD1)
                        : (isLocked ? Colors.white24 : Colors.white54),
                    size: 20,
                  ),
                  title: Row(
                    children: [
                      Text(model['name'] ?? '',
                          style: TextStyle(
                            color: isLocked ? Colors.white38 : Colors.white,
                            fontSize: 14,
                          )),
                      if (isProModel) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Colors.amber, Colors.orange]),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('PRO',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 8)),
                        ),
                      ],
                    ],
                  ),
                  trailing: isSelected
                      ? const Text('Active',
                          style: TextStyle(
                              color: Color(0xFF00FFD1), fontSize: 12))
                      : null,
                  onTap: isLocked
                      ? () {
                          Navigator.pop(context);
                          _showProPage();
                        }
                      : () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString(
                              'selected_model', model['id'] ?? '');
                          setState(() =>
                              _selectedModel = model['id'] ?? 'qwen2.5:3b');
                          setModalState(() =>
                              _selectedModel = model['id'] ?? 'qwen2.5:3b');
                        },
                );
              }),
              const SizedBox(height: 16),

              // Backend section
              const Text('Backend',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _backendConnected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _backendConnected
                        ? 'Connected to localhost:8000'
                        : 'Backend offline',
                    style: TextStyle(
                      color:
                          _backendConnected ? Colors.green : Colors.redAccent,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      await _checkBackend();
                      setModalState(() {});
                    },
                    child: const Text('Reconnect',
                        style: TextStyle(color: Color(0xFF00FFD1))),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showProPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ProPage(
          isPro: _isPro,
          onActivate: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('is_pro', true);
            setState(() => _isPro = true);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

class _ProPage extends StatelessWidget {
  final bool isPro;
  final VoidCallback onActivate;

  const _ProPage({required this.isPro, required this.onActivate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00FFD1)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Ono Pro',
            style: TextStyle(
                color: Color(0xFF00FFD1),
                fontSize: 22,
                fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Colors.amber, Colors.orange]),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(Icons.star, color: Colors.white, size: 50),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text('Unlock Ono Pro',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('Power up your local AI experience',
                  style: TextStyle(color: Colors.white54, fontSize: 16)),
            ),
            const SizedBox(height: 32),

            // Feature list
            _proFeature(Icons.model_training, 'Multi-Model Support',
                'Switch between Llama, Mistral, Gemma, and more'),
            _proFeature(Icons.palette, 'Custom Themes',
                'Personalize your Ono with custom color schemes'),
            _proFeature(Icons.settings_suggest, 'Advanced Settings',
                'Custom API endpoints, system prompts, temperature control'),
            _proFeature(Icons.cloud_sync, 'Cloud Sync',
                'Sync conversations across all your devices (coming soon)'),
            _proFeature(Icons.support_agent, 'Priority Support',
                'Get help faster with dedicated support'),
            const SizedBox(height: 32),

            // Pricing
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(
                    color: const Color(0xFF00FFD1).withOpacity(0.3)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('Student Price',
                      style: TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('\$29.99',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Text('one-time',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('or \$4.99/month',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // CTA
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPro ? Colors.white12 : Colors.amber,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: isPro ? null : onActivate,
                child: Text(
                  isPro ? 'Pro Active' : 'Activate Pro',
                  style: TextStyle(
                    color: isPro ? Colors.white38 : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'All features work locally. No data leaves your device.',
                style: TextStyle(color: Colors.white24, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _proFeature(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF0F4C75), Color(0xFF00FFD1)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
