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
    let pageLentgth = 15

    var isListEnded = false
    var loadingState: LoadingState = .idle

    var data: [InfiniteScrollModel] = []
}

enum InfiniteScrollEvent: Equatable {
    case loadInitialData
    case updateInitialData(data: [InfiniteScrollModel])
    case updateNextData(data: [InfiniteScrollModel])
    case updateDataWithError(error: InfiniteScrollAPIError)

    case forceRefreshData
    case retryToLoadNextPage

    case selectInfiniteScrollAtIndex(index: Int)
    case loadNextPage
    case playbackScreenDidOpen
}

enum InfiniteScrollCommand: Equatable {
    case loadInitialPageData
    case loadNextPageData
    case playbackStream(streamURL: String, broadcastID: String)
}

struct InfiniteScrollAPIError: Error, Equatable {}

struct InfiniteScrollEnvironment {
    let mainQueue: DispatchQueue = .main
    let backgroundQueue: DispatchQueue = .global(qos: .background)
    let infiniteScrollRepository: InfiniteScrollRepositoryProtocol
    weak var moduleOutput: InfiniteScrollModuleOutput?
}

enum InfiniteScrollFeature {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func getReducer() -> Reducer<InfiniteScrollState, InfiniteScrollEvent, InfiniteScrollCommand> {
        let reducer = Reducer<InfiniteScrollState, InfiniteScrollEvent, InfiniteScrollCommand>(reduce: { state, event in
            switch event {
            case .loadInitialData:
                var state = state
                state.loadingState = .refresh

                return .nextAndDispatch(state, [.loadInitialPageData])

            case let .updateInitialData(data):
                var state = state
                state.loadingState = .idle
                state.isListEnded = data.count < state.pageLentgth
                state.currentPage = 0
                state.data = data

                return .next(state)

            case let .updateNextData(data):
                var state = state
                state.loadingState = .idle
                state.isListEnded = data.count < state.pageLentgth
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

                return .nextAndDispatch(state, [.loadNextPageData])

            case .forceRefreshData:
                if state.loadingState == .refresh {
                    return .empty
                }

                var state = state
                state.loadingState = .refresh

                return .nextAndDispatch(state, [.loadInitialPageData])

            case .loadNextPage:
                if state.isListEnded {
                    return .empty
                }
                if state.loadingState == .nextPage {
                    return .empty
                }

                var state = state
                state.loadingState = .nextPage

                return .nextAndDispatch(state, [.loadNextPageData])

            case let .selectInfiniteScrollAtIndex(index):
                let item = state.data[index]
                return .dispatch([
                    .playbackStream(
                        streamURL: item.title,
                        broadcastID: item.subtitle
                    ),
                ])

            case .playbackScreenDidOpen:
                return .empty
            }
        })
        return reducer
    }

    static func getCommandHandler(
        environment: InfiniteScrollEnvironment
    ) -> CommandHandler<InfiniteScrollState, InfiniteScrollCommand, InfiniteScrollEvent, InfiniteScrollEnvironment> {
        let commandHanlder = CommandHandler<InfiniteScrollState, InfiniteScrollCommand, InfiniteScrollEvent, InfiniteScrollEnvironment>(
            reduce: { state, command, environment in
                switch command {
                case .loadInitialPageData:
                    return environment.infiniteScrollRepository.getInfiniteScrolls(
                        with: 0,
                        pageLentgth: state.pageLentgth
                    )
                    .subscribe(on: environment.backgroundQueue)
                    .map { result -> InfiniteScrollEvent in
                        .updateInitialData(data: result)
                    }
                    .mapError { _ in
                        InfiniteScrollAPIError()
                    }
                    .catch { error in
                        Just<InfiniteScrollEvent>(.updateDataWithError(error: error))
                    }
                    .eraseToAnyPublisher()

                case .loadNextPageData:
                    return environment.infiniteScrollRepository.getInfiniteScrolls(
                        with: state.currentPage + 1,
                        pageLentgth: state.pageLentgth
                    )
                    .subscribe(on: environment.backgroundQueue)
                    .map { result -> InfiniteScrollEvent in
                        .updateNextData(data: result)
                    }
                    .mapError { _ in
                        InfiniteScrollAPIError()
                    }
                    .catch { error in
                        Just<InfiniteScrollEvent>(.updateDataWithError(error: error))
                    }
                    .eraseToAnyPublisher()

                case let .playbackStream(streamURL, broadcastID):
                    return Future<InfiniteScrollEvent, Never> { promise in
                        DispatchQueue.main.async {
                            environment.moduleOutput?.infiniteScrollModuleWantsToPlaybackStream(
                                with: streamURL,
                                broadcastID: broadcastID
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

    static func getStateMapper() -> (InfiniteScrollState) -> InfiniteScrollViewState {
        let eventMapper: (InfiniteScrollState) -> InfiniteScrollViewState = { state in
            let contentState: LCEPagedState<[InfiniteScrollViewModel], InfiniteScrollViewError> = {
                let data: [InfiniteScrollViewModel] = state.data.map { model in
                    return InfiniteScrollViewModel(
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

    static func getEventMapper() -> (InfiniteScrollViewEvent) -> InfiniteScrollEvent {
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
