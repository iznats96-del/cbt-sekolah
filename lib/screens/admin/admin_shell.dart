import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/design.dart';
import '../../services/api.dart';
import '../home.dart';
import '../../widgets/cetak_kartu_helper.dart';
import '../../widgets/dashboard_header.dart';
import '../../widgets/state_views.dart';
import 'data_master_screen.dart';
import 'bank_soal_screen.dart';
import 'ujian_list_screen.dart';
import 'pengumuman_screen.dart';
import 'daftar_akun_screen.dart';
import 'user_management_screen.dart';
import '../shared/rekap_nilai_screen.dart';
import 'pengaturan_screen.dart';
import '../../widgets/app_bottom_nav.dart';

const _bg = Color(0xFFF4F7FF);
const _card = Colors.white;
const _navy = Color(0xFF101F3C);
const _navySoft = Color(0xFF3B4B6B);
const _muted = Color(0xFF8A97B1);
const _blue = Color(0xFF2563EB);
const _blueLight = Color(0xFFE8F1FF);
const _green = Color(0xFF22C55E);
const _amber = Color(0xFFF59E0B);
const _purple = Color(0xFF7C4DFF);

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      _AdminHome(go: _go),
      const DataMasterScreen(),
      const BankSoalScreen(),
      const UjianListScreen(),
      const PengumumanScreen(),
      const PengaturanScreen(),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _index,
        onChanged: _go,
        items: const [
          NavItem(Icons.home_outlined, Icons.home, 'Beranda'),
          NavItem(Icons.folder_outlined, Icons.folder, 'Master'),
          NavItem(Icons.quiz_outlined, Icons.quiz, 'Soal'),
          NavItem(Icons.assignment_outlined, Icons.assignment, 'Ujian'),
          NavItem(Icons.campaign_outlined, Icons.campaign, 'Info'),
          NavItem(Icons.settings_outlined, Icons.settings, 'Setelan'),
        ],
      ),
    );
  }
}

class _AdminHome extends StatefulWidget {
  final void Function(int index) go;
  const _AdminHome({required this.go});

  @override
  State<_AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<_AdminHome> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<int> _count(String table, {String? role}) async {
    var q = Api.client.from(table).select('id');
    if (role != null) q = q.eq('role', role);
    final rows = await q;
    return (rows as List).length;
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _count('siswa'),
        _count('profiles', role: 'guru'),
        _count('kelas'),
        _count('bank_soal'),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = {
          'total_siswa': results[0],
          'total_guru': results[1],
          'total_kelas': results[2],
          'total_soal': results[3],
        };
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: DashboardHeader(
        title: 'CBT SEKOLAH',
        subtitle: 'Pusat kendali ujian',
        stats: [
          ('siswa', '${_stats['total_siswa'] ?? 0}'),
          ('guru', '${_stats['total_guru'] ?? 0}'),
          ('kelas', '${_stats['total_kelas'] ?? 0}'),
        ],
        actions: const [LogoutButton()],
      ),
      body: ContentMaxWidth(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              const _AdminHero(),
              const SizedBox(height: 14),

              // Statistik (dari /api/admin/dashboard)
              _loading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(color: Cbt.blue)),
                    )
                  : GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 9,
                      crossAxisSpacing: 9,
                      childAspectRatio: 2,
                      children: [
                        _statV2('Siswa', _stats['total_siswa'], Icons.people_outline, _blue),
                        _statV2('Guru', _stats['total_guru'], Icons.person_outline, _green),
                        _statV2('Kelas', _stats['total_kelas'], Icons.school_outlined, _amber),
                        _statV2('Bank soal', _stats['total_soal'], Icons.quiz_outlined, _purple),
                      ],
                    ),
              const SizedBox(height: 16),
              _ControlCenter(),
              const SizedBox(height: 16),
              Cbt.label('AKSES CEPAT'),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, c) {
                final cols = (c.maxWidth / 200).floor().clamp(2, 4);
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    _FeatureCard(icon: Icons.people_outline, label: 'Siswa', color: Cbt.blue, onTap: () => widget.go(1)),
                    _FeatureCard(icon: Icons.person_outline, label: 'Guru', color: Cbt.teal, onTap: () => widget.go(1)),
                    _FeatureCard(icon: Icons.quiz_outlined, label: 'Bank Soal', color: Cbt.amber, onTap: () => widget.go(2)),
                    _FeatureCard(icon: Icons.assignment_outlined, label: 'Ujian', color: Cbt.red, onTap: () => widget.go(3)),
                    _FeatureCard(
                      icon: Icons.print_outlined,
                      label: 'Cetak Kartu',
                      color: Cbt.blue,
                      onTap: () => pilihDanCetakKartu(context),
                    ),
                    _FeatureCard(
                      icon: Icons.insert_chart_outlined,
                      label: 'Rekap Nilai',
                      color: Cbt.blue,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RekapNilaiScreen())),
                    ),
                    _FeatureCard(
                      icon: Icons.badge_outlined,
                      label: 'Daftar Akun + Password',
                      color: Cbt.teal,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DaftarAkunScreen())),
                    ),
                    _FeatureCard(
                      icon: Icons.person_add_outlined,
                      label: 'Akun Guru & Panitia',
                      color: Cbt.amber,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserManagementScreen())),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statV2(String label, dynamic value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$value',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(label,
                      style: const TextStyle(fontSize: 11, color: _muted)),
                ],
              ),
            ),
          ],
        ),
      );

}

class _AdminHero extends StatelessWidget {
  const _AdminHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _blueLight,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.admin_panel_settings_outlined,
                color: _blue, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Selamat datang, Administrator',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _navy)),
                SizedBox(height: 4),
                Text('Kelola siswa, soal, dan jalannya ujian dari satu tempat.',
                    style: TextStyle(fontSize: 11.5, color: _muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlCenter extends StatelessWidget {
  const _ControlCenter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.dashboard_customize_outlined, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pusat kendali', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 3),
                Text('Akses cepat untuk persiapan ujian hari ini', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          const _ChecklistRow(Icons.people_outline, 'Pastikan data siswa dan kelas sudah lengkap'),
          const _ChecklistRow(Icons.quiz_outlined, 'Cek soal dan kunci jawaban sebelum mengaktifkan ujian'),
          const _ChecklistRow(Icons.assignment_turned_in_outlined, 'Pantau rekap nilai setelah ujian selesai'),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ChecklistRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(children: [
        Icon(icon, size: 18, color: AppTheme.secondary),
        const SizedBox(width: 9),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
      ]),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _FeatureCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 9),
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _navySoft)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
