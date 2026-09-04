//
//  PGLMainFilterController.swift
//  Glance
//
//  Created by Will on 5/30/19.
//  Copyright © 2019 Will. All rights reserved.
//

import UIKit
import os
import Combine

enum FilterChangeMode{
    case replace
    case add
}


let PGLFilterBookMarksSetFlat = NSNotification.Name(rawValue: "PGLFilterBookMarksSetFlat")

@MainActor
class PGLMainFilterController:  UIViewController,
                                    UINavigationControllerDelegate, UISplitViewControllerDelegate,UIPopoverPresentationControllerDelegate,
                                    UICollectionViewDelegate {
        //UIDragInteractionDelegate, UIDropInteractionDelegate


        // MARK: ListView
     struct Item: Hashable {
        let title: String?
        let descriptor: PGLFilterDescriptor?
            // if nil then use the title for the category
    }

     var dataSource: UICollectionViewDiffableDataSource<Int, Item>! = nil
     var filterCollectionView: UICollectionView! = nil

    private let appearance = UICollectionLayoutListConfiguration.Appearance.insetGrouped
    // assigned in configureHierarchy of viewDidLoad
    var searchBar: UISearchBar!

    // MARK: model vars
    var stackData: () -> PGLFilterStack?  = { PGLFilterStack() } // a function is assigned to this var that answers the filterStack

    var appStack: PGLAppStack!

    var categories = PGLFilterCategory.allFilterCategories()

    var filters = PGLFilterCategory.filterDescriptors

    override var undoManager: UndoManager? {
           // Return a shared  undo manager
        if let myAppStack = appStack {
            return myAppStack.appStackUndoManager }
        else {
             return  super.undoManager
            }
       }

    var matchFilters = [PGLFilterDescriptor]()

    let frequentCategoryPath = IndexPath(row:0,section: 0)

    var longPressGesture: UILongPressGestureRecognizer!
    var longPressStart: IndexPath?

    var guideStepIndex: IndexPath?
        // only set in PGLDemo.GuideMode
        // index of a cell with guideArrow -
        // scroll to the spot so user can see it

    // MARK: - Constants
    static let tableViewCellIdentifier = "cellID"
    private static let nibName = "TableCell"

    var publishers = [any Cancellable]()
    var cancellable: (any Cancellable)?


    @IBOutlet weak var guideArrowBtn: UIBarButtonItem! {
        didSet {
            guideArrowBtn.isHidden = true
        }
    }

    
    deinit {
//        releaseVars()
        Logger(subsystem: LogSubsystem, category: LogMemoryRelease).info("\( String(describing: self) + " - deinit" )")
//        releaseNotifications()
    }

   override func releaseNotifications() {
       Logger(subsystem: LogSubsystem, category: LogMemoryRelease).info("\( String(describing: self) + " - releaseNotifications" )")
        for aCancel in publishers {
            aCancel.cancel()
        }
       publishers = [any Cancellable]()
    }

        ///empty method   does not need to release
   override func resetVars() {
        //sure about not releasing??
       Logger(subsystem: LogSubsystem, category: LogMemoryRelease).info("\( String(describing: self) + " - resetVars" )")
       releaseNotifications()
//       if filterCollectionView != nil {
//        filterCollectionView.removeFromSuperview()
//       }
//       dataSource = nil
//       filterCollectionView = nil
    }

    // MARK: Filter Navigator Modes

    enum FilterNavigatorMode: String
    {
        case Grouped
        case Flat
    }

    var mode: FilterNavigatorMode = .Grouped  // default flat
    {
        didSet
        {
            filterCollectionView.reloadData()
        }
    }

    enum Header: Int {
        case AllFilter = 0
        case Category = 1
    }
        // MARK: - Types

        /// State restoration values.
    private enum RestorationKeys: String {
        case viewControllerTitle
        case searchControllerIsActive
        case searchBarText
        case searchBarIsFirstResponder
    }

        /// NSPredicate expression keys.
    private enum ExpressionKeys: String {
        case displayName
            //        case yearIntroduced
            //        case introPrice
    }

    private struct SearchControllerRestorableState {
        var wasActive = false
        var wasFirstResponder = false
    }

    /** The following 2 properties are set in viewDidLoad(),
     They are implicitly unwrapped optionals because they are used in many other places
     throughout this view controller.
     */

        /// Search controller to help us with filtering.
    private var searchController: UISearchController!
        //    var filterGroupSymbol = UIImage(systemName: "chart.bar.doc.horizontal")
        //    var filterFlatSymbol = UIImage(systemName: "crectangle.grid.1x2")
        /// Secondary search results table view.
//    private var resultsTableController: PGLResultsController!

        /// Restoration state for UISearchController
    private var restoredState = SearchControllerRestorableState()

    @IBAction func backButtonAction(_ sender: UIBarButtonItem) {
        Logger(subsystem: LogSubsystem, category: LogNavigation).info( "\("#popViewController " + String(describing: self))")
        self.navigationController?.popViewController(animated: true)

    }

    @IBAction func showImageController(_ sender: UIBarButtonItem) {
        splitViewController?.show(.secondary)
        postCurrentFilterChange() // triggers PGLImageController to set view.isHidden to false
    }


        // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // MARK: List Setup

        configureHierarchy()
        configureDataSource()
        loadSearchController()
        selectCurrentFilterRow()

        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")

        splitViewController?.delegate = self
        guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
            else { Logger(subsystem: LogSubsystem, category: LogCategory).fault ("PGLFilterTableController viewDidLoad fatalError AppDelegate not loaded")
                return
        }
        appStack = myAppDelegate.appStack
        // [weak self]: stackData is a stored closure property, so `{ self... }`
        // would retain-cycle (self -> stackData -> closure -> self) and leak this
        // controller. releaseNotifications() does not reset it, so it must be weak.
        stackData = { [weak self] in self?.appStack.viewerStack }
        // closure is evaluated when referenced
//        navigationItem.title = "Effex" //thisStack.stackName

        let myCenter =  NotificationCenter.default

        cancellable = myCenter.publisher(for: PGLLoadedDataStack )
            .sink() {[weak self]
                myUpdate in
               Logger(subsystem: LogSubsystem, category: LogNavigation).info("PGLFilterTableController  notificationBlock PGLLoadedDataStack")
                guard let self = self else { return } // a released object sometimes receives the notification
                              // the guard is based upon the apple sample app 'Conference-Diffable'
              Logger(subsystem: LogSubsystem, category: LogNavigation).info( "\("#popViewController " + String(describing: self))")
                self.navigationController?.popViewController(animated: true)
            }
        publishers.append(cancellable!)
        setLongPressGesture()

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setLongPressGesture()

            // Restore the searchController's active state.
        if restoredState.wasActive {
            searchController.isActive = restoredState.wasActive
            restoredState.wasActive = false

            if restoredState.wasFirstResponder {
                searchController.searchBar.becomeFirstResponder()
                restoredState.wasFirstResponder = false
            }
        }
        if PGLDemo.GuideMode {
            if guideStepIndex != nil {
                filterCollectionView.scrollToItem(
                    at: guideStepIndex!,
                    at: .centeredVertically,
                    animated: true)
                guideStepIndex = nil // reset after use
            }
        }

    }

    override func viewWillDisappear(_ animated: Bool) {
        removeGestureRecogniziers(targetView: filterCollectionView)
    }

    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
        if showGuideArrowBack() {
            filterCollectionView.reloadData()
            // force off any guide symbols because back navigation is running
        }

    }

    override func viewDidDisappear(_ animated: Bool) {
        super .viewDidDisappear(animated)
        Logger(subsystem: LogSubsystem, category: LogCategory).debug("PGLMainFilterController #viewDidDisappear releaseNotifications")

       releaseNotifications()
    }

    func showGuideArrowBack() -> Bool {
        var showGuideBackArrow: Bool = false
        if PGLDemo.GuideMode {
            if PGLGuide.Steps.shouldNavigateBack()  {
                guideArrowBtn?.isHidden = false
                showGuideBackArrow = true
            } else {
                guideArrowBtn?.isHidden = true
            }
        } else {
            guideArrowBtn?.isHidden = true
        }
        setNeedsStatusBarAppearanceUpdate()
        return showGuideBackArrow
    }

        // MARK: SplitView
        func targetDisplayModeForAction(in svc: UISplitViewController) -> UISplitViewController.DisplayMode {
            if svc.displayMode == UISplitViewController.DisplayMode.secondaryOnly {
                // don't let parms list overlay the picture...
                Logger(subsystem: LogSubsystem, category: LogCategory).info("PGLSelectFilterController #targetDisplayModeForAction answers allVisible ")
                return UISplitViewController.DisplayMode.oneBesideSecondary
            }
            else { Logger(subsystem: LogSubsystem, category: LogCategory).info("PGLSelectFilterController #targetDisplayModeForAction answers automatic ")
                return UISplitViewController.DisplayMode.automatic}
        }

    func performFilterPick(descriptor: PGLFilterDescriptor) {

//        Logger(subsystem: LogSubsystem, category: LogCategory).info("PGLFilterTableController performFilterPick \(descriptor)")
        if let selectedFilter = descriptor.pglSourceFilter() {
            performBasicPick(filter: selectedFilter)

            // Registers on the persistent appStack (see extension PGLAppStack) so
            // the shared undo manager does not retain this controller.
            appStack.registerUndoAddFilter(selectedFilter)
        }
    }

    func performBasicPick(filter: PGLSourceFilter) {
        stackData()?.performFilterPick(selectedFilter: filter)
            // depending on mode will replace or add to the stack
        filter.addChildSequenceStack(appStack: appStack) // usually empty method except for the PGLSequencedFilters
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("filter set = \(String(describing: filter.filterName))")

            // post notification that filter is changed. The parmSettings manager should listen
        updateFilterLabel()
        postImageChange()
        postCurrentFilterChange()
        appStack.resetCellFilters()
    }


   override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
    if let theCell =  sender as? UITableViewCell {
        return theCell.isSelected
            // if the cell is not selected then don't go to parms..
            // this means there is no current filter
    } else
        { return false }
    }


    func updateFilterLabel()  {
        // some overlap with the configureCell...
        if stackData() != nil {
        _ = stackData()!

        }
}


    // MARK: - LongPressGestures
    func setLongPressGesture() {
        // Called from BOTH viewDidLoad and viewDidAppear. A UIGestureRecognizer keeps a
        // strong reference to its target, and filterCollectionView keeps a strong reference
        // to the recognizer, so each new recognizer forms the cycle
        // self -> view -> filterCollectionView -> recognizer -> self.
        // These are distinct recognizer objects (not identical target-action pairs, so UIKit
        // does not dedupe them), so without removing the previous one first every appearance
        // leaves an orphaned recognizer attached that retains self forever - leaking this
        // controller and the UISearchController it owns. Remove any existing one first.
        removeGestureRecogniziers(targetView: filterCollectionView)

        longPressGesture = UILongPressGestureRecognizer(target: self , action: #selector(PGLMainFilterController.longPressAction(_:)))
          if longPressGesture != nil {

//                 " defaults to 0.5 sec 1 finger 10 points allowed movement"
              filterCollectionView.addGestureRecognizer(longPressGesture!)
              longPressGesture!.isEnabled = true
//            Logger(subsystem: LogSubsystem, category: LogCategory).notice("PGLFilterTableController setLongPressGesture \(String(describing: self.longPressGesture))")
          }
      }

    func removeGestureRecogniziers(targetView: UIView) {
       // not called in viewWillDissappear..
       // recognizier does not seem to get restored if removed...
        if longPressGesture != nil {
            filterCollectionView.removeGestureRecognizer(longPressGesture!)
            longPressGesture!.removeTarget(self, action: #selector(PGLMainFilterController.longPressAction(_:)))
            longPressGesture = nil
//           NSLog("PGLFilterTableController removeGestureRecogniziers ")
       }

    }

    @objc func longPressAction(_ sender: UILongPressGestureRecognizer) {

        let pressLocation = sender.location(in: filterCollectionView)

        if sender.state == .began
        {
            Logger(subsystem: LogSubsystem, category: LogCategory).debug("PGLFilterTableController longPressAction begin")
            longPressStart =  filterCollectionView.indexPathForItem(at: pressLocation)

        }
        if sender.state == .recognized || sender.state == .ended {
            if longPressStart != nil {
                guard let tableCell = filterCollectionView.cellForItem(at: longPressStart!) else { return  }

                if let thisDescriptor = dataSource.itemIdentifier(for: longPressStart!)?.descriptor {
                    popUpFilterDescription(filterName: thisDescriptor.displayName , filterText: thisDescriptor.userDescription, filterCell: tableCell)
                }
            }
        }
    }


    func popUpFilterDescription(filterName: String, filterText: String, filterCell: UICollectionViewCell) {
        guard let helpController = storyboard?.instantiateViewController(withIdentifier: "PGLPopUpFilterInfo") as? PGLPopUpFilterInfo
        else {
            return
        }
        helpController.modalPresentationStyle = .popover
       helpController.preferredContentSize = CGSize(width: 200, height: 350.0)
        // specify anchor point?
        guard let popOverPresenter = helpController.popoverPresentationController
        else { return }
        popOverPresenter.sourceView = filterCell
        let sheet = popOverPresenter.adaptiveSheetPresentationController //adaptiveSheetPresentationController
        sheet.detents = [.medium(), .large()]
//        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        sheet.prefersEdgeAttachedInCompactHeight = true
        sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true

        helpController.textInfo =  filterText
        helpController.filterName = filterName

        present(helpController, animated: true )

    }


// MARK: Notification
 func postImageChange() {
     // PGLImageViewWillAppear triggers the Renderer to draw three frames even  is paused
     
     Logger(subsystem: LogSubsystem, category: LogCategory).notice("PGLMainFilterController notify PGLImageViewWillAppear")
    let updateFilterNotification = Notification(name: PGLImageViewWillAppear)
    NotificationCenter.default.post(updateFilterNotification)

}

 func postCurrentFilterChange() {

    let updateFilterNotification = Notification(name:PGLHideParmControlsOnFilterChange)

     NotificationCenter.default.post(name: updateFilterNotification.name, object: nil, userInfo: ["sender" : self as AnyObject])
     if showGuideArrowBack() {
         filterCollectionView.reloadData()
         // force off any guide symbols because back navigation is running
     }
}

    // MARK: unwind segue code. Triggered from PGLSelectParm
    @IBAction func goToChildStack(segue: UIStoryboardSegue) {
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("PGLParmsFilterTabsController goToChildStack segue")

    }

    @IBAction func goToParentFilterStack(segue: UIStoryboardSegue) {
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("PGLParmsFilterTabsController goToParentFilterStack segue")

    }

}
    // MARK: - Navigation


    extension PGLMainFilterController: UISearchBarDelegate {

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            Logger(subsystem: LogSubsystem, category: LogCategory).debug("PGLMainFilterController searchBarSearchButtonClicked")
            searchBar.resignFirstResponder()
        }

    }

    // MARK: - UISearchControllerDelegate

    // Use these delegate functions for additional control over the search controller.

