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
            relayoutForCurrentWindowBounds()
        }

        /// The window tracks the scene, but a collapsed UISplitViewController does
        /// not re-lay-out its compact column on rotation because the size *class*
        /// stays compact (iPhone portrait and landscape are both compact width).
        /// Force the split view and its collapsed compact column to re-layout to
        /// the current window bounds so the container view controllers pick up
        /// the new size and re-run their portrait/landscape constraints.
        ///
        /// Called on every rotation (from `windowScene(_:didUpdate:...)`) and also
        /// after the full-screen image viewer is dismissed: rotating while that
        /// viewer is presented deliberately skips the covered compact column (see
        /// below), so its frame is still whatever it was before the rotation —
        /// dismissal is not itself a rotation event, so nothing else re-runs this.
        func relayoutForCurrentWindowBounds() {
            guard let window = window else {
                NSLog("PGLWindowSceneDelegate.relayoutForCurrentWindowBounds: no window, bailing")
                return
            }
            NSLog("PGLWindowSceneDelegate.relayoutForCurrentWindowBounds: window.bounds=\(window.bounds)")
            window.rootViewController?.view.frame = window.bounds
            window.rootViewController?.view.setNeedsLayout()
            window.rootViewController?.view.layoutIfNeeded()

            // Only force the compact column's layout when it is actually the
            // visible content. When a view controller (e.g. the full-screen
            // image viewer) is presented on top, the compact column has no
            // window — forcing an AutoLayout activate/deactivate pass on
            // content that isn't part of the visible hierarchy crashed
            // (EXC_BAD_ACCESS deep in CoreAutoLayout). Forward the resize to
            // whatever is actually on screen instead.
            //
            // This runs AFTER the root's own layout pass above, not before:
            // UISplitViewController re-lays-out its compact column as part of
            // that pass using its own (stale) internal metrics, which was
            // silently overwriting a compact.view.frame assignment made
            // beforehand.
            if let split = window.rootViewController as? UISplitViewController,
               let compact = split.viewController(for: .compact) {
                if let presented = compact.presentedViewController ?? split.presentedViewController {
                    NSLog("PGLWindowSceneDelegate.relayoutForCurrentWindowBounds: presented branch, presented=\(presented), frame before=\(presented.view.frame)")
                    // Rotation in this app does not auto-resize anything (see
                    // the manual frame assignments above/below) — the
                    // presented view's frame must be set explicitly too, or
                    // its drawable size update has nothing new to read.
                    presented.view.frame = window.bounds
                    presented.view.setNeedsLayout()
                    presented.view.layoutIfNeeded()
                    NSLog("PGLWindowSceneDelegate.relayoutForCurrentWindowBounds: presented branch, frame after=\(presented.view.frame)")
                } else if compact.view.window != nil {
                    NSLog("PGLWindowSceneDelegate.relayoutForCurrentWindowBounds: compact branch, compact=\(compact), frame before=\(compact.view.frame)")
                    compact.view.frame = window.bounds
                    compact.view.setNeedsLayout()
                    compact.view.layoutIfNeeded()
                    NSLog("PGLWindowSceneDelegate.relayoutForCurrentWindowBounds: compact branch, frame after=\(compact.view.frame)")

                    // Reassigning the nav controller's own view frame does not
                    // cascade down to resize its currently-visible child VC's
                    // view — UINavigationController's internal content layout
                    // did not pick up the new bounds on its own. Force the top
                    // child directly too.
                    if let navCompact = compact as? UINavigationController,
                       let top = navCompact.topViewController {
                        NSLog("PGLWindowSceneDelegate.relayoutForCurrentWindowBounds: top child=\(top), frame before=\(top.view.frame)")
                        top.view.frame = compact.view.bounds

                        // Manually reassigning .frame does not make UIKit
                        // recompute safeAreaInsets — that normally only
                        // happens through a real system-driven resize. Left
                        // stale, it still reports portrait-shaped top/bottom
                        // insets after this forced landscape resize, so the
                        // safeArea-relative constraints below solve against
                        // the wrong safe area height (confirmed live: a
                        // control column height of 295 / image width of
                        // 491.67 are exactly what safeArea.height=295, the
                        // stale portrait value, produces — the correct
                        // landscape safeArea.height here is 393). Nudging
                        // additionalSafeAreaInsets forces
                        // viewSafeAreaInsetsDidChange to actually fire.
                        let nudge = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0.5)
                        top.additionalSafeAreaInsets = nudge
                        top.view.layoutIfNeeded()
                        top.additionalSafeAreaInsets = .zero

                        if let splitChild = top as? PGLTwoColumnSplitController {
                            // A plain setNeedsLayout/layoutIfNeeded is not
                            // enough: PGLTwoColumnSplitController caches
                            // which constraint set is active and only swaps
                            // it when its own notion of the orientation
                            // changes. That cache can already read the new
                            // orientation while the OLD constraint set is
                            // still the one actually active, so its own
                            // guard silently no-ops. Force it to re-decide.
                            NSLog("PGLWindowSceneDelegate.relayoutForCurrentWindowBounds: top child is PGLTwoColumnSplitController, forcing constraint re-swap")
                            splitChild.forceRelayoutForCurrentOrientation()
                        } else {
                            top.view.setNeedsLayout()
                            top.view.layoutIfNeeded()
                        }
                        NSLog("PGLWindowSceneDelegate.relayoutForCurrentWindowBounds: top child frame after=\(top.view.frame)")
                    }
                } else {
                    NSLog("PGLWindowSceneDelegate.relayoutForCurrentWindowBounds: compact has no window and nothing presented, skipping — compact=\(compact)")
                }
            } else {
                NSLog("PGLWindowSceneDelegate.relayoutForCurrentWindowBounds: rootViewController is not a UISplitViewController or has no compact column")
            }
        }
    }
