import Foundation

/// Base URL of the kai-proxy Supabase Edge Function.
///
/// This is NOT a secret — the security model assumes attackers know the endpoint;
/// App Attest is what gates access (see `AppAttestManager`). Safe to ship in the binary.
enum ProxyConfig {
    #if DEBUG
    /// Local `supabase functions serve`, or a staging project, during development.
    static let baseURL = URL(string: "http://localhost:54321/functions/v1/kai-proxy")!
    #else
    /// Production Supabase project. Set the project ref after `supabase functions deploy`.
    static let baseURL = URL(string: "https://REPLACE_PROJECT_REF.supabase.co/functions/v1/kai-proxy")!
    #endif
}
