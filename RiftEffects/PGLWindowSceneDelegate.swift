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

            guard let svc = splitViewController as? UISplitViewController else {
                // If the storyboard identifier doesn't match a UISplitViewController, fallback to an empty one
                return UISplitViewController()
            }

            let horizontalSize = window.traitCollection.horizontalSizeClass
            if horizontalSize == .compact {
                // iPhone compact width: show secondary only
                svc.preferredDisplayMode = .secondaryOnly
                if let navStackImageController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PGLNavStackImageController") as? PGLNavStackImageController {
                    svc.setViewController(navStackImageController, for: .secondary)
                }
            } else {
                // iPad / regular width: configure split behavior and display mode
                if #available(iOS 14.0, *) {
                    // Use preferredSplitBehavior to request tiling; splitBehavior is read-only
                    svc.preferredSplitBehavior = .tile
                }
                svc.presentsWithGesture = true
                svc.preferredDisplayMode = .twoBesideSecondary
                if let navPrimaryController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PGLNavPrimaryController") as? PGLNavPrimaryController {
                    svc.setViewController(navPrimaryController, for: .primary)
                }
                if let navSupplementaryController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SupplementNavController") as? PGLSupplementNavController {
                    svc.setViewController(navSupplementaryController, for: .supplementary)
                }
                if let navSecondaryController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PGLNavSecondaryController") as? PGLNavSecondaryController {
                    svc.setViewController(navSecondaryController, for: .secondary)
                }
            }

            return svc
        }
    }
