//
//  ContactListController.swift
//  ContactsUpdater
//
//  Created by Mathijs Bernson on 29/04/2019.
//  Copyright © 2019 Q42. All rights reserved.
//

import UIKit
import Contacts
import Promissum

struct Contact {
  let identifier: String
  let name: String?
  let emailAddresses: [String]
  let existingImage: Data?
  var newImage: Data?
  let hasProfilePicture: Bool
  fileprivate let cnContact: CNContact

  init(cnContact: CNContact) {
    name = CNContactFormatter.string(from: cnContact, style: .fullName)
    existingImage = cnContact.imageData
    newImage = nil
    hasProfilePicture = cnContact.imageDataAvailable
    identifier = cnContact.identifier
    emailAddresses = cnContact.emailAddresses.map { $0.value as String }
    self.cnContact = cnContact
  }
}

extension Contact: Equatable {
  static func == (lhs: Contact, rhs: Contact) -> Bool {
    return lhs.identifier == rhs.identifier
  }
}

class ContactListViewController: UITableViewController {
  var contacts = [Contact]()
  var checkedEmails = Set<String>()
  let store = CNContactStore()
  let httpManager = HttpManager(configuration: .default)

  override func viewDidLoad() {
    super.viewDidLoad()

    tableView.delegate = self
    tableView.dataSource = self
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    let status = CNContactStore.authorizationStatus(for: .contacts)
    switch status {
    case .authorized:
      loadContacts()
    case .denied, .restricted:
      let alert = UIAlertController(title: "Please grant access", message: nil, preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "Open settings", style: .default, handler: { _ in
        // todo
      }))
      alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
      present(alert, animated: true, completion: nil)
    case .notDetermined:
      store.requestAccess(for: .contacts, completionHandler: { [weak self] allowed, error in
        if allowed {
          DispatchQueue.main.async {
            self?.loadContacts()
          }
        } else if error != nil {
          // Handle this
        } else {
          // Handle this
        }
      })
     @unknown default: break // handle this
    }
  }

  func loadContacts() {
    let keysToFetch: [CNKeyDescriptor] = [
      CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
      CNContactEmailAddressesKey as CNKeyDescriptor,
      CNContactImageDataAvailableKey as CNKeyDescriptor,
      CNContactThumbnailImageDataKey as CNKeyDescriptor,
      CNContactImageDataKey as CNKeyDescriptor,
    ]

    // Get all the containers
    var allContainers: [CNContainer] = []
    do {
      allContainers = try store.containers(matching: nil)
    } catch {
      print("Error fetching containers")
    }

    var results: [CNContact] = []

    // Iterate all containers and append their contacts to our results array
    for container in allContainers {
      let fetchPredicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)

      do {
        let containerResults = try store.unifiedContacts(matching: fetchPredicate, keysToFetch: keysToFetch)
        results.append(contentsOf: containerResults)
      } catch {
        print("Error fetching results for container")
      }
    }

    self.contacts = results
      .map(Contact.init)
      .filter({ !$0.hasProfilePicture && $0.emailAddresses.count > 0 })

    tableView.reloadData()
  }

  func updateContact(contact: Contact, withImageData imageData: Data) -> Promise<Contact, Error> {
    let source = PromiseSource<Contact, Error>()
    let mutableContact = contact.cnContact.mutableCopy() as! CNMutableContact
    mutableContact.imageData = imageData

    let saveRequest = CNSaveRequest()
    saveRequest.update(mutableContact)

    do {
      try store.execute(saveRequest)
      source.resolve(contact)
    } catch {
      print(error.localizedDescription)
      source.reject(error)
    }
    return source.promise
  }

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return contacts.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: ContactCell.reuseIdentifier, for: indexPath)

    if let contactCell = cell as? ContactCell {
      let contact = contacts[indexPath.row]
      contactCell.viewModel = ContactCell.ViewModel(contact: contact, existingImage: contact.existingImage, newImage: contact.newImage)
      contactCell.delegate = self
      DispatchQueue.main.async { [weak self] in
        self?.loadNewImage(for: contact, at: indexPath)
      }
    }

    return cell
  }

  func loadNewImage(for contact: Contact, at indexPath: IndexPath) {
    guard let email = contact.emailAddresses.first else { return }
    guard !checkedEmails.contains(email) else { return }

    checkedEmails.insert(email)
    let hash = email.md5()
    let size: Int = 512
    let url = URL(string: "https://www.gravatar.com/avatar/\(hash)?s=\(size)")!

    httpManager.dataRequest(url: url)
      .then { [weak self] data in
        self?.contacts[indexPath.row].newImage = data
        self?.tableView.reloadRows(at: [indexPath], with: .fade)
        print("loaded image for \(email)")
      }
      .trap { error in
        print("failed loading image for \(email)")
      }
  }
}

extension ContactListViewController: ContactCellDelegate {
  func didAccept(image: Data, for contact: Contact) {
    updateContact(contact: contact, withImageData: image)
      .then { [weak self] _ in
        guard let row = self?.contacts.firstIndex(of: contact) else { return }
        self?.contacts.remove(at: row)
        self?.tableView.deleteRows(at: [IndexPath(row: row, section: 0)], with: .automatic)
      }
      .trap { [weak self] error in
        let alert = UIAlertController(title: "Failed to save contact", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
        self?.present(alert, animated: true, completion: nil)
      }
  }

  func didReject(image: Data, for contact: Contact) {
    guard let row = contacts.firstIndex(of: contact) else { return }
    contacts.remove(at: row)
    tableView.deleteRows(at: [IndexPath(row: row, section: 0)], with: .automatic)
  }
}
