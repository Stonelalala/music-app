import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' as rendering;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/mini_player.dart';
import '../home/home_page.dart';
import '../library/library_page.dart';
import '../discovery/discovery_page.dart';
import '../settings/settings_page.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _isVisible = true;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final colorScheme = Theme.of(context).colorScheme;

    int currentIndex = 0;
    if (location.startsWith('/home')) currentIndex = 0;
    if (location.startsWith('/library')) currentIndex = 1;
    if (location.startsWith('/discovery')) currentIndex = 2;
    if (location.startsWith('/my')) currentIndex = 3;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // 页面主要内容
          NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction == rendering.ScrollDirection.reverse) {
                if (_isVisible) setState(() => _isVisible = false);
              } else if (notification.direction ==
                  rendering.ScrollDirection.forward) {
                if (!_isVisible) setState(() => _isVisible = true);
              }
              return false;
            },
            child: IndexedStack(
              index: currentIndex,
              children: const [
                HomePage(),
                LibraryPage(),
                DiscoveryPage(),
                SettingsPage(),
              ],
            ),
          ),
          // 悬浮层：迷你播放器和底部导航
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              offset: _isVisible ? Offset.zero : const Offset(0, 1.2),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
              child: SafeArea(
                top: false,
                bottom: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 迷你播放器
                    const MiniPlayer(),
                    // 底部导航菜单
                    Padding(
                      padding: const EdgeInsets.fromLTRB(36, 0, 36, 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainer.withValues(
                                alpha: 0.78,
                              ),
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.18,
                                ),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
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
                                  Icons.person,
                                  Icons.person_outline,
                                  '我的',
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
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveColor = const Color(0xFFA1A1AA); // zinc-400

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
            context.go('/my');
            break;
        }
      },
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
