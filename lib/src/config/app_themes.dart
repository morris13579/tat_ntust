import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_colors.dart';

class AppThemes {
  static final lightTheme = ThemeData(
    fontFamily: 'MyFont',
    brightness: Brightness.light,
    backgroundColor: AppColors.lightBG,
    primaryColor: AppColors.mainColor,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.lightAccent,
    ),
    appBarTheme: const AppBarTheme(color: AppColors.mainColor),
    toggleableActiveColor: Colors.blue,
    dividerColor: const Color(0xFFF8F8F8),
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: AppColors.lightBG,
    iconTheme: const IconThemeData(
        color: Colors.black
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(
      primaryColor: AppColors.mainColor,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.black,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: Colors.black12,
        foregroundColor: Colors.black,
      ),
    ),
  ).copyWith(
    colorScheme:
        ThemeData().colorScheme.copyWith(secondary: AppColors.lightAccent),
  );

  static final darkTheme = ThemeData(
          fontFamily: "MyFont",
          useMaterial3: false,
          brightness: Brightness.dark,
          backgroundColor: AppColors.darkBG,
          primaryColor: AppColors.darkPrimary,
          primarySwatch: AppColors.mainColor,
          scaffoldBackgroundColor: AppColors.darkBG,
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: AppColors.darkAccent,
          ),
          iconTheme: const IconThemeData(
            color: Colors.white
          ),
          appBarTheme: const AppBarTheme(color: AppColors.darkAccent),
          toggleableActiveColor: Colors.blueAccent,
          dividerColor: const Color(0xFF2F2F2F),
          cupertinoOverrideTheme: const CupertinoThemeData(
            primaryColor: AppColors.darkAccent,
          ),
          buttonTheme: const ButtonThemeData(buttonColor: AppColors.darkAccent),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: Colors.white12,
              foregroundColor: Colors.white,
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              selectedItemColor: Colors.blue))
      .copyWith(
    colorScheme:
        ThemeData().colorScheme.copyWith(secondary: AppColors.darkAccent),
  );
}
