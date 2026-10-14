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

    /// Pins the image to the view's own edges, full-bleed apart from the
    /// drawer, and rebuilt by `applyLayout` for whichever of the two fixed
    /// portrait/landscape arrangements is currently active — including on
    /// rotation. (Previously the landscape image width was
    /// `safeArea.heightAnchor * 5/3`; a live lldb session traced the
    /// squeezed-column bug to that math executing correctly against a wrong
    /// safe-area height after a full-screen dismiss + rotate. Removing the
    /// safe-area dependency from the image entirely makes that failure mode
    /// unreachable rather than patched.)
    private var imageConstraints: [NSLayoutConstraint] = []

    private var drawerSizeConstraint: NSLayoutConstraint?
    private var drawerCrossAxisConstraints: [NSLayoutConstraint] = []
    private var drawerAttachmentConstraint: NSLayoutConstraint?

    private var isDrawerCollapsed = false

    /// Optional search controller for the drawer's list (set by subclasses).
    /// In portrait it is this controller's navigationItem search field. In
    /// landscape the navigation bar moves the field into the bottom toolbar,
    /// which spans the full width over the image, so the search bar is
    /// placed instead in the drawer's top handle strip beside the collapse button.
    var drawerSearchController: UISearchController? {
        didSet { placeDrawerSearchBar() }
    }

    /// controlView bottom-to-drawer; swapped for bottom-to-search-bar while
    /// the search bar is in the drawer (landscape).
    private var controlViewBottomConstraint: NSLayoutConstraint?
    private var drawerSearchBarConstraints: [NSLayoutConstraint] = []

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
        applyLayout(imageView, controlView, drawerView, portrait: isPortraitLayout, animated: false)
    }

    /// Rebuilds both the image and drawer constraints for a given
    /// orientation. `portrait` is passed in rather than read from
    /// `isPortraitLayout` here so every caller can decide, once, which signal
    /// (scene geometry at load/appear time vs. this view's own bounds during
    /// a live rotation) to trust — see `viewWillLayoutSubviews`.
    private func applyLayout(_ imageView: UIView, _ controlView: UIView, _ drawerView: UIVisualEffectView, portrait: Bool, animated: Bool) {
        NSLayoutConstraint.deactivate(imageConstraints)

        if portrait {
            imageConstraints = [
                imageView.topAnchor.constraint(equalTo: view.topAnchor),
                imageView.bottomAnchor.constraint(equalTo: drawerView.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ] }
        else {
            imageConstraints = [
                imageView.topAnchor.constraint(equalTo: view.topAnchor),
                imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                imageView.leadingAnchor.constraint(equalTo: drawerView.trailingAnchor),
                imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ]
        }
        applyDrawerConstraints(drawerView, controlView, portrait: portrait, animated: animated)

        NSLayoutConstraint.activate(imageConstraints)
    }

    /// Rebuilds the drawer's constraint set for a given orientation/collapsed
    /// state. Called both standalone (collapse/expand toggling, where the
    /// image doesn't need to move) and from `applyLayout`, which rebuilds the
    /// image constraints alongside it for an orientation change.
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
                ? drawerView.trailingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: drawerHandleThickness)
                : drawerView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor)
        }

        drawerSizeConstraint = sizeConstraint
        drawerCrossAxisConstraints = crossAxisConstraints
        drawerAttachmentConstraint = attachmentConstraint
        NSLayoutConstraint.activate(crossAxisConstraints + [sizeConstraint, attachmentConstraint])
        activeLayoutIsPortrait = portrait

        updateCollapseButton(portrait: portrait)
        placeDrawerSearchBar()

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

    /// Moves `drawerSearchController`'s search bar between the navigation bar
    /// (portrait, where the system shows it at the bottom) and the bottom of
    /// the drawer (landscape). Called on every drawer constraint rebuild, so
    /// orientation and collapse changes both apply.
    private func placeDrawerSearchBar() {
        guard let searchController = drawerSearchController,
              let drawerView,
              let portrait = activeLayoutIsPortrait
            else { return }
        let searchBar = searchController.searchBar

        if portrait {
            if searchBar.superview === drawerView.contentView {
                detachSearchBarFromDrawer(searchBar)
            }
            if navigationItem.searchController !== searchController {
                navigationItem.searchController = searchController
            }
        } else {
            if navigationItem.searchController === searchController {
                navigationItem.searchController = nil
                // The navigation bar finishes releasing the search bar in a later
                // layout pass - removing it from (or hiding it in) whatever view
                // it is in by then. Attaching immediately left the field invisible
                // until a drawer toggle re-attached it, so attach after that pass.
                DispatchQueue.main.async { [weak self] in
                    self?.attachSearchBarToDrawer(searchBar)
                }
            } else {
                attachSearchBarToDrawer(searchBar)
            }
        }
    }

    /// Re-places the search bar after its UISearchController presents or
    /// dismisses. Deactivating the search controller (e.g. the keyboard closing
    /// on an empty field) re-parents or hides its bar, and nothing else re-runs
    /// placement until the next drawer rebuild. Deferred so the search
    /// controller finishes its own bar handling first.
    func refreshDrawerSearchBar() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let searchBar = self.drawerSearchController?.searchBar else { return }
            if self.activeLayoutIsPortrait == false {
                self.attachSearchBarToDrawer(searchBar)
            }
        }
    }

    /// Landscape only: pins the search bar along the drawer's bottom edge and
    /// ends the control view just above it.
    private func attachSearchBarToDrawer(_ searchBar: UISearchBar) {
        guard let drawerView, let controlView = columns?.control.view,
              activeLayoutIsPortrait == false,
              navigationItem.searchController == nil
            else { return }
        let contentView = drawerView.contentView

        if searchBar.superview !== contentView {
            searchBar.removeFromSuperview()
            searchBar.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(searchBar)
            controlViewBottomConstraint?.isActive = false
            drawerSearchBarConstraints = [
                searchBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                searchBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                searchBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                controlView.bottomAnchor.constraint(equalTo: searchBar.topAnchor)
            ]
            NSLayoutConstraint.activate(drawerSearchBarConstraints)
        }
            // the navigation bar may have faded the bar out while hosting it
        searchBar.alpha = 1
        searchBar.searchTextField.alpha = 1
            // a collapsed landscape drawer is only the handle width
        searchBar.isHidden = isDrawerCollapsed
        contentView.layoutIfNeeded()
    }

    private func detachSearchBarFromDrawer(_ searchBar: UISearchBar) {
        NSLayoutConstraint.deactivate(drawerSearchBarConstraints)
        drawerSearchBarConstraints = []
        searchBar.removeFromSuperview()
        searchBar.translatesAutoresizingMaskIntoConstraints = true
        searchBar.isHidden = false
        controlViewBottomConstraint?.isActive = true
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

        guard let drawerView, let controlView = columns?.control.view,
              let imageView = columns?.imageViewer.view else { return }

        let portrait = view.bounds.height > view.bounds.width
        guard portrait != activeLayoutIsPortrait else { return }

        applyLayout(imageView, controlView, drawerView, portrait: portrait, animated: false)
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

        // The drawer only spans the safe area, not this view's full bounds, so
        // in landscape a strip above/below it (status bar / home indicator
        // area) shows this view's own background. Black matches the glass
        // drawer's dark styling and the image's own letterboxing.
        view.backgroundColor = .black

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
        let controlBottom = controlView.bottomAnchor.constraint(equalTo: effectView.contentView.bottomAnchor)
        controlViewBottomConstraint = controlBottom
        NSLayoutConstraint.activate([
            controlView.topAnchor.constraint(equalTo: effectView.contentView.topAnchor, constant: drawerHandleThickness),
            controlView.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor),
            controlView.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor),
            controlBottom
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
