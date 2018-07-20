//
//  ButtonTableViewCell.swift
//  pretixios
//
//  Created by Marc Delling on 20.09.17.
//  Copyright © 2017 Silpion IT-Solutions GmbH. All rights reserved.
//

import UIKit

protocol ButtonCellDelegate {
    func buttonTableViewCell(_ cell: ButtonTableViewCell, action: UIButton)
}

class ButtonTableViewCell: UITableViewCell {

    let button = UIButton(type: UIButtonType.system)
    var delegate : ButtonCellDelegate?
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    var title : String? {
        get {
            return button.titleLabel?.text
        }
        set {
            button.setTitle(newValue, for: .normal)
        }
    }
    
    fileprivate func setup() {
        self.selectionStyle = .none

        let color = UIColor.lightBlue
        
        button.titleLabel?.font = UIFont(name: "HelveticaNeue", size: 16.0)
        button.setTitleColor(color, for: .normal)
        button.setTitleColor(color, for: .selected)
        button.setTitleColor(color, for: .highlighted)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
        
        self.contentView.addSubview(button)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: self.contentView.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 200)
        ])
        
    }

    @objc fileprivate func buttonAction() {
        delegate?.buttonTableViewCell(self, action: self.button)
    }
}
