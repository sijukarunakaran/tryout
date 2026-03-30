# StateKit

`StateKit` is a lightweight reducer/store library for SwiftUI applications.

The latest update adds a macro-powered action routing flow:

- `@CasePathable` generates `CasePath` accessors for enum cases.
- `Reducer.scope(state:action:)` composes child reducers into parent reducers.
- The older closure-based `pullback` API is still available, but deprecated.

## Recommended style

The preferred architecture is:

- keep shared domain state once at the root
- let child features emit actions
- compose child reducers into the parent with `scope(state:action:)`

That keeps ownership explicit and avoids hidden shared mutable state.

## Example

This example shows an e-commerce style setup where `cart` lives once in root state and features compose into `AppReducer`.

```swift
import StateKit

struct Product: Equatable, Sendable {
    let id: Int
    let name: String
}

struct CartItem: Equatable, Sendable {
    var product: Product
    var quantity: Int
}

struct CartState: Equatable, Sendable {
    var items: [CartItem] = []
}

struct HomeState: Equatable, Sendable {
    var featured: [Product] = []
}

struct CheckoutState: Equatable, Sendable {
    var note = ""
}

struct AppState: Equatable, Sendable {
    var cart = CartState()
    var home = HomeState()
    var checkout = CheckoutState()
}

enum CartAction: Sendable {
    case add(Product)
    case remove(Product.ID)
}

enum HomeAction: Sendable {
    case addToCartTapped(Product)
}

enum CheckoutAction: Sendable {
    case removeFromCartTapped(Product.ID)
    case noteChanged(String)
}

@CasePathable
enum AppAction: Sendable {
    case cart(CartAction)
    case home(HomeAction)
    case checkout(CheckoutAction)
}

let cartReducer = Reducer<CartState, CartAction> { state, action in
    switch action {
    case let .add(product):
        if let index = state.items.firstIndex(where: { $0.product.id == product.id }) {
            state.items[index].quantity += 1
        } else {
            state.items.append(CartItem(product: product, quantity: 1))
        }
        return .none

    case let .remove(productID):
        state.items.removeAll { $0.product.id == productID }
        return .none
    }
}

let homeReducer = Reducer<HomeState, HomeAction> { state, action in
    switch action {
    case .addToCartTapped:
        // Parent owns cart mutation.
        return .none
    }
}

let checkoutReducer = Reducer<CheckoutState, CheckoutAction> { state, action in
    switch action {
    case let .noteChanged(note):
        state.note = note
        return .none

    case .removeFromCartTapped:
        // Parent owns cart mutation.
        return .none
    }
}

let appReducer = Reducer<AppState, AppAction>.combine(
    homeReducer.scope(
        state: \AppState.home,
        action: AppAction.home
    ),
    checkoutReducer.scope(
        state: \AppState.checkout,
        action: AppAction.checkout
    ),
    cartReducer.scope(
        state: \AppState.cart,
        action: AppAction.cart
    ),
    Reducer<AppState, AppAction> { state, action in
        switch action {
        case let .home(.addToCartTapped(product)):
            return cartReducer.reduce(&state.cart, .add(product)).map(AppAction.cart)

        case let .checkout(.removeFromCartTapped(productID)):
            return cartReducer.reduce(&state.cart, .remove(productID)).map(AppAction.cart)

        case .cart, .home, .checkout:
            return .none
        }
    }
)

let store = Store(
    initialState: AppState(),
    reducer: appReducer
)

store.send(.home(.addToCartTapped(Product(id: 1, name: "Keyboard"))))
```

## Why this is preferred

- `cart` is owned once in `AppState`
- child reducers stay focused on feature state
- parent reducer coordinates changes to shared domain state
- action routing is explicit and type-safe

## Deprecated migration path

The older `pullback` API still works:

```swift
let legacyReducer = homeReducer.pullback(
    state: \AppState.home,
    action: { action in
        guard case let .home(value) = action else { return nil }
        return value
    },
    embed: AppAction.home
)
```

The recommended replacement is:

```swift
let reducer = homeReducer.scope(
    state: \AppState.home,
    action: AppAction.home
)
```

## Notes

- `@CasePathable` currently generates case-path accessors for enum cases with a single associated value.
- `scope(state:action:)` is additive and does not break existing `Reducer` code.
- `pullback` is deprecated to guide migration, but it is not removed.
