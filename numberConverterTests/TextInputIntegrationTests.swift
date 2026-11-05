//
//  TextInputIntegrationTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

@testable import numberConverter
import Observation
import SwiftUI
import UIKit
import XCTest

@MainActor
final class TextInputIntegrationTests: XCTestCase {
    func testTwoDigitBaseRemainsEditableBeforeTheSecondDigit() async throws {
        try await withField(base: 10) { field, state, _ in
            try await focus(field)
            await replaceText("1", in: field)
            try await waitFor { field.text == "1" }
            XCTAssertEqual(state.base, 10)

            await replaceText("16", in: field)
            try await waitFor { state.base == 16 }
            XCTAssertEqual(field.text, "16")

            XCTAssertTrue(field.resignFirstResponder())
            try await waitFor { field.text == "16" && !field.isFirstResponder }
        }
    }

    func testPastedBaseAcceptsOnlyASCIIDigits() async throws {
        try await withField(base: 10) { field, state, root in
            try await focus(field)
            await replaceText("３a٣3.6", in: field)

            try await waitFor(diagnostics: { self.inputDiagnostics(field, state: state, root: root) }) {
                state.base == 36 && state.renderedBase == 36 && field.text == "36"
            }

            await replaceText("2a", in: field)
            try await waitFor(diagnostics: { self.inputDiagnostics(field, state: state, root: root) }) {
                state.base == 2 && state.renderedBase == 2 && field.text == "2"
            }

            await replaceText("2🙂b", in: field)
            try await waitFor(diagnostics: { self.inputDiagnostics(field, state: state, root: root) }) {
                state.base == 2 && state.renderedBase == 2 && field.text == "2"
            }
        }
    }

    func testLosingFocusClampsUnsupportedBasesToTheSupportedBounds() async throws {
        for (draft, expected) in [("0", 2), ("1", 2), ("99", 36)] {
            try await withField(base: 10) { field, state, _ in
                try await focus(field)
                await replaceText(draft, in: field)
                try await waitFor { field.text == draft }
                XCTAssertEqual(state.base, 10)

                XCTAssertTrue(field.resignFirstResponder())
                try await waitFor { state.base == expected && field.text == String(expected) }
            }
        }
    }

    func testEmptyAndOverflowingDraftsRestoreTheLastValidBaseOnFocusLoss() async throws {
        try await withField(base: 16) { field, state, _ in
            for draft in ["", String(repeating: "9", count: 100)] {
                try await focus(field)
                await replaceText(draft, in: field)
                try await waitFor { field.text == draft }
                XCTAssertEqual(state.base, 16)

                XCTAssertTrue(field.resignFirstResponder())
                try await waitFor { field.text == "16" && !field.isFirstResponder }
                XCTAssertEqual(state.base, 16)
            }
        }
    }

    func testExternalBaseChangesRefreshInactiveTextAndBecomeTheRestoredValue() async throws {
        try await withField(base: 10) { field, state, _ in
            state.base = 35
            try await waitFor { state.renderedBase == 35 && field.text == "35" }
            XCTAssertFalse(field.isFirstResponder)

            state.base = 8
            try await waitFor { state.renderedBase == 8 && field.text == "8" }
            XCTAssertFalse(field.isFirstResponder)

            try await focus(field)
            await replaceText("", in: field)
            try await waitFor { field.text?.isEmpty == true }
            XCTAssertEqual(state.base, 8)
            XCTAssertTrue(field.resignFirstResponder())
            try await waitFor { field.text == "8" && !field.isFirstResponder }
            XCTAssertEqual(state.base, 8)
        }
    }

    @Observable
    fileprivate final class BaseState {
        var base: Int
        @ObservationIgnored var renderedBase: Int

        init(base: Int) {
            self.base = base
            renderedBase = base
        }
    }

    private struct EditorHarness: View {
        let state: BaseState

        var body: some View {
            NavigationStack {
                Form {
                    LabeledContent {
                        BaseNumberField(
                            prompt: "10",
                            base: Binding(get: { state.base }, set: { state.base = $0 })
                        )
                    } label: {
                        Text(verbatim: "Base")
                    }
                }
            }
            // acknowledge the real SwiftUI update before sending the next event.
            .onChange(of: state.base) { _, newBase in
                state.renderedBase = newBase
            }
        }
    }

    private final class AppearingHost<Content: View>: UIHostingController<Content> {
        private(set) var hasAppeared = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            hasAppeared = true
        }
    }

    private func withField(
        base: Int,
        body: @MainActor (UITextField, BaseState, UIView) async throws -> Void
    ) async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive })
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let state = BaseState(base: base)
        let host = AppearingHost(rootView: EditorHarness(state: state).environment(\.scenePhase, .active))
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            host.view.endEditing(true)
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKeyAndVisible()
        }
        try await waitFor { host.hasAppeared && window.isKeyWindow }
        try await waitFor { self.firstTextField(in: host.view) != nil }
        let field = try XCTUnwrap(firstTextField(in: host.view))
        XCTAssertEqual(field.text, String(base))
        try await body(field, state, host.view)
    }

    private func firstTextField(in view: UIView) -> UITextField? {
        if let field = view as? UITextField {
            return field
        }
        return view.subviews.lazy.compactMap { self.firstTextField(in: $0) }.first
    }

    private func focus(_ field: UITextField) async throws {
        XCTAssertTrue(field.becomeFirstResponder())
        try await waitFor { field.isFirstResponder && field.isEditing }
        await settleLayout(in: field)
    }

    private func settleLayout(in field: UITextField) async {
        // finish the prior native/SwiftUI transaction before another edit.
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                field.window?.layoutIfNeeded()
                DispatchQueue.main.async { continuation.resume() }
            }
        }
    }

    private func replaceText(_ text: String, in field: UITextField) async {
        await settleLayout(in: field)
        guard let range = field.textRange(from: field.beginningOfDocument, to: field.endOfDocument) else {
            XCTFail("Cannot select the native base editor's text")
            return
        }
        field.selectedTextRange = range
        if text.isEmpty {
            if field.hasText {
                field.deleteBackward()
            }
        } else {
            field.insertText(text)
        }
        // public programmatic input does not promise UIControl event delivery.
        field.sendActions(for: .editingChanged)
        await settleLayout(in: field)
    }

    private func inputDiagnostics(_ field: UITextField, state: BaseState, root: UIView) -> String {
        let current = firstTextField(in: root)
        return "base=\(state.base), renderedBase=\(state.renderedBase), text=\(String(reflecting: field.text)), "
            + "focused=\(field.isFirstResponder), "
            + "attached=\(field.isDescendant(of: root)), window=\(field.window != nil), current=\(current === field), "
            + "liveText=\(String(reflecting: current?.text)), liveFocused=\(current?.isFirstResponder == true)"
    }

    private func waitFor(
        diagnostics: () -> String = { "" },
        file: StaticString = #filePath,
        line: UInt = #line,
        _ predicate: () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !predicate(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        guard predicate() else {
            XCTFail("The native base editor did not reach the expected state: \(diagnostics())", file: file, line: line)
            throw TextInputTestError.stateNotReached
        }
    }
}

private enum TextInputTestError: Error {
    case stateNotReached
}
