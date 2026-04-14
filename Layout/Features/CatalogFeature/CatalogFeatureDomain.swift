import Foundation
import StateKit

enum CatalogFeatureDomain {
    enum Delegate: Sendable {
        case addToCart(Product)
        case addProductToList(Product, ShoppingList.ID)
        case createList(name: String, product: Product?)
    }

    protocol State: Sendable {
        var products: [Product] { get set }
        var cartQuantities: [Product.ID: Int] { get set }
        var availableShoppingLists: [ShoppingList] { get set }
        var productDetail: ProductDetailState? { get set }
        var shoppingListFlow: ShoppingListFlowState? { get set }
    }

    struct Projection: Sendable {
        var cartQuantities: [Product.ID: Int]
        var shoppingLists: [ShoppingList]
    }

    struct ActionAdapter<Action: Sendable> {
        var productTapped: @Sendable (Action) -> Product.ID?
        var addToCartTapped: @Sendable (Action) -> Product?
        var addToListTapped: @Sendable (Action) -> (product: Product, hasExistingLists: Bool)?
        var productDetail: CasePath<Action, ProductDetailAction>
        var shoppingListFlow: CasePath<Action, ShoppingListFlowAction>
        var delegate: @Sendable (Delegate) -> Action
    }

    static func makeReducer<State: CatalogFeatureDomain.State, Action: Sendable>(
        adapter: ActionAdapter<Action>
    ) -> Reducer<State, Action> {
        Reducer<State, Action>.combine(
            productDetailReducer.optional.scope(
                state: \.productDetail,
                action: adapter.productDetail
            ),
            shoppingListFlowReducer.optional.scope(
                state: \.shoppingListFlow,
                action: adapter.shoppingListFlow
            ),
            Reducer<State, Action> { state, action in
                if let productID = adapter.productTapped(action) {
                    guard let product = state.products.first(where: { $0.id == productID }) else {
                        return .none
                    }
                    state.productDetail = ProductDetailState(
                        product: product,
                        cartQuantity: state.cartQuantities[product.id] ?? 0,
                        availableShoppingLists: state.availableShoppingLists
                    )
                    return .none
                }

                if let addToList = adapter.addToListTapped(action) {
                    state.shoppingListFlow = ShoppingListFlowState(
                        id: UUID(),
                        product: addToList.product,
                        mode: addToList.hasExistingLists ? .picker : .create,
                        availableLists: state.availableShoppingLists
                    )
                    return .none
                }

                if let product = adapter.addToCartTapped(action) {
                    return .task {
                        adapter.delegate(.addToCart(product))
                    }
                }

                if let detailAction = adapter.productDetail.extract(action) {
                    switch detailAction {
                    case let .addToCartTapped(product):
                        return .task {
                            adapter.delegate(.addToCart(product))
                        }

                    case let .shoppingListFlow(.listSelected(listID)):
                        guard let product = state.productDetail?.shoppingListFlow?.product else {
                            return .none
                        }
                        state.productDetail?.shoppingListFlow = nil
                        return .task {
                            adapter.delegate(.addProductToList(product, listID))
                        }

                    case .shoppingListFlow(.createListConfirmed):
                        guard let flow = state.productDetail?.shoppingListFlow else {
                            return .none
                        }
                        state.productDetail?.shoppingListFlow = nil
                        return .task {
                            adapter.delegate(.createList(name: flow.draftListName, product: flow.product))
                        }

                    case .dismissed:
                        state.productDetail = nil
                        return .none

                    case .addToListTapped, .shoppingListFlow:
                        return .none
                    }
                }

                if let flowAction = adapter.shoppingListFlow.extract(action) {
                    switch flowAction {
                    case let .listSelected(listID):
                        guard let product = state.shoppingListFlow?.product else {
                            return .none
                        }
                        state.shoppingListFlow = nil
                        return .task {
                            adapter.delegate(.addProductToList(product, listID))
                        }

                    case .createListConfirmed:
                        guard let flow = state.shoppingListFlow else {
                            return .none
                        }
                        state.shoppingListFlow = nil
                        return .task {
                            adapter.delegate(.createList(name: flow.draftListName, product: flow.product))
                        }

                    case .dismissed:
                        state.shoppingListFlow = nil
                        return .none

                    case .createNewListTapped, .draftListNameChanged:
                        return .none
                    }
                }

                return .none
            }
        )
    }

    static func makeProjection(
        cart: CartState,
        shoppingLists: [ShoppingList]
    ) -> Projection {
        Projection(
            cartQuantities: Dictionary(
                uniqueKeysWithValues: cart.items.map { ($0.product.id, $0.quantity) }
            ),
            shoppingLists: shoppingLists
        )
    }

    static func syncProductDetail(
        _ state: inout ProductDetailState?,
        projection: Projection
    ) {
        guard var detail = state else { return }
        detail.cartQuantity = projection.cartQuantities[detail.product.id] ?? 0
        detail.availableShoppingLists = projection.shoppingLists
        syncShoppingListFlow(&detail.shoppingListFlow, shoppingLists: projection.shoppingLists)
        state = detail
    }

    static func syncShoppingListFlow(
        _ state: inout ShoppingListFlowState?,
        shoppingLists: [ShoppingList]
    ) {
        state?.availableLists = shoppingLists
    }
}
