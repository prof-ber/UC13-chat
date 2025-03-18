import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(body: Center(child: MessageSender())));
  }
}

class MessageSender extends StatefulWidget {
  const MessageSender({super.key});

  @override
  MessageSenderState createState() => MessageSenderState();
}

class MessageSenderState extends State<MessageSender> {
  final TextEditingController _controller = TextEditingController();
  late IO.Socket socket;
  String connectionStatus = 'Disconnected';

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
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      socket.emit('message', _controller.text);
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(connectionStatus),
        SizedBox(height: 20),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Enter message',
          ),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: connectionStatus == 'Connected' ? _sendMessage : null,
          child: Text('Send Message'),
        ),
        SizedBox(height: 20),
        ElevatedButton(onPressed: _connectToSocketIO, child: Text('Reconnect')),
      ],
    );
  }
}
