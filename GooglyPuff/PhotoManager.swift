//
//  PhotoManager.swift
//  GooglyPuff
//
//  Created by Bjørn Olav Ruud on 06.08.14.
//  Copyright (c) 2014 raywenderlich.com. All rights reserved.
//

import Foundation

/// Notification when new photo instances are added
let PhotoManagerAddedContentNotification = "com.raywenderlich.GooglyPuff.PhotoManagerAddedContent"
/// Notification when content updates (i.e. Download finishes)
let PhotoManagerContentUpdateNotification = "com.raywenderlich.GooglyPuff.PhotoManagerContentUpdate"

typealias PhotoProcessingProgressClosure = (completionPercentage: CGFloat) -> Void
typealias BatchPhotoDownloadingCompletionClosure = (error: NSError?) -> Void

private let _sharedManager = PhotoManager()

class PhotoManager {
  class var sharedManager: PhotoManager {
    return _sharedManager
  }

  
  // create read-only stored property
  // https://books.google.com/books?id=Dq3TBQAAQBAJ&pg=PT200&lpg=PT200&dq=private+var+underscore+swift&source=bl&ots=XLknAbsDCv&sig=1BFc4NVNyUgbXdChpMYlexvn0Q0&hl=en&sa=X&ved=0CFIQ6AEwCGoVChMIu8z6oJbWyAIVDBo-Ch3VzA27#v=onepage&q=private%20var%20underscore%20swift&f=false
  
  private var _photos: [Photo] = []
  
  var photos: [Photo] {
    
    var photosCopy: [Photo]!
  
    dispatch_sync(concurrentPhotoQueue) {
        photosCopy = self._photos
    }
    
     return photosCopy
  
  }

  
  private let concurrentPhotoQueue = dispatch_queue_create("com.raywenderlich.GooglyPuff.photoQueue", DISPATCH_QUEUE_CONCURRENT)

  func addPhoto(photo: Photo) {
    
    dispatch_barrier_async(concurrentPhotoQueue) {
      self._photos.append(photo)
      dispatch_async(GlobalMainQueue) {
        self.postContentAddedNotification()
        
      }
    
    }

  }

  func downloadPhotosWithCompletion(completion: BatchPhotoDownloadingCompletionClosure?) {
    var storedError: NSError?
    for address in [OverlyAttachedGirlfriendURLString,
                    SuccessKidURLString,
                    LotsOfFacesURLString] {
      let url = NSURL(string: address)
      let photo = DownloadPhoto(url: url!) {
        image, error in
        if error != nil {
          storedError = error
        }
      }
      PhotoManager.sharedManager.addPhoto(photo)
    }

    if let completion = completion {
      completion(error: storedError)
    }
  }

  private func postContentAddedNotification() {
    NSNotificationCenter.defaultCenter().postNotificationName(PhotoManagerAddedContentNotification, object: nil)
  }
}
