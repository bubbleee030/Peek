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
            Text("\(contents.count) item\(contents.count == 1 ? "" : "s") • \(Formatting.size(contents.totalSize))")
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
                // Keyed by URL so expansion/selection reset when the panel
                // follows the Finder selection to another item.
                ListingView(contents: contents).id(model.url)
            }
        }
    }
}

/// The contents list. Archive folders expand in place; a lone top-level
/// folder (the usual shape of a zipped project) starts expanded.
private struct ListingView: View {
    let contents: PreviewContents
    @State private var selection: PreviewItem.ID?
    @State private var expanded: Set<PreviewItem.ID>

    init(contents: PreviewContents) {
        self.contents = contents
        let only = contents.items.count == 1 ? contents.items.first : nil
        _expanded = State(initialValue: only?.children?.isEmpty == false ? [only!.id] : [])
    }

    var body: some View {
        List(selection: $selection) {
            rows(contents.items)
        }
        .listStyle(.inset)
    }

    /// Type-erased because it recurses.
    private func rows(_ items: [PreviewItem]) -> AnyView {
        AnyView(ForEach(items) { item in
            if let children = item.children, !children.isEmpty {
                DisclosureGroup(isExpanded: isExpanded(item.id)) {
                    rows(children)
                } label: {
                    row(item)
                }
            } else {
                row(item)
            }
        })
    }

    private func isExpanded(_ id: PreviewItem.ID) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(id) },
            set: { if $0 { expanded.insert(id) } else { expanded.remove(id) } }
        )
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
                Text(Formatting.date(modified))
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Text(item.isDirectory ? "—" : Formatting.size(item.sizeBytes))
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 1)
    }
}

private enum Formatting {
    static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static func date(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
