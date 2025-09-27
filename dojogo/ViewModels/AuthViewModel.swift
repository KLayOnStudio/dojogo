import Foundation
import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let auth0Manager = Auth0Manager.shared

    init() {
        // Observe Auth0Manager state changes
        observeAuth0State()

        // Load stored user if available
        loadStoredUser()
    }

    func clearAllData() {
        Task {
            // Clear local storage
            LocalStorageService.shared.clearUserData()

            // Sign out from Auth0 and clear credentials
            do {
                try await auth0Manager.signOut()
                print("Cleared all Auth0 credentials and local data")
            } catch {
                print("Error clearing Auth0 data: \(error)")
            }

            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
                self.errorMessage = nil
            }
        }
    }

    private func observeAuth0State() {
        auth0Manager.$isAuthenticated
            .assign(to: &$isAuthenticated)

        // Also check for stored user when authentication state changes
        auth0Manager.$isAuthenticated
            .sink { [weak self] isAuth in
                if isAuth && self?.currentUser == nil {
                    self?.loadStoredUser()
                }
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func loadStoredUser() {
        if let storedUser = LocalStorageService.shared.getCurrentUser() {
            self.currentUser = storedUser
            print("Loaded stored user: \(storedUser.name) (ID: \(storedUser.id))")
        } else {
            print("No stored user found")
        }
    }

    func signIn() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let user = try await auth0Manager.signIn()

                await MainActor.run {
                    self.currentUser = user
                    self.isLoading = false

                    // Clear any old user data and save new user
                    LocalStorageService.shared.clearStoredUser()
                    LocalStorageService.shared.saveUser(user)
                    print("Saved new Auth0 user: \(user.name) (ID: \(user.id))")
                }

                // Create user in API
                do {
                    let createdUser = try await APIService.shared.createUser(user)
                    print("User created in API: \(createdUser.name)")
                } catch {
                    print("Failed to create user in API: \(error.localizedDescription)")
                    // Continue with local user for now
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func signUp() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let user = try await auth0Manager.signUp()

                await MainActor.run {
                    self.currentUser = user
                    self.isLoading = false

                    // Clear any old user data and save new user
                    LocalStorageService.shared.clearStoredUser()
                    LocalStorageService.shared.saveUser(user)
                    print("Saved new Auth0 user: \(user.name) (ID: \(user.id))")
                }

                // Create user in API
                do {
                    let createdUser = try await APIService.shared.createUser(user)
                    print("User created in API: \(createdUser.name)")
                } catch {
                    print("Failed to create user in API: \(error.localizedDescription)")
                    // Continue with local user for now
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func signOut() async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        do {
            try await auth0Manager.signOut()

            await MainActor.run {
                self.currentUser = nil
                self.isLoading = false

                // Clear local storage
                LocalStorageService.shared.clearUserData()
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func refreshTokenIfNeeded() async {
        do {
            try await auth0Manager.refreshCredentialsIfNeeded()
        } catch {
            await MainActor.run {
                self.errorMessage = "Session expired. Please sign in again."
            }
            await self.signOut()
        }
    }
}