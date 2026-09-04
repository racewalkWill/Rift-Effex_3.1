//
//  PGLTwoColumnSplitController.swift
//  RiftEffects
//
//  Created by Will on 2/14/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//
import UIKit
import os
import Combine

class PGLTwoColumnSplitController: UIViewController {
    struct PGLColumns {
        var control: UIViewController
        var imageViewer: UIViewController
    }

    var columns: PGLColumns?

    var publishers = [any Cancellable]()
    var cancellable: (any Cancellable)?

    /// Constraints for the side-by-side (landscape) arrangement: control on the
    /// left, wide image on the right. This is the original/current layout.
    private var horizontalConstraints: [NSLayoutConstraint] = []

    /// Constraints for the single-column (portrait) arrangement: image on top,
    /// controls stacked below — used in portrait on iPhone.
    private var verticalConstraints: [NSLayoutConstraint] = []

    /// Portrait uses the single-column layout. Prefer the live interface
    /// orientation; fall back to the view bounds before a window exists.
    private var isPortraitLayout: Bool {
        if let scene = view.window?.windowScene {
            return scene.effectiveGeometry.interfaceOrientation.isPortrait
        }
        return view.bounds.height > view.bounds.width
    }

    /// Which constraint set is currently active, so layout passes only swap
    /// when the orientation of this view's own bounds actually changes.
    private var activeLayoutIsPortrait: Bool?

    func layoutViews(_ imageView: UIView, _ controlView: UIView) {
            //        let spacer = -5.0
            // for iPad and iPhone Plus.. with three column split view

        // Remove any constraints from a prior layout pass before rebuilding.
        // (FilterImageContainerController re-calls this in viewIsAppearing.)
        NSLayoutConstraint.deactivate(horizontalConstraints + verticalConstraints)

        let safeArea = view.safeAreaLayoutGuide
        let imageWidthFactor: Double = 5/3

        // Landscape: control on the left, wide image on the right (4:3-ish).
        horizontalConstraints = [
            imageView.rightAnchor.constraint(equalTo: view.rightAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: safeArea.heightAnchor, multiplier: imageWidthFactor),
            // width to height 4:3 ratio
            controlView.rightAnchor.constraint(equalTo: imageView.leftAnchor, constant:  -30.0),
            controlView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            controlView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            controlView.leftAnchor.constraint(equalTo: safeArea.leftAnchor)
        ]

        // Portrait (iPhone): single column — image on top, controls below.
        verticalConstraints = [
            imageView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: safeArea.heightAnchor, multiplier: 0.55),
            controlView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8.0),
            controlView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            controlView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            controlView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor)
        ]

        let portrait = isPortraitLayout
        NSLayoutConstraint.activate(portrait ? verticalConstraints : horizontalConstraints)
        activeLayoutIsPortrait = portrait
    }

    /// Swap the active constraint set when this view's own bounds change
    /// orientation (iPhone portrait ↔ landscape). Done in a layout pass rather
    /// than viewWillTransition: covered controllers in the nav stack also
    /// receive viewWillTransition while their views still hold the old size,
    /// and activating landscape constraints on a portrait-sized view is
    /// unsatisfiable — UIKit breaks a constraint and the columns collapse
    /// (zero-height control view) when the controller reappears.
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        // Nothing to swap until the columns have been laid out at least once.
        guard !verticalConstraints.isEmpty else { return }

        let portrait = view.bounds.height > view.bounds.width
        guard portrait != activeLayoutIsPortrait else { return }

        NSLayoutConstraint.deactivate(horizontalConstraints + verticalConstraints)
        NSLayoutConstraint.activate(portrait ? verticalConstraints : horizontalConstraints)
        activeLayoutIsPortrait = portrait
    }

    /// Forces the portrait/landscape constraint swap on the next layout
    /// pass, bypassing the `activeLayoutIsPortrait` cache. Needed when this
    /// controller's view is resized programmatically from outside a normal
    /// rotation this instance itself observed — e.g.
    /// PGLWindowSceneDelegate.relayoutForCurrentWindowBounds forcing a
    /// covered controller's frame back to the current window bounds after
    /// the full-screen image viewer is dismissed. Without this, the cache
    /// can already read the "correct" orientation while the wrong
    /// constraint set is still the one actually active, so
    /// viewWillLayoutSubviews's own guard silently skips the swap.
    func forceRelayoutForCurrentOrientation() {
        activeLayoutIsPortrait = nil
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        guard let theImageController = columns?.imageViewer as? PGLImageController
            else { return }
        theImageController.postImageViewWillAppear()
        // make sure a redraw occurs in the Renderer PGLRedraw logic
    }

    func loadViewColumns(controller: UIViewController, imageViewer: UIViewController ) {

        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function) + \(controller)")

        columns = PGLColumns(control: controller, imageViewer: imageViewer)

        addChild(columns!.imageViewer)
        addChild(columns!.control)

        guard let controlView = controller.view else
            { return     }
        guard let imageView = imageViewer.view else
            { return     }

        controlView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(imageView)
        view.addSubview(controlView)

        layoutViews(imageView, controlView)

            // Notify the child view controller that the move is complete.
        controller.didMove(toParent: self)
        imageViewer.didMove(toParent: self)

    }

    func viewControllerRelease() {
        if columns != nil {
            viewControllerReleaseBasic(aPGLController: columns!.control)
            viewControllerReleaseBasic(aPGLController: columns!.imageViewer)
        }
    }

    func viewControllerReleaseBasic(aPGLController: UIViewController) {
        Logger(subsystem: LogSubsystem, category: LogNavigation).info( "\("#viewControllerReleaseBasic " + String(describing: self)) +  \(aPGLController)")
        aPGLController.view.removeFromSuperview()
        aPGLController.removeFromParent()

        aPGLController.releaseNotifications()
        aPGLController.resetVars()
    }

    func imageController() -> PGLCompactImageController? {
        // all of the subclasses use the imageController
        return columns?.imageViewer as? PGLCompactImageController
    }

    override func releaseNotifications() {
        super.releaseNotifications()
        for aCancel in publishers {
            aCancel.cancel()
        }
        publishers = [any Cancellable]()
     }

}
