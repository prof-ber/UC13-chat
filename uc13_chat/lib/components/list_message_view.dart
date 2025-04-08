import 'package:flutter/material.dart';
import '../entities/message_entity.dart';
import 'package:uc13_chat/appconstants.dart';

class ListMessageView extends StatelessWidget {
  final List<Message> messages;
  final Widget bottomWidget;

  const ListMessageView({
    Key? key,
    required this.messages,
    required this.bottomWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1e1e1e),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[messages.length - 1 - index];
                  return _buildMessageItem(message);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border(top: BorderSide(color: Colors.grey.shade800)),
              ),
              child: bottomWidget,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(Message message) {
    final isCurrentUser = message.name.toLowerCase() == 'you';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color:
                  isCurrentUser
                      ? const Color(0xFF00bcd4)
                      : const Color(0xFF6a0dad),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (message.text.isNotEmpty)
                  Text(
                    message.text,
                    style: const TextStyle(color: Colors.white),
                  ),
                if (message.fileUrl != null)
                  Container(
                    constraints: const BoxConstraints(
                      maxWidth: 200,
                      maxHeight: 200,
                    ),
                    child: _buildMessageImage(message.fileUrl),
                  ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageImage(String? imageUrl) {
    if (imageUrl == null) {
      return const SizedBox.shrink();
    }

    final fullImageUrl =
        imageUrl.startsWith('http')
            ? imageUrl
            : 'http://${AppConstants.SERVER_IP}:3000$imageUrl';

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        fullImageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print("Error loading image: $error");
          return const Icon(Icons.error);
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }
}
