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

import UIKit

extension PGLStackController {
    // may have memory capture problems with the method vars passed into the blocks
    // currentStack and currentActiveIndex are passed to the undo blocks

    func registerUndoRemoveFilter(_ removedFilter: PGLSourceFilter, oldIndex: IndexPath ) {
            // need to store this filter and stack position for the undo of the add

//        let currentStack = appStack.getViewerStack()
//        let currentActiveIndex = currentStack.activeFilterIndex

        if let myUndoManager = undoManager {
            myUndoManager.registerUndo(withTarget: self) { target in
                target.undoRemoveFilterFromStack(removedFilter, flatArrayPosition: oldIndex)
            }
            myUndoManager.setActionName("Delete Filter")

        }
    }


    func undoRemoveFilterFromStack(_ filter: PGLSourceFilter, flatArrayPosition: IndexPath) {

//        appStack.resetOutputAppStack( targetStack )
       // appStack.restore(removedFilter: filter, destinationRow: flatArrayPosition )
//        appStack.restore(removedFilter: filter, inputCell:  )
        updateDisplay()

        if let myUndoManager = undoManager {
            myUndoManager.registerUndo(withTarget: self) { target in
                    //                target.appStack.setFilterChangeModeToAdd()
                // reset the viewerStack and index
                target.removeFilter(indexPath: flatArrayPosition)
                target.updateDisplay()
            }
            myUndoManager.setActionName("Delete Filter")
        }
    }


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

extension PGLAppStack {
    func restore(removedFilter: PGLSourceFilter, inputCell: PGLFilterIndent ) {
        // inputCell was receiving the output of the removed filter
        // which attribute was it connected to ?
        // a filter input to another attribute will be in a child stack
        // the child stack has the parentAttrbiute relation
        // does the removed filter know it's stack??
        

//        let targetIndentCell = filterAt(indexPath:  destinationRow)
        let targetStack = inputCell.stack

        // is the removedFilter a transition that may change transition state with the move?
        // i.e. dissolve with priorFilterInput will lose an input if moved to first
        // capture initial state

        let oldImageInput = removedFilter.getInputImageAttribute() // may be nil depending on filter type
//        let isPriorFilterInput = (oldImageInput?.parmInputState == ParmInputState.inputPriorFilter) // nil answers false

        // so move
        targetStack.activeFilters.insert(removedFilter, at: inputCell.filterPosition)

        // reset the imageInput chain
        // does first filter need inputs set? priorFilter is no longer valid
        // could have inputCollection or a childStack as working input
        if inputCell.filterPosition == 0 {
            if let inputImageAttribute = targetStack.activeFilters[0].getInputImageAttribute(){
                    if inputImageAttribute.parmInputState == ParmInputState.inputPriorFilter {
                        inputImageAttribute.setImageParmState(newState: ParmInputState.missingImageInput)
                    }
                }
        }

        for index in 1 ..< targetStack.activeFilters.count {
            let priorFilter = targetStack.activeFilters[index - 1 ]
            let aFilter = targetStack.activeFilters[index]
            aFilter.setInput(image: priorFilter.outputImage(),source: targetStack.stackFilterName(priorFilter, index: index))
            aFilter.setInputImageParmState(newState: ParmInputState.inputPriorFilter)
            }

        targetStack.setFiltersStackPosition()



    }

}


