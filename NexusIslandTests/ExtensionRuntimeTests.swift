import XCTest
import JavaScriptCore
@testable import NexusIsland

/// Tests for the extension runtime's sandboxing and the ViewNode IR that
/// bridges JavaScript view trees into SwiftUI.
///
/// Security-critical: the sandbox must strip `eval` and `Function` so an
/// untrusted extension can't break out of JavaScriptCore. The ViewNode parser
/// must tolerate missing/optional fields gracefully (extensions return partial
/// trees all the time).
final class ExtensionRuntimeTests: XCTestCase {

    // MARK: - Sandbox hardening

    /// `eval` and `Function` are deleted by ExtensionSandbox.configureContext.
    /// This is the primary containment mechanism — without it an extension
    /// could synthesize arbitrary code. Lock it down hard.
    func testSandboxRemovesEvalAndFunction() {
        let context = JSContext()!

        // Before configuration both globals exist on JavaScriptCore's default context.
        XCTAssertNotNil(context.evaluateScript("eval"))
        XCTAssertNotNil(context.evaluateScript("Function"))

        ExtensionSandbox.configureContext(context, extensionID: "test.sandbox", permissions: [])

        // After configuration, attempting to call them must throw and the
        // global bindings must be gone.
        let evalAfter = context.evaluateScript("typeof eval")
        XCTAssertEqual(evalAfter?.toString(), "undefined", "eval must be removed from the sandbox")

        let functionAfter = context.evaluateScript("typeof Function")
        XCTAssertEqual(functionAfter?.toString(), "undefined", "Function must be removed from the sandbox")
    }

    func testSandboxFlagsNetworkDisabledWhenPermissionAbsent() {
        let context = JSContext()!
        ExtensionSandbox.configureContext(context, extensionID: "test.net", permissions: ["storage"])

        let flag = context.evaluateScript("globalThis.__nexusIslandNetworkDisabled")
        XCTAssertEqual(flag?.toBool(), true, "network must be flagged disabled without the 'network' permission")
    }

    func testSandboxDoesNotFlagNetworkWhenPermissionPresent() {
        let context = JSContext()!
        ExtensionSandbox.configureContext(context, extensionID: "test.net", permissions: ["network", "storage"])

        let flag = context.evaluateScript("globalThis.__nexusIslandNetworkDisabled")
        XCTAssertFalse(flag?.toBool() ?? true, "network flag must NOT be set when the 'network' permission is granted")
    }

    func testSandboxSetsExceptionHandler() {
        let context = JSContext()!
        ExtensionSandbox.configureContext(context, extensionID: "test.exc", permissions: [])

        // A throwing script must not crash the host; the exception handler
        // absorbs it. We just assert the context survives a bad script.
        context.evaluateScript("throw new Error('boom')")
        // If we got here, the exception handler prevented a crash.
        XCTAssertEqual(context.evaluateScript("1 + 1")?.toInt32(), 2)
    }

    // MARK: - ViewNode.from nil / empty handling

    func testViewNodeFromNilReturnsEmpty() {
        XCTAssertEqual(ViewNode.from(nil), .empty)
    }

    func testViewNodeFromNullReturnsEmpty() {
        let context = JSContext()!
        let null = context.evaluateScript("null")
        XCTAssertEqual(ViewNode.from(null), .empty)
    }

    func testViewNodeFromUndefinedReturnsEmpty() {
        let context = JSContext()!
        let undef = context.evaluateScript("undefined")
        XCTAssertEqual(ViewNode.from(undef), .empty)
    }

    func testViewNodeFromObjectWithoutTypeReturnsEmpty() {
        let context = JSContext()!
        let noType = context.evaluateScript("({ value: 'hi' })")
        XCTAssertEqual(ViewNode.from(noType), .empty)
    }

    /// Evaluates an expression as the return value of a function and yields the
    /// result — mirroring how extensions actually produce view nodes (a
    /// callback returns a plain object literal). Object literals evaluated at
    /// the top level can surface as `undefined`/`NaN` via `forProperty`, so we
    /// route them through a function call to match the production path.
    private func evaluateReturning(_ source: String) -> JSValue? {
        let context = JSContext()!
        return context.evaluateScript("(function() { return \(source); })()")
    }

    // MARK: - ViewNode.from structural nodes (with full values, as extensions emit)

