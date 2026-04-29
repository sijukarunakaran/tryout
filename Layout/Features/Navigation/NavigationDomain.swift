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
        Reducer<State, Action> { state, action in
            switch action {
            case .selectTab(let tab):
                state.selectedTab = tab
                return .none

            case .setHomeStack(let path):
                state.homeStack = path
                return .none

            case .setBrowseStack(let path):
                state.browseStack = path
                return .none

            case .presentLogin:
                if state.login == nil {
                    state.login = LoginState(id: UUID())
                }
                return .none

            case .dismissLogin:
                state.login = nil
                return .none

            case .presentShoppingListFlow(let flowState):
                state.shoppingListFlow = flowState
                return .none

            case .dismissShoppingListFlow:
                state.shoppingListFlow = nil
                return .none

            case .shoppingListFlow(.dismissed):
                state.shoppingListFlow = nil
                return .none

            case .shoppingListFlow:
                return .none

            case .openURL(let url):
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
        }
    )
}

typealias NavigationState = NavigationDomain.State
typealias NavigationAction = NavigationDomain.Action
