import 'package:flutter/material.dart';

class SeekerChatScreen extends StatelessWidget {
  const SeekerChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сообщения')),
      body: const Center(child: Text('Сообщения')),
    );
  }
}
