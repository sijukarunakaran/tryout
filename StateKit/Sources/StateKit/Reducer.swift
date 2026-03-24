//
//  Reducer.swift
//  Core
//
//  Created by Siju Karunakaran(UST,IN) on 14/05/25.
//

import Foundation

/// A reducer that synchronously updates `State` and returns an `Effect` of new `Action` values.
public struct Reducer<State: Sendable, Action: Sendable> {
    public let reduce: (inout State, Action) -> Effect<Action>

    /// Create a reducer from a closure
    public init(
        _ reduce: @escaping (inout State, Action) -> Effect<Action>
    ) {
        self.reduce = reduce
    }

    /// Enable calling the struct like a function
    public func callAsFunction(
        _ state: inout State,
        _ action: Action
    ) -> Effect<Action> {
        self.reduce(&state, action)
    }

    /// Combine multiple reducers into one by merging their effects.
    public static func combine(
        _ reducers: Reducer<State, Action>...
    ) -> Reducer<State, Action> {
        Reducer { state, action in
            let effects = reducers.map { $0.reduce(&state, action) }
            return Effect.merge(effects)
        }
    }

    /// Pullback a local reducer into a global one.
    /// `extract` and `embed` are now `@Sendable` to satisfy `Effect.map`.
    public func pullback<GlobalState, GlobalAction>(
        state toLocal: WritableKeyPath<GlobalState, State>,
        action extract: @Sendable @escaping (GlobalAction) -> Action?,
        embed embedLocal: @Sendable @escaping (Action) -> GlobalAction
    ) -> Reducer<GlobalState, GlobalAction> {
        Reducer<GlobalState, GlobalAction> { globalState, globalAction in
            guard let localAction = extract(globalAction) else { return .none }
            var localState = globalState[keyPath: toLocal]
            let effect = self.reduce(&localState, localAction)
            globalState[keyPath: toLocal] = localState
            return effect.map(embedLocal)
        }
    }
}

public extension Reducer {
    /// Wrap this reducer so you get callbacks before and/or after every action.
    func intercept(
        willDispatch: ((State, Action) -> Void)? = nil,
        didDispatch: ((State, Action) -> Void)? = nil
    ) -> Reducer<State, Action> {
        Reducer { state, action in
            // 1️⃣ callback before state changes
            willDispatch?(state, action)

            // 2️⃣ run original reducer logic
            let effect = self.reduce(&state, action)

            // 3️⃣ callback after state has been updated
            didDispatch?(state, action)
            return effect
        }
    }
}

extension Reducer {
    /// Lift a reducer over `State` into one over `State?`.
    /// - If state is `nil`, the action is ignored and `.none` is returned.
    /// - If state is non-nil, it’s forwarded to the underlying reducer.
    public var optional: Reducer<State?, Action> {
        Reducer<State?, Action> { state, action in
            // If the optional state is missing, do nothing
            guard var unwrapped = state else {
                return .none
            }

            let effect = self.reduce(&unwrapped, action)
            state = unwrapped
            return effect
        }
    }
}
