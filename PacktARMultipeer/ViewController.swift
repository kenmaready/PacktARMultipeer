//
//  ViewController.swift
//  PacktARMultipeer
//
//  Created by Ken Maready on 9/28/22.
//

import UIKit
import SceneKit
import ARKit
import MultipeerConnectivity

class ViewController: UIViewController, ARSCNViewDelegate, MCBrowserViewControllerDelegate {
    

    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var sessionInfoView: UIVisualEffectView!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet weak var mappingStatusLabel: UILabel!
    @IBOutlet weak var hostButton: UIButton!
    @IBOutlet weak var sendMapButton: RoundedButton!
    @IBOutlet weak var joinButton: UIButton!
    @IBOutlet var tapGestureRecognizer: UITapGestureRecognizer!
    
    var multipeerSession: MultipeerSession!
    var mapProvider: MCPeerID?
    var isTrackingEnabled = false;
    
    override func viewDidLoad() {
        super.viewDidLoad()

        multipeerSession = MultipeerSession(receivedDataHandler: receivedData)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("ARKit is not available on this device.")
        }
        
        UIApplication.shared.isIdleTimerDisabled = true
        hostButton.layer.cornerRadius = 0.125 * hostButton.bounds.size.width
        joinButton.layer.cornerRadius = 0.125 * joinButton.bounds.size.width
        tapGestureRecognizer.isEnabled = true
        sendMapButton.isHidden = true
    }

    @IBAction func hostSession(_ sender: UIButton) {
        
        // start the view's AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
        sceneView.session.delegate = self
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        
        multipeerSession.advertiseSelf()
        
        hostButton.isHidden = true
        joinButton.isHidden = true
        isTrackingEnabled = true
        sendMapButton.isHidden = false
    }
    
    @IBAction func joinSession(_ sender: UIButton) {
        if multipeerSession.session != nil {
            multipeerSession.setupBrowser()
            multipeerSession.browser.delegate = self
            self.present(multipeerSession.browser, animated: true, completion: nil)
        }
    }
    
    @IBAction func shareSession(_ sender: RoundedButton) {
        sceneView.session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap else {
                print("Error: \(error!.localizedDescription)")
                return
            }
            
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true) else {
                fatalError("Can't encode map.")
            }
            
            self.multipeerSession.sendToAllPeers(data)
            self.sendMapButton.isHidden = true
        }
    }
    
    @IBAction func handleSceneTap(_ sender: UITapGestureRecognizer) {
        guard let hitTestResult = sceneView
            .hitTest(sender.location(in: sceneView), types: [.existingPlaneUsingGeometry, .estimatedHorizontalPlane]).first else { return }
        
        let anchor = ARAnchor(name: "hero", transform: hitTestResult.worldTransform)
        sceneView.session.add(anchor: anchor)
        
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
        else { fatalError("Can't encode anchor.")}
        
        self.multipeerSession.sendToAllPeers(data)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let name = anchor.name, name.hasPrefix("hero") {
            node.addChildNode(loadPlayerModel())
        }
    }
    
    // MARK: - MCBrowserViewControllerDelegate
    
    func browserViewControllerDidFinish(_ browserVC: MCBrowserViewController) {
        multipeerSession.browser.dismiss(animated: true, completion: {() -> Void in
            print(" pressed done ")
            self.hostButton.isHidden = true
            self.joinButton.isHidden = true
        })
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        multipeerSession.browser.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        sessionInfoLabel.text = "Session failed: \(error.localizedDescription)"
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        sessionInfoLabel.text = "Session was interrupted."
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        sessionInfoLabel.text = "Session interruption ended."
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
}

// MARK: - Session Delegate

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if isTrackingEnabled {
            switch frame.worldMappingStatus {
            case .notAvailable, .limited:
                sendMapButton.isEnabled = false
            case .extending:
                sendMapButton.isEnabled = true
            case .mapped:
                if (!multipeerSession.connectedPeers.isEmpty) {
                    sendMapButton.isEnabled = true
                    tapGestureRecognizer.isEnabled = true
                    isTrackingEnabled = false
                }
            default:
                sendMapButton.isEnabled = false
            }
            mappingStatusLabel.text = frame.worldMappingStatus.rawValue.description
            updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState )
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
    }
    
    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        let message: String
        switch trackingState {
        case .normal where frame.anchors.isEmpty && multipeerSession.connectedPeers.isEmpty:
            message = "Move around to map the environment or wait to join a shared session."
        case .normal where !multipeerSession.connectedPeers.isEmpty && mapProvider == nil:
            let peerNames = multipeerSession.connectedPeers.map({ $0.displayName }).joined(separator: ", ")
            message = "Cononected with: \(peerNames)"
        case .notAvailable:
            message = "Tracking not available."
        case .limited(.excessiveMotion):
            message = "Tracking currently limited - move device more slowly."
        case .limited(.insufficientFeatures):
            message = "Tracking currenly limited - point the device at an area with visible surface area or improve lighting conditions."
        case .limited(.initializing) where mapProvider != nil,
                .limited(.relocalizing) where mapProvider != nil:
            message = "Received map from \(mapProvider!.displayName)."
        case .limited(.relocalizing):
            message = "Resuming session - move to where you were when the session was interrupted."
        case .limited(.initializing):
            message = "Initializing your AR session."
        default:
            message = ""
        }
        
        sessionInfoLabel.text = message
        sessionInfoView.isHidden = message.isEmpty
    }
}

