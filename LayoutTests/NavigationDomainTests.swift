import Foundation
import Testing
@testable import Layout

@Suite("NavigationDomain")
struct NavigationDomainTests {

    // MARK: - Tab switching

    @Test func selectTabUpdateSelectedTab() {
        var state = NavigationState()
        _ = NavigationDomain.reducer.reduce(&state, .selectTab(.browse))
        #expect(state.selectedTab == .browse)
    }

    // MARK: - Home stack

    @Test func setHomeStackUpdatesStack() {
        var state = NavigationState()
        let product = Product.catalog[0]
        _ = NavigationDomain.reducer.reduce(&state, .setHomeStack([.productDetail(product)]))
        #expect(state.homeStack == [.productDetail(product)])
    }

    @Test func setHomeStackEmptyPopsAll() {
        var state = NavigationState()
        state.homeStack = [.productDetail(Product.catalog[0])]
        _ = NavigationDomain.reducer.reduce(&state, .setHomeStack([]))
        #expect(state.homeStack.isEmpty)
    }

    // MARK: - Browse stack

    @Test func setBrowseStackUpdatesStack() {
        var state = NavigationState()
        let product = Product.catalog[1]
        _ = NavigationDomain.reducer.reduce(&state, .setBrowseStack([.productDetail(product)]))
        #expect(state.browseStack == [.productDetail(product)])
    }

    // MARK: - Login modal

    @Test func presentLoginCreatesLoginState() {
        var state = NavigationState()
        _ = NavigationDomain.reducer.reduce(&state, .presentLogin)
        #expect(state.login != nil)
    }

    @Test func presentLoginIsIdempotentWhenAlreadyPresent() {
        var state = NavigationState()
        _ = NavigationDomain.reducer.reduce(&state, .presentLogin)
        let firstID = state.login?.id
        _ = NavigationDomain.reducer.reduce(&state, .presentLogin)
        #expect(state.login?.id == firstID)
    }

    @Test func dismissLoginClearsLoginState() {
        var state = NavigationState()
        state.login = LoginState(id: UUID())
        _ = NavigationDomain.reducer.reduce(&state, .dismissLogin)
        #expect(state.login == nil)
    }

    // MARK: - Shopping list flow modal

    @Test func presentShoppingListFlowSetsModal() {
        var state = NavigationState()
        let flow = ShoppingListFlowState(id: UUID(), product: nil, mode: .create, availableLists: [])
        _ = NavigationDomain.reducer.reduce(&state, .presentShoppingListFlow(flow))
        #expect(state.shoppingListFlow != nil)
        #expect(state.shoppingListFlow?.mode == .create)
    }

    @Test func dismissShoppingListFlowClearsModal() {
        var state = NavigationState()
        state.shoppingListFlow = ShoppingListFlowState(id: UUID(), product: nil, mode: .create, availableLists: [])
        _ = NavigationDomain.reducer.reduce(&state, .dismissShoppingListFlow)
        #expect(state.shoppingListFlow == nil)
    }

    @Test func shoppingListFlowDismissedActionClearsModal() {
        var state = NavigationState()
        state.shoppingListFlow = ShoppingListFlowState(id: UUID(), product: nil, mode: .create, availableLists: [])
        _ = NavigationDomain.reducer.reduce(&state, .shoppingListFlow(.dismissed))
        #expect(state.shoppingListFlow == nil)
    }

    // MARK: - URL parsing

    @Test func openURLForKnownProductNavigatesToHomeAndPushesDestination() {
        var state = NavigationState()
        let product = Product.catalog[0]
        let url = URL(string: "layout://product/\(product.id.uuidString)")!
        _ = NavigationDomain.reducer.reduce(&state, .openURL(url))
        #expect(state.selectedTab == .home)
        #expect(state.homeStack == [.productDetail(product)])
    }

    @Test func openURLForUnknownProductIDDoesNothing() {
        var state = NavigationState()
        let url = URL(string: "layout://product/00000000-0000-0000-0000-000000000000")!
        _ = NavigationDomain.reducer.reduce(&state, .openURL(url))
        #expect(state.homeStack.isEmpty)
        #expect(state.selectedTab == .home)
    }

    @Test func openURLForCartSwitchesToCartTab() {
        var state = NavigationState()
        let url = URL(string: "layout://cart")!
        _ = NavigationDomain.reducer.reduce(&state, .openURL(url))
        #expect(state.selectedTab == .cart)
    }

    @Test func openURLForListsSwitchesToShoppingListsTab() {
        var state = NavigationState()
        let url = URL(string: "layout://lists")!
        _ = NavigationDomain.reducer.reduce(&state, .openURL(url))
        #expect(state.selectedTab == .shoppingLists)
    }

    @Test func openURLWithWrongSchemeDoesNothing() {
        var state = NavigationState()
        let url = URL(string: "https://example.com/cart")!
        _ = NavigationDomain.reducer.reduce(&state, .openURL(url))
        #expect(state.selectedTab == .home)
    }

    @Test func openURLWithUnknownHostDoesNothing() {
        var state = NavigationState()
        let url = URL(string: "layout://unknown")!
        _ = NavigationDomain.reducer.reduce(&state, .openURL(url))
        #expect(state.selectedTab == .home)
    }
}
