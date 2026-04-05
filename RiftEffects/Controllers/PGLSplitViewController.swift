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
import Combine
import SwiftUI

let  PGLShowImageListOverLay = NSNotification.Name(rawValue: "PGLShowImageListOverLay")

class PGLSplitViewController: UISplitViewController, NSFetchedResultsControllerDelegate {

    private let splitDelegate = PGLSplitViewDelegate()
    private var firstStartUpImageRun = false
    private var didConfigureColumns = false

    var imageListViewModel = PGLImageListViewModel()
    var imageListHostingController: UIViewController?

    var publishers = [any Cancellable]()
    var cancellable: (any Cancellable)?


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

//    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
//        get { .landscapeLeft}
//    }

    override func viewDidLoad() {

        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
        super.viewDidLoad()
        delegate = splitDelegate
        presentsWithGesture = true

        let myCenter =  NotificationCenter.default
        cancellable = myCenter.publisher(for:  PGLShowImageListOverLay)
            .sink() { [weak self]
                myUpdate in
                guard let self = self else { return } // a released object sometimes receives the

                Logger(subsystem: LogSubsystem, category: LogNavigation).info( "PGLShowImageListOverLay  notificationBlock")

                self.showImageList()
            }
        publishers.append(cancellable!)

    }  // viewDidLoad

    override func releaseNotifications() {
        for aCancel in publishers {
            aCancel.cancel()
        }
        publishers = [any Cancellable]()
    }

    func loadNavigationControllers()
    {
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("\(String(describing: self)) - \(#function)")
            //        /// columns are Primary on the left (Library) , Supplementary for filter & parms, Secondary shows the image controller
            //        ///  iPhone only uses Supplementary and Secondary. the Library to open stacks is  a menu command, not a column

        if let primaryNav = self.storyboard?.instantiateViewController(identifier: "PGLNavPrimaryController") as? UINavigationController {

            self.setViewController(primaryNav, for: .primary)

            // does the child need to be set too?  OpenStackController
            if let childController = self.storyboard?.instantiateViewController(withIdentifier: "OpenStackController") as? PGLOpenStackController {
                primaryNav.setViewControllers([childController], animated: false)

            }
                // primaryNav.topViewController as? PGLStackImageController {


           //  primaryNav.setViewControllers(<#T##viewControllers: [UIViewController]##[UIViewController]#>, animated: <#T##Bool#>)

            if let supplementNav =
                self.storyboard?.instantiateViewController(identifier:
                    "SupplementNavController") as? UINavigationController {
                self .setViewController(supplementNav, for: .supplementary)
                if let childController = self.storyboard?.instantiateViewController(withIdentifier: "StackController") as? PGLStackController {
                    supplementNav.setViewControllers([childController], animated: false)
                }
            }



            if let secondaryNav = self.storyboard?.instantiateViewController(withIdentifier: "PGLNavSecondaryController") as? UINavigationController {
                self.setViewController(secondaryNav, for: .secondary)
                if let childController = self.storyboard?.instantiateViewController(withIdentifier: "PGLImageController") as? PGLImageController {
                    secondaryNav.setViewControllers([childController], animated: false)
                }
            }



            if let compactNav = self.storyboard?.instantiateViewController(withIdentifier: "PGLNavStackImageController") as? UINavigationController {
                self.setViewController(compactNav, for: .compact)
                if let childController = self.storyboard?.instantiateViewController(withIdentifier: "PGLStackImageContainerController") as? PGLStackImageContainerController {
                    compactNav.setViewControllers([childController], animated: false)
                }
            }
        }

    }

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

        Logger(subsystem: LogSubsystem, category: LogCategory).notice("\( String(describing: self) + "-" + #function)")

        let deviceIdom = traitCollection.userInterfaceIdiom
        navigationItem.leftItemsSupplementBackButton = true

        if deviceIdom == .phone {
            navigationItem.hidesBackButton = false
            showsSecondaryOnlyButton = false
                // showsSecondaryOnlyButton  not needed for full screen of the PGLImageController
                // now doubleTap on the PGLImageController opens full screen of the PGLMetalController
            }

        super.viewWillAppear(animated)

    }

    override func viewDidAppear(_ animated: Bool) {

        Logger(subsystem: LogSubsystem, category: LogCategory).notice("\( String(describing: self) + "-" + #function)")

        if !firstStartUpImageRun {
            firstStartUpImageRun = requestStartupImage()
        }

    }


    override func updateProperties() {
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("\( String(describing: self) + "-" + #function)")
        if #available(iOS 26.0, *) {
            super.updateProperties()
        } else {
                // Fallback on earlier versions
        }
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

        Logger(subsystem: LogSubsystem, category: LogCategory).notice("\( String(describing: self) + "-" + #function)")
        
//        let deviceIdom = traitCollection.userInterfaceIdiom
       // navigationItem.leftItemsSupplementBackButton = true

