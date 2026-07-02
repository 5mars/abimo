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

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            // Decorative blob
            Circle()
                .fill(Color.brandLight.opacity(0.18))
                .frame(width: 280, height: 280)
                .offset(x: 140, y: -60)
                .blur(radius: 80)
                .ignoresSafeArea()

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

                        // Validation feedback
                        if !password.isEmpty && !confirmPassword.isEmpty && !passwordsMatch {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 13))
                                Text("Passwords do not match")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.brandRed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if !password.isEmpty && !confirmPassword.isEmpty && passwordsMatch {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                Text("Passwords match")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.brandGreen)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let errorMessage = authViewModel.errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 13))
                                Text(errorMessage)
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.brandRed)
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
                    .cardStyle()
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
