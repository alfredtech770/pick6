// SupabaseManager.swift
// Centralized Supabase client for the app.

import Supabase
import Foundation

enum SupabaseManager {
    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://lgnjawngkiamlngcffrk.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxnbmphd25na2lhbWxuZ2NmZnJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczNzE5MTIsImV4cCI6MjA5Mjk0NzkxMn0.JgIspzgxL3YaMuq_I5gdvh67AJN09kimJSOnM_uJaD4"
    )
}
