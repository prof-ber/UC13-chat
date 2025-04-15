import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'components/home_screen.dart';
import 'services/app_state.dart';
import 'services/socket_service.dart';
import 'services/user_service.dart';
import 'services/user_status_service.dart'; 
import 'components/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  // Garante que os widgets estejam inicializados antes de fazer qualquer operação
  WidgetsFlutterBinding.ensureInitialized();
  
  // Pré-carrega as fontes do Google Fonts para melhor desempenho
  await GoogleFonts.pendingFonts([
    GoogleFonts.roboto(),
    GoogleFonts.lato(),
    GoogleFonts.openSans(),
    GoogleFonts.montserrat(),
    GoogleFonts.poppins(),
    GoogleFonts.raleway(),
    GoogleFonts.ubuntu(),
    GoogleFonts.playfairDisplay(),
    GoogleFonts.merriweather(),
    GoogleFonts.sourceSansPro(),
  ]);
  
  // Inicializa o tema e carrega as preferências salvas
  final appTheme = AppTheme();
  await appTheme.loadPreferences();
  
  // Inicializa o estado do aplicativo
  final appState = AppState();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: appTheme),
      ],
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
  Timer? _statusUpdateTimer;

  @override
  void initState() {
    super.initState();
    // Inicializa o serviço de socket
    final appState = Provider.of<AppState>(context, listen: false);
    _socketService = SocketService(appState);

    // Configura o timer para atualizar o status dos usuários a cada 30 segundos
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateAllUserStatuses(appState);
    });
  }

  // Atualiza o status de todos os usuários
  void _updateAllUserStatuses(AppState appState) async {
    try {
      List<String> userIds = await UserService.getAllUserIds();
      Map<String, bool> statuses = await UserStatusService.getBulkUserStatus(userIds);
      statuses.forEach((userId, isOnline) {
        appState.setUserStatus(userId, isOnline);
      });
      _socketService.updateActivity();
    } catch (e) {
      print('Erro ao atualizar status dos usuários: $e');
    }
  }

  @override
  void dispose() {
    // Limpa recursos quando o widget é removido
    _socketService.disconnect();
    _statusUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppTheme>(
      builder: (context, appTheme, child) {
        return MaterialApp(
          title: 'UC13 Chat',
          debugShowCheckedModeBanner: false, // Remove a faixa de debug
          theme: appTheme.lightTheme,
          darkTheme: appTheme.darkTheme,
          themeMode: appTheme.themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}