extension PGLMainFilterController: UISearchControllerDelegate {

        func didPresentSearchController(_ searchController: UISearchController) {

            searchController.searchBar.becomeFirstResponder()
            Logger(subsystem: LogSubsystem, category: LogCategory).info("UISearchControllerDelegate invoked method: \(#function).")
        }

        func didDismissSearchController(_ searchController: UISearchController) {
            initalFilterList()
            Logger(subsystem: LogSubsystem, category: LogCategory).debug("UISearchControllerDelegate invoked method: \(#function).")
        }

}


extension PGLMainFilterController: UISearchResultsUpdating {
            //MARK: SearchController setup
    fileprivate func loadSearchController() {

        // called by viewDidLoad()
        searchController = UISearchController(searchResultsController: nil)


        searchController.searchResultsUpdater = self
        searchController.delegate = self

        searchController.automaticallyShowsCancelButton = true

            // IF iPhone then PGLNavStackImageController has the navigation item

        navigationItem.searchController = searchController

        searchController.searchBar.delegate = self
        navigationController?.isToolbarHidden = false
        searchController.hidesNavigationBarDuringPresentation = false


        /** Specify that this view controller determines how the search controller is presented.
         The search controller should be presented modally and match the physical size of this view controller.
         */
        definesPresentationContext = false

    }




