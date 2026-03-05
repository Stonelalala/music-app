import 'dart:ui';
import 'package:flutter/material.dart';

class ModernToast extends StatelessWidget {
  final String message;
  final IconData? icon;
  final bool isError;

  const ModernToast({
    super.key,
    required this.message,
    this.icon,
    this.isError = false,
  });

  static void show(
    BuildContext context,
    String message, {
    IconData? icon,
    bool isError = false,
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayEntry = OverlayEntry(
      builder: (context) => Center(
        child: ModernToast(message: message, icon: icon, isError: isError),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(duration, () {
      overlayEntry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: (isError ? Colors.red : colorScheme.surface).withOpacity(
                0.7,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: (isError ? Colors.red : colorScheme.primary).withOpacity(
                  0.2,
                ),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: isError ? Colors.white : colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isError ? Colors.white : colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
