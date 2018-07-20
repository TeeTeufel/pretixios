//
//  GuestTableViewController.swift
//  pretixios
//
//  Created by Marc Delling on 18.09.17.
//  Copyright © 2017 Silpion IT-Solutions GmbH. All rights reserved.
//

import UIKit

class DetailTableViewController: UITableViewController, ButtonCellDelegate {

    var order: Order?
    
    convenience init() {
        self.init(style: .grouped)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.rowHeight = 44;
        self.tableView.register(TextFieldTableViewCell.self, forCellReuseIdentifier: "textInputCell")
        self.tableView.register(LabelTableViewCell.self, forCellReuseIdentifier: "labelCell")
        self.tableView.register(ButtonTableViewCell.self, forCellReuseIdentifier: "buttonCell")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.title = order?.attendee_name
    }

    // MARK: - Table view data source

    enum Sections : Int {
        case Personal
        case Additional
        case Status
        case Save
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch(Sections(rawValue: section)!) {
        case .Personal:
            return 2
        case .Additional:
            return 1
        case .Status:
            return 6
        case .Save:
            if let _ = order?.checkin {
                return 0
            } else {
                return 1
            }
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
       
        switch(Sections(rawValue: indexPath.section)!, indexPath.row) {
            
        case(.Personal, 0):
            let cell = tableView.dequeueReusableCell(withIdentifier: "textInputCell", for: indexPath) as! TextFieldTableViewCell
            cell.label.text = NSLocalizedString("Name", comment: "")
            cell.textField.text = order?.attendee_name
            return cell
        case(.Personal, 1):
            let cell = tableView.dequeueReusableCell(withIdentifier: "textInputCell", for: indexPath) as! TextFieldTableViewCell
            cell.label.text = NSLocalizedString("Email", comment: "")
            cell.type = .email
            cell.textField.text = order?.attendee_email
            return cell
        
        case(.Additional, 0):
            let cell = tableView.dequeueReusableCell(withIdentifier: "textInputCell", for: indexPath) as! TextFieldTableViewCell
            cell.label.text = NSLocalizedString("Company", comment: "")
            cell.textField.text = order?.company
            return cell
            
        case(.Status, 0):
            let cell = tableView.dequeueReusableCell(withIdentifier: "labelCell", for: indexPath) as! LabelTableViewCell
            cell.label.text = NSLocalizedString("Status", comment: "")
            if let status = order?.status {
                switch(status) {
                case .n:
                    cell.valueLabel.text = NSLocalizedString("Pending", comment: "")
                case .p:
                    cell.valueLabel.text = NSLocalizedString("Paid", comment: "")
                case .e:
                    cell.valueLabel.text = NSLocalizedString("Expired", comment: "")
                case .c:
                    cell.valueLabel.text = NSLocalizedString("Canceled", comment: "")
                case .r:
                    cell.valueLabel.text = NSLocalizedString("Refunded", comment: "")
                }
            }
            return cell
        case(.Status, 1):
            let cell = tableView.dequeueReusableCell(withIdentifier: "labelCell", for: indexPath) as! LabelTableViewCell
            cell.label.text = NSLocalizedString("Order", comment: "")
            cell.valueLabel.text = order?.guid
            return cell
        case(.Status, 2):
            let cell = tableView.dequeueReusableCell(withIdentifier: "labelCell", for: indexPath) as! LabelTableViewCell
            cell.label.text = NSLocalizedString("Type", comment: "")
            cell.accessoryType = .none
            cell.selectionStyle = .none
            if let order = order {
                if let variation = order.variation {
                     cell.valueLabel.text = "\(order.item) - \(variation)"
                } else {
                     cell.valueLabel.text = NSLocalizedString("\(order.item) - Standard", comment: "")
                }
            }
            return cell
        case(.Status, 3):
            let cell = tableView.dequeueReusableCell(withIdentifier: "labelCell", for: indexPath) as! LabelTableViewCell
            cell.label.text = NSLocalizedString("Checkin", comment: "")
            cell.accessoryType = .none
            cell.selectionStyle = .none
            cell.valueLabel.text = order?.checkin?.shortTimeString()
            return cell
        case(.Status, 4):
            let cell = tableView.dequeueReusableCell(withIdentifier: "labelCell", for: indexPath) as! LabelTableViewCell
            cell.label.text = NSLocalizedString("Created", comment: "")
            cell.valueLabel.text = order?.datetime?.longTimeString()
            cell.accessoryType = .none
            cell.selectionStyle = .none
            return cell
        case(.Status, 5):
            let cell = tableView.dequeueReusableCell(withIdentifier: "labelCell", for: indexPath) as! LabelTableViewCell
            cell.label.text = NSLocalizedString("Invitation", comment: "")
            if let voucher = order?.voucher {
                cell.valueLabel.text = "\(voucher)"
            } else  {
                cell.valueLabel.text = NSLocalizedString("None", comment: "")
            }
            cell.accessoryType = .none
            cell.selectionStyle = .none
            return cell
            
        case(.Save, 0):
            let cell = tableView.dequeueReusableCell(withIdentifier: "buttonCell", for: indexPath) as! ButtonTableViewCell
            cell.title = NSLocalizedString("Redeem", comment: "")
            cell.delegate = self
            return cell
            
        default:
            return tableView.dequeueReusableCell(withIdentifier: "labelCell", for: indexPath)
        }
        
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch(Sections(rawValue: section)!) {
        case .Personal:
            return NSLocalizedString("Personal Data", comment: "")
        case .Additional:
            return NSLocalizedString("Additional Info", comment: "")
        case .Status:
            return NSLocalizedString("Status", comment: "")
        default: return ""
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch(Sections(rawValue: indexPath.section)!, indexPath.row) {
        case(.Status,0):
            let statusViewController = StatusTableViewController()
            statusViewController.order = order
            self.navigationController?.pushViewController(statusViewController, animated: true)
        case(.Status,1):
            let qrViewController = QrDisplayViewController()
            qrViewController.qrstring = order?.secret
            self.navigationController?.pushViewController(qrViewController, animated: true)
        default: ()
        }
    }
    
    // MARK : - ButtonCellDelegate
    
    func buttonTableViewCell(_ cell: ButtonTableViewCell, action: UIButton) {
        
        if let order = order {
            order.checkin = Date()
            order.synced = -1
            SyncManager.sharedInstance.save()
            
            NetworkManager.sharedInstance.postPretixRedeem(order: order) { (response, error) in
                
                DispatchQueue.main.async {
                    
                    var title : String?
                    var message : String?
                    
                    if let error = error {
                        title = NSLocalizedString("Network error", comment: "")
                        message = error.localizedDescription
                    } else if let response = response, let reason = response.reason {
                        title = NSLocalizedString("Redeem " + response.status.rawValue, comment: "")
                        switch(reason){
                        case .unpaid:
                            message = NSLocalizedString("Unpaid", comment: "")
                            break
                        case .product:
                            message = NSLocalizedString("Product", comment: "")
                            break
                        case .already_redeemed:
                            message = NSLocalizedString("Already redeemed", comment: "")
                            break
                        }
                    }
                    
                    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true)
                    
                    self.tableView.reloadData()
                }
            }
            
        }
    }
    
}
