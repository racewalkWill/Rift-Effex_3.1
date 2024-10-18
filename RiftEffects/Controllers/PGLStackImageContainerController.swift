//
//  PGLStackImageContainerController.swift
//  RiftEffects
//
//  Created by Will on 5/16/22.
//  Copyright © 2022 Will Loew-Blosser. All rights reserved.
//

import UIKit
import os
class PGLStackImageContainerController: PGLTwoColumnSplitController {
        //  2024-05-22 changed to use the super class PGLColumns.control and PGLColumns.imageViewer
        // removed duplicate vars var containerImageController,containerStackController
        // two vars pointed to the same controller - memory issue

    deinit {
//        releaseVars()
        Logger(subsystem: LogSubsystem, category: LogMemoryRelease).info("\( String(describing: self) + " - deinit" )")
    }

    override func viewDidLoad() {
        var containerImageController: PGLCompactImageController?
        var containerStackController: PGLStackController?
        super.viewDidLoad()
        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
        // Do any additional setup after loading the view.



//        navigationItem.title = "Effects"  //viewerStack.stackName

        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        containerStackController = storyboard.instantiateViewController(withIdentifier: "StackController") as? PGLStackController

        containerImageController = storyboard.instantiateViewController(withIdentifier: "PGLImageController") as? PGLCompactImageController
        if (containerImageController == nil) || (containerStackController == nil) {
            return // give up no controller
        }

        loadViewColumns(controller: containerStackController!, imageViewer: containerImageController!)

        setMoreBtnMenu() // needs the child imageController loaded 
        // no toolbar on the stackImageContainerController so  toolbar buttons don't show
//        containerStackController?.addToolBarButtons(toController: self)

        setUpdateEditButton()
        updateNavigationBar()
//        setNeedsStatusBarAppearanceUpdate()

        // if the stack is empty go to the addFilter directly
        if containerStackController?.appStack.viewerStack.isEmptyStack() ?? true {
            addFilterBtn(UIBarButtonItem())
        }

        let myCenter =  NotificationCenter.default

        cancellable = myCenter.publisher(for: PGLAnimationStateChanged)
            .sink() {
            [weak self]
            myUpdate in
            if let userDataDict = myUpdate.userInfo {
                // isViewLoaded or isBeingPresented??
                if let newState = userDataDict["animationState"]  as? PGLAnimationState  {
                    containerImageController?.setAnimation(newState , self!.toggleAnimationPauseBtn)
//                    NSLog(#function + "PGLStackImageContainer PGLAnimationStateChanged toggleAnimationPauseBtn \(self?.toggleAnimationPauseBtn)")

                }
                self?.navigationController?.setNeedsStatusBarAppearanceUpdate()
            }
        }

        cancellable = myCenter.publisher(for: PGLStackChange)
            .sink() { [weak self]
            myUpdate in
            Logger(subsystem: LogSubsystem, category: LogNavigation).info( "PGLStackImageContainerController  notificationBlock PGLStackChange")

            guard let self = self else { return } // a released object sometimes receives the notification
                          // the guard is based upon the apple sample app 'Conference-Diffable'
            self.updateNavigationBar()
                // flips the 'Edit' button hidden or visible
                guard let imageViewerController = imageController()
                    else { return }
                imageViewerController.setAnimationToggleBtn(barButtonItem: toggleAnimationPauseBtn)
        }
        publishers.append(cancellable!)

    }

    override func viewWillAppear(_ animated: Bool) {

        guard let imageViewerController = imageController()
            else { return }

        /// THIS makes the pause/play button appear !
        imageViewerController.setAnimationToggleBtn(barButtonItem: toggleAnimationPauseBtn)

            //        NSLog(#function + "PGLImageController toggleAnimationPauseBtn \(toggleAnimationPauseBtn)")


        updateNavigationBar()
    }



    @IBAction func helpBtnClick(_ sender: UIBarButtonItem) {
        guard let imageViewerController = imageController()
            else { return }
        imageViewerController.helpBtnAction(sender)
    }

    @IBOutlet weak var randomBtn: UIBarButtonItem!

    @IBAction func randomBtnClick(_ sender: UIBarButtonItem) {
        guard let imageViewerController = imageController()
            else { return }
        guard let stackController = columns?.control as? PGLStackController
        else {return }
        imageViewerController.randomBtnAction(sender)
        stackController.updateDisplay()
        updateNavigationBar()
    }

