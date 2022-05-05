//
//  InfiniteScrollModuleBuilder.swift
//  InfiniteScroll
//
//  Created by Dmitrii Coolerov on 23.03.2022.
//

import Combine
import Foundation
import Swiftea
import Swinject
import UIKit

final class InfiniteScrollModuleBuilder {
    private let resolver: Resolver
    private weak var moduleOutput: InfiniteScrollModuleOutput!

    init(
        resolver: Resolver,
        moduleOutput: InfiniteScrollModuleOutput
    ) {
        self.resolver = resolver
        self.moduleOutput = moduleOutput
    }

    func build() -> UIViewController {
        let store = Store<InfiniteScrollState, InfiniteScrollEvent, InfiniteScrollCommand, InfiniteScrollEnvironment>(
            state: InfiniteScrollState(),
            reducer: InfiniteScrollFeature.getReducer(),
            commandHandler: InfiniteScrollFeature.getCommandHandler(
                environment: InfiniteScrollEnvironment(
                    infiniteScrollRepository: resolver.resolve(InfiniteScrollRepositoryProtocol.self)!,
                    moduleOutput: moduleOutput
                )
            )
        )

        let viewStore = ViewStore<InfiniteScrollViewState, InfiniteScrollViewEvent>(
            store: store,
            eventMapper: InfiniteScrollFeature.getEventMapper(),
            stateMapper: InfiniteScrollFeature.getStateMapper()
        )

        let viewController = InfiniteScrollViewController(
            viewStore: viewStore,
            toastNotificationManager: resolver.resolve(ToastNotificationManagerProtocol.self)!
        )
        return viewController
    }
}
