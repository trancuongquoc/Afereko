//
//  Protocols.swift
//  Afureko
//
//  Created by Quoc Cuong on 11/9/18.
//  Copyright © 2018 Quoc Cuong. All rights reserved.
//

import Foundation
import AVFoundation

enum MergeOption {
    case withOriginalAudio
    case withoutAudio
}

protocol VideoManagerDelegate: class {
    func videoManager(didFinishMergingTo url: URL)
    
    func videoManager(didUpdatePlaybackTimeTo value: CMTime)
}

extension VideoManagerDelegate {
    func videoManager(didFinishMergingTo url: URL) { }
    
    func videoManager(didUpdatePlaybackTimeTo value: CMTime) { }
}

