//
//  CharacterImportSheet.swift
//  Maker
//
//  The short wizard that turns a .usdz or .glb file into the hero.
//

import SwiftUI
import SceneKit
import UniformTypeIdentifiers

struct CharacterImportSheet: View {
    @EnvironmentObject private var store: MakerStore
    @Environment(\.dismiss) private var dismiss

    @State private var picking = false
    @State private var name = ""
    @State private var height: Double = 1.8
    @State private var modelScene: SCNScene?
    @State private var boneNames: [String] = []
    @State private var boneMap: [String: String] = [:]
    @State private var triangles = 0
    @State private var storedFileName = ""
    @State private var testPose = false
    @State private var problem: String?

    private var allowedTypes: [UTType] {
        var types: [UTType] = []
        if let usdz = UTType(filenameExtension: "usdz") { types.append(usdz) }
        if let glb = UTType(filenameExtension: "glb") { types.append(glb) }
        return types.isEmpty ? [.data] : types
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let modelScene {
                        preview(modelScene)
                        nameAndSize
                        boneSection
                        warningSection
                    } else {
                        chooser
                    }

                    if let problem {
                        Text(problem)
                            .font(.caption)
                            .foregroundStyle(Palette.coral)
                    }
                }
                .padding(20)
            }
            .background(Palette.background)
            .navigationTitle("Bring in a character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use it") { save() }
                        .fontWeight(.bold)
                        .disabled(modelScene == nil)
                }
            }
            .fileImporter(isPresented: $picking,
                          allowedContentTypes: allowedTypes,
                          allowsMultipleSelection: false) { result in
                handle(result)
            }
        }
    }

    // MARK: Pieces

    private var chooser: some View {
        VStack(alignment: .leading, spacing: 12) {
            IconBadge(symbol: "cube.transparent.fill", tint: Palette.accent, size: 54)
            Text("Choose a rigged character")
                .font(.title3.bold())
            Text("A .usdz or .glb file with a skeleton in it. Maker will match its bones to the ones it knows, then walk it with the same steps as the built-in hero.")
                .font(.caption)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                picking = true
            } label: {
                Label("Choose a file", systemImage: "folder")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .makerCard()
    }

    private func preview(_ scene: SCNScene) -> some View {
        VStack(spacing: 8) {
            CharacterTurntable(scene: scene,
                               height: CGFloat(height),
                               boneMap: boneMap,
                               testPose: testPose)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            HStack {
                Toggle(isOn: $testPose) {
                    Text("Test pose")
                        .font(.caption.weight(.semibold))
                }
                .tint(Palette.accent)
                Spacer()
                Button {
                    picking = true
                } label: {
                    Label("Choose another", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .makerCard(padding: 12)
    }

    private var nameAndSize: some View {
        VStack(alignment: .leading, spacing: 12) {
            FieldLabel(text: "Name")
            TextField("My character", text: $name)
                .font(.headline)
                .textFieldStyle(.plain)
                .padding(11)
                .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                Text("Height")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.inkSoft)
                Slider(value: $height, in: 0.6...3.0)
                    .tint(Palette.accent)
                Text(String(format: "%.2f m", height))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Palette.inkSoft)
            }

            Text("\(triangles) triangles")
                .font(.caption2)
                .foregroundStyle(Palette.inkSoft)
        }
        .makerCard()
    }

    private var boneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Bones")
                    .font(.headline)
                Spacer()
                Text(boneNames.isEmpty ? "none found" : "\(boneMap.count) of \(MakerRig.bones.count) matched")
                    .font(.caption2)
                    .foregroundStyle(Palette.inkSoft)
            }

            if boneNames.isEmpty {
                Text("This file has no skeleton Maker can read, so it will stand still when the hero walks. You can still use it.")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(MakerRig.bones, id: \.self) { bone in
                    HStack(spacing: 8) {
                        Text(bone)
                            .font(.caption.weight(.semibold))
                            .frame(width: 92, alignment: .leading)
                        Menu {
                            Button("Not matched") { boneMap[bone] = nil }
                            ForEach(boneNames, id: \.self) { candidate in
                                Button(candidate) { boneMap[bone] = candidate }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(boneMap[bone] ?? "Not matched")
                                    .font(.caption)
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .black))
                            }
                            .foregroundStyle(boneMap[bone] == nil ? Palette.inkFaint : Palette.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Palette.surfaceAlt, in: Capsule())
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .makerCard()
    }

    private var warningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: "Worth knowing")
            if warnings.isEmpty {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.mint)
                    Text("Nothing to worry about.")
                        .font(.caption)
                }
            } else {
                ForEach(warnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(Palette.amber)
                        Text(warning)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .makerCard()
    }

    private var warnings: [String] {
        var list: [String] = []
        if triangles > 40_000 {
            list.append("This model has \(triangles) triangles. Under 40,000 keeps the game smooth.")
        }
        if boneNames.isEmpty {
            list.append("No bones found, so the arms and legs won't move. It will still walk around.")
        } else {
            let missing = MakerRig.required.filter { boneMap[$0] == nil }
            if !missing.isEmpty {
                list.append("Not matched yet: \(missing.joined(separator: ", ")). The parts that aren't matched simply won't move.")
            }
        }
        return list
    }

    // MARK: Actions

    private func handle(_ result: Result<[URL], Error>) {
        problem = nil
        switch result {
        case .failure:
            problem = "That file couldn't be opened."
        case .success(let urls):
            guard let url = urls.first else { return }
            let extensionName = url.pathExtension.lowercased()
            guard extensionName == "usdz" || extensionName == "glb" else {
                problem = "Choose a .usdz or a .glb file."
                return
            }

            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            guard let loaded = CharacterLoader.scene(at: url) else {
                problem = "Maker couldn't read that file. Try exporting it again as .usdz."
                return
            }

            let destination = CharacterStorage.destination(for: extensionName)
            try? FileManager.default.removeItem(at: destination)
            do {
                try FileManager.default.copyItem(at: url, to: destination)
            } catch {
                problem = "The file couldn't be copied into the game."
                return
            }

            let measurement = CharacterLoader.measure(loaded.rootNode)
            modelScene = loaded
            storedFileName = destination.lastPathComponent
            triangles = measurement.triangles
            height = 1.8
            boneNames = CharacterLoader.boneNames(in: loaded.rootNode)
            boneMap = MakerRig.autoMap(boneNames)
            let suggested = url.deletingPathExtension().lastPathComponent
            name = suggested.prefix(1).uppercased() + suggested.dropFirst()
            testPose = false
        }
    }

    private func save() {
        guard modelScene != nil else { return }
        let character = ImportedCharacter(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My character" : name,
            fileName: storedFileName,
            height: height,
            boneMap: boneMap,
            hasSkeleton: !boneNames.isEmpty,
            triangleCount: triangles
        )
        store.addImportedCharacter(character)
        dismiss()
    }
}

