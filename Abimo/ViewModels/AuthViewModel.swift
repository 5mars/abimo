//
//  AuthViewModel.swift
//  Abimo
//
//  Created by Claude on 2026-03-03.
//

import Foundation
import SwiftUI
import Combine
import Supabase

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseService.shared
    private var authStateTask: Task<Void, Never>?

    init() {
        Task {
            await checkAuthStatus()
        }
        listenForAuthChanges()
    }

    private func listenForAuthChanges() {
        authStateTask = Task {
            for await (event, session) in supabase.client.auth.authStateChanges {
                guard !Task.isCancelled else { break }
                switch event {
                case .signedIn, .tokenRefreshed:
                    if let user = session?.user {
                        currentUser = User(id: user.id, email: user.email, createdAt: user.createdAt)
                        isAuthenticated = true
                    }
                case .signedOut:
                    currentUser = nil
                    isAuthenticated = false
                default:
                    break
                }
            }
        }
    }

    func checkAuthStatus() async {
        isLoading = true
        defer { isLoading = false }

        do {
            currentUser = try await supabase.getCurrentUser()
            isAuthenticated = currentUser != nil
        } catch {
            print("Auth check error: \(error.localizedDescription)")
            isAuthenticated = false
        }
    }

    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            currentUser = try await supabase.signUp(email: email, password: password)
            isAuthenticated = true
        } catch {
            errorMessage = "Sign up failed: \(error.localizedDescription)"
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            currentUser = try await supabase.signIn(email: email, password: password)
            isAuthenticated = true
        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
        }
    }

    func signOut() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await supabase.signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }

    func deleteAccountAndSignOut() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await supabase.deleteAccount()
            // User no longer exists on server -- just clear local state
            // Do NOT call signOut() -- it will fail for deleted user
            currentUser = nil
            isAuthenticated = false
        } catch {
            errorMessage = "Account deletion failed: \(error.localizedDescription)"
        }
    }

    func clearLocalData() {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: bundleId)
        UserDefaults.standard.register(defaults: [
            "notif_inactivity": true,
            "notif_action_nudge": true,
            "notif_idea_nudge": true,
            "notif_streak": true
        ])
    }
}
