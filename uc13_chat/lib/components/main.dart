import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
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
      setState(() {
        messages.add(Message.fromJson(data));
      });
    });
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      final message = Message(
        name: 'You',
        text: _controller.text,
        to: 'All',
        timestamp: DateTime.now(),
      );
      socket.emit('message', message.toJson());
      setState(() {
        messages.add(message);
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
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF1e1e1e), // Fundo principal
    body: Column(
      children: [
        // Barra de status da conexão
        Container(
          padding: const EdgeInsets.all(8.0),
          color: const Color(0xFF252526), // Fundo secundário
          child: Text(
            connectionStatus,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFd4d4d4), // Texto cinza claro
            ),
          ),
        ),

        // Lista de mensagens
        Expanded(
          child: Container(
            color: const Color(0xFF1e1e1e), // Fundo principal
            child: ListMessageView(messages: messages),
          ),
        ),

        // Campo de texto e botões
        Container(
          padding: const EdgeInsets.all(8.0),
          color: const Color(0xFF252526), // Fundo secundário
          child: Column(
            children: [
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'Enter message',
                  labelStyle: TextStyle(color: Color(0xFFd4d4d4)), // Texto cinza claro
                ),
                style: const TextStyle(color: Color(0xFFd4d4d4)), // Texto cinza claro
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