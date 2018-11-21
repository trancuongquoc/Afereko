//
//  PlaybackController.swift
//  Afureko
//
//  Created by Quoc Cuong on 11/5/18.
//  Copyright © 2018 Quoc Cuong. All rights reserved.
//

import UIKit
import AVFoundation

class PlaybackController: UIViewController {
    
    @IBOutlet weak var rangeSlider: AMVideoRangeSlider!
    @IBOutlet weak var videoView: VideoView!
    @IBOutlet weak var nextButton: UIBarButtonItem!
    @IBOutlet weak var backButton: UIBarButtonItem!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    weak var videoManager: VideoManager!
    
    var outputVideoURLs = [URL]()
    
    var afterMergedOutputURL: URL!
    
    var mergeTask: DispatchWorkItem!
    
    var videoDuration: Float64 = 0 {
        didSet {
            if videoDuration > 20.00 {
                videoDuration = 20.00
            }
            
            DispatchQueue.main.async { [unowned self] in
                self.durationLabel.text = self.videoDuration.intoString()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if !outputVideoURLs.isEmpty {
            //An alert shows up to ask users how they wanna merge these videos.
            mergeFileRequest()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prepare()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerItemDidReachEnd),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                               object: nil)
    }
    
    func prepare() {
        func setup() {
            videoManager = VideoManager()
            videoManager.delegate = self
            videoView.delegate = self
            rangeSlider.delegate = self
            
            // To set stoptime after unwind from recordingAudioVC.
            if let url = afterMergedOutputURL {
                let videoAsset = AVURLAsset.init(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
                videoManager.setStopTime(value: videoAsset.duration)
            }
        }
        
        func disableUserInteraction() {
            videoView.enableUserInteractions = false
            disableUserInteractions(for: nil, barButtons: [self.nextButton])
        }
        
        // Prepare to playback after unwind from RecordAudioController
        // afterMergedOutputURL should not be nil here tks to unwind function.
        func configureAVPlayer() {
            if afterMergedOutputURL != nil {
                self.view.lock(with: "Loading")
                
                videoManager.configure(with: afterMergedOutputURL, within: videoView) { [unowned self] (completed) in
                    if completed {
                        // Once done configuring, get a thumbnail.
                        self.afterMergedOutputURL.thumbnailImage(at: 0.0, completion: { [unowned self] (image) in
                            self.videoView.thumbnailImage = image
                        })
                        
                        self.view.unlock()
                        self.videoView.enableUserInteractions = true
                        enableUserInteractions(for: nil, barButtons: [self.nextButton])
                    }
                }
            }
        }
        
        setup()
        disableUserInteraction()
        syncProgressAndDurationLabel()
        configureAVPlayer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        videoManager.pause()
        DispatchQueue.global(qos: .background).sync {
            //Here we remove files (if existed) at URL.
            cleanup()
            videoManager.cleanup()
        }
    }
    
    @IBAction func backButtonHandle(_ sender: UIBarButtonItem) {
        showAlert(title: "Leave?", message: "Any data recorded would be erased. Are you sure?", actionTitles: ["Sure", "No"], actions: [{ [unowned self] (leave) in
            if let workItem = self.mergeTask, !workItem.isCancelled {
                workItem.cancel()
            }
            
            self.afterMergedOutputURL.removeItemIfExisted()
            
            self.navigationController?.popViewController(animated: true)
            }, nil])
    }
    
    @IBAction func nextButtonHandle(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "toRecordAudio", sender: afterMergedOutputURL)
    }
    
    @IBAction func unwindToPlayback(sender: UIStoryboardSegue) {
        if let source = sender.source as? RecordingAudioController, let originalVideoURL = source.originalVideoURL {
            afterMergedOutputURL = originalVideoURL
        }
    }
    
    // Triggered when video reached the end.
    @objc func playerItemDidReachEnd() {
        videoManager.isPlaying = false
        videoManager.avPlayer.seek(to: .zero)
        DispatchQueue.main.async { [unowned self] in
            self.videoView.playButton.alpha = 1
        }
    }
    
    func merge(with option: MergeOption) {
        self.view.lock(with: "Merging")
        
        mergeTask = DispatchWorkItem { [unowned self] in
            guard let workItem = self.mergeTask, !workItem.isCancelled else {
                print("cancelled")
                return
            }
            self.videoManager.mergeAllVideos(with: self.outputVideoURLs, option: option)
        }
        
        DispatchQueue.global(qos: .utility).sync(execute: mergeTask)
    }
    
    func cleanup() {
        if !outputVideoURLs.isEmpty {
            for url in outputVideoURLs {
                url.removeItemIfExisted()
            }
        }
        
        mergeTask = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "toRecordAudio" {
            let destination = segue.destination as! RecordingAudioController
            destination.originalVideoURL = (sender as! URL)
        }
    }
    
    func syncProgressAndDurationLabel() {
        guard let url = afterMergedOutputURL else { return }
        videoDuration = url.videoDuration
        DispatchQueue.main.async { [unowned self] in
            self.progressLabel.text = "0.00"
        }
    }
    
    func mergeFileRequest() {
        showAlert(title: "Hello!", message: "How do you wannna merge these one?", actionTitles: ["With audio", "Without audio"],
                  actions: [{ [unowned self] (mergerWithAudio) in
                    self.merge(with: .withOriginalAudio)
                    }, { [unowned self] (mergerWithoutAudio) in
                        self.merge(with: .withoutAudio)
                    }])
    }
}

extension PlaybackController: VideoViewDelegate { //MARK: - VideoViewDelegate
    func videoViewDidRecognizeTapGesture() {
        switch videoManager.isPlaying {
        case true:
            videoManager.pause()
        case false:
            videoManager.play(option: .withTimeObserver, timeLimited: true)
        }
    }
}

extension PlaybackController: VideoManagerDelegate { //MARK: - VideoManagerDelegate
    func videoManager(didUpdatePlaybackTimeTo value: CMTime) {
        let secondUnit = CMTimeGetSeconds(value)
        DispatchQueue.main.async { [unowned self] in
            self.progressLabel.text = secondUnit.intoString()
        }
    }
    
    func videoManager(didFinishMergingTo url: URL) {
        afterMergedOutputURL = url
        
        let videoAsset = AVURLAsset.init(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        videoManager.setStopTime(value: videoAsset.duration)
        
        view.lock(with: "Merging")
        
        //Once done merging, setup everything again.
        videoManager.configure(with: url, within: videoView) { (completed) in
            if completed {
                url.thumbnailImage(at: 0.0, completion: { [unowned self] (image) in
                    self.videoView.thumbnailImage = image
                })
                
                self.syncProgressAndDurationLabel()
                
                self.view.unlock()
                DispatchQueue.main.async { [unowned self] in
                    self.videoView.playButton.alpha = 1.0
                }
                
                enableUserInteractions(for: nil, barButtons: [self.nextButton])
                self.videoView.enableUserInteractions = true
                self.rangeSlider.videoAsset = videoAsset
            }
        }
    }
}

extension PlaybackController: AMVideoRangeSliderDelegate {
    func rangeSliderLowerThumbValueChanged(value: CMTime) {
        videoManager.setStartTime(value: value)
        
        DispatchQueue.main.async { [unowned self] in
            self.videoView.thumbnailImageView.isHidden = true
        }
    }
    
    func rangeSliderUpperThumbValueChanged(value: CMTime) {
        videoManager.setStopTime(value: value)
        
        // Here we update new video's duration
        DispatchQueue.main.async { [unowned self] in
            let secondsUnit = Float64(value.seconds)
            self.durationLabel.text = secondsUnit.intoString()
        }
    }
}
