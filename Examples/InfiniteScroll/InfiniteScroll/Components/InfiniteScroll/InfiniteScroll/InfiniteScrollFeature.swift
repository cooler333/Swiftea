//
//  InfiniteScrollFeature.swift
//  InfiniteScroll
//
//  Created by Dmitrii Coolerov on 16.04.2022.
//

import Combine
import Foundation
import Swiftea

struct InfiniteScrollState: Equatable {
    enum LoadingState: Equatable {
        case error(InfiniteScrollAPIError)
        case refresh
        case nextPage
        case idle
    }

    var currentPage = 0

    var isListEnded = false
    var loadingState: LoadingState = .idle

    var data: [InfiniteScrollModel] = []
}

enum InfiniteScrollEvent: Equatable {
    case loadInitialData
    case updateInitialData(data: [InfiniteScrollModel], isListEnded: Bool)
    case updateNextData(data: [InfiniteScrollModel], isListEnded: Bool)
    case updateDataWithError(error: InfiniteScrollAPIError)

    case forceRefreshData
    case retryToLoadNextPage
    case receiveCancelAllRequests

    case selectInfiniteScrollAtIndex(index: Int)
    case loadNextPage
    case playbackScreenDidOpen
}

enum InfiniteScrollCommand: Equatable, Hashable {
    case loadInitialPageData
    case loadNextPageData(page: Int)
    case cancelAllRequests

    case openDetails(id: String)
}

struct InfiniteScrollAPIError: Error, Equatable {}

struct InfiniteScrollEnvironment {
    let pageLentgth = 15
    let mainQueue: DispatchQueue = .main
    let backgroundQueue: DispatchQueue = .global(qos: .background)
    let infiniteScrollRepository: InfiniteScrollRepositoryProtocol
    weak var moduleOutput: InfiniteScrollModuleOutput?
}

struct InfiniteScrollFeature {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func getReducer() -> Reducer<InfiniteScrollState, InfiniteScrollEvent, InfiniteScrollCommand> {
        let reducer = Reducer<InfiniteScrollState, InfiniteScrollEvent, InfiniteScrollCommand>(reduce: { state, event in
            switch event {
            case .loadInitialData:
                var state = state
                state.loadingState = .refresh

                return .nextAndDispatchCancellable(
                    state,
                    commands: [
                        .cancelAllRequests,
                        .loadInitialPageData,
                    ],
                    cancellableCommands: [
                        .cancelAllRequests,
                    ]
                )

            case let .updateInitialData(data, isListEnded):
                var state = state
                state.loadingState = .idle
                state.isListEnded = isListEnded
                state.currentPage = 0
                state.data = data

                return .next(state)

            case let .updateNextData(data, isListEnded):
                var state = state
                state.loadingState = .idle
                state.isListEnded = isListEnded
                state.currentPage += 1
                state.data += data

                return .next(state)

            case let .updateDataWithError(error):
                var state = state
                state.loadingState = .error(error)

                return .next(state)

            case .retryToLoadNextPage:
                var state = state
                state.loadingState = .nextPage

                return .nextAndDispatchCancellable(
                    state,
                    commands: [
                        .cancelAllRequests,
                        .loadNextPageData(page: state.currentPage + 1),
                    ],
                    cancellableCommands: [
                        .cancelAllRequests,
                    ]
                )

            case .forceRefreshData:
                var state = state
                state.loadingState = .refresh

                return .nextAndDispatchCancellable(
                    state, commands: [
                        .cancelAllRequests,
                        .loadInitialPageData,
                    ],
                    cancellableCommands: [
                        .cancelAllRequests,
                    ]
                )

            case .loadNextPage:
                if state.isListEnded {
                    return .empty
                }
                if state.loadingState == .refresh {
                    return .empty
                }

                var state = state
                state.loadingState = .nextPage

                return .nextAndDispatchCancellable(
                    state, commands: [
                        .cancelAllRequests,
                        .loadNextPageData(page: state.currentPage + 1),
                    ],
                    cancellableCommands: [
                        .cancelAllRequests,
                    ]
                )

            case .receiveCancelAllRequests:
                return .empty

            case let .selectInfiniteScrollAtIndex(index):
                let item = state.data[index]
                return .dispatch([
                    .openDetails(id: item.id),
                ])

            case .playbackScreenDidOpen:
                return .empty
            }
        })
        return reducer
    }

