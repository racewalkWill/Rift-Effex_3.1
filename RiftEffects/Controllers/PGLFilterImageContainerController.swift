//
//  PGLFilterImageContainerController.swift
//  RiftEffects
//
//  Created by Will on 5/23/22.
//  Copyright © 2022 Will Loew-Blosser. All rights reserved.
//

import UIKit
import os

/// container for Filter and Image controllers side by side
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

        setMoreBtnMenu()

        navigationController?.isToolbarHidden = true
        // should make the buttons on the filter controller toolbar visible
        // because this controller isToolbarHidden

        let myCenter =  NotificationCenter.default

        cancellable = myCenter.publisher(for: PGLAnimationStateChanged)
            .sink() {
            [weak self]
            myUpdate in
            if let userDataDict = myUpdate.userInfo {
                if let newState = userDataDict["animationState"]  as? PGLAnimationState  {
                    containerImageController?.setAnimation(newState , self!.toggleAnimationPauseBtn)
                }
            }
        }
        publishers.append(cancellable!)
    }

    override func viewIsAppearing(_ animated: Bool) {
        if columns == nil {
            return
        }
        layoutViews( columns!.imageViewer.view, columns!.control.view)
        super.viewIsAppearing(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        guard let imageViewerController = imageController()
            else { return }

        imageViewerController.releaseVars()
        imageViewerController.removeFromParent()

//        containerImageController = nil

        guard let containerFilterController = columns?.imageViewer as? PGLMainFilterController
            else { return }
        containerFilterController.removeFromParent()
//        containerFilterController = nil
    }

//    @IBAction func addFilterBtn(_ sender: UIBarButtonItem) {
//        // Segue back to the stackController
//        self.navigationController?.popViewController(animated: true)
//    }

//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        guard let imageViewerController = imageController()
//            else { return }
//        imageViewerController.setAnimationToggleBtn(barButtonItem: toggleAnimationPauseBtn)
//    }

    @IBAction func newStackBtnClick(_ sender: UIBarButtonItem) {
        // trash icon to start a new stack
        guard let imageViewerController = imageController()
            else { return }
        imageViewerController.newStackActionBtn(sender)
    }
    
    @IBAction func randomBtnClick(_ sender: UIBarButtonItem) {
        guard let containerImageController = imageController()
            else { return }
        containerImageController.randomBtnAction(sender)

    }
    @IBAction func moreBtnClick(_ sender: UIBarButtonItem) {
        // see the setMoreBtnMenu()

    }

    @IBOutlet weak var moreBtn: UIBarButtonItem!

    @IBOutlet weak var newTrashBtn: UIBarButtonItem!


    @IBAction func helpBtnClick(_ sender: UIBarButtonItem) {
        guard let containerImageController = imageController()
            else { return }
        containerImageController.helpBtnAction(sender)
        
    }
    @IBOutlet weak var randomBtn: UIBarButtonItem!

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
    
    
        //MARK: Toolbar buttons actions

  
        // MARK: Menu
    func setMoreBtnMenu() {
            //      if traitCollection.userInterfaceIdiom == .phone {
        guard let containerImageController = imageController()
            else { return }
        let libraryMenu = UIAction.init(title: "Library..", image: UIImage(systemName: "folder"), identifier: PGLImageController.LibraryMenuIdentifier, discoverabilityTitle: "Library", attributes: [], state: UIMenuElement.State.off) {
            action in
           containerImageController.openStackActionBtn(self.moreBtn)

        }

        if let mySplitView =  splitViewController as? PGLSplitViewController {
                //                if traitCollection.userInterfaceIdiom == .pad {
                //                    libraryMenu.attributes = [.disabled] // always disabled on iPad
                //                } else {
            if !mySplitView.stackProviderHasRows() {
                libraryMenu.attributes = [.disabled]
                    //                    }
            }

        }
        let contextMenu = UIMenu(title: "",
                                 children: [ libraryMenu
                                             ,
             UIAction(title: "Demo..", image:UIImage(systemName: "pencil.circle")) {
             action in
            containerImageController.loadDemoStack(self.moreBtn)
        },
            UIAction(title: "Save..", image:UIImage(systemName: "pencil")) {
            action in
                // self.saveStackAlert(self.moreBtn)
            containerImageController.saveStackActionBtn(self.moreBtn)
        },
            UIAction(title: "Export to Photos", image:UIImage(systemName: "pencil.circle")) {
            action in
            containerImageController.saveToPhotoLibrary()

        },
             UIAction(title: "Record", image:UIImage(systemName: "recordingtape")) {
            action in
            containerImageController.recordButtonTapped(controllerRecordBtn: self.recordBtn)
        },
            UIAction(title: "Privacy.. ", image:UIImage(systemName: "info.circle")) {
            action in
            containerImageController.displayPrivacyPolicy(self.moreBtn)
        }

        ])
        moreBtn.menu = contextMenu
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