    func updateSearchResults(for searchController: UISearchController) {
        // Update the filtered array based on the search text.
        let allFilters : [PGLFilterDescriptor] = filters
//            mode = .Flat // change later to support search in the grouped mode

        // Strip out all the leading and trailing spaces.
        let whitespaceCharacterSet = CharacterSet.whitespaces
        var strippedString =
            searchController.searchBar.text!.trimmingCharacters(in: whitespaceCharacterSet)
        if !strippedString.isEmpty {
            strippedString = strippedString.lowercased()
            let resultSet = allFilters.filter( {
                 let localName = $0.displayName.lowercased()
                    return localName.contains(strippedString)
            } )

            let filteredResults = Array(resultSet)
                // Apply the filtered results to the search results table.
            displaySearchResults(matchingFilters: filteredResults)
        } else
        {  // empty search string.. show everything
            displaySearchResults(matchingFilters: allFilters)
        }
    }

    func displaySearchResults(matchingFilters: [PGLFilterDescriptor]) {

        // depends on the mode of Grouped or Flat for the headers

        let filterItems = matchingFilters.map { Item(title: $0.displayName, descriptor: $0)}

        // get dataSource snapshot
        var snapshot = NSDiffableDataSourceSnapshot<Int, Item>()

        snapshot.appendSections([Header.AllFilter.rawValue])
//            snapshot.insertSections([0], beforeSection: 0)

        let allHeaderItem = Item(title: "Groups", descriptor: nil)
        snapshot.appendItems([allHeaderItem], toSection: Header.AllFilter.rawValue)

        snapshot.appendItems(filterItems, toSection: Header.AllFilter.rawValue)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

}
// MARK: - UIStateRestoration

extension PGLMainFilterController {
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        // Encode the view state so it can be restored later.

