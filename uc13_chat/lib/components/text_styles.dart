import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TextStyles {
  // Método para obter o estilo de texto para mensagens com base na fonte selecionada
  static TextStyle getMessageTextStyle(
    String fontFamily,
    Color color, {
    double fontSize = 14.0,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    // Lista de fontes do Google que suportamos
    const googleFonts = [
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

    // Se for uma fonte do Google, usamos o pacote google_fonts
    if (googleFonts.contains(fontFamily)) {
      switch (fontFamily) {
        case 'Roboto':
          return GoogleFonts.roboto(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          );
        case 'Lato':
          return GoogleFonts.lato(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          );
        case 'Open Sans':
          return GoogleFonts.openSans(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          );
        case 'Montserrat':
          return GoogleFonts.montserrat(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          );
        case 'Poppins':
          return GoogleFonts.poppins(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          );
        case 'Raleway':
          return GoogleFonts.raleway(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          );
        case 'Ubuntu':
          return GoogleFonts.ubuntu(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          );
        case 'Playfair Display':
          return GoogleFonts.playfairDisplay(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          );
        case 'Merriweather':
          return GoogleFonts.merriweather(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          );
        case 'Source Sans Pro':
          return GoogleFonts.sourceSansPro(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          );
        default:
          return TextStyle(
            fontFamily: fontFamily,
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          );
      }
    } else {
      // Se não for uma fonte do Google, usamos o sistema padrão
      return TextStyle(
        fontFamily: fontFamily,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
      );
    }
  }
}