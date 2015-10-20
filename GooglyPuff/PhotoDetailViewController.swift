//
//  PhotoDetailViewController.swift
//  GooglyPuff
//
//  Created by Bjørn Olav Ruud on 06.08.14.
//  Copyright (c) 2014 raywenderlich.com. All rights reserved.
//

import UIKit

private let RetinaToEyeScaleFactor: CGFloat = 0.5
private let FaceBoundsToEyeScaleFactor: CGFloat = 4.0

class PhotoDetailViewController: UIViewController {
  @IBOutlet var photoScrollView: UIScrollView!
  @IBOutlet var photoImageView: UIImageView!

  var image: UIImage!

  // MARK: - Lifecycle

  /* 
    QUEUE TYPES
    
    *Main Queue*
    Like any serial queue, tasks in this queue execute one at a time.
    However, it's guaranteed that all tasks will execute on the main thread, which is 
     the only thread allowed to update your UI.
  
    *System Concurrent Queues*
    Linked with their own Quality of Service (QoS) class
    Meant to express the intent of the submitted taks so that GCD can determine how to best prioritize
  
  
    // NEW FOR IOS8: QoS Framework
  
  
    QOS_CLASS_USER_INTERACTIVE: 
    Represents tasks that need to be done immediately in order
    to provide a nice user experience.
    Use it for UI updates, event handling and small workloads that require low latency
    Total amount of work done in this class during the execution of your app should be small
  
    QOS_CLASS_USER_INITIATED
    represents tasks that are initiated from the UI and can be performed asynchronously
    It should be used when the user is waiting for immedicate results and for 
    tasks required to continue user interaction
  
    QOS_CLASS_UTILITY:
    represents long running tasks, typically with a user-visible progress indicator
    Use it for computations, I/O, networking, continuous data feeds and similar tasks
    Designed to be energy efficient.
  
    QOS_CLASS_BACKGROUND
    represents tasks that the user is not directly aware of.
    Use it for prefetching, maintenance that don't require user interaction and aren't time sensitive.

  */
  
  /*
    HOW ND WHEN TO USE THE VARIOUS QUEUE TYPES WITH dispatch_async:
    
    *Custom Serial Queue*
    Good choice when you want to perform background tasks serially and track it
    Eliminates resource contention since you know only one task at a time is executing.
    If you need the data from a method, you must inline another closure to retrieve it or use dispatch_sync
  
    *Main Queue (Serial)*
    Common choice to update the UI after completing work in a task on a concurrent queue
    You nest one closure inside another
    If you're on the main queue and call dispatch_async on the main queue, you can guarantee
     this new task will execute sometime after current method finishes
  
    *Concurrent Queue*
    Common choice to perform non-UI work in background


  */
  
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    assert(image != nil, "Image not set; required to use view controller")
    photoImageView.image = image

    // Resize if neccessary to ensure it's not pixelated
    if image.size.height <= photoImageView.bounds.size.height &&
       image.size.width <= photoImageView.bounds.size.width {
      photoImageView.contentMode = .Center
    }

    // move the work off the main thread and onto a global queue
    // closure submitted asynchronously, calling thread continues-makes loading feel more snappy
    dispatch_async(GlobalMainQueue) {
      let overlayImage = self.faceOverlayImageFromImage(self.image)
      // add closure to main queue to fade in googly eyes
      dispatch_async(dispatch_get_main_queue()) {
        self.fadeInNewImage(overlayImage)
      }

    }
  }
}

// MARK: - Private Methods

private extension PhotoDetailViewController {
  func faceOverlayImageFromImage(image: UIImage) -> UIImage {
    let detector = CIDetector(ofType: CIDetectorTypeFace,
                     context: nil,
                     options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])

    // Get features from the image
    let newImage = CIImage(CGImage: image.CGImage)
    let features = detector.featuresInImage(newImage) as! [CIFaceFeature]!

