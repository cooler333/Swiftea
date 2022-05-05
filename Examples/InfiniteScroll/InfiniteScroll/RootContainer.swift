//
//  RootContainer.swift
//  InfiniteScroll
//
//  Created by Dmitrii Coolerov on 05.05.2022.
//

import Swinject
import Foundation

final class RootContainer {
    private let assembler: Assembler

    var resolver: Resolver {
        assembler.resolver
    }

    init() {
        assembler = Assembler([
            RootAssembly(),
        ])
    }
}

public final class RootAssembly: Assembly {
    public init() {}

    public func assemble(container: Container) {
        assembleStateless(container: container)
        assembleStatefull(container: container)
    }

    private func assembleStateless(container: Container) {
        container.register(InfiniteScrollModelParserProtocol.self) { _ in
            InfiniteScrollModelParser()
        }

        container.register(InfiniteScrollRepositoryProtocol.self) { resolver in
            InfiniteScrollRepositoryMock()

            // if you want to use real api
            // uncomment next line and change url domain

            // InfiniteScrollRepository(
            //     networkService: resolver.resolve(NetworkServiceProtocol.self)!,
            //     infiniteScrollModelParser: resolver.resolve(InfiniteScrollModelParserProtocol.self)!
            // )
        }
    }

    private func assembleStatefull(container: Container) {
        container.register(NetworkServiceProtocol.self) { resolver in
            NetworkService()
        }
        .inObjectScope(.weak)

        container.register(ToastNotificationManagerProtocol.self) { _ in
            ToastNotificationManager()
        }
        .inObjectScope(.container)
    }
}
