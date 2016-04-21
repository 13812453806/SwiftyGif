//
//  UIImageView+SwiftyGif.swift
//

import ImageIO
import UIKit

let _gifImageKey = malloc(4)
let _cacheKey = malloc(4)
let _currentImageKey = malloc(4)
let _displayOrderIndexKey = malloc(4)
let _syncFactorKey = malloc(4)
let _haveCacheKey = malloc(4)
let _loopCountKey = malloc(4)
let _displayingKey = malloc(4)
let _isAnimatingKey = malloc(4)
let _animationManagerKey = malloc(4)

public extension UIImageView {

    // PRAGMA - Inits

    /**
     Convenience initializer. Creates a gif holder (defaulted to infinite loop).
     - Parameter gifImage: The UIImage containing the gif backing data
     - Parameter manager: The manager to handle the gif display
     */
    public convenience init(gifImage:UIImage, manager:SwiftyGifManager = SwiftyGifManager.defaultManager) {
        self.init()
        setGifImage(gifImage,manager: manager, loopCount: -1);
    }

    /**
     Convenience initializer. Creates a gif holder.
     - Parameter gifImage: The UIImage containing the gif backing data
     - Parameter manager: The manager to handle the gif display
     - Parameter loopCount: The number of loops we want for this gif. -1 means infinite.
     */
    public convenience init(gifImage:UIImage, manager:SwiftyGifManager = SwiftyGifManager.defaultManager, loopCount:Int) {
        self.init()
        setGifImage(gifImage,manager: manager, loopCount: loopCount);
    }

    /**
     Set a gif image and a manager to an existing UIImageView. The gif will default to infinite loop.
     WARNING : this overwrite any previous gif.
     - Parameter gifImage: The UIImage containing the gif backing data
     - Parameter manager: The manager to handle the gif display
     */
    public func setGifImage(gifImage:UIImage, manager:SwiftyGifManager = SwiftyGifManager.defaultManager) {
        setGifImage(gifImage, manager: manager, loopCount: -1)
    }

    /**
     Set a gif image and a manager to an existing UIImageView. 
     WARNING : this overwrite any previous gif.
     - Parameter gifImage: The UIImage containing the gif backing data
     - Parameter manager: The manager to handle the gif display
     - Parameter loopCount: The number of loops we want for this gif. -1 means infinite.
     */
    public func setGifImage(gifImage:UIImage, manager:SwiftyGifManager = SwiftyGifManager.defaultManager, loopCount:Int) {

        self.loopCount = loopCount
        self.gifImage = gifImage
        self.animationManager = manager
        self.syncFactor = 0
        self.displayOrderIndex = 0
        self.cache = NSCache()
        self.haveCache = false

        if let gif = self.gifImage {

            if let source = gif.imageSource {
                self.currentImage = UIImage(CGImage: CGImageSourceCreateImageAtIndex(source, 0, nil)!)

                if !manager.containsImageView(self) {
                    manager.addImageView(self)
                    startDisplay()
                    startAnimatingGif()
                }
            }
        }
    }

    // PRAGMA - Logic

    /**
     Start displaying the gif for this UIImageView.
     */
    private func startDisplay() {
        self.displaying = true
        updateCache()
    }

    /**
     Stop displaying the gif for this UIImageView.
     */
    private func stopDisplay() {
        self.displaying = false
        updateCache()
    }

    /**
     Start displaying the gif for this UIImageView.
     */
    public func startAnimatingGif() {
        self.isAnimatingGif = true
    }

    /**
     Stop displaying the gif for this UIImageView.
     */
    public func stopAnimatingGif() {
        self.isAnimatingGif = false
    }

    /**
     Show a specific frame based on a delta from current frame
      - Parameter delta: The delsta from current frame we want
     */
    public func showFrameForIndexDelta(delta: Int) {

        self.displayOrderIndex += delta

        while self.displayOrderIndex >= self.gifImage!.displayOrder!.count{
            self.displayOrderIndex -= self.gifImage!.displayOrder!.count
        }

        while self.displayOrderIndex < 0 {
            self.displayOrderIndex += self.gifImage!.displayOrder!.count
        }

        showFrameAtIndex(self.displayOrderIndex)
    }

    /**
     Show a specific frame
      - Parameter index: The index of frame to show
     */
    public func showFrameAtIndex(index: Int) {
        self.displayOrderIndex = index
        updateFrame()
    }

    /**
     Update cache for the current imageView.
     */
    public func updateCache() {
        if self.animationManager.hasCache(self) && !self.haveCache {
            prepareCache()
            self.haveCache = true
        }else if !self.animationManager.hasCache(self) && self.haveCache {
            self.cache.removeAllObjects()
            self.haveCache = false
        }
    }

