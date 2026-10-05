# RelayAir artwork generation

The canonical image prompt is [RelayArtworkGenerationPrompt.json](RelayArtworkGenerationPrompt.json). It replaces the earlier free-form prompt and defines one shared style for all eleven RelayAir artwork assets.

## Generate or regenerate an icon

1. Set `generation_request.target_asset` to one `asset_id` from `asset_catalog`.
2. Set `generation_request.reference_asset_id` to that same ID and attach its current PNG as the visual reference when available.
3. Enable transparent background and square output in the image generator. Ask for one image only.
4. Use the reference for the icon's subject, silhouette, and established colors. Follow the JSON for its new finish, framing, camera, and lighting.
5. Save the result over the matching PNG in `RelayAirMobile/Assets.xcassets/<asset_id>.imageset/`.

Keep the shared style and asset catalog fixed between generations. The selected asset record is the only part that changes which icon is rendered. The JSON intentionally excludes renderer-specific controls that an image generator cannot reliably enforce; it locks the visible art direction instead.

The catalog covers `RelayTypeCreditCard`, `RelayTypePassport`, `RelayTypeAddress`, `RelayTypeCustom`, `SavedItemActionDelete`, `SavedItemActionRelay`, `SavedItemActionEdit`, `AppearanceSystem`, `AppearanceLight`, `AppearanceDark`, and `ScannerRelatedDocuments`.
