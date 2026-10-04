//
//  PGLCloudImportTests.swift
//  RiftEffectsTests
//
//  Compare the Core Data + CloudKit import between two devices.
//
//  A test run only executes on one device, so the comparison works through
//  snapshot files. Each run writes this device's snapshot to
//      Documents/CloudImportSnapshots/<PGLCurrentDeviceID>.json
//  in the app container. Copy the other device's snapshot into the same folder
//  (xcrun devicectl device copy from / copy to, domain appDataContainer,
//  identifier L-BSoftwareArtist.Rift-Effex) and rerun to compare.
//
//  Reports are also written to Documents/CloudImportSnapshots/Reports/ and
//  attached to the test results.
//

import Testing
import UIKit
import Photos
import CoreData
import CloudKit
import os

@testable import RiftEffects

// MARK: Snapshot model

/// One device's view of the CDFilterStack rows its Library controller shows.
struct CloudImportSnapshot: Codable {
    let deviceID: String        // PGLCurrentDeviceID - matches CDImageList.machineName
    let deviceName: String
    let deviceModel: String     // hardware identifier e.g. iPhone15,2
    let controllerName: String  // PGLLibraryController (iPhone) or PGLOpenStackController (iPad)
    let showChildStack: Bool    // changes the controller fetch predicate
    let capturedAt: Date
    let importStatus: String
    let stacks: [StackRow]
    let deviceLocalImageLists: [DeviceLocalImageList]
}

struct StackRow: Codable, Equatable {
    let key: String
    let title: String?
    let type: String?
    let created: Date?
    let modified: Date?
    let isChildStack: Bool
    let exportAlbumName: String?
    let globalSizeWidth: Double
    let globalSizeHeight: Double
    let thumbnailBytes: Int
    let filters: [FilterRow]
}

struct FilterRow: Codable, Equatable {
    let stackPosition: Int
    let ciFilterName: String?
    let pglSourceFilterClass: String?
    let valueNames: [String]
    let imageParms: [ImageParmRow]
}

struct ImageParmRow: Codable, Equatable {
    let parmName: String?
    let hasInputAssets: Bool
    let assetIDs: [String]
    let albumIds: [String]
    let machineName: String?
    let hasImageData: Bool
    let childStack: [StackRow]  // zero or one element - an array keeps the struct recursive
}

/// A CDImageList that still holds device-local identifiers (iCloud conversion failed).
struct DeviceLocalImageList: Codable {
    let stackPath: String
    let parmName: String?
    let machineName: String
    let assetCount: Int
}

// MARK: Tests

@MainActor
@Suite(.serialized) struct PGLCloudImportTests {

    static let bundleIdentifier = "L-BSoftwareArtist.Rift-Effex"
    static let logger = Logger(subsystem: TestLogSubsystem, category: "CloudImportTests")

    /// image size requested to prove an asset loads - small to keep the run light
    static let probeImageSize = CGSize(width: 300, height: 300)

    let persistentContainer: NSPersistentContainer

    init() throws {
        let appDelegate = try #require(UIApplication.shared.delegate as? AppDelegate)
        persistentContainer = appDelegate.dataWrapper.persistentContainer
    }

    // MARK: Test 1 - device rows match

    /// Snapshot every CDFilterStack row of the Library controller dataProvider on this
    /// device and compare it to the snapshots saved by the other devices.
    @Test(.timeLimit(.minutes(5)))
    func stackRowsMatchBetweenDevices() async throws {
        let importStatus = await waitForCloudKitImport(timeout: .seconds(30))
        let provider = libraryDataProvider()
        let snapshot = makeSnapshot(provider: provider, importStatus: importStatus)
        let snapshotURL = try write(snapshot: snapshot)

        Self.logger.notice("\(snapshot.controllerName, privacy: .public) on \(snapshot.deviceName, privacy: .public) holds \(snapshot.stacks.count, privacy: .public) CDFilterStack rows. \(importStatus, privacy: .public). Snapshot \(snapshotURL.path, privacy: .public)")
        Attachment.record(String(decoding: try Data(contentsOf: snapshotURL), as: UTF8.self), named: snapshotURL.lastPathComponent)

        let otherSnapshots = try readSnapshots().filter({ $0.deviceID != snapshot.deviceID })
        guard !otherSnapshots.isEmpty else {
            Issue.record("""
                No snapshot from another device in \(snapshotURL.deletingLastPathComponent().path).
                This device's snapshot was written. Run this test on the other device, copy its \
                snapshot here with 'xcrun devicectl device copy', then rerun to compare.
                """)
            return
        }

        var report = [String]()
        for otherSnapshot in otherSnapshots {
            let differences = compare(snapshot, otherSnapshot)
            report.append("== \(snapshot.deviceName) (\(snapshot.controllerName), \(snapshot.stacks.count) rows) vs \(otherSnapshot.deviceName) (\(otherSnapshot.controllerName), \(otherSnapshot.stacks.count) rows, captured \(otherSnapshot.capturedAt)) ==")
            report.append(contentsOf: differences.isEmpty ? ["no differences"] : differences)
            let differenceCount = differences.filter({ !$0.hasPrefix("NOTE") }).count
            #expect(differenceCount == 0, "\(differenceCount) differences between \(snapshot.deviceName) and \(otherSnapshot.deviceName). See the stack row comparison report.")
        }
        try publish(report: report, named: "StackRowComparison")
    }

    // MARK: Test 2 - images load from the Photo Library

    /// For every image parm of every stack, resolve the stored identifiers the way
    /// PGLFilterAttributeImage #loadInputAssets does, fetch the PHAssets and request
    /// each image through PGLCachedImageMgr. Reports every asset that does not load.
    @Test(.timeLimit(.minutes(30)))
    func stackImagesLoadFromPhotoLibrary() async throws {
        let authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        try #require(authorization == .authorized || authorization == .limited, "Photo Library access is \(authorization.rawValue) - grant access to Rift-Effex on \(Self.deviceName()) first")

        let provider = libraryDataProvider()
        let stacks = provider.fetchedResultsController.fetchedObjects ?? [CDFilterStack]()
        let photoMgr = PGLCachedImageMgr()
        var loadedResults = [String: String?]()  // localIdentifier : error text, nil when it loaded
        var failures = [String]()
        var checkedAssetCount = 0

        if authorization == .limited {
            failures.append("NOTE Photo Library access is limited - assets outside 'Selected Photos' report as not found")
        }

        for aStack in stacks {
            for (path, cdParmImage) in imageParms(in: aStack, path: stackLabel(aStack)) {
                guard let imageList = cdParmImage.inputAssets else { continue }
                let parmLabel = "\(path) parm \(cdParmImage.parmName ?? "nil")"

                let resolved = resolveLocalIdentifiers(imageList: imageList)
                failures.append(contentsOf: resolved.problems.map({ "\(parmLabel): \($0)" }))

                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: resolved.localIds, options: nil)
                var phAssets = [PHAsset]()
                fetchResult.enumerateObjects { asset, _, _ in phAssets.append(asset) }
                let foundIds = Set(phAssets.map({ $0.localIdentifier }))
                for missingId in resolved.localIds where !foundIds.contains(missingId) {
                    failures.append("\(parmLabel): local id \(missingId) is not in the Photo Library")
                }

                let pglAssets = phAssets
                    .filter({ loadedResults[$0.localIdentifier] == nil })
                    .map({ PGLAsset($0, collectionId: nil, collectionLocalTitle: nil) })
                await photoMgr.startCaching(for: pglAssets, targetSize: Self.probeImageSize)
                for aPGLAsset in pglAssets {
                    switch await photoMgr.requestImageResult(for: aPGLAsset, targetSize: Self.probeImageSize) {
                        case .success:
                            loadedResults[aPGLAsset.localIdentifier] = .some(nil)
                        case .failure(let cacheError):
                            loadedResults[aPGLAsset.localIdentifier] = .some(describe(cacheError))
                    }
                }
                await photoMgr.stopCaching(for: pglAssets, targetSize: Self.probeImageSize)

                for anAsset in phAssets {
                    checkedAssetCount += 1
                    if let errorText = loadedResults[anAsset.localIdentifier] ?? nil {
                        failures.append("\(parmLabel): PGLCachedImageMgr failed for \(anAsset.localIdentifier) - \(errorText)")
                    }
                }
            }
            aStack.managedObjectContext?.refresh(aStack, mergeChanges: false)
                // fault the stack so its parm graph does not accumulate over the run
        }
        await photoMgr.stopCaching()

