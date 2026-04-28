import Foundation

/// `true` when the current process is a test runner (Xcode or `swift test`).
let _isTesting: Bool = {
    let env = ProcessInfo.processInfo.environment

    // Set by xcodebuild when running tests.
    if env["XCTestBundlePath"] != nil || env["XCTestConfigurationFilePath"] != nil {
        return true
    }

    // XCTest framework is loaded — most reliable runtime signal.
    if NSClassFromString("XCTestCase") != nil {
        return true
    }

    // `swift test` via SwiftPM uses "swiftpm-testing-helper" as argv[0],
    // and .xctest bundles embed "xctest" in their path.
    // Test product binaries end with the target name, typically suffixed "Tests".
    if let exec = ProcessInfo.processInfo.arguments.first {
        let name = exec.lowercased()
        if name.contains("xctest")
            || name.contains("swiftpm-testing-helper")
            || name.hasSuffix("tests") {
            return true
        }
    }

    return false
}()
