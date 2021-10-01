import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_colors.dart';

class AppThemes {
  static final lightTheme = ThemeData(
    fontFamily: 'MyFont',
    brightness: Brightness.light,
    backgroundColor: AppColors.lightBG,
    primaryColor: AppColors.mainColor,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.lightAccent,
    ),
    appBarTheme: AppBarTheme(color: AppColors.mainColor),
    toggleableActiveColor: Colors.blue,
    dividerColor: Color(0xFFF8F8F8),
    scaffoldBackgroundColor: AppColors.lightBG,
    cupertinoOverrideTheme: CupertinoThemeData(
      primaryColor: AppColors.mainColor,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        primary: Colors.black,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        primary: Colors.black12,
        onPrimary: Colors.black,
      ),
    ),
  ).copyWith(
    colorScheme:
        ThemeData().colorScheme.copyWith(secondary: AppColors.lightAccent),
  );

  static final darkTheme = ThemeData(
    fontFamily: 'MyFont',
    brightness: Brightness.dark,
    backgroundColor: AppColors.darkBG,
    primaryColor: AppColors.darkPrimary,
    scaffoldBackgroundColor: AppColors.darkBG,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.darkAccent,
    ),
    appBarTheme: AppBarTheme(color: AppColors.darkAccent),
    toggleableActiveColor: Colors.blueAccent,
    dividerColor: Color(0xFF2F2F2F),
    cupertinoOverrideTheme: CupertinoThemeData(
      primaryColor: AppColors.darkAccent,
    ),
    buttonTheme: ButtonThemeData(buttonColor: AppColors.darkAccent),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        primary: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        primary: Colors.white12,
        onPrimary: Colors.white,
      ),
    ),
  ).copyWith(
    colorScheme:
        ThemeData().colorScheme.copyWith(secondary: AppColors.darkAccent),
  );
}
