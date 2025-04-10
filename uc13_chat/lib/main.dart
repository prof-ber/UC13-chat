import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'components/home_screen.dart';
import 'services/app_state.dart';
import 'services/socket_service.dart';
import 'services/user_service.dart';
import 'services/user_status_service.dart'; 

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late SocketService _socketService;
  Timer? _statusUpdateTimer; // Adicione esta linha

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _socketService = SocketService(appState);

    _statusUpdateTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _updateAllUserStatuses(appState);
    });
  }

  void _updateAllUserStatuses(AppState appState) async {
    List<String> userIds = await UserService.getAllUserIds();
    Map<String, bool> statuses = await UserStatusService.getBulkUserStatus(userIds);
    statuses.forEach((userId, isOnline) {
      appState.setUserStatus(userId, isOnline);
    });
    _socketService.updateActivity();
  }

  @override
  void dispose() {
    _socketService.disconnect();
    _statusUpdateTimer?.cancel(); // Adicione esta linha
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomeScreen());
  }
}