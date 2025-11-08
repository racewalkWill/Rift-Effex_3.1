//
//  PGLStackImageContainerController.swift
//  RiftEffects
//
//  Created by Will on 5/16/22.
//  Copyright © 2022 Will Loew-Blosser. All rights reserved.
//

import UIKit
import os
/// iPhone two column Stack and Image
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
        setHelpBtnMenu()
        setTemplateBtnMenu()

        // no toolbar on the stackImageContainerController so  toolbar buttons don't show
//        containerStackController?.addToolBarButtons(toController: self)

        updateNavigationBar()
//        setNeedsStatusBarAppearanceUpdate()

        // if the stack is empty go to the addFilter directly
        if containerStackController?.appStack.viewerStack.isEmptyStack() ?? true {

            guard let myStackTarget = columns?.control as? PGLStackController
            else {return }
            myStackTarget.appStack.setFilterChangeModeToAdd()
            myStackTarget.postFilterNavigationChange()
            performSegue(withIdentifier: "showFilterImageContainer", sender: self)
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
//                    NSLog(#function + "PGLStackImageContainer PGLAnimationStateChanged toggleAnimationPauseBtn \(String(describing: self?.toggleAnimationPauseBtn))")

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
        super.viewWillAppear(animated)
    }





    @IBOutlet weak var templateBtn: UIBarButtonItem!

