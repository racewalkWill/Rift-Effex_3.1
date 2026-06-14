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

        NSLayoutConstraint.activate(isPortraitLayout ? verticalConstraints : horizontalConstraints)
    }

    /// Swap the active constraint set when the device rotates (iPhone portrait
    /// ↔ landscape). Landscape keeps the original side-by-side layout.
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        let toPortrait = size.height > size.width
        let newConstraints = toPortrait ? verticalConstraints : horizontalConstraints
        // Nothing to swap until the columns have been laid out at least once.
        guard !newConstraints.isEmpty else { return }

        NSLayoutConstraint.deactivate(horizontalConstraints + verticalConstraints)
        NSLayoutConstraint.activate(newConstraints)
        coordinator.animate(alongsideTransition: { _ in
            self.view.layoutIfNeeded()
        })
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
