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
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String _selectedModel = 'qwen2.5:3b';
  bool _backendConnected = false;

  @override
  void initState() {
    super.initState();
    _checkBackend();
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
            content: '❌ Error: ${response.statusCode}',
            isUser: false,
            timestamp: DateTime.now().toIso8601String(),
          ));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          content: '❌ Cannot connect to Ono backend. Is it running?',
          isUser: false,
          timestamp: DateTime.now().toIso8601String(),
        ));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
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
              child: const Center(
                child: Text('O',
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
            const SizedBox(width: 12),
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
                          child: const Center(
                            child: Text('O',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          '把糊涂的事理清楚',
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
          border:
              Border.all(color: const Color(0xFF00FFD1).withOpacity(0.2)),
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
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings',
                  style: TextStyle(
                      color: Color(0xFF00FFD1),
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text('Model',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: _selectedModel,
                dropdownColor: const Color(0xFF1A1F36),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(
                      value: 'qwen2.5:3b', child: Text('qwen2.5:3b')),
                  DropdownMenuItem(
                      value: 'qwen2.5:7b', child: Text('qwen2.5:7b')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedModel = val);
                    setModalState(() => _selectedModel = val);
                  }
                },
              ),
              const SizedBox(height: 16),
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
}
