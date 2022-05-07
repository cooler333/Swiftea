//
//  InfiniteScrollViewController.swift
//  InfiniteScroll
//
//  Created by Dmitrii Coolerov on 17.03.2022.
//

import Combine
import Foundation
import Swiftea
import UIKit

enum InfiniteScrollViewEvent: Equatable {
    case viewDidLoad
    case viewDidPullToRefresh
    case viewDidTapReloadDataButton
    case viewDidTapRetryNextPageLoading
    case viewDidTapInfiniteScrollAtIndex(index: Int)
    case viewWillScrollToLastItem
}

enum InfiniteScrollViewError: Error, Equatable {
    case api
}

struct InfiniteScrollViewState: Equatable {
    let contentState: LCEPagedState<[InfiniteScrollViewModel], InfiniteScrollViewError>

    static var initial: InfiniteScrollViewState {
        InfiniteScrollViewState(
            contentState: .content(data: [], isListEnded: false)
        )
    }
}

struct InfiniteScrollViewModel: Equatable {
    let title: String
    let subtitle: String
    let id: String
    let details: String
}

// swiftlint:disable:next type_body_length
final class InfiniteScrollViewController: UIViewController {
    struct InfiniteScrollDisplayData: Hashable {
        public let title: String
        public let subtitle: String
        public let id: String
        public let details: String
    }

    // MARK: Private data structures

    private struct TitleItem: Hashable {
        let title: String
    }

    private struct EmptyItem: Hashable {
        let title: String
    }

    private struct LoadingErrorEmptyItem: Hashable {
        let title: String
    }

    private struct LoadingItem: Hashable {
        private let id = UUID()

        static func == (lhs: Self, rhs: Self) -> Bool {
            return false
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    private struct LoadingErrorContentItem: Hashable {
        private let id = UUID()
        let title: String

        static func == (lhs: Self, rhs: Self) -> Bool {
            return false
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    // MARK: Private properties

    private let viewStore: ViewStore<InfiniteScrollViewState, InfiniteScrollViewEvent>

    private var toastNotificationManager: ToastNotificationManagerProtocol

    private weak var tableView: UITableView!
    private var dataSource: UITableViewDiffableDataSource<Int, AnyHashable>!

    private var store = Set<AnyCancellable>()

    private let uiSubject = PassthroughSubject<Void, Never>()

    init(
        viewStore: ViewStore<InfiniteScrollViewState, InfiniteScrollViewEvent>,
        toastNotificationManager: ToastNotificationManagerProtocol
    ) {
        self.viewStore = viewStore
        self.toastNotificationManager = toastNotificationManager
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let tableView = UITableView(frame: .zero)
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
        ])
        self.tableView = tableView

        tableView.register(
            UITableViewCell.self,
            forCellReuseIdentifier: String(describing: type(of: UITableViewCell.self))
        )

        tableView.delegate = self
        dataSource = UITableViewDiffableDataSource<Int, AnyHashable>(
            tableView: tableView
        ) { tableView, indexPath, itemIdentifier in
            self.cell(with: tableView, indexPath: indexPath, itemIdentifier: itemIdentifier)
        }
        dataSource.defaultRowAnimation = .fade

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        viewStore.statePublisher.throttle(
            for: 0.25,
            scheduler: DispatchQueue.main,
            latest: true
        )
        .sink { [weak self] viewState in
            guard let self = self else { return }
            self.update(state: viewState)
        }
        .store(in: &store)

        viewStore.dispatch(.viewDidLoad)
    }

    @objc private func refresh() {
        viewStore.dispatch(.viewDidPullToRefresh)
        tableView.refreshControl?.endRefreshing()
    }

    // swiftlint:disable:next function_body_length
    private func cell(
        with tableView: UITableView,
        indexPath: IndexPath,
        itemIdentifier: AnyHashable
    ) -> UITableViewCell {
        switch itemIdentifier {
        case let itemIdentifier as TitleItem:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: String(describing: type(of: UITableViewCell.self)),
                for: indexPath
            )
            cell.selectionStyle = .none
            cell.textLabel?.text = itemIdentifier.title
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.textAlignment = .left
            return cell

        case is LoadingItem:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: String(describing: type(of: UITableViewCell.self)),
                for: indexPath
            )
            cell.selectionStyle = .none
            cell.textLabel?.text = "Loading... ⌛⌛⌛"
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.textAlignment = .center
            return cell

        case let item as LoadingErrorContentItem:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: String(describing: type(of: UITableViewCell.self)),
                for: indexPath
            )
            cell.selectionStyle = .none
            cell.textLabel?.text = item.title
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.textAlignment = .center
            return cell

        case let item as LoadingErrorEmptyItem:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: String(describing: type(of: UITableViewCell.self)),
                for: indexPath
            )
            cell.selectionStyle = .none
            cell.textLabel?.text = item.title
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.textAlignment = .center
            return cell

