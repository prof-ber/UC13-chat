import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:mobx/mobx.dart';
import '../entities/message_entity.dart';
import 'contacts.dart';
import '../services/gallery.dart';

final SERVER_IP = "172.17.9.224";

class ChatScreen extends StatefulWidget {
  final Contact contact;
  final User currentUser;

  const ChatScreen({Key? key, required this.contact, required this.currentUser})
    : super(key: key);

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  late IO.Socket socket;
  String connectionStatus = 'Disconnected';
  final ObservableList<Message> messages = ObservableList<Message>();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectToSocketIO();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _messageFocusNode.requestFocus(),
    );
  }

  void _connectToSocketIO() {
    socket = IO.io('http://$SERVER_IP:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      setState(() => connectionStatus = 'Connected');
      print('Connection established');
    });

    socket.onDisconnect((_) {
      setState(() => connectionStatus = 'Disconnected');
      print('Connection Disconnected');
    });

    socket.onConnectError((err) {
      setState(() => connectionStatus = 'Connection Error: $err');
      print('Connect Error: $err');
    });

    socket.on('message', (data) {
      setState(() => messages.add(Message.fromJson(data)));
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
        _controller.clear();
      });
      _messageFocusNode.requestFocus();
    }
  }

  Future<void> _uploadFile() async {
    setState(() => _isUploading = true);

    try {
      final result = await FileService.uploadFile(context);
      if (result != null) {
        final message = Message(
          name: 'You',
          text: '',
          to: widget.contact.id,
          timestamp: DateTime.now(),
          fileUrl: result['url'],
          width: result['width'],
          height: result['height'],
        );

        socket.emit('message', message.toJson());
        setState(() {
          messages.add(message);
        });
        print('File uploaded and sent successfully: ${result['url']}');
      } else {
        throw Exception('File upload failed: No URL returned');
      }
    } catch (e) {
      print('File upload error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload file: $e'),
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contact.name),
        backgroundColor: const Color(0xFF252526),
      ),
      backgroundColor: const Color(0xFF1e1e1e),
      body: SafeArea(
        child: Column(
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
            Expanded(child: ListMessageView(messages: messages)),
            Container(
              padding: const EdgeInsets.all(8.0),
              color: const Color(0xFF252526),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
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
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _isUploading ? Icons.hourglass_empty : Icons.attach_file,
                      color: Color(0xFFd4d4d4),
                    ),
                    onPressed: _isUploading ? null : _uploadFile,
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: Color(0xFFd4d4d4)),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ListMessageView extends StatelessWidget {
  final List<Message> messages;

  const ListMessageView({Key? key, required this.messages}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1e1e1e),
      child: ListView.builder(
        reverse: true,
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[messages.length - 1 - index];
          return _buildMessageItem(message);
        },
      ),
    );
  }

  Widget _buildMessageItem(Message message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment:
            message.name.toLowerCase() == 'you'
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color:
                  message.name.toLowerCase() == 'you'
                      ? Color(0xFF00bcd4)
                      : Color(0xFF6a0dad),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (message.text.isNotEmpty)
                  Text(message.text, style: TextStyle(color: Colors.white)),
                if (message.fileUrl != null)
                  Container(
                    constraints: BoxConstraints(maxWidth: 200, maxHeight: 200),
                    child: _buildMessageImage(
                      message.fileUrl,
                      message.width,
                      message.height,
                    ),
                  ),
                SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageImage(String? imageUrl, double? width, double? height) {
    if (imageUrl == null) {
      return SizedBox.shrink();
    }

    final fullImageUrl =
        imageUrl.startsWith('http')
            ? imageUrl
            : 'http://$SERVER_IP:3000$imageUrl';

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        fullImageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print("Error loading image: $error");
          return Icon(Icons.error);
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }
}
