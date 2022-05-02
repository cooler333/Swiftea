import Combine

import XCTest

@testable import Swiftea

final class SwifteaTests: XCTestCase {
    var cancellableStore: Set<AnyCancellable> = []

    override func tearDown() {
        super.tearDown()

        cancellableStore.forEach { $0.cancel() }
    }

    // swiftlint:disable:next function_body_length
    func testStore() throws {
        struct Model: CustomStringConvertible {
            let index: Int

            var description: String {
                return "Index: \(index)"
            }
        }

        struct State {
            var page = 0
            var models: [Model] = []
            var isLoading = false
            var isFinished = false
        }

        enum Event {
            case loadInitial
            case loadNextPage
            case recieveData([Model])
            case finish
            case recieveFinish
        }

        enum Command {
            case loadInitialData
            case loadNextData
            case finish
        }

        struct Environment {}

        let reducerReduce: (State, Event) -> Next<State, Command> = { state, event in
            print("State: \(state)")
            print("Event: \(event)")

            switch event {
            case .loadInitial:
                var state = state
                state.isLoading = true
                return .nextAndDispatch(state, [.loadInitialData])

            case .loadNextPage:
                if state.isLoading {
                    return .empty
                }
                var state = state
                state.page += 1
                state.isLoading = true
                return .nextAndDispatch(state, [.loadNextData])

            case let .recieveData(models):
                var state = state
                state.isLoading = false
                if state.page == 0 {
                    state.models = models
                } else {
                    state.models += models
                }
                return .next(state)

            case .finish:
                return .nextAndDispatch(state, [.finish])

            case .recieveFinish:
                var state = state
                state.isFinished = true
                return .next(state)
            }
        }

        let commandHandlerReduce: (State, Command, Environment) -> AnyPublisher<Event, Never> = { _, command, _ in
            switch command {
            case .loadInitialData:
                let models = [
                    Model(index: 0),
                    Model(index: 1),
                    Model(index: 2),
                    Model(index: 3),
                    Model(index: 4),
                ]
                return Future<Event, Never> { promise in
                    DispatchQueue.main.async {
                        promise(.success(.recieveData(models)))
                    }
                }
                .eraseToAnyPublisher()

            case .loadNextData:
                let models = [
                    Model(index: 5),
                    Model(index: 6),
                    Model(index: 7),
                    Model(index: 8),
                    Model(index: 9),
                ]
                return Future<Event, Never> { promise in
                    DispatchQueue.main.async {
                        promise(.success(.recieveData(models)))
                    }
                }
                .eraseToAnyPublisher()

            case .finish:
                return Just<Event>(.recieveFinish)
                    .eraseToAnyPublisher()
            }
        }

        let store = Store<State, Event, Command, Environment>(
            state: .init(),
            reducer: .init(
                reduce: reducerReduce
            ), commandHandler: .init(
                reduce: commandHandlerReduce,
                environment: .init()
            )
        )

        let responsesExpectation = expectation(description: "wait for all responses")

        var lastState: State!
        store.statePublisher.sink { state in
            if state.page == 0, !state.isLoading {
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .finish)
            }

            if state.isFinished {
                lastState = state
                responsesExpectation.fulfill()
            }
        }
        .store(in: &cancellableStore)

        store.dispatch(event: .loadInitial)

        wait(for: [responsesExpectation], timeout: 10)

        XCTAssertEqual(lastState.page, 1)
        XCTAssertEqual(lastState.models.count, 10)
        XCTAssertEqual(lastState.isLoading, false)
    }
}
