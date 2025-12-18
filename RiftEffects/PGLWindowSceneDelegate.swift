    //
    //  PGLWindowSceneDelegate.swift
    //  RiftEffects
    //
    //  Created by Will on 9/18/22.
    //  Copyright © 2022 Will Loew-Blosser. All rights reserved.
    //

    import UIKit
    import os

    final class PGLWindowSceneDelegate: UIResponder, UIWindowSceneDelegate {
      var window: UIWindow?

        func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
            Logger(subsystem: LogSubsystem, category: LogCategory).notice("\(String(describing: self)) - \(#function)")
//          guard let windowScene = scene as? UIWindowScene else { return }
//          let sceneWindow = UIWindow(windowScene: windowScene)
//                // The 'window' property will automatically be loaded with the storyboard's initial view controller.
//
//            sceneWindow.rootViewController =  setupSplitViewController(window:sceneWindow)
//          self.window = sceneWindow
//
//          guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
//            else { return }
//            myAppDelegate.windowSceneDelegate = self  // connect the windowSceneDelegate to the appDelegate
//
//        sceneWindow.makeKeyAndVisible()
//            NSLog("PGLWindowSceneDelegate: makeKeyAndVisitble called,")
        }

        func sceneWillEnterForeground(_ scene: UIScene) {
            // Called as the scene transitions from the background to the foreground.
            // Use this method to undo the changes made on entering the background.
            Logger(subsystem: LogSubsystem, category: LogCategory).notice("\( String(describing: self) + "-" + #function)")
        }

        func setupSplitViewController(window: UIWindow) -> UISplitViewController {
            let splitViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "RootSplitView")

            guard let splitVC = splitViewController as? UISplitViewController else {
                // If the storyboard identifier doesn't match a UISplitViewController, fallback to an empty one

                return UISplitViewController()
            }


            return splitVC
        }

        @available(iOS 26.0, *)
        func preferredWindowingControlStyle(
              for scene: UIWindowScene) -> UIWindowScene.WindowingControlStyle {
                      // return .unified  Windowing controls will appear as part of the scene’s content

              return .automatic
              //Windowing controls will use the default system style
      }

        func sceneDidBecomeActive(_ scene: UIScene) {
            // Called when the scene has moved from an inactive state to an active state.
            // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
            Logger(subsystem: LogSubsystem, category: LogCategory).notice("\( String(describing: self) + "-" + #function)")
        }

//        func windowScene( _ windowScene: UIWindowScene,
//                            didUpdateEffectiveGeometry previousGeometry: UIWindowScene.Geometry) {
//
//                let wasLocked = previousGeometry.isInterfaceOrientationLocked
//                let isLocked = windowScene.effectiveGeometry.isInterfaceOrientationLocked
//
//                if wasLocked != isLocked {
//                    NSLog("PGLWindowSceneDelegate #didUpdateEffectiveGeometry:")
////            game.pauseIfNeeded(isInterfaceOrientationLocked: isLocked)
//                }
//            }
    }