    // swiftlint:disable:next function_body_length
    func getCommandHandler(
        environment: InfiniteScrollEnvironment
    ) -> CommandHandler<InfiniteScrollCommand, InfiniteScrollEvent, InfiniteScrollEnvironment> {
        let commandHanlder = CommandHandler<InfiniteScrollCommand, InfiniteScrollEvent, InfiniteScrollEnvironment>(
            reduce: { command, environment in
                switch command {
                case .loadInitialPageData:
                    return environment.infiniteScrollRepository.getInfiniteScrolls(
                        with: 0,
                        pageLentgth: environment.pageLentgth
                    )
                    .subscribe(on: environment.backgroundQueue)
                    .map { result -> InfiniteScrollEvent in
                        .updateInitialData(data: result, isListEnded: result.count < environment.pageLentgth)
                    }
                    .mapError { _ in
                        InfiniteScrollAPIError()
                    }
                    .catch { error in
                        Just<InfiniteScrollEvent>(.updateDataWithError(error: error))
                    }
                    .eraseToAnyPublisher()

                case let .loadNextPageData(page):
                    return environment.infiniteScrollRepository.getInfiniteScrolls(
                        with: page,
                        pageLentgth: environment.pageLentgth
                    )
                    .subscribe(on: environment.backgroundQueue)
                    .map { result -> InfiniteScrollEvent in
                        .updateNextData(data: result, isListEnded: result.count < environment.pageLentgth)
                    }
                    .mapError { _ in
                        InfiniteScrollAPIError()
                    }
                    .catch { error in
                        Just<InfiniteScrollEvent>(.updateDataWithError(error: error))
                    }
                    .eraseToAnyPublisher()

                case .cancelAllRequests:
                    return Just<InfiniteScrollEvent>(.receiveCancelAllRequests)
                        .eraseToAnyPublisher()

                case let .openDetails(id):
                    return Future<InfiniteScrollEvent, Never> { promise in
                        DispatchQueue.main.async {
                            environment.moduleOutput?.infiniteScrollModuleWantsToOpenDetails(
                                with: id
                            )
                            promise(.success(.playbackScreenDidOpen))
                        }
                    }
                    .subscribe(on: environment.mainQueue)
                    .receive(on: environment.mainQueue)
                    .eraseToAnyPublisher()
                }
            },
            environment: environment
        )

        return commandHanlder
    }

    func getStateMapper() -> (InfiniteScrollState) -> InfiniteScrollViewState {
        let eventMapper: (InfiniteScrollState) -> InfiniteScrollViewState = { state in
            let contentState: LCEPagedState<[InfiniteScrollViewModel], InfiniteScrollViewError> = {
                let data: [InfiniteScrollViewModel] = state.data.map { model in
                    InfiniteScrollViewModel(
                        title: model.title,
                        subtitle: model.subtitle,
                        id: model.id,
                        details: model.details
                    )
                }
                switch state.loadingState {
                case .refresh:
                    return .loading(previousData: data, state: .refresh)

                case .nextPage:
                    return .loading(previousData: data, state: .nextPage)

                case .error:
                    return .error(previousData: data, isListEnded: state.isListEnded, error: .api)

                case .idle:
                    return .content(data: data, isListEnded: state.isListEnded)
                }
            }()
            return InfiniteScrollViewState(
                contentState: contentState
            )
        }
        return eventMapper
    }

    func getEventMapper() -> (InfiniteScrollViewEvent) -> InfiniteScrollEvent {
        let eventMapper: (InfiniteScrollViewEvent) -> InfiniteScrollEvent = { viewEvent in
            switch viewEvent {
            case .viewDidLoad:
                return .loadInitialData

            case .viewDidTapRetryNextPageLoading:
                return .loadNextPage

            case let .viewDidTapInfiniteScrollAtIndex(index):
                return .selectInfiniteScrollAtIndex(index: index)

            case .viewDidPullToRefresh:
                return .forceRefreshData

            case .viewDidTapReloadDataButton:
                return .forceRefreshData

            case .viewWillScrollToLastItem:
                return .loadNextPage
            }
        }
        return eventMapper
    }
}
