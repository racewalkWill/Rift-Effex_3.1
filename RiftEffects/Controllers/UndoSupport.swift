//
//  UndoSupport.swift
//  RiftEffects
//
//  Created by Will on 1/16/26.
//  Copyright © 2026 Will Loew-Blosser. All rights reserved.
//


//
//  UndoSupport.swift
//  RiftEffects
//
//  Created by Will on 1/16/26.
//  Copyright © 2026 Will Loew-Blosser. All rights reserved.
//

/// undoManager is singleton in AppStack.undoManager

extension PGLStackController {
    // may have memory capture problems with the method vars passed into the blocks
    // currentStack and currentActiveIndex are passed to the undo blocks

    func registerUndoRemoveFilter(_ removedFilter: PGLSourceFilter) {
            // need to store this stack and stack position for the undo of the add
//        let currentStack = appStack.getViewerStack()
//        let currentActiveIndex = currentStack.activeFilterIndex
        if let myUndoManager = undoManager {
            myUndoManager.registerUndo(withTarget: self) { target in

                target.undoRemoveFilterFromStack(removedFilter)
            }
            myUndoManager.setActionName("Delete Filter")

        }
    }

    func undoRemoveFilterFromStack(_ filter: PGLSourceFilter) {
        appStack.setFilterChangeModeToAdd()
        appStack.viewerStack.performFilterPick(selectedFilter: filter)
        updateDisplay()
        if let myUndoManager = undoManager {
            myUndoManager.registerUndo(withTarget: self) { target in
                target.appStack.setFilterChangeModeToAdd()
                let myStack = target.appStack.viewerStack
                myStack.performFilterPick(selectedFilter: filter)

            }
            myUndoManager.setActionName("Delete Filter")

        }


        // Note that the MainFilterController also calls
//        updateFilterLabel()
//        postImageChange()
//        postCurrentFilterChange()
//        appStack.resetCellFilters()
    }

//    func undoRemoveFilterFromStack(_ filter: PGLSourceFilter, stack: PGLFilterStack? = nil, atIndex: Int? = nil) {
//
//        let targetStack = stack ?? appStack.getViewerStack()
//        let targetActiveIndex = atIndex ?? targetStack.activeFilterIndex
//       
//
//        targetStack.stackMode = .add
//        targetStack.activeFilterIndex = targetActiveIndex
//        targetStack.performFilterPick(selectedFilter: filter)
//        // need to store this stack and stack position for the undo of the add
//
//        updateDisplay()
//        if let myUndoManager = undoManager {
//            myUndoManager.registerUndo(withTarget: self) { target in
//                    //                target.appStack.setFilterChangeModeToAdd()
//                // reset the viewerStack and index
////                let myStack = target.appStack.getViewerStack()
////                let activeIndex = myStack.activeFilterIndex
//                _ = targetStack.removeFilter(position: targetActiveIndex)
//                target.updateDisplay()
//                
//            }
//            myUndoManager.setActionName("Delete Filter")
//            
//        }
//        
//    }


}

extension PGLMainFilterController {

    func registerUndoAddFilter(_ newFilter: PGLSourceFilter) {
        undoManager?.registerUndo(withTarget: self ) {
            target in
            target.undoAddFilter(newFilter)
        }
        undoManager?.setActionName("Add Filter")
    }

    func undoAddFilter(_ oldFilter: PGLSourceFilter) {
        // tell stackController

        appStack.viewerStack.undoAddFilter(oldFilter: oldFilter)
        undoManager?.registerUndo(withTarget: self ) {
            target in
            target.appStack.setFilterChangeModeToAdd()
                // the addfilter set the mode to replace..
                // just add back not replace

            target.performBasicPick(filter: oldFilter)

        }
//        NSLog(#function + " \(String(describing: undoManager))" )
        undoManager?.setActionName("Add Filter")
    }

}


