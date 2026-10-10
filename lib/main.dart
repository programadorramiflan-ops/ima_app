import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:luna_assistant/app_config.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
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
  
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  
  bool _isListening = false;
  bool _isLoading = false;
  bool _speakResponse = true;
  Timer? _silenceTimer;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initTts();
    _requestPermissionsOnStart();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("pt-BR");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _requestPermissionsOnStart() async {
    await [
      Permission.microphone,
      Permission.camera,
    ].request();
  }

  void _listen() async {
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A permissão do microfone é obrigatória para usar a voz.')),
          );
        }
        return;
      }
    }

    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            _stopListeningAndSend();
          }
        },
        onError: (error) {
          _stopListeningAndSend();
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: "pt_BR",
          onResult: (val) {
            setState(() {
              _controller.text = val.recognizedWords;
            });
            _resetSilenceTimer();
          },
        );
      }
    } else {
      _stopListeningAndSend();
    }
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 3), () {
      if (_isListening) {
        _stopListeningAndSend();
      }
    });
  }

  void _stopListeningAndSend() {
    _silenceTimer?.cancel();
    if (_isListening) {
      _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
      if (_controller.text.trim().isNotEmpty) {
        _sendMessage();
      }
    }
  }

  void _speak(String text) async {
    if (_speakResponse && text.isNotEmpty) {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    }
  }

  Future<String> _fetchGeminiResponse(String prompt) async {
    final apiKey = AppConfig.apiKey.trim();
    
    // Diagnóstico se a chave estiver vazia
    if (apiKey.isEmpty) {
      return "Erro de Configuração: A chave de API (API_KEY) está vazia no app. Verifique se o GitHub Secret está configurado corretamente na Action.";
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );

    final String fullPrompt = 
        "Você é a IMA (Inteligência Multifuncional), uma assistente virtual empática, amigável e conversacional. "
        "Responda de forma direta, natural e acolhedora em português para: $prompt";

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': fullPrompt}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String? reply = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        return reply ?? "Não consegui obter uma resposta válida.";
      } else {
        return "Erro da API (${response.statusCode}): Servidor recusou a chave ou o pedido.";
      }
    } on SocketException {
      return "Erro de Rede (SocketException): O telemóvel tem internet, mas o Android bloqueou a resolução de DNS para o Google.";
    } on TimeoutException {
      return "A conexão com a IMA demorou muito tempo esgotando o limite.";
    } catch (e) {
      return "Erro inesperado: $e";
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isLoading = true;
      _controller.clear();
    });

    final responseText = await _fetchGeminiResponse(text);

    if (mounted) {
      setState(() {
        _messages.add({'sender': 'assistant', 'text': responseText});
        _isLoading = false;
      });
    }

    _speak(responseText);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('IMA - Inteligência Multifuncional'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                _speakResponse ? Icons.volume_up : Icons.volume_off,
                color: _speakResponse ? Colors.greenAccent : Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _speakResponse = !_speakResponse;
                });
              },
              tooltip: 'Alternar voz',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.smart_toy, size: 64, color: Colors.deepPurpleAccent),
                            SizedBox(height: 16),
                            Text(
                              'Toque no microfone e fale!',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isUser = msg['sender'] == 'user';
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isUser ? Colors.deepPurple : Colors.grey[800],
                              borderRadius: BorderRadius.circular(16),
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
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0),
              color: Colors.grey[900],
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.redAccent : Colors.white,
                      size: 28,
                    ),
                    onPressed: _listen,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: _isListening ? 'Ouvindo... (fale agora)' : 'Digite ou fale...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
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