//    @IBAction func randomBtnClick(_ sender: UIBarButtonItem) {
//        guard let imageViewerController = imageController()
//            else { return }
//        guard let stackController = columns?.control as? PGLStackController
//        else {return }
//        imageViewerController.randomBtnAction(sender)
//        stackController.updateDisplay()
//        updateNavigationBar()
//    }

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
        var musicItemState = UIMenuElement.Attributes.keepsMenuPresented
        if traitCollection.userInterfaceIdiom == .phone {
            musicItemState = UIMenuElement.Attributes.hidden
        }
        guard let imageViewerController = imageController()
            else { return }
        let libraryMenu = UIAction.init(title: PGLMenuLabel.Library.rawValue, image: UIImage(systemName: "folder"), identifier: PGLImageController.LibraryMenuIdentifier, discoverabilityTitle: "Library", attributes: [], state: UIMenuElement.State.off) {
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
         UIAction(title: PGLMenuLabel.Save.rawValue, image:UIImage(systemName: "square.and.arrow.down")) {
            action in
                // self.saveStackAlert(self.moreBtn)
            imageViewerController.saveStackActionBtn(self.moreBtn)
        },


         UIAction(title: PGLMenuLabel.Record.rawValue, image:UIImage(systemName: "recordingtape")) {
            action in
            imageViewerController.recordButtonTapped(controllerRecordBtn: self.moreBtn)

        },

         UIAction(title: PGLMenuLabel.Music.rawValue, image:UIImage(systemName: "music.note.list"),attributes: (musicItemState)) {
            action in
            imageViewerController.musicButtonTapped(controllerMusicBtn: self.moreBtn)

        } ,
//          UIAction(title: PGLMenuLabel.Optimize.rawValue, image:UIImage(systemName: "flag.circle.fill")) {
//             action in
//            imageViewerController.optimizeStack(controllerMusicBtn: self.moreBtn)
//         }
        ])
        moreBtn.menu = contextMenu
    }
    @IBOutlet weak var helpBtn: UIBarButtonItem!
    
    func setHelpBtnMenu() {
        guard let imageViewerController = imageController()
            else { return }

        let helpMenu = UIAction.init(title: PGLMenuLabel.Help.rawValue, image: UIImage(systemName: "folder"), identifier: PGLImageController.LibraryMenuIdentifier, discoverabilityTitle: "Help", attributes: [], state: UIMenuElement.State.off) { [weak self]
            action in
            guard let theHelpBtn = self?.helpBtn else { return }
            imageViewerController.helpBtnAction(theHelpBtn)

        }

        let contextMenu = UIMenu(title: "",
                                 children: [ helpMenu ,
            UIAction(title: PGLMenuLabel.Privacy.rawValue, image:UIImage(systemName: "info.circle")) { [weak self]
            action in
            guard let theHelpBtn = self?.helpBtn else { return }
            imageViewerController.displayPrivacyPolicy(theHelpBtn)
        }
            ] )
        helpBtn.menu = contextMenu
    }

    func setTemplateBtnMenu() {
        guard let imageViewerController = imageController()
            else { return }
        let imageName = "photo.stack"
        let contextMenu = UIMenu(title: "",
                                 children: [
                                    UIDeferredMenuElement.uncached { [weak self] completion in
                                        let actions = [
                                            UIAction.init(title: PGLMenuLabel.random.rawValue, image: UIImage(systemName: "folder"), identifier: PGLImageController.TemplateMenuIdentifier, discoverabilityTitle: "Template", attributes: [], state: UIMenuElement.State.off) {
                                                [weak self ]
                                                action in
                                                guard self != nil else { return }
                                                imageViewerController.templateBtnAction(imageViewerController.templateBtn)
                                            } ,
                                            UIAction(title: PGLMenuLabel.Guide.rawValue , image: UIImage(systemName: "hourglass"), state: PGLDemo.GuideMode == true ? .on : .off, handler: { (action) in
                                                PGLDemo.toggleGuideMode()
                                                let stackNotification = Notification(name:PGLStackChange)
                                                NotificationCenter.default.post(stackNotification)
                                                        }),
                                            UIAction(title: PGLMenuLabel.Blend.rawValue, image:UIImage(systemName: imageName)) {
                                                [weak self ]
                                                action in
                                                guard self != nil else { return }
                                                let demoGenerator = PGLDemo()
                                                demoGenerator.iPhoneCompact = false  // now on the iPad
                                                demoGenerator.blendTemplate(appStack: imageViewerController.appStack)
                                            },
                                            UIAction(title: PGLMenuLabel.Sequence.rawValue, image:UIImage(systemName: imageName)) {
                                                [weak self ]
                                                action in
                                                guard self != nil else { return }
                                                imageViewerController.loadDemoStack(imageViewerController.templateBtn)
                                            },
                                            UIAction(title: PGLMenuLabel.Edge.rawValue, image:UIImage(systemName: imageName)) {
                                                [weak self ]
                                                action in
                                                guard self != nil else { return }
                                                let demoGenerator = PGLDemo()
                                                demoGenerator.edgeTemplate(appStack: imageViewerController.appStack)
                                            },

                                            // place holder - change to demo methods
                                            UIAction(title: PGLMenuLabel.Tone.rawValue, image:UIImage(systemName: imageName)) {
                                                [weak self ]
                                                action in
                                                guard self != nil else { return }
                                                let demoGenerator = PGLDemo()
                                                demoGenerator.toneTemplate(appStack: imageViewerController.appStack)
                                            },
                                            // place holder - change to demo methods
                                            UIAction(title: PGLMenuLabel.Kaleidoscope.rawValue, image:UIImage(systemName: imageName)) {
                                                [weak self ]
                                                action in
                                                guard self != nil else { return }
                                                let demoGenerator = PGLDemo()
                                                demoGenerator.iPhoneCompact = false  // now on the iPad
                                                demoGenerator.kaleidoscopeTemplate(appStack: imageViewerController.appStack)

                                            },
                                        ]// actions closing bracket
                                        completion(actions)
                                    } // closing uncached bracket
        ]) // ] is for childern and ) is for UIManu

     templateBtn.menu = contextMenu

    }


    func updateNavigationBar() {

//        self.navigationItem.title = "Rift-Effex"
  
        guard let stackTarget = columns?.control as? PGLStackController
        else {return }
        self.navigationItem.title = stackTarget.appStack.outputStack.stackName
        setNeedsStatusBarAppearanceUpdate()
    }





    
    func addFilterBtn() {
        performSegue(withIdentifier: "showFilterImageContainer", sender: self)
    }


    
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
