import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
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
  }

  void _initTts() async {
    await _flutterTts.setLanguage("pt-BR");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissão do microfone é necessária para gravar áudio.')),
      );
    }
  }

  void _listen() async {
    await _requestMicPermission();

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
          pauseFor: const Duration(seconds: 3), // Timer de 3 segundos de silêncio
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
      setState(() => _isListening = false);
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

  String _generateResponse(String userMessage) {
    final msg = userMessage.toLowerCase().trim();

    if (msg.contains('triste') || msg.contains('chateado') || msg.contains('mal')) {
      return 'Sinto muito que esteja se sentindo assim. Estou aqui com você. O que aconteceu? Quer conversar sobre isso?';
    } else if (msg.contains('oi') || msg.contains('olá') || msg.contains('ima')) {
      return 'Olá! Como posso te ajudar agora?';
    } else if (msg.contains('bom dia')) {
      return 'Bom dia! Espero que o seu dia seja produtivo e abençoado.';
    } else if (msg.contains('boa tarde')) {
      return 'Boa tarde! Como estão as coisas por aí?';
    } else if (msg.contains('boa noite')) {
      return 'Boa noite! Como posso te auxiliar antes de descansar?';
    } else {
      return 'Entendi perfeitamente. Estou processando sua solicitação e continuo à disposição!';
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isLoading = true;
      _controller.clear();
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      final responseText = _generateResponse(text);

      setState(() {
        _messages.add({'sender': 'assistant', 'text': responseText});
        _isLoading = false;
      });

      _speak(responseText);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.smart_toy, size: 64, color: Colors.deepPurpleAccent),
                        SizedBox(height: 16),
                        Text(
                          'Toque no microfone e fale!',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
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
            padding: const EdgeInsets.all(8.0),
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
    );
  }
}
