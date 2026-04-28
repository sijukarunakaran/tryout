import StateKit
import SwiftUI

struct LoginView: View {
    var store: Store<LoginState, LoginAction>
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sign in required")
                        .font(.system(size: 30, weight: .black, design: .rounded))

                    Text("Sign in only when you want to save lists or add something to the cart.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    TextField(
                        "Email",
                        text: store.binding(
                            get: \.email,
                            send: LoginAction.emailChanged
                        )
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .padding(16)
                    .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    SecureField(
                        "Password",
                        text: store.binding(
                            get: \.password,
                            send: LoginAction.passwordChanged
                        )
                    )
                    .focused($focusedField, equals: .password)
                    .padding(16)
                    .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                if let errorMessage = store.state.errorMessage {
                    Text(errorMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(red: 0.73, green: 0.17, blue: 0.14))
                }

                Button("Sign In") {
                    store.send(.signInTapped)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.13, green: 0.39, blue: 0.28))
                .controlSize(.large)

                Spacer()
            }
            .padding(24)
            .background(Color(red: 0.97, green: 0.96, blue: 0.93))
            .navigationTitle("Login")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Not Now") {
                        store.send(.cancelTapped)
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            focusedField = .email
        }
    }
}
