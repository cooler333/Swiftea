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
    func testStoreRaceCondition() throws {
        // Arrange
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
                state.page += 1
                return .next(state)

            case .finish:
                return .nextAndDispatch(state, [.finish])

            case .recieveFinish:
                var state = state
                state.isFinished = true
                return .next(state)
            }
        }

        let commandHandlerReduce: (Command, Environment) -> AnyPublisher<Event, Never> = { command, _ in
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
                return Future<Event, Never> { promise in
                    DispatchQueue.main.async {
                        promise(.success(.recieveFinish))
                    }
                }
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

        // Act
        store.statePublisher.sink { state in
            if state.page == 1, !state.isLoading {
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

        // Assert
        wait(for: [responsesExpectation], timeout: 1)

        XCTAssertEqual(lastState.page, 2)
        XCTAssertEqual(lastState.models.count, 10)
        XCTAssertEqual(lastState.isLoading, false)
    }

    // swiftlint:disable:next function_body_length
    func testSubscriptionCancellationUsingEvent() throws {
        // Arrange
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
            case cancelPreviousRequests
            case recieveData([Model])
            case finish
            case recieveFinish
            case cancelled
        }

        enum Command {
            case loadInitialData
            case cancelPreviousLoadNextData
            case loadNextData
            case finish
        }

        struct Environment {}

        let reducerReduce: (State, Event) -> Next<State, Command> = { state, event in
            switch event {
            case .loadInitial:
                var state = state
                state.isLoading = true
                return .nextAndDispatch(state, [.loadInitialData])

            case .loadNextPage:
                var state = state
                state.isLoading = true
                return .nextAndDispatchCancellable(
                    state,
                    commands: [.loadNextData],
                    cancellablecommands: [.cancelPreviousLoadNextData]
                )

            case .cancelPreviousRequests:
                return .dispatch([.cancelPreviousLoadNextData])

            case .cancelled:
                return .empty

            case let .recieveData(models):
                var state = state
                state.isLoading = false
                if state.page == 0 {
                    state.models = models
                } else {
                    state.models += models
                }
                state.page += 1
                return .next(state)

            case .finish:
                return .dispatch([.finish])

            case .recieveFinish:
                var state = state
                state.isFinished = true
                return .next(state)
            }
        }

        let commandHandlerReduce: (Command, Environment) -> AnyPublisher<Event, Never> = { command, _ in
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

            case .cancelPreviousLoadNextData:
                return Just<Event>(.cancelled)
                    .eraseToAnyPublisher()

            case .finish:
                return Future<Event, Never> { promise in
                    DispatchQueue.main.async {
                        promise(.success(.recieveFinish))
                    }
                }
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

        // Act
        store.statePublisher.sink { state in
            if state.page == 1, !state.isLoading {
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .cancelPreviousRequests)
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

        // Assert
        wait(for: [responsesExpectation], timeout: 10)

        XCTAssertEqual(lastState.page, 2)
        XCTAssertEqual(lastState.models.count, 10)
    }

    // swiftlint:disable:next function_body_length
    func testSubscriptionCancellationUsingCommand() throws {
        // Arrange
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
            case cancelled
        }

        enum Command {
            case loadInitialData
            case cancelPreviousLoadNextData
            case loadNextData
            case finish
        }

        struct Environment {}

        let reducerReduce: (State, Event) -> Next<State, Command> = { state, event in
            switch event {
            case .loadInitial:
                var state = state
                state.isLoading = true
                return .nextAndDispatch(state, [.loadInitialData])

            case .loadNextPage:
                var state = state
                state.isLoading = true
                return .nextAndDispatchCancellable(
                    state,
                    commands: [.cancelPreviousLoadNextData, .loadNextData],
                    cancellablecommands: [.cancelPreviousLoadNextData]
                )

            case let .recieveData(models):
                var state = state
                state.isLoading = false
                if state.page == 0 {
                    state.models = models
                } else {
                    state.models += models
                }
                state.page += 1
                return .next(state)

            case .finish:
                return .dispatch([.finish])

            case .cancelled:
                return .empty

            case .recieveFinish:
                var state = state
                state.isFinished = true
                return .next(state)
            }
        }

        let commandHandlerReduce: (Command, Environment) -> AnyPublisher<Event, Never> = { command, _ in
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

            case .cancelPreviousLoadNextData:
                return Just<Event>(.cancelled)
                    .eraseToAnyPublisher()

            case .finish:
                return Future<Event, Never> { promise in
                    DispatchQueue.main.async {
                        promise(.success(.recieveFinish))
                    }
                }
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

        // Act
        store.statePublisher
            .sink { state in
                if state.page == 1, !state.isLoading {
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

        // Assert
        wait(for: [responsesExpectation], timeout: 10)

        XCTAssertEqual(lastState.page, 2)
        XCTAssertEqual(lastState.models.count, 10)
    }

    // swiftlint:disable:next function_body_length
    func testEventsOrder() throws {
        // Arrange
        struct State {
            var page = 0
            var isLoading = false
            var isFinished = false
        }

        enum Event {
            case loadInitial
            case loadNextPage
            case cancelPreviousRequests
            case recieveData
            case finish
            case recieveFinish
            case cancelled
        }

        enum Command {
            case loadInitialData
            case cancelPreviousLoadNextData
            case loadNextData
            case finish
        }

        struct Environment {}

        var events: [Event] = []

        let reducerReduce: (State, Event) -> Next<State, Command> = { state, event in
            events.append(event)

            switch event {
            case .loadInitial:
                var state = state
                state.isLoading = true
                return .nextAndDispatch(state, [.loadInitialData])

            case .loadNextPage:
                var state = state
                state.isLoading = true
                return .nextAndDispatchCancellable(
                    state,
                    commands: [.loadNextData],
                    cancellablecommands: [.cancelPreviousLoadNextData]
                )

            case .cancelPreviousRequests:
                return .dispatch([.cancelPreviousLoadNextData])

            case .cancelled:
                return .empty

            case .recieveData:
                var state = state
                state.isLoading = false
                state.page += 1
                return .next(state)

            case .finish:
                return .dispatch([.finish])

            case .recieveFinish:
                var state = state
                state.isFinished = true
                return .next(state)
            }
        }

        let commandHandlerReduce: (Command, Environment) -> AnyPublisher<Event, Never> = { command, _ in
            switch command {
            case .loadInitialData:
                return Future<Event, Never> { promise in
                    DispatchQueue.main.async {
                        promise(.success(.recieveData))
                    }
                }
                .eraseToAnyPublisher()

            case .loadNextData:
                return Future<Event, Never> { promise in
                    DispatchQueue.main.async {
                        promise(.success(.recieveData))
                    }
                }
                .eraseToAnyPublisher()

            case .cancelPreviousLoadNextData:
                return Just<Event>(.cancelled)
                    .eraseToAnyPublisher()

            case .finish:
                return Future<Event, Never> { promise in
                    DispatchQueue.main.async {
                        promise(.success(.recieveFinish))
                    }
                }
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

        // Act
        store.statePublisher.sink { state in
            if state.page == 1, !state.isLoading {
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .cancelPreviousRequests)
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .finish)
            }

            if state.isFinished {
                responsesExpectation.fulfill()
            }
        }
        .store(in: &cancellableStore)

        store.dispatch(event: .loadInitial)

        // Assert
        wait(for: [responsesExpectation], timeout: 10)

        let referenceEventsOrder: [Event] = [
            .loadInitial,
            .recieveData,
            .loadNextPage,
            .loadNextPage,
            .loadNextPage,
            .cancelPreviousRequests,
            .cancelled,
            .loadNextPage,
            .finish,
            .recieveData,
            .recieveFinish,
        ]

        XCTAssertEqual(events, referenceEventsOrder)
    }

    // swiftlint:disable:next function_body_length
    func testCommandsOrder() throws {
        // Arrange
        struct State {
            var page = 0
            var isLoading = false
            var isFinished = false
        }

        enum Event {
            case loadInitial
            case loadNextPage
            case cancelPreviousRequests
            case recieveData
            case finish
            case recieveFinish
            case cancelled
        }

        enum Command {
            case loadInitialData
            case cancelPreviousLoadNextData
            case loadNextData
            case finish
        }

        struct Environment {}

        let reducerReduce: (State, Event) -> Next<State, Command> = { state, event in
            switch event {
            case .loadInitial:
                var state = state
                state.isLoading = true
                return .nextAndDispatch(state, [.loadInitialData])

            case .loadNextPage:
                var state = state
                state.isLoading = true
                return .nextAndDispatchCancellable(
                    state,
                    commands: [.loadNextData],
                    cancellablecommands: [.cancelPreviousLoadNextData]
                )

            case .cancelPreviousRequests:
                return .dispatch([.cancelPreviousLoadNextData])

            case .cancelled:
                return .empty

            case .recieveData:
                var state = state
                state.isLoading = false
                state.page += 1
                return .next(state)

            case .finish:
                return .dispatch([.finish])

            case .recieveFinish:
                var state = state
                state.isFinished = true
                return .next(state)
            }
        }

        var commands: [Command] = []

        let commandHandlerReduce: (Command, Environment) -> AnyPublisher<Event, Never> = { command, _ in
            commands.append(command)

            switch command {
            case .loadInitialData:
                return Future<Event, Never> { promise in
                    DispatchQueue.main.async {
                        promise(.success(.recieveData))
                    }
                }
                .eraseToAnyPublisher()

            case .loadNextData:
                return Future<Event, Never> { promise in
                    DispatchQueue.main.async {
                        promise(.success(.recieveData))
                    }
                }
                .eraseToAnyPublisher()

            case .cancelPreviousLoadNextData:
                return Just<Event>(.cancelled)
                    .eraseToAnyPublisher()

            case .finish:
                return Future<Event, Never> { promise in
                    DispatchQueue.main.async {
                        promise(.success(.recieveFinish))
                    }
                }
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

        // Act
        store.statePublisher.sink { state in
            if state.page == 1, !state.isLoading {
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .cancelPreviousRequests)
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .finish)
            }

            if state.isFinished {
                responsesExpectation.fulfill()
            }
        }
        .store(in: &cancellableStore)

        store.dispatch(event: .loadInitial)

        // Assert
        wait(for: [responsesExpectation], timeout: 10)

        commands.forEach { command in
            print(command)
        }

        let referenceCommandsOrder: [Command] = [
            .loadInitialData,
            .loadNextData,
            .loadNextData,
            .loadNextData,
            .cancelPreviousLoadNextData,
            .loadNextData,
            .finish,
        ]

        XCTAssertEqual(commands, referenceCommandsOrder)
    }
}
