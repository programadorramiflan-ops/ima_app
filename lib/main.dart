import 'package:flutter/material.dart';
import 'package:luna_assistant/app_config.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IMA App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool hasKey = AppConfig.apiKey.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('IMA - Inteligência Multifuncional'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasKey ? Icons.check_circle : Icons.warning,
                color: hasKey ? Colors.green : Colors.orange,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                hasKey
                    ? 'API Key injetada com sucesso!'
                    : 'Chave de API não configurada.',
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
