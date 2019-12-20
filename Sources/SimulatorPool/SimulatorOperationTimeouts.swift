import Foundation

public final class SimulatorOperationTimeouts {
    public let create: TimeInterval
    public let preBootConfigure: TimeInterval
    public let boot: TimeInterval
    public let delete: TimeInterval
    public let shutdown: TimeInterval

    public init(
        create: TimeInterval,
        preBootConfigure: TimeInterval,
        boot: TimeInterval,
        delete: TimeInterval,
        shutdown: TimeInterval
    ) {
        self.create = create
        self.preBootConfigure = preBootConfigure
        self.boot = boot
        self.delete = delete
        self.shutdown = shutdown
    }
}
