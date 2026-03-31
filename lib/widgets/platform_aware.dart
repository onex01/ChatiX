import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Платформозависимая кнопка
class PlatformButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;
  final bool isDestructive;
  
  const PlatformButton({
    super.key,
    required this.title,
    required this.onPressed,
    this.isDestructive = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    
    if (isIOS) {
      return CupertinoButton(
        onPressed: onPressed,
        color: isDestructive ? CupertinoColors.destructiveRed : CupertinoColors.activeBlue,
        child: Text(title),
      );
    } else {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDestructive ? Colors.red : Colors.blue,
        ),
        child: Text(title),
      );
    }
  }
}

/// Платформозависимый AlertDialog
Future<bool?> showPlatformDialog({
  required BuildContext context,
  required String title,
  required String content,
  String cancelText = 'Отмена',
  String confirmText = 'OK',
  bool isDestructive = false,
}) async {
  final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
  
  if (isIOS) {
    return await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            child: Text(cancelText),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive,
            child: Text(confirmText),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  } else {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: isDestructive ? Colors.red : Colors.blue,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}