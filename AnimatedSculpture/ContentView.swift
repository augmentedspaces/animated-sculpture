//
//  ContentView.swift
//  AnimatedSculpture
//
//  Created by Nien Lam on 9/15/21.
//  Copyright © 2021 Line Break, LLC. All rights reserved.
//

import SwiftUI
import ARKit
import RealityKit
import Combine


// MARK: - View model for handling communication between the UI and ARView.
class ViewModel: ObservableObject {
    let uiSignal = PassthroughSubject<UISignal, Never>()
    
    @Published var positionLocked = false
    @Published var sliderValue: Double = 0
    
    enum UISignal {
        case lockPosition
    }
}


// MARK: - UI Layer.
struct ContentView : View {
    @StateObject var viewModel = ViewModel()
    
    var body: some View {
        ZStack {
            ARViewContainer(viewModel: viewModel)
            
            HStack {
                Button {
                    viewModel.uiSignal.send(.lockPosition)
                } label: {
                    Label("Lock Position", systemImage: "target")
                        .font(.system(.title))
                        .foregroundColor(.white)
                        .labelStyle(IconOnlyLabelStyle())
                        .frame(width: 44, height: 44)
                        .opacity(viewModel.positionLocked ? 0.25 : 1.0)
                }
                
                Slider(value: $viewModel.sliderValue, in: 0...1)
                    .accentColor(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, 10)
            .padding(.bottom, 30)
        }
        .edgesIgnoringSafeArea(.all)
        .statusBar(hidden: true)
    }
}


// MARK: - AR View.
struct ARViewContainer: UIViewRepresentable {
    let viewModel: ViewModel
    
    func makeUIView(context: Context) -> ARView {
        SimpleARView(frame: .zero, viewModel: viewModel)
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

class SimpleARView: ARView {
    var viewModel: ViewModel
    var arView: ARView { return self }
    var originAnchor: AnchorEntity!
    var subscriptions = Set<AnyCancellable>()
    
    // Empty entity for cursor.
    var cursor: Entity!


    // TODO: Add any local variables here. //////////////////////////////////////
    
    var boxEntity: Entity!
    var sphereEntity: Entity!

    var upDnToggle = false

    
    init(frame: CGRect, viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(frame: frame)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        setupScene()
    
        setupEntities()
    }
    
    func setupScene() {
        // Setup world tracking and plane detection.
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        arView.renderOptions = [.disableDepthOfField, .disableMotionBlur]
        arView.session.run(configuration)

        // Called every frame.
        scene.subscribe(to: SceneEvents.Update.self) { event in
            // Update cursor position when position is not locked.
            if !self.viewModel.positionLocked {
                self.updateCursor()
            }
            
            // Call renderLoop method on every frame.
            self.renderLoop()
        }.store(in: &subscriptions)
        
        // Process UI signals.
        viewModel.uiSignal.sink { [weak self] in
            self?.processUISignal($0)
        }.store(in: &subscriptions)
    }
    
    // Process UI signals.
    func processUISignal(_ signal: ViewModel.UISignal) {
        switch signal {
        case .lockPosition:
            viewModel.positionLocked.toggle()
        }
    }
    
    // Move cursor to plane detected.
    func updateCursor() {
        // Raycast to get cursor position.
        let results = raycast(from: center,
                              allowing: .existingPlaneGeometry,
                              alignment: .any)
        
        // Move cursor to position if hitting plane.
        if let result = results.first {
            cursor.isEnabled = true
            cursor.move(to: result.worldTransform, relativeTo: originAnchor)
        } else {
            cursor.isEnabled = false
        }
    }
    

    // TODO: Setup entities. //////////////////////////////////////
    func setupEntities() {
        // Create an anchor at scene origin.
        originAnchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(originAnchor)

        // Create and add empty cursor entity to origin anchor.
        cursor = Entity()
        originAnchor.addChild(cursor)

        
        // Checker material.
        var checkerMaterial = SimpleMaterial()
        let texture = try! TextureResource.load(named: "checker.png")
        checkerMaterial.baseColor = .texture(texture)


        // Setup example box entity.
        let boxMesh = MeshResource.generateBox(size: [0.03, 0.03, 0.03], cornerRadius: 0.0)
        boxEntity = ModelEntity(mesh: boxMesh, materials: [checkerMaterial])
        boxEntity.position.y = 0.015
        cursor.addChild(boxEntity)


        /*
        // Example: Stair pattern.
        for idx in 1..<10 {
            // Create and position new entity.
            let newEntity = boxEntity.clone(recursive: false)
            newEntity.position.x = Float(idx) * 0.03
            newEntity.position.y = Float(idx) * 0.03

            // Add to starting entity.
            boxEntity.addChild(newEntity)
        }
        */


        /*
        // Example: Spiral stair pattern.
        
        // Remember last entity in tree.
        var lastBoxEntity = boxEntity

        for _ in 0..<10 {
            // Create and position new entity.
            let newEntity = boxEntity.clone(recursive: false)
            newEntity.position.x = 0.03
            newEntity.position.y = 0.03

            // Rotate on y-axis by 45 degrees.
            newEntity.orientation = simd_quatf(angle: .pi / 4, axis: [0, 1, 0])

            // Add to last entity in tree.
            lastBoxEntity?.addChild(newEntity)
            
            // Set last entity used.
            lastBoxEntity = newEntity
        }
        */

 
        // Setup example sphere entity.
        let sphereMesh = MeshResource.generateSphere(radius: 0.015)
        sphereEntity = ModelEntity(mesh: sphereMesh, materials: [checkerMaterial])
        sphereEntity.position.x = 0.075
        sphereEntity.position.y = 0.015
        cursor.addChild(sphereEntity)
    }


    // TODO: Animate entities. //////////////////////////////////////
    func renderLoop() {
        // Slider value from UI.
        let sliderValue = Float(viewModel.sliderValue)

        // Scale sphere entity based on slider value.
        sphereEntity.scale = [1 + sliderValue * 2, 1 + sliderValue * 2, 1 + sliderValue * 2]
        

        // Increment or decrement z position of sphere.
        if upDnToggle {
            sphereEntity.position.z += 0.002
        } else {
            sphereEntity.position.z -= 0.002
        }

        // Put limits on movement.
        if sphereEntity.position.z > 0.1 {
            upDnToggle = false
        } else if sphereEntity.position.z < -0.1 {
            upDnToggle = true
        }
        

        // Spin box entity on y axis.
        boxEntity.orientation *= simd_quatf(angle: 0.04, axis: [0, 1, 0])
    }
}
