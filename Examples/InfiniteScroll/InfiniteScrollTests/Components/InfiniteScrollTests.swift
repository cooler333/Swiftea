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
    var cancellable = Set<AnyCancellable>()
    var viewController: UIViewController!

    override func setUpWithError() throws {
        // unused
    }

    override func tearDownWithError() throws {
        // unused
    }

    func testExample() throws {
        // Arrange
        let container = Container()
        let resolver: Resolver = container

        let infiniteScrollRepository = InfiniteScrollRepositoryProtocolMock()
        infiniteScrollRepository.getInfiniteScrollsWithPageLentgthReturnValue = Future<[InfiniteScrollModel], Error>({ promise in
            promise(.success(
                [
                    InfiniteScrollModel(title: "", subtitle: "", id: "", details: "")
                ]
            ))
        }).eraseToAnyPublisher()
        container.register(InfiniteScrollRepositoryProtocol.self) { _ in
            infiniteScrollRepository
        }

        let toastNotificationManager = ToastNotificationManagerProtocolMock()
        toastNotificationManager.showNotificationWithClosure = { _ in

        }
        container.register(ToastNotificationManagerProtocol.self) { _ in
            toastNotificationManager
        }

        let feature = InfiniteScrollFeature()
        let moduleOutput: InfiniteScrollModuleOutput? = nil

        let store = Store<InfiniteScrollState, InfiniteScrollEvent, InfiniteScrollCommand, InfiniteScrollEnvironment>(
            state: InfiniteScrollState(),
            reducer: feature.getReducer(),
            commandHandler: feature.getCommandHandler(
                environment: InfiniteScrollEnvironment(
                    infiniteScrollRepository: resolver.resolve(InfiniteScrollRepositoryProtocol.self)!,
                    moduleOutput: moduleOutput
                )
            )
        )

        let viewStore = ViewStore<InfiniteScrollViewState, InfiniteScrollViewEvent>(
            store: store,
            eventMapper: feature.getEventMapper(),
            stateMapper: feature.getStateMapper()
        )

        viewController = InfiniteScrollViewController(
            viewStore: viewStore,
            toastNotificationManager: resolver.resolve(ToastNotificationManagerProtocol.self)!
        )

        let stateExpectation = expectation(description: "state")
        var states: [InfiniteScrollViewState] = []
        viewStore.statePublisher.sink { state in
            states.append(state)
            if states.count == 3 {
                stateExpectation.fulfill()
            }
        }.store(in: &cancellable)

        // Act
        viewStore.dispatch(.viewDidLoad)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            viewStore.dispatch(.viewWillScrollToLastItem)
        }

        // Assert
        wait(for: [stateExpectation], timeout: 2)

        let referenseStates: [InfiniteScrollViewState] = [
            InfiniteScrollViewState(contentState: .content(data: [], isListEnded: false)),
            InfiniteScrollViewState(contentState: .loading(previousData: [], state: .refresh)),
            InfiniteScrollViewState(contentState: .content(data: [InfiniteScrollViewModel(title: "", subtitle: "", id: "", details: "")], isListEnded: true)),
        ]
        XCTAssertEqual(states, referenseStates)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }
}
