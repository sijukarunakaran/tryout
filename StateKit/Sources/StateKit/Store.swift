import Combine
import Foundation
import SwiftUI

/// A single source of truth for state + effects, entirely @MainActor-isolated.
@MainActor
public final class Store<State: Sendable & Equatable, Action: Sendable>: ObservableObject {
    @Published public private(set) var state: State
    private let reducer: Reducer<State, Action>
    private let isActive: () -> Bool
    private var effectsCancellables: Set<AnyCancellable> = []

    /// Initialize the store with an initial state and a Reducer struct.
    public init(
        initialState: State,
        reducer: Reducer<State, Action>,
        isActive: @escaping () -> Bool = { true }
    ) {
        self.state = initialState
        self.reducer = reducer
        self.isActive = isActive
    }

    /// Send an action through the reducer, run any returned effect,
    /// and re-send any resulting actions back through `send(_:)`.
    public func send(_ action: Action) {
        guard self.isActive() else { return }

        // Invoke the Reducer struct
        let effect = self.reducer.callAsFunction(&self.state, action)
        effect.run { @Sendable result in
            Task { @MainActor in
                self.send(result)
            }
        }
    }

    /// Scope this store to a local child store, keeping state in sync.
    public func scope<LocalState: Sendable, LocalAction: Sendable>(
        state toLocal: @Sendable @escaping (State) -> LocalState,
        action fromLocal: @Sendable @escaping (LocalAction) -> Action
    ) -> Store<LocalState, LocalAction> {
        // Create a local reducer that forwards actions and updates local state
        let localReducer = Reducer<LocalState, LocalAction> { localState, localAction in
            self.send(fromLocal(localAction))
            localState = toLocal(self.state)
            return .none
        }

        let localStore = Store<LocalState, LocalAction>(
            initialState: toLocal(self.state),
            reducer: localReducer
        )

        // Keep the local store in sync with this store's state
        self.$state
            .map(toLocal)
            .removeDuplicates()
            .sink { newLocalState in
                localStore.state = newLocalState
            }
            .store(in: &localStore.effectsCancellables)

        return localStore
    }
}

extension Store {
    /// Create a SwiftUI Binding from a store's state and an action-generator.
    public func binding<Value>(
        get toLocal: @escaping (State) -> Value,
        send toAction: @escaping (Value) -> Action
    ) -> Binding<Value> {
        Binding<Value>(
            get: { toLocal(self.state) },
            set: { newValue in
                self.send(toAction(newValue))
            }
        )
    }
}

extension Store where State: Sendable, Action: Sendable {
    /// Convenience to build a child store for an optional child state.
    public func ifLet<ChildState: Sendable & Equatable, ChildAction: Sendable>(
        state keyPath: KeyPath<State, ChildState?>,
        action: @escaping @Sendable (ChildAction) -> Action
    ) -> Store<ChildState, ChildAction>? {
        // 1. Capture the initial child state, or bail out.
        guard let initialChild = state[keyPath: keyPath] else {
            return nil
        }

        // 2. Build a local reducer that forwards actions
        //    and resyncs from the parent when possible.
        let parent = self

        let localReducer = Reducer<ChildState, ChildAction> { localState, localAction in
            // Forward action to parent
            parent.send(action(localAction))

            // After parent handled it, try to resync local state
            if let latest = parent.state[keyPath: keyPath] {
                localState = latest
            }

            return .none
        }

        // 3. Create the child store with the initial child state.
        let childStore = Store<ChildState, ChildAction>(
            initialState: initialChild,
            reducer: localReducer,
            isActive: { parent.state[keyPath: keyPath] != nil }
        )

        // 4. Keep the child in sync with the parent *only while child exists*.
        parent.$state
            .map { $0[keyPath: keyPath] }
            .removeDuplicates { lhs, rhs in
                switch (lhs, rhs) {
                case (nil, nil):
                    true
                case let (l?, r?):
                    l == r
                default:
                    false
                }
            }
            .sink { [weak childStore] maybeChild in
                guard let childStore, let value = maybeChild else {
                    // Parent child became nil: don't crash, just stop updating.
                    return
                }
                childStore.state = value
            }
            .store(in: &childStore.effectsCancellables)

        return childStore
    }
}
