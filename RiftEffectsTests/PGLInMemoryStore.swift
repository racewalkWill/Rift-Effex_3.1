//
//  PGLInMemoryStore.swift
//  RiftEffectsTests
//
//  A temporary in-memory Core Data store built from the app's model.
//  Tests save into it so the device store and CloudKit are never touched.
//

import UIKit
import CoreData
import Testing

@testable import RiftEffects

@MainActor
enum PGLInMemoryStore {

    /// a new empty in-memory container - each call is an independent store
    static func makeContainer(name: String) throws -> NSPersistentContainer {
        let appDelegate = try #require(UIApplication.shared.delegate as? AppDelegate)
        let model = appDelegate.dataWrapper.persistentContainer.managedObjectModel
            // the same model instance - a second copy would register the entity classes twice
        let container = NSPersistentContainer(name: name, managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))
            // SQLite at /dev/null is an in-memory store
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        var loadError: (any Error)?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        return container
    }

    /// a stack provider on a new in-memory container, set up like the test providers
    /// with a background context fetch controller
    static func makeProvider(name: String) throws -> PGLStackProvider {
        let provider = PGLStackProvider(with: try makeContainer(name: name))
        provider.setFetchControllerForBackgroundContext()
        return provider
    }
}
