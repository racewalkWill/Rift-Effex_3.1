//
//  PGLOutputLinkStoreTests.swift
//  RiftEffectsTests
//
//  Save and restore of filter output links (model 2.5).
//  A target CDParmImage.outputLinkMaster points at the CDStoredFilter row of the source filter.
//  Each test saves into a temporary in-memory store built from the app's model,
//  so the device store and CloudKit are never touched.
//

import Testing
import UIKit
import CoreData

@testable import RiftEffects

@MainActor
@Suite(.serialized) struct PGLOutputLinkStoreTests {

    let container: NSPersistentContainer
    var context: NSManagedObjectContext { container.viewContext }

    init() throws {
        let appDelegate = try #require(UIApplication.shared.delegate as? AppDelegate)
        let model = appDelegate.dataWrapper.persistentContainer.managedObjectModel
            // the same model instance - a second copy would register the entity classes twice
        container = NSPersistentContainer(name: "PGLOutputLinkStoreTests", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))
            // SQLite at /dev/null is an in-memory store
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        var loadError: (any Error)?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
    }

    // MARK: helpers

    func makeStack(_ title: String, filterNames: [String]) throws -> PGLFilterStack {
        let stack = PGLFilterStack()
        stack.stackName = title
        stack.stackType = "testCase PGLOutputLinkStoreTests"
        for aName in filterNames {
            let filter = try #require(PGLSourceFilter(filter: aName), "\(aName) did not build")
            filter.setDefaults()
            stack.appendFilter(filter)
        }
        return stack
    }

    /// save the way PGLAppStack #writeCDStacks does - links after all rows are written
    @discardableResult
    func save(_ stack: PGLFilterStack) throws -> CDFilterStack {
        let cdStack = stack.writeCDStack(moContext: context)
        stack.storeParmLinks()
        try context.save()
        return cdStack
    }

    /// load the way PGLAppStack #resetToTopStack does
    func load(_ cdStack: CDFilterStack) -> PGLFilterStack {
        let loadedStack = PGLFilterStack()
        loadedStack.on(cdStack: cdStack)
        loadedStack.resolveParmLinks()
        return loadedStack
    }

    func backgroundParm(_ filter: PGLSourceFilter) throws -> PGLFilterAttributeImage {
        return try #require(filter.attribute(nameKey: kCIInputBackgroundImageKey) as? PGLFilterAttributeImage)
    }

    // MARK: tests

    /// the output of filter 0 feeds the background input of filter 2 - saved and restored
    @Test func outputLinkSavesAndRestores() throws {
        let stack = try makeStack("outputLink", filterNames: ["CIBumpDistortion", "CIKaleidoscope", "CISourceOverCompositing"])
        let sourceOutput = try #require(stack.activeFilters[0].outputLink)
        let target = try backgroundParm(stack.activeFilters[2])
        sourceOutput.link(target: target)
        #expect(target.linkMaster === sourceOutput, "precondition - the link is made")

        let cdStack = try save(stack)
        let cdSource = try #require(stack.activeFilters[0].storedFilter)
        let cdTarget = try #require(target.storedParmImage)
        #expect(cdTarget.outputLinkMaster === cdSource, "the target row points at the source filter row")
        #expect(cdTarget.linkMaster == nil, "not stored as an image list link")
        #expect(cdSource.outputLinkTargets?.count == 1, "inverse relationship")

        let loadedStack = load(cdStack)
        #expect(loadedStack.activeFilters.count == 3)
        let loadedSourceOutput = try #require(loadedStack.activeFilters[0].outputLink)
        let loadedTarget = try backgroundParm(loadedStack.activeFilters[2])
        #expect(loadedTarget.linkMaster === loadedSourceOutput, "the restored target follows the restored source output")
        #expect(loadedSourceOutput.linkTargets.count == 1)
    }

    /// unlink then save clears the stored relationship
    @Test func unlinkedOutputClearsRow() throws {
        let stack = try makeStack("outputUnlink", filterNames: ["CIBumpDistortion", "CISourceOverCompositing"])
        let sourceOutput = try #require(stack.activeFilters[0].outputLink)
        let target = try backgroundParm(stack.activeFilters[1])
        sourceOutput.link(target: target)
        let cdStack = try save(stack)
        #expect(target.storedParmImage?.outputLinkMaster != nil)

        sourceOutput.unlinkAll()
        try save(stack)
        #expect(target.storedParmImage?.outputLinkMaster == nil, "the unlink is stored")

        let loadedStack = load(cdStack)
        let loadedTarget = try backgroundParm(loadedStack.activeFilters[1])
        #expect(loadedTarget.linkMaster == nil)
    }

    /// deleting the source filter row nullifies the target relationship
    @Test func deletedSourceFilterNullifiesTarget() throws {
        let stack = try makeStack("outputDelete", filterNames: ["CIBumpDistortion", "CISourceOverCompositing"])
        let sourceOutput = try #require(stack.activeFilters[0].outputLink)
        let target = try backgroundParm(stack.activeFilters[1])
        sourceOutput.link(target: target)
        try save(stack)
        let cdTarget = try #require(target.storedParmImage)
        let cdSource = try #require(stack.activeFilters[0].storedFilter)

        context.delete(cdSource)
        try context.save()
        #expect(cdTarget.outputLinkMaster == nil, "Nullify rule on CDStoredFilter.outputLinkTargets")
    }
}
