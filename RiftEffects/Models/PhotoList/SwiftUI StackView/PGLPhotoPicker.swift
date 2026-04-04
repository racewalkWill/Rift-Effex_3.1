/*
 From the Apple Sample App 'Image Gallery.swiftpm'
See the sample app 'Image Gallery License.txt' file for this sample’s licensing information.
*/

import SwiftUI
import PhotosUI

/// SwiftUI photo picker for the PGLImageListOverlayView
struct PGLPhotoPicker: UIViewControllerRepresentable {
    @ObservedObject var viewModel: PGLImageListViewModel
    let sectionID: UUID

    /// A dismiss action provided by the environment. This may be called to dismiss this view controller.
    @Environment(\.dismiss) var dismiss
    
    /// Creates the picker view controller that this object represents.
    func makeUIViewController(context: UIViewControllerRepresentableContext<PGLPhotoPicker>) -> PHPickerViewController {
        
        // Configure the picker.
        var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        // Limit to images.
        configuration.filter = .images
        // Avoid transcoding, if possible.
        configuration.preferredAssetRepresentationMode = .current
        // assume only transition filters with multiple inputs are used
        // allow many selection
        configuration.selectionLimit = 0


        let photoPickerViewController = PHPickerViewController(configuration: configuration)
        photoPickerViewController.delegate = context.coordinator
        return photoPickerViewController
    }
    
    /// Creates the coordinator that allows the picker to communicate back to this object.
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// Updates the picker while it’s being presented.
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: UIViewControllerRepresentableContext<PGLPhotoPicker>) {
        // No updates are necessary.
    }
}

class Coordinator: NSObject, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
    let parent: PGLPhotoPicker
    
    /// Called when one or more items have been picked, or when the picker has been canceled.
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        
        // Dismisss the presented picker.
        self.parent.dismiss()
        
        guard
            let result = results.first,
            result.itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        else { return }

        // insert the picked image(s) into the target image list
        // patterned on PGLImageListPicker #loadImageListFromPicker(..)
            // refactor to share the code?

        var newSelection = [String: PHPickerResult]()
        var assets = [PGLAsset]()

        for result in results {
            // localIdentifier is the key for the newSelection dict
            let identifier = result.assetIdentifier!
            newSelection[identifier] = result
        }

        var identifiers:[String] = newSelection.keys.map(\.description)
        let fetchAssetResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        // in limited access mode an identifier may not fetch the asset

        for fetchAsset in fetchAssetResult.objects {
            let anNewPGLAsset = PGLAsset(sourceAsset: fetchAsset)
            assets.append(anNewPGLAsset)
            identifiers.append(fetchAsset.localIdentifier)
            // if video then cache into local file and assign localURL to asset
            if let thisResultProvider = newSelection[fetchAsset.localIdentifier] {
                if thisResultProvider.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
//                    let myAppDelegate =  UIApplication.shared.delegate as! AppDelegate
//                    myAppDelegate.showWaiting(onController: theController)

//                    loadLocalVideoURL(thisAsset: anNewPGLAsset, pickerResult: selection[fetchAsset.localIdentifier]!)
                    anNewPGLAsset.requestVideo()
                }
                }

        }
        parent.viewModel.addAssets(in: parent.sectionID, assets: assets)

        // add the newPGLAssets to the targetParm

    }
    
    init(_ parent: PGLPhotoPicker) {
        self.parent = parent
    }
}
