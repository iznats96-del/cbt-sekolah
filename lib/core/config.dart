class AppConfig {
  static const String appName = 'CBT Sekolah';

  // ─── PRIMARY: Supabase Cloud ──────────────────────────────
  // FLIP: -DPRIMARY_FALLBACK=true → fallback server jadi primary (untuk tes/EMERGENCY).
  static const bool _useFallbackAsPrimary =
      bool.fromEnvironment('PRIMARY_FALLBACK', defaultValue: false);
  static const String supabaseUrl = _useFallbackAsPrimary
      // Mode fallback-as-primary: SDK diarahkan ke server cadangan (Node + PG).
      // Server ini mengimplementasikan endpoint Supabase-compatible
      // (/auth/v1/token, /rest/v1/*, /storage/v1) sehingga SELURUH layar app
      // tetap bisa jalan walau Supabase mati.
      ? 'https://smkyp79.my.id'
      : 'https://yukqngrtgevveimhrwke.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_zw9bbTdmBoZqUvdW8ZV-2Q_Pr0sDrhp';

  /// true kalau Supabase dimatiin (domain sengaja mati) → skip semua auth via Supabase SDK
  static const bool supabaseDisabled = _useFallbackAsPrimary;

  // ─── FALLBACK: Cloudflare Tunnel → Node.js + PostgreSQL ───
  // Domain permanen via Cloudflare Named Tunnel (smkyp79.my.id)
  static const String fallbackApiUrl = 'https://smkyp79.my.id';

  /// Supabase primary, smkyp79 (Node fallback) hanya sebagai cadangan.
  /// true = active-passive failover: kalau Supabase down 3x berturut-turut,
  /// trafik otomatis pindah ke fallbackApiUrl sampai Supabase pulih.
  /// false = Supabase-only (failover mati, error langsung tampil ke UI).
  static const bool failoverEnabled = true;

  // ─── FAILOVER TUNING ──────────────────────────────────────
  /// Health check interval (seconds)
  static const int healthCheckIntervalSec = 30;

  /// Max consecutive failures before declaring primary DOWN
  static const int failureThreshold = 3;

  /// Timeout per request attempt (seconds)
  static const int requestTimeoutSec = 8;

  /// Circuit breaker open duration before retry probe (seconds)
  static const int circuitBreakerOpenSec = 60;

  /// Max retries with exponential backoff on transient errors
  static const int maxRetries = 2;
}