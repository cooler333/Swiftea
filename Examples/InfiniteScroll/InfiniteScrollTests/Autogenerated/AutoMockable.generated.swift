// Generated using Sourcery 1.8.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable line_length
// swiftlint:disable variable_name

import Foundation
import InfiniteScroll
import Combine
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif
















class InfiniteScrollRepositoryProtocolMock: InfiniteScrollRepositoryProtocol {

    // MARK: - getInfiniteScrolls

    var getInfiniteScrollsWithPageLentgthCallsCount = 0
    var getInfiniteScrollsWithPageLentgthCalled: Bool {
        return getInfiniteScrollsWithPageLentgthCallsCount > 0
    }
    var getInfiniteScrollsWithPageLentgthReceivedArguments: (currentPage: Int, pageLentgth: Int)?
    var getInfiniteScrollsWithPageLentgthReceivedInvocations: [(currentPage: Int, pageLentgth: Int)] = []
    var getInfiniteScrollsWithPageLentgthReturnValue: AnyPublisher<[InfiniteScrollModel], Error>!
    var getInfiniteScrollsWithPageLentgthClosure: ((Int, Int) -> AnyPublisher<[InfiniteScrollModel], Error>)?

    func getInfiniteScrolls(with currentPage: Int, pageLentgth: Int) -> AnyPublisher<[InfiniteScrollModel], Error> {
        getInfiniteScrollsWithPageLentgthCallsCount += 1
        getInfiniteScrollsWithPageLentgthReceivedArguments = (currentPage: currentPage, pageLentgth: pageLentgth)
        getInfiniteScrollsWithPageLentgthReceivedInvocations.append((currentPage: currentPage, pageLentgth: pageLentgth))
        if let getInfiniteScrollsWithPageLentgthClosure = getInfiniteScrollsWithPageLentgthClosure {
            return getInfiniteScrollsWithPageLentgthClosure(currentPage, pageLentgth)
        } else {
            return getInfiniteScrollsWithPageLentgthReturnValue
        }
    }
}
class ToastNotificationManagerProtocolMock: ToastNotificationManagerProtocol {

    // MARK: - showNotification

    var showNotificationWithCallsCount = 0
    var showNotificationWithCalled: Bool {
        return showNotificationWithCallsCount > 0
    }
    var showNotificationWithReceivedType: ToastNotificationType?
    var showNotificationWithReceivedInvocations: [ToastNotificationType] = []
    var showNotificationWithClosure: ((ToastNotificationType) -> Void)?

    func showNotification(with type: ToastNotificationType) {
        showNotificationWithCallsCount += 1
        showNotificationWithReceivedType = type
        showNotificationWithReceivedInvocations.append(type)
        showNotificationWithClosure?(type)
    }
}
