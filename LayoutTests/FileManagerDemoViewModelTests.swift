import Foundation
import os
import Testing
import Splice
@testable import Layout

private struct FileManagerRecorder: Sendable {
    private struct State {
        var createdDirectories: [(url: URL, intermediate: Bool)] = []
        var writes: [(data: Data, url: URL)] = []
        var reads: [URL] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func recordCreateDirectory(url: URL, intermediate: Bool) {
        state.withLock {
            $0.createdDirectories.append((url, intermediate))
        }
    }

    func recordWrite(data: Data, url: URL) {
        state.withLock {
            $0.writes.append((data, url))
        }
    }

    func recordRead(url: URL) {
        state.withLock {
            $0.reads.append(url)
        }
    }

    var createdDirectories: [(url: URL, intermediate: Bool)] {
        state.withLock(\.createdDirectories)
    }

    var writes: [(data: Data, url: URL)] {
        state.withLock(\.writes)
    }

    var reads: [URL] {
        state.withLock(\.reads)
    }
}

private enum TestFailure: Error, Equatable {
    case expected
}

@MainActor
private func makeViewModel(fileManager: FileManagerClient) -> FileManagerDemoViewModel {
    withDependencies(
        { values in
            values[FileManagerClient.self] = fileManager
        },
        operation: {
            FileManagerDemoViewModel()
        }
    )
}

@Test
@MainActor
func saveCreatesDirectoryAndWritesText() throws {
    let recorder = FileManagerRecorder()
    let expectedURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("localdi-demo")
        .appendingPathComponent("note.txt")
    let viewModel = makeViewModel(
        fileManager: FileManagerClient(
            fileExists: { _ in false },
            createDirectory: { url, intermediate in
                recorder.recordCreateDirectory(url: url, intermediate: intermediate)
            },
            write: { data, url in
                recorder.recordWrite(data: data, url: url)
            },
            read: { _ in Data() }
        )
    )

    let savedURL = try viewModel.save("Hello, file system!")

    #expect(savedURL == expectedURL)
    #expect(recorder.createdDirectories.count == 1)
    #expect(
        recorder.createdDirectories.first?.url.path == expectedURL.deletingLastPathComponent().path
    )
    #expect(recorder.createdDirectories.first?.intermediate == true)
    #expect(recorder.writes.count == 1)
    #expect(recorder.writes.first?.url == expectedURL)
    #expect(recorder.writes.first?.data == Data("Hello, file system!".utf8))
}

@Test
@MainActor
func saveSkipsDirectoryCreationWhenFolderExists() throws {
    let recorder = FileManagerRecorder()
    let expectedURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("localdi-demo")
        .appendingPathComponent("note.txt")
    let viewModel = makeViewModel(
        fileManager: FileManagerClient(
            fileExists: { _ in true },
            createDirectory: { url, intermediate in
                recorder.recordCreateDirectory(url: url, intermediate: intermediate)
            },
            write: { data, url in
                recorder.recordWrite(data: data, url: url)
            },
            read: { _ in Data() }
        )
    )

    _ = try viewModel.save("Existing folder")

    #expect(recorder.createdDirectories.isEmpty)
    #expect(recorder.writes.count == 1)
    #expect(recorder.writes.first?.url == expectedURL)
    #expect(recorder.writes.first?.data == Data("Existing folder".utf8))
}

@Test
@MainActor
func loadReadsSavedFileContents() throws {
    let recorder = FileManagerRecorder()
    let expectedURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("localdi-demo")
        .appendingPathComponent("note.txt")
    let viewModel = makeViewModel(
        fileManager: FileManagerClient(
            fileExists: { _ in true },
            createDirectory: { _, _ in },
            write: { _, _ in },
            read: { url in
                recorder.recordRead(url: url)
                return Data("Loaded text".utf8)
            }
        )
    )

    let loadedText = try viewModel.load()

    #expect(loadedText == "Loaded text")
    #expect(recorder.reads == [expectedURL])
}

@Test
@MainActor
func savePropagatesWriteFailures() {
    let viewModel = makeViewModel(
        fileManager: FileManagerClient(
            fileExists: { _ in true },
            createDirectory: { _, _ in },
            write: { _, _ in throw TestFailure.expected },
            read: { _ in Data() }
        )
    )

    do {
        _ = try viewModel.save("Will fail")
        Issue.record("Expected save to throw")
    } catch {
        #expect(error as? TestFailure == .expected)
    }
}
