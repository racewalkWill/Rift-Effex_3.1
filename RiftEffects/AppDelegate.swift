//
//  AppDelegate.swift
//  Glance
//
//  Created by Will on 10/11/17.
//  Copyright © 2017 Will Loew-Blosser. All rights reserved.
//  testing verified commits with SSH key  2024/01/15
//  2nd test of verification with SSH download clone 2025/01/16

import UIKit
import CoreData
import Photos
import os

let iCloudDataContainerName = "iCloud.L-BSoftwareArtist.RiftEffects"
let LogSubsystem = "L-BSoftwareArtist.RiftEffects"


let LogCategory = "PGL"
let LogNavigation = "PGL_Nav"
let LogMemoryRelease = "PGL_Mem"
let LogMigration = "PGL_Migration"
let LogParms = "PGL_Parms"
let LogMetal = "PGL_Metal"

// change in areas as needed.
// caution on changes it is a GLOBAL

let RendererScale:Float32 = 0.98
// controls the size of the background color frame around the image area in mtkView

@MainActor var MainViewImageResize = false

// or false to not perform ciOutputImage.cropped(to: currentStack.cropRect) in Render #drawIn
// should be a user setting
// 2/12/2020 leave as false - makes the cropped produce an empty image if in single filter edit mode.
@MainActor var ShowHelpOnOpen = false
@MainActor var AlbumPrefix = "PhotoArt"

