import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/modern_widgets.dart';
import '../shared/soal_form_screen.dart';

class BankSoalScreen extends StatefulWidget {
  const BankSoalScreen({super.key});

  @override
  State<BankSoalScreen> createState() => _BankSoalScreenState();
}

class _BankSoalScreenState extends State<BankSoalScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _soal = [];
  List<Map<String, dynamic>> _mapelList = [];
  String? _filterMapel;
  bool _loading = true;
  String? _error;
  
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _load();
    _loadMapel();
    _animationController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _searchController.addListener(() {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
        _load();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadMapel() async {
    try {
      final rows = await Api.client
          .from('mata_pelajaran')
          .select('id,nama')
          .order('nama');
      if (!mounted) return;
      setState(() => _mapelList = List<Map<String, dynamic>>.from(rows));
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var q = Api.client
          .from('bank_soal')
          .select('*,mata_pelajaran(nama)');
      if (_filterMapel != null) q = q.eq('mapel_id', _filterMapel!);
      
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final allRows = await q.order('created_at', ascending: false);
        final filtered = allRows.where((s) {
          final soalText = (s['soal'] ?? '').toString().toLowerCase();
          final mapelText = ((s['mata_pelajaran'] as Map?)?['nama'] ?? '').toString().toLowerCase();
          return soalText.contains(_searchQuery) || mapelText.contains(_searchQuery);
        }).toList();
        
        if (!mounted) return;
        setState(() {
          _soal = List<Map<String, dynamic>>.from(filtered);
          _loading = false;
        });
      } else {
        final rows = await q.order('created_at', ascending: false);
        if (!mounted) return;
        setState(() {
          _soal = List<Map<String, dynamic>>.from(rows);
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat soal: $e';
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: ModalRoute.of(context)?.animation ?? DefaultCurve(), curve: Curves.easeOutCubic)),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: const Text('Tambah Soal Baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              Expanded(
                child: DraggableScrollableSheet(
                  initialChildSize: 0.7,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  builder: (_, controller) => Stack(
                    children: [
                      SingleChildScrollView(
                        controller: controller,
                        child: const SoalFormScreen(),
                      ),
                      Positioned(
                        top: 8,
                        right: 16,
                        child: IconButton.filledTonal(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    _load();
  }

  Future<void> _edit(Map<String, dynamic> soal) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: ModalRoute.of(context)?.animation ?? DefaultCurve(), curve: Curves.easeOutCubic)),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: const Text('Edit Soal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              Expanded(
                child: DraggableScrollableSheet(
                  initialChildSize: 0.7,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  builder: (_, controller) => Stack(
                    children: [
                      SingleChildScrollView(
                        controller: controller,
                        child: SoalFormScreen(initial: soal, soalId: soal['id']),
                      ),
                      Positioned(
                        top: 8,
                        right: 16,
                        child: IconButton.filledTonal(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    _load();
  }

  Widget _buildDeleteRow(BuildContext context, Map<String, dynamic> soal) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFEE5A5A)],
          begin: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_outline, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> soal) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_rounded,
              size: 64,
              color: AppTheme.danger,
            ),
            const SizedBox(height: 16),
            Text(
              'Hapus Soal?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.danger),
            ),
            const SizedBox(height: 8),
            Text(
              soal['soal']?.toString().length > 60
                  ? '${soal['soal']}...'
                  : soal['soal'].toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                    label: const Text('Batal'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.delete),
                    label: const Text('Hapus'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Menghapus...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await Api.client.from('bank_soal').delete().eq('id', soal['id']);
      if (!mounted) return;
      Navigator.of(context).pop();
      _load();
      showToast(
        context: context,
        message: 'Soal berhasil dihapus',
        icon: Icons.check_circle_outline,
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(
        context: context,
        message: 'Gagal hapus: $e',
        icon: Icons.error_outline,
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Bank Soal', style: TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Material(
          color: Colors.transparent,
          child: FadeInTransition(
            alignment: Alignment.topCenter,
            child: const Text(''),
            animation: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
              parent: ModalRoute.of(context)?.animation ?? DefaultCurve(),
              curve: Curves.easeOut,
            )),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Search field with instant debounce
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari soal berdasarkan kalimat atau mata pelajaran...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Filter chips as active pill style
                SizedBox(
                  height: 38,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        ChipFilter(
                          label: 'Semua',
                          selected: _filterMapel == null,
                          onSelect: () { setState(() => _filterMapel = null); _load(); },
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        for (final m in _mapelList) ...[
                          ChipFilter(
                            label: '${m['nama']}',
                            selected: _filterMapel == m['id'],
                            onSelect: () { setState(() => _filterMapel = (on) ? m['id'].toString() : null); _load(); },
                            color: AppTheme.secondary,
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: ExpandedFabMenu(
        items: [
          FabMenuItem(
            label: 'Tambah Soal',
            icon: Icons.add,
            onPressed: _add,
          ),
          if (_filterMapel != null)
            FabMenuItem(
              label: 'Reset Filter',
              icon: Icons.filter_list_off,
              onPressed: () { setState(() => _filterMapel = null); _load(); },
              color: AppTheme.danger,
            ),
        ],
        mainIcon: Icons.add,
        mainColor: AppTheme.primary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ShimmerLoading(
        count: 5,
        itemBuilder: (index) => Card(
          child: ListTile(
            leading: CircleAvatar(radius: 20),
            title: ShimmerEffect(width: 200, height: 16),
            subtitle: ShimmerEffect(width: 100, height: 14),
          ),
        ),
      );
    }
    
    if (_error != null) return Center(child: Text(_error!));
    
    if (_soal.isEmpty) {
      return FloatingIllustration(
        icon: Icons.quiz_outlined,
        title: 'Belum ada soal',
        subtitle: 'Mulai buat bank soal untuk ujian Anda',
        action: _add,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _soal.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final s = _soal[i];
          final mapel = (s['mata_pelajaran'] is Map)
              ? (s['mata_pelajaran'] as Map)['nama']?.toString() ?? ''
              : '';
          final jenis = s['jenis']?.toString() ?? 'pg';
          final text = s['soal']?.toString() ?? '';
          
          return GestureDetector(
            onTap: () => _edit(s),
            child: Dismissible(
              key: Key(s['id'].toString()),
              direction: DismissDirection.endToStart,
              background: _buildDeleteRow(context, s),
              onDismissed: (_) => _delete(s),
              child: ScaleTransition(
                scale: Tween(begin: 0.95, end: 1.0).animate(
                  CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
                ),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white,
                          Colors.white.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: jenis == 'pg' 
                            ? AppTheme.primary.withOpacity(0.1)
                            : AppTheme.accent.withOpacity(0.1),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: jenis == 'pg' 
                                ? AppTheme.primary.withOpacity(0.15)
                                : AppTheme.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            jenis == 'pg' ? 'PG' : (jenis == 'jodoh' ? 'JD' : 'ES'),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        text.length > 60 ? '${text.substring(0, 60)}...' : text,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text([
                        if (mapel.isNotEmpty) mapel,
                        'Bobot: ${s['bobot'] ?? 1}',
                      ].join(' • '),
                      style: TextStyle(color: Colors.grey[600])),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ActionChip(
                            avatarIcon: const Icon(Icons.edit_outlined, size: 14),
                            label: const Text('Edit', style: TextStyle(fontSize: 11)),
                            onPressed: () => _edit(s),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            avatarIcon: Icon(Icons.delete_outline, size: 14, color: AppTheme.danger),
                            label: const Text('Hapus', style: TextStyle(fontSize: 11, color: AppTheme.danger)),
                            onPressed: () => _delete(s),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Helper classes
class ChipFilter extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelect;
  final Color color;

  const ChipFilter({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelect,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey[300]!,
            width: 1.5,
          ),
          boxShadow: selected ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class DefaultCurve implements Listenable {
  @override
  void addListener(listener) {}
  @override
  void removeListener(listener) {}
  @override
  void dispatchNotification(NotificationHandler handler) {}
}

class DefaultCurve2 implements Animation<double> {
  @override
  void addListener(listener) {}
  @override
  void removeListener(listener) {}
  @override
  bool isDisposed() => false;
  @override
  double get value => throw UnimplementedError();
}
