//
//  App.swift
//  ForgeSwiftDemo
//

import UIKit
import ForgeSwift

@main
class ForgeDemo: App {
    override var body: any View {
        Counter()
    }
}

// MARK: - Counter
//
// The first composite view in ForgeSwift. Proves: CompositeView protocol,
// Model/Builder separation, Observable → markDirty → rebuild, and that
// the wrapper-based identity-stable layout survives repeated rebuilds.
//
// An auto-incrementing timer drives the observable; the Builder reads
// it through the data protocol via `node.watch(...)` so the node
// subscribes + reads in one explicit call.

@MainActor
protocol CounterData: AnyObject {
    var count: Observable<Int> { get }
}

@MainActor
final class CounterModel: ViewModel, CounterData {
    let count = Observable(0)
    private var task: Task<Void, Never>?

    init() {
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self else { break }
                self.count.value += 1
            }
        }
    }

    deinit {
        task?.cancel()
    }
}

@MainActor
final class CounterBuilder: Builder {
    let data: CounterData
    weak var node: Node?

    init(data: CounterData) {
        self.data = data
    }

    func build() -> any View {
        guard let node else { return Text("—") }
        let value = node.watch(data.count)
        return Text("Seconds elapsed: \(value)")
    }
}

struct Counter: CompositeView {
    func makeModel(node: Node) -> CounterModel {
        CounterModel()
    }

    func makeBuilder(model: CounterModel) -> Builder {
        CounterBuilder(data: model)
    }
}
