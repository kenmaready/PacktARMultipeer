//
//  RoundedButton.swift
//  PacktARMultipeer
//
//  Created by Ken Maready on 9/28/22.
//

import UIKit

@IBDesignable
class RoundedButton: UIButton {
    override var isEnabled: Bool {
        didSet {
            backgroundColor = isEnabled ? tintColor: .gray
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    func setup() {
        backgroundColor = tintColor
        layer.cornerRadius = 8
        clipsToBounds = true
        setTitleColor(.white, for: .normal)
        titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
    }
}
