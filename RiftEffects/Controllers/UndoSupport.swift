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
    // Thin wrapper: the undo is registered on the persistent appStack so the
    // shared undo manager does not retain this controller. See extension PGLAppStack.
    func registerUndoRemoveFilter(_ removedCell: PGLFilterIndent ) {
        appStack.registerUndoRemoveFilter(removedCell)
    }
}

extension PGLMainFilterController {
    // Thin wrapper — registers the undo on the persistent appStack (no controller retention).
    func registerUndoAddFilter(_ newFilter: PGLSourceFilter) {
        appStack.registerUndoAddFilter(newFilter)
    }
}

extension PGLSelectParmController {
    // Thin wrapper: registers the image-change undo on the persistent appStack so
    // this controller is not retained by the shared undo manager. The iPhone guard
    // is kept here (registration-time) to preserve prior behavior and avoid the
    // iOS26.3 cast crash noted below.
    func registerUndoImageChange(imageAttribute: PGLFilterAttributeImage,
                                 oldImageList: PGLImageList) {
        if (traitCollection.userInterfaceIdiom == .phone){
            // in iOS26.3 there is a crash on the iPhone
            // ERROR Could not cast value of type 'AGXG16GFamilyComputeProgram' to 'RiftEffects.PGLSelectParmController'.
            // iPad is okay - possible Apple iOS bug
            return
        }
        appStack.registerUndoImageChange(imageAttribute: imageAttribute, oldImageList: oldImageList)
    }
}



extension PGLAppStack {

    // MARK: - Undo (retargeted to the persistent appStack)
    // These register on the app-lifetime appStackUndoManager with
    // `withTarget: self` (the persistent PGLAppStack) so the transient view
    // controllers are NOT retained by the undo stack. NSUndoManager retains its
    // target strongly, which previously pinned every controller that registered
    // an undo. UI refresh now happens through the existing NotificationCenter
    // posts that the on-screen controllers already observe.

    // Delete Filter ------------------------------------------------------------
    func registerUndoRemoveFilter(_ removedCell: PGLFilterIndent) {
        appStackUndoManager.registerUndo(withTarget: self) { appStack in
            appStack.undoRemoveFilter(removedCell)
        }
        appStackUndoManager.setActionName("Delete Filter")
        UIMenuSystem.main.setNeedsRevalidate()
    }

    func undoRemoveFilter(_ removedCell: PGLFilterIndent) {
        // undo of a delete restores the removed filter
        restore(removedCell)
        postStackChange()

        let flatCells = flatCellFilters
        guard let flatArrayPosition = flatCells.firstIndex(where: {
            $0.stack == removedCell.stack
            && $0.filter.stackPosition == removedCell.filter.stackPosition
            && $0.filter.filterName == removedCell.filter.filterName })
            else { return }
        appStackUndoManager.registerUndo(withTarget: self) { appStack in
            appStack.redoRemoveFilter(at: flatArrayPosition)
        }
        appStackUndoManager.setActionName("Delete Filter")
        UIMenuSystem.main.setNeedsRevalidate()
    }

    func redoRemoveFilter(at flatArrayPosition: Int) {
        // redo of a delete removes the filter again — the model half of
        // PGLStackController.removeFilter(indexPath:); UI refresh via postStackChange.
        let flatCells = flatCellFilters
        guard flatArrayPosition < flatCells.count else { return }
        let cellIndent = flatCells[flatArrayPosition]
        _ = moveTo(filterIndent: cellIndent)
        _ = cellIndent.stack.removeFilter(position: cellIndent.filterPosition)
        registerUndoRemoveFilter(cellIndent)
        resetViewStack()
        postStackChange()
        if showFilterImage { postSelectActiveStackRow() }
    }

    // Add Filter ---------------------------------------------------------------
    func registerUndoAddFilter(_ newFilter: PGLSourceFilter) {
        appStackUndoManager.registerUndo(withTarget: self) { appStack in
            appStack.undoAddFilter(oldFilter: newFilter)
        }
        appStackUndoManager.setActionName("Add Filter")
        UIMenuSystem.main.setNeedsRevalidate()
    }

    func undoAddFilter(oldFilter: PGLSourceFilter) {
        // undo of an add removes the just-added filter.
        // viewerStack.undoAddFilter posts PGLCurrentFilterChange (render only), so
        // also postStackChange() to refresh the stack table.
        viewerStack.undoAddFilter(oldFilter: oldFilter)
        postStackChange()
        appStackUndoManager.registerUndo(withTarget: self) { appStack in
            appStack.redoAddFilter(oldFilter)
        }
        appStackUndoManager.setActionName("Add Filter")
        UIMenuSystem.main.setNeedsRevalidate()
    }

    func redoAddFilter(_ filter: PGLSourceFilter) {
        // redo of an add re-adds the filter — the model half of
        // PGLMainFilterController.performBasicPick(filter:).
        setFilterChangeModeToAdd()
        viewerStack.performFilterPick(selectedFilter: filter)
        filter.addChildSequenceStack(appStack: self)
        resetCellFilters()
        postStackChange()
        registerUndoAddFilter(filter)
    }

    // Change Image -------------------------------------------------------------
    func registerUndoImageChange(imageAttribute: PGLFilterAttributeImage, oldImageList: PGLImageList) {
        if oldImageList.isEmpty() { return } // nothing to revert to
        appStackUndoManager.registerUndo(withTarget: self) { appStack in
            appStack.undoImageChange(imageAttribute: imageAttribute, oldImageList: oldImageList)
        }
        appStackUndoManager.setActionName("Change Image")
        UIMenuSystem.main.setNeedsRevalidate()
    }

    func undoImageChange(imageAttribute: PGLFilterAttributeImage, oldImageList: PGLImageList) {
        if imageAttribute.inputParmType() == .inputChildStack {
            return // child-stack restore not supported (matches prior behavior)
        }
        if let existingImageList = imageAttribute.inputCollection {
            registerRedoImageChange(imageAttribute: imageAttribute, oldImageList: existingImageList)
            let targetFilter = imageAttribute.aSourceFilter
            targetFilter.setUserPick(attribute: imageAttribute, imageList: oldImageList)
        }
        // UI refresh (was PGLSelectParmController.updateAfterImagePick):
        // reload the parm table and redraw the render surface.
        NotificationCenter.default.post(name: PGLReloadParmTableView, object: nil)
        postFilterChangeRedraw()
    }

    func registerRedoImageChange(imageAttribute: PGLFilterAttributeImage, oldImageList: PGLImageList) {
        if oldImageList.isEmpty() { return }
        appStackUndoManager.registerUndo(withTarget: self) { appStack in
            appStack.undoImageChange(imageAttribute: imageAttribute, oldImageList: oldImageList)
        }
        appStackUndoManager.setActionName("Change Image")
        UIMenuSystem.main.setNeedsRevalidate()
    }

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

        if  action == #selector(undo)  {
            NSLog(#function  + String(describing: self ) +  " #selector(undo) ")
                //            NSLog("undoManager \(String(describing: undoManager))")
            let isUndoable = undoManager?.canUndo ?? false
                //            NSLog("undoManager canUndo \(isUndoable)")
            return isUndoable
        }
        if  action == #selector(redo)  {
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

    @objc  func undo( _: Any?) {
  //        NSLog(#function + String(describing: self ))
        undoManager?.undo() 
      }

      @objc  func redo( _: Any?) {
  //          NSLog(#function + String(describing: self ))
            undoManager?.redo()
        }


}


