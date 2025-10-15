    //
    //  PGLWindowSceneDelegate.swift
    //  RiftEffects
    //
    //  Created by Will on 9/18/22.
    //  Copyright © 2022 Will Loew-Blosser. All rights reserved.
    //

    import UIKit

    final class PGLWindowSceneDelegate: UIResponder, UIWindowSceneDelegate {
      var window: UIWindow?

        func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
          guard let windowScene = scene as? UIWindowScene else { return }
          let sceneWindow = UIWindow(windowScene: windowScene)
                // The 'window' property will automatically be loaded with the storyboard's initial view controller.

            sceneWindow.rootViewController =  setupSplitViewController(window:sceneWindow)
          self.window = sceneWindow

          guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
            else { return }
            myAppDelegate.windowSceneDelegate = self  // connect the windowSceneDelegate to the appDelegate

        sceneWindow.makeKeyAndVisible()
            NSLog("PGLWindowSceneDelegate: scene connected")
        }

        func setupSplitViewController(window: UIWindow) -> UISplitViewController {
            let splitViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "RootSplitView")

            guard let splitVC = splitViewController as? UISplitViewController else {
                // If the storyboard identifier doesn't match a UISplitViewController, fallback to an empty one

                return UISplitViewController()
            }
            splitVC.preferredSplitBehavior = .automatic
            splitVC.preferredDisplayMode = .automatic
            splitVC.displayModeButtonVisibility = .automatic

            return splitVC
        }
    }
