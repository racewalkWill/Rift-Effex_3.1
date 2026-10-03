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

    static func snapshotFolder() throws -> URL {
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
