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

    /// Holds `columns.control`'s view over the full-bleed image. Never set to
    /// `alpha < 1` — the glass material provides the translucency, and a
    /// reduced alpha on the effect view (or a superview) breaks the effect.
    private var drawerView: UIVisualEffectView?
    private var collapseButton: UIButton?

    /// The handle strip left on screen when the drawer is collapsed.
    private let drawerHandleThickness: CGFloat = 44.0

    /// Fraction of the safe area the drawer occupies when expanded. Internal
    /// (not private) so PGLImageController can size a matching drawer-avoidance
    /// layout guide for its on-image sliders/controls, which otherwise sit
    /// exactly where the drawer floats now that the image is full-bleed.
    static let drawerPortraitHeightFraction: CGFloat = 0.45
    static let drawerLandscapeWidthFraction: CGFloat = 0.38

    /// Pins the image to the view's own edges — full-bleed, one constraint
    /// set, never swapped on rotation. (Previously the landscape image width
    /// was `safeArea.heightAnchor * 5/3`; a live lldb session traced the
    /// squeezed-column bug to that math executing correctly against a wrong
    /// safe-area height after a full-screen dismiss + rotate. Removing the
    /// safe-area dependency from the image entirely makes that failure mode
    /// unreachable rather than patched.)
    private var imageConstraints: [NSLayoutConstraint] = []

    private var drawerSizeConstraint: NSLayoutConstraint?
    private var drawerCrossAxisConstraints: [NSLayoutConstraint] = []
    private var drawerAttachmentConstraint: NSLayoutConstraint?

    private var isDrawerCollapsed = false

    /// Prefer the live interface orientation; fall back to the view bounds
    /// before a window exists.
    private var isPortraitLayout: Bool {
        if let scene = view.window?.windowScene {
            return scene.effectiveGeometry.interfaceOrientation.isPortrait
        }
        return view.bounds.height > view.bounds.width
    }

    /// Which drawer arrangement is currently active, so layout passes only
    /// rebuild when the orientation of this view's own bounds actually changes.
    private var activeLayoutIsPortrait: Bool?

    func layoutViews(_ imageView: UIView, _ controlView: UIView) {
        guard let drawerView else { return }

        NSLayoutConstraint.deactivate(imageConstraints)
        imageConstraints = [
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ]
        NSLayoutConstraint.activate(imageConstraints)

        applyDrawerConstraints(drawerView, controlView, portrait: isPortraitLayout, animated: false)
    }

    /// Rebuilds the drawer's constraint set for a given orientation/collapsed
    /// state. Only the drawer moves on rotation — the image's constraints
    /// above are untouched by this method.
    private func applyDrawerConstraints(_ drawerView: UIVisualEffectView, _ controlView: UIView, portrait: Bool, animated: Bool) {
        let safeArea = view.safeAreaLayoutGuide

        drawerSizeConstraint?.isActive = false
        NSLayoutConstraint.deactivate(drawerCrossAxisConstraints)
        drawerAttachmentConstraint?.isActive = false

        let sizeConstraint: NSLayoutConstraint
        let crossAxisConstraints: [NSLayoutConstraint]
        let attachmentConstraint: NSLayoutConstraint

        if portrait {
            sizeConstraint = drawerView.heightAnchor.constraint(equalTo: safeArea.heightAnchor, multiplier: Self.drawerPortraitHeightFraction)
            crossAxisConstraints = [
                drawerView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
                drawerView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor)
            ]
            attachmentConstraint = isDrawerCollapsed
                ? drawerView.topAnchor.constraint(equalTo: view.bottomAnchor, constant: -drawerHandleThickness)
                : drawerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        } else {
            sizeConstraint = drawerView.widthAnchor.constraint(equalTo: safeArea.widthAnchor, multiplier: Self.drawerLandscapeWidthFraction)
            crossAxisConstraints = [
                drawerView.topAnchor.constraint(equalTo: safeArea.topAnchor),
                drawerView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor)
            ]
            attachmentConstraint = isDrawerCollapsed
                ? drawerView.trailingAnchor.constraint(equalTo: view.leadingAnchor, constant: drawerHandleThickness)
                : drawerView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        }

        drawerSizeConstraint = sizeConstraint
        drawerCrossAxisConstraints = crossAxisConstraints
        drawerAttachmentConstraint = attachmentConstraint
        NSLayoutConstraint.activate(crossAxisConstraints + [sizeConstraint, attachmentConstraint])
        activeLayoutIsPortrait = portrait

        updateCollapseButton(portrait: portrait)

        if animated {
            UIView.animate(withDuration: 0.3) { [weak self] in
                self?.view.layoutIfNeeded()
            }
        }
    }

    private func updateCollapseButton(portrait: Bool) {
        guard let collapseButton else { return }
        let collapsedSymbol = portrait ? "chevron.up" : "chevron.right"
        let expandedSymbol = portrait ? "chevron.down" : "chevron.left"
        collapseButton.setImage(UIImage(systemName: isDrawerCollapsed ? collapsedSymbol : expandedSymbol), for: .normal)
    }

    @objc private func toggleDrawerCollapsed() {
        guard let drawerView, let controlView = columns?.control.view else { return }
        isDrawerCollapsed.toggle()
        applyDrawerConstraints(drawerView, controlView, portrait: isPortraitLayout, animated: true)
    }

    /// Vector-type parms (point/rect/gradient-corner) place a draggable
    /// positionView directly on the image at the parm's own stored
    /// coordinates. Unlike the on-image slider, that position can't be
    /// nudged aside — it IS the value being edited — so when one becomes
    /// active the only fix is getting the drawer out of the way. Called by
    /// PGLSelectParmController when such a row is selected; a no-op if
    /// already collapsed.
    func collapseDrawerForPositionEditing() {
        guard !isDrawerCollapsed, let drawerView, let controlView = columns?.control.view else { return }
        isDrawerCollapsed = true
        applyDrawerConstraints(drawerView, controlView, portrait: isPortraitLayout, animated: true)
    }

    /// Rebuild the drawer set only when this view's own bounds change
    /// orientation (iPhone portrait ↔ landscape). Done in a layout pass rather
    /// than viewWillTransition: covered controllers in the nav stack also
    /// receive viewWillTransition while their views still hold the old size,
    /// and activating landscape constraints on a portrait-sized view is
    /// unsatisfiable — UIKit breaks a constraint and the drawer collapses to
    /// zero size when the controller reappears.
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        guard let drawerView, let controlView = columns?.control.view else { return }

        let portrait = view.bounds.height > view.bounds.width
        guard portrait != activeLayoutIsPortrait else { return }

        applyDrawerConstraints(drawerView, controlView, portrait: portrait, animated: false)
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

        let effectView = UIVisualEffectView(effect: UIGlassEffect())
        effectView.translatesAutoresizingMaskIntoConstraints = false
        // Dark override so .label/.systemBackground-style content resolves
        // light-on-dark, matching glass over live imagery without recoloring
        // every control individually.
        effectView.overrideUserInterfaceStyle = .dark
        view.addSubview(effectView)
        drawerView = effectView

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .white
        button.addTarget(self, action: #selector(toggleDrawerCollapsed), for: .touchUpInside)
        effectView.contentView.addSubview(button)
        collapseButton = button
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: drawerHandleThickness),
            button.heightAnchor.constraint(equalToConstant: drawerHandleThickness),
            button.topAnchor.constraint(equalTo: effectView.contentView.topAnchor),
            button.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor)
        ])

        effectView.contentView.addSubview(controlView)
        NSLayoutConstraint.activate([
            controlView.topAnchor.constraint(equalTo: effectView.contentView.topAnchor, constant: drawerHandleThickness),
            controlView.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor),
            controlView.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor),
            controlView.bottomAnchor.constraint(equalTo: effectView.contentView.bottomAnchor)
        ])

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
        collapseButton?.removeFromSuperview()
        collapseButton = nil
        drawerView?.removeFromSuperview()
        drawerView = nil
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
