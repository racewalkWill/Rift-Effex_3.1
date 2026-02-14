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


        if (traitCollection.userInterfaceIdiom == .phone){
            // in iOS26.3 there is a crash on the iPhone
            // ERROR Could not cast value of type 'AGXG16GFamilyComputeProgram' (0x1157133d8) to 'RiftEffects.PGLSelectParmController' (0x10264c490).
            // iPad is okay - possible Apple iOS bug
            return
        }

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

        if (traitCollection.userInterfaceIdiom == .phone){
            // in iOS26.3 there is a crash on the iPhone
            // ERROR Could not cast value of type 'AGXG16GFamilyComputeProgram' (0x1157133d8) to 'RiftEffects.PGLSelectParmController' (0x10264c490).
            // iPad is okay - possible Apple iOS bug
            return
        }

        if imageAttribute.inputParmType() == .inputChildStack {
            return  // needs work
            // restore a child stack
            // appStack.addChildStackBasic(childStack: imageAttribute.inputStack!
        } else {
            // restore the imageList
            // imageAttribute.inputParmType() == .inputPhoto
            if let existingImageList = imageAttribute.inputCollection {
                    // case of inputStack and input priorfilter
                registerRedoImageChange(
                    imageAttribute: imageAttribute,
                    oldImageList: existingImageList)

                let targetFilter = imageAttribute.aSourceFilter
                targetFilter.setUserPick(attribute: imageAttribute,
                                         imageList: oldImageList)
                    // some filter classes override setUserPick
        }

        updateAfterImagePick(imageAttribute)

        }

    }

    func registerRedoImageChange(imageAttribute: PGLFilterAttributeImage,
                                 oldImageList: PGLImageList) {

        if (traitCollection.userInterfaceIdiom == .phone){
            // in iOS26.3 there is a crash on the iPhone
            // ERROR Could not cast value of type 'AGXG16GFamilyComputeProgram' (0x1157133d8) to 'RiftEffects.PGLSelectParmController' (0x10264c490).
            // iPad is okay - possible Apple iOS bug
            return
        }

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

extension PGLStackImageContainerController {
//    var undoAction: UIAction {
//           UIAction(
//               title: PGLMenuLabel.Undo.rawValue,
//               image: UIImage(systemName: "Undo"),
//               identifier: PGLImageController.EditMenuIdentifier,
//               discoverabilityTitle: PGLMenuLabel.Undo.rawValue,
//               attributes: []
//           ) { [weak self] _ in
//               guard let self = self else { return }
//               self.undo(self.editButtonItem)
//           }
//       }
//   
//       var redoAction: UIAction {
//           UIAction(
//               title: PGLMenuLabel.Redo.rawValue,
//               image: UIImage(systemName: "Undo"),
//               identifier: PGLImageController.EditMenuIdentifier,
//               discoverabilityTitle: PGLMenuLabel.Redo.rawValue,
//               attributes: []
//           ) { [weak self] _ in
//               guard let self = self else { return }
//               self.redo(self.editButtonItem)
//           }
//       }
//
//    func undo(_ sender: UIBarButtonItem) {
//        // need to ask the undoManager if there
////        self.containerStackController.undoRemoveFilterFromStack(removedCell: nil)
//
//    }
//
//    func redo(_ sender: UIBarButtonItem) {
////        self.containerStackController.undoRemoveFilterFromStack(removedCell: nil)
//    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        NSLog(#function + String(describing: self ) + (String(describing: action)))
          if action == #selector(paste(_:)) {

              let hasImages =   UIPasteboard.general.hasImages
//              NSLog(#function + "hasImages:\(hasImages) "  + String(describing: self ))
              return hasImages
          }

        if action == #selector(copy(_ : )) {
//            NSLog(#function  + String(describing: self ) +  " #selector(copy) ")
            return true // image controller always has an image.. maybe CIImage.empty

        }

        if action == UndoActionSelector  {
            NSLog(#function  + String(describing: self ) +  " #selector(undo) ")
                //            NSLog("undoManager \(String(describing: undoManager))")
            let isUndoable = undoManager?.canUndo ?? false
                //            NSLog("undoManager canUndo \(isUndoable)")
            return isUndoable
        }
        if action == RedoActionSelector {
                //            NSLog("undoManager \(String(describing: undoManager))")
            let isRedoable = undoManager?.canRedo ?? false
                //            NSLog("undoManager isRedoable \(isRedoable)")
            return isRedoable
        }

//        else {
//            return super.canPerformAction(action, withSender: sender)
        return false  // do not run up the UIResponder chain
//        }

    }

    override func copy(_ sender: Any?) {
        splitViewController?.copy(sender)
    }

    override func paste(_ sender: Any?) {
        splitViewController?.paste(sender)
    }


}


