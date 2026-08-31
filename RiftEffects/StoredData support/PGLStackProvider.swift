//
//  PGLStackProvider.swift
//  WillsFilterTool
//
//  Created by Will on 9/1/21.
//  Copyright © 2021 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreData

class PGLStackProvider {
    private(set) var persistentContainer: NSPersistentContainer
    var fetchedResultsController: NSFetchedResultsController<CDFilterStack>!
    var providerManagedObjectContext: NSManagedObjectContext!

    var showChildStack = UserDefaults.standard.bool(forKey:  "showChildStack")  // userDefault setting

    init(with persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer

    }
        /// was fetchedStacks: [CDFilterStack ] array
        ///  now [FilterStack] struct array
    lazy var fetchedStacks = fetchedResultsController.fetchedObjects?.map({ ($0 .asFilterStackStruct() ) })

    func setFetchControllerForStackViewContext() {
        providerManagedObjectContext = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<CDFilterStack> = CDFilterStack.fetchRequest()
        if showChildStack {
            fetchRequest.predicate = NSPredicate(value: true) // return all stacks
        } else {
            // Only parent stacks: outputToParm == nil
            let left = NSExpression(forKeyPath: "outputToParm")
            let right = NSExpression(forConstantValue: NSNull())
            fetchRequest.predicate = NSComparisonPredicate(
                leftExpression: left,
                rightExpression: right,
                modifier: .direct,
                type: .equalTo,
                options: []
            )
        }

        fetchRequest.fetchBatchSize = 15  // usually 12 rows visible -
            // breaks up the full object fetch into view sized chunks

            // only CDFilterStacks with outputToParm = null.. ie it is not a child stack)
        var sortArray = [NSSortDescriptor]()
        sortArray.append(NSSortDescriptor(key: "type", ascending: true))
        sortArray.append(NSSortDescriptor(key: "created", ascending: false))


        fetchRequest.sortDescriptors = sortArray

         fetchedResultsController = NSFetchedResultsController(
                                        fetchRequest: fetchRequest,
                                        managedObjectContext: providerManagedObjectContext,
                                        sectionNameKeyPath: "type" ,
                                        cacheName: "StackType")
//        controller.delegate = fetchedResultsControllerDelegate
            // Full persistent tracking: the delegate and the file cache name are non-nil. The controller monitors objects in its result set
            // and updates section and ordering information in response
            // to relevant changes. The controller maintains a persistent cache of the results of its computation.
            do {
                try fetchedResultsController.performFetch()
            } catch {
                fatalError("###\(#function): Failed to performFetch: \(error)")
            }
    }

        func setFetchControllerForBackgroundContext() {
            providerManagedObjectContext = persistentContainer.newBackgroundContext()
            let fetchRequest: NSFetchRequest<CDFilterStack> = CDFilterStack.fetchRequest()
    //        fetchRequest.predicate = NSPredicate(format: "outputToParm = null")  // only parent stacks
            fetchRequest.predicate = NSPredicate(value: true) // return all stacks
            fetchRequest.fetchBatchSize = 15  // usually 12 rows visible -
                // breaks up the full object fetch into view sized chunks

                // only CDFilterStacks with outputToParm = null.. ie it is not a child stack)
            var sortArray = [NSSortDescriptor]()
            sortArray.append(NSSortDescriptor(key: "type", ascending: true))
            sortArray.append(NSSortDescriptor(key: "created", ascending: false))


            fetchRequest.sortDescriptors = sortArray

             fetchedResultsController = NSFetchedResultsController(
                                            fetchRequest: fetchRequest,
                                             managedObjectContext: providerManagedObjectContext,
                                             sectionNameKeyPath: "type" ,
                                             cacheName: "backgroundStack")

    //        controller.delegate = fetchedResultsControllerDelegate
                // Full persistent tracking: the delegate and the file cache name are non-nil. The controller monitors objects in its result set
                // and updates section and ordering information in response
                // to relevant changes. The controller maintains a persistent cache of the results of its computation.
            do {
                    try fetchedResultsController.performFetch()
            } catch {
                    fatalError("###\(#function): Failed to performFetch: \(error)") }
        }

    func delete(stack: FilterStack, shouldSave: Bool = true) {
        guard let cdStack = providerManagedObjectContext.registeredObject(for: stack.objectID)
                else { return }
        guard let context = cdStack.managedObjectContext else {
            // missing managedObjectContext occurs when in a filtered mode search and the stack is deleted successfully
            // but remains in the filtered view. Then a second 'delete' action will not have a managedObjectContext
            // cancel or change in the search criteria will update and not show this deleted stack
            // annoying !!
            return
        }
        let objectID = cdStack.objectID
        context.perform { [objectID] in
            if let object = context.registeredObject(for: objectID) ?? (try? context.existingObject(with: objectID)) {
                context.delete(object)

                if shouldSave {
                    context.save(with: .deletePost)
                }
            }
        }
    }

    func rollback() {
        ///Removes everything from the undo stack, discards all insertions and deletions, and restores updated objects to their last committed values. This method does not refetch data from the persistent store or stores.
            providerManagedObjectContext.rollback()
    }

    func reset() {
        providerManagedObjectContext.reset()
    }
        
    func batchDelete(deleteIds: [NSManagedObjectID]) {
        guard !deleteIds.isEmpty else { return }
        let taskContext = persistentContainer.viewContext
        let batchDelete = NSBatchDeleteRequest(objectIDs: deleteIds)
        batchDelete.resultType = .resultTypeObjectIDs
        do {
            let batchDeleteResult = try taskContext.execute(batchDelete) as? NSBatchDeleteResult
            // NSBatchDeleteRequest deletes rows directly in the store, bypassing the context.
            // Without this merge, taskContext (and every NSFetchedResultsController bound to it,
            // including PGLLibraryController's) keeps stale registered objects and the deleted
            // stacks reappear on the next fetch until some unrelated save/reset happens to catch up.
            if let deletedObjectIDs = batchDeleteResult?.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: deletedObjectIDs], into: [taskContext])
            }
        } catch {
            print("###\(#function): Failed to batch delete existing records: \(error)")
        }
    }

    @discardableResult
    func saveStack(aStack: CDFilterStack, in context: NSManagedObjectContext, shouldSave: Bool = true) -> Bool {
        guard shouldSave else { return true }
        // performAndWait so the caller can report the outcome. The save runs on the
        // context's own queue; the calling stack save has already stopped drawing.
        var didSave = false
        context.performAndWait {
            didSave = context.save(with: .addPost)
        }
        return didSave
    }

    func filterStackCount() -> Int {
        // number of rows in the CDFilterStack table
        var rowCount = 0

        let fetchCountRequest: NSFetchRequest<CDFilterStack> = CDFilterStack.fetchRequest()
        fetchCountRequest.predicate = NSPredicate(value: true)
            // all rows returned

        rowCount = try! persistentContainer.viewContext.count(for: fetchCountRequest)

        return rowCount
    }

}
