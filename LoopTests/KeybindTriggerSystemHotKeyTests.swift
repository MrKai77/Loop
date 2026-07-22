import Foundation
import XCTest

@testable import Loop

/// Verifies that Carbon callbacks preserve `KeybindTrigger` behavior and do not race its lifecycle.
final class KeybindTriggerSystemHotKeyTests: XCTestCase {
    private var originalArgumentDomain: [String: Any] = [:]

    override func setUp() -> Void {
        super.setUp()

        // Override only the timing features that would make callback assertions asynchronous.
        // The volatile argument domain avoids writing test values into the developer's real Loop
        // preferences and is restored verbatim in `tearDown`.
        let defaults: UserDefaults = .standard
        originalArgumentDomain = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        var arguments: [String: Any] = originalArgumentDomain
        arguments["doubleClickToTrigger"] = false
        arguments["triggerDelay"] = 0.0
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
    }

    override func tearDown() -> Void {
        UserDefaults.standard.setVolatileDomain(
            originalArgumentDomain,
            forName: UserDefaults.argumentDomain
        )
        super.tearDown()
    }

    func testNormalPressOpensWithoutClosingOnRelease() -> Void {
        let setup: KeybindTriggerSetup = makeSetup(binding: makeNormalBinding())

        setup.backend.emit(id: 1, phase: .pressed)
        setup.backend.emit(id: 1, phase: .released)

        XCTAssertEqual(setup.spy.opened, [setup.binding.action])
        XCTAssertTrue(setup.spy.closes.isEmpty)
    }

    func testBypassPressOpensAndReleaseCloses() -> Void {
        let setup: KeybindTriggerSetup = makeSetup(binding: makeBypassBinding())

        setup.backend.emit(id: 1, phase: .pressed)
        setup.backend.emit(id: 1, phase: .released)

        XCTAssertEqual(setup.spy.opened, [setup.binding.action])
        XCTAssertEqual(setup.spy.closes, [false])
    }

    func testDuplicatePressOnlyRepeatsRepeatableActions() -> Void {
        let regular: KeybindTriggerSetup = makeSetup(binding: makeNormalBinding())
        regular.backend.emit(id: 1, phase: .pressed)
        regular.backend.emit(id: 1, phase: .pressed)

        let repeatableAction: WindowAction = .init(.growLeft, keybind: [.kVK_LeftArrow])
        let repeatable: KeybindTriggerSetup = makeSetup(
            binding: makeNormalBinding(action: repeatableAction)
        )
        repeatable.backend.emit(id: 1, phase: .pressed)
        repeatable.backend.emit(id: 1, phase: .pressed)

        XCTAssertEqual(regular.spy.opened.count, 1)
        XCTAssertTrue(repeatableAction.canRepeat)
        XCTAssertEqual(repeatable.spy.opened.count, 2)
    }

    func testOnlyExactRegisteredKeyDownDefersToCarbon() -> Void {
        let setup: KeybindTriggerSetup = makeSetup(binding: makeNormalBinding())
        let shortcut: Set<CGKeyCode> = setup.binding.shortcut.keyCodes

        XCTAssertTrue(setup.trigger.shouldDeferToSystemHotKey(
            type: .keyDown,
            keyCodes: shortcut
        ))
        XCTAssertFalse(setup.trigger.shouldDeferToSystemHotKey(
            type: .keyUp,
            keyCodes: shortcut
        ))
        XCTAssertFalse(setup.trigger.shouldDeferToSystemHotKey(
            type: .keyDown,
            keyCodes: shortcut.union([.kVK_UpArrow])
        ))
    }

    func testQueuedPressIsDiscardedAfterStop() -> Void {
        var scheduled: [() -> Void] = []
        let setup: KeybindTriggerSetup = makeSetup(
            binding: makeNormalBinding(),
            // Holding the block simulates Carbon input queued behind `stop` on the event-tap
            // thread, where the generation check must discard it.
            scheduler: { scheduled.append($0) }
        )

        setup.backend.emit(id: 1, phase: .pressed)
        setup.trigger.stop()
        scheduled.forEach { $0() }

        XCTAssertTrue(setup.spy.opened.isEmpty)
    }

    private func makeSetup(
        binding: SystemHotKeyBinding,
        scheduler: @escaping (@escaping () -> Void) -> Void = { $0() }
    ) -> KeybindTriggerSetup {
        // The backend assigns IDs from 1, so rebuilding with one binding gives every test a stable
        // callback ID without invoking the process-global Carbon API.
        let backend: SystemHotKeyBackendSpy = .init()
        let monitor: SystemHotKeyMonitor = .init(backend: backend)
        let spy: KeybindCallbackSpy = .init()
        let trigger: KeybindTrigger = .init(
            windowActionCache: .init(),
            systemHotKeyMonitor: monitor,
            systemHotKeyScheduler: scheduler,
            openCallback: { action in
                spy.opened.append(action)
                spy.isOpen = true
            },
            closeCallback: { forceClose in
                spy.closes.append(forceClose)
                spy.isOpen = false
            },
            checkIfLoopOpen: { spy.isOpen }
        )
        monitor.rebuild(bindings: [binding])
        return .init(
            trigger: trigger,
            monitor: monitor,
            backend: backend,
            binding: binding,
            spy: spy
        )
    }

    private func makeNormalBinding(
        action: WindowAction = .init(.leftHalf, keybind: [.kVK_LeftArrow])
    ) -> SystemHotKeyBinding {
        .init(
            shortcut: .init(keyCodes: [
                .kVK_Command, .kVK_Option, .kVK_LeftArrow
            ])!,
            action: action,
            bypassesTrigger: false
        )
    }

    private func makeBypassBinding() -> SystemHotKeyBinding {
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
    }
}

/// Records user-visible callbacks without constructing Loop's window-management UI.
private final class KeybindCallbackSpy {
    var opened: [WindowAction] = []
    var closes: [Bool] = []
    var isOpen: Bool = false
}

/// Keeps the collaborating trigger, monitor, backend, binding, and callback spy together.
private struct KeybindTriggerSetup {
    let trigger: KeybindTrigger
    let monitor: SystemHotKeyMonitor
    let backend: SystemHotKeyBackendSpy
    let binding: SystemHotKeyBinding
    let spy: KeybindCallbackSpy
}