    UIGraphicsBeginImageContext(image.size)
    let imageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)

    // Draws this in the upper left coordinate system
    image.drawInRect(imageRect, blendMode: kCGBlendModeNormal, alpha: 1.0)

    let context = UIGraphicsGetCurrentContext()
    for faceFeature in features {
      let faceRect = faceFeature.bounds
      CGContextSaveGState(context)

      // CI and CG work in different coordinate systems, we should translate to
      // the correct one so we don't get mixed up when calculating the face position.
      CGContextTranslateCTM(context, 0.0, imageRect.size.height)
      CGContextScaleCTM(context, 1.0, -1.0)

      if faceFeature.hasLeftEyePosition {
        let leftEyePosition = faceFeature.leftEyePosition
        let eyeWidth = faceRect.size.width / FaceBoundsToEyeScaleFactor
        let eyeHeight = faceRect.size.height / FaceBoundsToEyeScaleFactor
        let eyeRect = CGRect(x: leftEyePosition.x - eyeWidth / 2.0,
          y: leftEyePosition.y - eyeHeight / 2.0,
          width: eyeWidth,
          height: eyeHeight)
        drawEyeBallForFrame(eyeRect)
      }

      if faceFeature.hasRightEyePosition {
        let leftEyePosition = faceFeature.rightEyePosition
        let eyeWidth = faceRect.size.width / FaceBoundsToEyeScaleFactor
        let eyeHeight = faceRect.size.height / FaceBoundsToEyeScaleFactor
        let eyeRect = CGRect(x: leftEyePosition.x - eyeWidth / 2.0,
          y: leftEyePosition.y - eyeHeight / 2.0,
          width: eyeWidth,
          height: eyeHeight)
        drawEyeBallForFrame(eyeRect)
      }

      CGContextRestoreGState(context);
    }

    let overlayImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return overlayImage
  }

  func faceRotationInRadians(leftEyePoint startPoint: CGPoint, rightEyePoint endPoint: CGPoint) -> CGFloat {
    let deltaX = endPoint.x - startPoint.x
    let deltaY = endPoint.y - startPoint.y
    let angleInRadians = CGFloat(atan2f(Float(deltaY), Float(deltaX)))

    return angleInRadians;
  }

  func drawEyeBallForFrame(rect: CGRect) {
    let context = UIGraphicsGetCurrentContext()
    CGContextAddEllipseInRect(context, rect)
    CGContextSetFillColorWithColor(context, UIColor.whiteColor().CGColor)
    CGContextFillPath(context)

    var x: CGFloat
    var y: CGFloat
    var eyeSizeWidth: CGFloat
    var eyeSizeHeight: CGFloat
    eyeSizeWidth = rect.size.width * RetinaToEyeScaleFactor
    eyeSizeHeight = rect.size.height * RetinaToEyeScaleFactor

    x = CGFloat(arc4random_uniform(UInt32(rect.size.width - eyeSizeWidth)))
    y = CGFloat(arc4random_uniform(UInt32(rect.size.height - eyeSizeHeight)))
    x += rect.origin.x
    y += rect.origin.y

    let eyeSize = min(eyeSizeWidth, eyeSizeHeight)
    let eyeBallRect = CGRect(x: x, y: y, width: eyeSize, height: eyeSize)
    CGContextAddEllipseInRect(context, eyeBallRect)
    CGContextSetFillColorWithColor(context, UIColor.blackColor().CGColor)
    CGContextFillPath(context)
  }

  func fadeInNewImage(newImage: UIImage) {
    let tmpImageView = UIImageView(image: newImage)
    tmpImageView.autoresizingMask = .FlexibleWidth | .FlexibleHeight
    tmpImageView.contentMode = photoImageView.contentMode
    tmpImageView.frame = photoImageView.bounds
    tmpImageView.alpha = 0.0
    photoImageView.addSubview(tmpImageView)

    UIView.animateWithDuration(0.75, animations: {
      tmpImageView.alpha = 1.0
    }, completion: {
      finished in
      self.photoImageView.image = newImage
      tmpImageView.removeFromSuperview()
    })
  }
}

// MARK: - UIScrollViewDelegate

extension PhotoDetailViewController: UIScrollViewDelegate {
  func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
    return photoImageView
  }
}
