import 'package:flutter/material.dart';
import '../../../shared/services/icon_service.dart';

class IconPickerDialog extends StatelessWidget {
  const IconPickerDialog({super.key});

  static const List<Map<String, dynamic>> icons = [
    {'key': 'default', 'label': 'Стандартная', 'asset': 'assets/icons/default.png'},
    {'key': 'black', 'label': 'Чёрная', 'asset': 'assets/icons/black.png'},
    {'key': 'black _white', 'label': 'Чёрная с белым', 'asset': 'assets/icons/black_white.png'},
    {'key': 'brize', 'label': 'Бриз', 'asset': 'assets/icons/brize.png'},
    {'key': 'ing_yang', 'label': 'Инь-Ян', 'asset': 'assets/icons/ing_yang.png'},
    {'key': 'white', 'label': 'Белая', 'asset': 'assets/icons/white.png'},
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Выберите иконку'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: icons.length,
          itemBuilder: (context, index) {
            final icon = icons[index];
            return GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                await IconService.setIcon(icon['key'] as String);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Иконка "${icon['label']}" установлена')),
                  );
                }
              },
              child: Column(
                children: [
                  Expanded(
                    child: Image.asset(
                      icon['asset'] as String,
                      width: 64,
                      height: 64,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    icon['label'] as String,
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ],
    );
  }
}