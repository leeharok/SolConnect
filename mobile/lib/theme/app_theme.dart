import 'package:material_ui/material_ui.dart';

/// 솔커넥트 디자인 토큰
class AppColors {
  AppColors._();

  static const primary = Color(0xFF305035); // 테마색
  static const accent = Color(0xFFF1C15B); // 강조색
  static const background = Color(0xFFFBF8F3); // 배경색
  static const text = Color(0xFF1A1A1A); // 글자색

  static const textSub = Color(0xFF8A8A8A);
  static const hint = Color(0xFFB5B5B5);
  static const border = Color(0xFFDADADA);
  static const placeholder = Color(0xFFD9D9D9);
  static const white = Colors.white;
  static const error = Color(0xFFD64545);
}

class AppFonts {
  AppFonts._();

  /// 앱 이름·화면 제목 (학교안심 모험가). pubspec.yaml에 등록 전에는 기본 폰트로 대체됨.
  static const display = 'SchoolSafeAdventurer';

  /// 본문
  static const body = 'Pretendard';
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle logo({double size = 28}) => TextStyle(
        fontFamily: AppFonts.display,
        fontFamilyFallback: const [AppFonts.body],
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
        letterSpacing: -0.5,
      );

  static const title = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: [AppFonts.body],
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
  );

  static const sectionTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  static const caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSub,
  );
}

class AppTheme {
  AppTheme._();

  static const radius = 10.0;

  static ThemeData get light {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppFonts.body,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.white,
        secondary: AppColors.accent,
        onSecondary: AppColors.text,
        surface: AppColors.background,
        onSurface: AppColors.text,
        error: AppColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: title,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        hintStyle: const TextStyle(color: AppColors.hint, fontSize: 15),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.primary, 1.5),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error, 1.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          disabledForegroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.white),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        selectedColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(fontSize: 14, color: AppColors.text),
        secondaryLabelStyle:
            const TextStyle(fontSize: 14, color: AppColors.white),
        checkmarkColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.text,
      ),
    );
  }

  static const title = AppTextStyles.title;
}
