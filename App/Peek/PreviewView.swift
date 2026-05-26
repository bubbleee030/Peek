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
                    row(item)
                }
                .listStyle(.inset)
            }
        }
    }

    private func row(_ item: PreviewItem) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: FileIcon.image(for: item))
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
            Text(item.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 12)
            if let modified = item.modified {
                Text(Self.date(modified))
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Text(item.isDirectory ? "—" : Self.size(item.sizeBytes))
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 1)
    }

    private static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static func date(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
