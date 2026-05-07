import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' as rendering;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/mini_player.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  final String currentLocation;
  final Widget miniPlayer;

  const MainShell({
    super.key,
    required this.child,
    required this.currentLocation,
    this.miniPlayer = const MiniPlayer(),
  });

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _isVisible = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    int currentIndex = 0;
    if (widget.currentLocation.startsWith('/home')) currentIndex = 0;
    if (widget.currentLocation.startsWith('/library')) currentIndex = 1;
    if (widget.currentLocation.startsWith('/discovery')) currentIndex = 2;
    if (widget.currentLocation.startsWith('/my')) currentIndex = 3;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
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
            child: widget.child,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              offset: _isVisible ? Offset.zero : const Offset(0, 1.2),
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      widget.miniPlayer,
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.surfaceContainerHigh.withValues(
                                    alpha: 0.92,
                                  ),
                                  colorScheme.surfaceContainer.withValues(
                                    alpha: 0.86,
                                  ),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.14,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.shadow.withValues(
                                    alpha: 0.1,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                _buildNavItem(
                                  index: 0,
                                  currentIndex: currentIndex,
                                  icon: Icons.home_rounded,
                                  outlinedIcon: Icons.home_outlined,
                                  label: '\u4e3b\u9875',
                                  onTap: () => context.go('/home'),
                                ),
                                _buildNavItem(
                                  index: 1,
                                  currentIndex: currentIndex,
                                  icon: Icons.music_note_rounded,
                                  outlinedIcon: Icons.music_note_outlined,
                                  label: '\u6b4c\u66f2',
                                  onTap: () => context.go('/library'),
                                ),
                                _buildNavItem(
                                  index: 2,
                                  currentIndex: currentIndex,
                                  icon: Icons.explore_rounded,
                                  outlinedIcon: Icons.explore_outlined,
                                  label: '\u53d1\u73b0',
                                  onTap: () => context.go('/discovery'),
                                ),
                                _buildNavItem(
                                  index: 3,
                                  currentIndex: currentIndex,
                                  icon: Icons.person_rounded,
                                  outlinedIcon: Icons.person_outline_rounded,
                                  label: '\u6211\u7684',
                                  onTap: () => context.go('/my'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required int currentIndex,
    required IconData icon,
    required IconData outlinedIcon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = index == currentIndex;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isSelected ? icon : outlinedIcon,
                  size: 20,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
