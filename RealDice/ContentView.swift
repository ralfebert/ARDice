import ARKit
import FocusEntity
import RealityKit
import SwiftUI

struct RealityKitView: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let view = ARView()

        // Start AR session
        let session = view.session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        session.run(config)

        // Add coaching overlay
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.session = session
        coachingOverlay.goal = .horizontalPlane
        view.addSubview(coachingOverlay)

        // Set debug options
        #if DEBUG
            // view.debugOptions = [.showFeaturePoints, .showAnchorOrigins, .showAnchorGeometry]
        #endif

        // Handle ARSession events via delegate
        context.coordinator.view = view
        session.delegate = context.coordinator

        // Handle taps
        view.addGestureRecognizer(
            UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleTap)
            )
        )

        return view
    }

    func updateUIView(_ view: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, ARSessionDelegate {
        weak var view: ARView?
        var focusEntity: FocusEntity?
        var diceEntity: ModelEntity?

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let view = self.view else { return }
            print("Anchor added to the scene: ", anchors)
            self.focusEntity = FocusEntity(on: view, style: .classic(color: .yellow))
        }

        @objc func handleTap() {
            guard let view = self.view, let focusEntity = self.focusEntity else { return }

            if let diceEntity = self.diceEntity {
                diceEntity.addForce(.init(0, 2, 0), relativeTo: nil)
                diceEntity.addTorque(.init(Float.random(in: 0 ... 0.4), Float.random(in: 0 ... 0.4), Float.random(in: 0 ... 0.4)), relativeTo: nil)
                return
            }

            // Create a new anchor to add content to
            let anchor = AnchorEntity()
            view.scene.anchors.append(anchor)

            // Add a Dice entity
            let diceEntity = try! Entity.loadModel(named: "Dice")
            diceEntity.scale = .init(0.1, 0.1, 0.1)
            diceEntity.position = focusEntity.position
            anchor.addChild(diceEntity)
            self.diceEntity = diceEntity

            // Setup Physics
            let extent = diceEntity.visualBounds(relativeTo: diceEntity).extents.y
            let boxShape = ShapeResource.generateBox(size: [extent, extent, extent])
            diceEntity.collision = CollisionComponent(shapes: [boxShape])
            diceEntity.physicsBody = PhysicsBodyComponent(
                massProperties: .init(shape: boxShape, mass: 50),
                material: nil,
                mode: .dynamic
            )

            // Create a plane below the Dice
            let box = MeshResource.generateBox(width: 2, height: 0.001, depth: 2)
            let material = SimpleMaterial(color: .white, isMetallic: false)
            let planeEntity = ModelEntity(mesh: box, materials: [material])
            planeEntity.position = focusEntity.position
            planeEntity.physicsBody = PhysicsBodyComponent(massProperties: .default, material: nil, mode: .static)
            planeEntity.collision = CollisionComponent(shapes: [.generateBox(width: 2, height: 0.001, depth: 2)])
            planeEntity.position = focusEntity.position
            anchor.addChild(planeEntity)
        }
    }
}

struct ContentView: View {
    var body: some View {
        RealityKitView()
            .ignoresSafeArea()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
