import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../services/cache_service.dart';
import '../services/update_service.dart';
import '../version.dart';
import 'edit_profile_screen.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  String _appVersion = AppVersion.version;
  String _buildNumber = AppVersion.buildNumber.toString();
  
  @override
  void initState() {
    super.initState();
    _getAppVersion();
  }
  
  Future<void> _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }
  
  Future<void> _checkForUpdates() async {
    final updateInfo = await UpdateService.checkForUpdates();
    if (updateInfo != null && mounted) {
      await UpdateService.showUpdateDialog(context, updateInfo);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У вас последняя версия приложения')),
      );
    }
  }

  Future<void> _showWallpaperPicker(SettingsProvider settings) async {
    final List<Map<String, dynamic>> builtInWallpapers = [
      {'name': 'Градиент синий', 'color1': Colors.blue, 'color2': Colors.purple, 'isGradient': true},
      {'name': 'Градиент зелёный', 'color1': Colors.green, 'color2': Colors.teal, 'isGradient': true},
      {'name': 'Градиент оранжевый', 'color1': Colors.orange, 'color2': Colors.red, 'isGradient': true},
      {'name': 'Сплошной цвет', 'color': Colors.grey.shade100, 'isGradient': false},
      {'name': 'Тёмный', 'color': Colors.grey.shade900, 'isGradient': false},
    ];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Встроенные обои', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ...builtInWallpapers.map((wallpaper) => ListTile(
                    leading: wallpaper['isGradient'] == true
                        ? Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [wallpaper['color1'], wallpaper['color2']],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          )
                        : Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: wallpaper['color'],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                          ),
                    title: Text(wallpaper['name']),
                    onTap: () {
                      if (wallpaper['isGradient'] == true) {
                        settings.setWallpaperGradient([
                          wallpaper['color1'].value,
                          wallpaper['color2'].value,
                        ]);
                      } else {
                        settings.setWallpaperColor(wallpaper['color'].value);
                      }
                      Navigator.pop(context);
                    },
                  )),
                  
                  const Divider(),
                  
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Своё изображение', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Выбрать из галереи'),
                    onTap: () async {
                      final picker = ImagePicker();
                      final file = await picker.pickImage(source: ImageSource.gallery);
                      if (file != null) {
                        // Здесь можно сохранить изображение в Firebase Storage
                        // settings.setWallpaperImage(file.path);
                      }
                      Navigator.pop(context);
                    },
                  ),
                  
                  if (settings.wallpaperUrl != null || settings.wallpaperColor != null)
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: const Text('Удалить обои', style: TextStyle(color: Colors.red)),
                      onTap: () {
                        settings.clearWallpaper();
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: isLight ? Colors.grey.shade50 : const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Настройки'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: isLight ? Colors.white : null,
        foregroundColor: isLight ? Colors.black : null,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Профиль
          _buildProfileSection(isLight),
          const Divider(height: 1),
          
          // Внешний вид
          _buildAppearanceSection(settingsProvider, themeProvider, isLight),
          const Divider(height: 1),
          
          // Чаты
          _buildChatSection(isLight),
          const Divider(height: 1),
          
          // Кэш
          _buildCacheSection(isLight),
          const Divider(height: 1),
          
          // Обновления
          _buildUpdateSection(isLight),
          const Divider(height: 1),
          
          // О приложении
          _buildAboutSection(isLight),
          const Divider(height: 1),
          
          // Выход
          _buildLogoutSection(isLight),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }
  
  Widget _buildProfileSection(bool isLight) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final nickname = data?['nickname'] ?? currentUser.email?.split('@')[0];
        final photoUrl = data?['photoUrl'];
        
        return ListTile(
          leading: CircleAvatar(
            radius: 30,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null ? const Icon(Icons.person, size: 30) : null,
          ),
          title: Text(
            nickname ?? 'Пользователь',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isLight ? Colors.black87 : Colors.white,
            ),
          ),
          subtitle: Text(
            currentUser.email ?? '',
            style: TextStyle(
              color: isLight ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            );
          },
        );
      },
    );
  }
  
  Widget _buildAppearanceSection(SettingsProvider settings, ThemeProvider theme, bool isLight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Внешний вид',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isLight ? Colors.grey.shade700 : Colors.grey.shade400,
            ),
          ),
        ),
        ListTile(
          leading: Icon(Icons.brightness_6, color: isLight ? Colors.grey.shade700 : Colors.grey.shade400),
          title: Text('Тема', style: TextStyle(color: isLight ? Colors.black87 : Colors.white)),
          subtitle: Text(
            _getThemeModeName(theme.themeMode),
            style: TextStyle(color: isLight ? Colors.grey.shade600 : Colors.grey.shade500),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showThemePicker(theme),
        ),
        ListTile(
          leading: Icon(Icons.color_lens, color: isLight ? Colors.grey.shade700 : Colors.grey.shade400),
          title: Text('Акцентный цвет', style: TextStyle(color: isLight ? Colors.black87 : Colors.white)),
          subtitle: Text(
            _getColorName(settings.accentColor),
            style: TextStyle(color: isLight ? Colors.grey.shade600 : Colors.grey.shade500),
          ),
          trailing: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: settings.accentColor,
              shape: BoxShape.circle,
            ),
          ),
          onTap: () => _showColorPicker(settings),
        ),
        ListTile(
          leading: Icon(Icons.text_fields, color: isLight ? Colors.grey.shade700 : Colors.grey.shade400),
          title: Text('Размер шрифта', style: TextStyle(color: isLight ? Colors.black87 : Colors.white)),
          subtitle: Text(
            '${settings.fontSize.toStringAsFixed(0)} pt',
            style: TextStyle(color: isLight ? Colors.grey.shade600 : Colors.grey.shade500),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showFontSizePicker(settings),
        ),
        ListTile(
          leading: Icon(Icons.wallpaper, color: isLight ? Colors.grey.shade700 : Colors.grey.shade400),
          title: Text('Обои чата', style: TextStyle(color: isLight ? Colors.black87 : Colors.white)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showWallpaperPicker(settings),
        ),
      ],
    );
  }
  
  Widget _buildChatSection(bool isLight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Чаты',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isLight ? Colors.grey.shade700 : Colors.grey.shade400,
            ),
          ),
        ),
        SwitchListTile(
          title: Text('Показывать аватарки', style: TextStyle(color: isLight ? Colors.black87 : Colors.white)),
          value: true,
          onChanged: (value) {},
        ),
        SwitchListTile(
          title: Text('Отправка по Enter', style: TextStyle(color: isLight ? Colors.black87 : Colors.white)),
          value: true,
          onChanged: (value) {},
        ),
      ],
    );
  }
  
  Widget _buildCacheSection(bool isLight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Кэш',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isLight ? Colors.grey.shade700 : Colors.grey.shade400,
            ),
          ),
        ),
        FutureBuilder<int>(
          future: CacheService.getCacheSize(),
          builder: (context, snapshot) {
            final size = snapshot.data ?? 0;
            return ListTile(
              leading: Icon(Icons.storage, color: isLight ? Colors.grey.shade700 : Colors.grey.shade400),
              title: Text('Размер кэша', style: TextStyle(color: isLight ? Colors.black87 : Colors.white)),
              subtitle: Text('$size МБ', style: TextStyle(color: isLight ? Colors.grey.shade600 : Colors.grey.shade500)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showCacheOptions(size),
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildUpdateSection(bool isLight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Обновления',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isLight ? Colors.grey.shade700 : Colors.grey.shade400,
            ),
          ),
        ),
        ListTile(
          leading: Icon(Icons.update, color: isLight ? Colors.grey.shade700 : Colors.grey.shade400),
          title: Text('Проверить обновления', style: TextStyle(color: isLight ? Colors.black87 : Colors.white)),
          subtitle: Text('Текущая версия: $_appVersion ($_buildNumber)', style: TextStyle(color: isLight ? Colors.grey.shade600 : Colors.grey.shade500)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _checkForUpdates,
        ),
      ],
    );
  }
  
  Widget _buildAboutSection(bool isLight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'О приложении',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isLight ? Colors.grey.shade700 : Colors.grey.shade400,
            ),
          ),
        ),
        ListTile(
          leading: Icon(Icons.info, color: isLight ? Colors.grey.shade700 : Colors.grey.shade400),
          title: Text('Версия', style: TextStyle(color: isLight ? Colors.black87 : Colors.white)),
          subtitle: Text('$_appVersion ($_buildNumber)', style: TextStyle(color: isLight ? Colors.grey.shade600 : Colors.grey.shade500)),
          onTap: () => _showAboutDialog(),
        ),
        // AboutSection(isLight: isLight),
      ],
    );
  }
  
  Widget _buildLogoutSection(bool isLight) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ElevatedButton(
          onPressed: () => _showLogoutDialog(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Выйти из аккаунта'),
        ),
      ),
    );
  }
  
  void _showThemePicker(ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.light_mode),
            title: const Text('Светлая'),
            trailing: theme.themeMode == ThemeMode.light ? const Icon(Icons.check, color: Colors.blue) : null,
            onTap: () {
              theme.setTheme(ThemeMode.light);
              Navigator.pop(context);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Тёмная'),
            trailing: theme.themeMode == ThemeMode.dark ? const Icon(Icons.check, color: Colors.blue) : null,
            onTap: () {
              theme.setTheme(ThemeMode.dark);
              Navigator.pop(context);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.smartphone),
            title: const Text('Системная'),
            trailing: theme.themeMode == ThemeMode.system ? const Icon(Icons.check, color: Colors.blue) : null,
            onTap: () {
              theme.setTheme(ThemeMode.system);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  
  void _showColorPicker(SettingsProvider settings) {
    final colors = [
      Colors.blue, Colors.green, Colors.red, 
      Colors.purple, Colors.orange, Colors.teal,
      Colors.pink, Colors.indigo
    ];
    final colorNames = [
      'Синий', 'Зелёный', 'Красный', 
      'Фиолетовый', 'Оранжевый', 'Бирюзовый',
      'Розовый', 'Индиго'
    ];
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Wrap(
        children: List.generate(colors.length, (index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: colors[index],
              radius: 16,
            ),
            title: Text(colorNames[index]),
            trailing: settings.accentColor == colors[index] 
                ? const Icon(Icons.check, color: Colors.blue) 
                : null,
            onTap: () {
              settings.setAccentColor(colors[index]);
              Navigator.pop(context);
            },
          );
        }),
      ),
    );
  }
  
  void _showFontSizePicker(SettingsProvider settings) {
    double tempSize = settings.fontSize;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Размер шрифта'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${tempSize.toStringAsFixed(0)} pt',
                  style: TextStyle(fontSize: tempSize),
                ),
                const SizedBox(height: 20),
                Slider(
                  value: tempSize,
                  min: 12,
                  max: 24,
                  divisions: 12,
                  label: tempSize.toStringAsFixed(0),
                  onChanged: (value) {
                    setState(() {
                      tempSize = value;
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              settings.setFontSize(tempSize);
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
  
  void _showCacheOptions(int currentSize) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистка кэша'),
        content: Text('Текущий размер кэша: $currentSize МБ\n\nОчистить кэш?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              await CacheService.clearCache();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Кэш очищен')),
                );
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }
  
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ChatiX'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Мессенджер с открытым исходным кодом'),
            const SizedBox(height: 8),
            Text('Версия: $_appVersion ($_buildNumber)'),
            const SizedBox(height: 8),
            const Text('Сделано командой © 2026 Duality Project'),
            const Text('Github: https://github.com/onex01/ChatiX'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
  
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти из аккаунта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }
  
  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'Светлая';
      case ThemeMode.dark: return 'Тёмная';
      case ThemeMode.system: return 'Системная';
      default: return 'Системная';
    }
  }
  
  String _getColorName(Color color) {
    if (color == Colors.blue) return 'Синий';
    if (color == Colors.green) return 'Зелёный';
    if (color == Colors.red) return 'Красный';
    if (color == Colors.purple) return 'Фиолетовый';
    if (color == Colors.orange) return 'Оранжевый';
    if (color == Colors.teal) return 'Бирюзовый';
    if (color == Colors.pink) return 'Розовый';
    if (color == Colors.indigo) return 'Индиго';
    return 'Кастомный';
  }
}

// Отдельный виджет для информации о приложении
// class AboutSection extends StatelessWidget {
//   final bool isLight;
  
//   const AboutSection({super.key, required this.isLight});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.all(16),
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: isLight ? Colors.grey.shade50 : const Color(0xFF1C1C1E),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(
//           color: isLight ? Colors.grey.shade200 : Colors.grey.shade800,
//         ),
//       ),
//       child: Column(
//         children: [
//           const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.blue),
//           const SizedBox(height: 12),
//           Text(
//             'ChatiX',
//             style: TextStyle(
//               fontSize: 24,
//               fontWeight: FontWeight.bold,
//               color: isLight ? Colors.black87 : Colors.white,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Мессенджер с открытым исходным кодом',
//             style: TextStyle(
//               fontSize: 12,
//               color: isLight ? Colors.grey.shade600 : Colors.grey.shade400,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Сделано командой © 2026 Duality Project',
//             style: TextStyle(
//               fontSize: 12,
//               color: isLight ? Colors.grey.shade500 : Colors.grey.shade500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }