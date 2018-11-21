//
//  VideoView.swift
//  Afureko
//
//  Created by Quoc Cuong on 11/5/18.
//  Copyright © 2018 Quoc Cuong. All rights reserved.
//

import UIKit
import AVFoundation

protocol VideoViewDelegate: class {
    func videoViewDidRecognizeTapGesture()
}

class VideoView: UIView {
    
    weak var delegate: VideoViewDelegate?
    
    var thumbnailImage: UIImage? {
        didSet {
            DispatchQueue.main.async { [unowned self] in
                self.thumbnailImageView.image = self.thumbnailImage?.resize(with: self.frame.size)
            }
        }
    }
    
    var state: Bool = false {
        didSet {
            syncPlayButtonAppearance()
        }
    }
    
    var enableUserInteractions = true {
        didSet {
            if enableUserInteractions {
                DispatchQueue.main.async { [unowned self] in
                    self.isUserInteractionEnabled = true
                    self.playButton.isUserInteractionEnabled = true
                }
            } else {
                DispatchQueue.main.async { [unowned self] in
                    self.isUserInteractionEnabled = false
                    self.playButton.isUserInteractionEnabled = false
                }
            }
        }
    }
    
    private func syncPlayButtonAppearance() {
        self.playButton.fadeIn(0.5)
        if self.state {
            setPlayButtonImage(with: "pause")
        } else {
            setPlayButtonImage(with: "play")
        }
        self.playButton.fadeOut(1)
        
    }
    
    private func setPlayButtonImage(with imageLiteral: String) {
        DispatchQueue.main.async { [unowned self] in
            self.playButton.setImage(UIImage(named: imageLiteral), for: .normal)
        }
    }
    
    lazy var playButton: UIButton = {
        let button = UIButton(type: UIButton.ButtonType.system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "play"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(handleTapOnView), for: .touchUpInside)
        return button
    }()
    
    lazy var thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        thumbnailImageView.put(inCenterOf: self)
        playButton.put(inCenterOf: self, widthConstant: 50, heightConstant: 50)
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleTapOnView))
        singleTap.numberOfTapsRequired = 1
        self.addGestureRecognizer(singleTap)
        
        DispatchQueue.main.async { [unowned self] in
            self.isUserInteractionEnabled = true
            self.playButton.isHidden = false
        }
    }
    
    @objc func handleTapOnView() {
        state = !state
        delegate?.videoViewDidRecognizeTapGesture()
        DispatchQueue.main.async { [unowned self] in
            self.thumbnailImageView.isHidden = true
        }
    }
}