        // Encode the title.
        coder.encode(navigationItem.title!, forKey: RestorationKeys.viewControllerTitle.rawValue)

        // Encode the search controller's active state.
        coder.encode(searchController.isActive, forKey: RestorationKeys.searchControllerIsActive.rawValue)

        // Encode the first responser status.
        coder.encode(searchController.searchBar.isFirstResponder, forKey: RestorationKeys.searchBarIsFirstResponder.rawValue)

        // Encode the search bar text.
        coder.encode(searchController.searchBar.text, forKey: RestorationKeys.searchBarText.rawValue)
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        // Restore the title.
        guard let decodedTitle = coder.decodeObject(forKey: RestorationKeys.viewControllerTitle.rawValue) as? String else {
            Logger(subsystem: LogSubsystem, category: LogCategory).error ("PGLMainFilterController decodeRestorableState fatalError( A title did not exist. ")
            return 
        }
        navigationItem.title! = decodedTitle

        /** Restore the active state:
         We can't make the searchController active here since it's not part of the view
         hierarchy yet, instead we do it in viewWillAppear.
         */
        restoredState.wasActive = coder.decodeBool(forKey: RestorationKeys.searchControllerIsActive.rawValue)

        /** Restore the first responder status:
         Like above, we can't make the searchController first responder here since it's not part of the view
         hierarchy yet, instead we do it in viewWillAppear.
         */
        restoredState.wasFirstResponder = coder.decodeBool(forKey: RestorationKeys.searchBarIsFirstResponder.rawValue)

