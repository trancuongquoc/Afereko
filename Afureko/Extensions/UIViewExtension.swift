//
//  VideoView.swift
//  Afureko
//
//  Created by Quoc Cuong on 11/5/18.
//  Copyright © 2018 Quoc Cuong. All rights reserved.
//


import UIKit

extension UIView {
    
    func lock(with text: String) {
        DispatchQueue.main.async { [unowned self] in
            if let _ = self.viewWithTag(10) {
                //View is already locked
            }
            else {
                let lockView = UIView(frame: self.bounds)
                lockView.backgroundColor = UIColor(white: 0.0, alpha: 0.75)
                lockView.tag = 10
                lockView.alpha = 0.0
                let activity = UIActivityIndicatorView(style: .white)
                activity.hidesWhenStopped = true
                activity.center = lockView.center
                
                let originX = activity.frame.origin.x + activity.bounds.width + 8
                let message = UILabel(frame: CGRect(x: originX, y: activity.frame.origin.y, width: 60, height: activity.bounds.height))
                message.text = text
                message.textColor = .lightGray
                message.font = UIFont.systemFont(ofSize: 14)
                
                lockView.addSubview(activity)
                lockView.addSubview(message)
                
                activity.startAnimating()
                self.addSubview(lockView)
                
                
                UIView.animate(withDuration: 0.2, animations: {
                    lockView.alpha = 1.0
                })
                
            }
        }
    }
    
    func unlock() {
        DispatchQueue.main.async { [unowned self] in
            if let lockView = self.viewWithTag(10) {
                UIView.animate(withDuration: 0.2, animations: {
                    lockView.alpha = 0.0
                }, completion: { finished in
                    lockView.removeFromSuperview()
                })
            }
        }
    }
    
    func fadeOut(_ duration: TimeInterval) {
        DispatchQueue.main.async {
            UIView.animate(withDuration: duration, animations: {
                self.alpha = 0.0
            })
        }
    }
    
    func fadeIn(_ duration: TimeInterval) {
        DispatchQueue.main.async {
            UIView.animate(withDuration: duration, animations: {
                self.alpha = 1.0
            })
        }
    }
    
    class func viewFromNibName(_ name: String) -> UIView? {
        let views = Bundle.main.loadNibNamed(name, owner: nil, options: nil)
        return views?.first as? UIView
    }
    
    func put(inCenterOf containerView: UIView, widthConstant: CGFloat = 0, heightConstant: CGFloat = 0) {
        containerView.addSubview(self)
        self.centerXAnchor.constraint(equalTo: containerView.centerXAnchor).isActive = true
        self.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        
        if widthConstant != 0 {
            self.widthAnchor.constraint(equalToConstant: widthConstant).isActive = true
        } else {
            self.widthAnchor.constraint(equalTo: containerView.widthAnchor).isActive = true
        }
        
        if heightConstant != 0 {
            self.heightAnchor.constraint(equalToConstant: heightConstant).isActive = true
        } else {
            self.heightAnchor.constraint(equalTo: containerView.heightAnchor).isActive = true
        }
    }
    
}

