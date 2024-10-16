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


var LogCategory = "PGL"
var LogNavigation = "PGL_Nav"
var LogMemoryRelease = "PGL_Mem"
var LogMigration = "PGL_Migration"
var LogParms = "PGL_Parms"
// change in areas as needed.
// caution on changes it is a GLOBAL

var RendererScale:Float32 = 0.98
// controls the size of the background color frame around the image area in mtkView

var MainViewImageResize = false

// or false to not perform ciOutputImage.cropped(to: currentStack.cropRect) in Render #drawIn
// should be a user setting
// 2/12/2020 leave as false - makes the cropped produce an empty image if in single filter edit mode.
var ShowHelpOnOpen = false

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {



    var window: UIWindow?
    var windowSceneDelegate: PGLWindowSceneDelegate?

    var appStack = PGLAppStack()
    lazy var dataWrapper: CoreDataWrapper = { return CoreDataWrapper() }()

    var activityIndicator: UIActivityIndicatorView?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
            // Override point for customization after application launch.
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

            //       PGLFaceCIFilter.register()
            //        PGLFilterCategory.allFilterCategories()

        _ = dataWrapper.persistentContainer  // get lazy vars setup now

        Logger(subsystem: LogSubsystem, category: LogNavigation).notice( "start didFinishLaunchingWithOptions")
        PGLFilterCIAbstract.register()
//        WarpItMetalFilter.register()

        CompositeTextPositionFilter.register()
        PGLSaliencyBlurFilter.register()
        PGLImageCIFilter.register()
        PGLRandomFilterAction.register()
        PGLCISequenced.register()
        PGLCopyToOutputCIFilter.register()
        PGLPolygonGradientCI.register()





        Logger(subsystem: LogSubsystem, category: LogCategory).notice( " didFinishLaunchingWithOptions appStack created")
        checkVersion()
        MainViewImageResize = UserDefaults.standard.bool(forKey: "MainViewImageResize")
            // If the specified key doesn‘t exist, this method returns false.
        
//        RendererScale = UserDefaults.standard.float(forKey: "RendererScale")
        ShowHelpOnOpen =   UserDefaults.standard.bool(forKey: "DisplayStartHelp")
        return true
    }

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

    func checkVersion() {
            //        self.dataWrapper.build14DeleteOrphanStacks()
        Logger(subsystem: LogSubsystem, category: LogCategory).notice( "completed checkVersion")
    }




    func application(
      _ application: UIApplication,
      configurationForConnecting connectingSceneSession: UISceneSession,
      options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let myConfig =  UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: .windowApplication)
        myConfig.delegateClass = PGLWindowSceneDelegate.self
        return myConfig
    }

}