        // Restore the text in the search field.
        searchController.searchBar.text = coder.decodeObject(forKey: RestorationKeys.searchBarText.rawValue) as? String
    }

}

extension PGLMainFilterController {
    private func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { [unowned self] section, layoutEnvironment in
            var config = UICollectionLayoutListConfiguration(appearance: appearance)
            config.headerMode = .firstItemInSection  // or .supplementary
            return NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
        }
    }
}

extension PGLMainFilterController {
    // MARK: List groups

    private func configureHierarchy() {
        // called by viewDidLoad

        filterCollectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        filterCollectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        filterCollectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterCollectionView)
        filterCollectionView.delegate = self

        // Inside PGLTwoColumnSplitController's glass drawer: the insetGrouped
        // list appearance below defaults every cell's background to opaque
        // systemBackground via UIBackgroundConfiguration. Clearing the
        // collection view itself isn't enough — each cell registration below
        // also clears its own backgroundConfiguration when this is true.
        if parent is PGLTwoColumnSplitController {
            filterCollectionView.backgroundColor = .clear
        }

    }

    private func configureDataSource() {

        let headerFilterRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] (cell, indexPath, item) in
//            var content = cell.defaultContentConfiguration()
            var content = UIListContentConfiguration.extraProminentInsetGroupedHeader()
            content.text = item.title
            cell.contentConfiguration = content
            let disclosureOptions = UICellAccessory.outlineDisclosure(
                displayed: .always,
                options: UICellAccessory.OutlineDisclosureOptions() ) { [weak self] in
                    guard let self else { return }
                    if (indexPath.section == Header.AllFilter.rawValue) && (indexPath.row == 0) {
                        /// flip FilterNavigatorMode to opposite
                        if self.mode == FilterNavigatorMode.Grouped {
                            self.mode = FilterNavigatorMode.Flat
                            self.displaySearchResults(matchingFilters: self.filters )
                        }
                        else {
                            self.mode = FilterNavigatorMode.Grouped
                            self.initalFilterList()
                        }

                    }
                }
            cell.accessories = [disclosureOptions]
            if self?.parent is PGLTwoColumnSplitController {
                cell.backgroundConfiguration = .clear()
            }
        }

        let headerRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] (cell, indexPath, item) in
