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
    
      var storedError: NSError!
      var downloadGroup = dispatch_group_create()
      var addresses = [OverlyAttachedGirlfriendURLString,
                       SuccessKidURLString,
                       LotsOfFacesURLString]
 
    
      // addresses array is expanded to hold three of each address
      addresses += addresses + addresses
    
      // will hold the created blocks for later use
      var blocks: [dispatch_block_t] = []
    
      /*
        CANCELLING DISPATCH BLOCKS-new for iOS8
      
        Dispatch block objects
        -can set a Quality of Service class per object for internal prioritization in a queue
        -can cancel the execution of block objects
          -a block object can only be cancelled before it reaches the head of a queue and starts executing
      */
    
      for i in 0 ..< addresses.count {
          dispatch_group_enter(downloadGroup)
          // creates a new block object
          // first parameter is a flag defining various block traits
          // flag used here makes the block inherit its QoS class from the queue it is dispatched to
        
          let block = dispatch_block_create(DISPATCH_BLOCK_INHERIT_QOS_CLASS) {
              let index = Int(i)
              let address = addresses[index]
              let url = NSURL(string: address)
              let photo = DownloadPhoto(url: url!) {
                  image, error in
                if let error = error {
                    storedError = error
                }
                dispatch_group_leave(downloadGroup)
              }
              PhotoManager.sharedManager.addPhoto(photo)
        }
        blocks.append(block)
        // block is dispatched asynchronously to the global main queue
        // code that sets up the dispatch block is already executing on the main queue so you are guaranteed the 
        //  download blocks will execute at some later time
        dispatch_async(GlobalMainQueue, block)
      }
    
    // first three downloads left alone
    for block in blocks[3 ..< blocks.count] {
        let cancel = arc4random_uniform(2) // 0 or 1, like a coin toss
        // if the random num = 1, block is cancelled, IF the block is still in a queue and has not begun executing.
        // blocks cannot be cancelled in the middle of execution
        if cancel == 1 {
            dispatch_block_cancel(block)
            // since all blocks are added to the dispatch group, remember to remove the cancelled ones
            dispatch_group_leave(downloadGroup)
        }
    }
    
    dispatch_group_notify(downloadGroup, GlobalMainQueue) {
      if let completion = completion {
          completion(error: storedError)
      }
    }
    
}
  
  
  private func postContentAddedNotification() {
    NSNotificationCenter.defaultCenter().postNotificationName(PhotoManagerAddedContentNotification, object: nil)
  }
}
