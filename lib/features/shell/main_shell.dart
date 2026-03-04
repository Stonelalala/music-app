import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/mini_player.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    int currentIndex = 0;
    if (location.startsWith('/home')) currentIndex = 0;
    if (location.startsWith('/library')) currentIndex = 1;
    if (location.startsWith('/discovery')) currentIndex = 2;
    if (location.startsWith('/settings')) currentIndex = 3;
    if (location.startsWith('/tasks'))
      currentIndex = 2; // Tasks map to Discovery tab

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: Stack(
        children: [
          // 页面主要内容
          child,
          // 悬浮层：迷你播放器和底部导航
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              bottom: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                // 对齐到右侧（为了搜索按钮和收起的CD）
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 迷你播放器 (会自适应宽度)
                  const MiniPlayer(),
                  // 底部导航菜单
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF1E1E1E,
                            ).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildNavItem(
                                0,
                                Icons.home,
                                Icons.home_outlined,
                                '主页',
                                currentIndex,
                                context,
                              ),
                              _buildNavItem(
                                1,
                                Icons.music_note,
                                Icons.music_note_outlined,
                                '歌曲',
                                currentIndex,
                                context,
                              ),
                              _buildNavItem(
                                2,
                                Icons.explore,
                                Icons.explore_outlined,
                                '发现',
                                currentIndex,
                                context,
                              ),
                              _buildNavItem(
                                3,
                                Icons.settings,
                                Icons.settings_outlined,
                                '设置',
                                currentIndex,
                                context,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData activeIcon,
    IconData icon,
    String label,
    int currentIndex,
    BuildContext context,
  ) {
    final isSelected = index == currentIndex;
    final color = isSelected ? AppTheme.accent : AppTheme.textSecondary;

    return GestureDetector(
      onTap: () {
        switch (index) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/library');
            break;
          case 2:
            context.go('/discovery');
            break;
          case 3:
            context.go('/settings');
            break;
        }
      },
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? activeIcon : icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
