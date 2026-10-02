//
//  RelayItemStore.swift
//  RelayAirMobile
//
//  Card rows and relay details live in separate local SQLite tables. Create, update,
//  and delete write the related records in one database transaction.
//

import Foundation
import OSLog
import SQLiteData
import SwiftUI

@MainActor
@Observable
final class RelayItemStore {

    /// Newest first, and live: SQLiteData observes the table, so this reflects a write as
    /// soon as it lands and any view reading it re-renders.
    @ObservationIgnored
    @FetchAll(RelayItem.order { $0.createdAt.desc() })
    var items: [RelayItem]

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @ObservationIgnored
    private let logger = Logger(
        subsystem: "com.ladulghanneey.RelayAir.ios",
        category: "RelayItemStore"
    )

    // MARK: - Create

    @discardableResult
    func create(
        type: RelayType,
        tag: String,
        details: RelayItemDetails,
        background: CardGradient,
        content: CardContent,
        texture: CardTexture?,
        finish: CardFinish
    ) throws -> RelayItem {
        let item = RelayItem(
            id: UUID(),
            type: type,
            tag: tag.trimmingCharacters(in: .whitespacesAndNewlines),
            subtitle: details.subtitle(for: type),
            createdAt: Date(),
            gradientID: background.id,
            texture: texture,
            finish: finish,
            content: content
        )
        let detailsRecord = RelayItemDetailsRecord(
            relayItemId: item.id,
            details: details
        )

        do {
            try database.write { db in
                try RelayItem.insert { item }.execute(db)
                try RelayItemDetailsRecord.insert { detailsRecord }.execute(db)
            }
        } catch {
            logger.error("Create failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        return item
    }

    // MARK: - Read

    func item(id: UUID) throws -> RelayItem? {
        try database.read { db in
            try RelayItem.find(id).fetchOne(db)
        }
    }

    /// Reads the dedicated SQLite record.
    func details(for item: RelayItem) async throws -> RelayItemDetails {
        let record = try await database.read { db in
            try RelayItemDetailsRecord.find(item.id).fetchOne(db)
        }
        return record?.details ?? RelayItemDetails()
    }

    // MARK: - Update

    /// Saves the card row and detail record together in the same transaction.
    func update(_ item: RelayItem, details: RelayItemDetails) throws {
        var row = item
        row.tag = item.tag.trimmingCharacters(in: .whitespacesAndNewlines)
        row.subtitle = details.subtitle(for: item.type)
        let detailsRecord = RelayItemDetailsRecord(
            relayItemId: item.id,
            details: details
        )

        do {
            try database.write { db in
                try RelayItem.update(row).execute(db)
                try RelayItemDetailsRecord.update(detailsRecord).execute(db)
            }
        } catch {
            logger.error("Update failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    // MARK: - Delete

    func delete(_ item: RelayItem) throws {
        do {
            try database.write { db in
                if let detailsRecord = try RelayItemDetailsRecord.find(item.id).fetchOne(db) {
                    try RelayItemDetailsRecord.delete(detailsRecord).execute(db)
                }
                try RelayItem.delete(item).execute(db)
            }
        } catch {
            logger.error("Delete failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