        case let item as EmptyItem:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: String(describing: type(of: UITableViewCell.self)),
                for: indexPath
            )
            cell.selectionStyle = .none
            cell.textLabel?.text = item.title
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.textAlignment = .center
            return cell

        default:
            fatalError("Unexpected state")
        }
    }

    private func toDisplayData(from viewModels: [InfiniteScrollViewModel]) -> [InfiniteScrollDisplayData] {
        let displayData = viewModels.map { model in
            InfiniteScrollDisplayData(
                title: model.title,
                subtitle: model.subtitle,
                id: model.id,
                details: model.details
            )
        }
        return displayData
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func update(state: InfiniteScrollViewState) {
        switch state.contentState {
        case let .content(data, isListEnded):
            if let refreshControl = tableView.refreshControl {
                if refreshControl.isRefreshing {
                    refreshControl.endRefreshing()
                }
            }

            if data.isEmpty {
                updateEmpty()
            } else {
                updateContent(
                    with: toDisplayData(from: data),
                    isListEnded: isListEnded
                )
            }

        case let .loading(previousData, state):
            if let refreshControl = tableView.refreshControl, state == .refresh, !previousData.isEmpty {
                if !refreshControl.isRefreshing {
                    refreshControl.beginRefreshing()
                }
            }

            if previousData.isEmpty {
                updateEmptyLoading()
            } else {
                updateLoading(
                    with: toDisplayData(from: previousData),
                    loadingState: state
                )
            }

        case let .error(previousData, isListEnded, error):
            if let refreshControl = tableView.refreshControl {
                if refreshControl.isRefreshing {
                    refreshControl.endRefreshing()
                }
            }

            if previousData.isEmpty {
                updateEmptyError(error: error)
            } else {
                toastNotificationManager.showNotification(
                    with: .danger(title: "Error", message: error.localizedDescription)
                )

                updateContent(
                    with: toDisplayData(from: previousData),
                    isListEnded: isListEnded
                )
            }
        }
    }

    private func updateEmptyLoading() {
        let displayData: [AnyHashable] = [
            LoadingItem(),
        ]
        var snapshot = NSDiffableDataSourceSnapshot<Int, AnyHashable>()
        snapshot.appendSections([0])
        snapshot.appendItems(displayData)
        dataSource.apply(snapshot)
    }

    private func updateEmptyError(error: Error) {
        let displayData: [AnyHashable] = [
            LoadingErrorEmptyItem(
                title: "Error happens. Tap to reload list\n\nDetails:\n\(error.localizedDescription)"
            ),
        ]
        var snapshot = NSDiffableDataSourceSnapshot<Int, AnyHashable>()
        snapshot.appendSections([0])
        snapshot.appendItems(displayData)
        dataSource.apply(snapshot)
    }

    private func updateEmpty() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, AnyHashable>()
        snapshot.appendSections([0])
        snapshot.appendItems([EmptyItem(title: "List is empty")])
        dataSource.apply(snapshot, animatingDifferences: false) {
            // unused
        }
    }

    private func updateLoading(with displayData: [InfiniteScrollDisplayData], loadingState: LCEPagedLoadingState) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, AnyHashable>()
        snapshot.appendSections([0])

        let display = displayData.map { displayData -> TitleItem in
            let title = "\(displayData.title)\n\(displayData.id)"
            return TitleItem(title: title)
        }
        snapshot.appendItems(display)

        if loadingState == .nextPage {
            snapshot.appendItems([LoadingItem()])
        }

        dataSource.apply(snapshot, animatingDifferences: false) {
            // unused
        }
    }

    private func updateContent(with displayData: [InfiniteScrollDisplayData], isListEnded: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, AnyHashable>()
        snapshot.appendSections([0])

        let display = displayData.map { displayData -> TitleItem in
            let title = "\(displayData.title)\n\(displayData.id)"
            return TitleItem(title: title)
        }
        snapshot.appendItems(display)

        if !isListEnded {
            snapshot.appendItems([LoadingErrorContentItem(title: "Tap to load more")])
        }

        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

extension InfiniteScrollViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let numberOfSections = dataSource.numberOfSections(in: tableView)
        if numberOfSections > 0, numberOfSections - 1 == indexPath.section {
            let numberOfRows = dataSource.tableView(tableView, numberOfRowsInSection: indexPath.section)
            if numberOfRows > 0, numberOfRows - 1 == indexPath.row + 2 {
                viewStore.dispatch(.viewWillScrollToLastItem)
            }
        }
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let itemIdentifier = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        switch itemIdentifier {
        case is LoadingItem:
            break

        case is EmptyItem:
            break

        case is LoadingErrorContentItem:
            viewStore.dispatch(.viewDidTapRetryNextPageLoading)

        case is LoadingErrorEmptyItem:
            viewStore.dispatch(.viewDidTapReloadDataButton)

        case is TitleItem:
            viewStore.dispatch(.viewDidTapInfiniteScrollAtIndex(index: indexPath.row))

        default:
            fatalError("Unexpected state")
        }
    }
    // swiftlint:disable:next file_length
}
