import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../theme/colors.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {'role': 'ai', 'message': 'I have access to your portfolio. Ask me for advice!'}
  ];
  bool _isTyping = false;

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;

    final userMsg = _controller.text;
    setState(() {
      _messages.add({'role': 'user', 'message': userMsg});
      _isTyping = true;
      _controller.clear();
    });

    final api = Provider.of<ApiService>(context, listen: false);
    final firebase = Provider.of<FirebaseService>(context, listen: false);

    // 1. Fetch current portfolio snapshot (Once)
    final snapshot = await firebase.getPortfolioStream().first;
    
    // 2. Send to Gemini
    final response = await api.getPortfolioAdvice(userMsg, snapshot);

    setState(() {
      _messages.add({'role': 'ai', 'message': response});
      _isTyping = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(title: const Text("AI Advisor"), backgroundColor: AppColors.cardDark),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final isUser = _messages[index]['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : AppColors.cardDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_messages[index]['message']!, style: const TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),
          ),
          if (_isTyping) const LinearProgressIndicator(color: AppColors.primary),
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.cardDark,
            child: Row(
              children: [
                Expanded(child: TextField(controller: _controller, decoration: const InputDecoration.collapsed(hintText: "Ask about your stocks..."))),
                IconButton(icon: const Icon(Icons.send, color: AppColors.primary), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}