import Foundation
import StateKit

@Feature
enum NavigationDomain {
    @NonisolatedEquatable
    struct State: Sendable {
        var selectedTab: AppTab = .home
        var homeStack: [AppDestination] = []
        var browseStack: [AppDestination] = []
        var login: LoginState?
        var shoppingListFlow: ShoppingListFlowState?
    }

    @CasePathable
    enum Action: Sendable {
        case selectTab(AppTab)
        case setHomeStack([AppDestination])
        case setBrowseStack([AppDestination])
        case presentLogin
        case dismissLogin
        case presentShoppingListFlow(ShoppingListFlowState)
        case dismissShoppingListFlow
        case shoppingListFlow(ShoppingListFlowAction)
        case openURL(URL)
    }

    static let reducer = Reducer<State, Action>.combine(
        shoppingListFlowReducer.optional.scope(
            state: \.shoppingListFlow,
            action: Action.shoppingListFlow
        ),
        .on(Action.selectTab) { state, tab in
            state.selectedTab = tab
            return .none
        },
        .on(Action.setHomeStack) { state, path in
            state.homeStack = path
            return .none
        },
        .on(Action.setBrowseStack) { state, path in
            state.browseStack = path
            return .none
        },
        .on(matching: { if case .presentLogin = $0 { return true }; return false }) { state in
            if state.login == nil {
                state.login = LoginState(id: UUID())
            }
            return .none
        },
        .on(matching: { if case .dismissLogin = $0 { return true }; return false }) { state in
            state.login = nil
            return .none
        },
        .on(Action.presentShoppingListFlow) { state, flowState in
            state.shoppingListFlow = flowState
            return .none
        },
        .on(matching: { if case .dismissShoppingListFlow = $0 { return true }; return false }) { state in
            state.shoppingListFlow = nil
            return .none
        },
        .on(Action.shoppingListFlow) { state, flowAction in
            if case .dismissed = flowAction {
                state.shoppingListFlow = nil
            }
            return .none
        },
        .on(Action.openURL) { state, url in
            guard
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                components.scheme == "layout"
            else { return .none }

            let host = components.host ?? ""
            let pathSegment = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            switch host {
            case "product":
                guard
                    let uuid = UUID(uuidString: pathSegment),
                    let product = Product.catalog.first(where: { $0.id == uuid })
                else { return .none }
                state.selectedTab = .home
                state.homeStack.append(.productDetail(product))

            case "cart":
                state.selectedTab = .cart

            case "lists":
                state.selectedTab = .shoppingLists

            default:
                break
            }
            return .none
        }
    )
}

typealias NavigationState = NavigationDomain.State
typealias NavigationAction = NavigationDomain.Action
