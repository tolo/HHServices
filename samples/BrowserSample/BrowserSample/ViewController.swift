//
//  ViewController.swift
//  BrowserSample
//
//  Copyright (c) Tobias Löfstrand, Leafnode AB.
//  License: MIT - https://github.com/tolo/HHServices/blob/master/LICENSE
//

import UIKit
import HHServices

class ViewController: UIViewController {
    
    private var browser: ServiceBrowser?
    private var browseResult: [Service] = []
    private var resolvingService: Service?
    private var tableView: UITableView!
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setupBrowser()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBrowser()
    }
    
    private func setupBrowser() {
        // Browse for services - make sure you set the type parameter to your service type
        browser = ServiceBrowser(type: "_myexampleservice._tcp.", domain: "local.")
    }
    
    override func loadView() {
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        rootView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        rootView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        tableView = UITableView(frame: CGRect(x: 20, y: 40, width: 280, height: 200), style: .plain)
        tableView.layer.cornerRadius = 4
        tableView.layer.borderColor = UIColor(white: 0.5, alpha: 1).cgColor
        tableView.layer.borderWidth = 1
        tableView.delegate = self
        tableView.dataSource = self
        rootView.addSubview(tableView)
        
        let resolveButton = UIButton(type: .roundedRect)
        resolveButton.frame = CGRect(x: 40, y: 250, width: 240, height: 44)
        resolveButton.setTitle("Resolve selected", for: .normal)
        resolveButton.addTarget(self, action: #selector(resolve), for: .touchUpInside)
        rootView.addSubview(resolveButton)
        
        let browseButton = UIButton(type: .roundedRect)
        browseButton.frame = CGRect(x: 40, y: 300, width: 240, height: 44)
        browseButton.setTitle("Browse again", for: .normal)
        browseButton.addTarget(self, action: #selector(browseAgain), for: .touchUpInside)
        rootView.addSubview(browseButton)
        
        view = rootView
        
        startBrowsing()
        
        // Schedule automatic browse refresh
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            self.browseAgain()
        }
    }
    
    // MARK: - Actions
    
    @objc private func resolve() {
        guard let selectedIndexPath = tableView.indexPathForSelectedRow,
              selectedIndexPath.row < browseResult.count,
              resolvingService == nil else {
            showAlert(title: nil, message: "Select a service")
            return
        }
        
        let service = browseResult[selectedIndexPath.row]
        resolvingService = service
        
        Task {
            do {
                let resolver = ServiceResolver(service: service)
                let resolvedService = try await resolver.resolve()
                
                DispatchQueue.main.async {
                    self.resolvingService = nil
                    self.handleResolvedService(resolvedService)
                }
            } catch {
                DispatchQueue.main.async {
                    self.resolvingService = nil
                    self.showAlert(title: "Resolve result", message: "Service did NOT resolve: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func browseAgain() {
        resolvingService = nil
        browseResult.removeAll()
        tableView.reloadData()
        startBrowsing()
    }
    
    private func startBrowsing() {
        guard let browser = browser else { return }
        
        Task {
            for await event in browser.browse() {
                DispatchQueue.main.async {
                    self.handleBrowseEvent(event)
                }
            }
        }
    }
    
    private func handleBrowseEvent(_ event: DiscoveryEvent) {
        switch event {
        case .serviceAdded(let service, _):
            if !browseResult.contains(where: { $0.name == service.name && $0.type == service.type }) {
                browseResult.append(service)
                tableView.reloadData()
            }
        case .serviceRemoved(let service, _):
            browseResult.removeAll { $0.name == service.name && $0.type == service.type }
            tableView.reloadData()
        }
    }
    
    private func handleResolvedService(_ service: Service) {
        var message = "Service resolved:\n"
        
        if let hostName = service.hostName {
            message += "Host: \(hostName)\n"
        }
        
        if let port = service.port {
            message += "Port: \(port)\n"
        }
        
        if !service.addresses.isEmpty {
            message += "Addresses:\n"
            for address in service.addresses {
                if let presentation = address.presentation {
                    if let port = address.port {
                        message += "  \(presentation):\(port)\n"
                    } else {
                        message += "  \(presentation)\n"
                    }
                } else {
                    message += "  \(address.family)\n"
                }
            }
        }
        
        showAlert(title: "Resolve result", message: message)
    }
    
    private func showAlert(title: String?, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return browseResult.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let service = browseResult[indexPath.row]
        cell.textLabel?.text = service.name
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ViewController: UITableViewDelegate {
    // Table view delegate methods can be added here if needed
}