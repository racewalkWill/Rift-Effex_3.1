//
//  PGLSplitViewController.swift
//  Glance
//
//  Created by Will on 10/13/17.
//  Copyright © 2017 Will. All rights reserved.
//

import UIKit
import os
import Photos
import CoreData



class PGLSplitViewController: UISplitViewController, NSFetchedResultsControllerDelegate {

    private let splitDelegate = PGLSplitViewDelegate()

    var startupImageList: PGLImageList? {
        didSet {
            /// PGLImageListPicker sets the value in loadImageListFromPicker(results: )
            if startupImageList != nil {
                appStack.viewerStack.loadStartup(userStartupImageList: startupImageList!)
            }
        }
    }

    var appStack: PGLAppStack! {
        // now a computed property
        guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
            else { Logger(subsystem: LogSubsystem, category: LogCategory).fault("PGLSplitViewController viewDidLoad fatalError(AppDelegate not loaded")
            fatalError("PGLSplitViewController could not access the AppDelegate")
        }
       return  myAppDelegate.appStack
    }

    var imageListPicker: PGLImageListPicker?

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        get { .landscapeLeft}
    }

    override func viewDidLoad() {

        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
        super.viewDidLoad()
        delegate = splitDelegate


      //  preferredDisplayMode = UISplitViewController.DisplayMode.oneBesideSecondary
        // comment out iOS26 iPad test
        
        // if the smaller iPhone is compact then should be the two column where the columns are controlled by buttons
        // used to have this.. check versions


        presentsWithGesture = true
        showsSecondaryOnlyButton = false
            // this button shows on the navigation of the secondary controller - the imageController
            // it goes to full screen secondaryOnly column
            // NOT needed now that doubletap to full screen is implemented

        let horizontalSize = traitCollection.horizontalSizeClass
        /// columns are Primary on the left (Library) , Supplementary for filter & parms, Secondary shows the image controller
        ///  iPhone only uses Supplementary and Secondary. the Library to open stacks is  a menu command, not a column
        if horizontalSize == .compact {
//                preferredDisplayMode = UISplitViewController.DisplayMode.oneBesideSecondary }
            preferredDisplayMode = UISplitViewController.DisplayMode.secondaryOnly }
                // load controllers


//                if let supplementNav = self.storyboard?.instantiateViewController(identifier:
//                    "SupplementNavController") as? UINavigationController {
//                    self .setViewController(supplementNav, for: .supplementary)
//                }
            // "PGLNavStackImageController" compact case .secondaryOnly
                if let secondaryNav = self.storyboard?.instantiateViewController(withIdentifier: "PGLNavStackImageController") as? UINavigationController {
                    self.setViewController(secondaryNav, for: .secondary)
                }
        else {
            preferredDisplayMode = UISplitViewController.DisplayMode.twoDisplaceSecondary
            if let primaryNav = self.storyboard?.instantiateViewController(identifier: "PGLNavPrimaryController") as? UINavigationController {
                self.setViewController(primaryNav, for: .primary)

                if let supplementNav = self.storyboard?.instantiateViewController(identifier:
                                                                                    "SupplementNavController") as? UINavigationController {
                    self .setViewController(supplementNav, for: .supplementary)
                }

                if let secondaryNav = self.storyboard?.instantiateViewController(withIdentifier: "PGLNavSecondaryController") as? UINavigationController {
                    self.setViewController(secondaryNav, for: .secondary)
                }
            }
        }



        // Do any additional setup after loading the view.
        requestStartupImage()
        // moved to the AppStack
        // rotate to trigger display issue

       // self.setNeedsUpdateProperties()
        // or setNeedsDisplay ? or other setNeeds...

        let myCenter =  NotificationCenter.default
        let queue = OperationQueue.main
        myCenter.addObserver(forName: PGLUpdateSplitView, object: nil , queue: queue) { [weak self]
            myUpdate in
            guard let self = self else { return } // a released object sometimes receives the notification
                          // the guard is based upon the apple sample app 'Conference-Diffable'

//            Logger(subsystem: LogSubsystem, category: LogNavigation).info( "PGLSupplementNavController  notificationBlock PGLShowStackImageContainer")

            Task { @MainActor in
//                self.setNeedsUpdateProperties()

                self.view.setNeedsLayout()
                self.view.setNeedsDisplay()
                Logger(subsystem: LogSubsystem, category: LogNavigation).info("\(String(describing: self)) - task ran setNeedsLayout and setNeedsDisplay")
//                self.performSegue(withIdentifier:"compact view controller",sender:self)
            }

        }



    }  // viewDidLoad
                //    override func didReceiveMemoryWarning() {
//        super.didReceiveMemoryWarning()
//        // Dispose of any resources that can be recreated.
//    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
// MARK: iPhone Navigation
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("\( String(describing: self) + "-" + #function)")


    }


    override func viewWillLayoutSubviews() {

//     navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        // 2021-11-01 comment out the assignment and the triple column navigation comes back.
        // still not showing the imageController

        // turns on the full screen toggle button on the left nav bar
        // Do not change the configuration of the returned button.
        // The split view controller updates the button’s configuration and appearance automatically based on the current display mode
        // and the information provided by the delegate object.
        // mode is controlled by targetDisplayModeForAction(in svc: UISplitViewController) -> UISplitViewController.DisplayMode

        let deviceIdom = traitCollection.userInterfaceIdiom
        navigationItem.leftItemsSupplementBackButton = true

        if deviceIdom == .phone {
            navigationItem.hidesBackButton = false
            showsSecondaryOnlyButton = false
                // showsSecondaryOnlyButton  not needed for full screen of the PGLImageController
                // now doubleTap on the PGLImageController opens full screen of the PGLMetalController
            }

    }

    func stackProviderHasRows() -> Bool {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        let provider = PGLStackProvider(with: appDelegate!.dataWrapper.persistentContainer)
        provider.setFetchControllerForBackgroundContext()
        let stackRowCount = provider.filterStackCount()
        provider.reset()
        return stackRowCount > 0
    }

    // MARK: startup Pick

    func requestStartupImage() {
//        if startupImageList == nil {
            let newList = PGLImageList()

            imageListPicker = PGLImageListPicker(targetList: newList, controller: self)
            if imageListPicker != nil {
                    /// with  a nil  target attribute just picks one image from the photoLibary
                guard let pickerViewController = imageListPicker!.set(targetAttribute: nil)
                    else { return }
                self.present(pickerViewController, animated: true)
            }
            // where is the pickerCompletion and the picker dismiss?
        
        }

}

