import Foundation
import Supabase

/// Single shared Supabase client for the whole app.
///
/// 3. Copy your Project URL and anon/public key below (or, better, load them
///    from a plist / xcconfig that's gitignored — see README).
enum SupabaseConfig {
    static let url = URL(string: "https://uusmhcptszjqgmeaoocl.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV1c21oY3B0c3pqcWdtZWFvb2NsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxNDE3NjksImV4cCI6MjEwMjcxNzc2OX0.wAcCWq-g5xW8I5V2CDT4GpVD-KF0NIV7YTvPLnixfY0"
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey,
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
            emitLocalSessionAsInitialSession: true
        )
    )
)