extension ARFrame.WorldMappingStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notAvailable:
            return "Not Available"
        case .limited:
            return "Limited"
        case .extending:
            return "Extending"
        case .mapped:
            return "Mapped"
        default:
            return "Unknown Status"
        }
    }
}

// MARK: - Load Player Model

extension ViewController {
    
    static func time(atFrame frame:Int, fps:Double = 30) -> TimeInterval {
        return TimeInterval(frame) / fps
    }
    static func timeRange(forStartingAtFrame start:Int, endingAtFrame end:Int, fps:Double = 30) -> (offset:TimeInterval, duration:TimeInterval) {
        let startTime   = self.time(atFrame: start, fps: fps)
        let endTime     = self.time(atFrame: end, fps: fps)
        return (offset:startTime, duration:endTime - startTime)
    }
    
    static func animation(from full:CAAnimation, startingAtFrame start:Int, endingAtFrame end:Int, fps:Double = 30) -> CAAnimation {
        let range = self.timeRange(forStartingAtFrame: start, endingAtFrame: end, fps: fps)
        let animation = CAAnimationGroup()
        let sub = full.copy() as! CAAnimation
        sub.timeOffset = range.offset
        animation.animations = [sub]
        animation.duration = range.duration
        return animation
    }
    
    // load monster model
    private func loadPlayerModel() -> SCNNode {
        
        // -- Load the monster from the collada scene
        
        let tempNode:SCNNode = SCNNode()
        let monsterScene:SCNScene = SCNScene(named: "Assets.scnassets/theDude.DAE")!
        let referenceNode = monsterScene.rootNode.childNode(withName: "CATRigHub001", recursively: false)! //CATRigHub001
        tempNode.addChildNode(referenceNode)
       
        
        // -- Set the anchor point to the center of the character
        let (minVec, maxVec)  = tempNode.boundingBox
        let bound = SCNVector3(x: maxVec.x - minVec.x, y: maxVec.y - minVec.y,z: maxVec.z - minVec.z)
        tempNode.pivot = SCNMatrix4MakeTranslation(bound.x * 1.1, 0 , 0)
        
        // -- Set the scale and name of the current class
        tempNode.scale = SCNVector3(0.1/100.0, 0.1/100.0, 0.1/100.0)
        
        
        // -- Get the animation keys and store it in the anims
        let animKeys = referenceNode.animationKeys.first
        let animPlayer = referenceNode.animationPlayer(forKey: animKeys!)
        let anims = CAAnimation(scnAnimation: (animPlayer?.animation)!)
        
        
        // -- Get the run animation from the animations
        let runAnimation = ViewController.animation(from: anims, startingAtFrame: 31, endingAtFrame: 50)
        runAnimation.repeatCount = .greatestFiniteMagnitude
        runAnimation.fadeInDuration = 0.0
        runAnimation.fadeOutDuration = 0.0
        
        // -- Remove all the animations from the character
        referenceNode.removeAllAnimations()
        
        // -- Set the run animation to the player
        let runPlayer = SCNAnimationPlayer(animation: SCNAnimation(caAnimation: runAnimation))
        tempNode.addAnimationPlayer(runPlayer, forKey: "run")
        
        // -- Play the run animation at start
        tempNode.animationPlayer(forKey: "run")?.play()
        
        return tempNode
    }
}

// MARK: - Received Data Handler Functions

extension ViewController {
    func receivedData(_ data: Data, from peer: MCPeerID) {
        if let unarchivedMap = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [ARWorldMap.classForKeyedUnarchiver()], from: data),
        let worldMap = unarchivedMap as? ARWorldMap {
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = .horizontal
            configuration.initialWorldMap = worldMap
            sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            
            mapProvider = peer
            
            if (!multipeerSession.connectedPeers.isEmpty) {
                tapGestureRecognizer.isEnabled = true
            }
        }
        
        else if let unarchivedAnchor = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [ARAnchor.classForKeyedUnarchiver()], from: data),
                let anchor = unarchivedAnchor as? ARAnchor {
            sceneView.session.add(anchor: anchor)
        } else {
            print("Unknown data received from \(peer)")
        }
    }
}
