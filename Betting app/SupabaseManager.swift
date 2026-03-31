// SupabaseManager.swift
// Centralized Supabase client for the app.

import Supabase
import Foundation

enum SupabaseManager {
    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://jisbgspvllgwtfgoeihx.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imppc2Jnc3B2bGxnd3RmZ29laWh4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzNjM4NzEsImV4cCI6MjA4OTkzOTg3MX0.hMiiTCHQj5-hjtb6gFL_X9lGmHw4baCk4_0j9RNoIFs"
    )
}
