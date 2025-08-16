//
//  ViewController.swift
//  PublisherSample
//
//  Copyright (c) Tobias Löfstrand, Leafnode AB.
//  License: MIT - https://github.com/tolo/HHServices/blob/master/LICENSE
//

import UIKit
import HHServices

class ViewController: UIViewController {
    
    private var publisher: ServicePublisher?
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setupPublisher()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPublisher()
    }
    
    private func setupPublisher() {
        let serverPort: UInt16 = 12345
        
        // Setup the service publisher - remember to update the type parameter with your actual service type
        publisher = ServicePublisher(
            name: "PublisherSample",
            type: "_myexampleservice._tcp.",
            domain: "local.",
            port: serverPort
        )
        publisher?.delegate = self
    }
    
    override func loadView() {
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        rootView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        rootView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let publishButton = UIButton(type: .roundedRect)
        publishButton.frame = CGRect(x: 40, y: 50, width: 240, height: 44)
        publishButton.setTitle("Publish", for: .normal)
        publishButton.addTarget(self, action: #selector(beginPublish), for: .touchUpInside)
        rootView.addSubview(publishButton)
        
        let unpublishButton = UIButton(type: .roundedRect)
        unpublishButton.frame = CGRect(x: 40, y: 100, width: 240, height: 44)
        unpublishButton.setTitle("Unpublish", for: .normal)
        unpublishButton.addTarget(self, action: #selector(endPublish), for: .touchUpInside)
        rootView.addSubview(unpublishButton)
        
        view = rootView
    }
    
    // MARK: - Actions
    
    @objc private func beginPublish() {
        guard let publisher = publisher else { return }
        
        Task {
            do {
                try await publisher.publish()
                DispatchQueue.main.async {
                    self.showAlert(title: "Publish result", message: "Publish successful!")
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(title: "Publish result", message: "Publish failed: \(error.localizedDescription)")
                }
            }
        }
        
        // Alternative: using the delegate-based approach
        // try? publisher.startPublishing()
        
        // Examples of other publishing options:
        // Task { try await publisher.publishBluetoothOnly() }
    }
    
    @objc private func endPublish() {
        publisher?.stop()
    }
    
    private func showAlert(title: String?, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - ServicePublisherDelegate

extension ViewController: ServicePublisherDelegate {
    func servicePublisher(_ publisher: ServicePublisher, didPublishWithName name: String) {
        DispatchQueue.main.async {
            self.showAlert(title: "Publish result", message: "Publish successful with name: \(name)")
        }
    }
    
    func servicePublisherDidStop(_ publisher: ServicePublisher) {
        DispatchQueue.main.async {
            self.showAlert(title: "Publish result", message: "Publisher stopped")
        }
    }
    
    func servicePublisher(_ publisher: ServicePublisher, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.showAlert(title: "Publish result", message: "Publish failed: \(error.localizedDescription)")
        }
    }
}