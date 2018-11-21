//
//  VideoManager.swift
//  Afureko
//
//  Created by Quoc Cuong on 11/5/18.
//  Copyright © 2018 Quoc Cuong. All rights reserved.
//

import AVFoundation
import UIKit

enum PlaybackOption {
    case withTimeObserver
    case withoutTimeObserver
}

class VideoManager: NSObject {
    
    static var instancesOfSelf = [VideoManager]()
    
    var avPlayerLayer: AVPlayerLayer!
    var avPlayer: AVPlayer!
    var timeObserverToken: Any?
    var isPlaying = false
    
    private var startTime: CMTime = .zero {
        didSet {
            seek(to: startTime)
        }
    }
    
    private var stopTime: CMTime = .zero
    
    let maximumPlaybackDuration: Float64 = 20.0
    let defaultSize = CGSize(width: 1920, height: 1080) // Default video size
    
    weak var delegate: VideoManagerDelegate?
    
    override init() {
        super.init()
        VideoManager.instancesOfSelf.append(self)
        print("VideoManager instance is initialized")
    }
    
    deinit {
        print("VideoManager got deinitialized.")
    }
    
    func setStartTime(value: CMTime) { startTime = value }
    func setStopTime(value: CMTime) { stopTime =  value }
    
    class func destroySelf(object: VideoManager)
    {
        instancesOfSelf = instancesOfSelf.filter {
            $0 !== object
        }
    }
    
    func configure(with url: URL, within videoView: UIView, commpletionHandler: @escaping (Bool) -> Void) {
        func configureAVPlayerLayer() {
            DispatchQueue.main.async {
                self.avPlayerLayer = AVPlayerLayer(player: self.avPlayer)
                self.avPlayerLayer.frame = videoView.bounds
                self.avPlayerLayer.videoGravity = .resizeAspectFill
                videoView.layer.insertSublayer(self.avPlayerLayer, at: 0)
            }
        }
        
        func configureAVPlayerItem() {
            avPlayer = AVPlayer()
            let itemToPlay = AVPlayerItem(url: url)
            self.avPlayer.replaceCurrentItem(with: itemToPlay)
            self.avPlayer.seek(to: .zero)
        }
        
        configureAVPlayerItem()
        configureAVPlayerLayer()
        commpletionHandler(true)
    }
    
    private func addPeriodicTimeObserver(limited: Bool) {
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: 0.1, preferredTimescale: timeScale)
        
        timeObserverToken = avPlayer.addPeriodicTimeObserver(forInterval: time, queue: .main, using: { [unowned self] (time) in
            self.delegate?.videoManager(didUpdatePlaybackTimeTo: time)
            
            if limited {
                if time >= self.stopTime {
                    self.stop()
                }
            }
        })
    }
    
    private func removePeriodicTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            avPlayer.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    func stop() {
        pause()
        seek(to: startTime)
        removePeriodicTimeObserver()
    }
    
    func seek(to time: CMTime) {
        pause()
        avPlayer.seek(to: time)
        delegate?.videoManager(didUpdatePlaybackTimeTo: time)
    }
    
    func play(option: PlaybackOption = .withoutTimeObserver, timeLimited: Bool = false) {
        if option == .withTimeObserver {
            addPeriodicTimeObserver(limited: timeLimited)
        }
        
        avPlayer.play()
        isPlaying = true
    }
    
    func pause() {
        if isPlaying {
            avPlayer.pause()
            isPlaying = false
        } else {
            print("Unsuccessfully pause video.")
        }
    }
    
    func cleanup() {
        avPlayer.pause()
        avPlayer.replaceCurrentItem(with: nil)
        removePeriodicTimeObserver()
        avPlayerLayer.removeFromSuperlayer()
        avPlayerLayer = nil
        avPlayer = nil
        VideoManager.destroySelf(object: self)
    }
}

extension VideoManager {     //MARK: - Merge & Export
    
    func mergeAllVideos(with urls: [URL], option: MergeOption) {
        let mixComposition = AVMutableComposition.init()
        
        // To capture video.
        let compositionVideoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        // To capture audio.
        let compositionAudioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        var nextCliptStartTime: CMTime = CMTime.zero
        // Iterate video array.
        for file_url in urls {
            // Do Merging here.
            let videoAsset = AVURLAsset.init(url: file_url, options: [AVURLAssetPreferPreciseDurationAndTimingKey : true])
            let timeRangeInAsset = CMTimeRangeMake(start: CMTime.zero, duration: videoAsset.duration)
            
            do {
                // Merge video.
                try compositionVideoTrack?.insertTimeRange(CMTimeRange(start: CMTime.zero, duration: videoAsset.duration), of: videoAsset.tracks(withMediaType: .video)[0], at: nextCliptStartTime)
                if option == .withOriginalAudio {
                    // Merge Audio
                    try compositionAudioTrack?.insertTimeRange(CMTimeRange(start: CMTime.zero, duration: videoAsset.duration), of: videoAsset.tracks(withMediaType: .audio)[0], at: nextCliptStartTime)
                }
            } catch {
                print(error)
            }
            
            // Increment the time to which next clip add.
            nextCliptStartTime = CMTimeAdd(nextCliptStartTime, timeRangeInAsset.duration)
        }
        
        // Add rotation to make it portrait.
        let rotationTransform = CGAffineTransform(rotationAngle: CGFloat(Double.pi/2))
        compositionVideoTrack!.preferredTransform = rotationTransform
        
        // Exporting
        guard let savePathUrl = tempURL(for: ".mov") else { return }
        export(from: mixComposition, preset: AVAssetExportPresetPassthrough, outputType: .mov, savePathUrl: savePathUrl) { [unowned self] (error, url) in
            if error != nil {
                print(error!)
            }
            
            if let outputURL = url {
                self.delegate?.videoManager(didFinishMergingTo: outputURL)
            }
        }
    }
    
