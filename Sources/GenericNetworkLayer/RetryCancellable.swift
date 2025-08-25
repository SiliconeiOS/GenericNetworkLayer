//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

public final class RetryCancellable: Cancellable, @unchecked Sendable {
    
    private let queue = DispatchQueue(label: "com.net.GenericNetworkLayer.RetryCancellable.syncQueue")
    
    private var isCancelled: Bool = false
    private var currentTask: Cancellable?
    
    var isOperationCancelled: Bool {
        queue.sync {
            return isCancelled
        }
    }
    
    public func cancel() {
        queue.sync {
            currentTask?.cancel()
            isCancelled = true
        }
    }
    
    func update(task: Cancellable?) {
        queue.sync {
            guard !isCancelled else {
                task?.cancel()
                return
            }
            currentTask = task
        }
    }
}
