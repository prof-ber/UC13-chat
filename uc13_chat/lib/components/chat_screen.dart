import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:mobx/mobx.dart';
import 'list_message.dart';
import '../entities/message_entity.dart';
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
  final TextEditingController _controller = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  late IO.Socket socket;
  String connectionStatus = 'Disconnected';
  final ObservableList<Message> messages = ObservableList<Message>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectToSocketIO();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messageFocusNode.hasFocus) {
        _messageFocusNode.unfocus();
      }
      _messageFocusNode.requestFocus();
    });
  }

  void _connectToSocketIO() {
    socket = IO.io('http://$SERVER_IP:3000', <String, dynamic>{
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
        to: widget.contact.id,
        timestamp: DateTime.now(),
      );
      socket.emit('message', message.toJson());
      setState(() {
        messages.add(message);
      });
      _controller.clear();

      _messageFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageFocusNode.dispose();
    _controller.dispose();
    socket.disconnect();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    if (bottomInset > 0) {
      _messageFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contact.name),
        backgroundColor: const Color(0xFF252526),
      ),
      backgroundColor: const Color(0xFF1e1e1e),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            color: const Color(0xFF252526),
            child: Text(
              connectionStatus,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFd4d4d4),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFF1e1e1e),
              child: ListMessageView(messages: messages),
            ),
          ),
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
