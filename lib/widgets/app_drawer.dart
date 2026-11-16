import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myradio1/providers/localization_provider.dart';
import 'package:myradio1/providers/sleep_timer_provider.dart';
import 'package:myradio1/providers/theme_provider.dart';
import 'package:myradio1/screens/add_station_screen.dart';
import 'package:myradio1/screens/drive_mode_screen.dart';
import 'package:myradio1/screens/recordings_screen.dart';
import 'package:myradio1/services/share_service.dart';
import 'package:myradio1/theme/app_theme.dart';

class AppDrawer extends ConsumerWidget {
  final VoidCallback onGoHome;

  const AppDrawer({
    super.key,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final timerState = ref.watch(sleepTimerProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: const Icon(Icons.radio_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.get('app_title', lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الإصدار 1.1.0 Pro',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  // 1. Home
                  ListTile(
                    leading: const Icon(Icons.home_rounded, color: AppTheme.primary),
                    title: Text(
                      AppStrings.get('home', lang),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onGoHome();
                    },
                  ),
                  const Divider(indent: 16, endIndent: 16, height: 1),

                  // 2. Dark / Light Mode Switch
                  SwitchListTile(
                    secondary: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: isDark ? AppTheme.secondary : Colors.amber,
                    ),
                    title: Text(
                      isDark ? AppStrings.get('theme_dark', lang) : AppStrings.get('theme_light', lang),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    value: isDark,
                    onChanged: (val) {
                      ref.read(themeModeProvider.notifier).toggleTheme();
                    },
                  ),
                  const Divider(indent: 16, endIndent: 16, height: 1),

                  // 3. Language Setting
                  ListTile(
                    leading: const Icon(Icons.language_rounded, color: AppTheme.accentLive),
                    title: Text(
                      AppStrings.get('language', lang),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      lang == 'ar' ? 'العربية' : (lang == 'de' ? 'Deutsch' : 'English'),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            lang == 'ar' ? 'العربية' : (lang == 'de' ? 'Deutsch' : 'English'),
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, color: AppTheme.primary, size: 16),
                        ],
                      ),
                    ),
                    onTap: () {
                      _showLanguageSheet(context, ref, lang);
                    },
                  ),
                  const Divider(indent: 16, endIndent: 16, height: 1),

                  // 4. Recordings Library
                  ListTile(
                    leading: const Icon(Icons.library_music_rounded, color: AppTheme.secondary),
                    title: Text(
                      AppStrings.get('recordings_library', lang),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RecordingsScreen()),
                      );
                    },
                  ),
                  const Divider(indent: 16, endIndent: 16, height: 1),

                  // 5. Sleep Timer
                  ListTile(
                    leading: Icon(
                      Icons.timer_outlined,
                      color: timerState.isActive ? AppTheme.primary : AppTheme.textMuted,
                    ),
                    title: Text(
                      AppStrings.get('sleep_timer', lang),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    trailing: timerState.isActive
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              timerState.formattedRemaining,
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      _showSleepTimerDialog(context, ref, lang);
                    },
                  ),
                  const Divider(indent: 16, endIndent: 16, height: 1),