//@UIApplicationMain   //@main
// see https://github.com/swiftlang/swift-evolution/blob/main/proposals/0383-deprecate-uiapplicationmain-and-nsapplicationmain.md

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var windowSceneDelegate: PGLWindowSceneDelegate?
    var airPlaySceneDelegate: PGLAirPlaySceneDelegate?
    var airPlayDeviceController: PGLAirPlayMetalController?
    weak var mainMetalController: PGLMetalController?

    var appStack = PGLAppStack()
    lazy var dataWrapper: CoreDataWrapper = { return CoreDataWrapper() }()

    var activityIndicator: UIActivityIndicatorView?

    // MARK: - Menus

    override func buildMenu(with builder: any UIMenuBuilder) {
            //        Add the various menus to the menu bar.
            //            The system only asks UIApplication and UIApplicationDelegate for the main menus.
            //            Main menus appear regardless of who is in the responder chain.

            //        super.buildMenu(with: builder)


            // Ensure that the builder is modifying the menu bar system.
        guard builder.system == UIMenuSystem.main else { return }

        builder.remove(menu: UIMenu.Identifier.file)
        builder.remove(menu: UIMenu.Identifier.format)
//        builder.remove(command: #selector())
        let editMenu = builder.menu(for: .edit)
        let standardCommands = builder.menu(for: UIMenu.Identifier(rawValue: "com.apple.menu.standard-edit"))
        let _ = editMenu?.children // keep if you need to inspect later

        if let standardCommands {
                // Filter out specific items and replace the menu
            let filteredChildren = standardCommands.children.filter { item in
                !(item.title == "Cut" ||
                  item.title == "Select All" ||
                  item.title == "Paste and Match Style" ||
                  item.title == "Writing Tools" ||
                  item.title == "AutoFill" ||
                  item.title == "Dictation" ||
                  item.title == "Emoji" ||
                  item.title == "Show Keyboard"
                )
            }
            let newStandardMenu = UIMenu(title: standardCommands.title,
                                         image: standardCommands.image,
                                         identifier: standardCommands.identifier,
                                         options: standardCommands.options,
                                         children: filteredChildren)
            builder.replace(menu: standardCommands.identifier, with: newStandardMenu)
        }
         builder.remove(menu: UIMenu.Identifier(rawValue: "com.apple.menu.find"))
        // these are edit command menus
//        builder.remove(menu: UIMenu.Identifier(rawValue: "com.apple.command.speech"))
//        builder.remove(menu: UIMenu.Identifier(rawValue: "com.apple.menu.transformation"))
//        builder.remove(menu: UIMenu.Identifier(rawValue: "com.apple.menu.substitutions"))
//        builder.remove(menu: UIMenu.Identifier(rawValue: "com.apple.menu.spelling"))
//      NSLog(#function + "\(String(describing: builder.system))")
        /*
         from inspecting builder.system.baseUIMenuSystem@0.cachedInitialRootMenu
        identifier = 0x0000000209c49658 @"com.apple.menu.application"
        _identifier = 0x0000000209c49718 @"com.apple.menu.about"
        identifier = 0x0000000209c49738 @"com.apple.menu.preferences"
         identifier = 0x0000000209c49738 @"com.apple.menu.preferences"
         _identifier = 0x0000000209c49778 @"com.apple.menu.hide"
         _identifier = 0x0000000209c49798 @"com.apple.menu.quit"
         _identifier = 0x0000000209c49698 @"com.apple.menu.file"
         _identifier = 0x0000000209c497d8 @"com.apple.menu.new-item"
         _identifier = 0x0000000209c497f8 @"com.apple.menu.open"
         _identifier = 0x0000000209c49838 @"com.apple.menu.close"
         _identifier = 0x0000000209c49878 @"com.apple.menu.document"
         _identifier = 0x0000000209c49858 @"com.apple.menu.print"
         _identifier = 0x0000000209c49678 @"com.apple.menu.edit"
         _identifier = 0x0000000209c49898 @"com.apple.menu.undo-redo"
         _identifier = 0x0000000209c498b8 @"com.apple.menu.standard-edit"
            .. _title = "Delete"
         _identifier = 0x0000000209c498d8 @"com.apple.menu.find"
         _identifier = 0x0000000209c498f8 @"com.apple.menu.find-panel"
         _identifier = 0x0000000209c49978 @"com.apple.menu.spelling"
         _identifier = 0x0000000209c499d8 @"com.apple.menu.substitutions"
         _identifier = 0x0000000209c49a58 @"com.apple.menu.transformations"
         _identifier = 0x0000000209c49a78 @"com.apple.command.speech"
         _identifier = 0x0000000209c49ad8 @"com.apple.menu.format"
         _identifier = 0x0000000209c49af8 @"com.apple.menu.font"
         _identifier = 0x0000000209c49958 @"com.apple.menu.text-style"
         _identifier = 0x0000000209c49b18 @"com.apple.menu.text-size"
         _identifier = 0x0000000209c49b38 @"com.apple.menu.text-color"
         _identifier = 0x0000000209c49b78 @"com.apple.menu.text"
         _identifier = 0x0000000209c496b8 @"com.apple.menu.view"
         _identifier = 0x0000000209c49c58 @"com.apple.menu.toolbar"
         _identifier = 0x0000000209c49c78 @"com.apple.menu.sidebar"
         _identifier = 0x0000000209c49c98 @"com.apple.menu.fullscreen"
         _identifier = 0x0000000209c496d8 @"com.apple.menu.window"
         _identifier = 0x0000000209c496f8 @"com.apple.menu.help"
         */

    }

    @objc func undoCommand() {
        NSLog(#function + " called")
    }

    @objc func redoCommand() {
        NSLog(#function + " called")
    }

    override var undoManager: UndoManager? {
           // Return a shared or per-document undo manager
        NSLog(#function + "\( String(describing: self))")
        return super.undoManager
       }

    /** Add the various menus to the menu bar.
        The system only asks UIApplication and UIApplicationDelegate for the main menus.
        Main menus appear regardless of who is in the responder chain.

    */

    /// added required implementations of  the  protocol UIApplicationDelegate
    func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool
    {
        return true
    }

    fileprivate func registerCustomFilters() {

        
        Logger(subsystem: LogSubsystem, category: LogNavigation).notice( "start registerCustomFilters")
        PGLFilterCIAbstract.register()
        //        WarpItMetalFilter.register()
        //        CompositeTextPositionFilter.register()
        //       PGLFaceCIFilter.register()
        //        PGLFilterCategory.allFilterCategories()
        CIBlendText.register()
        PGLSaliencyBlurFilter.register()
        PGLImageCIFilter.register()
        PGLRandomFilterAction.register()
        PGLCISequenced.register()
        PGLCopyToOutputCIFilter.register()
        PGLPolygonGradientCI.register()
//        PGLPasteUIImageFilter.register()
    }
    
    /// older parts of the protocol
    func application(_ application: UIApplication,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
            // Override point for customization after application launch.

        // pushSchemaToCloudKit()

        _ = dataWrapper.persistentContainer
        registerCustomFilters()

//        Logger(subsystem: LogSubsystem, category: LogCategory).notice( " didFinishLaunchingWithOptions appStack created")
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("\(String(describing: self)) - \(#function)")
//        checkVersion()
        MainViewImageResize = UserDefaults.standard.bool(forKey: "MainViewImageResize")
            // If the specified key doesn‘t exist, this method returns false.
        
//        RendererScale = UserDefaults.standard.float(forKey: "RendererScale")
        ShowHelpOnOpen =   UserDefaults.standard.bool(forKey: "DisplayStartHelp")

        AlbumPrefix = UserDefaults.standard.string(forKey: "AlbumPrefix") ?? "PhotoArt"
        return true
    }

    func application(
      _ application: UIApplication,
      configurationForConnecting connectingSceneSession: UISceneSession,
      options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {

        if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            let airPlayConfig = UISceneConfiguration(
                name: "AirPlayScene",
                sessionRole: .windowExternalDisplayNonInteractive )
            airPlayConfig.delegateClass = PGLAirPlaySceneDelegate.self
            NSLog( #function + " return airPlayConfig")

            return airPlayConfig
        }
        // everything else
        let myConfig =  UISceneConfiguration(
            name: "MainScene",
            sessionRole: connectingSceneSession.role)
        myConfig.delegateClass = PGLWindowSceneDelegate.self
        NSLog( #function + " return MainScene config")
        return myConfig
    }

    //MARK: standard lifecycle overrides
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
            //        NSLog("AppDelegate applicationDidReceiveMemoryWarning")
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("AppDelegate applicationDidReceiveMemoryWarning")
            // run a memory graph.. who and how many objects have the memory?
            // see the Swift Programming Lang  book on strong referencs and reference cycles
            // chap "Automatic Reference Counting"
    }

    func applicationWillResignActive(_ application: UIApplication) {
            // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
            // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.

    }

    func applicationDidEnterBackground(_ application: UIApplication) {
            // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
            // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
            // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
            // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
            // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
            // Saves changes in the application's managed object context before the application terminates.
            //        NSLog("AppDelegate #applicationWillTerminate saveContext")
            //        self.saveContext()
    }



        //Mark: Error Alert

// MARK: User info

    func displayUser(alert: UIAlertController) {
            // presents an alert on top of the open viewController
            // informs user to try again with 'Save As'

        guard let frontViewController = frontViewController()
        else { return }
        frontViewController.present(alert, animated: true )

    }

    func displayDataError( error: (any Error)?) {
        let alertStringMsg = "\(String(describing: error?.localizedDescription))"
        let alert = UIAlertController(title: "Data Store Error", message: alertStringMsg, preferredStyle: .alert)
        let action = UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default)
        alert.addAction(action)
        displayUser(alert: alert)

    }

    /// drill down to the front view controller from the windowScene window
    func frontViewController() -> UIViewController? {
        guard let lastWindow = windowSceneDelegate?.window
        else { return nil
                // need a window to present an alert.. give up
        }
        var parentController = lastWindow.rootViewController
            // drill down until front viewController is reached
        while (parentController?.presentedViewController != nil &&
               parentController != parentController!.presentedViewController) {
            parentController = parentController!.presentedViewController
        }
        return parentController
    }

    /// show spinning wait indicator on left side of front view controller. Otherwise disappears on black Right side 
    func showWaiting(onController: UIViewController) {

        NSLog("AppDelegate #showWaiting onController \(onController)")
         activityIndicator = UIActivityIndicatorView(frame: CGRectMake(0, 0, 100, 100))
         guard let thisIndicator = activityIndicator
            else { return }

//         put on the left side where the indicator is visible. Image area is black
        let center = CGPoint(x: onController.view.frame.minX + 100, y: onController.view.frame.midY)
        thisIndicator.center = center
        thisIndicator.hidesWhenStopped = true
        thisIndicator.style = UIActivityIndicatorView.Style.large
        thisIndicator.color = .systemBlue
        onController.view.addSubview(thisIndicator)
        onController.view.bringSubviewToFront(thisIndicator)

        thisIndicator.startAnimating()

//            UIApplication.sharedApplication().beginIgnoringInteractionEvents()
    }

    func closeWaitingIndicator() {
        NSLog("AppDelegate #closeWaitingIndicator \(String(describing: activityIndicator))")
        guard let theWaitIndicator = activityIndicator
        else { return }

        theWaitIndicator.stopAnimating()
        theWaitIndicator.removeFromSuperview()
        activityIndicator = nil
    }


        // MARK: Migration

//    func checkVersion() {
//            //        self.dataWrapper.build14DeleteOrphanStacks()
//        Logger(subsystem: LogSubsystem, category: LogCategory).notice( "completed checkVersion")
//    }






//    func pushSchemaToCloudKit() {
    // was used in application(_ application: UIApplication, didFinishLaunchingWithOptions
        //******* START ONLY One time to push schema to cloudKit

            // trigger lightweight migration

    //        if (false ) {
    //                // only true when migrating data model change to iCloud
    //            guard dataWrapper.persistentContainer.persistentStoreDescriptions.first != nil
    //            else { fatalError("Could not retrieve a persistent store description.")
    //            }
    //                //        // initialize the CloudKit schema
    //                //
    //                //            //        let options = NSPersistentCloudKitContainerOptions(containerIdentifier: iCloudDataContainerName)
    //                //            //        options.shouldInitializeSchema = true // toggle to false when done
    //                //            //        description.cloudKitContainerOptions = options
    //            NSLog("initializeCloudKitSchema  START " )
    //            let theContainer =  dataWrapper.persistentContainer
    //
    //            if let myCloudContainer = theContainer as? NSPersistentCloudKitContainer {
    //                do {
    //                    try myCloudContainer.initializeCloudKitSchema(options: NSPersistentCloudKitContainerSchemaInitializationOptions.printSchema )
    //                }
    //                catch {
    //                    NSLog("initializeCloudKitSchema \(error.localizedDescription)" )
    //
    //                }
    //
    //            }
    //            NSLog("initializeCloudKitSchema  END " )
    //        }
    //            ******* END ONLY One time to push schema to cloudKit
//    }
}
