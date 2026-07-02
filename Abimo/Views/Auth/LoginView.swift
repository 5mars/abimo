//
//  LoginView.swift
//  Abimo
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Background
            Color.appBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    // Mascot + title
                    VStack(spacing: 12) {
                        Image(MascotMood.playful.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 170, height: 170)
                            .scaleEffect(appeared ? 1 : 0.6)
                            .opacity(appeared ? 1 : 0)

                        Text("Abimo")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.textPri)

                        Text("Record ideas, analyze instantly")
                            .font(.system(size: 16))
                            .foregroundColor(.textSec)
                    }
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)

                    Spacer().frame(height: 48)

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
                        .textContentType(.password)

                        if let errorMessage = authViewModel.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 13))
                                Text(errorMessage)
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.brand)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                        }

                        GradientButton(
                            title: "Sign In",
                            isLoading: authViewModel.isLoading,
                            isDisabled: email.isEmpty || password.isEmpty
                        ) {
                            Task { await authViewModel.signIn(email: email, password: password) }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .offset(y: appeared ? 0 : 30)
                    .opacity(appeared ? 1 : 0)

                    Spacer().frame(height: 24)

                    // Sign up link
                    Button {
                        showSignUp = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(.textSec)
                            Text("Sign Up")
                                .foregroundColor(.brand)
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 15))
                    }
                    .disabled(authViewModel.isLoading)
                    .opacity(appeared ? 1 : 0)

                    Spacer().frame(height: 40)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) {
                appeared = true
            }
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
                .environmentObject(authViewModel)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
