//
//  PGLStackController.swift
//  Glance
//
//  Created by Will on 5/22/19.
//  Copyright © 2019 Will. All rights reserved.
//

import UIKit
import Photos
import os
import Combine

let PGLShowStackImageContainer = NSNotification.Name(rawValue: "PGLShowStackImageContainer")
let PGLSaveStackAction = NSNotification.Name(rawValue: "PGLSaveStackAction")

class PGLStackController: UITableViewController, UITextFieldDelegate, UINavigationControllerDelegate, UIPopoverPresentationControllerDelegate, UIAdaptivePresentationControllerDelegate {
    // tableview of the filters in the stack
    // opens on cell select the masterFilterController to pick new filter
    // on swipe cell "Parms" opens parmController to change filter parms
    // edit order by drag or delete a filter in the edit mode

    var appStack: PGLAppStack!
    var filterShiftBtn: UIBarButtonItem!
    var filterShiftImage: UIBarButtonItem!
    var upChevronBtn: UIBarButtonItem!
    var downChevronBtn: UIBarButtonItem!
    var toolBarSpacer: UIBarButtonItem!

    var longPressGesture: UILongPressGestureRecognizer!
    var longPressStart: IndexPath?
    var segueStarted = false  // set to true during prepareFor segue

    var existingStackTypes: [String]!
    var albumUserTextCell: UITextField?
    var saveStackBtn: UIButton?
    var myButtonHeader: PGLEffexButtonsHeader?

    var publishers = [any Cancellable]()
    var cancellable: (any Cancellable)?

    /// default to title and album input cells as hidden
    private var showStackTitleAlbumCells = false
    private var titleAlbumSectionRowCount: Int = 0

    enum StackSections: Int {
        case header = 0
        case filters = 1
    }

    enum StackHeaderCell: Int {
        case title = 0
        case album = 1
        case saveBtn = 2
    }

    // MARK: View LifeCycle

    
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
        guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
            else {
            Logger(subsystem: LogSubsystem, category: LogCategory).fault ("PGLStackController viewDidLoad fatalError(AppDelegate not loaded")
            return
        }

        appStack = myAppDelegate.appStack

        // Uncomment the following line to preserve selection between presentations
         self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.



        let myCenter =  NotificationCenter.default
        cancellable = myCenter.publisher(for:  PGLHideParmControlsOnFilterChange)
            .sink() { [weak self]
                myUpdate in
                guard let self = self else { return } // a released object sometimes receives the

                Logger(subsystem: LogSubsystem, category: LogNavigation).info( "PGLStackController  notificationBlock PGLCurrentFilterChange")

                self.updateDisplay()
            }
        publishers.append(cancellable!)

        cancellable = myCenter.publisher(for: PGLStackChange)
            .sink() { [weak self]
            myUpdate in
            Logger(subsystem: LogSubsystem, category: LogNavigation).info( "PGLStackController  notificationBlock PGLStackChange")

            guard let self = self else { return } // a released object sometimes receives the notification
                          // the guard is based upon the apple sample app 'Conference-Diffable'

            self.appStack = myAppDelegate.appStack
            self.updateDisplay()
        }
        publishers.append(cancellable!)


        cancellable = myCenter.publisher(for:  PGLSelectActiveStackRow)
            .sink() { [weak self]
            myUpdate in
            Logger(subsystem: LogSubsystem, category: LogNavigation).info("PGLStackController  notificationBlock PGLSelectActiveStackRow")
            guard let self = self else { return } // a released object sometimes receives the notification

            self.selectActiveFilterRow()
        }
        publishers.append(cancellable!)

        cancellable = myCenter.publisher(for:  PGLStackStartSave)
            .sink() { [weak self]
                myUpdate in 
                if !(self?.showStackTitleAlbumCells ?? false) {
                    // two messages to show from the image controller
                    // only the stack controller should toggle back/forth
                    self?.toggleStackTitleAlbumCellsVisible()
                }
        }
        publishers.append(cancellable!)

        updateNavigationBar()
        setLongPressGesture()

        if !(splitViewController?.isCollapsed ?? false) {
            navigationController?.isToolbarHidden = false
            addToolBarButtons(toController: self)

            postPGLHideParmUIControls()
            if appStack.outputStack.isEmptyStack() {
                    // just skip ahead to the filter controller since there is no filter now

//                Logger(subsystem: LogSubsystem, category: LogNavigation).info("PGLStackController  notificationBlock emptyStack segue to filter controller")
                self.performSegue(withIdentifier: "showFilterController" , sender: nil)
            }
        }
        registerCellNibs()


        
        // provide the album names (aka stackTypes) for the header album choice menu
        // see setAlbumChoiceMenu that creates UIActions for the menu with the stackTypes
        
