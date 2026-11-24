import Foundation

/// Public connection details for the Supabase project.
///
/// The URL and the publishable key are public by design and safe to commit. Access control relies on
/// row-level security in the database (see supabase/migrations), never on hiding these values.
/// The secret / service_role key must never appear in this repository.
enum AppConfig {
    static let supabaseURL = URL(string: "https://nnqieyhfnmcfyicgdpsp.supabase.co")!
    static let supabasePublishableKey = "sb_publishable_QpWjLh_qOs1Z8sjHuqY-nQ_0lIKIN5N"
}
