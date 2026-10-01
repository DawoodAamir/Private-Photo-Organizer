# Privacy

Photos and metadata stay in the app's local Application Support directory. There is no analytics, account, server, cloud synchronization, or app network entitlement.

The system photo picker shares only selected items. File import grants read access to selected files. Originals are copied unchanged and may retain location or other embedded metadata; the app's reduced JPEG previews omit that metadata. Analysis uses these previews locally through Vision and the bundled Core AI model. Tag suggestions are not saved until approved.

Archiving hides a photo from the active library; it does not delete its original. This version provides no permanent-delete command. Back up the app's local data before removing the app or its container. Local storage is not a separate encrypted vault and follows the device's normal storage protections and backup settings.

The privacy manifest declares no tracking or collected data. Review it again before adding telemetry, external services, or additional required-reason APIs.
