//
//  RelayItem.swift
//  RelayAirMobile
//
//  A saved relay item, as a row. Everything here is safe to read without authenticating:
//  the tag, the card's design, and a subtitle. The private half — `RelayItemDetails` —
//  lives in `RelayItemSecrets` behind Face ID, keyed by this row's `id`.
//
//  That is the whole reason the split exists. The wallet renders from these rows alone,
//  so scrolling your cards never raises a prompt.
//
//  Enums are stored as their raw values via `RawRepresentation` rather than by conforming
//  `RelayType` and friends to `QueryBindable`. Same column either way, but the card types
//  stay unaware there is a database.
//

import Foundation
import OSLog
import SQLiteData

@Table("relayItems")
struct RelayItem: Identifiable, Equatable, Sendable {
    let id: UUID

    @Column(as: RelayType.RawRepresentation.self)
    var type: RelayType

    /// What the user called it. Plain text on purpose — it is the one field guaranteed to
    /// be shown in a list, so sealing it would buy nothing and cost a prompt per row.
    var tag = ""

    /// The identifying scrap shown under the tag, denormalised at save time so the list
    /// needs nothing from the Keychain. Kept to what is already printed on receipts:
    /// see `RelayItemDetails.subtitle(for:)`.
    var subtitle = ""

    var createdAt = Date()

    // MARK: Design

    var gradientID = CardGradient.default.id

    @Column(as: CardTexture?.RawRepresentation.self)
    var texture: CardTexture?

    @Column(as: CardFinish.RawRepresentation.self)
    var finish: CardFinish = .frosted

    @Column(as: CardContent.JSONRepresentation.self)
    var content = CardContent()
}

extension RelayItem {

    /// Looked up rather than stored, so removing a gradient from the palette degrades to
    /// the default instead of failing to decode.
    var background: CardGradient { CardGradient.named(gradientID) }

    /// What to show in a list. Never empty — an untagged item still names its kind.
    var displayName: String {
        if !tag.isEmpty { return tag }
        return subtitle.isEmpty ? type.title : subtitle
    }
}

// MARK: - Connection

private let logger = Logger(subsystem: "com.ladulghanneey.RelayAir.ios", category: "Database")

/// Opens and migrates the app's database.
///
/// `defaultDatabase()` provisions per-context: the live app gets a file on disk, previews
/// and tests get their own temporary databases, so a preview cannot write into real data.
///
/// No query tracing. GRDB can log every statement it runs via
/// `Configuration.prepareDatabase` + `db.trace(options: .profile)`, which is useful for a
/// specific hunt and pure noise the rest of the time — add it while you need it, then take
/// it back out. If you ever do, log `$0` and not `$0.expandedDescription`: the latter
/// prints bound values.
func appDatabase() throws -> any DatabaseWriter {
    let database = try defaultDatabase()
    logger.info("open '\(database.path)'")

    var migrator = DatabaseMigrator()
    #if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
    #endif

    // Frozen once shipped. Schema changes get a new migration, never an edit to this one.
    migrator.registerMigration("Create relayItems") { db in
        try #sql(
            """
            CREATE TABLE "relayItems" (
              "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
              "type" TEXT NOT NULL,
              "tag" TEXT NOT NULL DEFAULT '',
              "subtitle" TEXT NOT NULL DEFAULT '',
              "createdAt" TEXT NOT NULL,
              "gradientID" TEXT NOT NULL DEFAULT 'midnight',
              "texture" TEXT,
              "finish" TEXT NOT NULL DEFAULT 'frosted',
              "content" TEXT NOT NULL DEFAULT '{}'
            )
            """
        )
        .execute(db)
    }

    try migrator.migrate(database)
    return database
}
