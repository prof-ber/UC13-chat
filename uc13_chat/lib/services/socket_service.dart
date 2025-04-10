import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state.dart';

class SocketService {
  static SocketService? _instance;
  factory SocketService(AppState appState) {
    _instance ??= SocketService._internal(appState);
    return _instance!;
  }
  
  final AppState appState;
  SocketService._internal(this.appState);

  IO.Socket? _socket;
  final String _serverIP = "172.17.9.63";
  String connectionStatus = 'Disconnected';


  Future<void> initSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      print('Token não encontrado. O usuário precisa fazer login.');
      return;
    }

    _socket = IO.io('http://$_serverIP:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'token': token},
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      connectionStatus = 'Connected';
      print('Connection established');
      _socket!.emit('authenticate', token);
    });

    _socket!.onDisconnect((_) {
      connectionStatus = 'Disconnected';
      print('Connection Disconnected');
    });

    _socket!.onConnectError((err) {
      connectionStatus = 'Connection Error: $err';
      print('Connect Error: $err');
    });
  }

  Future<void> reconnect() async {
  disconnect();
  await initSocket();
}

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.close();
    _socket?.destroy();
  }

  void updateActivity() {
    _socket?.emit('updateActivity');
  }

  bool get isConnected => _socket?.connected ?? false;
}