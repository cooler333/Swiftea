import Combine

import XCTest

@testable import Swiftea

final class SwifteaTests: XCTestCase {
    var cancellable: Set<AnyCancellable> = []
    var backgroundConcurrentQueue = DispatchQueue(label: "backgroundConcurrentQueue")

    override func tearDown() {
        super.tearDown()

        cancellable.forEach { $0.cancel() }
    }

    // swiftlint:disable:next function_body_length
    func testStoreRaceCondition() throws {
        // Arrange
        struct Model: Equatable, CustomStringConvertible {
            let index: Int

            var description: String {
                return "Index: \(index)"
            }
        }

        struct State: Equatable {
            var page = 0
            var models: [Model] = []
            var isLoading = false
            var isFinished = false
        }

        enum Event {
            case loadInitial
            case loadNextPage
            case receiveData([Model])
            case finish
            case receiveFinish
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

            case let .receiveData(models):
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

            case .receiveFinish:
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
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveData(models)))
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
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveData(models)))
                    }
                }
                .eraseToAnyPublisher()

            case .finish:
                return Future<Event, Never> { promise in
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveFinish))
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
        var additionalEventsHandled = false

        store.statePublisher.sink { state in
            if state.page == 1, !additionalEventsHandled {
                additionalEventsHandled = true
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
        .store(in: &cancellable)

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
        struct Model: Equatable, CustomStringConvertible {
            let index: Int

            var description: String {
                return "Index: \(index)"
            }
        }

        struct State: Equatable {
            var page = 0
            var models: [Model] = []
            var isLoading = false
            var isFinished = false
        }

        enum Event {
            case loadInitial
            case loadNextPage
            case cancelPreviousRequests
            case receiveData([Model])
            case finish
            case receiveFinish
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
                    cancellableCommands: [.cancelPreviousLoadNextData]
                )

            case .cancelPreviousRequests:
                return .dispatch([.cancelPreviousLoadNextData])

            case .cancelled:
                return .empty

            case let .receiveData(models):
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

            case .receiveFinish:
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
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveData(models)))
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
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveData(models)))
                    }
                }
                .eraseToAnyPublisher()

            case .cancelPreviousLoadNextData:
                return Just<Event>(.cancelled)
                    .eraseToAnyPublisher()

            case .finish:
                return Future<Event, Never> { promise in
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveFinish))
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
        var additionalEventsHandled = false

        store.statePublisher.sink { state in
            if state.page == 1, !additionalEventsHandled {
                additionalEventsHandled = true
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
        .store(in: &cancellable)

        store.dispatch(event: .loadInitial)

        // Assert
        wait(for: [responsesExpectation], timeout: 1)

        XCTAssertEqual(lastState.page, 2)
        XCTAssertEqual(lastState.models.count, 10)
    }

    // swiftlint:disable:next function_body_length
    func testSubscriptionCancellationUsingCommand() throws {
        // Arrange
        struct Model: Equatable, CustomStringConvertible {
            let index: Int

            var description: String {
                return "Index: \(index)"
            }
        }

        struct State: Equatable {
            var page = 0
            var models: [Model] = []
            var isFinished = false
        }

        enum Event {
            case loadInitial
            case loadNextPage
            case receiveData([Model])
            case finish
            case receiveFinish
            case receiveCancelPreviousLoadNextData
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
                return .dispatch([.loadInitialData])

            case .loadNextPage:
                return .dispatchCancellable(
                    commands: [.cancelPreviousLoadNextData, .loadNextData],
                    cancellableCommands: [.cancelPreviousLoadNextData]
                )

            case let .receiveData(models):
                var state = state
                if state.page == 0 {
                    state.models = models
                } else {
                    state.models += models
                }
                state.page += 1
                return .next(state)

            case .finish:
                return .dispatch([.finish])

            case .receiveCancelPreviousLoadNextData:
                return .empty

            case .receiveFinish:
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
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveData(models)))
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
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveData(models)))
                    }
                }
                .eraseToAnyPublisher()

            case .cancelPreviousLoadNextData:
                return Just<Event>(.receiveCancelPreviousLoadNextData)
                    .eraseToAnyPublisher()

            case .finish:
                return Future<Event, Never> { promise in
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveFinish))
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
        var additionalEventsHandled = false

        store.statePublisher.sink { state in
            if state.page == 1, !additionalEventsHandled {
                additionalEventsHandled = true
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
        .store(in: &cancellable)

        store.dispatch(event: .loadInitial)

        // Assert
        wait(for: [responsesExpectation], timeout: 1)

        XCTAssertEqual(lastState.page, 2)
        XCTAssertEqual(lastState.models.count, 10)
    }

    // swiftlint:disable:next function_body_length
    func testNextWithUnchangedState() throws {
        // Arrange
        struct Model: Equatable, CustomStringConvertible {
            let index: Int

            var description: String {
                return "Index: \(index)"
            }
        }

        struct State: Equatable {
            var page = 0
            var models: [Model] = []
            var isFinished = false
        }

        enum Event {
            case loadInitial
            case loadNextPage
            case receiveData([Model])
            case finish
            case receiveFinish
            case receiveCancelPreviousLoadNextData
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
                return .dispatch([.loadInitialData])

            case .loadNextPage:
                // Pass same state value to .next
                var state = state
                let isFinished = state.isFinished
                state.isFinished = isFinished
                return .nextAndDispatchCancellable(
                    state,
                    commands: [.cancelPreviousLoadNextData, .loadNextData],
                    cancellableCommands: [.cancelPreviousLoadNextData]
                )

            case let .receiveData(models):
                var state = state
                if state.page == 0 {
                    state.models = models
                } else {
                    state.models += models
                }
                state.page += 1
                return .next(state)

            case .finish:
                return .dispatch([.finish])

            case .receiveCancelPreviousLoadNextData:
                return .empty

            case .receiveFinish:
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
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveData(models)))
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
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveData(models)))
                    }
                }
                .eraseToAnyPublisher()

            case .cancelPreviousLoadNextData:
                return Just<Event>(.receiveCancelPreviousLoadNextData)
                    .eraseToAnyPublisher()

            case .finish:
                return Future<Event, Never> { promise in
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveFinish))
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
        var additionalEventsHandled = false

        store.statePublisher.sink { state in
            if state.page == 1, !additionalEventsHandled {
                additionalEventsHandled = true
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
        .store(in: &cancellable)

        store.dispatch(event: .loadInitial)

        // Assert
        wait(for: [responsesExpectation], timeout: 1)

        XCTAssertEqual(lastState.page, 2)
        XCTAssertEqual(lastState.models.count, 10)
    }

    // swiftlint:disable:next function_body_length
    func testEventsOrder() throws {
        // Arrange
        struct State: Equatable {
            var page = 0
            var isLoading = false
            var isFinished = false
        }

        enum Event {
            case loadInitial
            case loadNextPage
            case cancelPreviousRequests
            case receiveDataFOOBAR
            case finish
            case receiveFinishFOOBAR
            case cancelledFOOBAR
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
                    cancellableCommands: [.cancelPreviousLoadNextData]
                )

            case .cancelPreviousRequests:
                return .dispatch([.cancelPreviousLoadNextData])

            case .cancelledFOOBAR:
                return .empty

            case .receiveDataFOOBAR:
                var state = state
                state.isLoading = false
                state.page += 1
                return .next(state)

            case .finish:
                return .dispatch([.finish])

            case .receiveFinishFOOBAR:
                var state = state
                state.isFinished = true
                return .next(state)
            }
        }

        let commandHandlerReduce: (Command, Environment) -> AnyPublisher<Event, Never> = { command, _ in
            switch command {
            case .loadInitialData:
                return Future<Event, Never> { promise in
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveDataFOOBAR))
                    }
                }
                .eraseToAnyPublisher()

            case .loadNextData:
                return Future<Event, Never> { promise in
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveDataFOOBAR))
                    }
                }
                .eraseToAnyPublisher()

            case .cancelPreviousLoadNextData:
                return Just<Event>(.cancelledFOOBAR)
                    .eraseToAnyPublisher()

            case .finish:
                return Future<Event, Never> { promise in
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveFinishFOOBAR))
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
        var additionalEventsHandled = false

        store.statePublisher.sink { state in
            if state.page == 1, !additionalEventsHandled {
                additionalEventsHandled = true
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
        .store(in: &cancellable)

        store.dispatch(event: .loadInitial)

        // Assert
        wait(for: [responsesExpectation], timeout: 1)

        let referenceEventsOrder: [Event] = [
            .loadInitial,
            .receiveDataFOOBAR,
            .loadNextPage,
            .loadNextPage,
            .loadNextPage,
            .cancelPreviousRequests,
            .loadNextPage,
            .finish,
            .cancelledFOOBAR,
            .receiveDataFOOBAR,
            .receiveFinishFOOBAR,
        ]

        XCTAssertEqual(events, referenceEventsOrder)
    }

    // swiftlint:disable:next function_body_length
    func testCommandsOrder() throws {
        // Arrange
        struct State: Equatable {
            var page = 0
            var isLoading = false
            var isFinished = false
        }

        enum Event {
            case loadInitial
            case loadNextPage
            case cancelPreviousRequests
            case receiveData
            case finish
            case receiveFinish
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
                    cancellableCommands: [.cancelPreviousLoadNextData]
                )

            case .cancelPreviousRequests:
                return .dispatch([.cancelPreviousLoadNextData])

            case .cancelled:
                return .empty

            case .receiveData:
                var state = state
                state.isLoading = false
                state.page += 1
                return .next(state)

            case .finish:
                return .dispatch([.finish])

            case .receiveFinish:
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
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveData))
                    }
                }
                .eraseToAnyPublisher()

            case .loadNextData:
                return Future<Event, Never> { promise in
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveData))
                    }
                }
                .eraseToAnyPublisher()

            case .cancelPreviousLoadNextData:
                return Just<Event>(.cancelled)
                    .eraseToAnyPublisher()

            case .finish:
                return Future<Event, Never> { promise in
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveFinish))
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
        var additionalEventsHandled = false

        store.statePublisher.sink { state in
            if state.page == 1, !additionalEventsHandled {
                additionalEventsHandled = true
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
        .store(in: &cancellable)

        store.dispatch(event: .loadInitial)

        // Assert
        wait(for: [responsesExpectation], timeout: 1)

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

    // swiftlint:disable:next function_body_length
    func testStateOrder() throws {
        // Arrange
        struct Model: Equatable, CustomStringConvertible {
            let index: Int

            var description: String {
                return "Index: \(index)"
            }
        }

        struct State: Equatable {
            var page = 0
            var models: [Model] = []
            var isLoading = false
            var isFinished = false
        }

        enum Event {
            case loadInitial
            case loadNextPage
            case receiveData([Model])
            case finish
            case receiveFinish
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

            case let .receiveData(models):
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

            case .receiveFinish:
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
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveData(models)))
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
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveData(models)))
                    }
                }
                .eraseToAnyPublisher()

            case .finish:
                return Future<Event, Never> { promise in
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveFinish))
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
        var states: [State] = []

        // Act
        var additionalEventsHandled = false

        store.statePublisher.sink { state in
            states.append(state)
            if state.page == 1, !additionalEventsHandled {
                additionalEventsHandled = true
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .loadNextPage)
                store.dispatch(event: .finish)
            }

            if state.isFinished {
                responsesExpectation.fulfill()
            }
        }
        .store(in: &cancellable)

        store.dispatch(event: .loadInitial)

        // Assert
        wait(for: [responsesExpectation], timeout: 1)

        let referenceStates: [State] = [
            State(page: 0, models: [], isLoading: false, isFinished: false),
            State(page: 0, models: [], isLoading: true, isFinished: false),
            State(page: 1, models: [
                Model(index: 0),
                Model(index: 1),
                Model(index: 2),
                Model(index: 3),
                Model(index: 4),
            ], isLoading: false, isFinished: false),
            State(page: 1, models: [
                Model(index: 0),
                Model(index: 1),
                Model(index: 2),
                Model(index: 3),
                Model(index: 4),
            ], isLoading: true, isFinished: false),
            State(page: 1, models: [
                Model(index: 0),
                Model(index: 1),
                Model(index: 2),
                Model(index: 3),
                Model(index: 4),
            ], isLoading: true, isFinished: false),
            State(page: 2, models: [
                Model(index: 0),
                Model(index: 1),
                Model(index: 2),
                Model(index: 3),
                Model(index: 4),
                Model(index: 5),
                Model(index: 6),
                Model(index: 7),
                Model(index: 8),
                Model(index: 9),
            ], isLoading: false, isFinished: false),
            State(page: 2, models: [
                Model(index: 0),
                Model(index: 1),
                Model(index: 2),
                Model(index: 3),
                Model(index: 4),
                Model(index: 5),
                Model(index: 6),
                Model(index: 7),
                Model(index: 8),
                Model(index: 9),
            ], isLoading: false, isFinished: true),
        ]

        XCTAssertEqual(states, referenceStates)
    }

    // swiftlint:disable:next function_body_length
    func testStateData() throws {
        // Arrange
        struct State: Equatable {
            var page = 0
            var isLoading = false
            var isFinished = false
        }

        enum Event {
            case loadInitial
            case loadNextPage
            case receiveData(value: Int)
            case finish
            case receiveFinish
        }

        enum Command: Equatable {
            case loadInitialData(value: Int)
            case loadNextData(value: Int)
            case finish
        }

        struct Environment {}

        let reducerReduce: (State, Event) -> Next<State, Command> = { state, event in
            switch event {
            case .loadInitial:
                var state = state
                state.isLoading = true
                return .nextAndDispatch(state, [.loadInitialData(value: state.page)])

            case .loadNextPage:
                var state = state
                state.isLoading = true
                return .nextAndDispatch(
                    state,
                    [.loadNextData(value: state.page)]
                )

            case .receiveData:
                var state = state
                state.isLoading = false
                state.page += 1
                return .next(state)

            case .finish:
                return .dispatch([.finish])

            case .receiveFinish:
                var state = state
                state.isFinished = true
                return .next(state)
            }
        }

        let commandHandlerReduce: (Command, Environment) -> AnyPublisher<Event, Never> = { command, _ in
            switch command {
            case let .loadInitialData(value):
                return Future<Event, Never> { promise in
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveData(value: value)))
                    }
                }
                .eraseToAnyPublisher()

            case let .loadNextData(value):
                return Future<Event, Never> { promise in
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveData(value: value)))
                    }
                }
                .eraseToAnyPublisher()

            case .finish:
                return Future<Event, Never> { promise in
                    self.backgroundConcurrentQueue.async {
                        promise(.success(.receiveFinish))
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
        var stateValues: [State] = []

        // Act
        var additionalEventsHandled = false

        store.statePublisher.sink { state in
            stateValues.append(state)

            if state.page == 1, !additionalEventsHandled {
                additionalEventsHandled = true
                for _ in (0...100) {
                    store.dispatch(event: .loadNextPage)
                }
                store.dispatch(event: .finish)
            }

            if state.isFinished {
                responsesExpectation.fulfill()
            }
        }
        .store(in: &cancellable)

        store.dispatch(event: .loadInitial)

        // Assert
        wait(for: [responsesExpectation], timeout: 1)

        let referenceStateValues: [Int] = Array(0...102)
        XCTAssertEqual( stateValues.map { $0.page }.uniqued(), referenceStateValues)
    }

}

extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}
