//
//  AMVideoRangeSlider.swift
//  Afureko
//
//  Created by Quoc Cuong on 11/13/18.
//  Copyright © 2018 Quoc Cuong. All rights reserved.
//

import UIKit
import QuartzCore
import AVFoundation

internal class AMVideoRangeSliderThumbLayer: CAShapeLayer {
    var highlighted = false
    weak var rangeSlider : AMVideoRangeSlider?
    
    override func layoutSublayers() {
        super.layoutSublayers()
        self.cornerRadius = self.bounds.width / 2
        self.setNeedsDisplay()
    }
    
    override func draw(in ctx: CGContext) {
        ctx.move(to: CGPoint(x: self.bounds.width/2, y: self.bounds.height/5))
        ctx.addLine(to: CGPoint(x: self.bounds.width/2, y: self.bounds.height - self.bounds.height/5))
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.strokePath()
    }
}

internal class AMVideoRangeSliderTrackLayer: CAShapeLayer {
    
    weak var rangeSlider : AMVideoRangeSlider?
    
    override func draw(in ctx: CGContext) {
        if let slider = rangeSlider {
            let lowerValuePosition = CGFloat(slider.positionForValue(value: slider.lowerValue))
            let upperValuePosition = CGFloat(slider.positionForValue(value: slider.upperValue))
            let rect = CGRect(x: lowerValuePosition, y: 0.0, width: upperValuePosition - lowerValuePosition, height: bounds.height)
            ctx.setFillColor(slider.sliderTintColor.cgColor)
            ctx.fill(rect)
        }
    }
}

public protocol AMVideoRangeSliderDelegate: class {
    func rangeSliderLowerThumbValueChanged(value: CMTime)
    func rangeSliderUpperThumbValueChanged(value: CMTime)
}

public class AMVideoRangeSlider: UIControl {
    
    public var middleValue = 0.0 {
        didSet {
            self.updateLayerFrames()
        }
    }
    
    public var minimumValue: Double = 0.0 {
        didSet {
            self.updateLayerFrames()
        }
    }
    
    public var maximumValue: Double = 1.0 {
        didSet {
            self.updateLayerFrames()
        }
    }
    
    public var lowerValue: Double = 0.0 {
        didSet {
            self.updateLayerFrames()
        }
    }
    
    public var upperValue: Double = 1.0 {
        didSet {
            self.updateLayerFrames()
        }
    }
    
    public var videoAsset : AVAsset? {
        didSet {
            self.generateVideoImages()
        }
    }
    
    public var currentTime : CMTime {
        return CMTimeMakeWithSeconds(self.videoAsset!.duration.seconds * self.middleValue, preferredTimescale: self.videoAsset!.duration.timescale)
    }
    
    public var startTime : CMTime! {
        return CMTimeMakeWithSeconds(self.videoAsset!.duration.seconds * self.lowerValue, preferredTimescale: self.videoAsset!.duration.timescale)
    }
    
    public var stopTime : CMTime! {
        return CMTimeMakeWithSeconds(self.videoAsset!.duration.seconds * self.upperValue, preferredTimescale: self.videoAsset!.duration.timescale)
    }
    
    public var rangeTime : CMTimeRange! {
        let lower = self.videoAsset!.duration.seconds * self.lowerValue
        let upper = self.videoAsset!.duration.seconds * self.upperValue
        let duration = CMTimeMakeWithSeconds(upper - lower, preferredTimescale: self.videoAsset!.duration.timescale)
        return CMTimeRangeMake(start: self.startTime, duration: duration)
    }
    
    public var sliderTintColor = UIColor(red:0.97, green:0.71, blue:0.19, alpha:1.00) {
        didSet {
            self.lowerThumbLayer.backgroundColor = self.sliderTintColor.cgColor
            self.upperThumbLayer.backgroundColor = self.sliderTintColor.cgColor
            
        }
    }
    
    public var middleThumbTintColor : UIColor! {
        didSet {
            self.middleThumbLayer.backgroundColor = self.middleThumbTintColor.cgColor
        }
    }
    
    weak var delegate : AMVideoRangeSliderDelegate?
    
    var middleThumbLayer = AMVideoRangeSliderThumbLayer()
    var lowerThumbLayer = AMVideoRangeSliderThumbLayer()
    var upperThumbLayer = AMVideoRangeSliderThumbLayer()
    
    var trackLayer = AMVideoRangeSliderTrackLayer()
    
    var previousLocation = CGPoint()
    
    var thumbWidth : CGFloat {
        return 15
    }
    
    var thumpHeight : CGFloat {
        return self.bounds.height + 10
    }
    
