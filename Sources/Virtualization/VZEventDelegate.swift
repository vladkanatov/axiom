import Foundation
import Virtualization

public final class VZEventDelegate: NSObject, VZVirtualMachineDelegate {
    public typealias GuestDidStopHandler = @Sendable () -> Void
    public typealias DidStopWithErrorHandler = @Sendable (Error) -> Void
    public typealias NetworkAttachmentDisconnectedHandler = @Sendable (Error) -> Void

    private let guestDidStopHandler: GuestDidStopHandler
    private let didStopWithErrorHandler: DidStopWithErrorHandler
    private let networkAttachmentDisconnectedHandler: NetworkAttachmentDisconnectedHandler

    public init(
        guestDidStopHandler: @escaping GuestDidStopHandler,
        didStopWithErrorHandler: @escaping DidStopWithErrorHandler,
        networkAttachmentDisconnectedHandler: @escaping NetworkAttachmentDisconnectedHandler
    ) {
        self.guestDidStopHandler = guestDidStopHandler
        self.didStopWithErrorHandler = didStopWithErrorHandler
        self.networkAttachmentDisconnectedHandler = networkAttachmentDisconnectedHandler
    }

    public func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        guestDidStopHandler()
    }

    public func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        didStopWithErrorHandler(error)
    }

    public func virtualMachine(
        _ virtualMachine: VZVirtualMachine,
        networkDevice: VZNetworkDevice,
        attachmentWasDisconnectedWithError error: Error
    ) {
        networkAttachmentDisconnectedHandler(error)
    }
}
