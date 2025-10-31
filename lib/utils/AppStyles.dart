import 'package:flutter/material.dart';

class AppColors{
  static const Color primaryColor = Colors.indigo;
  static const Color dashBoardBGColor = Colors.indigoAccent;
  static const Color mainbackground = Colors.indigo;
  static const Color background = Colors.white70;
  static const Color textColor = Colors.black87;
  static const Color iconColor = Colors.black87;
  static const Color drawerHeaderColor = Colors.black;
  static const Color listTileColor = Colors.white70;
}

class AppTextStyles {
  static const TextStyle heading = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.bold,
    color: AppColors.textColor,
    fontFamily: 'GoogleSans'
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: Colors.black87,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: Colors.grey,
  );
}

class AppButtonStyles {
  static final ButtonStyle mainButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30.0),
    ),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
  );
}