// MARK: - Turntable

struct CharacterTurntable: UIViewRepresentable {
    let scene: SCNScene
    let height: CGFloat
    let boneMap: [String: String]
    let testPose: Bool

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.isPlaying = true

        let stage = SCNScene()
        stage.background.contents = UIColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 1)

        let camera = SCNCamera()
        camera.fieldOfView = 40
        camera.zNear = 0.05
        camera.zFar = 60
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 1.25, 3.6)
        cameraNode.look(at: SCNVector3(0, 0.95, 0), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        stage.rootNode.addChildNode(cameraNode)

        let sun = SCNNode()
        let sunLight = SCNLight()
        sunLight.type = .directional
        sunLight.intensity = 1000
        sun.light = sunLight
        sun.eulerAngles = SCNVector3(-0.9, 0.6, 0)
        stage.rootNode.addChildNode(sun)

        let ambient = SCNNode()
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 520
        ambient.light = ambientLight
        stage.rootNode.addChildNode(ambient)

        let container = SCNNode()
        stage.rootNode.addChildNode(container)
        container.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 16)))

        let measurement = CharacterLoader.measure(scene.rootNode)
        scene.rootNode.position = SCNVector3(0, -measurement.minY, 0)
        container.addChildNode(scene.rootNode)

        view.scene = stage
        view.pointOfView = cameraNode

        context.coordinator.container = container
        context.coordinator.apply(height: height, boneMap: boneMap, testPose: false, root: scene.rootNode)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.apply(height: height, boneMap: boneMap, testPose: testPose, root: scene.rootNode)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var container: SCNNode?
        private var bones: [String: SCNNode] = [:]
        private var restPose: [String: SCNVector3] = [:]
        private var posing = false
        private var currentMap: [String: String] = [:]

        func apply(height: CGFloat, boneMap: [String: String], testPose: Bool, root: SCNNode) {
            let measurement = CharacterLoader.measure(root)
            let scale = measurement.height > 0.001 ? Float(height) / measurement.height : 1
            container?.scale = SCNVector3(scale, scale, scale)

            if boneMap != currentMap {
                currentMap = boneMap
                refresh(root: root, map: boneMap)
                posing = false
                applyPose(testPose)
            } else if testPose != posing {
                applyPose(testPose)
            }
        }

        private func refresh(root: SCNNode, map: [String: String]) {
            var byName: [String: SCNNode] = [:]
            root.enumerateHierarchy { node, _ in
                if let name = node.name { byName[name] = node }
            }
            bones = [:]
            restPose = [:]
            for (rigBone, modelBone) in map {
                if let node = byName[modelBone] {
                    bones[rigBone] = node
                    restPose[rigBone] = node.eulerAngles
                }
            }
        }

        private func applyPose(_ on: Bool) {
            posing = on
            let angles: [String: Float] = [
                "UpperLeg.L": 0.5,
                "UpperLeg.R": -0.4,
                "UpperArm.L": -0.7,
                "UpperArm.R": 0.7,
                "LowerArm.L": -0.35,
                "LowerArm.R": 0.35
            ]
            for (rigBone, node) in bones {
                guard let rest = restPose[rigBone] else { continue }
                let extra = on ? (angles[rigBone] ?? 0) : 0
                node.eulerAngles = SCNVector3(rest.x + extra, rest.y, rest.z)
            }
        }
    }
}
