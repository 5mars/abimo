//
//  SignUpView.swift
//  Abimo
//

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var passwordsMatch: Bool { password == confirmPassword }
    private var canSubmit: Bool { !email.isEmpty && !password.isEmpty && passwordsMatch }
    private var bothPasswordsEntered: Bool { !password.isEmpty && !confirmPassword.isEmpty }

    /// One feedback line: server error wins, else the mismatch hint.
    private var feedbackLine: String? {
        authViewModel.errorMessage ?? (bothPasswordsEntered && !passwordsMatch ? "Passwords don't match" : nil)
    }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 48)

                    // Header
                    VStack(spacing: 12) {
                        Image(MascotMood.playful.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 130, height: 130)

                        Text("Create Account")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.textPri)

                        Text("Join Abimo today")
                            .font(.system(size: 15))
                            .foregroundColor(.textSec)
                    }

                    Spacer().frame(height: 40)

                    // Form card
                    VStack(spacing: 14) {
                        AppTextField(
                            placeholder: "Email",
                            text: $email,
                            keyboardType: .emailAddress
                        )
                        .textContentType(.emailAddress)

                        AppTextField(
                            placeholder: "Password",
                            text: $password,
                            isSecure: true
                        )
                        .textContentType(.newPassword)

                        AppTextField(
                            placeholder: "Confirm Password",
                            text: $confirmPassword,
                            isSecure: true
                        )
                        .textContentType(.newPassword)
                        .overlay(alignment: .trailing) {
                            // Match confirmation lives inside the field, not as a text row
                            if bothPasswordsEntered && passwordsMatch {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.brandGreen)
                                    .padding(.trailing, 14)
                            }
                        }

                        if let feedbackLine {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 13))
                                Text(feedbackLine)
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.brand)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        GradientButton(
                            title: "Create Account",
                            isLoading: authViewModel.isLoading,
                            isDisabled: !canSubmit
                        ) {
                            Task {
                                await authViewModel.signUp(email: email, password: password)
                                if authViewModel.isAuthenticated { dismiss() }
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 24)

                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15))
                        .foregroundColor(.textSec)
                        .disabled(authViewModel.isLoading)

                    Spacer().frame(height: 40)
                }
            }
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthViewModel())
}
