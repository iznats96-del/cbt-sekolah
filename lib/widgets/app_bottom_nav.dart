import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavItem(this.icon, this.activeIcon, this.label);
}

/// Bottom navigation bergaya kartu melayang: putih, sudut atas 22,
/// ikon aktif dalam pill biru muda + garis aksen di bawah label.
class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<NavItem> items;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x141E3A66),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _item(items[i], i == selectedIndex, i),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(NavItem item, bool active, int index) {
    final color = active ? AppTheme.primary : const Color(0xFF94A3B8);
    return InkWell(
      onTap: () => onChanged(index),
      splashColor: AppTheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: active ? 46 : 38,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? const Color(0xFFE8F1FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                active ? item.activeIcon : item.icon,
                size: 21,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: active ? 18 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