        let problemCount = failures.filter({ !$0.hasPrefix("NOTE") }).count
        let report = ["\(Self.deviceName()): \(stacks.count) stacks, \(checkedAssetCount) asset references, \(loadedResults.count) unique assets requested, \(problemCount) problems"] + failures
        try publish(report: report, named: "ImageLoad")
        #expect(problemCount == 0, "\(problemCount) images will not load on \(Self.deviceName()). See the image load report.")
    }

    // MARK: Test 3 - failed iCloud identifier conversion

    /// Any CDImageList with a machineName stores device-local asset identifiers -
    /// the conversion to PHCloudIdentifier failed when it was saved. Report the stack
    /// and the device that wrote it.
    @Test func noDeviceLocalAssetIdentifiers() throws {
        let localLists = deviceLocalImageLists()
        let knownDevices = Dictionary((try? readSnapshots())?.map({ ($0.deviceID, $0.deviceName) }) ?? [], uniquingKeysWith: { first, _ in first })

        var report = ["\(Self.deviceName()) (deviceID \(PGLCurrentDeviceID)): \(localLists.count) CDImageList rows with a machineName"]
        for aList in localLists {
            let writer: String
            if aList.machineName == PGLCurrentDeviceID {
                writer = "this device \(Self.deviceName()) - the ids load here only"
            } else if let otherName = knownDevices[aList.machineName] {
                writer = "\(otherName) - the ids do not load on this device"
            } else {
                writer = "unknown device \(aList.machineName) - the ids do not load on this device"
            }
            report.append("\(aList.stackPath) parm \(aList.parmName ?? "nil"): \(aList.assetCount) device-local assetIDs written by \(writer)")
        }
        try publish(report: report, named: "DeviceLocalAssetIds")
        #expect(localLists.isEmpty, "\(localLists.count) image lists failed the iCloud identifier conversion. See the device local asset ids report.")
    }

    // MARK: Diagnose - stacks on one device only

    /// For each stack this device holds that another device's snapshot does not, ask
    /// whether it was ever exported (mirroring metadata has a CKRecord.ID) and whether
    /// that record is on the CloudKit server. Also reports the CloudKit event history.
    ///   - not exported          -> this device's export is stuck
    ///   - on the server         -> the other device's import is stuck
    ///   - exported, not on server -> deleted from the server (zone reset / delete)
    @Test(.timeLimit(.minutes(5)))
    func diagnoseStacksOnOneDevice() async throws {
        _ = try #require(persistentContainer as? NSPersistentCloudKitContainer)
        let reportName = "OneDeviceDiagnosis"
        var report = ["started \(Date())"]
        try writeProgress(report, named: reportName)
            // progress is written after every step so a hang still leaves a report on the device

        report.append(contentsOf: cloudKitEventHistory(days: 60))
        try writeProgress(report, named: reportName)

        let provider = libraryDataProvider()
        let localStacks = provider.fetchedResultsController.fetchedObjects ?? [CDFilterStack]()
        let localByKey = Dictionary(grouping: localStacks, by: { Self.rowKey(type: $0.type, title: $0.title, created: Self.wholeSeconds($0.created)) })

        let otherSnapshots = try readSnapshots().filter({ $0.deviceID != PGLCurrentDeviceID })
        try #require(!otherSnapshots.isEmpty, "Needs another device's snapshot - see stackRowsMatchBetweenDevices")

        // Read the CDFilterStack records on the server directly. recordID(for:) goes
        // through the mirroring delegate and hangs while its export is stuck.
        report.append("scanning the CloudKit zone")
        try writeProgress(report, named: reportName)
        let serverStacks: [String: [String]]  // rowKey : recordNames
        do {
            serverStacks = try await scanServerStacks(report: &report)
        } catch {
            report.append("CloudKit zone scan failed: \(error.localizedDescription)")
            try publish(report: report, named: reportName)
            Issue.record("CloudKit zone scan failed: \(error)")
            return
        }
        try writeProgress(report, named: reportName)

        for otherSnapshot in otherSnapshots {
            let otherKeys = Set(otherSnapshot.stacks.map({ $0.key }))

            let onlyHere = localByKey.keys.filter({ !otherKeys.contains($0) }).sorted()
            report.append("== \(onlyHere.count) stacks on \(Self.deviceName()) and not on \(otherSnapshot.deviceName) ==")
            for aKey in onlyHere {
                if let recordNames = serverStacks[aKey] {
                    report.append("\(aKey): ON SERVER (\(recordNames.joined(separator: ", "))) - \(otherSnapshot.deviceName) has not imported it")
                } else {
                    report.append("\(aKey): NOT ON SERVER - \(Self.deviceName()) has not exported it")
                }
            }

            let onlyThere = otherKeys.filter({ localByKey[$0] == nil }).sorted()
            report.append("== \(onlyThere.count) stacks on \(otherSnapshot.deviceName) and not on \(Self.deviceName()) ==")
            for aKey in onlyThere {
                if let recordNames = serverStacks[aKey] {
                    report.append("\(aKey): ON SERVER (\(recordNames.joined(separator: ", "))) - \(Self.deviceName()) has not imported it")
                } else {
                    report.append("\(aKey): NOT ON SERVER - \(otherSnapshot.deviceName) has not exported it")
                }
            }
        }
        try publish(report: report, named: reportName)
    }

    /// Every CDFilterStack record in the Core Data CloudKit zone on the server, keyed by
    /// rowKey. Read only - fetches title / type / created, never the thumbnail assets.
    /// Also reports the record count by type.
    func scanServerStacks(report: inout [String]) async throws -> [String: [String]] {
        let database = CKContainer(identifier: iCloudDataContainerName).privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
        let configuration = CKOperation.Configuration()
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120

        var stacks = [String: [String]]()
        var countsByType = [String: Int]()
        var failedRecords = 0
        var changeToken: CKServerChangeToken?
        var moreComing = true
        while moreComing {
            let token = changeToken
            let page = try await database.configuredWith(configuration: configuration) { configuredDatabase in
                try await configuredDatabase.recordZoneChanges(inZoneWith: zoneID, since: token, desiredKeys: ["CD_title", "CD_type", "CD_created"], resultsLimit: 400)
            }
            for (_, aResult) in page.modificationResultsByID {
                guard case .success(let modification) = aResult else {
                    failedRecords += 1
                    continue
                }
                let aRecord = modification.record
                countsByType[aRecord.recordType, default: 0] += 1
                guard aRecord.recordType == "CD_CDFilterStack" else { continue }
                let key = Self.rowKey(type: aRecord["CD_type"] as? String, title: aRecord["CD_title"] as? String, created: Self.wholeSeconds(aRecord["CD_created"] as? Date))
                stacks[key, default: [String]()].append(aRecord.recordID.recordName)
            }
            changeToken = page.changeToken
            moreComing = page.moreComing
        }
        report.append("== CloudKit zone \(zoneID.zoneName) ==")
        for (aType, aCount) in countsByType.sorted(by: { $0.key < $1.key }) {
            report.append("\(aType): \(aCount) records")
        }
        if failedRecords > 0 {
            report.append("\(failedRecords) records failed to fetch")
        }
        let duplicated = stacks.filter({ $0.value.count > 1 })
        report.append("\(stacks.count) distinct stack keys on the server, \(duplicated.count) keys with more than one record")
        return stacks
    }

    /// Summary of the stored NSPersistentCloudKitContainer events plus every failure.
    func cloudKitEventHistory(days: Int) -> [String] {
        let since = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)
        let context = persistentContainer.newBackgroundContext()
        // build the request inside the block - NSPersistentCloudKitContainerEventRequest is not Sendable
        return context.performAndWait { () -> [String] in
            var lines = [String]()
            let request = NSPersistentCloudKitContainerEventRequest.fetchEvents(after: since)
            do {
                let result = try context.execute(request) as? NSPersistentCloudKitContainerEventResult
                let events = (result?.result as? [NSPersistentCloudKitContainer.Event]) ?? [NSPersistentCloudKitContainer.Event]()
                let typeNames: [NSPersistentCloudKitContainer.EventType: String] = [.setup: "setup", .import: "import", .export: "export"]
                lines.append("== CloudKit events since \(since): \(events.count) ==")
                for aType in [NSPersistentCloudKitContainer.EventType.setup, .import, .export] {
                    let ofType = events.filter({ $0.type == aType })
                    let lastGood = ofType.filter({ $0.succeeded && $0.endDate != nil }).compactMap({ $0.endDate }).max()
                    let failed = ofType.filter({ $0.endDate != nil && !$0.succeeded })
                    lines.append("\(typeNames[aType] ?? "?"): \(ofType.count) events, \(failed.count) failed, last success \(String(describing: lastGood))")
                }
                for anEvent in events where anEvent.endDate != nil && !anEvent.succeeded {
                    let error = anEvent.error as NSError?
                    lines.append("FAILED \(typeNames[anEvent.type] ?? "?") \(anEvent.startDate) - \(error?.localizedDescription ?? "no error") (\(error?.domain ?? "") \(error?.code ?? 0))")
                    if let partialErrors = error?.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: NSError] {
                        for (recordID, itemError) in partialErrors.prefix(10) {
                            lines.append("    record \(recordID.recordName): \(itemError.localizedDescription)")
                        }
                    }
                }
                let unfinished = events.filter({ $0.endDate == nil })
                if !unfinished.isEmpty {
                    lines.append("\(unfinished.count) events never finished, oldest started \(String(describing: unfinished.map({ $0.startDate }).min()))")
                }
            } catch {
                lines.append("CloudKit event history fetch failed: \(error.localizedDescription)")
            }
            return lines
        }
    }

    // MARK: Observe sync

    /// Record the live CloudKit mirroring events for up to 10 minutes - stops early once an
    /// export succeeds. Read only. Progress is written every 15 seconds.
    @Test(.timeLimit(.minutes(12)))
    func observeCloudKitSync() async throws {
        let reportName = "SyncObservation"
        let header = ["observing CloudKit events on \(Self.deviceName()) from \(Date())"]
        let recorder = CloudKitEventRecorder(container: persistentContainer)
        defer { recorder.stop() }

        let deadline = ContinuousClock.now + .seconds(600)
        var writtenCount = -1
        while ContinuousClock.now < deadline && !recorder.exportSucceeded {
            try await Task.sleep(for: .seconds(15))
            if recorder.lines.count != writtenCount {
                writtenCount = recorder.lines.count
                try writeProgress(header + recorder.lines, named: reportName)
            }
        }
        let summary = recorder.exportSucceeded ? "an export SUCCEEDED - observation stopped" : "no export succeeded in 10 minutes"
        try publish(report: header + recorder.lines + ["\(Date()) \(summary), \(recorder.lines.count) event notifications"], named: reportName)
    }

    // MARK: Orphan legacy filter delete

    nonisolated static var orphanDeleteMarker: URL? {
        try? snapshotFolder().appendingPathComponent("RUN_ORPHAN_DELETE")
    }

    nonisolated static var orphanDeleteEnabled: Bool {
        guard let marker = orphanDeleteMarker else { return false }
        return FileManager.default.fileExists(atPath: marker.path)
    }

    /// Report what #deleteOrphanLegacyFilters would delete - never saves.
    @Test func orphanLegacyFilterDeleteDryRun() throws {
        try publish(report: deleteOrphanLegacyFilters(commit: false), named: "OrphanDeleteDryRun")
    }

    /// Delete the legacy filters that belong to no stack. Enabled only by the
    /// RUN_ORPHAN_DELETE marker in Documents/CloudImportSnapshots, removed by the run.
    @Test(.enabled(if: PGLCloudImportTests.orphanDeleteEnabled, "push RUN_ORPHAN_DELETE to Documents/CloudImportSnapshots to enable"))
    func orphanLegacyFilterDelete() throws {
        if let marker = Self.orphanDeleteMarker {
            try? FileManager.default.removeItem(at: marker)
                // one run per marker
        }
        let report = deleteOrphanLegacyFilters(commit: true)
        try publish(report: report, named: "OrphanDelete")
        #expect(!report.contains(where: { $0.hasPrefix("SAVE FAILED") }))
    }

    /// CDStoredFilter rows with an archived ciFilter (the format before CDParmValue) and no
    /// stack. No stack, library or child stack reaches them, so the app never loads them,
    /// but they still sync - 89 MB of archive on 2026-10-04.
    /// Deleted through the context, not NSBatchDeleteRequest, so the Cascade rules remove
    /// their CDParmImage and CDImageList rows and the mirroring delegate exports the deletes.
    /// A filter whose parm holds a child stack is skipped - the cascade would delete it.
    func deleteOrphanLegacyFilters(commit: Bool) -> [String] {
        let viewContext = persistentContainer.viewContext
        var report = ["\(commit ? "DELETE" : "DRY RUN") orphan legacy filters on \(Self.deviceName()) started \(Date())"]

        let request: NSFetchRequest<CDStoredFilter> = CDStoredFilter.fetchRequest()
        request.predicate = NSPredicate(format: "stack == nil AND ciFilter != nil")
        request.propertiesToFetch = ["ciFilterName", "stackPosition"]
        let orphans = (try? viewContext.fetch(request)) ?? [CDStoredFilter]()

        var deleted = 0
        var skipped = 0
        var parmImageCount = 0
        var imageListCount = 0
        for anOrphan in orphans {
            let parms = (anOrphan.input as? Set<CDParmImage>) ?? Set<CDParmImage>()
            let label = "\(anOrphan.ciFilterName ?? "nil") position \(anOrphan.stackPosition) - \(parms.count) parm images"
            guard anOrphan.stack == nil else {
                report.append("SKIP \(label): now belongs to a stack")
                skipped += 1
                continue
            }
            if parms.contains(where: { $0.inputStack != nil }) {
                report.append("SKIP \(label): a parm holds a child stack")
                skipped += 1
                continue
            }
            parmImageCount += parms.count
            imageListCount += parms.filter({ $0.inputAssets != nil }).count
            report.append("\(commit ? "DELETE" : "WOULD DELETE") \(label)")
            if commit {
                viewContext.delete(anOrphan)  // Cascade deletes the parm images and their image lists
            }
            deleted += 1
        }

        if commit && viewContext.hasChanges {
            do {
                try viewContext.save()
                report.append("store saved")
            } catch {
                report.append("SAVE FAILED: \(error.localizedDescription)")
                viewContext.rollback()
            }
        }
        report.insert("\(orphans.count) orphan legacy filters, \(deleted) \(commit ? "deleted" : "would delete") with \(parmImageCount) parm images and \(imageListCount) image lists, \(skipped) skipped", at: 1)
        return report
    }

    // MARK: Stackless filter delete

    nonisolated static var stacklessDeleteMarker: URL? {
        try? snapshotFolder().appendingPathComponent("RUN_STACKLESS_DELETE")
    }

    nonisolated static var stacklessDeleteEnabled: Bool {
        guard let marker = stacklessDeleteMarker else { return false }
        return FileManager.default.fileExists(atPath: marker.path)
    }

    /// Report what #deleteStacklessFilters would delete - never saves.
    @Test func stacklessFilterDeleteDryRun() throws {
        try publish(report: deleteStacklessFilters(commit: false), named: "StacklessDeleteDryRun")
    }

    /// Delete every CDStoredFilter with no stack and everything only it reaches. Enabled
    /// only by the RUN_STACKLESS_DELETE marker in Documents/CloudImportSnapshots, removed by the run.
    @Test(.enabled(if: PGLCloudImportTests.stacklessDeleteEnabled, "push RUN_STACKLESS_DELETE to Documents/CloudImportSnapshots to enable"))
    func stacklessFilterDelete() throws {
        if let marker = Self.stacklessDeleteMarker {
            try? FileManager.default.removeItem(at: marker)
                // one run per marker
        }
        let report = deleteStacklessFilters(commit: true)
        try publish(report: report, named: "StacklessDelete")
        #expect(!report.contains(where: { $0.hasPrefix("SAVE FAILED") || $0.hasPrefix("ABORT") }))
    }

    /// CDStoredFilter rows with no stack - left behind when a filter is removed from a saved
    /// stack (#writeCDStack #removeFromFilters nils the relationship, it does not delete the row).
    /// Walks each one: its CDParmValue rows (values is a Nullify relationship, so they are
    /// deleted explicitly), its CDParmImage rows, their CDImageList and CDImageData, and any
    /// child stack on a parm with that stack's filters, recursively.
    /// ABORTS without deleting anything if the walk reaches a stack that is not the child of
    /// the parm it was reached from - that stack could be in the Library.
    func deleteStacklessFilters(commit: Bool) -> [String] {
        let viewContext = persistentContainer.viewContext
        var report = ["\(commit ? "DELETE" : "DRY RUN") stackless filters on \(Self.deviceName()) started \(Date())"]

        let request: NSFetchRequest<CDStoredFilter> = CDStoredFilter.fetchRequest()
        request.predicate = NSPredicate(format: "stack == nil")
        let stackless = (try? viewContext.fetch(request)) ?? [CDStoredFilter]()

        var rows = [String: [NSManagedObject]]()  // kind : rows to delete
        var visited = Set<NSManagedObjectID>()
        var unsafe = [String]()

        func add(_ row: NSManagedObject, kind: String) -> Bool {
            guard visited.insert(row.objectID).inserted else { return false }
            rows[kind, default: [NSManagedObject]()].append(row)
            return true
        }
        func walk(filter: CDStoredFilter) {
            guard add(filter, kind: "filters") else { return }
            for aValue in (filter.values as? Set<CDParmValue>) ?? Set<CDParmValue>() {
                _ = add(aValue, kind: "parmValues")
            }
            for aParm in (filter.input as? Set<CDParmImage>) ?? Set<CDParmImage>() {
                guard add(aParm, kind: "parmImages") else { continue }
                if let imageList = aParm.inputAssets { _ = add(imageList, kind: "imageLists") }
                if let imageData = aParm.parmImageData { _ = add(imageData, kind: "imageData") }
                if let childStack = aParm.inputStack {
                    guard childStack.outputToParm?.objectID == aParm.objectID else {
                        unsafe.append("'\(childStack.type ?? "nil") / \(childStack.title ?? "nil")' is not the child of the parm that reaches it")
                        continue
                    }
                    guard add(childStack, kind: "childStacks") else { continue }
                    report.append("  child stack '\(childStack.type ?? "nil") / \(childStack.title ?? "nil")' - \(childStack.filters?.count ?? 0) filters")
                    for aChildFilter in (childStack.filters as? Set<CDStoredFilter>) ?? Set<CDStoredFilter>() {
                        walk(filter: aChildFilter)
                    }
                }
            }
        }
        for aFilter in stackless {
            walk(filter: aFilter)
        }

        let kinds = ["filters", "childStacks", "parmImages", "imageLists", "imageData", "parmValues"]
        let counts = kinds.map({ "\(rows[$0]?.count ?? 0) \($0)" }).joined(separator: ", ")
        report.insert("\(stackless.count) stackless filters reach \(counts)", at: 1)

        guard unsafe.isEmpty else {
            report.append("ABORT - nothing deleted:")
            report.append(contentsOf: unsafe.map({ "  \($0)" }))
            return report
        }
        guard commit else { return report }

        for aKind in kinds {
            for aRow in rows[aKind] ?? [NSManagedObject]() where !aRow.isDeleted {
                viewContext.delete(aRow)
            }
        }
        do {
            try viewContext.save()
            report.append("store saved")
        } catch {
            report.append("SAVE FAILED: \(error.localizedDescription)")
            viewContext.rollback()
        }
        return report
    }

    // MARK: Legacy archived CIFilter migration

    /// Marker file that enables the committing migration test. Pushed to the device with
    /// devicectl right before the run and removed by the test, so a full test run never
    /// rewrites the store by accident.
    nonisolated static var legacyMigrationMarker: URL? {
        try? snapshotFolder().appendingPathComponent("RUN_LEGACY_MIGRATION")
    }

    nonisolated static var legacyMigrationEnabled: Bool {
        guard let marker = legacyMigrationMarker else { return false }
        return FileManager.default.fileExists(atPath: marker.path)
    }

    /// Report what the legacy CIFilter migration would do - never saves.
    @Test(.timeLimit(.minutes(20)))
    func legacyCIFilterMigrationDryRun() throws {
        let report = migrateLegacyCIFilters(commit: false)
        try publish(report: report, named: "LegacyCIFilterDryRun")
    }

    /// Move the settings of every legacy filter (archived CIFilter, the format before the
    /// CDParmValue table) into CDParmValue rows and clear the archive. Only filters whose
    /// reload matches the archived values are saved. See #migrateLegacyCIFilters.
    @Test(.enabled(if: PGLCloudImportTests.legacyMigrationEnabled, "push RUN_LEGACY_MIGRATION to Documents/CloudImportSnapshots to enable"),
          .timeLimit(.minutes(20)))
    func legacyCIFilterMigration() throws {
        if let marker = Self.legacyMigrationMarker {
            try? FileManager.default.removeItem(at: marker)
                // one run per marker
        }
        let report = migrateLegacyCIFilters(commit: true)
        try publish(report: report, named: "LegacyCIFilterMigration")
        #expect(!report.contains(where: { $0.hasPrefix("SAVE FAILED") }))
    }

    /// For each CDStoredFilter that belongs to a stack and still holds an archived ciFilter:
    ///  1. load it as the app does (#readPGLFilter uses the archive as localFilter)
    ///  2. point the attributes at that archive - #readPGLFilter leaves them on the
    ///     builder's default filter, so a plain resave would store default values
    ///  3. store the parm values and nil the archive
    ///  4. reload the filter as the app does with no archive and compare every non image
    ///     input against the archive
    /// Each filter runs in its own scratch child context of the viewContext. Only a filter
    /// that matches is pushed to the viewContext; a mismatch is reported and discarded.
    /// Image parms and image lists are not written - #writeCDStack is deliberately not used
    /// since it reconverts asset ids and would drop unresolved photos.
    /// Orphan filters (no stack) are not touched.
    func migrateLegacyCIFilters(commit: Bool) -> [String] {
        let viewContext = persistentContainer.viewContext
        var report = ["\(commit ? "MIGRATION" : "DRY RUN") on \(Self.deviceName()) started \(Date())"]

        let idRequest = NSFetchRequest<NSManagedObjectID>(entityName: "CDStoredFilter")
        idRequest.resultType = .managedObjectIDResultType
        idRequest.predicate = NSPredicate(format: "ciFilter != nil AND stack != nil")
        let legacyIDs = (try? viewContext.fetch(idRequest)) ?? [NSManagedObjectID]()
        report.append("\(legacyIDs.count) legacy filters in stacks")

        var migrated = 0
        var skipped = 0
        for aFilterID in legacyIDs {
            let scratch = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            scratch.parent = viewContext
            scratch.undoManager = nil
            guard let cdFilter = try? scratch.existingObject(with: aFilterID) as? CDStoredFilter,
                  let cdStack = cdFilter.stack,
                  let archived = cdFilter.ciFilter
            else {
                report.append("SKIP \(aFilterID.uriRepresentation().lastPathComponent): not readable")
                skipped += 1
                continue
            }
            let label = "'\(cdStack.type ?? "nil") / \(cdStack.title ?? "nil")' filter \(cdFilter.stackPosition) \(cdFilter.ciFilterName ?? "nil")"
            let savedSize: CGSize? = (cdStack.globalSizeWidth > 0 && cdStack.globalSizeHeight > 0)
                ? CGSize(width: cdStack.globalSizeWidth, height: cdStack.globalSizeHeight) : nil
                // the same savedSize #on(cdStack:) passes
            let expected = Self.comparableInputs(archived)

            guard let legacySource = PGLSourceFilter.readPGLFilter(myCDFilter: cdFilter, savedSize: savedSize) else {
                report.append("SKIP \(label): does not load (excluded or unknown filter) - left unchanged")
                skipped += 1
                continue
            }
            legacySource.resetAttributesToLocalFilter()
            let animationKeys = Self.applyArchivedValues(archived, to: legacySource)
            legacySource.storeParmValue(moContext: scratch)
            Self.storeVectorsForLoad(of: legacySource, savedSize: savedSize)
            cdFilter.ciFilter = nil

            guard let reloaded = PGLSourceFilter.readPGLFilter(myCDFilter: cdFilter, savedSize: savedSize) else {
                report.append("SKIP \(label): does not reload - left unchanged")
                scratch.rollback()
                skipped += 1
                continue
            }
            let actual = Self.comparableInputs(reloaded.localFilter)
            let mismatches = Self.inputMismatches(expected: expected.filter({ !animationKeys.contains($0.key) }), actual: actual)
            let animationResets = Self.inputMismatches(expected: expected.filter({ animationKeys.contains($0.key) }), actual: actual)
            legacySource.releaseVars()
            reloaded.releaseVars()

            guard mismatches.isEmpty else {
                report.append("SKIP \(label): reload differs - left unchanged")
                report.append(contentsOf: mismatches.map({ "    \($0)" }))
                scratch.rollback()
                skipped += 1
                continue
            }

            let comparedCount = expected.filter({ !animationKeys.contains($0.key) }).filter({ if case .notCompared = $0.value { return false } else { return true } }).count
            let animationNote = animationResets.isEmpty ? "" : " - animation position reset: \(animationResets.joined(separator: "; "))"
            if commit {
                do {
                    try scratch.save()  // pushes to the viewContext only
                    report.append("MIGRATED \(label): \(comparedCount) inputs verified\(animationNote)")
                    migrated += 1
                } catch {
                    report.append("SAVE FAILED \(label): \(error.localizedDescription)")
                    scratch.rollback()
                    skipped += 1
                }
            } else {
                report.append("WOULD MIGRATE \(label): \(comparedCount) inputs verified\(animationNote)")
                migrated += 1
                scratch.rollback()
            }
            scratch.reset()
        }

        if commit && viewContext.hasChanges {
            do {
                try viewContext.save()
                report.append("store saved")
            } catch {
                report.append("SAVE FAILED viewContext: \(error.localizedDescription)")
                viewContext.rollback()
            }
        }
        report.insert("\(migrated) \(commit ? "migrated" : "would migrate"), \(skipped) skipped", at: 1)
        return report
    }

    /// Push each archived input value through the attribute's own setter so attribute
    /// state outside the CIFilter (canvasVector, filterRect) matches the archive.
    /// #resetAttributesToLocalFilter alone is not enough - #storeParmValue writes that state.
    /// Answers the keys of animation time attributes: their archived value is the transition
    /// position when saved, not a setting, and PGLFilterAttributeTime #set takes a rate.
    static func applyArchivedValues(_ archived: CIFilter, to source: PGLSourceFilter) -> Set<String> {
        var animationKeys = Set<String>()
        for anAttribute in source.nonImageParms() {
            guard let key = anAttribute.attributeName,
                  archived.inputKeys.contains(key),
                  let value = archived.value(forKey: key)
            else { continue }

            if anAttribute is PGLFilterAttributeTime {
                animationKeys.insert(key)
            } else if let rectangle = anAttribute as? PGLAttributeRectangle, let vector = value as? CIVector {
                // #set is empty for rectangles - same path as #setStoredValueToAttribute
                rectangle.filterRect = vector.cgRectValue
                rectangle.applyCropRect(mappedCropRect: rectangle.filterRect)
            } else if anAttribute.usesCanvasCoordinates(), let vector = value as? CIVector {
                // the archive holds the render space value the legacy load renders with
                anAttribute.set(vector.scaledToCanvas(fromRenderSize: RenderTargetSize))
            } else if value is NSNumber, anAttribute is PGLFilterAttributeNumber || anAttribute is PGLFilterAttributeAngle {
                anAttribute.set(value)
            }
            // other types (color, string, affine) read the archive after #resetAttributesToLocalFilter
        }
        return animationKeys
    }

    /// Rewrite the stored CDAttributeVector values in the space this stack's load reads.
    ///
    /// PGLFilterAttributeVector #storeParmValue writes live RenderTargetSize-relative values
    /// and relies on #writeCDStack also writing globalSize = RenderTargetSize; on load
    /// #setStoredValueToAttribute sets the raw value and #resizeFrom(savedSize: globalSize)
    /// maps it to FilterCanvasSize. The migration does not rewrite globalSize - that would
    /// reinterpret the other vectors already stored in the stack - so store the value the
    /// existing savedSize maps back to the canonical value: the canvas value when there is
    /// no savedSize (resizeFrom is then the identity), else the value in savedSize space.
    static func storeVectorsForLoad(of source: PGLSourceFilter, savedSize: CGSize?) {
        func storable(_ canvasVector: CIVector) -> CIVector {
            guard let savedSize else { return canvasVector }
            return canvasVector.scaledFromCanvas(toRenderSize: savedSize)
        }
        for anAttribute in source.nonImageParms() {
            guard let vectorAttribute = anAttribute as? PGLFilterAttributeVector,
                  vectorAttribute.usesCanvasCoordinates(),
                  let cdVector = vectorAttribute.storedParmValue as? CDAttributeVector,
                  let canvasVector = vectorAttribute.getVectorValue()
            else { continue }
            let stored = storable(canvasVector)
            cdVector.vectorX = stored.x as NSNumber
            cdVector.vectorY = stored.y as NSNumber
            if let endPoint = vectorAttribute.endPoint {
                let storedEnd = storable(endPoint)
                cdVector.vectorEndX = storedEnd.x as NSNumber
                cdVector.vectorEndY = storedEnd.y as NSNumber
            }
        }
    }

    enum ComparableInput: Equatable {
        case numbers([Double])
        case text(String)
        case notCompared(String)  // a type with no stable value representation
    }

    /// Every non image input of the filter as numbers or text.
    static func comparableInputs(_ filter: CIFilter) -> [String: ComparableInput] {
        var answer = [String: ComparableInput]()
        for aKey in filter.inputKeys {
            guard let value = filter.value(forKey: aKey) else { continue }
            switch value {
                case is CIImage:
                    continue  // images are restored from the image lists, not the parm values
                case let number as NSNumber:
                    answer[aKey] = .numbers([number.doubleValue])
                case let vector as CIVector:
                    answer[aKey] = .numbers((0..<vector.count).map({ Double(vector.value(at: $0)) }))
                case let color as CIColor:
                    answer[aKey] = .numbers([color.red, color.green, color.blue, color.alpha].map({ Double($0) }))
                case let attributed as NSAttributedString:
                    answer[aKey] = .text(attributed.string)
                case let text as String:
                    answer[aKey] = .text(text)
                case let nsValue as NSValue where String(cString: nsValue.objCType).contains("CGAffineTransform"):
                    let transform = nsValue.cgAffineTransformValue
                    answer[aKey] = .numbers([transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty].map({ Double($0) }))
                default:
                    answer[aKey] = .notCompared(String(describing: type(of: value)))
            }
        }
        return answer
    }

    static func inputMismatches(expected: [String: ComparableInput], actual: [String: ComparableInput]) -> [String] {
        var mismatches = [String]()
        for (aKey, expectedValue) in expected.sorted(by: { $0.key < $1.key }) {
            let actualValue = actual[aKey]
            switch (expectedValue, actualValue) {
                case (.notCompared, _):
                    continue
                case (.numbers(let want), .numbers(let got)?):
                    let close = want.count == got.count && zip(want, got).allSatisfy({ abs($0 - $1) <= 1e-3 * max(1, abs($0)) })
                    if !close { mismatches.append("\(aKey): archived \(want) reloaded \(got)") }
                case (.text(let want), .text(let got)?):
                    if want != got { mismatches.append("\(aKey): archived '\(want)' reloaded '\(got)'") }
                default:
                    mismatches.append("\(aKey): archived \(expectedValue) reloaded \(String(describing: actualValue))")
            }
        }
        return mismatches
    }

    // MARK: Data provider

    /// The dataProvider as PGLLibraryController (iPhone) and PGLOpenStackController
    /// (iPad) build it - both are private lazy vars with the same configuration.
    func libraryDataProvider() -> PGLStackProvider {
        let provider = PGLStackProvider(with: persistentContainer)
        provider.setFetchControllerForStackViewContext()
        return provider
    }

    static func controllerName() -> String {
        UIDevice.current.userInterfaceIdiom == .phone ? "PGLLibraryController" : "PGLOpenStackController"
    }

    static func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { rawBuffer in
            String(decoding: rawBuffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }

    static func deviceName() -> String {
        "\(UIDevice.current.name) \(deviceModel())"
    }

    /// Wait for a CloudKit import event to finish so the snapshot is not taken mid import.
    /// An import that already finished before the test started is not reported again.
    func waitForCloudKitImport(timeout: Duration) async -> String {
        let watcher = CloudImportWatcher(container: persistentContainer)
        defer { watcher.stop() }
        let deadline = ContinuousClock.now + timeout
        while watcher.lastImportEnd == nil && ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(500))
        }
        guard let importEnd = watcher.lastImportEnd else {
            return "no CloudKit import event within \(timeout) - store assumed current"
        }
        if let importError = watcher.lastImportError {
            return "CloudKit import ended \(importEnd) with error: \(importError)"
        }
        return "CloudKit import ended \(importEnd)"
    }

    // MARK: Snapshot

    func makeSnapshot(provider: PGLStackProvider, importStatus: String) -> CloudImportSnapshot {
        let stacks = provider.fetchedResultsController.fetchedObjects ?? [CDFilterStack]()
        var visited = Set<NSManagedObjectID>()
        return CloudImportSnapshot(
            deviceID: PGLCurrentDeviceID,
            deviceName: Self.deviceName(),
            deviceModel: Self.deviceModel(),
            controllerName: Self.controllerName(),
            showChildStack: provider.showChildStack,
            capturedAt: Date(),
            importStatus: importStatus,
            stacks: stacks.map({ stackRow($0, visited: &visited) }),
            deviceLocalImageLists: deviceLocalImageLists())
    }

    static func rowKey(type: String?, title: String?, created: Date?) -> String {
        // objectIDs differ per device - match rows on their synced attributes
        let createdSeconds = created.map({ String(Int($0.timeIntervalSince1970.rounded())) }) ?? "nil"
        return "\(type ?? "nil") / \(title ?? "nil") / \(createdSeconds)"
    }

    /// The originating device keeps full Date precision, an importing device has the
    /// CloudKit precision and the snapshot file has ISO 8601 seconds - compare seconds.
    static func wholeSeconds(_ date: Date?) -> Date? {
        date.map({ Date(timeIntervalSince1970: $0.timeIntervalSince1970.rounded()) })
    }

    func stackRow(_ cdStack: CDFilterStack, visited: inout Set<NSManagedObjectID>) -> StackRow {
        let firstVisit = visited.insert(cdStack.objectID).inserted
            // guard a corrupt cyclic child graph
        let filterRows = firstVisit ? sortedFilters(cdStack).map({ filterRow($0, visited: &visited) }) : [FilterRow]()
        return StackRow(
            key: Self.rowKey(type: cdStack.type, title: cdStack.title, created: cdStack.created),
            title: cdStack.title,
            type: cdStack.type,
            created: Self.wholeSeconds(cdStack.created),
            modified: Self.wholeSeconds(cdStack.modified),
            isChildStack: cdStack.outputToParm != nil,
            exportAlbumName: cdStack.exportAlbumName,
            globalSizeWidth: cdStack.globalSizeWidth,
            globalSizeHeight: cdStack.globalSizeHeight,
            thumbnailBytes: cdStack.thumbnail?.count ?? 0,
            filters: filterRows)
    }

    func filterRow(_ cdFilter: CDStoredFilter, visited: inout Set<NSManagedObjectID>) -> FilterRow {
        let valueNames = (cdFilter.values as? Set<CDParmValue>)?.map({ $0.attributeName ?? "nil" }).sorted() ?? [String]()
        var parmRows = [ImageParmRow]()
        for aParm in sortedImageParms(cdFilter) {
            let childRows = aParm.inputStack.map({ [stackRow($0, visited: &visited)] }) ?? [StackRow]()
            parmRows.append(ImageParmRow(
                parmName: aParm.parmName,
                hasInputAssets: aParm.inputAssets != nil,
                assetIDs: aParm.inputAssets?.assetIDs ?? [String](),
                albumIds: aParm.inputAssets?.albumIds ?? [String](),
                machineName: aParm.inputAssets?.machineName,
                hasImageData: aParm.parmImageData != nil,
                childStack: childRows))
        }
        return FilterRow(
            stackPosition: Int(cdFilter.stackPosition),
            ciFilterName: cdFilter.ciFilterName,
            pglSourceFilterClass: cdFilter.pglSourceFilterClass,
            valueNames: valueNames,
            imageParms: parmRows)
    }

    func sortedFilters(_ cdStack: CDFilterStack) -> [CDStoredFilter] {
        let filters = (cdStack.filters as? Set<CDStoredFilter>) ?? Set<CDStoredFilter>()
        return filters.sorted(by: { ($0.stackPosition, $0.ciFilterName ?? "") < ($1.stackPosition, $1.ciFilterName ?? "") })
    }

    func sortedImageParms(_ cdFilter: CDStoredFilter) -> [CDParmImage] {
        let parms = (cdFilter.input as? Set<CDParmImage>) ?? Set<CDParmImage>()
        return parms.sorted(by: { ($0.parmName ?? "") < ($1.parmName ?? "") })
    }

    func stackLabel(_ cdStack: CDFilterStack) -> String {
        "'\(cdStack.type ?? "nil") / \(cdStack.title ?? "nil")'"
    }

    /// Every CDParmImage reached from the stack, including those in child stacks.
    func imageParms(in cdStack: CDFilterStack, path: String) -> [(path: String, parm: CDParmImage)] {
        var answer = [(path: String, parm: CDParmImage)]()
        var visited = Set<NSManagedObjectID>()
        collectImageParms(in: cdStack, path: path, into: &answer, visited: &visited)
        return answer
    }

    private func collectImageParms(in cdStack: CDFilterStack, path: String, into answer: inout [(path: String, parm: CDParmImage)], visited: inout Set<NSManagedObjectID>) {
        guard visited.insert(cdStack.objectID).inserted else { return }
        for aFilter in sortedFilters(cdStack) {
            let filterPath = "\(path) filter \(aFilter.stackPosition) \(aFilter.ciFilterName ?? "nil")"
            for aParm in sortedImageParms(aFilter) {
                answer.append((path: filterPath, parm: aParm))
                if let childStack = aParm.inputStack {
                    collectImageParms(in: childStack, path: "\(filterPath) > child \(stackLabel(childStack))", into: &answer, visited: &visited)
                }
            }
        }
    }

    // MARK: Device-local identifiers

    func deviceLocalImageLists() -> [DeviceLocalImageList] {
        let fetchRequest: NSFetchRequest<CDImageList> = CDImageList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "machineName != nil")
        let localLists = (try? persistentContainer.viewContext.fetch(fetchRequest)) ?? [CDImageList]()
        return localLists.map({ aList in
            DeviceLocalImageList(
                stackPath: owningStackPath(aList.parm),
                parmName: aList.parm?.parmName,
                machineName: aList.machineName ?? "nil",
                assetCount: aList.assetIDs?.count ?? 0)
        })
    }

    /// Top stack > child stack ... > filter for the parm, walking up through outputToParm.
    func owningStackPath(_ cdParmImage: CDParmImage?) -> String {
        guard let parm = cdParmImage else { return "orphan CDImageList (no parm)" }
        guard let filter = parm.filter else { return "orphan CDParmImage (no filter)" }
        guard var stack = filter.stack else { return "orphan CDStoredFilter \(filter.ciFilterName ?? "nil") (no stack)" }

        var path = [stackLabel(stack) + " filter \(filter.stackPosition) \(filter.ciFilterName ?? "nil")"]
        var visited: Set<NSManagedObjectID> = [stack.objectID]
        while let parentParm = stack.outputToParm, let parentFilter = parentParm.filter, let parentStack = parentFilter.stack,
              visited.insert(parentStack.objectID).inserted {
            path.insert(stackLabel(parentStack) + " filter \(parentFilter.stackPosition) \(parentFilter.ciFilterName ?? "nil")", at: 0)
            stack = parentStack
        }
        return path.joined(separator: " > child ")
    }

    // MARK: Identifier resolution

    /// Mirrors PGLFilterAttributeImage #loadInputAssets but keeps every failure reason.
    func resolveLocalIdentifiers(imageList: CDImageList) -> (localIds: [String], problems: [String]) {
        let storedIds = imageList.assetIDs ?? [String]()
        if let deviceTag = imageList.machineName {
            if deviceTag == PGLCurrentDeviceID {
                return (storedIds, [String]())
            }
            return ([String](), ["\(storedIds.count) assetIDs are device-local to device \(deviceTag) - loadInputAssets skips them on this device"])
        }

        var localIds = [String]()
        var problems = [String]()
        let cloudIds = storedIds.map({ PHCloudIdentifier(stringValue: $0) })
        let mappings = PHPhotoLibrary.shared().localIdentifierMappings(for: cloudIds)
        for aCloudId in cloudIds {
            switch mappings[aCloudId] {
                case .success(let localId):
                    localIds.append(localId)
                case .failure(let error):
                    let code = (error as? PHPhotosError)?.code
                    let reason: String
                    switch code {
                        case .identifierNotFound: reason = "identifierNotFound"
                        case .multipleIdentifiersFound: reason = "multipleIdentifiersFound"
                        default: reason = error.localizedDescription
                    }
                    problems.append("cloudId \(aCloudId.stringValue) did not map to a local id - \(reason)")
                case .none:
                    problems.append("cloudId \(aCloudId.stringValue) has no mapping result")
            }
        }
        return (localIds, problems)
    }

    func describe(_ cacheError: PGLCachedImageMgr.CachedImageManagerError) -> String {
        switch cacheError {
            case .error(let photosError):
                let nsError = photosError as NSError
                return "\(nsError.domain) \(nsError.code) \(nsError.localizedDescription)"
            case .cancelled:
                return "request cancelled"
            case .failed:
                return "no image returned"
        }
    }

    // MARK: Compare

    func compare(_ mine: CloudImportSnapshot, _ other: CloudImportSnapshot) -> [String] {
        var differences = [String]()
        var myStacks = mine.stacks
        var otherStacks = other.stacks

        if mine.showChildStack != other.showChildStack {
            differences.append("NOTE showChildStack differs (\(mine.deviceName) \(mine.showChildStack), \(other.deviceName) \(other.showChildStack)) - comparing parent stacks only")
            myStacks = myStacks.filter({ !$0.isChildStack })
            otherStacks = otherStacks.filter({ !$0.isChildStack })
        }

        let myRows = Dictionary(grouping: myStacks, by: { $0.key })
        let otherRows = Dictionary(grouping: otherStacks, by: { $0.key })

        for aKey in Set(myRows.keys).union(otherRows.keys).sorted() {
            let mineForKey = myRows[aKey] ?? [StackRow]()
            let otherForKey = otherRows[aKey] ?? [StackRow]()
            if otherForKey.isEmpty {
                differences.append("\(aKey): only on \(mine.deviceName)")
            } else if mineForKey.isEmpty {
                differences.append("\(aKey): only on \(other.deviceName)")
            } else if mineForKey.count != otherForKey.count {
                differences.append("\(aKey): \(mineForKey.count) rows on \(mine.deviceName), \(otherForKey.count) rows on \(other.deviceName) (duplicate import?)")
            } else {
                for (myRow, otherRow) in zip(mineForKey, otherForKey) where myRow != otherRow {
                    differences.append(contentsOf: rowDifferences(myRow, otherRow, path: aKey, names: (mine.deviceName, other.deviceName)))
                }
            }
        }
        return differences
    }

    func rowDifferences(_ mine: StackRow, _ other: StackRow, path: String, names: (String, String)) -> [String] {
        var differences = [String]()
        func check<T: Equatable>(_ field: String, _ myValue: T, _ otherValue: T) {
            if myValue != otherValue {
                differences.append("\(path) \(field): \(names.0) \(String(describing: myValue)) | \(names.1) \(String(describing: otherValue))")
            }
        }
        check("modified", mine.modified, other.modified)
        check("isChildStack", mine.isChildStack, other.isChildStack)
        check("exportAlbumName", mine.exportAlbumName, other.exportAlbumName)
        check("globalSize", "\(mine.globalSizeWidth) x \(mine.globalSizeHeight)", "\(other.globalSizeWidth) x \(other.globalSizeHeight)")
        check("thumbnailBytes", mine.thumbnailBytes, other.thumbnailBytes)
        check("filter count", mine.filters.count, other.filters.count)

        for (myFilter, otherFilter) in zip(mine.filters, other.filters) where myFilter != otherFilter {
            let filterLabel = "filter \(myFilter.stackPosition) \(myFilter.ciFilterName ?? "nil")"
            check("\(filterLabel) stackPosition", myFilter.stackPosition, otherFilter.stackPosition)
            check("\(filterLabel) ciFilterName", myFilter.ciFilterName, otherFilter.ciFilterName)
            check("\(filterLabel) pglSourceFilterClass", myFilter.pglSourceFilterClass, otherFilter.pglSourceFilterClass)
            check("\(filterLabel) values", myFilter.valueNames, otherFilter.valueNames)
            check("\(filterLabel) image parms", myFilter.imageParms.map({ $0.parmName ?? "nil" }), otherFilter.imageParms.map({ $0.parmName ?? "nil" }))

            let myParms = myFilter.imageParms.sorted(by: Self.parmOrder)
            let otherParms = otherFilter.imageParms.sorted(by: Self.parmOrder)
            for (myParm, otherParm) in zip(myParms, otherParms) where myParm != otherParm {
                let parmLabel = "\(filterLabel) parm \(myParm.parmName ?? "nil")"
                check("\(parmLabel) hasInputAssets", myParm.hasInputAssets, otherParm.hasInputAssets)
                if myParm.assetIDs != otherParm.assetIDs && Set(myParm.assetIDs) == Set(otherParm.assetIDs) {
                    differences.append("\(path) \(parmLabel) assetIDs: same \(myParm.assetIDs.count) assets in a different order")
                } else {
                    check("\(parmLabel) assetIDs", myParm.assetIDs, otherParm.assetIDs)
                }
                if Set(myParm.albumIds) != Set(otherParm.albumIds) {
                    check("\(parmLabel) albumIds", myParm.albumIds, otherParm.albumIds)
                }
                check("\(parmLabel) machineName", myParm.machineName, otherParm.machineName)
                check("\(parmLabel) hasImageData", myParm.hasImageData, otherParm.hasImageData)
                check("\(parmLabel) has child stack", myParm.childStack.count, otherParm.childStack.count)
                for (myChild, otherChild) in zip(myParm.childStack, otherParm.childStack) where myChild != otherChild {
                    differences.append(contentsOf: rowDifferences(myChild, otherChild, path: "\(path) \(parmLabel) > child '\(myChild.title ?? "nil")'", names: names))
                }
            }
        }
        return differences
    }

    /// Order the image parms independent of the device - a filter can hold more than
    /// one CDParmImage with the same parmName, and NSSet order differs per device.
    static func parmOrder(_ left: ImageParmRow, _ right: ImageParmRow) -> Bool {
        let leftKey = [left.parmName ?? "", left.hasInputAssets ? "1" : "0", left.assetIDs.sorted().joined(separator: ","), left.childStack.first?.key ?? ""]
        let rightKey = [right.parmName ?? "", right.hasInputAssets ? "1" : "0", right.assetIDs.sorted().joined(separator: ","), right.childStack.first?.key ?? ""]
        return leftKey.lexicographicallyPrecedes(rightKey)
    }

    // MARK: Files

    nonisolated static func snapshotFolder() throws -> URL {
        let documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let folder = documents.appendingPathComponent("CloudImportSnapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func write(snapshot: CloudImportSnapshot) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let url = try Self.snapshotFolder().appendingPathComponent("\(snapshot.deviceID).json")
        try encoder.encode(snapshot).write(to: url, options: .atomic)
        return url
    }

    func readSnapshots() throws -> [CloudImportSnapshot] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let files = try FileManager.default.contentsOfDirectory(at: Self.snapshotFolder(), includingPropertiesForKeys: nil)
        return files
            .filter({ $0.pathExtension == "json" })
            .compactMap({ fileURL in
                do {
                    return try decoder.decode(CloudImportSnapshot.self, from: Data(contentsOf: fileURL))
                } catch {
                    Issue.record("Unreadable snapshot \(fileURL.lastPathComponent): \(error)")
                    return nil
                }
            })
    }

    /// Write the report so far, without logging or attaching it.
    func writeProgress(_ report: [String], named reportName: String) throws {
        let reportFolder = try Self.snapshotFolder().appendingPathComponent("Reports", isDirectory: true)
        try FileManager.default.createDirectory(at: reportFolder, withIntermediateDirectories: true)
        let fileName = "\(reportName)-\(Self.deviceModel()).txt"
        try Data(report.joined(separator: "\n").utf8).write(to: reportFolder.appendingPathComponent(fileName), options: .atomic)
    }

    /// Log the report, write it to Documents/CloudImportSnapshots/Reports and attach it.
    func publish(report: [String], named reportName: String) throws {
        let text = report.joined(separator: "\n")
        for aLine in report {
            Self.logger.notice("\(reportName, privacy: .public): \(aLine, privacy: .public)")
        }
        let reportFolder = try Self.snapshotFolder().appendingPathComponent("Reports", isDirectory: true)
        try FileManager.default.createDirectory(at: reportFolder, withIntermediateDirectories: true)
        let fileName = "\(reportName)-\(Self.deviceModel()).txt"
        try Data(text.utf8).write(to: reportFolder.appendingPathComponent(fileName), options: .atomic)
        Attachment.record(text, named: fileName)
    }
}