//        if deviceIdom == .phone {
            navigationItem.hidesBackButton = false
            showsSecondaryOnlyButton = false
                // showsSecondaryOnlyButton  not needed for full screen of the PGLImageController
                // now doubleTap on the PGLImageController opens full screen of the PGLMetalController
//            }
        super.viewWillLayoutSubviews()

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

    func requestStartupImage() -> Bool {
            // return true on first run
        let alwaysReturnTrue = true
        if firstStartUpImageRun {
                //already run at startup
            return alwaysReturnTrue
        }
        let newList = PGLImageList()

        imageListPicker = PGLImageListPicker(targetList: newList, controller: self)
        if imageListPicker != nil {
                /// with  a nil  target attribute just picks one image from the photoLibary
            guard let pickerViewController = imageListPicker!.set(targetAttribute: nil)
            else { return  alwaysReturnTrue }
            DispatchQueue.main.async { [weak self] in
                self?.present(pickerViewController, animated: true)
            }

            return alwaysReturnTrue

        }
        return alwaysReturnTrue
    }


        // MARK: Menus

        override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {

          if action == #selector(paste(_:)) {

              let hasImages =   UIPasteboard.general.hasImages
//              NSLog(#function + "hasImages:\(hasImages) "  + String(describing: self ))
              return hasImages
          }

            if action == #selector(copy(_ : )) {
                NSLog(#function  + String(describing: self ) +  " #selector(copy) ")
                return true // image controller always has an image.. maybe CIImage.empty

            }
            else {
                return super.canPerformAction(action, withSender: sender)
            }

          }

        override func copy(_ sender: Any?) {
            NSLog(#function  + String(describing: self ))
            guard let myAppStack = self.appStack
            else {return }
            if !myAppStack.isImageControllerOpen {
               return
            }
            let metalRenderer = myAppStack.appRenderer

            if let clipboardImage = try? metalRenderer.captureImage()
                {
                    let pb = UIPasteboard.general
                    pb.image = clipboardImage }
                else {
                    return
                }
        }


        override func paste(_ sender: Any?) {
              // Handle paste from UIPasteboard
          NSLog(#function + String(describing: self ))
          let pb = UIPasteboard.general
          if pb.numberOfItems < 1 {
                // this should prevent the system allow paste confirmation from showing
                return
            }
          if let uiImage = pb.image {
              if let ci =  CIImage.init(image: uiImage) {
                  let theOrientation = CGImagePropertyOrientation(uiImage.imageOrientation)
                  let pickedCIImage = ci.oriented(theOrientation)
                  pasteCIImage(pickedCIImage)
                  return
              }
          }

          }

        func pasteCIImage(_ ciImage: CIImage) {
            NSLog(#function + String(describing: self ))
            appStack.outputOrViewFilterStack().pasteCIImage(ciImage)
        }

// MARK: ImageListOverlay

    func showImageList() {
        if imageListHostingController != nil {
            hideImageListOverlay()
        } else {
            showImageListOverlay()
        }
    }

    func showImageListOverlay() {

        let currentStack = appStack.viewerStack
        if currentStack.isEmptyStack()  { return }

        // must have current filter and must be a transtion filter with multiple images
        imageListViewModel.loadFromFilter(currentStack.currentFilter())

        let overlayView = PGLImageListOverlayView { [weak self] in
            self?.hideImageListOverlay()
        }
        .environmentObject(imageListViewModel)
        let hostingController = UIHostingController(rootView: overlayView)
        hostingController.view.backgroundColor = .clear

        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        view.bringSubviewToFront(hostingController.view)

        // can this attach over the imageController view area?
        // otherwise move all this to the splitViewController to set it over the imageController

        let insetFraction = 1.0 / 5.0
        let horizontalInset = view.bounds.width * insetFraction
        let verticalInset = view.bounds.height * insetFraction

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor, constant: verticalInset),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -verticalInset),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: horizontalInset),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -horizontalInset)
        ])

        hostingController.didMove(toParent: self)
        imageListHostingController = hostingController
    }

    func hideImageListOverlay() {
        // Update filter inputs from the modified image lists
        let currentStack = appStack.viewerStack
        if !currentStack.isEmptyStack() {
            let filter = currentStack.currentFilter()
            for attr in filter.imageAttributes() {
                guard let imageList = attr.inputCollection,
                      let attrName = attr.attributeName
                else { continue }
                // Clear cached images so the filter re-loads and centers from updated assets
                imageList.cachedImages.removeAll()
                filter.setImageValuesAndClone(inputList: imageList, attributeName: attrName)
            }
            let updateNotification = Notification(name: PGLRedrawFilterChange)
            NotificationCenter.default.post(name: updateNotification.name, object: nil, userInfo: ["filterHasChanged": true as AnyObject])
        }

        imageListHostingController?.willMove(toParent: nil)
        imageListHostingController?.view.removeFromSuperview()
        imageListHostingController?.removeFromParent()
        imageListHostingController = nil
    }



}

