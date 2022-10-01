//
//  MultipeerSession.swift
//  PacktARMultipeer
//
//  Created by Ken Maready on 9/28/22.
//

import Foundation
import MultipeerConnectivity

class MultipeerSession: NSObject, MCSessionDelegate {
    
    static let serviceType = "ar-multi-sample"
    
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    var browser: MCBrowserViewController!
    var advertiser: MCAdvertiserAssistant? = nil
    var session: MCSession!
    let receivedDataHandler: (Data, MCPeerID) -> Void
    
    var connectedPeers: [MCPeerID] {
        return session.connectedPeers
    }
    
    init(receivedDataHandler: @escaping (Data, MCPeerID) -> Void) {
        self.receivedDataHandler = receivedDataHandler
        super.init()
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }
    
    func advertiseSelf() {
        advertiser = MCAdvertiserAssistant(serviceType: MultipeerSession.serviceType, discoveryInfo: nil, session: session)
        advertiser!.start()
    }
    
    func setupBrowser() {
        browser = MCBrowserViewController(serviceType: MultipeerSession.serviceType, session: session)
        browser.maximumNumberOfPeers = 1
        browser.minimumNumberOfPeers = 1
    }
    
    func sendToAllPeers(_ data: Data) {
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("Error sending data to peers from session \(session.hashValue): \(error.localizedDescription)")
        }
    }
}

// MARK: - MCSessionDelegate

extension MultipeerSession {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case MCSessionState.connected:
            print("Connected: \(peerID.displayName)")
        case MCSessionState.connecting:
            print("Connecting: \(peerID.displayName)")
        case MCSessionState.notConnected:
            print("Not connected: \(peerID.displayName)")
        default:
            print("default case reached in didChange switch statement.")
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        receivedDataHandler(data, peerID)
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        fatalError("A stream was attempted to be sent to this service. This service does not send/receive streams.")
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        fatalError("A resource was attempted to be sent to this service. This service does not send/reecive resources.")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        fatalError("A resource was attempted to be sent to this service. This service does not send/receive resources.")
    }
}
