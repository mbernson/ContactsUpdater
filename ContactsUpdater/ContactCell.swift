//
//  ContactCell.swift
//  ContactsUpdater
//
//  Created by Mathijs Bernson on 29/04/2019.
//  Copyright © 2019 Q42. All rights reserved.
//

import UIKit

protocol ContactCellDelegate: class {
  func didAccept(image: Data, for contact: Contact)
  func didReject(image: Data, for contact: Contact)
}

class ContactCell: UITableViewCell {
  static let reuseIdentifier = "ContactCell"

  weak var delegate: ContactCellDelegate?

  @IBOutlet weak var nameLabel: UILabel!
  @IBOutlet weak var emailAddressLabel: UILabel!
  @IBOutlet weak var oldImageView: UIImageView!
  @IBOutlet weak var newImageView: UIImageView!

  struct ViewModel {
    let contact: Contact
    var existingImage: Data?
    var newImage: Data?
  }

  var viewModel: ViewModel? { didSet { applyViewModel() } }

  private func applyViewModel() {
    nameLabel.text = viewModel?.contact.name
    emailAddressLabel.text = viewModel?.contact.emailAddresses.first

    if let existingImage = viewModel?.existingImage, let image = UIImage(data: existingImage) {
      oldImageView.image = image
    } else {
      oldImageView.image = UIImage(named: "placeholder")
    }

    if let newImage = viewModel?.newImage, let image = UIImage(data: newImage) {
      newImageView.image = image
    } else {
      newImageView.image = UIImage(named: "placeholder")
    }
  }

  override func awakeFromNib() {
    super.awakeFromNib()

    oldImageView.layer.cornerRadius = oldImageView.frame.width / 2
    oldImageView.layer.masksToBounds = true
    newImageView.layer.cornerRadius = newImageView.frame.width / 2
    newImageView.layer.masksToBounds = true
  }

  @IBAction func acceptButtonTouched(_ sender: UIButton) {
    guard let contact = viewModel?.contact, let newImage = viewModel?.newImage else {
      return
    }

    delegate?.didAccept(image: newImage, for: contact)
  }

  @IBAction func rejectButtonTouched(_ sender: UIButton) {
    guard let contact = viewModel?.contact, let newImage = viewModel?.newImage else {
      return
    }

    delegate?.didReject(image: newImage, for: contact)
  }
}
