//
//  SessionEntryTableViewCell.swift
//  SessionEntryTableViewCell
//
//  Created by Daniel Torres on 29/8/21.
//

import UIKit

class SessionEntryTableViewCell: UITableViewCell {
    
    @IBOutlet weak var sessionImage: UIImageView!
    @IBOutlet weak var sessionTime: UILabel!
    @IBOutlet weak var sessionDate: UILabel!
    @IBOutlet weak var sessionDuration: UILabel!
    

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
