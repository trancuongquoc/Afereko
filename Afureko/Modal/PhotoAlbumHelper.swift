//
//  PhotoAlbumHelper.swift
//  Afureko
//
//  Created by Quoc Cuong on 10/24/18.
//  Copyright © 2018 Quoc Cuong. All rights reserved.
//

import Photos

class PhotoAlbum {
    static let shared = PhotoAlbum()
    
    var permissionGranted = false
    
    func createAlbum(named: String, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: named)
        }, completionHandler: completion)
    }
    
    func getAlbum(title: String, completionHandler: @escaping (PHAssetCollection?) -> ()) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title = %@", title)
            let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
            
            if let album = collections.firstObject {
                completionHandler(album)
            } else {
                self?.createAlbum(named: title, completion: { (success, error) in
                    if error != nil {
                        print(error!)
                    }
                    
                    if success {
                        print("success")
                    }
                })
            }
        }
    }
    
    func checkPermission() {
        switch PHPhotoLibrary.authorizationStatus() {
        case .notDetermined, .denied:
            requestPermission()
        case .authorized:
            permissionGranted = true
        default:
            permissionGranted = false
        }
    }
    
    private func requestPermission() {
        PHPhotoLibrary.requestAuthorization { [unowned self] (granted) in
            self.permissionGranted = true
        }
    }
    
    func save(videoURL: URL, toAlbum titled: String, completionHandler: @escaping (Bool, Error?) -> ()) {
        getAlbum(title: titled) { (album) in
            DispatchQueue.global(qos: .background).async {
                PHPhotoLibrary.shared().performChanges({
                    let assetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                    let assets = assetRequest!.placeholderForCreatedAsset
                        .map { [$0] as NSArray } ?? NSArray()
                    let albumChangeRequest = album.flatMap { PHAssetCollectionChangeRequest(for: $0) }
                    albumChangeRequest?.addAssets(assets)
                }, completionHandler: { (success, error) in
                    completionHandler(success, error)
                })
            }
        }
    }
}
