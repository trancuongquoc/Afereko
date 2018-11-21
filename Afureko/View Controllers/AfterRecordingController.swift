//
//  AfterRecordingController.swift
//  Afureko
//
//  Created by Quoc Cuong on 11/9/18.
//  Copyright © 2018 Quoc Cuong. All rights reserved.
//

import UIKit
import AVFoundation

class AfterRecordingController: UIViewController {
    
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var videoView: VideoView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var popToRootButton: UIButton!
    
    weak var videoManager: VideoManager!
    
    var finalVideoURL: URL!
    
    var videoDuration: Float64 = 0 {
        didSet {
            if videoDuration > 20.00 {
                videoDuration = 20.00
            }
            
            DispatchQueue.main.async { [unowned self] in
                self.durationLabel.text = "/" + self.videoDuration.intoString()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prepare()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerItemDidReachEnd),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                               object: nil)
        PhotoAlbum.shared.checkPermission()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        videoManager.pause()
        cleanup()
    }
    
    func syncTrackingTime() {
        guard let url = finalVideoURL else { return }
        videoDuration = url.videoDuration
        DispatchQueue.main.async { [unowned self] in
            self.progressLabel.text = "0.00"
        }
    }
    
    func prepare() {
        func setup() {
            videoManager = VideoManager()
            videoManager.delegate = self
            videoView.delegate = self
            
            self.progressBar.setProgress(0, animated: false)
        }
        
        func disableUserInteraction() {
            videoView.enableUserInteractions = false
        }
        
        // Prepare to playback after unwind from RecordAudioController
        // afterMergedOutputURL should not be nil here tks to unwind function.
        func configureAVPlayer() {
            if finalVideoURL != nil {
                view.lock(with: "Loading")
                
                videoManager.configure(with: finalVideoURL, within: videoView) { [unowned self] (completed) in
                    if completed {
                        // Once done configuring, get a thumbnail.
                        self.finalVideoURL.thumbnailImage(at: 0.0, completion: { [unowned self] (image) in
                            self.videoView.thumbnailImage = image
                        })
                        
                        self.view.unlock()
                        self.videoView.enableUserInteractions = true
                    }
                }
            }
        }
        
        setup()
        disableUserInteraction()
        syncTrackingTime()
        configureAVPlayer()
    }
    
    @objc func playerItemDidReachEnd() {
        videoManager.isPlaying = false
        videoManager.avPlayer.seek(to: .zero)
        DispatchQueue.main.async { [unowned self] in
            self.videoView.playButton.alpha = 1
        }
    }
    
    func cleanup() {
        NotificationCenter.default.removeObserver(self)
        if finalVideoURL != nil {
            finalVideoURL.removeItemIfExisted()
        }
    }
}

extension AfterRecordingController {
    @IBAction func saveButtonHandle(_ sender: Any) {
        videoManager.pause()
        view.lock(with: "Saving")
        guard let url = finalVideoURL else { return }
        PhotoAlbum.shared.save(videoURL: url, toAlbum: "AfterRecording") { (success, error) in
            if error != nil {
                print(error!)
            }
            
            if success {
                self.view.unlock()
                showAlert(title: "Saved", message: "Successfully saved to camera roll.", actionTitles: ["Ok"], actions: [nil])
                DispatchQueue.global(qos: .background).async {
                    url.removeItemIfExisted()
                }
            }
        }
        
    }
    
    @IBAction func backtoRootButtonHandle(_ sender: UIButton) {
        showAlert(title: "Leave?", message: "Any data recorded would be erased. Are you sure?", actionTitles: ["Sure", "No"], actions: [{ (sure) in
            self.navigationController?.popToRootViewController(animated: true)
            }, nil])
    }
}

extension AfterRecordingController: VideoViewDelegate {
    func videoViewDidRecognizeTapGesture() {
        switch videoManager.isPlaying {
        case true:
            videoManager.pause()
        case false:
            videoManager.play(option: .withTimeObserver)
        }
    }
}

extension AfterRecordingController: VideoManagerDelegate {
    func videoManager(didUpdatePlaybackTimeTo value: CMTime) {
        let secondUnit = CMTimeGetSeconds(value)
        let progressValue = Float(secondUnit / videoDuration)
        DispatchQueue.main.async { [unowned self] in
            self.progressLabel.text = secondUnit.intoString()
            self.progressBar.setProgress(progressValue, animated: true)
        }
    }
}
