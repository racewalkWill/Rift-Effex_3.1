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
            guard let windowScene = scene as? UIWindowScene else { return }

            // Create the window explicitly and tie it to the window scene so its
            // bounds track the scene geometry across device rotations. The
            // storyboard auto-created window did not resize on runtime rotation,
            // which left iPhone landscape stuck in the portrait layout.
            let sceneWindow = UIWindow(windowScene: windowScene)
            sceneWindow.rootViewController = setupSplitViewController(window: sceneWindow)
            self.window = sceneWindow

            if let myAppDelegate = UIApplication.shared.delegate as? AppDelegate {
                myAppDelegate.windowSceneDelegate = self  // connect the windowSceneDelegate to the appDelegate
            }

            sceneWindow.makeKeyAndVisible()
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

        func windowScene(_ windowScene: UIWindowScene,
                         didUpdate previousCoordinateSpace: any UICoordinateSpace,
                         interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
                         traitCollection previousTraitCollection: UITraitCollection) {
            guard let window = window else { return }
            // The window tracks the scene, but a collapsed UISplitViewController does
            // not re-lay-out its compact column on rotation because the size *class*
            // stays compact (iPhone portrait and landscape are both compact width).
            // Force the split view and its collapsed compact column to re-layout to
            // the new window bounds so the container view controllers pick up the new
            // size and re-run their portrait/landscape constraints.
            window.rootViewController?.view.frame = window.bounds
            if let split = window.rootViewController as? UISplitViewController,
               let compact = split.viewController(for: .compact) {
                compact.view.frame = window.bounds
                compact.view.setNeedsLayout()
                compact.view.layoutIfNeeded()
            }
            window.rootViewController?.view.setNeedsLayout()
            window.rootViewController?.view.layoutIfNeeded()
        }
    }
