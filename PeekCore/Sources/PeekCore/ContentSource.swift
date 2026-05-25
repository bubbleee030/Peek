import Foundation

/// Anything that can produce a flat listing. Sendable so a source can be read
/// off the main thread from the app's view model.
public protocol ContentSource: Sendable {
    func read() throws -> PreviewContents
}

public enum ContentSourceError: Error, Equatable {
    case cannotRead(String)
    case unsupported(String)
}
