# Swiftea

if you were looking for something like: 
- TEA(The Elm Architecture)
- MVU (Model-View-Update)
- MVI (Model-View-Intent)
- Redux-like
- Flux-like
- UDF (Unidirectional Data Flow)
- e.t.c

but on Swift... Then you have found it!

Swiftea is implementation of TEA/MVU architecture pattern using Swift.

## Features

- Cancellable side effects (cancel outdated network requests)
- Do not use 3rd party libraries
- use Combine
- 100% business logic code coverage

## Known issues

- Logical race (race condition) cause of Combine + multithread
- Events, Commands, State mutates on main queue but should be mutated on serial backgroud queue

#### We're open to merge requests

## Examples

- [Infinite Scroll](https://github.com/cooler333/Swiftea/tree/main/Examples/InfiniteScroll)

#### Other
- [Cocoapods integration](https://github.com/cooler333/Swiftea/tree/main/Examples/PodExample)
- [Swift Package Manager integration](https://github.com/cooler333/Swiftea/tree/main/Examples/SPMExample)

## Requirements

- iOS: 13.0
- Swift: 5.5

## Installation (Cocoapods / SPM)

Swiftea is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'Swiftea'
```

Also you can integrate framework as SPM package

## Alternatives
- [Mobius.swift](https://github.com/spotify/Mobius.swift)
- [ReSwift](https://github.com/ReSwift/ReSwift)
- [ReCombine](https://github.com/ReCombine/ReCombine)
- [Swift Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)
- [Tea In Swift](https://github.com/chriseidhof/tea-in-swift)
- [More](https://github.com/onmyway133/awesome-ios-architecture#unidirectional-data-flow)

## Author

Dmitrii Coolerov, coolerov333@gmail.com

## License

Swiftea is available under the MIT license. See the LICENSE file for more info.
