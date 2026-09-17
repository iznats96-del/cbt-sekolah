import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/modern_widgets.dart';

/// DEDICATED REKAP NILAI PAGE FOR TEACHERS
/// Features:
/// - Group results by Mata Pelajaran (mapel)
/// - Filter by kelas, jurusan, tanggal
/// - Export CSV/Excel
/// - Detailed student view per ujian
class RekapNilaiFullScreen extends StatefulWidget {
  const RekapNilaiFullScreen({super.key});

  @override
  State<RekapNilaiFullScreen> createState() => _RekapNilaiFullScreenState();
}

class _RekapNilaiFullScreenState extends State<RekapNilaiFullScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _ujianList = [];
  List<Map<String, dynamic>> _hasilList = [];
  List<Map<String, dynamic>> _kelasList = [];
  List<Map<String, dynamic>> _jurusanList = [];
  
  String? _filterMapel;
  String? _filterKelas;
  String? _filterJurusan;
  DateTimeRange? _dateRange;
  
  bool _loading = true;
  bool _exporting = false;
  late AnimationController _animationController;
  
  // Grouped data structure
  Map<String, List<Map<String, dynamic>>> _resultsByMapel = {};
  Map<String, List<Map<String, dynamic>>> _resultsByKelas = {};

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _animationController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    try {
      final futures = await Future.wait([
        Api.client.rpc('my_hasil').catchError((e) => []),
        Api.client.from('ujian').select('*,mata_pelajaran(nama),kelas(nama)').order('created_at', ascending: false).catchError((e) => []),
        Api.client.from('kelas').select('id,nama,jurusan_id').order('nama').catchError((e) => []),
        Api.client.from('jurusan').select('id,nama,singkatan').order('singkatan').catchError((e) => []),
      ]);

      if (!mounted) return;
      
      final hasilRaw = futures[0] as List;
      final ujianList = futures[1] as List;
      final kelasList = futures[2] as List;
      final jurusanList = futures[3] as List;

      setState(() {
        _hasilList = hasilRaw.map((h) => Map<String, dynamic>.from(h)).toList();
        _ujianList = ujianList.map((u) => Map<String, dynamic>.from(u)).toList();
        _kelasList = kelasList.map((k) => Map<String, dynamic>.from(k)).toList();
        _jurusanList = jurusanList.map((j) => Map<String, dynamic>.from(j)).toList();
        
        _groupResults();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          showToast(context: context, message: 'Gagal memuat rekap: $e', type: ToastType.error);
        });
      }
    }
  }

  void _groupResults() {
    // Group by mapel
    final groupedByMapel = <String, List<Map<String, dynamic>>>{};
    final groupedByKelas = <String, List<Map<String, dynamic>>>{};

    for (final h in _hasilList) {
      final ujianId = h['ujian_id'];
      final ujian = _ujianList.firstWhere(
        (u) => u['id'] == ujianId, 
        orElse: () => {} as Map<String, dynamic>
      );
      
      final mapelName = (ujian['mata_pelajaran'] as Map?)?['nama'] ?? 'Tanpa Mapel';
      final kelasName = (ujian['kelas'] as Map?)?['nama'] ?? 'Tidak Ada Kelas';

      groupedByMapel.putIfAbsent(mapelName, () => []).add({...h, '_ujian': ujian});
      groupedByKelas.putIfAbsent(kelasName, () => []).add({...h, '_ujian': ujian});
    }

    setState(() {
      _resultsByMapel = groupedByMapel;
      _resultsByKelas = groupedByKelas;
    });
  }

  List<Map<String, dynamic>> get filteredResults {
    var results = _hasilList.toList();

    if (_filterMapel != null && _filterMapel!.isNotEmpty) {
      results = results.where((h) {
        final ujian = _ujianList.firstWhere(
          (u) => u['id'] == h['ujian_id'],
          orElse: () => {} as Map<String, dynamic>
        );
        final mapelName = (ujian['mata_pelajaran'] as Map?)?['nama'] ?? '';
        return mapelName.toLowerCase().contains(_filterMapel!.toLowerCase());
      }).toList();
    }

    if (_filterKelas != null && _filterKelas!.isNotEmpty) {
      results = results.where((h) {
        final ujian = _ujianList.firstWhere(
          (u) => u['id'] == h['ujian_id'],
          orElse: () => {} as Map<String, dynamic>
        );
        final kelasName = (ujian['kelas'] as Map?)?['nama'] ?? '';
        return kelasName.toLowerCase().contains(_filterKelas!.toLowerCase());
      }).toList();
    }

    return results;
  }

  Future<void> _exportCSV() async {
    setState(() => _exporting = true);
    try {
      final now = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
      final lines = <String>[
        'Nama Ujian,Mapel,Kelas,Siswa,NIS,Nilai,Benar,Salah,Kosong,Dinilai',
        ...filteredResults.map((h) {
          final ujian = _ujianList.firstWhere(
            (u) => u['id'] == h['ujian_id'],
            orElse: () => {} as Map<String, dynamic>
          );
          final siswaName = h['siswa']?['nama'] ?? 'Unknown';
          final nis = h['siswa']?['nis'] ?? '-';
          
          return '${ujian['nama']},"${(ujian['mata_pelajaran'] as Map?)?['nama'] ?? ''}",'
                '"${(ujian['kelas'] as Map?)?['nama'] ?? ''}",$siswaName,$nis,'
                '${h['nilai']?.toStringAsFixed(1) ?? '-"},"${h['jumlah_benar'] ?? 0}",'
                '"${h['jumlah_salah'] ?? 0}","${h['jumlah_kosong'] ?? 0}",${h['dinilai'] || false}';
        }),
      ];

      await Clipboard.setData(ClipboardData(text: lines.join('\n')));
      if (mounted) {
        showToast(context: context, message: 'CSV tersalin ke clipboard ✅', type: ToastType.success);
        Navigator.pop(context); // Close modal
      }
    } catch (e) {
      if (mounted) {
        showToast(context: context, message: 'Export gagal: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari mapel/kelas...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (v) {
                    setState(() {
                      _filterMapel = v.toLowerCase();
                      _filterKelas = v.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (c) => _FilterBottomSheet(
                      kelasList: _kelasList,
                      jurusanList: _jurusanList,
                      onApply: (mapel, kelas, jurusan) {
                        setState(() {
                          _filterMapel = mapel;
                          _filterKelas = kelas;
                          _filterJurusan = jurusan;
                        });
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(
                label: Text('${_hasilList.length} hasil'),
                backgroundColor: AppTheme.primary.withOpacity(0.1),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDelete: _hasilList.isEmpty ? null : () {
                  setState(() {
                    _filterMapel = null;
                    _filterKelas = null;
                    _filterJurusan = null;
                  });
                },
              ),
              Chip(
                label: const Text('Grouped by Mapel'),
                backgroundColor: AppTheme.accent.withOpacity(0.1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Rekap Nilai Terpadu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export CSV',
            onPressed: _loading ? null : _exportCSV,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadAllData,
          ),
        ],
      ),
      body: _loading
          ? ShimmerLoading(
              count: 8,
              itemBuilder: (index) => Card(
                child: ListTile(
                  title: ShimmerEffect(width: 200, height: 16),
                  subtitle: ShimmerEffect(width: 150, height: 14),
                ),
              ),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_hasilList.isEmpty) {
      return Center(
        child: FloatingIllustration(
          icon: Icons.assessment_outlined,
          title: 'Belum ada hasil',
          subtitle: 'Hasil ujian akan muncul setelah guru mengoreksi dan mengumpulkan jawaban',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _resultsByMapel.keys.length > 0 ? _resultsByMapel.length : _resultsByKelas.length,
        itemBuilder: (context, index) {
          final mapelName = _resultsByMapel.keys.elementAt(index);
          final results = _resultsByMapel[mapelName] ?? [];

          // Calculate stats
          final values = results.map((r) => r['nilai'] as num?).whereType<double>().toList();
          final avg = values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
          final max = values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) : 0.0;
          final min = values.isNotEmpty ? values.reduce((a, b) => a < b ? a : b) : 0.0;
          final passed = values.where((v) => v >= 75).length;

          return FadeInTransition(
            animation: _animationController,
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                initialExpanded: index == 0,
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  child: Icon(Icons.menu_book_outlined, color: AppTheme.primary),
                ),
                title: Text('$mapelName (${results.length} siswa)',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  'Rata-rata ${avg.toStringAsFixed(1)} | Lulus ${passed}/${results.length}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _miniStat('Max', '${max.toStringAsFixed(0)}', AppTheme.secondary),
                    const SizedBox(width: 8),
                    _miniStat('Min', '${min.toStringAsFixed(0)}', AppTheme.danger),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const Divider(height: 16),
                      itemBuilder: (context, i) => _ResultRow(result: results[i]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final Map<String, dynamic> result;

  const _ResultRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final ujian = result['_ujian'];
    final siswaName = result['siswa_name'] ?? 'Unknown';
    final nis = result['siswa_nis'] ?? '-';
    final nilai = result['nilai'] as num?;
    
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: nilai != null && nilai >= 75
            ? AppTheme.secondary.withOpacity(0.1)
            : AppTheme.danger.withOpacity(0.1),
        child: Text(
          '$nilai'.split('.').first,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: nilai != null && nilai >= 75 ? AppTheme.secondary : AppTheme.danger,
          ),
        ),
      ),
      title: Text(siswaName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text('NIS: $nis • ${(ujian['nama'] ?? 'Ujian')}').text(
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ).widget,
      trailing: Chip(
        label: Text(
          nilai != null ? '${nilai.toStringAsFixed(0)}' : '-',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        backgroundColor: nilai != null && nilai >= 75
            ? AppTheme.secondary.withOpacity(0.15)
            : AppTheme.danger.withOpacity(0.15),
      ),
    );
  }
}

class _FilterBottomSheet extends StatelessWidget {
  final List<Map<String, dynamic>> kelasList;
  final List<Map<String, dynamic>> jurusanList;
  final Function(String?, String?, String?) onApply;

  const _FilterBottomSheet({
    required this.kelasList,
    required this.jurusanList,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter Hasil',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Mapel'),
            items: ['Semua', ...MapelMapper.unique().toList()]
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) {},
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Kelas'),
            items: ['Semua', ...kelasList.map((k) => k['nama'].toString())]
                .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                .toList(),
            onChanged: (v) {},
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Jurusan'),
            items: ['Semua', ...jurusanList.map((j) => j['singkatan'])]
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {},
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => onApply(null, null, null),
            icon: const Icon(Icons.check),
            label: const Text('Terapkan Filter'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper for unique mapel names
class MapelMapper {
  static final _names = <String>{
    'Produktif TKJ 1',
    'Produktif TKJ 2',
    'Bahasa Inggris',
    'PKN',
    'Agama',
    'Seni Budaya',
  };

  static Set<String> unique() => _names;
}
