//
//  PGLFilterDeleteTests.swift
//  RiftEffectsTests
//
//  Regression tests for orphan rows. Each test saves stacks into a temporary in-memory
//  store built from the app's model, so the device store and CloudKit are never touched.
//   - CDStoredFilter.values is Cascade: deleting a filter deletes its CDParmValue rows
//   - #writeCDStack deletes the rows of filters removed from a saved stack
//     (#deleteRemovedCDFilters) and keeps a child stack a replacing filter took over
//

import Testing
import UIKit
import CoreData

@testable import RiftEffects

@MainActor
@Suite(.serialized) struct PGLFilterDeleteTests {

    let container: NSPersistentContainer
    var context: NSManagedObjectContext { container.viewContext }

    init() throws {
        let appDelegate = try #require(UIApplication.shared.delegate as? AppDelegate)
        let model = appDelegate.dataWrapper.persistentContainer.managedObjectModel
            // the same model instance - a second copy would register the entity classes twice
        container = NSPersistentContainer(name: "PGLFilterDeleteTests", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))
            // SQLite at /dev/null is an in-memory store
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        var loadError: (any Error)?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
    }

    // MARK: helpers

    func makeFilter(_ name: String) throws -> PGLSourceFilter {
        let filter = try #require(PGLSourceFilter(filter: name), "\(name) did not build")
        filter.setDefaults()
        return filter
    }

    func makeStack(_ title: String, filterNames: [String]) throws -> PGLFilterStack {
        let stack = PGLFilterStack()
        stack.stackName = title
        stack.stackType = "testCase PGLFilterDeleteTests"
        for aName in filterNames {
            stack.appendFilter(try makeFilter(aName))
        }
        return stack
    }

    /// Attach a child stack to the image parm the way PGLAppStack #addChildStackBasic does.
    func attachChildStack(to imageParm: PGLFilterAttributeImage, filterName: String) throws -> PGLFilterStack {
        let child = PGLFilterStack()
        child.stackName = "child of \(imageParm.attributeName ?? "nil")"
        child.stackType = "input"
        child.appendFilter(try makeFilter(filterName))
        child.parentAttribute = imageParm
        imageParm.inputStack = child
        imageParm.setImageParmState(newState: ParmInputState.inputChildStack)
        return child
    }

    @discardableResult
    func save(_ stack: PGLFilterStack) throws -> CDFilterStack {
        let cdStack = stack.writeCDStack(moContext: context)
        try context.save()
        return cdStack
    }

    func count(_ entityName: String, _ format: String? = nil) throws -> Int {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        if let format { request.predicate = NSPredicate(format: format) }
        return try context.count(for: request)
    }

    /// Rows that no stack reaches - must stay zero after every save.
    func expectNoOrphans(_ comment: Comment) throws {
        #expect(try count("CDStoredFilter", "stack == nil") == 0, "stackless filters - \(comment)")
        #expect(try count("CDParmValue", "storedFilter == nil") == 0, "parm values with no filter - \(comment)")
        #expect(try count("CDParmImage", "filter == nil") == 0, "parm images with no filter - \(comment)")
        #expect(try count("CDImageList", "parm == nil") == 0, "image lists with no parm - \(comment)")
    }

    func valueCount(of cdFilter: CDStoredFilter?) -> Int {
        cdFilter?.values?.count ?? 0
    }

    // MARK: tests

    /// The model has the Cascade rule - deleting a saved stack leaves nothing behind.
    @Test func deleteStackCascadesToParmValues() throws {
        let stack = try makeStack("deleteStack", filterNames: ["CIBumpDistortion", "CIKaleidoscope", "CIVignetteEffect"])
        let cdStack = try save(stack)
        #expect(try count("CDParmValue") > 0, "the filters stored parm values")
        try expectNoOrphans("after the first save")

        context.delete(cdStack)
        try context.save()

        #expect(try count("CDFilterStack") == 0)
        #expect(try count("CDStoredFilter") == 0)
        #expect(try count("CDParmImage") == 0)
        #expect(try count("CDParmValue") == 0, "CDStoredFilter.values must be Cascade")
    }

    /// Removing a filter from a saved stack deletes its rows on the next save and leaves the
    /// other filters and their values alone.
    @Test func removedFilterRowsAreDeleted() throws {
        let stack = try makeStack("removeFilter", filterNames: ["CIBumpDistortion", "CIKaleidoscope", "CIVignetteEffect"])
        let cdStack = try save(stack)
        let removedCDFilter = try #require(stack.activeFilters[1].storedFilter)
        let removedValueCount = valueCount(of: removedCDFilter)
        let totalValues = try count("CDParmValue")
        #expect(removedValueCount > 0)

        _ = stack.removeFilter(position: 1)
        try save(stack)

        #expect(cdStack.filters?.count == 2)
        #expect(removedCDFilter.isDeleted || removedCDFilter.managedObjectContext == nil, "the removed filter row is deleted")
        #expect(try count("CDStoredFilter") == 2)
        #expect(try count("CDParmValue") == totalValues - removedValueCount, "only the removed filter's values are gone")
        try expectNoOrphans("after removing a filter")

        // a second save of the same stack must not fail on the already deleted row
        try save(stack)
        #expect(try count("CDStoredFilter") == 2)
        try expectNoOrphans("after a second save")
    }

    /// Replacing a filter whose image parm holds a child stack: moveInputsFrom hands the
    /// child stack to the new filter, so the child stack must survive the old filter's delete
    /// (CDParmImage.inputStack is Cascade).
    @Test func replacedFilterKeepsChildStack() throws {
        let stack = try makeStack("replaceFilter", filterNames: ["CIBumpDistortion", "CIKaleidoscope"])
        let bumpImageParm = try #require(stack.activeFilters[0].imageParms()?.first(where: { $0.attributeName == kCIInputImageKey }))
        let child = try attachChildStack(to: bumpImageParm, filterName: "CIPhotoEffectNoir")
        try save(stack)
        let childCDStack = try #require(child.storedStack)
        let oldCDFilter = try #require(stack.activeFilters[0].storedFilter)
        #expect(childCDStack.outputToParm?.filter == oldCDFilter)
        #expect(try count("CDFilterStack") == 2)

        stack.replaceFilter(at: 0, newFilter: try makeFilter("CIPinchDistortion"))
        try save(stack)

        #expect(!childCDStack.isDeleted && childCDStack.managedObjectContext != nil, "the child stack still exists")
        #expect(try count("CDFilterStack") == 2, "parent and child stacks")
        #expect(childCDStack.outputToParm?.filter?.ciFilterName == "CIPinchDistortion", "the child stack moved to the replacing filter")
        #expect(childCDStack.filters?.count == 1, "the child stack kept its filter")
        #expect(oldCDFilter.isDeleted || oldCDFilter.managedObjectContext == nil, "the replaced filter row is deleted")
        #expect(try count("CDStoredFilter") == 3, "Pinch + Kaleidoscope + the child's Noir")
        try expectNoOrphans("after replacing a filter with a child stack")
    }

    /// Save As (a new name) must leave the original stack with all its filters - only the
    /// new stack loses the removed filter.
    @Test func saveAsKeepsOriginalStackFilters() throws {
        let stack = try makeStack("original", filterNames: ["CIBumpDistortion", "CIKaleidoscope", "CIVignetteEffect"])
        let originalCDStack = try save(stack)
        #expect(originalCDStack.filters?.count == 3)

        _ = stack.removeFilter(position: 1)
        stack.stackName = "original renamed"  // a changed name saves as a new stack
        let newCDStack = try save(stack)

        #expect(newCDStack !== originalCDStack)
        #expect(originalCDStack.filters?.count == 3, "the original stack keeps all its filters")
        #expect(newCDStack.filters?.count == 2)
        #expect(try count("CDFilterStack") == 2)
        try expectNoOrphans("after Save As")
    }
}
