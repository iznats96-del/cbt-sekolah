class AppConfig {
  static const String appName = 'CBT Sekolah';

  // ─── PRIMARY: Supabase Cloud ──────────────────────────────
  static const String supabaseUrl = 'https://yukqngrtgevveimhrwke.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl1a3FuZ3J0Z2V2dmVpbWhyd2tlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzA2OTQxNzEsImV4cCI6MjA0NjI3MDE3MX0.YUow';

  // ─── FALLBACK: Cloudflare Tunnel → Node.js + PostgreSQL ───
  // Domain permanen via Cloudflare Named Tunnel (smkyp79.my.id)
  static const String fallbackApiUrl = 'https://smkyp79.my.id';

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