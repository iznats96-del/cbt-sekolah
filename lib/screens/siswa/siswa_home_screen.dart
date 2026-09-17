import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/modern_widgets.dart';
import 'ujian_beranda_list.dart';

class SiswaHomeScreen extends StatefulWidget {
  const SiswaHomeScreen({super.key});

  @override
  State<SiswaHomeScreen> createState() => _SiswaHomeScreenState();
}

class _SiswaHomeScreenState extends State<SiswaHomeScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profil;
  Map<String, dynamic>? _siswaRow;
  bool _loading = true;
  late AnimationController _pulseController;
  
  List<Map<String, dynamic>> _ujianList = [];
  bool _fetchUjian = false;

  @override
  void initState() {
    super.initState();
    _load();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _pulseController.repeat(reverse: true);
    _loadUjianList();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await Api.currentProfile();
    Map<String, dynamic>? row;
    try {
      final rows = await Api.client
          .from('siswa')
          .select('nama,nis,nisn,aktive_ok,kelas(nama,jurusan(singkatan))')
          .eq('profile_id', Api.user?.id ?? '')
          .limit(1);
      if (rows.isNotEmpty) row = Map<String, dynamic>.from(rows.first as Map);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _profil = p;
      _siswaRow = row;
      _loading = false;
    });
  }

  Future<void> _loadUjianList() async {
    try {
      final res = await Api.client
        .from('ujian')
        .select('*,kualitas(nilai_rata),mata_pelajaran(nama)')
        .or('status.eq.aktif,status.eq.selesai')
        .order('tanggal', ascending: false)
        .limit(10);
      
      if (!mounted) return;
      setState(() {
        _ujianList = List<Map<String, dynamic>>.from(res);
        _fetchUjian = true;
      });
    } catch (_) {}
  }

  Widget _buildHeader() {
    return AnimatedScale(
      scale: _loading ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 400),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primary, AppTheme.secondary],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return Transform.scale(
                    scale: _pulseController.value,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Icon(Icons.person_rounded, size: 32, color: Colors.white),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _siswaRow?['nama']?.toString() ?? _profil?['nama']?.toString() ?? 'Halo, Siswa!',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _siswaRow?['kelas']['nama']?.toString() ?? '',
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.3),
                child: Text(
                  _siswaRow?['nis']?.toString().substring(0, 3) ?? 'NIS',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ShimmerLoading(
        count: 3,
        itemBuilder: (index) => Card(
          margin: EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: ShimmerEffect(width: 60, height: 60, borderRadius: BorderRadius.circular(30)),
            title: ShimmerEffect(width: 180, height: 20),
            subtitle: ShimmerEffect(width: 120, height: 16),
          ),
        ),
      );
    }

    return PullToRefreshIndicator(
      onRefresh: _loadUjianList,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              
              // Active exam countdown card
              _ujianList.any((u) => u['status'] == 'aktif')
                  ? ScaleTransition(
                      scale: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
                        parent: kAlwaysCompleteAnimation, curve: Curves.elasticOut),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: AppTheme.danger, width: 2),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  AppTheme.danger.withOpacity(0.1),
                                  Colors.white,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.danger.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.event_busy_rounded, color: AppTheme.danger),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Ujian Aktif Sekarang',
                                      style: TextStyle(
                                        fontSize: 16, 
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.danger,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                ..._ujianList.where((u) => u['status'] == 'aktif').map((ujian) {
                                  final mapel = ujian['mata_pelajaran']['nama'] ?? 'Mata Pelajaran';
                                  return Card(
                                    margin: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      leading: CircleAvatar(
                                        backgroundColor: AppTheme.primary.withOpacity(0.1),
                                        child: Icon(Icons.quiz_rounded, color: AppTheme.primary),
                                      ),
                                      title: Text(mapel, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      subtitle: Text(
                                        ujian['alokasi_menit'].toString() + ' menit • Token: ${ujian['token']}',
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                      trailing: ElevatedButton.icon(
                                        onPressed: () {},
                                        icon: const Icon(Icons.login_rounded, size: 16),
                                        label: const Text('Masuk'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.danger,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(70, 36),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              
              const SizedBox(height: 20),
              
              // Recent exams list
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riwayat Ujian',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton.outlined(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: _loadUjianList,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              _ujianList.isEmpty
                  ? FloatingIllustration(
                      icon: Icons.history_edu,
                      title: 'Belum ada riwayat',
                      subtitle: 'Mulai ikuti ujian untuk melihat riwayat',
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _ujianList.length,
                      itemBuilder: (context, index) {
                        final ujian = _ujianList[index];
                        return _buildUjianCard(ujian, index);
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUjianCard(Map<String, dynamic> ujian, int index) {
    final mapel = ujian['mata_pelajaran']['nama'] ?? '';
    final tanggal = ujian['tanggal']?.toString().split('T').first ?? '';
    
    Color badgeColor;
    IconData badgeIcon;
    String badgeText;
    
    switch (ujian['status']) {
      case 'selesai':
        badgeColor = AppTheme.success;
        badgeIcon = Icons.check_circle_outline;
        badgeText = 'Selesai';
        break;
      default:
        badgeColor = Colors.grey[400]!;
        badgeIcon = Icons.pending_outlined;
        badgeText = 'Draft';
    }

    return SlideIn(
      animation: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: kAlwaysCompleteAnimation,
        curve: Interval(0.2 + (index * 0.1).clamp(0.0, 0.8), 1.0 - (index * 0.1).clamp(0.0, 0.2), curve: Curves.easeOut),
      )),
      child: RippleWrapper(
        onTap: () {},
        child: Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.white, Colors.white.withOpacity(0.9)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primary.withOpacity(0.1),
                child: Icon(Icons.quiz_rounded, color: AppTheme.primary),
              ),
              title: Text(mapel, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('$tanggal • ${ujian['alokasi_menit']} menit',
                  style: TextStyle(color: Colors.grey[600])),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 14, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(badgeText, 
                        style: TextStyle(color: badgeColor, 
                             fontSize: 11, 
                             fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
