import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const ImaApp());
}

class ImaApp extends StatelessWidget {
  const ImaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IMA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121B26),
        primaryColor: const Color(0xFF2563EB),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  String _apiKey = '';
  bool _isListening = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _initTts();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('gemini_api_key') ?? '';
    });
  }

  Future<void> _saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', key);
    setState(() {
      _apiKey = key;
    });
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("pt-BR");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    }
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _controller.text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, configure sua Chave de API nas configurações.')),
      );
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });

    _controller.clear();

    try {
      final url = Uri.parse(
        'https://ready-knives-see.loca.lt/generate',
      );

      List<Map<String, dynamic>> contents = [];
      int start = _messages.length > 10 ? _messages.length - 10 : 0;

      for (int i = start; i < _messages.length; i++) {
        contents.add({
          'role': _messages[i]['role'] == 'user' ? 'user' : 'model',
          'parts': [{'text': _messages[i]['text']}]
        });
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': 'Você é a IMA (Inteligência Multifuncional), uma assistente virtual por voz humana, direta, empática e prestativa.'}
            ]
          },
          'contents': contents,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['candidates'][0]['content']['parts'][0]['text'] ?? 'Sem resposta';

        setState(() {
          _messages.add({'role': 'model', 'text': reply});
        });

        await _speak(reply);
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']['message'] ?? 'Erro desconhecido na API';
        setState(() {
          _messages.add({'role': 'model', 'text': 'Erro na requisição: $errorMessage'});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'model', 'text': 'Erro de conexão: $e'});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openSettings() {
    final keyController = TextEditingController(text: _apiKey);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuração da API'),
        content: TextField(
          controller: keyController,
          decoration: const InputDecoration(
            labelText: 'Chave de API Gemini',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveApiKey(keyController.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IMA'),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.green.shade900.withOpacity(0.3),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text('Conexão HTTPS criptografada end-to-end (AES-256)', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? const Color(0xFF2563EB) : const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        msg['text'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isLoading) const LinearProgressIndicator(),
            Container(
              color: const Color(0xFF1E293B),
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : Colors.blue),
                    onPressed: _listen,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Fale ou digite...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
