import XCTest
@testable import StateKit

final class ReducerScopingTests: XCTestCase {
    func testScopeRoutesChildActionToChildReducer() {
        struct ChildState: Equatable, Sendable {
            var count = 0
        }

        struct ParentState: Equatable, Sendable {
            var child = ChildState()
        }

        enum ChildAction: Sendable {
            case increment
        }

        @CasePathable
        enum ParentAction: Sendable {
            case child(ChildAction)
            case ignored
        }

        let childReducer = Reducer<ChildState, ChildAction> { state, action in
            switch action {
            case .increment:
                state.count += 1
                return .none
            }
        }

        let reducer = childReducer.scope(
            state: \ParentState.child,
            action: ParentAction.child
        )

        var state = ParentState()
        _ = reducer.reduce(&state, ParentAction.child(.increment))

        XCTAssertEqual(state.child.count, 1)
    }

    func testScopeIgnoresUnrelatedAction() {
        struct ChildState: Equatable, Sendable {
            var count = 0
        }

        struct ParentState: Equatable, Sendable {
            var child = ChildState()
        }

        enum ChildAction: Sendable {
            case increment
        }

        @CasePathable
        enum ParentAction: Sendable {
            case child(ChildAction)
            case ignored
        }

        let childReducer = Reducer<ChildState, ChildAction> { state, action in
            switch action {
            case .increment:
                state.count += 1
                return .none
            }
        }

        let reducer = childReducer.scope(
            state: \ParentState.child,
            action: ParentAction.child
        )

        var state = ParentState()
        _ = reducer.reduce(&state, ParentAction.ignored)

        XCTAssertEqual(state.child.count, 0)
    }

    func testGeneratedCasePathEmbedsAndExtracts() {
        enum ChildAction: Equatable, Sendable {
            case increment
        }

        @CasePathable
        enum ParentAction: Equatable, Sendable {
            case child(ChildAction)
            case ignored
        }

        XCTAssertEqual(ParentAction.child.extract(.child(.increment)), .increment)
        XCTAssertNil(ParentAction.child.extract(.ignored))
        XCTAssertEqual(ParentAction.child.embed(.increment), .child(.increment))
    }
}
