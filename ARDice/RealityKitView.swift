import ARKit
import FocusEntity
import RealityKit
import SwiftUI

struct RealityKitView: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let view = ARView()

        let session = view.session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = .horizontal
        session.run(config)

        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.session = session
        coachingOverlay.goal = .horizontalPlane
        view.addSubview(coachingOverlay)

        #if DEBUG
            // view.debugOptions = [.showFeaturePoints, .showAnchorOrigins, .showAnchorGeometry, .showPhysics]
        #endif

        context.coordinator.view = view
        session.delegate = context.coordinator

        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap)))

        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, ARSessionDelegate {
        weak var view: ARView?
        var focusEntity: FocusEntity?
        var diceEntity: ModelEntity?

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let view = self.view else { return }
            self.focusEntity = FocusEntity(on: view, style: .classic(color: .yellow))
        }

        @objc func handleTap() {
            guard let view = self.view, let focusEntity = self.focusEntity else { return }

            if let diceEntity = self.diceEntity {
                // roll the dice on 2nd tap
                diceEntity.addForce([0, 2, 0], relativeTo: nil)
                diceEntity.addTorque([Float.random(in: 0 ... 0.4), Float.random(in: 0 ... 0.4), Float.random(in: 0 ... 0.4)], relativeTo: nil)
            } else {
                // create the dice on 1st tap
                let anchor = AnchorEntity()
                view.scene.addAnchor(anchor)

                let diceEntity = try! Entity.loadModel(named: "Dice")
                diceEntity.scale = [0.1, 0.1, 0.1]
                diceEntity.position = focusEntity.position

                let extent = diceEntity.visualBounds(relativeTo: diceEntity).extents.y
                let boxShape = ShapeResource.generateBox(size: [extent, extent, extent])
                diceEntity.collision = CollisionComponent(shapes: [boxShape])
                diceEntity.physicsBody = PhysicsBodyComponent(
                    massProperties: .init(shape: boxShape, mass: 50),
                    material: nil,
                    mode: .dynamic
                )

                self.diceEntity = diceEntity
                anchor.addChild(diceEntity)

                // Create a plane below the dice
                let planeMesh = MeshResource.generatePlane(width: 2, depth: 2)
                let material = SimpleMaterial(color: .init(white: 1.0, alpha: 0.1), isMetallic: false)
                let planeEntity = ModelEntity(mesh: planeMesh, materials: [material])
                planeEntity.position = focusEntity.position
                planeEntity.physicsBody = PhysicsBodyComponent(massProperties: .default, material: nil, mode: .static)
                planeEntity.collision = CollisionComponent(shapes: [.generateBox(width: 2, height: 0.001, depth: 2)])
                planeEntity.position = focusEntity.position
                anchor.addChild(planeEntity)
            }
        }
    }
}