    func mergeVideoAndAudio(videoUrl: URL,
                            audioUrl: URL,
                            shouldFlipHorizontally: Bool = false) {
        
        let mixComposition = AVMutableComposition()
        var mutableCompositionVideoTrack = [AVMutableCompositionTrack]()
        var mutableCompositionAudioTrack = [AVMutableCompositionTrack]()
        var mutableCompositionAudioOfVideoTrack = [AVMutableCompositionTrack]()
        
        //start merge
        
        let videoAsset = AVURLAsset.init(url: videoUrl, options: [AVURLAssetPreferPreciseDurationAndTimingKey : true])
        let audioAsset = AVURLAsset.init(url: audioUrl, options: [AVURLAssetPreferPreciseDurationAndTimingKey : true])
        
        let compositionAddVideo = mixComposition.addMutableTrack(withMediaType: .video,
                                                                 preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let compositionAddAudio = mixComposition.addMutableTrack(withMediaType: .audio,
                                                                 preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let compositionAddAudioOfVideo = mixComposition.addMutableTrack(withMediaType: .audio,
                                                                        preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let aVideoAssetTrack: AVAssetTrack = videoAsset.tracks(withMediaType: .video)[0]
        let aAudioOfVideoAssetTrack: AVAssetTrack? = videoAsset.tracks(withMediaType: .audio).first
        let aAudioAssetTrack: AVAssetTrack = audioAsset.tracks(withMediaType: .audio)[0]
        
        // Default must have tranformation
        
        compositionAddVideo!.preferredTransform = aVideoAssetTrack.preferredTransform
        
        if shouldFlipHorizontally {
            // Flip video horizontally
            var frontalTransform: CGAffineTransform = CGAffineTransform(scaleX: -1.0, y: 1.0)
            frontalTransform = frontalTransform.translatedBy(x: -aVideoAssetTrack.naturalSize.width, y: 0.0)
            frontalTransform = frontalTransform.translatedBy(x: 0.0, y: -aVideoAssetTrack.naturalSize.width)
            compositionAddVideo!.preferredTransform = frontalTransform
        }
        
        mutableCompositionVideoTrack.append(compositionAddVideo!)
        mutableCompositionAudioTrack.append(compositionAddAudio!)
        mutableCompositionAudioOfVideoTrack.append(compositionAddAudioOfVideo!)
        
        do {
            try mutableCompositionVideoTrack[0].insertTimeRange(CMTimeRangeMake(start: CMTime.zero,
                                                                                duration: aVideoAssetTrack.timeRange.duration),
                                                                of: aVideoAssetTrack,
                                                                at: CMTime.zero)
            
            //In my case my audio file is longer then video file so i took videoAsset duration
            //instead of audioAsset duration
            try mutableCompositionAudioTrack[0].insertTimeRange(CMTimeRangeMake(start: CMTime.zero,
                                                                                duration: aVideoAssetTrack.timeRange.duration),
                                                                of: aAudioAssetTrack,
                                                                at: CMTime.zero)
            
            // adding audio (of the video if exists) asset to the final composition
            if let aAudioOfVideoAssetTrack = aAudioOfVideoAssetTrack {
                try mutableCompositionAudioOfVideoTrack[0].insertTimeRange(CMTimeRangeMake(start: CMTime.zero,
                                                                                           duration: aVideoAssetTrack.timeRange.duration),
                                                                           of: aAudioOfVideoAssetTrack,
                                                                           at: CMTime.zero)
            }
        } catch {
            print(error)
        }
        
        // Exporting
        let savePathUrl = tempURL(for: ".mov")
        export(from: mixComposition, preset: AVAssetExportPresetHighestQuality, outputType: .mov, savePathUrl: savePathUrl!) { [unowned self] (error, url) in
            if error != nil {
                print(error!)
            }
            
            self.delegate?.videoManager(didFinishMergingTo: url ?? videoUrl)
        }
    }
    
    func export(from mixComposition: AVMutableComposition, preset: String, outputType: AVFileType, savePathUrl: URL, completion: @escaping (_ error: Error?, _ url: URL?) -> Void) {
        let exporter = AVAssetExportSession.init(asset: mixComposition, presetName: preset)!
        
        exporter.outputFileType = outputType
        exporter.outputURL = savePathUrl
        exporter.shouldOptimizeForNetworkUse = true
        
        exporter.exportAsynchronously { () -> Void in
            switch exporter.status {
            case .completed:
                print("successfully exported.")
                completion(nil, savePathUrl)
            case .failed:
                print("failed \(String(describing: exporter.error))")
                completion(exporter.error, nil)
            case .cancelled:
                print("cancelled \(String(describing: exporter.error))")
                completion(exporter.error, nil)
            default:
                print("complete")
                completion(exporter.error, nil)
            }
        }
        
    }
}