                  // 5b. Add Custom Station
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary),
                    title: Text(
                      AppStrings.get('add_custom_station', lang),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddStationScreen()),
                      );
                    },
                  ),
                  const Divider(indent: 16, endIndent: 16, height: 1),

                  // 5c. Drive Mode
                  ListTile(
                    leading: const Icon(Icons.directions_car_rounded, color: AppTheme.accentLive),
                    title: Text(
                      AppStrings.get('drive_mode', lang),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DriveModeScreen()),
                      );
                    },
                  ),
                  const Divider(indent: 16, endIndent: 16, height: 1),

                  // 6. About Developer Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: _buildDeveloperCard(context, lang),
                  ),

                  const Divider(indent: 16, endIndent: 16, height: 1),

                  // 7. Exit App
                  ListTile(
                    leading: const Icon(Icons.exit_to_app_rounded, color: AppTheme.accentRecord),
                    title: Text(
                      AppStrings.get('exit_app', lang),
                      style: const TextStyle(
                        color: AppTheme.accentRecord,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () => _showExitConfirmation(context, lang),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref, String lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isRtl = lang == 'ar';
        final languages = [
          {
            'code': 'ar',
            'title': 'العربية',
            'subtitle': 'Arabic',
            'flag': '🇸🇦',
          },
          {
            'code': 'en',
            'title': 'English',
            'subtitle': 'الإنجليزية',
            'flag': '🇬🇧',
          },
          {
            'code': 'de',
            'title': 'Deutsch',
            'subtitle': 'الألمانية',
            'flag': '🇩🇪',
          },
        ];

        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.language_rounded, color: AppTheme.accentLive, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      AppStrings.get('language_settings', lang),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...languages.map((l) {
                  final code = l['code']!;
                  final isSelected = lang == code;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.12)
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.6)
                            : AppTheme.border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: Text(
                        l['flag']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        l['title']!,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                          color: isSelected ? AppTheme.primary : null,
                        ),
                      ),
                      subtitle: Text(
                        l['subtitle']!,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 22)
                          : const Icon(Icons.radio_button_unchecked_rounded, color: AppTheme.textMuted, size: 20),
                      onTap: () {
                        ref.read(localeProvider.notifier).setLocale(code);
                        Navigator.pop(ctx);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSleepTimerDialog(BuildContext context, WidgetRef ref, String lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final timerState = ref.watch(sleepTimerProvider);
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                AppStrings.get('sleep_timer', lang),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (timerState.isActive) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${AppStrings.get('remaining', lang)}: ${timerState.formattedRemaining}',
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(sleepTimerProvider.notifier).cancelTimer();
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          AppStrings.get('cancel_timer', lang),
                          style: const TextStyle(color: AppTheme.accentRecord),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [15, 30, 45, 60, 90].map((mins) {
                  return ActionChip(
                    label: Text('$mins ${AppStrings.get('minutes', lang)}'),
                    backgroundColor: AppTheme.surfaceElevated,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onPressed: () {
                      ref.read(sleepTimerProvider.notifier).startTimer(mins);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${AppStrings.get('sleep_timer_set', lang)} ($mins ${AppStrings.get('minutes', lang)})')),
                      );
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeveloperCard(BuildContext context, String lang) {
    const devName = 'حسن عبيد';
    const devEmail = 'ithasan4@gmail.com';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.surfaceElevated : AppTheme.lightSurfaceElevated;
    final btnBg = isDark ? AppTheme.surface : AppTheme.lightSurface;
    final borderCol = isDark ? AppTheme.border : AppTheme.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  AppStrings.get('about_dev', lang),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                      child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            devName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            devEmail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: 'نسخ المعلومات',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Clipboard.setData(
                              const ClipboardData(text: 'المطور: $devName\nالبريد الإلكتروني: $devEmail'),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppStrings.get('copied', lang))),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: btnBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderCol),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy_rounded, size: 14, color: AppTheme.primary),
                                SizedBox(width: 4),
                                Text(
                                  'نسخ',
                                  style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'مشاركة المعلومات',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            final shareText = AppStrings.get('share_dev_info', lang);
                            final launched = await ShareService.shareText(
                              shareText,
                              subject: AppStrings.get('share_title', lang),
                            );
                            if (!launched && context.mounted) {
                              _showShareDialog(context, lang, devName, devEmail);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: btnBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderCol),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.share_rounded, size: 14, color: AppTheme.secondary),
                                SizedBox(width: 4),
                                Text(
                                  'مشاركة',
                                  style: TextStyle(fontSize: 11, color: AppTheme.secondary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(BuildContext context, String lang, String devName, String devEmail) {
    final shareContent = AppStrings.get('share_dev_info', lang);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.share_rounded, color: AppTheme.secondary),
            const SizedBox(width: 10),
            Text(AppStrings.get('share_title', lang), style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: SelectableText(
                shareContent,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: shareContent));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppStrings.get('copied', lang))),
              );
            },
            child: const Text('نسخ للنشر'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
            ),
            child: Text(AppStrings.get('cancel', lang)),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation(BuildContext context, String lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.accentRecord),
            const SizedBox(width: 10),
            Text(
              AppStrings.get('exit_confirm_title', lang),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          AppStrings.get('exit_confirm_msg', lang),
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppStrings.get('cancel', lang),
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              SystemNavigator.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRecord,
              foregroundColor: Colors.white,
            ),
            child: Text(AppStrings.get('exit', lang)),
          ),
        ],
      ),
    );
  }
}