    @IBOutlet weak var moreBtn: UIBarButtonItem!

    @IBOutlet weak var newTrashBtn: UIBarButtonItem!

    @IBAction func newTrashBtnAction(_ sender: UIBarButtonItem) {
        guard let imageViewerController = imageController()
            else { return }

        imageViewerController.newStackActionBtn(sender)



    }

    @IBOutlet weak var recordBtyn: UIBarButtonItem!
    
    @IBAction func recordBtnAction(_ sender: UIBarButtonItem) {
        guard let imageViewerController = imageController()
            else { return }
        imageViewerController.recordButtonTapped(controllerRecordBtn:sender)
    }
    @IBOutlet weak var toggleAnimationPauseBtn: UIBarButtonItem!
    
    @IBAction func toggleAnimationPause(_ sender: UIBarButtonItem) {
        let updateNotification = Notification(name:PGLPauseAnimation)
               NotificationCenter.default.post(name: updateNotification.name, object: nil, userInfo: nil )
        // could just toggle the sender from here without notification dispatch?
        guard let imageViewerController = imageController()
            else { return }
        imageViewerController.setAnimationToggleBtn(barButtonItem: sender)

    }
    
    func setMoreBtnMenu() {
            //      if traitCollection.userInterfaceIdiom == .phone {
        guard let imageViewerController = imageController()
            else { return }
        let libraryMenu = UIAction.init(title: "Library..", image: UIImage(systemName: "folder"), identifier: PGLImageController.LibraryMenuIdentifier, discoverabilityTitle: "Library", attributes: [], state: UIMenuElement.State.off) {
            action in
           imageViewerController.openStackActionBtn(self.moreBtn)

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
            imageViewerController.loadDemoStack(self.moreBtn)
        },
            UIAction(title: "Save..", image:UIImage(systemName: "pencil")) {
            action in
                // self.saveStackAlert(self.moreBtn)
            imageViewerController.saveStackActionBtn(self.moreBtn)
        },

//            UIAction(title: "Export to Photos", image:UIImage(systemName: "pencil.circle")) {
//            action in
//            imageViewerController.saveToPhotoLibrary()
//        },
             UIAction(title: "Record", image:UIImage(systemName: "recordingtape")) {
            action in
            imageViewerController.recordButtonTapped(controllerRecordBtn: self.recordBtyn)

        },

            UIAction(title: "Privacy.. ", image:UIImage(systemName: "info.circle")) {
            action in
            imageViewerController.displayPrivacyPolicy(self.moreBtn)
        }
        ])
        moreBtn.menu = contextMenu
    }

    func setUpdateEditButton() {
        guard let stackTarget = columns?.control as? PGLStackController
        else {return }
       // update the edit button
       if (stackTarget.tableView.isEditing) {
                // change to "Done"
                stackEditBtn!.title = "Done"
       } else {
           stackEditBtn!.title = "Edit" }
    }

    func updateNavigationBar() {

//        self.navigationItem.title = "Rift-Effex"
        guard let stackTarget = columns?.control as? PGLStackController
        else {return }
//        self.navigationItem.title = stackTarget.title

        stackEditBtn.isHidden = stackTarget.appStack.viewerStack.isEmptyStack()
        setNeedsStatusBarAppearanceUpdate()
    }


    @objc func toggleEditing() {
        guard let myStackTarget = columns?.control as? PGLStackController
        else {return }

        guard let myTableView = myStackTarget.tableView else {
            return
        }
        myTableView.setEditing(!myTableView.isEditing, animated: true)
        setUpdateEditButton()
    }

    @IBAction func addFilterBtn(_ sender: Any) {
        guard let myStackTarget = columns?.control as? PGLStackController
        else {return }
        myStackTarget.appStack.setFilterChangeModeToAdd()
        myStackTarget.postFilterNavigationChange()
        performSegue(withIdentifier: "showFilterImageContainer", sender: self)
    }

    @IBAction func stackEditBtn(_ sender: UIBarButtonItem) {
        toggleEditing()
    }
    
    @IBOutlet weak var stackEditBtn: UIBarButtonItem!
    
    @IBOutlet weak var openParmsBtn: UIBarButtonItem!
    
    @IBAction func openParmsAction(_ sender: UIBarButtonItem) {
        guard let myStackTarget = columns?.control as? PGLStackController
        else {return }
        myStackTarget.segueToParmController() // does the current filter need to be set?
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
