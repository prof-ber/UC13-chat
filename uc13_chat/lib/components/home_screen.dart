import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'login_screen.dart';
import 'signup.dart';
import 'profile_picture.dart';
import 'contacts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (!appState.initialDataLoaded) {
      await _checkLoginStatus();
      appState.setInitialDataLoaded(true);
    }
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getString('userId');
    if (storedUserId != null) {
      setLoggedIn(true, storedUserId);
    }
  }

  void setLoggedIn(bool value, String? newUserId) {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setLoggedIn(value, newUserId);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('token');
    setLoggedIn(false, null);
  }

  void _navigateToContacts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ContactsScreen()),
    );
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(setLoggedIn: setLoggedIn),
      ),
    );
  }

  void _navigateToCadastro() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CadastroScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat App')),
      body: Center(
        child: Consumer<AppState>(
          builder: (context, appState, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (appState.isLoggedIn && appState.userId != null)
                  ProfilePicture(userId: appState.userId!),
                const SizedBox(height: 20),
                if (appState.isLoggedIn) ...[
                  ElevatedButton(
                    onPressed: _navigateToContacts,
                    child: const Text('Contatos'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _logout, child: const Text('Logout')),
                ] else ...[
                  ElevatedButton(
                    onPressed: _navigateToLogin,
                    child: const Text('Login'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _navigateToCadastro,
                    child: const Text('Cadastrar'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}