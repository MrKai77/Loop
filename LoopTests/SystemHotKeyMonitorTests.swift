import Carbon.HIToolbox
import XCTest

@testable import Loop

/// Verifies registration lifecycle, partial failures, and stale Carbon callback rejection.
final class SystemHotKeyMonitorTests: XCTestCase {
    func testRoutesRegisteredPressAndRelease() -> Void {
        let backend: SystemHotKeyBackendSpy = .init()
        let monitor: SystemHotKeyMonitor = .init(backend: backend)
        let bindings: [SystemHotKeyBinding] = makeBindings()
        var received: [(SystemHotKeyBinding, SystemHotKeyPhase)] = []
        monitor.eventCallback = { received.append(($0, $1)) }

        monitor.rebuild(bindings: bindings)
        backend.emit(id: 1, phase: .pressed)
        backend.emit(id: 1, phase: .released)

        XCTAssertEqual(backend.registrationIDs, [1, 2])
        XCTAssertEqual(received.map(\.0), [bindings[0], bindings[0]])
        XCTAssertEqual(received.map(\.1), [.pressed, .released])
    }

    func testSkipsFailedRegistrationAndContinues() -> Void {
        let backend: SystemHotKeyBackendSpy = .init()
        backend.rejectedIDs = [1]
        let monitor: SystemHotKeyMonitor = .init(backend: backend)
        let bindings: [SystemHotKeyBinding] = makeBindings()
        var received: [SystemHotKeyBinding] = []
        monitor.eventCallback = { binding, _ in received.append(binding) }

        monitor.rebuild(bindings: bindings)
        backend.emit(id: 1, phase: .pressed)
        backend.emit(id: 2, phase: .pressed)

        XCTAssertFalse(monitor.isRegistered(shortcut: bindings[0].shortcut))
        XCTAssertTrue(monitor.isRegistered(shortcut: bindings[1].shortcut))
        XCTAssertEqual(received, [bindings[1]])
    }

    func testStartFailureRegistersNothing() -> Void {
        let backend: SystemHotKeyBackendSpy = .init()
        backend.startStatus = OSStatus(eventNotHandledErr)
        let monitor: SystemHotKeyMonitor = .init(backend: backend)
        let binding: SystemHotKeyBinding = makeBindings()[0]

        monitor.rebuild(bindings: [binding])

        XCTAssertTrue(backend.registrationIDs.isEmpty)
        XCTAssertFalse(monitor.isRegistered(shortcut: binding.shortcut))
    }

    func testRebuildIgnoresStaleRegistrationIDs() -> Void {
        let backend: SystemHotKeyBackendSpy = .init()
        let monitor: SystemHotKeyMonitor = .init(backend: backend)
        let bindings: [SystemHotKeyBinding] = makeBindings()
        var received: [SystemHotKeyBinding] = []
        monitor.eventCallback = { binding, _ in received.append(binding) }

        monitor.rebuild(bindings: [bindings[0]])
        monitor.rebuild(bindings: [bindings[1]])
        backend.emit(id: 1, phase: .pressed)
        backend.emit(id: 2, phase: .pressed)

        XCTAssertEqual(received, [bindings[1]])
    }

    func testStopClearsRegistrationsAndCallbacks() -> Void {
        let backend: SystemHotKeyBackendSpy = .init()
        let monitor: SystemHotKeyMonitor = .init(backend: backend)
        let binding: SystemHotKeyBinding = makeBindings()[0]
        var callbackCount: Int = 0
        monitor.eventCallback = { _, _ in callbackCount += 1 }

        monitor.rebuild(bindings: [binding])
        monitor.stop()
        backend.emit(id: 1, phase: .pressed)

        XCTAssertFalse(monitor.isRegistered(shortcut: binding.shortcut))
        XCTAssertEqual(backend.stopCallCount, 1)
        XCTAssertEqual(callbackCount, 0)
    }

    private func makeBindings() -> [SystemHotKeyBinding] {
        [
            .init(
                shortcut: .init(keyCodes: [
                    .kVK_Command, .kVK_Option, .kVK_LeftArrow
                ])!,
                action: .init(.leftHalf, keybind: [.kVK_LeftArrow]),
                bypassesTrigger: false
            ),
            .init(
                shortcut: .init(keyCodes: [
                    .kVK_Command, .kVK_Control, .kVK_RightArrow
                ])!,
                action: .init(
                    .nextScreen,
                    keybind: [.kVK_Command, .kVK_Control, .kVK_RightArrow],
                    bypassTriggerKey: true
                ),
                bypassesTrigger: true
            )
        ]
    }
}

/// Deterministic in-memory substitute for the process-global Carbon registration API.
///
/// Tests can reject selected IDs or fail startup without reserving real global shortcuts. Emitted
/// events still travel through the monitor's production ID-to-binding callback path.
final class SystemHotKeyBackendSpy: SystemHotKeyRegistrationBackend {
    var eventCallback: ((SystemHotKeyEvent) -> Void)?
    var startStatus: OSStatus = noErr
    var rejectedIDs: Set<UInt32> = []
    private(set) var registrationIDs: [UInt32] = []
    private(set) var stopCallCount: Int = 0

    func start() -> OSStatus {
        startStatus
    }

    func register(shortcut: SystemHotKeyShortcut, id: UInt32) -> OSStatus {
        registrationIDs.append(id)
        return rejectedIDs.contains(id) ? OSStatus(eventHotKeyExistsErr) : noErr
    }

    func unregisterAll() -> Bool {
        true
    }

    func stop() -> Bool {
        stopCallCount += 1
        return true
    }

    func emit(id: UInt32, phase: SystemHotKeyPhase) -> Void {
        eventCallback?(.init(id: id, phase: phase))
    }
}