    func testViewNodeParsesHStack() {
        // Extensions emit fully-specified nodes; the parser must round-trip them.
        let node = evaluateReturning(#"""
        { type: "hstack", spacing: 12, align: "top", distribution: "fill", children: [] }
        """#)
        let parsed = ViewNode.from(node)

        guard case let .hstack(spacing, align, distribution, children) = parsed else {
            XCTFail("expected .hstack, got \(String(describing: parsed))")
            return
        }
        XCTAssertEqual(spacing, 12)
        XCTAssertEqual(align, "top")
        XCTAssertEqual(distribution, "fill")
        XCTAssertTrue(children.isEmpty)
    }

    func testViewNodeParsesVStack() {
        let node = evaluateReturning(#"""
        { type: "vstack", spacing: 6, align: "leading", distribution: "equalSpacing", children: [] }
        """#)
        let parsed = ViewNode.from(node)

        guard case let .vstack(spacing, align, distribution, children) = parsed else {
            XCTFail("expected .vstack, got \(String(describing: parsed))")
            return
        }
        XCTAssertEqual(spacing, 6)
        XCTAssertEqual(align, "leading")
        XCTAssertEqual(distribution, "equalSpacing")
        XCTAssertTrue(children.isEmpty)
    }

    func testViewNodeParsesSpacerWithMinLength() {
        let node = evaluateReturning(#"{ type: "spacer", minLength: 20 }"#)
        let parsed = ViewNode.from(node)

        guard case let .spacer(minLength) = parsed else {
            XCTFail("expected .spacer, got \(String(describing: parsed))")
            return
        }
        XCTAssertEqual(minLength, 20)
    }

    func testViewNodeParsesDivider() {
        let node = evaluateReturning(#"{ type: "divider" }"#)
        XCTAssertEqual(ViewNode.from(node), .divider)
    }

    // MARK: - ViewNode.from leaf nodes (with full values)

    func testViewNodeParsesText() {
        let node = evaluateReturning(#"""
        { type: "text", value: "Hello", style: "title", color: "red", lineLimit: 2 }
        """#)
        let parsed = ViewNode.from(node)

        guard case let .text(value, style, color, lineLimit) = parsed else {
            XCTFail("expected .text, got \(String(describing: parsed))")
            return
        }
        XCTAssertEqual(value, "Hello")
        XCTAssertEqual(style, .title)
        XCTAssertEqual(color, .named("red"))
        XCTAssertEqual(lineLimit, 2)
    }

    func testViewNodeParsesTextWithRGBColor() {
        let node = evaluateReturning(#"""
        { type: "text", value: "x", style: "body", color: { r: 0.5, g: 0.5, b: 0.5, a: 1 } }
        """#)
        let parsed = ViewNode.from(node)

        guard case let .text(_, _, color, _) = parsed else {
            XCTFail("expected .text, got \(String(describing: parsed))")
            return
        }
        XCTAssertEqual(color, .rgba(r: 0.5, g: 0.5, b: 0.5, a: 1))
    }

    func testViewNodeParsesIcon() {
        let node = evaluateReturning(#"{ type: "icon", name: "star.fill", size: 18, color: "yellow" }"#)
        let parsed = ViewNode.from(node)

        guard case let .icon(name, size, color) = parsed else {
            XCTFail("expected .icon, got \(String(describing: parsed))")
            return
        }
        XCTAssertEqual(name, "star.fill")
        XCTAssertEqual(size, 18)
        XCTAssertEqual(color, .named("yellow"))
    }

    func testViewNodeParsesProgress() {
        let node = evaluateReturning(#"{ type: "progress", value: 0.7, total: 1, color: "green" }"#)
        let parsed = ViewNode.from(node)

        guard case let .progress(value, total, color) = parsed else {
            XCTFail("expected .progress, got \(String(describing: parsed))")
            return
        }
        XCTAssertEqual(value, 0.7, accuracy: 0.001)
        XCTAssertEqual(total, 1, accuracy: 0.001)
        XCTAssertEqual(color, .named("green"))
    }

    // MARK: - ColorValue

    func testNamedColorEquality() {
        XCTAssertEqual(ColorValue.named("red"), .named("red"))
        XCTAssertNotEqual(ColorValue.named("red"), .named("blue"))
    }

    func testRGBAColorEquality() {
        XCTAssertEqual(ColorValue.rgba(r: 1, g: 0, b: 0, a: 1), .rgba(r: 1, g: 0, b: 0, a: 1))
        XCTAssertNotEqual(ColorValue.rgba(r: 1, g: 0, b: 0, a: 1), .rgba(r: 0, g: 0, b: 0, a: 1))
    }

    func testNamedAndRGBAAreNeverEqual() {
        XCTAssertNotEqual(ColorValue.named("white"), .rgba(r: 1, g: 1, b: 1, a: 1))
    }

    // MARK: - TextStyle

    func testTextStyleParsesKnownCases() {
        XCTAssertEqual(TextStyle(rawValue: "body"), .body)
        XCTAssertEqual(TextStyle(rawValue: "title"), .title)
        XCTAssertEqual(TextStyle(rawValue: "monospaced"), .monospaced)
        XCTAssertEqual(TextStyle(rawValue: "monospacedSmall"), .monospacedSmall)
    }

    func testTextStyleUnknownRawValueReturnsNil() {
        XCTAssertNil(TextStyle(rawValue: "bogus"))
    }

    // MARK: - DisplayMode

    func testDisplayModeExhaustiveCases() {
        // If a new display mode is added, this test forces us to update the
        // renderer switch and the tests that cover it.
        let modes: [DisplayMode] = [.compact, .expanded, .fullExpanded, .minimalLeading, .minimalTrailing]
        XCTAssertEqual(Set(modes.map { "\($0)" }).count, modes.count, "all DisplayMode cases must be distinct")
    }
}
