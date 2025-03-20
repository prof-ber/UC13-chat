import 'package:flutter/material.dart';

class MessageTo extends StatelessWidget {
  const MessageTo({
    Key? key,
    required this.name,
    required this.message,
  }) : super(key: key);

  final String name;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.blueAccent, // Cor de fundo para mensagens do remetente
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
          bottomLeft: Radius.circular(16.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end, // Alinha o conteúdo à direita
        children: [
          Text(
            name,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12.0,
            ),
          ),
          const SizedBox(height: 4.0), // Espaço entre o nome e a mensagem
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.0,
            ),
          ),
        ],
      ),
    );
  }
}