    public override var frame: CGRect {
        didSet {
            self.updateLayerFrames()
        }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    public required init(coder : NSCoder) {
        super.init(coder: coder)!
        self.commonInit()
    }
    
    public override func layoutSubviews() {
        self.updateLayerFrames()
    }
    
    func commonInit() {
        self.trackLayer.rangeSlider = self
        self.middleThumbLayer.rangeSlider = self
        self.lowerThumbLayer.rangeSlider = self
        self.upperThumbLayer.rangeSlider = self
        
        self.layer.addSublayer(self.trackLayer)
        self.layer.addSublayer(self.lowerThumbLayer)
        self.layer.addSublayer(self.upperThumbLayer)
        
        self.middleThumbLayer.backgroundColor = UIColor.green.cgColor
        self.lowerThumbLayer.backgroundColor = self.sliderTintColor.cgColor
        self.upperThumbLayer.backgroundColor = self.sliderTintColor.cgColor
        
        self.trackLayer.contentsScale = UIScreen.main.scale
        self.lowerThumbLayer.contentsScale = UIScreen.main.scale
        self.upperThumbLayer.contentsScale = UIScreen.main.scale
        
        self.updateLayerFrames()
    }
    
    func updateLayerFrames() {
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        self.trackLayer.frame = self.bounds
        self.trackLayer.setNeedsDisplay()
        
        let lowerThumbCenter = CGFloat(self.positionForValue(value: self.lowerValue))
        self.lowerThumbLayer.frame = CGRect(x: lowerThumbCenter - self.thumbWidth / 2, y: -5.0, width: self.thumbWidth, height: self.thumpHeight)
        
        let upperThumbCenter = CGFloat(self.positionForValue(value: self.upperValue))
        self.upperThumbLayer.frame = CGRect(x: upperThumbCenter - self.thumbWidth / 2, y: -5.0, width: self.thumbWidth, height: self.thumpHeight)
        
        CATransaction.commit()
    }
    
    func positionForValue(value: Double) -> Double {
        return Double(self.bounds.width - self.thumbWidth) * (value - self.minimumValue) / (self.maximumValue - self.minimumValue) + Double(self.thumbWidth / 2.0)
    }
    
    public override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        self.previousLocation = touch.location(in: self)
        
        if self.lowerThumbLayer.frame.contains(self.previousLocation) {
            self.lowerThumbLayer.highlighted = true
        } else if self.upperThumbLayer.frame.contains(self.previousLocation) {
            self.upperThumbLayer.highlighted = true
        } else {
            self.middleThumbLayer.highlighted = true
        }
        
        return self.lowerThumbLayer.highlighted || self.upperThumbLayer.highlighted || self.middleThumbLayer.highlighted
    }
    
    func boundValue(value: Double, toLowerValue lowerValue: Double, upperValue: Double) -> Double {
        return min(max(value, lowerValue), upperValue)
    }
    
    public override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let location = touch.location(in: self)
        
        let deltaLocation = Double(location.x - self.previousLocation.x)
        let deltaValue = (self.maximumValue - self.minimumValue) * deltaLocation / Double(self.bounds.width - self.thumbWidth)
        let newMiddle = Double(self.previousLocation.x) / Double(self.bounds.width - self.thumbWidth)
        
        self.previousLocation = location
        
        if self.lowerThumbLayer.highlighted {
            if deltaValue > 0 && self.rangeTime.duration.seconds <= 1{
                
            } else {
                self.lowerValue += deltaValue
                self.lowerValue = self.boundValue(value: self.lowerValue, toLowerValue: self.minimumValue, upperValue: self.maximumValue)
                self.delegate?.rangeSliderLowerThumbValueChanged(value: startTime)
            }
            
        } else if self.middleThumbLayer.highlighted {
            self.middleValue = newMiddle
            self.middleValue = self.boundValue(value: self.middleValue, toLowerValue: self.lowerValue, upperValue: self.upperValue)
        } else if self.upperThumbLayer.highlighted {
            if deltaValue < 0 && self.rangeTime.duration.seconds <= 1 {
                
            } else {
                self.upperValue += deltaValue
                self.upperValue = self.boundValue(value: self.upperValue, toLowerValue: self.minimumValue, upperValue: self.maximumValue)
                self.delegate?.rangeSliderUpperThumbValueChanged(value: stopTime)
            }
        }
        
        self.sendActions(for: .valueChanged)
        return true
    }
    
    public override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        DispatchQueue.main.async { [unowned self] in
            self.lowerThumbLayer.highlighted = false
            self.upperThumbLayer.highlighted = false
        }
    }
    
    func generateVideoImages() {
        var imageWidth: CGFloat!
        var imageFrame: CGRect!
        var numberOfImages = 0
        
        self.lowerValue = 0.0
        self.upperValue = 1.0
        
        DispatchQueue.main.async { [unowned self] in
            for subview in self.subviews {
                if subview is UIImageView {
                    subview.removeFromSuperview()
                }
            }
        }
        
        
        let imageGenerator = AVAssetImageGenerator(asset: self.videoAsset!)
        
        let assetDuration = CMTimeGetSeconds(self.videoAsset!.duration)
        var times = [NSValue]()
        
        numberOfImages = Int((self.frame.width / self.frame.height))
            
            for index in 1...numberOfImages {
                let point = CMTimeMakeWithSeconds(assetDuration/Double(index), preferredTimescale: 600)
                times += [NSValue(time: point)]
            }
        

        
        times = times.reversed()
        DispatchQueue.main.async { [unowned self] in
            imageWidth = self.frame.width/CGFloat(numberOfImages)
            imageFrame = CGRect(x: 0, y: 2, width: imageWidth, height: self.frame.height - 4)
        }
        
        imageGenerator.generateCGImagesAsynchronously(forTimes: times) { (requestedTime, image, actualTime, result, error) in
            if error == nil {
                
                if result == AVAssetImageGenerator.Result.succeeded {
                    
                    DispatchQueue.main.async { [unowned self] in
                        let imageView = UIImageView(image: UIImage(cgImage: image!))
                        imageView.contentMode = .scaleAspectFill
                        imageView.clipsToBounds = true
                        imageView.frame = imageFrame
                        imageFrame.origin.x += imageWidth
                        self.insertSubview(imageView, at:1)
                    }
                }
                
                if result == AVAssetImageGenerator.Result.failed {
                    print("Generating Fail")
                }
                
            } else {
                print("Error at generating images : \(error)")
            }
        }
        
    }
}