    /**
     Update current image displayed. This method is called by the manager.
     */
    public func updateCurrentImage() {

        if self.displaying{
            updateFrame()
            updateIndex()
            if loopCount == 0 || !isDisplayedInScreen(self)  || !self.isAnimatingGif {
                stopDisplay()
            }
        }else{
            if(isDisplayedInScreen(self) && loopCount != 0 && self.isAnimatingGif) {
                startDisplay()
            }
            if isDiscarded(self) {
                self.animationManager.deleteImageView(self)
            }
        }
    }

    private func updateFrame() {

        if !self.haveCache {
            self.currentImage = UIImage(CGImage: CGImageSourceCreateImageAtIndex(self.gifImage!.imageSource!,self.gifImage!.displayOrder![self.displayOrderIndex],nil)!)
        }else{
            if let image = (cache.objectForKey(self.displayOrderIndex) as? UIImage) {
                self.currentImage = image
            }else{
                self.currentImage = UIImage(CGImage: CGImageSourceCreateImageAtIndex(self.gifImage!.imageSource!,self.gifImage!.displayOrder![self.displayOrderIndex],nil)!)
            }//prevent case that cache is not ready
        }
    }

    /**
     Check if the imageView has been discarded and is not in the view hierarchy anymore.
     - Returns : A boolean for weather the imageView was discarded
     */
    public func isDiscarded(imageView:UIView?) -> Bool{
        if(imageView == nil || imageView!.superview == nil) {
            return true
        }
        return false
    }

    /**
     Check if the imageView is displayed.
     - Returns : A boolean for weather the imageView is displayed
     */
    public func isDisplayedInScreen(imageView:UIView?) ->Bool{
        if (self.hidden) {
            return false
        }

        let screenRect = UIScreen.mainScreen().bounds
        let viewRect = imageView!.convertRect(self.frame,toView:UIApplication.sharedApplication().keyWindow)

        let intersectionRect = CGRectIntersection(viewRect, screenRect);
        if (CGRectIsEmpty(intersectionRect) || CGRectIsNull(intersectionRect)) {
            return false
        }
        return (self.window != nil)
    }

    /**
     Update index.
     */
    private func updateIndex() {
        if let gif = self.gifImage {
            self.syncFactor = (self.syncFactor+1) % gif.displayRefreshFactor!
            if self.syncFactor == 0 {
                self.displayOrderIndex = (self.displayOrderIndex+1) % gif.imageCount!
                if displayOrderIndex == 0 && self.loopCount > 0 {
                    self.loopCount -= 1;
                }
            }
        }
    }

    /**
     Prepare the cache by adding every images of the gif to an NSCache object.
     */
    private func prepareCache() {
        self.cache.removeAllObjects()

        if let gif = self.gifImage {
            for i in 0 ..< gif.displayOrder!.count {
                let image = UIImage(CGImage: CGImageSourceCreateImageAtIndex(gif.imageSource!, gif.displayOrder![i],nil)!)
                self.cache.setObject(image,forKey:i)
            }
        }
    }

    // PRAGMA - get / set associated values

    public var gifImage: UIImage? {
        get {
            return (objc_getAssociatedObject(self, _gifImageKey) as! UIImage?)
        }
        set {
            objc_setAssociatedObject(self, _gifImageKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }
    public var currentImage: UIImage {
        get {
            return (objc_getAssociatedObject(self, _currentImageKey) as! UIImage)
        }
        set {
            objc_setAssociatedObject(self, _currentImageKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }

    private var displayOrderIndex: Int {
        get {
            return (objc_getAssociatedObject(self, _displayOrderIndexKey) as! Int)
        }
        set {
            objc_setAssociatedObject(self, _displayOrderIndexKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }

    private var syncFactor: Int {
        get {
            return (objc_getAssociatedObject(self, _syncFactorKey) as! Int)
        }
        set {
            objc_setAssociatedObject(self, _syncFactorKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }

    public var loopCount: Int {
        get {
            return (objc_getAssociatedObject(self, _loopCountKey) as! Int)
        }
        set {
            objc_setAssociatedObject(self, _loopCountKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }

    public var animationManager: SwiftyGifManager {
        get {
            return (objc_getAssociatedObject(self, _animationManagerKey) as! SwiftyGifManager)
        }
        set {
            objc_setAssociatedObject(self, _animationManagerKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }

    private var haveCache: Bool {
        get {
            return (objc_getAssociatedObject(self, _haveCacheKey) as! Bool)
        }
        set {
            objc_setAssociatedObject(self, _haveCacheKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }

    public var displaying: Bool {
        get {
            return (objc_getAssociatedObject(self, _displayingKey) as! Bool)
        }
        set {
            objc_setAssociatedObject(self, _displayingKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }

    public var isAnimatingGif: Bool {
        get {
            return (objc_getAssociatedObject(self, _isAnimatingKey) as! Bool)
        }
        set {
            objc_setAssociatedObject(self, _isAnimatingKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }

    private var cache: NSCache {
        get {
            return (objc_getAssociatedObject(self, _cacheKey) as! NSCache)
        }
        set {
            objc_setAssociatedObject(self, _cacheKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }
}
