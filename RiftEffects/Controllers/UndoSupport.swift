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

    func registerUndoRemoveFilter(_ removedCell: PGLFilterIndent ) {
            // need to store this filter and stack position for the undo of the add

//        let currentStack = appStack.getViewerStack()
//        let currentActiveIndex = currentStack.activeFilterIndex

        if let myUndoManager = undoManager {
            myUndoManager.registerUndo(withTarget: self) { target in
                target.undoRemoveFilterFromStack(removedCell: removedCell)
            }
            myUndoManager.setActionName("Delete Filter")

        }
        UIMenuSystem.main.setNeedsRevalidate()
    }


    func undoRemoveFilterFromStack(removedCell: PGLFilterIndent ) {

        appStack.restore(removedCell)
        updateDisplay()
        let flatCells = appStack.flatCellFilters
        guard let flatArrayPosition = flatCells.firstIndex(where: { $0.stack == removedCell.stack && $0.filter.stackPosition == removedCell.filter.stackPosition && $0.filter.filterName == removedCell.filter.filterName })
            else {
                return }

        if let myUndoManager = undoManager {
            myUndoManager.registerUndo(withTarget: self) { target in
                    //                target.appStack.setFilterChangeModeToAdd()
                // reset the viewerStack and index
                let newIndex = IndexPath(row:flatArrayPosition, section: StackSections.filters.rawValue)
                target.removeFilter(indexPath: newIndex)
            }
            myUndoManager.setActionName("Delete Filter")
            UIMenuSystem.main.setNeedsRevalidate()
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
        UIMenuSystem.main.setNeedsRevalidate()
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

extension PGLSelectParmController {
    func registerUndoImageChange(imageAttribute: PGLFilterAttributeImage,
                                 oldImageList: PGLImageList) {
        if oldImageList.isEmpty() {
            return // nothing to revert to
        }
        undoManager?.registerUndo(withTarget: self ) {
            target in
            target.undoImageChange(imageAttribute: imageAttribute,
                                   oldImageList: oldImageList)
        }
        undoManager?.setActionName("Change Image")
        UIMenuSystem.main.setNeedsRevalidate()
    }

    func undoImageChange(imageAttribute: PGLFilterAttributeImage,
                         oldImageList: PGLImageList) {

        if let existingImageList = imageAttribute.inputCollection {
                // case of inputStack and input priorfilter
            registerRedoImageChange(
                imageAttribute: imageAttribute,
                oldImageList: existingImageList)

        let targetFilter = imageAttribute.aSourceFilter
        targetFilter.setUserPick(attribute: imageAttribute,
                                 imageList: oldImageList)
        // some filter classes override setUserPick

        updateAfterImagePick(imageAttribute)

        }

    }

    func registerRedoImageChange(imageAttribute: PGLFilterAttributeImage,
                                 oldImageList: PGLImageList) {
        if oldImageList.isEmpty() {
            return
        }
        undoManager?.registerUndo(withTarget: self ) {
            target in
            target.undoImageChange(imageAttribute: imageAttribute,
                                   oldImageList: oldImageList)
        }
        undoManager?.setActionName("Change Image")
        UIMenuSystem.main.setNeedsRevalidate()
    }
}



extension PGLAppStack {
    func restore( _ removedCell: PGLFilterIndent ) {
        // filter indent has filter, stack and filterPosition vars

//        let targetIndentCell = filterAt(indexPath:  destinationRow)
        let targetStack = removedCell.stack
        let removedFilter = removedCell.filter

        viewerStack = targetStack
        // reset the AppStack

        // is the removedFilter a transition that may change transition state with the move?
        // i.e. dissolve with priorFilterInput will lose an input if moved to first
        // capture initial state

//        let oldImageInput = removedFilter.getInputImageAttribute() // may be nil depending on filter type
//        let isPriorFilterInput = (oldImageInput?.parmInputState == ParmInputState.inputPriorFilter) // nil answers false

        // so move
        targetStack.activeFilters.insert(removedFilter, at: removedCell.filterPosition)

        // reset the imageInput chain
        // does first filter need inputs set? priorFilter is no longer valid
        // could have inputCollection or a childStack as working input

        // this is not needed to reset the first filter missingImageInputState
        // the state has not changed
//        if removedCell.filterPosition == 0 {
//            if let inputImageAttribute = removedFilter.getInputImageAttribute(){
//                    if inputImageAttribute.parmInputState == ParmInputState.inputPriorFilter {
//                        inputImageAttribute.setImageParmState(newState: ParmInputState.missingImageInput)
//                    }
//                }
//        }

        for index in 1 ..< targetStack.activeFilters.count {
            let priorFilter = targetStack.activeFilters[index - 1 ]
            let aFilter = targetStack.activeFilters[index]
            aFilter.setInput(image: priorFilter.outputImage(),source: targetStack.stackFilterName(priorFilter, index: index))
            aFilter.setInputImageParmState(newState: ParmInputState.inputPriorFilter)
            }

        targetStack.setFiltersStackPosition()

      //
        // DOES the existingFilter in a child stack need to get the parm parent inputStack var reset
        // and the targetStack parentAttribute reset to point to the parm parent?

    }

}


