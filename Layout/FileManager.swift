import Foundation
import Splice

@DependencyClient
struct FileManagerClient: Sendable {
    var fileExists: @Sendable (URL) -> Bool
    var createDirectory: @Sendable (URL, Bool) throws -> Void
    var write: @Sendable (Data, URL) throws -> Void
    var read: @Sendable (URL) throws -> Data

    init(
        fileExists: @escaping @Sendable (URL) -> Bool,
        createDirectory: @escaping @Sendable (URL, Bool) throws -> Void,
        write: @escaping @Sendable (Data, URL) throws -> Void,
        read: @escaping @Sendable (URL) throws -> Data
    ) {
        self.fileExists = fileExists
        self.createDirectory = createDirectory
        self.write = write
        self.read = read
    }
}

extension FileManagerClient {
    @DependencySource
    private static let live = FileManagerClient(
        fileExists: { FileManager.default.fileExists(atPath: $0.path) },
        createDirectory: { url, intermediate in
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: intermediate)
        },
        write: { data, url in
            try data.write(to: url)
        },
        read: { url in
            try Data(contentsOf: url)
        }
    )
}
