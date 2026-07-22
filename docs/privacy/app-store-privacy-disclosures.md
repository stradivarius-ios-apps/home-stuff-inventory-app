# App Store Privacy Disclosure Notes

Status: Active current-state submission gate

These notes capture the current implemented app behavior. Recheck them before each TestFlight or App Store submission if data flows, dependencies, entitlements, capabilities, or privacy-facing features change.

## Current data flows

- Item, Inventory, Location, Storage Place, Category, Quantity, Notes, tags, list-management values, settings screens, search state, and recent item view events are stored locally through SwiftData.
- Recent item view events contain local item identifiers and view timestamps for on-device ranking only. They are not transmitted off device.
- Readable export and complete backup are plaintext JSON files. Home Stuff does not encrypt or password-protect either file; before it creates one, it explains this boundary and the data each file can contain. After a user saves or shares a file, protection and retention depend on the selected Files location, cloud provider, application, or recipient.
- Compatible restore is a user-initiated local file workflow and does not create or transmit a new export file. The app does not upload restore contents to the developer or a backend.
- DEBUG sample data is compiled behind `#if DEBUG`; Release builds do not compile the sample-data launch argument or environment flag gate.

## Current App Store Connect answers

- Data Collection: No user data collected by the developer or third-party partners for the current app version.
- Tracking: No tracking.
- Data Linked to the User: None collected off device.
- Data Not Linked to the User: None collected off device.
- App Encryption Documentation: None of the algorithms mentioned above. The app target declares `ITSAppUsesNonExemptEncryption = false` in the generated app `Info.plist`.

## Verified absence for the current release

- No account system, backend service, analytics SDK, advertising SDK, tracking SDK, CloudKit/iCloud sync, arbitrary import, app-managed sharing service, barcode scanning, AI, Photos, Camera, Contacts, Location Services, or network-based feature is present in the Release app target. Readable export and complete backup/restore remain local user-initiated file workflows.
- No app entitlements file or sensitive capability is configured.
- No third-party package manager dependency is present in the project.
- No current app target usage was found for custom/proprietary encryption, app-level standard encryption algorithms, CryptoKit, CommonCrypto, SecKey, CCCrypt, custom AES/RSA/ECC implementation, secure messaging, VPN/tunneling, or third-party cryptography libraries.
- The Release-target Required Reason API audit found only `volumeAvailableCapacityForImportantUsageKey`, used immediately before restore staging to detect whether the app can write the safety and candidate files. Low capacity produces an observable low-storage restore failure, and the capacity value is not sent off device.
- `PrivacyInfo.xcprivacy` declares only `NSPrivacyAccessedAPICategoryDiskSpace` with Apple-approved reason `E174.1`. The audit found no Release-target use of the File Timestamp, System Boot Time, User Defaults, or Active Keyboards categories and no third-party dependencies.

## Recheck before submission

- Re-run a source scan for networking, SDKs, entitlements, sensitive Apple frameworks, and required-reason API use.
- Re-run a source scan for custom encryption, CryptoKit/CommonCrypto/SecKey usage, secure messaging, VPN/tunneling, and cryptography dependencies before relying on the export compliance declaration.
- Confirm `HomeStuffInventoryApp/Resources/PrivacyInfo.xcprivacy` remains in the app target resources and appears in the built Release `.app` bundle.
- Parse the bundled manifest and confirm exactly one Disk Space entry with exactly reason `E174.1`, empty collected-data/tracking-domain arrays, and tracking set to false.
- Reconcile any new Required Reason API source use with the final privacy manifest and archive report.
- Update App Store Connect privacy answers if any data is transmitted off device, any third-party code is added, or any sensitive capability is introduced.
- Update App Store Connect export compliance answers and remove or change `ITSAppUsesNonExemptEncryption = false` if non-exempt app-level encryption is added.
