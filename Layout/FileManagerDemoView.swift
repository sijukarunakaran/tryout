import SwiftUI
import Splice

struct FileManagerDemoView: View {
    @State private var text = "Hello, file system!"
    @State private var status = ""

    private let viewModel = FileManagerDemoViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("File Manager Demo")
                .font(.title2)
                .bold()

            TextField("Text to save", text: $text)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Button("Save") { Task { await saveButtonTapped() } }
                Button("Load") { Task { await loadButtonTapped() } }
            }

            Text(status)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private func saveButtonTapped() async {
        do {
            let url = try viewModel.save(text)
            status = "Saved to: \(url.lastPathComponent)"
        } catch {
            status = "Save failed: \(error.localizedDescription)"
        }
    }

    private func loadButtonTapped() async {
        do {
            let loaded = try viewModel.load()
            text = loaded
            status = "Loaded from disk"
        } catch {
            status = "Load failed: \(error.localizedDescription)"
        }
    }
}

struct FileManagerDemoViewModel {
    @Dependency(FileManagerClient.self) private var fileManager

    func save(_ text: String) throws -> URL {
        let folderURL = baseFolderURL()
        if !fileManager.fileExists(folderURL) {
            try fileManager.createDirectory(folderURL, true)
        }
        let fileURL = folderURL.appendingPathComponent("note.txt")
        let data = Data(text.utf8)
        try fileManager.write(data, fileURL)
        return fileURL
    }

    func load() throws -> String {
        let fileURL = baseFolderURL().appendingPathComponent("note.txt")
        let data = try fileManager.read(fileURL)
        return String(decoding: data, as: UTF8.self)
    }

    private func baseFolderURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("localdi-demo")
    }
}

#Preview {
    FileManagerDemoView()
}
