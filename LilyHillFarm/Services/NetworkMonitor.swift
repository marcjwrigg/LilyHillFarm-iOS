//
//  NetworkMonitor.swift
//  LilyHillFarm
//
//  Network connectivity monitoring service
//

import Foundation
import Network
import Combine

/// Monitors network connectivity and publishes changes
@MainActor
class NetworkMonitor: ObservableObject {
    // MARK: - Singleton

    static let shared = NetworkMonitor()

    // MARK: - Published Properties

    /// Current network connectivity status
    @Published private(set) var isConnected: Bool = false

    /// Network path details
    @Published private(set) var connectionType: ConnectionType = .unknown

    /// Is expensive (cellular) connection
    @Published private(set) var isExpensive: Bool = false

    // MARK: - Private Properties

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.lilyhillfarm.networkmonitor")

    // MARK: - Connection Types

    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unknown
    }

    // MARK: - Initialization

    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Monitoring

    /// Start monitoring network changes
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            _Concurrency.Task { @MainActor in
                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                self.isExpensive = path.isExpensive
                self.connectionType = self.determineConnectionType(from: path)

                // Log connection changes
                if !wasConnected && self.isConnected {
                    print("📶 Network: Connected (\(self.connectionType))")
                } else if wasConnected && !self.isConnected {
                    print("📵 Network: Disconnected")
                }
            }
        }

        monitor.start(queue: queue)
        print("📡 NetworkMonitor: Started monitoring")
    }

    /// Determine connection type from network path
    private func determineConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wired
        } else {
            return .unknown
        }
    }

    // MARK: - Public Methods

    /// Check if current connection is suitable for sync
    var isSuitableForSync: Bool {
        // Always sync on WiFi or wired
        // Only sync on cellular if user hasn't restricted it (future: add setting)
        return isConnected && (connectionType == .wifi || connectionType == .wired || connectionType == .cellular)
    }

    /// Wait for connection to become available
    func waitForConnection(timeout: TimeInterval = 30) async -> Bool {
        if isConnected {
            return true
        }

        let startTime = Date()

        while !isConnected && Date().timeIntervalSince(startTime) < timeout {
            try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        return isConnected
    }
}