// MARK: CloudKit event recorder

/// Records every NSPersistentCloudKitContainer event notification as a report line.
@MainActor
final class CloudKitEventRecorder {
    private(set) var lines = [String]()
    private(set) var exportSucceeded = false
    private var observer: (any NSObjectProtocol)?

    init(container: NSPersistentContainer) {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: .main) { [weak self] notification in
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event
                else { return }
                let typeName: String
                switch event.type {
                    case .setup: typeName = "setup"
                    case .import: typeName = "import"
                    case .export: typeName = "export"
                    @unknown default: typeName = "unknown"
                }
                var line = "\(Date()) \(typeName) \(event.identifier.uuidString.prefix(8)) started \(event.startDate)"
                if let endDate = event.endDate {
                    line += " ENDED \(endDate) (\(Int(endDate.timeIntervalSince(event.startDate)))s) succeeded \(event.succeeded)"
                } else {
                    line += " in progress"
                }
                if let error = event.error as NSError? {
                    line += " error \(error.domain) \(error.code) \(error.localizedDescription)"
                    if let partialErrors = error.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: NSError] {
                        line += " partial errors \(partialErrors.count):"
                        for (recordID, itemError) in partialErrors.prefix(10) {
                            line += " [\(recordID.recordName) \(itemError.code) \(itemError.localizedDescription)]"
                        }
                    }
                }
                let exportDone = event.type == .export && event.endDate != nil && event.succeeded
                MainActor.assumeIsolated {
                    self?.lines.append(line)
                    if exportDone { self?.exportSucceeded = true }
                }
            }
    }

    func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }
}

// MARK: CloudKit event watcher

/// Records the end of the next NSPersistentCloudKitContainer import event.
@MainActor
final class CloudImportWatcher {
    private(set) var lastImportEnd: Date?
    private(set) var lastImportError: String?
    private var observer: (any NSObjectProtocol)?

    init(container: NSPersistentContainer) {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: .main) { [weak self] notification in
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event,
                      event.type == .import,
                      let importEnd = event.endDate
                else { return }
                let errorText = event.error?.localizedDescription
                MainActor.assumeIsolated {
                    self?.lastImportEnd = importEnd
                    self?.lastImportError = errorText
                }
            }
    }

    func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }
}
