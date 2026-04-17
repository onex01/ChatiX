import 'package:dynamic_icon_changer/dynamic_icon_changer.dart';

class IconService {
  static final _iconChanger = DynamicIconChanger();

  static const List<String> androidAliases = [
    '.MainActivityDefault',
    '.MainActivityBlack',
    '.MainActibityBlackWhite',
    '.MainActivityBrize',
    '.MainActivityIngYang',
    '.MainActivityWhite',
  ];

  /// Установить иконку по ключу (например, 'black', 'blue_white', 'default')
  static Future<void> setIcon(String key, {bool relaunch = true}) async {
    String? iosIconName;
    switch (key) {
      case 'default':
        iosIconName = null;
        break;
      case 'black':
        iosIconName = 'black';
        break;
      case 'black_white':
        iosIconName = 'black_white';
        break;
      case 'brize':
        iosIconName = 'brize';
        break;
      case 'ing_yang':
        iosIconName = 'ing_yang';
        break;
      case 'white':
        iosIconName = 'white';
        break;
      default:
        return;
    }
    await _iconChanger.setIcon(
      iosIconName,
      androidActiveAliases: androidAliases,
      relaunch: relaunch,
    );
  }
}