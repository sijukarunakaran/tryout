import Foundation
import StateKit

@Feature
enum LoginDomain {
    @NonisolatedEquatable
    struct State: Identifiable, Sendable {
        let id: UUID
        var email = ""
        var password = ""
        var errorMessage: String?
    }

    enum Delegate: Sendable {
        case signedIn(email: String)
        case cancelled
    }

    @CasePathable
    enum Action: Sendable {
        case emailChanged(String)
        case passwordChanged(String)
        case signInTapped
        case cancelTapped
        case delegate(Delegate)
    }

    static let reducer = Reducer<State, Action> { state, action in
        switch action {
        case let .emailChanged(email):
            state.email = email
            state.errorMessage = nil
            return .none

        case let .passwordChanged(password):
            state.password = password
            state.errorMessage = nil
            return .none

        case .signInTapped:
            let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
            let password = state.password.trimmingCharacters(in: .whitespacesAndNewlines)

            guard email.isEmpty == false else {
                state.errorMessage = "Enter your email to continue."
                return .none
            }

            guard password.isEmpty == false else {
                state.errorMessage = "Enter your password to continue."
                return .none
            }

            return .task {
                .delegate(.signedIn(email: email))
            }

        case .cancelTapped:
            return .task {
                .delegate(.cancelled)
            }

        case .delegate:
            return .none
        }
    }
}

typealias LoginState = LoginDomain.State
typealias LoginAction = LoginDomain.Action

let loginReducer = LoginDomain.reducer
