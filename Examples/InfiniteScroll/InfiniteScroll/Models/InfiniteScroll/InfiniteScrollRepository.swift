//
//  InfiniteScrollRepository.swift
//  InfiniteScroll
//
//  Created by Dmitrii Coolerov on 18.04.2022.
//

import Combine
import Foundation

public protocol InfiniteScrollRepositoryProtocol: AnyObject {
    func getInfiniteScrolls(with currentPage: Int, pageLentgth: Int) -> AnyPublisher<[InfiniteScrollModel], Error>
}

final class InfiniteScrollRepository {
    private let networkService: NetworkServiceProtocol
    private let infiniteScrollModelParser: InfiniteScrollModelParserProtocol

    init(
        networkService: NetworkServiceProtocol,
        infiniteScrollModelParser: InfiniteScrollModelParserProtocol
    ) {
        self.networkService = networkService
        self.infiniteScrollModelParser = infiniteScrollModelParser
    }
}

extension InfiniteScrollRepository: InfiniteScrollRepositoryProtocol {
    func getInfiniteScrolls(with currentPage: Int, pageLentgth: Int) -> AnyPublisher<[InfiniteScrollModel], Error> {
        let baseURL = "https://api.foobar.com"
        let path = "foo/getBar"
        let url = URL(string: baseURL)!.appendingPathComponent(path)

        let parameters = NetworkRequestParameters(
            url: url,
            authorizationType: .accessToken,
            httpBody: [
                "start": String(currentPage * pageLentgth),
                "length": String(pageLentgth),
            ]
        )

        let infiniteScrollResponseData = networkService.get(
            parameters: parameters,
            withType: [InfiniteScrollResponseData].self
        )
        let infiniteScrollModelData = infiniteScrollResponseData
            .map(infiniteScrollModelParser.parse)
        return infiniteScrollModelData.eraseToAnyPublisher()
    }
}
