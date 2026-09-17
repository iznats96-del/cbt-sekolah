import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';

// ==================== GLASSMORPHISM CARD ====================
class GlassCard extends StatelessWidget {
  final Widget child;
  final double? borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius,
    this.backgroundColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? 16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? AppTheme.glassBackground,
            borderRadius: BorderRadius.circular(borderRadius ?? 16),
            border: Border.all(
              color: AppTheme.glassBorder,
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.1),
              ],
            ),
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ==================== SHIMMER LOADING ====================
class ShimmerLoading extends StatefulWidget {
  final int count;
  final Widget Function(int index) itemBuilder;
  final bool vertical;

  const ShimmerLoading({
    super.key,
    this.count = 5,
    required this.itemBuilder,
    this.vertical = true,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _animation = Tween(begin: 0.0, end: 1.5).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        if (widget.vertical) {
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.count,
            itemBuilder: widget.itemBuilder,
          );
        } else {
          return Row(
            children: List.generate(widget.count, widget.itemBuilder),
          );
        }
      },
    );
  }
}

class ShimmerEffect extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerEffect({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Color(0xFFE0E0E0), Color(0xFFF5F5F5), Color(0xFFE0E0E0)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// ==================== CUSTOM SCROLLBAR ====================
class CustomScrollbar extends StatelessWidget {
  final ScrollController? controller;
  final Axis direction;
  final Widget child;

  const CustomScrollbar({
    super.key,
    this.controller,
    this.direction = Axis.vertical,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: controller,
      radius: const Radius.circular(10),
      thickness: 6,
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return AppTheme.primary.withOpacity(0.7);
        }
        return AppTheme.primary.withOpacity(0.5);
      }),
      child: child,
    );
  }
}

// ==================== PULL-TO-REFRESH ====================
class PullToRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const PullToRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: 0,
      edgeOffset: 64,
      strokeWidth: 2,
      backgroundColor: Colors.transparent,
      color: AppTheme.secondary,
      child: child,
    );
  }
}

// ==================== MODERN BUTTONS ====================
class ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final ButtonType type;
  final bool isLoading;
  final Color? color;

  const ModernButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.type = ButtonType.filled,
    this.isLoading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final btnColor = color ?? AppTheme.primary;
    
    Widget content;
    if (isLoading) {
      content = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
          Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      );
    }

    switch (type) {
      case ButtonType.filled:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
          child: content,
        );
      case ButtonType.outlined:
        return OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: btnColor,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(color: btnColor, width: 1.5),
          ),
          child: content,
        );
      case ButtonType.text:
        return TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: content,
        );
    }
  }
}

enum ButtonType { filled, outlined, text }

