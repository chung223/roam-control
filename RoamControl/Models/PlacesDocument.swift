import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Saved favourites as a file.
///
/// Everything this app keeps is deliberately on the device and nowhere else,
/// which is the point of it — and also means a lost iPhone is a lost
/// collection, with no service holding a copy to restore from. A file is the
/// way out that does not undo the reason for the constraint: it is made when
/// asked for, it goes where its owner puts it, and nothing sends it anywhere.
struct PlacesDocument: Codable, Sendable {
    /// Read on import and refused if it is not recognised, so that a later
    /// format cannot be half-understood by an earlier build.
    static let currentFormat = "sprout.places.v1"

    var format: String
    var exportedAt: Date
    var favourites: [LocationTarget]

    init(favourites: [LocationTarget], exportedAt: Date = .now) {
        self.format = Self.currentFormat
        self.exportedAt = exportedAt
        self.favourites = favourites
    }

    var isSupported: Bool { format == Self.currentFormat }
}

/// The document wrapper SwiftUI's exporter and importer need.
///
/// Plain JSON rather than a declared file type of its own. A private type
/// would need an Info.plist declaration to buy nothing, and this way the file
/// opens in anything — someone about to hand their saved places to another
/// device can read exactly what is in it first.
struct PlacesFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var document: PlacesDocument

    init(document: PlacesDocument) {
        self.document = document
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        document = try decoder.decode(PlacesDocument.self, from: data)
        guard document.isSupported else { throw CocoaError(.fileReadUnknownStringEncoding) }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(document))
    }
}
