import Foundation
import Observation
import SwiftUI

/// A single source of truth for state + effects, entirely @MainActor-isolated.
@Observable
@MainActor
public final class Store<State: Sendable & Equatable, Action: Sendable> {
    public private(set) var state: State
    private let reducer: Reducer<State, Action>
    private let isActive: () -> Bool
    // TaskBag is reference-typed; its own deinit cancels all tasks,
    // so Store.deinit doesn't need to touch any @MainActor-isolated state.
    private let taskBag = TaskBag()

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

        let effect = self.reducer.callAsFunction(&self.state, action)
        guard !effect.isEmpty else { return }
        let tasks = effect.run { @Sendable [weak self] result in
            Task { @MainActor in
                self?.send(result)
            }
        }
        taskBag.add(tasks)
    }

    /// Scope this store to a child store, keeping state in sync.
    ///
    /// `LocalState` must be `Equatable` so that unchanged derived state does
    /// not cause spurious SwiftUI re-renders.
    public func scope<LocalState: Sendable & Equatable, LocalAction: Sendable>(
        state toLocal: @Sendable @escaping (State) -> LocalState,
        action fromLocal: @Sendable @escaping (LocalAction) -> Action
    ) -> Store<LocalState, LocalAction> {
        let localReducer = Reducer<LocalState, LocalAction> { [weak self] localState, localAction in
            guard let self else { return .none }
            self.send(fromLocal(localAction))
            localState = toLocal(self.state)
            return .none
        }

        let localStore = Store<LocalState, LocalAction>(
            initialState: toLocal(self.state),
            reducer: localReducer
        )

        observeStateChanges { [weak self, weak localStore] in
            guard let self, let localStore else { return }
            let newState = toLocal(self.state)
            guard localStore.state != newState else { return }
            localStore.state = newState
        }

        return localStore
    }

    /// Perpetually observes `state` and calls `onChange` on every mutation.
    /// Re-registers after each firing so the loop is perpetual while `self` is alive.
    ///
    /// The `onChange` closure is `@MainActor`-isolated, so callers can freely
    /// capture non-Sendable values (e.g. `KeyPath`) without any unsafe wrappers —
    /// `@MainActor` closures are implicitly `Sendable` (SE-0302) and their captures
    /// are guaranteed to be accessed only on the main actor.
    private func observeStateChanges(
        onChange: @MainActor @escaping () -> Void
    ) {
        withObservationTracking {
            _ = self.state
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                onChange()
                self.observeStateChanges(onChange: onChange)
            }
        }
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

extension Store {
    /// Convenience to build a child store for an optional child state.
    ///
    /// Returns `nil` immediately when the child state is absent. The returned
    /// store stops accepting actions once the parent's optional becomes `nil`.
    public func ifLet<ChildState: Sendable & Equatable, ChildAction: Sendable>(
        state keyPath: KeyPath<State, ChildState?>,
        action: @escaping @Sendable (ChildAction) -> Action
    ) -> Store<ChildState, ChildAction>? {
        guard let initialChild = state[keyPath: keyPath] else {
            return nil
        }

        let localReducer = Reducer<ChildState, ChildAction> { [weak self] localState, localAction in
            guard let self else { return .none }
            self.send(action(localAction))
            if let latest = self.state[keyPath: keyPath] {
                localState = latest
            }
            return .none
        }

        let childStore = Store<ChildState, ChildAction>(
            initialState: initialChild,
            reducer: localReducer,
            isActive: { [weak self] in self?.state[keyPath: keyPath] != nil }
        )

        // `keyPath` is non-Sendable, but captured inside a @MainActor closure —
        // Swift 6 allows this because the closure only ever runs on the main actor.
        observeStateChanges { [weak self, weak childStore] in
            guard let self, let childStore else { return }
            guard let value = self.state[keyPath: keyPath], childStore.state != value else { return }
            childStore.state = value
        }

        return childStore
    }
}

/// Collects `Task` references and cancels them all when deallocated.
///
/// Using a separate reference-typed container avoids the `@MainActor`/`deinit`
/// isolation mismatch: Store's `deinit` is nonisolated and cannot touch
/// `@MainActor`-isolated stored properties directly.
private final class TaskBag: @unchecked Sendable {
    private var tasks: [Task<Void, Never>] = []
    private let lock = NSLock()

    func add(_ newTasks: [Task<Void, Never>]) {
        guard !newTasks.isEmpty else { return }
        lock.withLock {
            tasks = tasks.filter { !$0.isCancelled }
            tasks.append(contentsOf: newTasks)
        }
    }

    deinit {
        lock.withLock { tasks.forEach { $0.cancel() } }
    }
}
