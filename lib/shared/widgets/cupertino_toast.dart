import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CupertinoToast {
  CupertinoToast._();

  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 1400),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _currentEntry?.remove();
    _currentEntry = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CupertinoToastView(
        message: message,
        icon: icon,
        duration: duration,
        onDismiss: () {
          if (_currentEntry == entry) {
            _currentEntry = null;
          }
          entry.remove();
        },
      ),
    );
    overlay.insert(entry);
    _currentEntry = entry;
  }
}

class _CupertinoToastView extends StatefulWidget {
  const _CupertinoToastView({
    required this.message,
    required this.duration,
    required this.onDismiss,
    this.icon,
  });

  final String message;
  final IconData? icon;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_CupertinoToastView> createState() => _CupertinoToastViewState();
}

class _CupertinoToastViewState extends State<_CupertinoToastView>
    with SingleTickerProviderStateMixin {
  static const Duration _fadeDuration = Duration(milliseconds: 200);

  late final AnimationController _controller;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _fadeDuration);
    _controller.forward();
    _dismissTimer = Timer(widget.duration, _beginDismiss);
  }

  Future<void> _beginDismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    widget.onDismiss();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? const Color(0xE5F2F2F7)
        : const Color(0xE51C1C1E);
    final fg = isDark ? CupertinoColors.black : CupertinoColors.white;

    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Align(
            alignment: const Alignment(0, 0.72),
            child: FadeTransition(
              opacity: _controller,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1).animate(
                  CurvedAnimation(parent: _controller, curve: Curves.easeOut),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: 18, color: fg),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              color: fg,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
