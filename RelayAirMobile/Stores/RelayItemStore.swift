//
//  RelayItemStore.swift
//  RelayAirMobile
//
//  CRUD over saved relay items. Every write goes through here, which is what makes the
//  two halves — the row and its Keychain entry — stay in step.
//
//  Reads are not this store's job. `items` is a `@FetchAll`, so it observes the table and
//  updates itself after any write, from here or anywhere else. Nothing needs refreshing.
//  A view can equally declare its own `@FetchAll` and skip the store entirely.
//
//  Ordering inside each write is deliberate, not incidental:
//
//  · Create writes the secret first. An insert that then fails leaves a Keychain entry
//    with no row, which `sweepOrphanedSecrets()` collects. The other order would leave a
//    card in the wallet with nothing behind it — visible, and useless.
//  · Delete removes the row first, then the entry. A row that survives its secret is the
//    recoverable failure; a secret that survives its row is the one the sweep catches.
//

import Foundation
import OSLog
import SQLiteData

@MainActor
@Observable
final class RelayItemStore {

    /// Newest first, and live: SQLiteData observes the table, so this reflects a write as
    /// soon as it lands. `@ObservationIgnored` is required on property wrappers inside an
    /// `@Observable` class and does not disable that observation.
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

        try RelayItemSecrets.store(details, for: item.id)

        do {
            try database.write { db in
                try RelayItem.insert { item }.execute(db)
            }
        } catch {
            // Rolled back here rather than left for the sweep — we know right now that it
            // has no row.
            try? RelayItemSecrets.delete(for: item.id)
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

    /// The private half. Puts up Face ID, and suspends rather than blocking while it is up.
    func details(
        for item: RelayItem,
        reason: String = "Unlock your saved details"
    ) async throws -> RelayItemDetails {
        try await RelayItemSecrets.load(for: item.id, reason: reason)
    }

    // MARK: - Update

    /// Saves a changed row. Pass `details` only when the private half changed too — it
    /// costs a Keychain write and a recomputed subtitle.
    func update(_ item: RelayItem, details: RelayItemDetails? = nil) throws {
        var row = item
        row.tag = item.tag.trimmingCharacters(in: .whitespacesAndNewlines)

        if let details {
            row.subtitle = details.subtitle(for: item.type)
            try RelayItemSecrets.store(details, for: item.id)
        }

        do {
            try database.write { db in
                try RelayItem.update(row).execute(db)
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
                try RelayItem.delete(item).execute(db)
            }
        } catch {
            logger.error("Delete failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        // After the row, and unchecked: if this fails the entry is an orphan, and an
        // orphan is sweepable. Failing the whole delete would leave the user staring at a
        // card they asked to remove.
        try? RelayItemSecrets.delete(for: item.id)
    }

    // MARK: - Maintenance

    /// Deletes Keychain entries with no matching row. Cheap, and raises no Face ID prompt
    /// — enumerating accounts reads attributes, not data. Worth calling at launch.
    ///
    /// Reads the ids straight from the database rather than from `items`, which is observed
    /// and may not have loaded yet this early in launch.
    func sweepOrphanedSecrets() {
        do {
            let known = Set(try database.read { db in try RelayItem.all.fetchAll(db) }.map(\.id))
            let orphans = RelayItemSecrets.storedIDs().subtracting(known)

            guard !orphans.isEmpty else { return }
            logger.info("Sweeping \(orphans.count) orphaned secret(s)")
            for id in orphans {
                try? RelayItemSecrets.delete(for: id)
            }
        } catch {
            logger.error("Sweep failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
