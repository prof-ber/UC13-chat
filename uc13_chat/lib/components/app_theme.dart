import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme with ChangeNotifier {
  static final AppTheme _instance = AppTheme._internal();
  
  factory AppTheme() {
    return _instance;
  }
  
  AppTheme._internal();
  
  // Lista de fontes disponíveis
  static const List<String> availableFonts = [
    'Roboto',
    'Lato',
    'Open Sans',
    'Montserrat',
    'Poppins',
    'Raleway',
    'Ubuntu',
    'Playfair Display',
    'Merriweather',
    'Source Sans Pro',
  ];
  
  // Tema atual
  ThemeMode _themeMode = ThemeMode.system;
  ThemeData? _customLightTheme;
  ThemeData? _customDarkTheme;
  
  // Cores padrão para o tema claro
  static const Color _defaultLightPrimary = Color(0xFF6200EE);
  static const Color _defaultLightSecondary = Color(0xFF03DAC6);
  static const Color _defaultLightBackground = Color(0xFFF5F5F5);
  static const Color _defaultLightSurface = Colors.white;
  static const Color _defaultLightError = Color(0xFFB00020);
  static const Color _defaultLightText = Color(0xFF000000);
  
  // Cores padrão para o tema escuro
  static const Color _defaultDarkPrimary = Color(0xFFBB86FC);
  static const Color _defaultDarkSecondary = Color(0xFF03DAC6);
  static const Color _defaultDarkBackground = Color(0xFF121212);
  static const Color _defaultDarkSurface = Color(0xFF1E1E1E);
  static const Color _defaultDarkError = Color(0xFFCF6679);
  static const Color _defaultDarkText = Color(0xFFFFFFFF);
  
  // Cores específicas do chat
  static const Color _defaultFromMessageColor = Color(0xFF6a0dad);
  static const Color _defaultToMessageColor = Color(0xFF00bcd4);
  static const Color _defaultFromTextColor = Colors.white;
  static const Color _defaultToTextColor = Colors.white;
  
  // Fontes
  static const String _defaultFontFamily = 'Roboto';
  
  // Getters
  ThemeMode get themeMode => _themeMode;
  ThemeData get currentTheme => _themeMode == ThemeMode.dark ? darkTheme : lightTheme;
  ThemeData get lightTheme => _customLightTheme ?? _defaultLightTheme;
  ThemeData get darkTheme => _customDarkTheme ?? _defaultDarkTheme;
  
  // Cores específicas do chat
  Color get fromMessageColor => _fromMessageColor ?? _defaultFromMessageColor;
  Color get toMessageColor => _toMessageColor ?? _defaultToMessageColor;
  Color get fromTextColor => _fromTextColor ?? _defaultFromTextColor;
  Color get toTextColor => _toTextColor ?? _defaultToTextColor;
  String get fontFamily => _fontFamily ?? _defaultFontFamily;
  
  // Cores personalizadas
  Color? _fromMessageColor;
  Color? _toMessageColor;
  Color? _fromTextColor;
  Color? _toTextColor;
  String? _fontFamily;
  
  // Tema claro padrão
  ThemeData get _defaultLightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: _defaultLightPrimary,
      colorScheme: const ColorScheme.light(
        primary: _defaultLightPrimary,
        secondary: _defaultLightSecondary,
        background: _defaultLightBackground,
        surface: _defaultLightSurface,
        error: _defaultLightError,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onBackground: _defaultLightText,
        onSurface: _defaultLightText,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: _defaultLightBackground,
      fontFamily: _defaultFontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: _defaultLightPrimary,
        foregroundColor: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: _defaultLightText),
        bodyMedium: TextStyle(color: _defaultLightText),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _defaultLightPrimary, width: 2.0),
        ),
        labelStyle: TextStyle(color: _defaultLightPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _defaultLightPrimary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
  
  // Tema escuro padrão
  ThemeData get _defaultDarkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: _defaultDarkPrimary,
      colorScheme: const ColorScheme.dark(
        primary: _defaultDarkPrimary,
        secondary: _defaultDarkSecondary,
        background: _defaultDarkBackground,
        surface: _defaultDarkSurface,
        error: _defaultDarkError,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onBackground: _defaultDarkText,
        onSurface: _defaultDarkText,
        onError: Colors.black,
      ),
      scaffoldBackgroundColor: _defaultDarkBackground,
      fontFamily: _defaultFontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: _defaultDarkSurface,
        foregroundColor: _defaultDarkText,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: _defaultDarkText),
        bodyMedium: TextStyle(color: _defaultDarkText),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _defaultDarkPrimary, width: 2.0),
        ),
        labelStyle: TextStyle(color: _defaultDarkPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _defaultDarkPrimary,
          foregroundColor: Colors.black,
        ),
      ),
    );
  }
  
  // Métodos para alterar o tema
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _savePreferences();
    notifyListeners();
  }
  
  void toggleThemeMode() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _savePreferences();
    notifyListeners();
  }
  
  // Métodos para personalizar cores específicas do chat
  void setFromMessageColor(Color color) {
    _fromMessageColor = color;
    _savePreferences();
    notifyListeners();
  }
  
  void setToMessageColor(Color color) {
    _toMessageColor = color;
    _savePreferences();
    notifyListeners();
  }
  
  // Métodos para personalizar cores de texto
  void setFromTextColor(Color color) {
    _fromTextColor = color;
    _savePreferences();
    notifyListeners();
  }
  
  void setToTextColor(Color color) {
    _toTextColor = color;
    _savePreferences();
    notifyListeners();
  }
  
  void setFontFamily(String fontFamily) {
    _fontFamily = fontFamily;
    _savePreferences();
    notifyListeners();
  }
  
  // Método para personalizar completamente o tema
  void setCustomLightTheme(ThemeData theme) {
    _customLightTheme = theme;
    _savePreferences();
    notifyListeners();
  }
  
  void setCustomDarkTheme(ThemeData theme) {
    _customDarkTheme = theme;
    _savePreferences();
    notifyListeners();
  }
  
  // Método para resetar para o tema padrão
  void resetToDefaultTheme() {
    _customLightTheme = null;
    _customDarkTheme = null;
    _fromMessageColor = null;
    _toMessageColor = null;
    _fromTextColor = null;
    _toTextColor = null;
    _fontFamily = null;
    _savePreferences();
    notifyListeners();
  }
  
  // Carregar preferências salvas
  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Carregar modo do tema
      final themeModeIndex = prefs.getInt('themeMode');
      if (themeModeIndex != null) {
        _themeMode = ThemeMode.values[themeModeIndex];
      }
      
      // Carregar cores de fundo das mensagens
      final fromMessageColorValue = prefs.getInt('fromMessageColor');
      if (fromMessageColorValue != null) {
        _fromMessageColor = Color(fromMessageColorValue);
      }
      
      final toMessageColorValue = prefs.getInt('toMessageColor');
      if (toMessageColorValue != null) {
        _toMessageColor = Color(toMessageColorValue);
      }
      
      // Carregar cores de texto das mensagens
      final fromTextColorValue = prefs.getInt('fromTextColor');
      if (fromTextColorValue != null) {
        _fromTextColor = Color(fromTextColorValue);
      }
      
      final toTextColorValue = prefs.getInt('toTextColor');
      if (toTextColorValue != null) {
        _toTextColor = Color(toTextColorValue);
      }
      
      // Carregar fonte
      final savedFontFamily = prefs.getString('fontFamily');
      if (savedFontFamily != null) {
        _fontFamily = savedFontFamily;
      }
      
      notifyListeners();
    } catch (e) {
      print('Erro ao carregar preferências: $e');
    }
  }
  
  // Salvar preferências
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Salvar modo do tema
      await prefs.setInt('themeMode', _themeMode.index);
      
      // Salvar cores de fundo das mensagens
      if (_fromMessageColor != null) {
        await prefs.setInt('fromMessageColor', _fromMessageColor!.value);
      } else {
        await prefs.remove('fromMessageColor');
      }
      
      if (_toMessageColor != null) {
        await prefs.setInt('toMessageColor', _toMessageColor!.value);
      } else {
        await prefs.remove('toMessageColor');
      }
      
      // Salvar cores de texto das mensagens
      if (_fromTextColor != null) {
        await prefs.setInt('fromTextColor', _fromTextColor!.value);
      } else {
        await prefs.remove('fromTextColor');
      }
      
      if (_toTextColor != null) {
        await prefs.setInt('toTextColor', _toTextColor!.value);
      } else {
        await prefs.remove('toTextColor');
      }
      
      // Salvar fonte
      if (_fontFamily != null) {
        await prefs.setString('fontFamily', _fontFamily!);
      } else {
        await prefs.remove('fontFamily');
      }
    } catch (e) {
      print('Erro ao salvar preferências: $e');
    }
  }
}