// ==================== MODERN BOTTOM SHEET ====================
class ModernBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? subtitle,
    List<Widget>? actions,
    Widget? content,
    double? height,
    bool isDismissible = true,
    Widget Function()? footer,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation,
            curve: Curves.easeOutCubic,
          )),
          child: Container(
            height: height ?? MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (title != null || subtitle != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        const Divider(height: 24),
                      ],
                    ),
                  ),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    child: content ?? const SizedBox.shrink(),
                  ),
                ),
                if (footer != null) footer(),
                if (actions != null && actions.isNotEmpty) ...[
                  Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: actions,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== EXPANDED FAB MENU ====================
class ExpandedFabMenu extends StatefulWidget {
  final List<FabMenuItem> items;
  final IconData mainIcon;
  final Color? mainColor;
  final Duration duration;

  const ExpandedFabMenu({
    super.key,
    required this.items,
    this.mainIcon = Icons.add,
    this.mainColor,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<ExpandedFabMenu> createState() => _ExpandedFabMenuState();
}

class _ExpandedFabMenuState extends State<ExpandedFabMenu> with TickerProviderStateMixin {
  bool _isOpened = false;
  late AnimationController _controller;
  late List<AnimationController> _itemControllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _itemControllers = List.generate(widget.items.length, (_) => AnimationController(vsync: this));
    _animations = _itemControllers.map((ctrl) => Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut))).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    for (var ctrl in _itemControllers) ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpened = !_isOpened;
      if (_isOpened) {
        _controller.forward();
        for (var i = 0; i < _itemControllers.length; i++) {
          _itemControllers[i].stop();
          _itemControllers[i].value = 0;
          Future.delayed(Duration(milliseconds: i * 50), () {
            if (mounted) _itemControllers[i].forward();
          });
        }
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        ...List.generate(widget.items.length, (i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (context, _) {
              return Transform.translate(
                offset: Offset(0, -(_controller.value * 60 - widget.items.length * 60) + (1 - _animations[i].value) * 60),
                child: Opacity(
                  opacity: _animations[i].value,
                  child: FloatingActionButton.extended(
                    heroTag: 'fab_item_$i',
                    onPressed: widget.items[i].onPressed,
                    backgroundColor: widget.items[i].color ?? AppTheme.primary,
                    icon: Icon(widget.items[i].icon),
                    label: Text(widget.items[i].label),
                  ),
                ),
              );
            },
          );
        }),
        FloatingActionButton(
          heroTag: 'main_fab',
          onPressed: _toggle,
          backgroundColor: widget.mainColor ?? AppTheme.primary,
          elevation: _isOpened ? 0 : 6,
          child: AnimatedRotation(
            turns: _isOpened ? 0.5 : 0,
            duration: widget.duration,
            child: Icon(widget.mainIcon, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class FabMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  FabMenuItem({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
  });
}

// ==================== PARTICLE BACKGROUND ====================
class ParticleBackground extends StatefulWidget {
  final int particleCount;
  final Duration duration;
  final Widget child;

  const ParticleBackground({
    super.key,
    this.particleCount = 20,
    this.duration = const Duration(seconds: 15),
    required this.child,
  });

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground> {
  late List<ParticleData> particles;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    particles = List.generate(widget.particleCount, (_) => ParticleData.random());
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ...particles.map((p) {
          return Positioned(
            left: p.x,
            top: p.y,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Transform.translate(
                  offset: Offset(p.vx * _controller.value * 20, p.vy * _controller.value * 20),
                  child: Container(
                    width: p.size,
                    height: p.size,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

class ParticleData {
  final double x, y, vx, vy, size;
  
  ParticleData({required this.x, required this.y, required this.vx, required this.vy, required this.size});
  
  factory ParticleData.random() {
    return ParticleData(
      x: Random().nextDouble() * 100,
      y: Random().nextDouble() * 100,
      vx: (Random().nextDouble() - 0.5) * 0.5,
      vy: (Random().nextDouble() - 0.5) * 0.5,
      size: Random().nextDouble() * 6 + 4,
    );
  }
}

// ==================== ANIMATED CIRCULAR INDICATOR ====================
class CircularIndicator extends StatefulWidget {
  final double progress;
  final String label;
  final Color? color;
  final double size;

  const CircularIndicator({
    super.key,
    required this.progress,
    required this.label,
    this.color,
    this.size = 60,
  });

  @override
  State<CircularIndicator> createState() => _CircularIndicatorState();
}

class _CircularIndicatorState extends State<CircularIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _progressAnim = Tween(begin: 0.0, end: widget.progress).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnim,
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _progressAnim.value,
                  strokeWidth: 4,
                  backgroundColor: Colors.grey[200],
                  color: widget.color ?? AppTheme.primary,
                  strokeCap: StrokeCap.round,
                ),
                Text(
                  widget.label,
                  style: TextStyle(fontSize: widget.size * 0.3, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== TOAST NOTIFICATION ====================
Future<void> showToast({
  required BuildContext context,
  required String message,
  IconData? icon,
  ToastType type = ToastType.info,
}) async {
  await ScaffoldMessenger.of(context).hideCurrentSnackBar();
  
  late Color bgColor;
  switch (type) {
    case ToastType.success:
      bgColor = AppTheme.success;
      break;
    case ToastType.error:
      bgColor = AppTheme.danger;
      break;
    case ToastType.warning:
      bgColor = AppTheme.warning;
      break;
    case ToastType.info:
    default:
      bgColor = AppTheme.primary;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          if (icon != null) Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
        ],
      ),
      backgroundColor: bgColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: EdgeInsets.only(bottom: 20),
      duration: const Duration(milliseconds: 2000),
    ),
  );
}

enum ToastType { success, error, warning, info }

// ==================== COPY CLIPBOARD WITH ANIMATION ====================
Future<bool> copyToClipboard(String text, {String? message}) async {
  final result = await Clipboard.setData(ClipboardData(text: text));
  final hasContent = await Clipboard.hasStrings();
  return hasContent;
}

// ==================== ANIMATED SLIDE IN ====================
class SlideIn extends AnimatedWidget {
  final Widget child;

  const SlideIn({super.key, required this.child, Animation<double> animation})
      : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.2),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: listenable,
        curve: Curves.easeOutCubic,
      )),
      child: child,
    );
  }
}

class FadeIn extends AnimatedWidget {
  final Widget child;

  const FadeIn({super.key, required this.child, Animation<double> animation})
      : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: listenable,
      child: child,
    );
  }
}
