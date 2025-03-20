import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'list_message.dart';
import '../entities/message_entity.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ChatScreen(),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  late IO.Socket socket;
  String connectionStatus = 'Disconnected';
  final ObservableList<Message> messages = ObservableList<Message>();

  @override
  void initState() {
    super.initState();
    _connectToSocketIO();
  }

  void _connectToSocketIO() {
    socket = IO.io('http://localhost:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      setState(() {
        connectionStatus = 'Connected';
      });
      print('Connection established');
    });

    socket.onDisconnect((_) {
      setState(() {
        connectionStatus = 'Disconnected';
      });
      print('Connection Disconnected');
    });

    socket.onConnectError((err) {
      setState(() {
        connectionStatus = 'Connection Error: $err';
      });
      print('Connect Error: $err');
    });

    socket.on('message', (data) {
      final message = data as Map<String, dynamic>;
      setState(() {
        messages.add(Message(
          name: message['from'] ?? 'Unknown',
          text: message['text'] ?? '',
          to: message['to'] ?? 'All',
        ));
      });
    });
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      final message = {
        'from': 'You',
        'text': _controller.text,
        'to': 'All',
      };
      socket.emit('message', message);
      setState(() {
        messages.add(Message(
          name: message['from'] as String? ?? 'Unknown',
          text: message['text'] as String? ?? '',
          to: message['to'] as String? ?? 'All',
        ));
      });
      _controller.clear();
    }
  }

  @override
  void dispose() {
    socket.disconnect();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey[200],
            child: Text(
              connectionStatus,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListMessageView(messages: messages),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey[200],
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Enter message',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: connectionStatus == 'Connected' ? _sendMessage : null,
                      child: const Text('Send Message'),
                    ),
                    ElevatedButton(
                      onPressed: _connectToSocketIO,
                      child: const Text('Reconnect'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}