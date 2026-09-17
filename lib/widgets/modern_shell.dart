import 'package:flutter/material.dart';
import '../../widgets/modern_widgets.dart';

/// Modern Shell Template with Bottom Navigation + Swipe Gestures
class ModernShell extends StatefulWidget {
  final List<String> titles;
  final List<Widget> pages;
  final IconData primaryIcon;
  final Widget? logoutDialogBuilder;

  const ModernShell({
    super.key,
    required this.titles,
    required this.pages,
    required this.primaryIcon,
    this.logoutDialogBuilder,
  });

  @override
  State<ModernShell> createState() => _ModernShellState();
}

class _ModernShellState extends State<ModernShell> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late PageController _pageController;
  bool _isBottomBarAnimating = false;
  
  late AnimationController _fabController;
  bool _showFABMenu = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    
    // Check if current page has FAB menu (pages > 4 means we need FAB)
    _showFABMenu = widget.pages.length > 3;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _showLogoutConfirmation() async {
    if (!mounted) return;

    final showDialog = await showDialog<bool>(
      context: context,
      builder: (context) => AnimatedScale(
        scale: _showFABMenu ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: BottomSheet(
          onClosing: () {},
          builder: (context) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 64,
                  color: Colors.orange[700],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Keluar Aplikasi',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Apakah Anda yakin ingin keluar?\nSeluruh sesi akan ditutup.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.logout),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        label: const Text('Keluarkan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (showDialog == true && mounted) {
      // Perform logout
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Widget _buildAppBar(String title) {
    return SlideAppBar(
      title: title,
      actions: [
        LogoutButton(onPressed: _showLogoutConfirmation),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: widget.titles.asMap().entries.map((entry) {
            final index = entry.key;
            final title = entry.value;
            final isSelected = _selectedIndex == index;
            
            return GestureDetector(
              onTap: () => _onItemTapped(index),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) {
                        return ScaleTransition(scale: anim, child: RotationTransition(turns: anim, child: child));
                      },
                      child: Icon(
                        isSelected 
                            ? widget.primaryIcon 
                            : Icons.grid_view_outlined,
                        key: ValueKey(isSelected),
                        size: 24,
                        color: isSelected ? Theme.of(context).primaryColor : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedDefaultTextStyle(
                      defaultStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Theme.of(context).primaryColor : Colors.grey[400],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      child: Text(title),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        PageView(
          controller: _pageController,
          onPageChanged: (index) {
            if (_selectedIndex != index && !_isBottomBarAnimating) {
              setState(() => _selectedIndex = index);
            }
          },
          physics: const NeverScrollableScrollPhysics(),
          children: widget.pages,
        ),
        if (_showFABMenu)
          Positioned(
            right: 16,
            bottom: 84,
            child: FloatingActionButton.extended(
              heroTag: '_main_fab',
              onPressed: () {
                setState(() => _showFABMenu = !_showFABMenu);
              },
              backgroundColor: Theme.of(context).primaryColor,
              elevation: _showFABMenu ? 0 : 6,
              icon: AnimatedRotation(
                turns: _showFABMenu ? 0.5 : 0,
                duration: const Duration(milliseconds: 300),
                child: Icon(_selectedIndex == 0 ? Icons.home : Icons.add),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Flexible(child: _buildBody()),
            _buildBottomNav(context),
          ],
        ),
      ),
    );
  }
}

/// AppBar with slide-up animation effect
class SlideAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final Widget? leading;
  final Color? backgroundColor;

  const SlideAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = false,
    this.leading,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppBar(
        automaticallyImplyLeading: showBackButton || leading != null,
        leading: leading ??
            (showBackButton
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Kembali',
                  )
                : null),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        actions: actions,
        flexibleSpace: Material(
          color: Colors.transparent,
          child: FadeInTransition(
            alignment: Alignment.topCenter,
            child: const Text(''),
            animation: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
              parent: ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation,
              curve: Curves.easeOut,
            )),
          ),
        ),
      ),
    );
  }
}

/// Button to show logout confirmation
class LogoutButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const LogoutButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => RotationTransition(turns: anim, child: child),
        child: Icon(Icons.logout_rounded, key: ValueKey(false)),
      ),
      tooltip: 'Keluar',
      onPressed: onPressed,
    );
  }
}

/// Fade-in transition with default animation controller
class FadeInTransition extends AnimatedWidget {
  final Widget child;

  const FadeInTransition({
    super.key,
    required this.child,
    Animation<double> animation = const AlwaysStoppedAnimation(1),
    this.alignment = Alignment.topCenter,
  }) : super(listenable: animation);

  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: listenable,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: alignment == Alignment.topCenter
              ? const Offset(0, -0.1)
              : alignment == Alignment.bottomCenter
                  ? const Offset(0, 0.1)
                  : Offset.zero,
          end: Offset.zero,
        ).animate(listenable),
        child: child,
      ),
    );
  }
}

