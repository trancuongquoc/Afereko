//
//  Extensions.swift
//  Afureko
//
//  Created by Quoc Cuong on 11/5/18.
//  Copyright © 2018 Quoc Cuong. All rights reserved.
//

import UIKit
import AVFoundation

func showAlert(title: String?, message: String?, actionTitles:[String?], actions:[((UIAlertAction) -> Void)?]) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    for (index, title) in actionTitles.enumerated() {
        let action = UIAlertAction(title: title, style: .default, handler: actions[index])
        alert.addAction(action)
    }
    if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
        rootVC.present(alert, animated: true, completion: nil)
    }
}

func tempURL(for type: String) -> URL? {
    let directory = NSTemporaryDirectory() as NSString
    
    if directory != "" {
        let path = directory.appendingPathComponent(NSUUID().uuidString + type)
        return URL(fileURLWithPath: path)
    }
    
    return nil
}

func disableUserInteractions(for buttons: [UIButton]?, barButtons: [UIBarButtonItem]?) {
    if let buttons = buttons {
        for button in buttons {
            if button.isEnabled == true {
                DispatchQueue.main.async {
                    button.isEnabled = false
                }
            }
        }
    }
    
    if let buttons = barButtons {
        for button in buttons {
            if button.isEnabled == true {
                DispatchQueue.main.async {
                    button.isEnabled = false
                }
            }
        }
    }
}

func enableUserInteractions(for buttons: [UIButton]?, barButtons: [UIBarButtonItem]?) {
    if let buttons = buttons {
        for button in buttons {
            DispatchQueue.main.async {
                button.isEnabled = true
            }
        }
    }
    
    if let buttons = barButtons {
        for button in buttons {
            DispatchQueue.main.async {
                button.isEnabled = true
            }
        }
    }
}

extension Float64 {
    func intoString() -> String {
        let text = String(format: "%.02f", self)
        return text
    }
}

extension URL {
    
    var videoDuration: Float64 {
        let videoAsset = AVURLAsset.init(url: self, options: [AVURLAssetPreferPreciseDurationAndTimingKey : true])
        let duration = CMTimeGetSeconds(videoAsset.duration)
        return duration
    }
    
    var videoDurationInCMTime: CMTime {
        let videoAsset = AVURLAsset.init(url: self, options: [AVURLAssetPreferPreciseDurationAndTimingKey : true])
        let duration = videoAsset.duration
        return duration
    }
    
    func removeItemIfExisted() {
        let savePathURL = self
        do {
            try FileManager.default.removeItem(at: savePathURL)
        }
        catch let error as NSError {
            print("Ooops! Something went wrong while removing file: \(error)")
        }
    }
    
    func thumbnailImage(at time: Double, completion: (_ image: UIImage) -> Void) {
        let asset = AVURLAsset(url: self)
        
        let assetIG = AVAssetImageGenerator(asset: asset)
        assetIG.appliesPreferredTrackTransform = true
        assetIG.apertureMode = AVAssetImageGenerator.ApertureMode.encodedPixels
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 60)
        
        var thumbnailImageRef: CGImage?
        do {
            thumbnailImageRef = try assetIG.copyCGImage(at: cmTime, actualTime: nil)
        } catch let error {
            print("Error: \(error)")
        }
        
        if let resultImage = thumbnailImageRef {
            let image = UIImage(cgImage: resultImage)
            completion(image)
        }
    }
}

extension UIImage {
    func resize(with newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage ?? self
    }
}

extension AVCaptureDevice {
    func toggleTorch() -> TorchMode {
        let currentDevice = self
        
        if currentDevice.hasTorch {
            do {
                try self.lockForConfiguration()
                
                switch self.torchMode {
                case .on:
                    self.torchMode = .off
                case .off:
                    self.torchMode = .auto
                case .auto:
                    self.torchMode = .on
                }
                self.unlockForConfiguration()
            } catch {
                print("Torch cant be used.")
            }
        }
        return torchMode
    }
}

