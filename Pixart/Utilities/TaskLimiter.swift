//
//  TaskLimiter.swift
//  Pixart
//

import Foundation

/// Concurrency throttle to limit simultaneous heavy background operations (e.g., Vision analysis).
actor TaskLimiter {
    private let maxConcurrent: Int
    private var runningCount: Int = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(maxConcurrent: Int = 4) {
        self.maxConcurrent = maxConcurrent
    }
    
    func execute<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        await acquire()
        defer {
            release()
        }
        return try await operation()
    }
    
    func executeNonThrowing<T: Sendable>(_ operation: @Sendable () async -> T) async -> T {
        await acquire()
        defer {
            release()
        }
        return await operation()
    }
    
    private func acquire() async {
        if runningCount < maxConcurrent {
            runningCount += 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    private func release() {
        if !waiters.isEmpty {
            let next = waiters.removeFirst()
            next.resume()
        } else {
            runningCount = max(0, runningCount - 1)
        }
    }
}
