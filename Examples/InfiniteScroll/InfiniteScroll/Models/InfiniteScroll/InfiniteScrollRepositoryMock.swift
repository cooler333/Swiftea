//
//  InfiniteScrollRepository.swift
//  InfiniteScroll
//
//  Created by Dmitrii Coolerov on 18.04.2022.
//

import Combine
import Foundation

final class InfiniteScrollRepositoryMock {}

extension InfiniteScrollRepositoryMock: InfiniteScrollRepositoryProtocol {
    func getInfiniteScrolls(with currentPage: Int, pageLentgth: Int) -> AnyPublisher<[InfiniteScrollModel], Error> {
        if currentPage == 0 {
            let refreshRandom = Int.random(in: 0...3)
            let refreshError = refreshRandom == 0

            return Future<[InfiniteScrollModel], Error> { promise in
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 3) {
                    if refreshError {
                        promise(.failure(URLError(.notConnectedToInternet)))
                    } else {
                        promise(.success(self.generateModels(count: pageLentgth)))
                    }
                }
            }.eraseToAnyPublisher()
        } else {
            let nextPageRandom = Int.random(in: 0...2)
            let nextPageError = nextPageRandom == 0

            return Future<[InfiniteScrollModel], Error> { promise in
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 3) {
                    if nextPageError {
                        promise(.failure(URLError(.notConnectedToInternet)))
                    } else {
                        promise(.success(self.generateModels(count: pageLentgth)))
                    }
                }
            }.eraseToAnyPublisher()
        }
    }

    private func generateModels(count: Int) -> [InfiniteScrollModel] {
        var data: [InfiniteScrollModel] = []
        (0...count).forEach { _ in
            data.append(generateModel())
        }
        return data
    }

    private func generateModel() -> InfiniteScrollModel {
        InfiniteScrollModel(
            title: "Title " + UUID().uuidString.lowercased(),
            subtitle: "Subtitle " + UUID().uuidString.lowercased(),
            id: UUID().uuidString,
            details: "Lorem ipsum" + UUID().uuidString.lowercased()
        )
    }
}
