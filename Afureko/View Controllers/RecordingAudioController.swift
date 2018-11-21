//
//  RecordingAudioController.swift
//  Afureko
//
//  Created by Quoc Cuong on 11/6/18.
//  Copyright © 2018 Quoc Cuong. All rights reserved.
//

import UIKit
import AVFoundation

class RecordingAudioController: UIViewController {
    
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var backButton: UIBarButtonItem!
    @IBOutlet weak var videoView: VideoView!
    @IBOutlet weak var nextButton: UIBarButtonItem!
    @IBOutlet weak var recordButton: UIButton!
    
    var originalVideoURL: URL!
    var afterMergedVideoURL: URL!
    var audioOutputURL: URL!
    
    weak var videoManager: VideoManager!
    weak var audioManager: AudioManager!
    
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
    
    var mergeTask: DispatchWorkItem!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prepare()
    }
    
    func prepare() {
        func setup() {
            videoManager = VideoManager()
            videoManager.delegate = self
            
            audioManager = AudioManager()
            audioManager.delegate = self
            
            progressBar.setProgress(0, animated: false)
        }
        
        func disableUserInteraction() {
            disableUserInteractions(for: nil, barButtons: [self.nextButton])
            videoView.enableUserInteractions = false
        }
        
        func configureAVPlayer() {
            if originalVideoURL != nil {
                view.lock(with: "Merging")
                
                videoManager.configure(with: originalVideoURL, within: videoView) { [unowned self] (completed) in
                    if completed {
                        // Once done configuring, get a thumbnail.
                        self.originalVideoURL.thumbnailImage(at: 0.0, completion: { [unowned self] (image) in
                            self.videoView.thumbnailImage = image
                        })
                        
                        self.view.unlock()
                        enableUserInteractions(for: [self.recordButton], barButtons: nil)
                    }
                }
            }
        }
        
        func configureAudioRecorder() {
            audioManager.configure { (error) in
                if error != nil {
                    print(error!)
                }
            }
        }
        
        func configureMaximumRecordingDuration() {
            guard let url = originalVideoURL else { return }
            videoDuration = url.videoDuration
            audioManager.setMaximumRecordingDuration(to: videoDuration)
            DispatchQueue.main.async { [unowned self] in
                self.progressLabel.text = "0.00"
            }
        }
        
        setup()
        disableUserInteraction()
        configureAVPlayer()
        configureAudioRecorder()
        configureMaximumRecordingDuration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        videoManager.cleanup()
        audioManager.cleanup()
        cleanup()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toAfterRecording" {
            let destination = segue.destination as! AfterRecordingController
            destination.finalVideoURL = sender as! URL
        }
    }
    
    func cleanup() {
        mergeTask = nil
        if audioOutputURL != nil {
            audioOutputURL.removeItemIfExisted()
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    deinit {
        print("RecordingAudioController got deinit.")
    }
    
    //MARK: - IBAction
    @IBAction func RecordButtonTouchUpInside(_ sender: UIButton) {
        self.audioManager.startRecording()
        
        DispatchQueue.main.async { [unowned self] in
            if self.audioManager.isRecording {
                self.recordButton.setImage(UIImage(named: "recording"), for: .normal)
                self.videoManager.play()
            } else {
                self.recordButton.setImage(UIImage(named: "record"), for: .normal)
                self.videoManager.pause()
            }
        }
            videoView.handleTapOnView()
            disableUserInteractions(for: nil, barButtons: [backButton])
    }
    
    @IBAction func backButtonHandle(_ sender: UIBarButtonItem) {
        showAlert(title: "Leave?", message: "Any data recorded would be erased. Are you sure?", actionTitles: ["Sure", "No"], actions: [{ [unowned self] (leave) in
            if let workItem = self.mergeTask, !workItem.isCancelled {
                workItem.cancel()
            }
            
            if self.afterMergedVideoURL != nil {
                self.afterMergedVideoURL.removeItemIfExisted()
            }
            
            self.performSegue(withIdentifier: "unwindToPlayback", sender: nil)
            }, nil])
    }
    
    @IBAction func nextButtonHandle(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "toAfterRecording", sender: afterMergedVideoURL)
    }
    
    func merge(videoWith audioURL: URL) {
        view.lock(with: "Merging")
        
        mergeTask = DispatchWorkItem { [unowned self] in
            guard let workItem = self.mergeTask, !workItem.isCancelled else {
                print("cancelled")
                return
            }
            self.videoManager.mergeVideoAndAudio(videoUrl: self.originalVideoURL, audioUrl: audioURL)
        }
        
        DispatchQueue.global(qos: .utility).sync(execute: mergeTask)
    }
}

extension RecordingAudioController: AudioManagerDelegate { //MARK: - AudioManagerDelegate
    func audioManager(didUpdateRecordingTimeTo newValue: Float64) {
        let secondsInString = String(format: "%.02f", newValue)
        let progressValue = Float(newValue / audioManager.maximumRecordingDuration)
        
        DispatchQueue.main.async { [unowned self] in
            self.progressLabel.text = secondsInString
            self.progressBar.setProgress(progressValue, animated: true)
        }
    }
    
    func audioManager(didFinishRecordingAudioTo outputAudioURL: URL) {
        DispatchQueue.main.async { [unowned self] in
            self.recordButton.setImage(UIImage(named: "record"), for: .normal)
        }
        
        audioOutputURL = outputAudioURL
        
        disableUserInteractions(for: [recordButton], barButtons: nil)
        
        showAlert(title: "Done recording!", message: "Merge, now?", actionTitles: ["Yes", "No"], actions: [
            { [unowned self] (merge) in
                self.merge(videoWith: outputAudioURL)
            },
            { [unowned self] (no) in
                enableUserInteractions(for: nil, barButtons: [self.nextButton])
            }])
        
        enableUserInteractions(for: nil, barButtons: [self.backButton])
    }
}

extension RecordingAudioController: VideoManagerDelegate { //MARK: - VideoManagerDelegate
    func videoManager(didFinishMergingTo url: URL) {
        if url == originalVideoURL {
            showAlert(title: "Failed", message: "Something went wrong! Failed to merge.", actionTitles: ["Close"], actions: [nil])
        } else {
            afterMergedVideoURL = url
        }
        view.unlock()
        enableUserInteractions(for: nil, barButtons: [self.nextButton])
    }
}
