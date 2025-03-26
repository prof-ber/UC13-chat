import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:mobx/mobx.dart';

class Message {
  final String name;
  final String text;

  Message({required this.name, required this.text});
}

class ListMessageView extends StatelessWidget {
  final List<Message> messages;

  const ListMessageView({Key? key, required this.messages}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return ListTile(
          title: Text(message.name),
          subtitle: Text(message.text),
        );
      },
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

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
        messages.add(Message(name: 'Server', text: data.toString()));
      });
    });
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      final message = Message(name: 'You', text: _controller.text);
      socket.emit('message', message.text);
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
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
          Expanded(child: ListMessageView(messages: messages)),
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
