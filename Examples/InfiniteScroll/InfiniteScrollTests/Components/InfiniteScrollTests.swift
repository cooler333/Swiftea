//
//  InfiniteScrollTests.swift
//  InfiniteScrollTests
//
//  Created by Dmitrii Coolerov on 05.05.2022.
//

import Combine
import Swiftea
import Swinject

import XCTest

@testable import InfiniteScroll

class InfiniteScrollTests: XCTestCase {
    var infiniteScrollRepository: InfiniteScrollRepositoryProtocolMock!

    var viewStore: ViewStore<InfiniteScrollViewState, InfiniteScrollViewEvent>!
    var viewController: UIViewController!

    var cancellable = Set<AnyCancellable>()

    var eventPublusher = PassthroughSubject<InfiniteScrollEvent, Never>()

    override func setUpWithError() throws {
        let container = Container()
        let resolver: Resolver = container

        infiniteScrollRepository = InfiniteScrollRepositoryProtocolMock()
        container.register(InfiniteScrollRepositoryProtocol.self) { _ in
            self.infiniteScrollRepository
        }

        let toastNotificationManager = ToastNotificationManagerProtocolMock()
        toastNotificationManager.showNotificationWithClosure = { _ in
            // unused
        }
        container.register(ToastNotificationManagerProtocol.self) { _ in
            toastNotificationManager
        }

        let feature = InfiniteScrollFeature()

        let testReducer = Reducer<InfiniteScrollState, InfiniteScrollEvent, InfiniteScrollCommand> { state, event in
            self.eventPublusher.send(event)
            return feature.getReducer().dispatch(state: state, event: event)
        }

        let store = Store<InfiniteScrollState, InfiniteScrollEvent, InfiniteScrollCommand, InfiniteScrollEnvironment>(
            state: InfiniteScrollState(),
            reducer: testReducer,
            commandHandler: feature.getCommandHandler(
                environment: InfiniteScrollEnvironment(
                    infiniteScrollRepository: resolver.resolve(InfiniteScrollRepositoryProtocol.self)!,
                    moduleOutput: nil
                )
            )
        )

        viewStore = ViewStore<InfiniteScrollViewState, InfiniteScrollViewEvent>(
            store: store,
            eventMapper: feature.getEventMapper(),
            stateMapper: feature.getStateMapper()
        )

        viewController = InfiniteScrollViewController(
            viewStore: viewStore,
            toastNotificationManager: resolver.resolve(ToastNotificationManagerProtocol.self)!
        )
    }

    override func tearDownWithError() throws {
        // unused
    }

    func testNextPage() throws {
        // Arrange
        let finalExpectation = expectation(description: "final")

        infiniteScrollRepository.getInfiniteScrollsWithPageLentgthReturnValue = Future<[InfiniteScrollModel], Error>({ promise in
            let data = (0...14).map { index in
                InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
            }
            promise(.success(data))
        }).eraseToAnyPublisher()

        eventPublusher.sink { event in
            if event == .updateInitialData(
                data: (0...14).map { index in
                    InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
                },
                isListEnded: false
            ) {
                self.infiniteScrollRepository.getInfiniteScrollsWithPageLentgthReturnValue = Future<[InfiniteScrollModel], Error>({ promise in
                    let data = (15...15).map { index in
                        InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
                    }
                    promise(.success(data))
                }).eraseToAnyPublisher()
                self.viewStore.dispatch(.viewWillScrollToLastItem)
            }
        }.store(in: &cancellable)

        var states: [InfiniteScrollViewState] = []
        viewStore.statePublisher.sink { state in
            states.append(state)

            let finalState = InfiniteScrollViewState(
                contentState: .content(
                    data: (0...15).map { index in
                        InfiniteScrollViewModel(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: true
                )
            )
            if state == finalState {
                finalExpectation.fulfill()
            }
        }.store(in: &cancellable)

        // Act
        viewStore.dispatch(.viewDidLoad)

        // Assert
        wait(for: [finalExpectation], timeout: 1)

        let referenseStates: [InfiniteScrollViewState] = [
            InfiniteScrollViewState(
                contentState: .content(
                    data: [],
                    isListEnded: false
                )
            ),
            InfiniteScrollViewState(
                contentState: .loading(
                    previousData: [],
                    state: .refresh
                )
            ),
            InfiniteScrollViewState(
                contentState: .content(
                    data: (0...14).map { index in
                        InfiniteScrollViewModel(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: false
                )
            ),
            InfiniteScrollViewState(
                contentState: .loading(
                    previousData: (0...14).map { index in
                        InfiniteScrollViewModel(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    state: .nextPage
                )
            ),
            InfiniteScrollViewState(
                contentState: .content(
                    data: (0...15).map { index in
                        InfiniteScrollViewModel(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: true
                )
            ),
        ]
        XCTAssertEqual(states, referenseStates)
    }

    func testRefresh() throws {
        // Arrange
        let finalExpectation = expectation(description: "final")

        infiniteScrollRepository.getInfiniteScrollsWithPageLentgthReturnValue = Future<[InfiniteScrollModel], Error>({ promise in
            let data = (0...14).map { index in
                InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
            }
            promise(.success(data))
        }).eraseToAnyPublisher()

        eventPublusher.sink { event in
            if event == .updateInitialData(
                data: (0...14).map { index in
                    InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
                },
                isListEnded: false
            ) {
                self.infiniteScrollRepository.getInfiniteScrollsWithPageLentgthReturnValue = Future<[InfiniteScrollModel], Error>({ promise in
                    let data = (15...20).map { index in
                        InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
                    }
                    promise(.success(data))
                }).eraseToAnyPublisher()
                self.viewStore.dispatch(.viewDidPullToRefresh)
            }
        }.store(in: &cancellable)

        var states: [InfiniteScrollViewState] = []
        viewStore.statePublisher.sink { state in
            states.append(state)

            let finalState = InfiniteScrollViewState(
                contentState: .content(
                    data: (15...20).map { index in
                        InfiniteScrollViewModel(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: true
                )
            )
            if state == finalState {
                finalExpectation.fulfill()
            }
        }.store(in: &cancellable)

        // Act
        viewStore.dispatch(.viewDidLoad)

        // Assert
        wait(for: [finalExpectation], timeout: 1)

        let referenseStates: [InfiniteScrollViewState] = [
            InfiniteScrollViewState(
                contentState: .content(
                    data: [],
                    isListEnded: false
                )
            ),
            InfiniteScrollViewState(
                contentState: .loading(
                    previousData: [],
                    state: .refresh
                )
            ),
            InfiniteScrollViewState(
                contentState: .content(
                    data: (0...14).map { index in
                        InfiniteScrollViewModel(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: false
                )
            ),
            InfiniteScrollViewState(
                contentState: .loading(
                    previousData: (0...14).map { index in
                        InfiniteScrollViewModel(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    state: .refresh
                )
            ),
            InfiniteScrollViewState(
                contentState: .content(
                    data: (15...20).map { index in
                        InfiniteScrollViewModel(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: true
                )
            ),
        ]
        XCTAssertEqual(states, referenseStates)
    }
}
