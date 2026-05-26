import SwiftUI
import AppKit
import PeekCore

struct PreviewView: View {
    @ObservedObject var model: PreviewViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 480, minHeight: 360)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: model.url.path))
                .resizable().frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.title).font(.headline).lineLimit(1)
                summary
            }
            Spacer()
        }
        .padding(12)
    }

    @ViewBuilder private var summary: some View {
        if case let .loaded(contents) = model.state {
            Text("\(contents.count) item\(contents.count == 1 ? "" : "s") • \(Self.size(contents.totalSize))")
                .font(.subheadline).foregroundStyle(.secondary)
        } else {
            Text(" ").font(.subheadline)
        }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.secondary)
                Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
        case .loaded(let contents):
            if contents.items.isEmpty {
                Text("Empty").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(contents.items) { item in
                    HStack(spacing: 8) {
                        Image(systemName: item.isDirectory ? "folder" : "doc")
                            .foregroundStyle(item.isDirectory ? Color.accentColor : Color.secondary)
                        Text(item.name).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        if !item.isDirectory {
                            Text(Self.size(item.sizeBytes)).foregroundStyle(.secondary)
                                .font(.callout).monospacedDigit()
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
