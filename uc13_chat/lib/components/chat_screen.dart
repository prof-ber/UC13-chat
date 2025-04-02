import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:mobx/mobx.dart';
import 'list_message.dart';
import '../entities/message_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'contacts.dart';

final SERVER_IP = "172.17.9.224";

class ChatScreen extends StatefulWidget {
  final Contact contact;
  final User currentUser;

  const ChatScreen({
    super.key,
    required this.contact,
    required this.currentUser,
  });

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  ImageProvider? _avatarImage;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  late IO.Socket socket;
  String connectionStatus = 'Disconnected';
  final ObservableList<Message> messages = ObservableList<Message>();

  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    _avatarImage = NetworkImage('https://example.com/avatar.jpg');
    _isMounted = true;
    WidgetsBinding.instance.addObserver(this);
    _connectToSocketIO();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messageFocusNode.hasFocus) {
        _messageFocusNode.unfocus();
      }
      _messageFocusNode.requestFocus();
    });
  }

  void _connectToSocketIO() async {
    // Obter o token de autenticação
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      print('Token não encontrado. O usuário precisa fazer login.');
      // Aqui você pode adicionar lógica para redirecionar o usuário para a tela de login
      return;
    }

    socket = IO.io('http://localhost:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'token': token},
    });

    socket.connect();

    socket.onConnect((_) {
      if (_isMounted) {
        setState(() {
          connectionStatus = 'Connected';
        });
      }
      print('Connection established');
      socket.emit('authenticate', token);
    });

    socket.onDisconnect((_) {
      if (_isMounted) {
        setState(() {
          connectionStatus = 'Disconnected';
        });
      }
      print('Connection Disconnected');
    });

    socket.onConnectError((err) {
      if (_isMounted) {
        setState(() {
          connectionStatus = 'Connection Error: $err';
        });
      }
      print('Connect Error: $err');
    });

    socket.on('old_messages', (data) {
      if (_isMounted) {
        setState(() {
          messages.clear(); // Limpa as mensagens existentes
          messages.addAll((data as List).map((m) {
            return Message(
              name: m['is_sender'] ? 'You' : 'Other',
              text: m['content'],
              to: m['is_sender'] ? m['other_user_id'] : 'You',
              timestamp: DateTime.parse(m['timestamp']),
            );
          }));
        });
      }
    });

    socket.on('message', (data) {
      if (_isMounted) {
        setState(() {
          messages.add(Message(
            name: data['is_sender'] ? 'You' : 'Other',
            text: data['content'],
            to: data['is_sender'] ? data['other_user_id'] : 'You',
            timestamp: DateTime.parse(data['timestamp']),
          ));
        });
        _controller.clear();

        // Mantém o foco no campo após enviar
        _messageFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _isMounted = false;
    WidgetsBinding.instance.removeObserver(this); // Remover o observer
    _messageFocusNode.dispose();
    _controller.dispose();
    
    // Desconectar e limpar o socket
    socket.disconnect();
    socket.close();
    socket.destroy();
    
    // Limpar a lista de mensagens
    messages.clear();
    
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!_isMounted) return;  // Adicione esta linha
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    if (bottomInset > 0) {
      _messageFocusNode.requestFocus();
    }
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      final message = Message(
        name: 'You',
        text: _controller.text,
        to: widget.contact.id,
        timestamp: DateTime.now(),
      );
      socket.emit('message', {
        'content': message.text,
        'to': message.to,
        'timestamp': message.timestamp.toIso8601String(),
      });
      setState(() {
        messages.add(message);
      });
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1e1e1e),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2C34),
        leadingWidth: 100,
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            CircleAvatar(
              backgroundImage: _avatarImage,
              onBackgroundImageError: (exception, stackTrace) {
                if (mounted) {
                  setState(() {
                    _avatarImage = AssetImage('assets/default_avatar.png');
                  });
                }
              },
              radius: 18,
            ),
          ],
        ),
        title: Text(widget.contact.name),
      ),
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
                  focusNode: _messageFocusNode,
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