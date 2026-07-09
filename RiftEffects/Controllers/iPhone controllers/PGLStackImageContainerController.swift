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
class PGLStackImageContainerController: PGLTwoColumnSplitController, @MainActor UIEditMenuInteractionDelegate {
        //  2024-05-22 changed to use the super class PGLColumns.control and PGLColumns.imageViewer
        // removed duplicate vars var containerImageController,containerStackController
        // two vars pointed to the same controller - memory issue

    var editMenuInteraction: UIEditMenuInteraction?
    
    var containerImageController: PGLCompactImageController?
    var containerStackController: PGLStackController?

    override var undoManager: UndoManager? {
           // Return a shared  undo manager
        if let myAppStack = appStack {
            return myAppStack.appStackUndoManager }
        else {
             return  super.undoManager
            }
       }

    var appStack: PGLAppStack?

    deinit {
//        releaseVars()
        Logger(subsystem: LogSubsystem, category: LogMemoryRelease).info("\( String(describing: self) + " - deinit" )")
    }

    override func viewDidLoad() {

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

        // should implement delegate methods
         editMenuInteraction = UIEditMenuInteraction(delegate: self)
         if editMenuInteraction != nil {
             view.addInteraction(editMenuInteraction!)
             editBtn.menu = setEditBtnMenu()
            }

//        setEditBtnMenu(hasClipBoardImages: false) // default

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
                    self?.containerImageController?.setAnimation(newState , self!.toggleAnimationPauseBtn)
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

        // UIPasteboard.changedNotification

        cancellable = myCenter.publisher(for: UIPasteboard.changedNotification)
            .sink() { [weak self]
            myUpdate in
                Logger(subsystem: LogSubsystem, category: LogNavigation).info("\(#function) UIPasteboard.changedNotification")

                guard self != nil else { return } // a released object sometimes receives the notification
                          // the guard is based upon the apple sample app 'Conference-Diffable'
      //          self.setEditBtnMenu(hasClipBoardImages: UIPasteboard.general.hasImages   )
                // flips the 'Edit' button hidden or visible

        }
        publishers.append(cancellable!)

        guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
            else { Logger(subsystem: LogSubsystem, category: LogCategory).fault (" PGLStackImageContainerController viewDidLoad error AppDelegate not loaded")
                return
        }
        appStack = myAppDelegate.appStack


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


    @IBOutlet weak var editBtn: UIBarButtonItem!

    @IBAction func editBtnAction(_ sender: UIBarButtonItem) {
        let configuration = UIEditMenuConfiguration(identifier: nil, sourcePoint: .zero)
           if let interaction = editMenuInteraction {
               // Present the edit menu interaction.
       //        NSLog(#function + String(describing: self))
               interaction.presentEditMenu(with: configuration)
               // same as protocol UIEditMenuInteractionDelegate #editMenuInteraction(_:menuFor:suggestedActions:)
           }
    }

    func editMenuInteraction(
        _ interaction: UIEditMenuInteraction,
        menuFor configuration: UIEditMenuConfiguration,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {

        let myEditMenu = setEditBtnMenu()

        return myEditMenu



//        menu.addObserver(self, forKeyPath: "selectedElement", options: .new, context: nil)
//        menu.addObserver(self, forKeyPath: "isEnabled", options: .new, context: nil)

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
        guard imageController() != nil
            else { return }
        // [weak self] + re-fetch imageController() inside each handler. Capturing
        // self or the image controller strongly here leaks both (self -> moreBtn.menu
        // -> UIAction -> closure -> self is a retain cycle).
        let libraryMenu = UIAction.init(title: PGLMenuLabel.Library.rawValue, image: UIImage(systemName: "folder"), identifier: PGLImageController.LibraryMenuIdentifier, discoverabilityTitle: "Library", attributes: [], state: UIMenuElement.State.off) { [weak self]
            action in
           guard let self, let imageViewerController = self.imageController() else { return }
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
         UIAction(title: PGLMenuLabel.Save.rawValue, image:UIImage(systemName: "square.and.arrow.down")) { [weak self]
            action in
                // self.saveStackAlert(self.moreBtn)
            guard let self, let imageViewerController = self.imageController() else { return }
            imageViewerController.saveStackActionBtn(self.moreBtn)
        },


         UIAction(title: PGLMenuLabel.Record.rawValue, image:UIImage(systemName: "recordingtape")) { [weak self]
            action in
            guard let self, let imageViewerController = self.imageController() else { return }
            imageViewerController.recordButtonTapped(controllerRecordBtn: self.moreBtn)

        },

         UIAction(title: PGLMenuLabel.Music.rawValue, image:UIImage(systemName: "music.note.list"),attributes: (musicItemState)) { [weak self]
            action in
            guard let self, let imageViewerController = self.imageController() else { return }
            imageViewerController.musicButtonTapped(controllerMusicBtn: self.moreBtn)

        } ,
          UIAction(title: PGLMenuLabel.Optimize.rawValue, image:UIImage(systemName: "flag.circle.fill")) { [weak self]
             action in
            guard let self, let imageViewerController = self.imageController() else { return }
            imageViewerController.optimizeStack(controllerMusicBtn: self.moreBtn)
         }
        ])
        moreBtn.menu = contextMenu
    }
    @IBOutlet weak var helpBtn: UIBarButtonItem!
    
    func setHelpBtnMenu() {
        guard imageController() != nil
            else { return }

        // Re-fetch the image controller inside the handler (weakly) — capturing it
        // strongly here would keep it (and this container) alive via helpBtn.menu.
        let helpMenu = UIAction.init(title: PGLMenuLabel.Help.rawValue, image: UIImage(systemName: "folder"), identifier: PGLImageController.LibraryMenuIdentifier, discoverabilityTitle: "Help", attributes: [], state: UIMenuElement.State.off) { [weak self]
            action in
            guard let self, let imageViewerController = self.imageController(), let theHelpBtn = self.helpBtn else { return }
            imageViewerController.helpBtnAction(theHelpBtn)

        }

        let contextMenu = UIMenu(title: "",
                                 children: [ helpMenu ,
            UIAction(title: PGLMenuLabel.Privacy.rawValue, image:UIImage(systemName: "info.circle")) { [weak self]
            action in
            guard let self, let imageViewerController = self.imageController(), let theHelpBtn = self.helpBtn else { return }
            imageViewerController.displayPrivacyPolicy(theHelpBtn)
        }
            ] )
        helpBtn.menu = contextMenu
    }

    func setTemplateBtnMenu() {
        guard imageController() != nil
            else { return }
        let imageName = "photo.stack"
        // The uncached provider re-runs each time the menu opens, so it re-fetches
        // the image controller (weakly) instead of capturing it strongly — a strong
        // capture here would keep it alive for the life of templateBtn.menu.
        let contextMenu = UIMenu(title: "",
                                 children: [
                                    UIDeferredMenuElement.uncached { [weak self] completion in
                                        guard let self, let imageViewerController = self.imageController()
                                            else { completion([]); return }
                                        let actions = [
                                            UIAction.init(title: PGLMenuLabel.random.rawValue, image: UIImage(systemName: "folder"), identifier: PGLImageController.TemplateMenuIdentifier, discoverabilityTitle: "Template", attributes: [], state: UIMenuElement.State.off) {
                                                [weak imageViewerController]
                                                action in
                                                guard let imageViewerController else { return }
                                                imageViewerController.templateBtnAction(imageViewerController.templateBtn)
                                            } ,
                                            UIAction(title: PGLMenuLabel.Guide.rawValue , image: UIImage(systemName: "hourglass"), state: PGLDemo.GuideMode == true ? .on : .off, handler: { (action) in
                                                PGLDemo.toggleGuideMode()
                                                let stackNotification = Notification(name:PGLStackChange)
                                                NotificationCenter.default.post(stackNotification)
                                                        }),
                                            UIAction(title: PGLMenuLabel.Blend.rawValue, image:UIImage(systemName: imageName)) {
                                                [weak imageViewerController]
                                                action in
                                                guard let imageViewerController else { return }
                                                let demoGenerator = PGLDemo()
                                                demoGenerator.iPhoneCompact = false  // now on the iPad
                                                demoGenerator.blendTemplate(appStack: imageViewerController.appStack)
                                            },
                                            UIAction(title: PGLMenuLabel.Sequence.rawValue, image:UIImage(systemName: imageName)) {
                                                [weak imageViewerController]
                                                action in
                                                guard let imageViewerController else { return }
                                                imageViewerController.loadDemoStack(imageViewerController.templateBtn)
                                            },
                                            UIAction(title: PGLMenuLabel.Edge.rawValue, image:UIImage(systemName: imageName)) {
                                                [weak imageViewerController]
                                                action in
                                                guard let imageViewerController else { return }
                                                let demoGenerator = PGLDemo()
                                                demoGenerator.edgeTemplate(appStack: imageViewerController.appStack)
                                            },

                                            // place holder - change to demo methods
                                            UIAction(title: PGLMenuLabel.Tone.rawValue, image:UIImage(systemName: imageName)) {
                                                [weak imageViewerController]
                                                action in
                                                guard let imageViewerController else { return }
                                                let demoGenerator = PGLDemo()
                                                demoGenerator.toneTemplate(appStack: imageViewerController.appStack)
                                            },
                                            // place holder - change to demo methods
                                            UIAction(title: PGLMenuLabel.Kaleidoscope.rawValue, image:UIImage(systemName: imageName)) {
                                                [weak imageViewerController]
                                                action in
                                                guard let imageViewerController else { return }
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

    func setEditBtnMenu () -> UIMenu? {
        // based on example code in Apple app 'ControlMenus'
        //  - class DeferredMenuElementDemoViewController #viewDidLoad
        guard let imageViewerController = imageController()
            else { return nil }

        // All handlers below weak-capture self / the image controller. This menu
        // is stored on editBtn.menu for the life of the container, so a strong
        // capture would leak the container and its image controller.
        let copyAction = UIAction(
            title: PGLMenuLabel.Copy.rawValue,
            image: UIImage(systemName: "Copy"),
            identifier: PGLImageController.EditMenuIdentifier,
            discoverabilityTitle: PGLMenuLabel.Copy.rawValue,
            attributes: []
        ) { [weak imageViewerController] action in
            guard let imageViewerController else { return }
            imageViewerController.copy(imageViewerController.editButtonItem)
        }

        let pasteAction = UIDeferredMenuElement({ [weak imageViewerController] completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let hasClipBoardImage = UIPasteboard.general.hasImages
                let pasteAttribute: UIMenuElement.Attributes = hasClipBoardImage ? [] : [.disabled]

                let thePasteAction = UIAction(
                    title: PGLMenuLabel.Paste.rawValue,
                    image: UIImage(systemName: "Paste"),
                    attributes: pasteAttribute
                ) { [weak imageViewerController] action in
                    guard let imageViewerController else { return }
                    imageViewerController.paste(imageViewerController.editButtonItem)
                }
                completion([thePasteAction])

            }
        })

        let undoAction =
        UIDeferredMenuElement({ [weak self] completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard let self else { completion([]); return }
                let hasUndo = self.undoManager?.canUndo ?? false
                let unDoAttribute: UIMenuElement.Attributes = hasUndo ? [] : [.disabled]

                let theUndo = UIAction(
                title: PGLMenuLabel.Undo.rawValue,
//                    image: UIImage(systemName: "arrow.2.circlepath.circle"),
                    identifier: PGLImageController.EditMenuIdentifier,
                    discoverabilityTitle: PGLMenuLabel.Undo.rawValue,
                    attributes: unDoAttribute
                ) { [weak self] action in
                    guard let self else { return }
                    if (self.undoManager?.canUndo ?? false) == false { return }
                        self.undoManager?.undo()
                }
                completion([theUndo])
            }
        })

        let redoAction =
        UIDeferredMenuElement({ [weak self] completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard let self else { completion([]); return }
                let hasRedo = self.undoManager?.canRedo ?? false
                let unDoAttribute: UIMenuElement.Attributes = hasRedo ? [] : [.disabled]

                let theRedo = UIAction(
                title: PGLMenuLabel.Redo.rawValue,
//                    image: UIImage(systemName: "arrow.2.circlepath.circle"),
                    identifier: PGLImageController.EditMenuIdentifier,
                    discoverabilityTitle: PGLMenuLabel.Redo.rawValue,
                    attributes: unDoAttribute
                ) { [weak self] action in
                    guard let self else { return }
                    if (self.undoManager?.canRedo ?? false) == false { return }
                    self.undoManager?.redo()
                }
                completion([theRedo])
            }
        })

        var menuChildern = [copyAction, pasteAction]
        if self.undoManager?.canUndo ?? false {
            menuChildern.append(undoAction)
        }
        if self.undoManager?.canRedo ?? false {
            menuChildern.append(redoAction)
        }

        let buttonEditMenu = UIMenu(
            title: "",
            image: nil,
            identifier: nil,
            children: menuChildern
        )
        return buttonEditMenu
//                theEditBtn.menu = buttonEditMenu
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

