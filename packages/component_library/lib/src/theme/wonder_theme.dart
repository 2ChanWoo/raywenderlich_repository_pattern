import 'package:component_library/src/theme/wonder_theme_data.dart';
import 'package:flutter/material.dart';

class WonderTheme extends InheritedWidget {
  const WonderTheme({
    required Widget child,
    required this.lightTheme,
    required this.darkTheme,
    Key? key,
  }) : super(
          key: key,
          child: child,
        );

  final WonderThemeData lightTheme;
  final WonderThemeData darkTheme;

  @override
  /// 상속하는 모든 위젯에 알림을 보내, WonderTheme을 재구축. 변경사항을 반영한다.
  /// 기존 위젯의 어둡거나 밝은 테마가 변경될 테마와 다른 경우에만 단독으로 알려줍니다! - 불필요한 리빌드 방지
  bool updateShouldNotify(
    WonderTheme oldWidget,
  ) =>
      oldWidget.lightTheme != lightTheme || oldWidget.darkTheme != darkTheme;

  static WonderThemeData of(BuildContext context) {
    /// 위젯 트리에서 가장 가까운 위젯을 가져와 변수에 저장합니다.
    final WonderTheme? inheritedTheme =
        context.dependOnInheritedWidgetOfExactType<WonderTheme>();

    /// 해당 유형의 위젯이 위젯트리에 없으면 중단됩니다.
    ///! 이는 개발 프로세스 중에 중요하다?!
    assert(inheritedTheme != null, 'No WonderTheme found in context');

    /// 현재 밝기를 저장합니다.
    final currentBrightness = Theme.of(context).brightness;

    /// 현재 밝기에 따라, 밝거나 어두운 테마를 변환합니다.
    return currentBrightness == Brightness.dark
        ? inheritedTheme!.darkTheme
        : inheritedTheme!.lightTheme;
  }
}