        if let sections = appStack.dataProvider.fetchedResultsController.sections {
            existingStackTypes = sections.map({$0.name})
        } else
            { existingStackTypes = [String]() }
    }



    override func viewWillAppear(_ animated: Bool) {

//        appStack.postSelectActiveStackRow()
        if traitCollection.horizontalSizeClass == .compact {
            modalPresentationStyle = .formSheet
            let myPresentation =  presentationController
            myPresentation?.delegate = self
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("\( String(describing: self) + "-" + #function)")
        super.viewDidAppear(animated)
//        appStack.resetViewStack()
        segueStarted = false  // reset flag
        if PGLDemo.GuideMode {
            // NOT checking for place in the guide script

            // go to default cell in the stackController
            selectStackBottomRowFilter()
//            let thisStep = PGLGuideStep(controller: "PGLStackController", filter: nil, parmName: nil)
//            if let guide = PGLGuide.Steps.contains(thisStep) {
//                myButtonHeader?.arrowBtn.isHidden = false } else {
//                    myButtonHeader?.arrowBtn.isHidden = true
//                }
//        } else {
//            myButtonHeader?.arrowBtn.isHidden = true
            }
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        if traitCollection.verticalSizeClass == .compact {
            return .none }
        else { return .automatic }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super .viewDidDisappear(animated)
        NSLog("PGLStackController #viewDidDisappear removing notification observor")

        NotificationCenter.default.removeObserver(self, name: PGLHideParmControlsOnFilterChange, object: self)
        NotificationCenter.default.removeObserver(self, name: PGLStackChange, object: self)
        NotificationCenter.default.removeObserver(self, name: PGLSelectActiveStackRow, object: self)
    }


     func updateDisplay() {
        // called by the action buttons
         Logger(subsystem: LogSubsystem, category: LogCategory).info ("\( String(describing: self) + "-" + #function) ")
        appStack.resetCellFilters() // updates the flattened cell filter array

         tableView.reloadData()
         setShiftBtnState()
         updateNavigationBar()
                 //         highlightViewerStackCells()


    }

    func selectStackBottomRowFilter()
    {   let sectionCount = tableView.numberOfSections

        let bottomRow  = tableView.numberOfRows(inSection: sectionCount - 1)

        let bottomIndexPath = IndexPath(row: bottomRow - 1, section: sectionCount - 1)
        tableView.selectRow(at: bottomIndexPath, animated: true, scrollPosition: .bottom)
        tableView(tableView, didSelectRowAt: bottomIndexPath)

    }

    override func releaseNotifications() {
        for aCancel in publishers {
            aCancel.cancel()
        }
        publishers = [any Cancellable]()
    }

        ///empty method PGLStackController  does not need to release
   override func resetVars() {


    }


    // MARK: ToolBar

    @IBOutlet weak var openParmsBtn: UIBarButtonItem!

    @IBAction func openParmsAction(_ sender: UIBarButtonItem) {

        
        segueToParmController()
    }
    
    func addToolBarButtons(toController: UIViewController) {


        filterShiftBtn = UIBarButtonItem(title: "", style: .plain, target: self , action: #selector(singleFilterOutput))
        filterShiftImage = UIBarButtonItem(title: "", style: .plain, target: self , action: #selector(singleFilterOutput))
        // both use the same selector...

        filterShiftImage.image = UIImage(systemName: "chart.bar.doc.horizontal")
        filterShiftBtn.possibleTitles = [StackDisplayMode.Single.rawValue, StackDisplayMode.All.rawValue ]

        upChevronBtn = UIBarButtonItem(title: "", style: .plain, target: self , action: #selector(upChevronAction))
        upChevronBtn.image = UIImage(systemName:"chevron.up")
        downChevronBtn = UIBarButtonItem(title: "", style: .plain, target: self , action: #selector(downChevronAction))
        downChevronBtn.image = UIImage(systemName:"chevron.down")
        toolBarSpacer = UIBarButtonItem.fixedSpace(15.0)
        toController.setToolbarItems([filterShiftImage, filterShiftBtn,  toolBarSpacer, upChevronBtn, downChevronBtn], animated: true)
        setShiftBtnState()
        setChevronState()
    }

    @objc func singleFilterOutput() {
        appStack.toggleShowFilterImage()
        setShiftBtnState()
        if appStack.showFilterImage { appStack.postSelectActiveStackRow() }
        else { // deselect row

        }
        setChevronState()
//        postCurrentFilterChange()
    }

    func setShiftBtnState() {
        if filterShiftBtn != nil {
            filterShiftBtn.isEnabled = (appStack.flatRowCount() > 1)
            filterShiftImage.isEnabled = filterShiftBtn.isEnabled
            setChevronState()
            if (appStack.showFilterImage) {
                filterShiftBtn.title  = StackDisplayMode.Single.rawValue
            } else {
                filterShiftBtn.title  = StackDisplayMode.All.rawValue
            }
        }

    }

    @objc func upChevronAction(_ sender: UIBarButtonItem) {


            // if on a child stack (indented cell) then outputFilterStack is
            // not set right... how to handle this?
        appStack.moveActiveBack()
        setChevronState()
        postCurrentFilterChange()
        if appStack.showFilterImage {appStack.postSelectActiveStackRow()}

    }

    @objc func downChevronAction(_ sender: UIBarButtonItem) {

        appStack.moveActiveAhead() // changes to child if needed

        setChevronState()
        postCurrentFilterChange()
        if appStack.showFilterImage {appStack.postSelectActiveStackRow()}

    }

    func setChevronState() {
        if !appStack.showFilterImage {
            upChevronBtn.isEnabled = false
            downChevronBtn.isEnabled = false
            return
        }

        let rowCount = appStack.flatRowCount()

        if (rowCount <= 1) {
            // disable both chevrons
            upChevronBtn.isEnabled = false
            downChevronBtn.isEnabled = false
            return
        }
        let theSelectedRow = appStack.activeFilterCellRow()
            switch theSelectedRow {
                case 0 :
                    // on first.. can't go further
                    upChevronBtn.isEnabled = false
                    downChevronBtn.isEnabled = true
                case rowCount - 1 :
                    // on last filter can't go further
                    upChevronBtn.isEnabled = true
                    downChevronBtn.isEnabled = false
                default:
                    // in the middle enable both
                    upChevronBtn.isEnabled = true
                    downChevronBtn.isEnabled = true
            }
    }


    func selectActiveFilterRow() {

        if tableView.numberOfRows(inSection: StackSections.filters.rawValue ) == 0 {
            return
            // empty table.. trashed the stack.. nothing to show..
        }
        guard let activeRow = appStack.activeFilterCellRow()
            else { return }
        let rowPath = IndexPath(row: activeRow, section: StackSections.filters.rawValue)
        if appStack.showFilterImage {

            tableView.selectRow(at: rowPath, animated: true, scrollPosition: .middle)
        } else {
            // deselect - no rows should be selected
            tableView.deselectRow(at: rowPath, animated: true)
            updateDisplay()  // only update to remove row selection !
        }

    }

    func isLimitedPhotoLibAccess() -> Bool {
        let accessLevel: PHAccessLevel = .readWrite // or .addOnly
        let authorizationStatus = PHPhotoLibrary.authorizationStatus(for: accessLevel)

        switch authorizationStatus {
            case .limited :
            return true
        default:
            // all other authorizationStatus values
           return false
        }
    }


    // MARK: - Table view delegate
    override func indexPathForPreferredFocusedView(in tableView: UITableView) -> IndexPath? {
        guard let targetRow = appStack.activeFilterCellRow()
        else { return nil }
        return IndexPath(row: targetRow, section: StackSections.filters.rawValue)
    }
    
    // MARK: Table Setup
    override func numberOfSections(in tableView: UITableView) -> Int {
        //  return the number of sections
//        let mySectionCount =  appStack.stackSections().count
//        return mySectionCount + 1 // + 1 for the header
        return 2

    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //  return the number of rows

           switch section {
               case 0:
                   // may be zero or 3
                   return titleAlbumSectionRowCount
                   //  stackName, type, saveBtn input rows
               case 1:
                   return appStack.flatRowCount()
               default:
                   return 0
           }


    }

    // MARK: TableView cells

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//             headers don't count for indexPath.
        if indexPath.section == 0 {
                return titleAlbumCell(tableView, indexPath)}
            else {
                return filterCellFor(tableView, indexPath)
                }
    }





    fileprivate func filterCellFor(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell {
        // filter cell section
        let cell = tableView.dequeueReusableCell(withIdentifier: "filterRowCell", for: indexPath)

        if !appStack.isIndexPathInRangeForFlattendFilters(indexPath: indexPath) {
            return cell
                // empty cell
        }

        let aFilterIndent = appStack.filterAt(indexPath: indexPath)

        cell.textLabel?.text = aFilterIndent.descriptorDisplayName  // same text as the filterController cell
        cell.indentationLevel = aFilterIndent.level
        if appStack.isLastFilterOfSection(currentFilter: aFilterIndent)  {
            // child stack is indented
            // only label the bottom filter with the detailText
            cell.detailTextLabel?.text = aFilterIndent.stack.stackName
                    // stackName is set in #addChildStackBasic with #parentParmName
//            cell.detailTextLabel?.backgroundColor = UIColor.secondaryLabel
        } else {
            cell.detailTextLabel?.text = ""
//            cell.detailTextLabel?.backgroundColor = UIColor.clear
        }
        aFilterIndent.setCellViewerStackBackground(aCell: cell, viewerStack: appStack.viewerStack)

        if aFilterIndent.stack is PGLSequenceStack {
            cell.imageView?.image = PGLFilterAttribute.SequenceSymbol }

        else {
            switch aFilterIndent.level {
                case 0:
                    cell.imageView?.image = PGLFilterAttribute.TopStackSymbol
                case 1:
                    cell.imageView?.image = PGLFilterAttribute.ChildStack1Symbol
                case 2:
                    cell.imageView?.image = PGLFilterAttribute.ChildStack2Symbol
                case 3:
                    cell.imageView?.image = PGLFilterAttribute.ChildStack3Symbol
                case 4:
                    cell.imageView?.image = PGLFilterAttribute.ChildStack4Symbol
                case 5:
                    cell.imageView?.image = PGLFilterAttribute.ChildStack5Symbol
                default:
                    cell.imageView?.image = PGLFilterAttribute.ChildStackSymbol
            }
        }

        if appStack.isOutputFilter(aFilterIndent) {
            // shows in single mode the filter being displayed in the image
            // or in All mode the last filter of the output
            cell.imageView?.image = PGLFilterAttribute.OutputFilterSymbol
        }
        aFilterIndent.setCellViewerStackBackground(aCell: cell, viewerStack: appStack.viewerStack)

            // Configure the cell...
        if appStack.isImageControllerOpen {
                // disable the detail disclosure button until the image controller shows
                // other controllers in the detail are the PGLAssetGridController and the PGLAssetController
                // these select an image or imageList for image parms
                //            cell.accessoryType = .detailDisclosureButton
        } else { cell.accessoryType = .none}

        return cell
    }





// MARK: Stack Name input

    func addAlbumLookUp(albumUserText: UITextField) {
        let overlayButton = UIButton(type: .custom)
        let bookmarkImage = UIImage(systemName: "bookmark")
        overlayButton.setImage(bookmarkImage, for: .normal)

        overlayButton.sizeToFit()
        setAlbumChoiceMenu(bookMarkBtn: overlayButton)

        // Assign the overlay button to the text field
        albumUserText.leftView = overlayButton
        albumUserText.leftViewMode = .always
        
    }

    @objc func setAlbumChoiceMenu(bookMarkBtn: UIButton) {
        // open popup menu with existingStackTypes
//        existingStackTypes

        let albumItems:[UIAction] = existingStackTypes.map {
            UIAction( title: $0, handler: { thisAction in self.setStackTo(albumName: thisAction.title )})
        }

        let albumMenu = UIMenu(title:"Albums", children: albumItems)
        bookMarkBtn.menu = albumMenu
        bookMarkBtn.showsMenuAsPrimaryAction = true

    }

    func setStackTo(albumName: String) {
        NSLog("PGLStackController #setStackTo(albumName \(albumName)")
        let theOutputStack = self.appStack.outputStack
        theOutputStack.stackType = albumName
        theOutputStack.exportAlbumName = albumName
        albumUserTextCell?.text = albumName
    }

//    override func tableView( _ tableView: UITableView, didHighlightRowAt indexPath:IndexPath ) {
//        // make the viewerStack visible for this filter
//        if let filterIndentHightlighted = appStack.filterIndent(atIndex: indexPath) {
//            appStack.moveTo(filterIndent: filterIndentHightlighted)
//        }
//
//    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if indexPath.section == StackSections.header.rawValue {
            // no segue naviation on header cells
            return
        }
        if !appStack.flatCellFilters.isEmpty {
            let cellIndent = appStack.flatCellFilters[indexPath.row]
            _ = appStack.moveTo(filterIndent: cellIndent)

                /// make the imageController show the new output either single filter or stack output
            appStack.showFilterImage = !appStack.showFilterImage

            let notificationRedrawFilter = Notification(name: PGLRedrawFilterChange)
            NotificationCenter.default.post(name: notificationRedrawFilter.name, object: nil, userInfo: ["filterHasChanged" : true as AnyObject])

            self.updateDisplay()

            let selectedCell = tableView.cellForRow(at: indexPath)
            selectedCell?.setSelected(true, animated: true)
                // setSelected does NOT call this delegate didSelectRowAt again
        }
    }

    func segueToParmController() {
            if splitViewController?.isCollapsed ?? false {
                performSegue(withIdentifier: "twoContainers", sender: self)
            } else {
                performSegue(withIdentifier: "ParmSettings", sender: self)
            }
    }



    // MARK: Header setup

    fileprivate func registerCellNibs() {
        let stackInfoHeaderCellNib = UINib(nibName: PGLStackInfoHeader.nibName, bundle: nil)
        tableView.register(stackInfoHeaderCellNib ,forCellReuseIdentifier: PGLStackInfoHeader.reuseIdentifer)

        let stackAlbumHeaderCellNib = UINib(nibName: PGLStackAlbumHeader.nibName, bundle: nil)
        tableView.register(stackAlbumHeaderCellNib ,forCellReuseIdentifier: PGLStackAlbumHeader.reuseIdentifer)

        let saveButtonsCellNib = UINib(nibName: PGLSaveButtonRow.nibName, bundle: nil)
        tableView.register(saveButtonsCellNib , forCellReuseIdentifier: PGLSaveButtonRow.reuseIdentifer)

        let effexButtonsCellNib = UINib(nibName: PGLEffexButtonsHeader.nibName, bundle: nil)
        tableView.register(effexButtonsCellNib , forHeaderFooterViewReuseIdentifier: PGLEffexButtonsHeader.reuseIdentifer)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 0
        }
        if section == 1 {
            return 50
        }
        return 0 
    }

    override func tableView( _ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            if showStackTitleAlbumCells {
                return UITableViewHeaderFooterView()
            } else { return nil }
        }
        if section == 1 {
            if  let myButtonHeader = tableView.dequeueReusableHeaderFooterView(withIdentifier: PGLEffexButtonsHeader.reuseIdentifer) as? PGLEffexButtonsHeader {

                myButtonHeader.addFilterBtn.addTarget(self, action: #selector(addFilterToStack ), for: .touchUpInside)
                myButtonHeader.editFiltersBtn.addTarget(self, action: #selector(toggleEditing ), for: .touchUpInside)

                if PGLDemo.GuideMode {
                    myButtonHeader.arrowBtn.isHidden = false // always on during GuideMode
                    myButtonHeader.backgroundColor = .systemYellow
//                    let thisStep = PGLGuideStep(controller: "PGLStackController", filter: nil, parmName: nil)
//                    if let guide = PGLGuide.Steps.contains(thisStep) {
//                        myButtonHeader.arrowBtn.isHidden = false } else {
//                            myButtonHeader.arrowBtn.isHidden = true
//                        }
                } else {
                    myButtonHeader.arrowBtn.isHidden = true
                }
                return myButtonHeader
            }
        }
        return nil // no other headers
    }


    fileprivate func titleAlbumCell(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell {
            // header

        let myStack = appStack.outputStack
        if indexPath.section == 0 {
            switch indexPath.row {
                case StackHeaderCell.title.rawValue :
                    guard let cell = tableView.dequeueReusableCell(withIdentifier: PGLStackInfoHeader.reuseIdentifer, for: indexPath) as? PGLStackInfoHeader
                    else {
                        fatalError("PGLStackController headerCell did not load")
                    }
                    cell.cellLabel.text = "Title:"
                    cell.userText.text = myStack.stackName
                    cell.userText.delegate = self
                    cell.userText.tag = StackHeaderCell.title.rawValue
                    cell.userText.returnKeyType = .done
                    cell.userText.delegate = self
                    return cell

                case StackHeaderCell.album.rawValue :
                    guard let cell = tableView.dequeueReusableCell(withIdentifier: PGLStackAlbumHeader.reuseIdentifer, for: indexPath) as? PGLStackAlbumHeader
                    else {
                        fatalError("PGLStackController headerCell did not load")
                    }
                    cell.cellLabel.text = "Album:"
                    cell.userText.text = myStack.stackType
                    cell.userText.delegate = self
                    cell.userText.tag = StackHeaderCell.album.rawValue
                    cell.userText.returnKeyType = .done
                    cell.userText.delegate = self
                    addAlbumLookUp(albumUserText: cell.userText)
                    albumUserTextCell = cell.userText
                    return cell

                case StackHeaderCell.saveBtn.rawValue :
                    guard let cell = tableView.dequeueReusableCell(withIdentifier: PGLSaveButtonRow.reuseIdentifer, for: indexPath) as? PGLSaveButtonRow
                    else { fatalError("PGLStackController did not load save buttons") }
                    cell.cancelBtn.addTarget(self, action: #selector(cancelStackSave), for: .touchUpInside)
                    cell.saveBtn.addTarget(self, action: #selector(saveStack), for: .touchUpInside)
                    saveStackBtn = cell.saveBtn
                    saveStackBtn?.setTitle("Save", for: .normal)
                    return cell
                default :
                        // or let cell = tableView.dequeueReusableCell(withIdentifier: "childStackHeader", for: indexPath)

                    guard let cell = tableView.dequeueReusableCell(withIdentifier: PGLStackInfoHeader.reuseIdentifer, for: indexPath) as? PGLStackInfoHeader
                    else {
                        fatalError("PGLStackController headerCell did not load")
                    }
                    return cell
            }
        }
        return UITableViewCell()
    }


        // MARK: Bar Buttons

    @objc func addFilterToStack() {
        // hideParmControls()
        self.appStack.setFilterChangeModeToAdd()

        postFilterNavigationChange()
        if let myParentTwoColumnStack = parent as? PGLStackImageContainerController {
            myParentTwoColumnStack.addFilterBtn()
        } else {
            performSegue(withIdentifier: "showFilterController", sender: self)
                // chooses new filter
        }
    }


    @IBAction func showImageControllerAction(_ sender: UIBarButtonItem) {

        // if splitViewController.isCollapsed then show(.secondary) does nothing
        splitViewController?.show(.secondary)
        postCurrentFilterChange() // triggers PGLImageController to set view.isHidden to false
            // show the new results !


    }

    @objc func cancelStackSave() {
      toggleStackTitleAlbumCellsVisible()
    }

    @objc func saveStack() {
        // post notication to the imageController
        let notifier = Notification(name: PGLStackSavePerform)
        NotificationCenter.default.post(notifier)
        toggleStackTitleAlbumCellsVisible()

    }

    func toggleStackTitleAlbumCellsVisible() {

        showStackTitleAlbumCells = !showStackTitleAlbumCells
        if showStackTitleAlbumCells {
            titleAlbumSectionRowCount = 3
        } else {
            titleAlbumSectionRowCount = 0
        }
        tableView.reloadData()
    }

//    func showStackControllerAction() {
//        // other part of split should navigate back to the stack controller
//        // after the Random button is clicked
//        let goToStack = Notification(name: PGLLoadedDataStack)
//        NotificationCenter.default.post(goToStack)
//
//    }

    // MARK: - LongPressGestures
    func setLongPressGesture() {

        longPressGesture = UILongPressGestureRecognizer(target: self , action: #selector(PGLMainFilterController.longPressAction(_:)))
          if longPressGesture != nil {

//                 " defaults to 0.5 sec 1 finger 10 points allowed movement"
              tableView.addGestureRecognizer(longPressGesture!)
              longPressGesture!.isEnabled = true
//            NSLog("PGLStackController setLongPressGesture \(String(describing: longPressGesture))")
          }
      }

    func removeGestureRecogniziers(targetView: UIView) {
       // not called in viewWillDissappear..
       // recognizier does not seem to get restored if removed...
        if longPressGesture != nil {
            tableView.removeGestureRecognizer(longPressGesture!)
            longPressGesture!.removeTarget(self, action: #selector(PGLMainFilterController.longPressAction(_:)))
            longPressGesture = nil
//           NSLog("PGLStackController removeGestureRecogniziers ")
       }

    }

    @objc func longPressAction(_ sender: UILongPressGestureRecognizer) {

        let point = sender.location(in: tableView)

        if sender.state == .began
        {   Logger(subsystem: LogSubsystem, category: LogCategory).debug("PGLStackController longPressAction begin")
            guard let longPressIndexPath = tableView.indexPathForRow(at: point) else {
                longPressStart = nil // assign to var
                return
            }
            longPressStart = longPressIndexPath // assign to var
        }
        if longPressStart?.section == 0 {
            // header cells album,title buttons
            return
        }
        if sender.state == .recognized {  // could also use .ended but there is slight delay
            // open popup with filter userDescription
            if longPressStart != nil {

                guard let tableCell = tableView.cellForRow(at: longPressStart!) else { return  }
                let aFilterIndent = appStack.filterAt(indexPath: longPressStart!)
                if let description = aFilterIndent.filter.filterUserDescription() {
                // now need the PGLFilterDescriptor from the filter..
                // filter should be able to get it's descriptor from
                // filter name and class
                    let myDisplayName = aFilterIndent.filter.descriptorDisplayName ?? "Filter"
                    popUpFilterDescription(filterName: myDisplayName, filterText: description, filterCell: tableCell)
                } else { return }
            }
        }



    }

    func popUpFilterDescription(filterName: String, filterText: String, filterCell: UITableViewCell) {
        if segueStarted { return }
            // don't open if the navigation is already triggered
        guard let helpController = storyboard?.instantiateViewController(withIdentifier: "PGLPopUpFilterInfo") as? PGLPopUpFilterInfo
        else {
            return
        }
        helpController.modalPresentationStyle = .popover
        let popUpWidth = view.frame.width * 0.8
        let popUpHeight = view.frame.height * 0.6
       helpController.preferredContentSize = CGSize(width: popUpWidth, height: popUpHeight)

        guard let popOverPresenter = helpController.popoverPresentationController
        else { return }
        popOverPresenter.canOverlapSourceViewRect = true // or barButtonItem
//        popOverPresenter.popoverLayoutMargins // default is 10 points inset from device edges
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


// MARK: Navigation

    func highlightViewerStackCells() {
        // change background of cells in the current viewerStack
        // viewerStack is used to add new filter.. thus
        // a new filter can be added to a childstack if it is highlighted

        for aFilterIndent in appStack.flatCellFilters {
            let cellIndex = appStack.indexPathFor(filterIndent: aFilterIndent)
            guard let cell = tableView.cellForRow(at: cellIndex)
                else { 
                Logger(subsystem: LogSubsystem, category: LogNavigation).info( "PGLStackController  #highlightViewerStackCells failed for cellIndex \(cellIndex)")
                    return }
            if aFilterIndent.stack === appStack.viewerStack {
                Logger(subsystem: LogSubsystem, category: LogNavigation).info( "PGLStackController  #highlightViewerStackCells SETS cellIndex \(cellIndex)")
                cell.backgroundColor = UIColor.systemGroupedBackground
                    // .withAlphaComponent(0.2)
                
                }
            else {
                cell.backgroundColor = nil
            }
        }

    }


    func updateNavigationBar() {

        setNeedsStatusBarAppearanceUpdate()
    }

    func postFilterNavigationChange() {
//        postCurrentFilterChange()  // should only have one sender

    }

    func postPGLHideParmUIControls(){
        let updateFilterNotification = Notification(name:PGLHideParmUIControls)
        NotificationCenter.default.post(updateFilterNotification)
    }

    func postCurrentFilterChange() {
        let updateFilterNotification = Notification(name: PGLHideParmControlsOnFilterChange)

        NotificationCenter.default.post(name: updateFilterNotification.name, object: nil, userInfo: ["sender" : self as AnyObject])
    }

    //PGLSelectActiveStackRow

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // can check  if segue.identifier == "showCollection" and
        // segue.destination as? PGLImageCollectionMasterController ...
        // but currently only one segue so just set the model object for the cell

//        if let cellDetail = sender as? UITableViewCell  {
//
//            if let thePath = tableView.indexPath(for: cellDetail) {
//                let cellObject = appStack.cellFilters[thePath.row]
//                appStack.moveTo(filterIndent: cellObject)
//            }
//
//        }
        let segueId = segue.identifier
        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function) + \(String(describing: segueId))")
        let filterName = appStack.currentFilter?.filterName

        Logger(subsystem: LogSubsystem, category: LogNavigation).info(" \(String(describing: segueId))  + \(String(describing:filterName) )")


        switch segueId {
            case "showImageController":
                let controller = segue.destination as! PGLImageController

                controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                controller.navigationItem.leftItemsSupplementBackButton = true
            case "showParmSettings" :
                    // didSelectRowAt has set the appStack model
                return
            case "showFilterController" :
                // iPhone compact
                return
            default:
                return
        }

//        if segue.identifier == "showParmSettings" {
//            // didSelectRowAt has set the appStack model
//            return //
//        }


    }

    // MARK: Swipe Actions

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // on swipe from the filter list open the parm controller
          var contextActions = [UIContextualAction]()

        let cellFilter: PGLFilterIndent =  appStack.flatCellFilters[indexPath.row]
        let thisSourceFilter = cellFilter.filter
        contextActions = thisSourceFilter.cellFilterAction(stackController: self, indexPath: indexPath)

         return UISwipeActionsConfiguration(actions: contextActions)
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("shouldPerformSegue \(identifier)")
         segueStarted = true
        // don't open a popOverController seque is starting
//        let iPhoneCompact = (traitCollection.userInterfaceIdiom == .phone) &&
//                            (traitCollection.horizontalSizeClass == .compact)
        let iPhoneCompact = splitViewController?.isCollapsed ?? false

        switch identifier {
            case "ParmSettings":
                if iPhoneCompact {
                    return false
                } else
                { return true }

            case "showFilterController" :
                if iPhoneCompact {
                    return true
                } else
                { return true }

            case "twoContainers" :
                if iPhoneCompact  {
                    return true
                } else
                { return false }
            default:
                return true
        }

    }
    func removeFilter(indexPath: IndexPath) {

        let cellIndent = appStack.flatCellFilters[indexPath.row]
        _ = appStack.moveTo(filterIndent: cellIndent)
            // sets the activeFilterIndex of the childStack
            // makes the childStack the viewerStack

        let thisStack = appStack.getViewerStack()

        _ = thisStack.removeFilter(position: thisStack.activeFilterIndex)
        // needs work here... the parent of the child stack needs to
        // set the inputStack to nil and update the inputParmState to
        // missingInput

        // change back to the mainstck
        appStack.resetViewStack()


       self.updateDisplay()
        if appStack.showFilterImage {appStack.postSelectActiveStackRow()}
        // other updates in PGLImageController
    //            updateNavigationBar()
//                postCurrentFilterChange()
//                postStackChange()

    }

    //

    // MARK: editing support

         override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
             if indexPath.section == StackSections.header.rawValue {
                 // disable the header delete, move edits
                 return false
             } else {
                 return true
             }
             
         }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
//            if let identifierToDelete = itemIdentifier(for: indexPath) {
//                var snapshot = self.snapshot()
//                snapshot.deleteItems([identifierToDelete])
//                apply(snapshot)
            }
        }


    // MARK: reordering support

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        // delete row at sourceIndexPath
        // insert row at destination
        // if moving up the stack then inserts before the existing destination
        // if moving down the stack then inserts after the existing destination

        appStack.moveFilter(fromSourceRow: sourceIndexPath, destinationRow: destinationIndexPath )
        updateDisplay()  // or just reloadData?
    }

        // MARK: - Edit Btn



    @objc func toggleEditing() {
        tableView.setEditing(!tableView.isEditing, animated: true)

    }

}

/// UITextFieldDelegate Header cells text editing
extension PGLStackController {
//    func textField(
//        _ textField: UITextField,
//        shouldChangeCharactersIn range: NSRange,
//        replacementString string: String
//    ) -> Bool {
//
//        return true
//    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        // see the StackSaveState logic in #writeCDStack..
        if saveStackBtn?.title(for: .normal) != "Save As" {
            saveStackBtn?.setTitle("Save", for: .normal)
        }
    }
        /// make sure that textField is not editing on first display !
        ///  only enter here after the user selects and edits the text
    func textFieldDidEndEditing(_ textField: UITextField) {

       let thisStack = appStack.outputStack

            // first stack is the highest level.. not a child stack
        guard var newText = textField.text else {return }

        newText = newText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        var isSave = true
        switch textField.tag {
            case StackHeaderCell.title.rawValue :
                if newText != thisStack.stackName {
                    isSave = false
                }
            case StackHeaderCell.album.rawValue :
                if newText != thisStack.stackType {
                    isSave = false
                }
            default:
               isSave = true
        }
        if isSave {
                if saveStackBtn?.title(for: .normal) != "Save As" {
                        // don't overwrite if on the other unchanged field
                        // "Save As" gets to win..
                    saveStackBtn?.setTitle("Save", for: .normal)
                }
            }
        else {
            saveStackBtn?.setTitle("Save As", for: .normal)
        }

        switch textField.tag {
            /// also the case of one field is changed then tab into the other. Save As should still  be button text
            case StackHeaderCell.title.rawValue:
                if newText != thisStack.stackName {
                    thisStack.stackName = newText
                    postStackNameChange()
                }

            case StackHeaderCell.album.rawValue:
                    if newText != thisStack.stackType {
                        thisStack.stackType = newText
                        thisStack.exportAlbumName = thisStack.stackType
                        postStackNameChange()
                    }
            default:
                return
        }

        Logger(subsystem: LogSubsystem, category: LogCategory).debug("PGLStackController textFieldDidEndEditing name - \(thisStack.stackName) type - \(thisStack.stackType) - tag \(textField.tag) ")
       

    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        textField.resignFirstResponder()
        return true
    }

    func postStackNameChange() {

        // trigger the imageController  to refresh
        let stackNotification = Notification(name:PGLStackNameChange)
        NotificationCenter.default.post(stackNotification)

        


    }


}
