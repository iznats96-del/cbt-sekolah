import 'package:flutter/material.dart';

// ==================== ANIMATED BACKGROUND ====================
class AnimatedBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;
  final Duration duration;

  const AnimatedBackground({
    super.key,
    required this.child,
    this.colors,
    this.duration = const Duration(seconds: 10),
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.colors ?? [
                AppTheme.primary,
                AppTheme.secondary,
                AppTheme.accent,
              ],
              stops: [
                (_controller.value - 0.5).clamp(0.0, 1.0),
                _controller.value.clamp(0.0, 1.0),
                (_controller.value + 0.5).clamp(0.0, 1.0),
              ],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

// ==================== SPRING ANIMATION WRAPPER ====================
class SpringAnimation extends StatelessWidget {
  final Widget child;
  final VoidCallback? onEnd;

  const SpringAnimation({
    super.key,
    required this.child,
    this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      child: child,
    );
  }
}

// ==================== HORIZONTAL SWIPE DELETE ====================
class SwipeDeleteItem extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onDelete;
  final Color deleteColor;

  const SwipeDeleteItem({
    super.key,
    required this.child,
    this.onDelete,
    this.deleteColor = Colors.red,
  });

  @override
  State<SwipeDeleteItem> createState() => _SwipeDeleteItemState();
}

class _SwipeDeleteItemState extends State<SwipeDeleteItem> {
  final _dragStart = Offset.zero;
  Offset? _currentOffset;

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      if (_currentOffset == null) {
        _currentOffset = details.delta;
      } else {
        _currentOffset = Offset(_currentOffset!.dx + details.delta.dx, _currentOffset!.dy + details.delta.dy);
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    final threshold = 80.0;
    if ((_currentOffset?.dx ?? 0).abs() > threshold) {
      _performDelete();
    } else {
      setState(() => _currentOffset = null);
    }
  }

  Future<void> _performDelete() async {
    await widget.onDelete?.call();
    if (mounted) setState(() => _currentOffset = null);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: widget.deleteColor.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.delete_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Transform.translate(
              offset: Offset(_currentOffset?.dx ?? 0, 0),
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== FLOATING ILLUSTRATION ====================
class FloatingIllustration extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? action;
  final Widget? actionButton;

  const FloatingIllustration({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.actionButton,
  });

  @override
  State<FloatingIllustration> createState() => _FloatingIllustrationState();
}

class _FloatingIllustrationState extends State<FloatingIllustration> with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _bounceAnimation = Tween<double>(begin: 0, end: 10).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeInOut,
    ));
    _bounceController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _bounceAnimation,
            builder: (context, _) {
              return Transform.translate(
                offset: Offset(0, _bounceAnimation.value),
                child: Icon(widget.icon, size: 80, color: Colors.grey[400]),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (widget.action != null || widget.actionButton != null)
            FloatingActionButton.extended(
              onPressed: widget.action,
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add),
              label: Text(widget.actionButton?.toString() ?? 'Tambah'),
            ),
        ],
      ),
    );
  }
}
