import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({Key? key}) : super(key: key);

  @override
  _ThemeSettingsScreenState createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  // Método auxiliar para obter o estilo de texto para a visualização das fontes
  TextStyle _getGoogleFontStyle(String fontName) {
    switch (fontName) {
      case 'Roboto':
        return GoogleFonts.roboto();
      case 'Lato':
        return GoogleFonts.lato();
      case 'Open Sans':
        return GoogleFonts.openSans();
      case 'Montserrat':
        return GoogleFonts.montserrat();
      case 'Poppins':
        return GoogleFonts.poppins();
      case 'Raleway':
        return GoogleFonts.raleway();
      case 'Ubuntu':
        return GoogleFonts.ubuntu();
      case 'Playfair Display':
        return GoogleFonts.playfairDisplay();
      case 'Merriweather':
        return GoogleFonts.merriweather();
      case 'Source Sans Pro':
        return GoogleFonts.sourceSansPro();
      default:
        return TextStyle(fontFamily: fontName);
    }
  }

  void _showColorPicker(BuildContext context, Color currentColor, Function(Color) onColorChanged) {
    Color pickerColor = currentColor;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Escolha uma cor'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (Color color) {
                pickerColor = color;
              },
              pickerAreaHeightPercent: 0.8,
              enableAlpha: true,
              displayThumbColor: true,
              paletteType: PaletteType.hsv,
              pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Aplicar'),
              onPressed: () {
                onColorChanged(pickerColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalização do Tema'),
      ),
      body: Consumer<AppTheme>(
        builder: (context, appTheme, child) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Seleção de modo de tema
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Modo do Tema',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            label: Text('Claro'),
                            icon: Icon(Icons.light_mode),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            label: Text('Escuro'),
                            icon: Icon(Icons.dark_mode),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            label: Text('Sistema'),
                            icon: Icon(Icons.settings_suggest),
                          ),
                        ],
                        selected: {appTheme.themeMode},
                        onSelectionChanged: (Set<ThemeMode> selection) {
                          appTheme.setThemeMode(selection.first);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Cores das mensagens
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cores das Mensagens',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('Cor das suas mensagens'),
                        trailing: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: appTheme.fromMessageColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey),
                          ),
                        ),
                        onTap: () => _showColorPicker(
                          context,
                          appTheme.fromMessageColor,
                          (color) => appTheme.setFromMessageColor(color),
                        ),
                      ),
                      ListTile(
                        title: const Text('Cor das mensagens recebidas'),
                        trailing: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: appTheme.toMessageColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey),
                          ),
                        ),
                        onTap: () => _showColorPicker(
                          context,
                          appTheme.toMessageColor,
                          (color) => appTheme.setToMessageColor(color),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Seleção de fonte
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fonte',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: appTheme.fontFamily,
                        decoration: const InputDecoration(
                          labelText: 'Selecione a fonte',
                          border: OutlineInputBorder(),
                        ),
                        items: AppTheme.availableFonts.map((String fontName) {
                          return DropdownMenuItem<String>(
                            value: fontName,
                            child: Text(
                              fontName,
                              style: _getGoogleFontStyle(fontName),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            appTheme.setFontFamily(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Botão para resetar o tema
              ElevatedButton.icon(
                onPressed: () {
                  appTheme.resetToDefaultTheme();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tema resetado para o padrão')),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Resetar para o tema padrão'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Visualização do tema atual
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Visualização',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Column(
                          children: [
                            // Mensagem enviada
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12.0),
                                  decoration: BoxDecoration(
                                    color: appTheme.fromMessageColor,
                                    borderRadius: BorderRadius.circular(16.0),
                                  ),
                                  child: Text(
                                    'Sua mensagem',
                                    style: AppTheme.availableFonts.contains(appTheme.fontFamily)
                                        ? _getGoogleFontStyle(appTheme.fontFamily).copyWith(color: Colors.white)
                                        : TextStyle(
                                            color: Colors.white,
                                            fontFamily: appTheme.fontFamily,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Mensagem recebida
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12.0),
                                  decoration: BoxDecoration(
                                    color: appTheme.toMessageColor,
                                    borderRadius: BorderRadius.circular(16.0),
                                  ),
                                  child: Text(
                                    'Mensagem recebida',
                                    style: AppTheme.availableFonts.contains(appTheme.fontFamily)
                                        ? _getGoogleFontStyle(appTheme.fontFamily).copyWith(color: Colors.white)
                                        : TextStyle(
                                            color: Colors.white,
                                            fontFamily: appTheme.fontFamily,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}