//            var content = cell.defaultContentConfiguration()
            var content = UIListContentConfiguration.extraProminentInsetGroupedHeader()
            content.text = item.title
            cell.contentConfiguration = content
            cell.accessories = [.outlineDisclosure()]
            if self?.parent is PGLTwoColumnSplitController {
                cell.backgroundConfiguration = .clear()
            }
        }

        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] (cell, indexPath, item) in
            guard self != nil else { return }
            var content = cell.defaultContentConfiguration()
            content.text = item.title
            cell.contentConfiguration = content
            let disclosureOptions = UICellAccessory.OutlineDisclosureOptions(style: .cell)
            cell.accessories = [.outlineDisclosure(options: disclosureOptions)]
            if self?.parent is PGLTwoColumnSplitController {
                cell.backgroundConfiguration = .clear()
            }
        }

        // [weak self]: dataSource is a stored property and this provider closure is
        // held by it, so capturing self strongly cycles (self -> dataSource ->
        // provider closure -> self) and leaks this controller.
        dataSource = UICollectionViewDiffableDataSource<Int, Item>(collectionView: filterCollectionView) {
            [weak self] (collectionView: UICollectionView, indexPath: IndexPath, item: Item) -> UICollectionViewCell? in
            var guideStepSelected = false
            if indexPath.row == 0 {
                if indexPath.section == Header.AllFilter.rawValue {
                    // filters header
                    return collectionView.dequeueConfiguredReusableCell(using: headerFilterRegistration, for: indexPath, item: item)
                } else  {
                            // category header
                    let theHeaderCell = collectionView.dequeueConfiguredReusableCell(using: headerRegistration, for: indexPath, item: item)

                    if  PGLDemo.GuideMode && !guideStepSelected {
                         let thisStep = PGLGuideStep(controller: "PGLMainFilterController", filter: item.title!, parmName: nil)
                        if let guide = PGLGuide.Steps.contains(thisStep) {
                            guideStepSelected = true
                            self?.guideStepIndex = indexPath
                            var content = UIListContentConfiguration.extraProminentInsetGroupedHeader()
                            content.text = item.title!
                                // Configure content.

                                // Customize appearance.
                            content.image = UIImage(systemName: guide.label )
                            if #available(iOS 18.0, *) {
//                                content.imageProperties.tintColor = .systemYellow
                                
                            }
                            theHeaderCell.contentConfiguration = content
                        }
                        }
                    return theHeaderCell
                    }

            } else {
                // ordinary filter cell
                let theFilterCell = collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
                if PGLDemo.GuideMode  && !guideStepSelected {
                    let thisStep = PGLGuideStep(controller: "PGLMainFilterController", filter: item.descriptor?.filterName, parmName: nil)
                    if let guide = PGLGuide.Steps.contains(thisStep) {
                        guideStepSelected = true
                        self?.guideStepIndex = indexPath
                        var content = theFilterCell.defaultContentConfiguration()
                        content.image = UIImage(systemName: guide.label)
                        content.text = item.title!
                        theFilterCell.contentConfiguration = content
                    }
                }
                return theFilterCell
            }

        }
        initalFilterList()
    }

    func initalFilterList() {
            // initial data
            /// add a Filter category that expands all

        var snapshot = NSDiffableDataSourceSnapshot<Int, Item>()

        let headerAll = Header.AllFilter.rawValue
        let sections = Array(1...categories.count)
        snapshot.appendSections([headerAll])
        snapshot.appendSections(sections)
        dataSource.apply(snapshot, animatingDifferences: false)
        var headerSnapShot = NSDiffableDataSourceSectionSnapshot<Item>()
        var headerItemTitle = "A-Z Effex" // for FilterNavigatorMode.Grouped
        if mode == FilterNavigatorMode.Flat {
            headerItemTitle = "Groups"
        }
        let headerItem = Item(title: headerItemTitle, descriptor: nil)
        headerSnapShot.append([headerItem])
        dataSource.apply(headerSnapShot, to: Header.AllFilter.rawValue)
        for section in sections {
            var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<Item>()
            let categoryHeaderItem = Item(title: categories[section - 1].categoryName, descriptor: nil)
            sectionSnapshot.append([categoryHeaderItem])
            let filterItems = categories[section - 1 ].filterDescriptors.map {Item(title: $0.displayName, descriptor: $0)}
            sectionSnapshot.append(filterItems, to: categoryHeaderItem)
//            sectionSnapshot.collapse(filterItems)
            dataSource.apply(sectionSnapshot, to: section )
        }


    }
}

