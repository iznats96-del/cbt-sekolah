class AppConfig {
  static const String appName = 'CBT Sekolah';
  static const String supabaseUrl = 'https://yukqngrtgevveimhrwke.supabase.co';
  static const String supabaseAnonKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl1a3FuZ3J0Z2V2dmVpbWhyd2tlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkzNjI5MTUsImV4cCI6MjEwNDkzODkxNX0.AeN-apHCNUjFpWlhrHZbTPC_ade27FJ_9_CMYUow';

    /// URL API cadangan (Express + PostgreSQL di PC/server lokal)
    /// Ganti IP ini sesuai alamat PC server di jaringan LAN
    static const String fallbackApiUrl = 'http://192.168.1.100:3000';
  }