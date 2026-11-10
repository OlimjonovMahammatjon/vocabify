class AppConstants {
  static const String appName = 'Vocabify';

  // Supabase Configuration
  static const String supabaseUrl = 'https://iqribysjojmpjjctjlbf.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlxcmlieXNqb2ptcGpqY3RqbGJmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc4MDc0NjIsImV4cCI6MjA5MzM4MzQ2Mn0.0e2lB1Ebe9H58byMYTSQBlktYsj-_XO5LnkMIHYWrB0';

  // Outbox storage key
  static const String outboxKey = 'vocabify_outbox_v1';
  static const String themeKey = 'vocabify_theme_mode';

  // AI Vision Configuration (Groq is primary ultra-fast LPU inference)
  static const String groqApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );

  // Gemini AI Vision Configuration (Fallback / Alternative)
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
}
