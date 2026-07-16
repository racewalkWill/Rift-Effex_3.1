//
//  PGLFilterImageContainerController.swift
//  RiftEffects
//
//  Created by Will on 5/23/22.
//  Copyright © 2022 Will Loew-Blosser. All rights reserved.
//

import UIKit
import os

/// iPhone container for Filter and Image controllers side by side
class PGLFilterImageContainerController: PGLTwoColumnSplitController {
    // 2024-05-22 changed to use the super class PGLColumns.control and PGLColumns.imageViewer
    // removed duplicate vars var containerImageController,containerFilterController
    // two vars pointed to the same controller - memory issue

        // an opaque type is returned from addObservor
    var notifications: [NSNotification.Name : Any] = [:]

    deinit {
//        releaseVars()
        Logger(subsystem: LogSubsystem, category: LogMemoryRelease).info("\( String(describing: self) + " - deinit" )")
    }


    override func viewDidLoad() {
        var containerImageController: PGLCompactImageController?
        var containerFilterController: PGLMainFilterController?
        
        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
        super.viewDidLoad()

        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        containerFilterController = storyboard.instantiateViewController(withIdentifier: "FilterTable") as? PGLMainFilterController

        containerImageController = storyboard.instantiateViewController(withIdentifier: "PGLImageController") as? PGLCompactImageController
        if (containerImageController == nil) || (containerFilterController == nil) {
            return // give up no controller
        }
        loadViewColumns(controller: containerFilterController!, imageViewer: containerImageController! )

//        setMoreBtnMenu()
//        setTemplateBtnMenu()
        setHelpBtnMenu()



        navigationController?.isToolbarHidden = true
        // should make the buttons on the filter controller toolbar visible
        // because this controller isToolbarHidden

//         let myCenter =  NotificationCenter.default

            ///FilterImageContainer does not have any changes to make for animation state changes
//        cancellable = myCenter.publisher(for: PGLAnimationStateChanged)


    }

    override func viewIsAppearing(_ animated: Bool) {
        if columns == nil {
            return
        }
        layoutViews( columns!.imageViewer.view, columns!.control.view)
        super.viewIsAppearing(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        // Tear down only on an actual pop/dismiss. viewDidDisappear also fires when
        // another controller is pushed on top; releasing the children then makes this
        // instance a zombie when navigation comes back to it — the filter collection
        // view stays in the hierarchy while its deallocated diffable dataSource (a weak
        // UICollectionView reference) goes nil, and the focus system crashes preparing
        // a cell: "UICollectionView dataSource is not set".
        guard isMovingFromParent || isBeingDismissed else {
            super.viewDidDisappear(animated)
            return
        }

        if let imageViewerController = imageController() {
            imageViewerController.releaseVars()
            imageViewerController.view.removeFromSuperview()
            imageViewerController.removeFromParent()
        }

        // NOTE: the filter controller is columns.control (columns.imageViewer is the
        // PGLCompactImageController). Remove the view too — a removeFromParent alone
        // leaves the stale collection view in the hierarchy.
        if let containerFilterController = columns?.control as? PGLMainFilterController {
            containerFilterController.view.removeFromSuperview()
            containerFilterController.removeFromParent()
        }
        columns = nil
        super.viewDidDisappear(animated)
    }



    @IBAction func newStackBtnClick(_ sender: UIBarButtonItem) {
        // trash icon to start a new stack
        guard let imageViewerController = imageController()
            else { return }
        imageViewerController.newStackActionBtn(sender)
    }

    @IBOutlet weak var newTrashBtn: UIBarButtonItem!

    @IBOutlet weak var recordBtn: UIBarButtonItem!
    
    @IBAction func recordBtnAction(_ sender: UIBarButtonItem) {
        guard let containerImageController = imageController()
            else { return }
        containerImageController.recordButtonTapped(controllerRecordBtn:sender)
    }


    @IBOutlet weak var toggleAnimationPauseBtn: UIBarButtonItem!
    

    @IBAction func toggleAnimationPause(_ sender: UIBarButtonItem) {
        let updateNotification = Notification(name:PGLPauseAnimation)
               NotificationCenter.default.post(name: updateNotification.name, object: nil, userInfo: nil )

    }
    
    @IBOutlet weak var helpBtn: UIBarButtonItem!
    
        //MARK: Toolbar buttons actions

  
        // MARK: Menu


    func setHelpBtnMenu() {
        guard imageController() != nil
            else { return }

        // [weak self] + re-fetch imageController() inside the handlers: capturing
        // self or the image controller strongly here creates a retain cycle
        // (self -> helpBtn.menu -> UIAction -> closure -> self) that leaks both
        // this container and its image controller.
        let helpMenu = UIAction.init(title: PGLMenuLabel.Help.rawValue, image: UIImage(systemName: "folder"), identifier: PGLImageController.LibraryMenuIdentifier, discoverabilityTitle: "Help", attributes: [], state: UIMenuElement.State.off) { [weak self]
            action in
            guard let self, let imageViewerController = self.imageController() else { return }
            imageViewerController.helpBtnAction(self.helpBtn)

        }


        let contextMenu = UIMenu(title: "",
                                 children: [ helpMenu ,
                                             UIAction(title: PGLMenuLabel.Privacy.rawValue, image:UIImage(systemName: "info.circle")) { [weak self]
            action in
            guard let self, let imageViewerController = self.imageController() else { return }
            imageViewerController.displayPrivacyPolicy(self.helpBtn)
        }
            ] )
        helpBtn.menu = contextMenu
    }


        // MARK: - Navigation

        // In a storyboard-based application, you will often want to do a little preparation before navigation
        override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            // Get the new view controller using segue.destination.
            // Pass the selected object to the new view controller.
            let segueId = segue.identifier

            Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function) + \(String(describing: segueId))")

        }

}
