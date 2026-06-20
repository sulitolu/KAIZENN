import Foundation

/// Base URL of the kai-proxy Supabase Edge Function.
///
/// This is NOT a secret — the security model assumes attackers know the endpoint;
/// App Attest is what gates access (see `AppAttestManager`). Safe to ship in the binary.
enum ProxyConfig {
    // Live kaizenn-proxy project (ap-northeast-1). DEBUG and release use the same
    // hosted function; the dev-bypass path (DEBUG/simulator) is gated server-side by
    // DEV_BYPASS_ENABLED, which is disabled in production before launch.
    static let baseURL = URL(string: "https://oeaphuyfcexpidpzzcri.supabase.co/functions/v1/kai-proxy")!
}
