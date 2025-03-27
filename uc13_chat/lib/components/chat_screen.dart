import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:mobx/mobx.dart';
import 'list_message.dart';
import '../entities/message_entity.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  late IO.Socket socket;
  String connectionStatus = 'Disconnected';
  final ObservableList<Message> messages = ObservableList<Message>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Registrar o observer
    _connectToSocketIO();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messageFocusNode.hasFocus) {
        _messageFocusNode.unfocus();
      }
      _messageFocusNode.requestFocus();
    });
  }

  void _connectToSocketIO() {
    socket = IO.io('http://172.17.9.201:3000', <String, dynamic>{
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

      // Mantém o foco no campo após enviar
      _messageFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remover o observer
    _messageFocusNode.dispose();
    _controller.dispose();
    socket.disconnect();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Isso é chamado quando o teclado aparece ou desaparece
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    if (bottomInset > 0) {
      // Teclado está visível - garantir que o campo está focado
      _messageFocusNode.requestFocus();
    }
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
            color: const Color(0xFF252526),
            child: Column(
              children: [
                TextField(
                  focusNode: _messageFocusNode, // <-- Conecte o FocusNode aqui
                  controller: _controller,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Enter message',
                    labelStyle: TextStyle(color: Color(0xFFd4d4d4)),
                  ),
                  style: const TextStyle(color: Color(0xFFd4d4d4)),
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.send,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed:
                          connectionStatus == 'Connected' ? _sendMessage : null,
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
