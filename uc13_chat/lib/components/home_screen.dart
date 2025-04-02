import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'chat_screen.dart';
import 'signup.dart';
import 'profile_picture.dart';
import 'contacts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isLoggedIn = false;
  String? userId;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getString('userId');
    if (storedUserId != null) {
      setState(() {
        isLoggedIn = true;
        userId = storedUserId;
      });
    }
  }

  void setLoggedIn(bool value, String? newUserId) {
    setState(() {
      isLoggedIn = value;
      userId = newUserId;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('token');
    setLoggedIn(false, null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoggedIn && userId != null) ProfilePicture(userId: userId!),
            const SizedBox(height: 20),
            if (isLoggedIn) ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ContactsScreen()),
                  );
                },
                child: const Text('Contatos'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _logout, child: const Text('Logout')),
            ] else ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => LoginScreen(setLoggedIn: setLoggedIn),
                    ),
                  );
                },
                child: const Text('Login'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CadastroScreen()),
                  );
                },
                child: const Text('Cadastrar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