/// Selection Navigation
extension PGLMainFilterController {


    func selectedFilterDescriptor(inTable: UICollectionView)-> PGLFilterDescriptor? {
        var selectedDescriptor: PGLFilterDescriptor?

        if let thePath = inTable.indexPathsForSelectedItems?.first {

            let selectedItem = dataSource.itemIdentifier(for: thePath)
            selectedDescriptor = selectedItem?.descriptor

            }
        return selectedDescriptor
    }

    func selectCurrentFilterRow() {
            // select and show the current initial filter
        if stackData()!.isEmptyStack() { return }
        let currentFilter = stackData()?.currentFilter()

        var thePath = IndexPath(row:0, section: 0)

        thePath.section = currentFilter?.uiPosition.categoryIndex ?? 0
        thePath.row = currentFilter?.uiPosition.filterIndex ?? 0

        filterCollectionView.selectItem(at: thePath, animated: true, scrollPosition: .centeredVertically)
        Logger(subsystem: LogSubsystem, category: LogCategory).debug("PGLMainFilterController selects row at \(thePath)")

    }

    func selectedFilterDescriptor(inTable: UITableView)-> PGLFilterDescriptor? {
        var selectedDescriptor: PGLFilterDescriptor?

        if let thePath = inTable.indexPathForSelectedRow {

            selectedDescriptor = categories[thePath.section].filterDescriptors[thePath.row]
            Logger(subsystem: LogSubsystem, category: LogCategory).debug("PGLMainFilterController \(#function) mode = Grouped path = \(thePath)")

        }
        return selectedDescriptor
    }



    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        var descriptor: PGLFilterDescriptor
        descriptor = selectedFilterDescriptor(inTable: filterCollectionView)!

        performFilterPick(descriptor: descriptor)
        navigateToParmController()
    }


    func navigateToParmController() {
        // was     func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {

            // ISSUE - call this in new path of
            //         collectionView(UICollectionView, performPrimaryActionForItemAt: IndexPath)

            // manual segue to either the ParmSettings iPad layout or the TwoContainer  iPhone compact layout
            // assumes that didSelectRow has run to set the filterPick into the appStack
            //  therefore indexPath is not used.

        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")

//        let iPhoneCompact = traitCollection.userInterfaceIdiom == .phone
        let iPhoneCompact = splitViewController!.isCollapsed
            // iPhone Pro Max in landscape uses three column splitViewController
            //  in portrait it is the twoContainer .phone case

        if iPhoneCompact {
//            if let  twoContainerController = storyboard?.instantiateViewController(withIdentifier: "PGLParmImageController") as? PGLParmImageController
//            {
//                navigationController?.pushViewController(twoContainerController, animated: true)
//            }

                let filterSegue = "filterImageToParmImage"
                if let myTwoController = navigationController?.viewControllers.first(where: {$0 is PGLFilterImageContainerController}) {
                    myTwoController.performSegue(withIdentifier: filterSegue, sender: self)
                        //  on iPhone goes to parmImageContainer.
                }


        } else {
            if let iPadParmController = storyboard?.instantiateViewController(withIdentifier: "ParmSettingsViewController") as? PGLSelectParmController
            {
                navigationController?.pushViewController(iPadParmController, animated: true)
            }
            else {
                return
            }

        }

            // present not needed with segue
    }

} // end PGLMainFilterController methods

