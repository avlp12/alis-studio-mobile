// Alis Studio Mobile — main UI and generation flow.
// Builds on Apple's mlx-swift-examples StableDiffusion library (MIT, vendored under Sources/).

import MLX
import StableDiffusion
import SwiftUI

// MARK: - Alis Studio design tokens (mirrors the desktop app's palette, light + dark)

enum AlisColor {
    static func c(_ s: ColorScheme, _ light: UInt, _ dark: UInt) -> Color {
        Color(hex: s == .dark ? dark : light)
    }
    static func bg(_ s: ColorScheme) -> Color { c(s, 0xfaf9f5, 0x211f1d) }
    static func surface(_ s: ColorScheme) -> Color { c(s, 0xffffff, 0x2b2926) }
    static func surface1(_ s: ColorScheme) -> Color { c(s, 0xf3f2ec, 0x322f2b) }
    static func text(_ s: ColorScheme) -> Color { c(s, 0x22201d, 0xf2efe7) }
    static func text2(_ s: ColorScheme) -> Color { c(s, 0x6b6960, 0xb4b0a4) }
    static func muted(_ s: ColorScheme) -> Color { c(s, 0x9b988e, 0x827e74) }
    static func border(_ s: ColorScheme) -> Color {
        s == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10)
    }
    static func borderStrong(_ s: ColorScheme) -> Color {
        s == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.18)
    }
    static func clay(_ s: ColorScheme) -> Color { c(s, 0xc4623f, 0xd6795a) }
    static func onClay(_ s: ColorScheme) -> Color { c(s, 0xffffff, 0x1c1a18) }
    static let ok = Color(hex: 0x5a9367)
}

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255, opacity: 1)
    }
}

/// The Alis mark — a tiered pine + a spark, drawn in a 24×24 space (matches the desktop logo).
struct AlisMark: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        var path = Path()
        let pine: [(Double, Double)] = [
            (12, 2.7), (14.55, 8.1), (13.2, 8.1), (15.9, 12.6), (13.55, 12.6), (17.35, 17.2),
            (13.05, 17.2), (13.05, 20.9), (10.95, 20.9), (10.95, 17.2), (6.65, 17.2),
            (10.45, 12.6), (8.1, 12.6), (10.8, 8.1), (9.45, 8.1),
        ]
        path.move(to: p(pine[0].0, pine[0].1))
        for pt in pine.dropFirst() { path.addLine(to: p(pt.0, pt.1)) }
        path.closeSubpath()
        let star: [(Double, Double)] = [
            (18, 2.3), (18.53, 3.77), (20.0, 4.3), (18.53, 4.83), (18, 6.3), (17.47, 4.83),
            (16, 4.3), (17.47, 3.77),
        ]
        path.move(to: p(star[0].0, star[0].1))
        for pt in star.dropFirst() { path.addLine(to: p(pt.0, pt.1)) }
        path.closeSubpath()
        return path
    }
}

struct PineLogo: View {
    @Environment(\.colorScheme) private var scheme
    var size: CGFloat = 26
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(AlisColor.clay(scheme))
            .frame(width: size, height: size)
            .overlay(
                AlisMark().fill(AlisColor.onClay(scheme))
                    .frame(width: size * 0.74, height: size * 0.74))
    }
}

// MARK: - Main screen

struct ContentView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var prompt = "a serene mountain lake at sunrise, mist over the water"
    @State private var evaluator = StableDiffusionEvaluator()
    @State private var showGallery = false
    @State private var pickingModel = false
    @State private var gallery: [GalleryItem] = []

    private var busy: Bool { evaluator.progress != nil }

    // Independent of desktop Alis Studio; reads CFBundleShortVersionString (= MARKETING_VERSION).
    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0"
    }

    private var deviceRAMGiB: Double { Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824 }
    // Requires an 8 GB-class iPhone. 8 GB devices report ~7.8–8.0 GB; 6 GB report ~5.9 GB.
    private var deviceSupported: Bool {
        ProcessInfo.processInfo.physicalMemory >= 7 * 1024 * 1024 * 1024
    }

    var body: some View {
        ZStack {
            AlisColor.bg(scheme).ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                Rectangle().fill(AlisColor.border(scheme)).frame(height: 0.5)
                if !deviceSupported {
                    unsupportedScreen
                } else if showGallery {
                    galleryScreen
                } else {
                    generateScreen
                }
            }
        }
        .tint(AlisColor.clay(scheme))
        .sheet(isPresented: $pickingModel) {
            ModelPickerSheet(current: evaluator.modelKey) { key in
                evaluator.setModel(key)
                pickingModel = false
            }
        }
    }

    private var unsupportedScreen: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40)).foregroundStyle(AlisColor.clay(scheme))
            Text("This device isn't supported")
                .font(.system(size: 17, weight: .medium)).foregroundStyle(AlisColor.text(scheme))
            Text(
                "Alis Studio Mobile runs a multi-gigabyte diffusion model entirely on-device and "
                    + "needs an iPhone with 8 GB of RAM or more (iPhone 15 Pro, 16, 16 Pro, or newer).\n\n"
                    + "This device reports \(String(format: "%.1f", deviceRAMGiB)) GB."
            )
            .font(.system(size: 13)).foregroundStyle(AlisColor.text2(scheme))
            .multilineTextAlignment(.center).padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topBar: some View {
        HStack(spacing: 9) {
            PineLogo(size: 26)
            Text(showGallery ? "Gallery" : "Alis Studio Mobile")
                .font(.system(size: 15, weight: .medium)).foregroundStyle(AlisColor.text(scheme))
                .lineLimit(1).minimumScaleFactor(0.8).layoutPriority(1)
            if !showGallery {
                Text("v" + appVersion)
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(AlisColor.muted(scheme))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(AlisColor.surface1(scheme))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            Spacer()
            if deviceSupported {
                Button {
                    showGallery.toggle()
                    if showGallery { gallery = AlisGallery.list() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: showGallery ? "sparkles" : "square.grid.2x2")
                        Text(showGallery ? "Generate" : "Gallery").font(.system(size: 13))
                    }
                    .foregroundStyle(AlisColor.text(scheme))
                    .padding(.horizontal, 11).frame(height: 30)
                    .overlay(Capsule().stroke(AlisColor.border(scheme), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(AlisColor.surface(scheme))
    }

    private var generateScreen: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(AlisColor.surface1(scheme))
                if let image = evaluator.image {
                    Image(decorative: image, scale: 1)
                        .resizable().aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo").font(.system(size: 32))
                        Text("Your image appears here").font(.system(size: 13))
                    }
                    .foregroundStyle(AlisColor.muted(scheme))
                }
                if let progress = evaluator.progress {
                    VStack {
                        Spacer()
                        VStack(spacing: 5) {
                            Text(progress.title).font(.system(size: 11)).foregroundStyle(AlisColor.text2(scheme))
                            ProgressView(value: progress.current, total: progress.limit)
                            if progress.title == "Download" {
                                Text("First run downloads several GB — keep the screen on.")
                                    .font(.system(size: 10)).foregroundStyle(AlisColor.muted(scheme))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(10)
                        .background(AlisColor.surface(scheme).opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(10)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AlisColor.border(scheme), lineWidth: 0.5))

            composer
            modelRow
            settingsRow
        }
        .padding(14)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(
                "Describe an image to generate…", text: $prompt, axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.system(size: 16)).foregroundStyle(AlisColor.text(scheme))
            .lineLimit(1...5)

            HStack(spacing: 8) {
                if !prompt.isEmpty {
                    Button { prompt = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(AlisColor.muted(scheme))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button {
                    if busy { evaluator.cancel() }
                    else { evaluator.run(prompt: prompt, negativePrompt: "") }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: busy ? "stop.fill" : "sparkles")
                        Text(busy ? "Stop" : "Generate").font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(busy ? AlisColor.text(scheme) : AlisColor.onClay(scheme))
                    .padding(.horizontal, 16).frame(height: 36)
                    .background(busy ? AlisColor.surface1(scheme) : AlisColor.clay(scheme))
                    .clipShape(Capsule())
                    .overlay(busy ? Capsule().stroke(AlisColor.borderStrong(scheme), lineWidth: 0.5) : nil)
                }
                .buttonStyle(.plain)
                .disabled(prompt.isEmpty && !busy)
            }
        }
        .padding(13)
        .background(AlisColor.surface(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AlisColor.borderStrong(scheme), lineWidth: 1))
    }

    private var modelRow: some View {
        Button { pickingModel = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "cube").font(.system(size: 17)).foregroundStyle(AlisColor.text2(scheme))
                VStack(alignment: .leading, spacing: 1) {
                    Text(evaluator.modelKey == "sdxl-turbo" ? "SDXL-Turbo" : "SD-Turbo")
                        .font(.system(size: 13)).foregroundStyle(AlisColor.text(scheme))
                    Text(evaluator.modelKey == "sdxl-turbo" ? "4-bit · fp16-fix VAE" : "4-bit · fp16 VAE")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(AlisColor.muted(scheme))
                }
                Spacer()
                Image(systemName: "chevron.down").font(.system(size: 13)).foregroundStyle(AlisColor.muted(scheme))
            }
            .padding(.horizontal, 11).frame(height: 46)
            .background(AlisColor.surface(scheme))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AlisColor.borderStrong(scheme), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    private var settingsRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Steps").font(.system(size: 11)).foregroundStyle(AlisColor.muted(scheme))
                    Spacer()
                    Text("\(evaluator.steps)").font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(AlisColor.text(scheme))
                }
                Stepper("", value: $evaluator.steps, in: 1...8).labelsHidden().scaleEffect(0.85)
                    .frame(height: 16).disabled(busy)
            }
            .padding(8).background(AlisColor.surface1(scheme)).clipShape(RoundedRectangle(cornerRadius: 8))

            statCard("Size", "512²")
            statCard("VAE", evaluator.modelKey == "sdxl-turbo" ? "fp16-fix" : "fp16")
        }
    }

    private func statCard(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundStyle(AlisColor.muted(scheme))
            Text(value).font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(AlisColor.text(scheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8).background(AlisColor.surface1(scheme)).clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var galleryScreen: some View {
        ScrollView {
            if gallery.isEmpty {
                Text("No images yet. Generate one to start your gallery.")
                    .font(.system(size: 14)).foregroundStyle(AlisColor.muted(scheme))
                    .multilineTextAlignment(.center).padding(.top, 60).padding(.horizontal, 30)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(gallery) { item in
                        GalleryCard(item: item) {
                            prompt = item.prompt
                            showGallery = false
                        } onDelete: {
                            AlisGallery.delete(item.id)
                            gallery = AlisGallery.list()
                        }
                    }
                }
                .padding(14)
            }
        }
    }
}

// MARK: - Model picker sheet (Style-B)

struct ModelPickerSheet: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    let current: String
    let onSelect: (String) -> Void

    private let models: [(key: String, name: String, sub: String, note: String)] = [
        ("sdxl-turbo", "SDXL-Turbo", "4-bit · fp16-fix VAE · ~4.3 GB", "Best quality"),
        ("sd-turbo", "SD-Turbo", "4-bit · fp16 VAE · ~3.4 GB", "Fastest"),
    ]

    var body: some View {
        ZStack {
            AlisColor.bg(scheme).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Model").font(.system(size: 17, weight: .medium)).foregroundStyle(AlisColor.text(scheme))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundStyle(AlisColor.text2(scheme))
                    }.buttonStyle(.plain)
                }
                ForEach(models, id: \.key) { m in
                    Button { onSelect(m.key) } label: {
                        HStack(spacing: 11) {
                            Image(systemName: "cube").font(.system(size: 18)).foregroundStyle(AlisColor.text2(scheme))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.name).font(.system(size: 14)).foregroundStyle(AlisColor.text(scheme))
                                Text(m.sub).font(.system(size: 11, design: .monospaced)).foregroundStyle(AlisColor.muted(scheme))
                            }
                            Spacer()
                            if m.key == current {
                                Image(systemName: "checkmark").foregroundStyle(AlisColor.clay(scheme))
                            } else {
                                Text(m.note).font(.system(size: 11)).foregroundStyle(AlisColor.text2(scheme))
                            }
                        }
                        .padding(12)
                        .background(AlisColor.surface(scheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(m.key == current ? AlisColor.clay(scheme) : AlisColor.border(scheme),
                                    lineWidth: m.key == current ? 1.5 : 0.5))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(18)
        }
        #if os(iOS)
            .presentationDetents([.height(230)])
        #endif
    }
}

// MARK: - Gallery

struct GalleryItem: Identifiable {
    let id: String
    let image: CGImage?
    let prompt: String
    let model: String
    let steps: Int
}

struct GalleryCard: View {
    @Environment(\.colorScheme) private var scheme
    let item: GalleryItem
    let onReuse: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Rectangle().fill(AlisColor.surface1(scheme))
                if let img = item.image {
                    Image(decorative: img, scale: 1).resizable().aspectRatio(contentMode: .fill)
                }
            }
            .aspectRatio(1, contentMode: .fill).clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(item.prompt).font(.system(size: 12)).foregroundStyle(AlisColor.text2(scheme))
                    .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 9) {
                    Text("\(item.model == "sdxl-turbo" ? "SDXL" : "SD-T") · \(item.steps) st")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(AlisColor.muted(scheme))
                    Spacer()
                    Button(action: onReuse) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 13)).foregroundStyle(AlisColor.text2(scheme))
                    }.buttonStyle(.plain)
                    Button(action: onDelete) {
                        Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(AlisColor.text2(scheme))
                    }.buttonStyle(.plain)
                }
            }
            .padding(8)
        }
        .background(AlisColor.surface(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AlisColor.border(scheme), lineWidth: 0.5))
    }
}

enum AlisGallery {
    static var dir: URL {
        let d = URL.documentsDirectory.appending(path: "gallery")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func save(_ img: CGImage, prompt: String, model: String, steps: Int) {
        let id = UUID().uuidString
        ImageSaver.savePNG(img, to: dir.appending(path: "\(id).png"))
        let meta = ["prompt": prompt, "model": model, "steps": String(steps)]
        if let data = try? JSONSerialization.data(withJSONObject: meta) {
            try? data.write(to: dir.appending(path: "\(id).json"))
        }
    }

    static func delete(_ id: String) {
        try? FileManager.default.removeItem(at: dir.appending(path: "\(id).png"))
        try? FileManager.default.removeItem(at: dir.appending(path: "\(id).json"))
    }

    static func list() -> [GalleryItem] {
        let files =
            (try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let pngs = files.filter { $0.pathExtension == "png" }
            .sorted { (mod($0) ?? .distantPast) > (mod($1) ?? .distantPast) }
        return pngs.map { url in
            let id = url.deletingPathExtension().lastPathComponent
            var prompt = ""
            var model = ""
            var steps = 0
            if let d = try? Data(contentsOf: dir.appending(path: "\(id).json")),
                let m = (try? JSONSerialization.jsonObject(with: d)) as? [String: String]
            {
                prompt = m["prompt"] ?? ""
                model = m["model"] ?? ""
                steps = Int(m["steps"] ?? "") ?? 0
            }
            return GalleryItem(id: id, image: loadCG(url), prompt: prompt, model: model, steps: steps)
        }
    }

    private static func loadCG(_ url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    private static func mod(_ url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}

/// Progress reporting with a title.
struct Progress: Equatable {
    let title: String
    let current: Double
    let limit: Double
}

/// Async model factory
actor ModelFactory {

    enum LoadState {
        case idle
        case loading(Task<ModelContainer<TextToImageGenerator>, Error>)
        case loaded(ModelContainer<TextToImageGenerator>)
    }

    enum SDError: LocalizedError {
        case unableToLoad

        var errorDescription: String? {
            switch self {
            case .unableToLoad:
                return String(
                    localized:
                        "Unable to load the Stable Diffusion model. Please check your internet connection or available storage space."
                )
            }
        }
    }

    // Alis: model chosen at init (the picker rebuilds the factory); env overrides the default.
    public nonisolated let configuration: StableDiffusionConfiguration

    public nonisolated var modelKey: String {
        configuration.id.localizedCaseInsensitiveContains("sdxl") ? "sdxl-turbo" : "sd-turbo"
    }

    public nonisolated let canShowProgress: Bool
    public nonisolated let canUseNegativeText: Bool

    private var loadState = LoadState.idle
    private var loadConfiguration = LoadConfiguration(float16: true, quantize: true)

    private(set) var conserveMemory = false
    private var memoryConfigured = false

    init(preset: StableDiffusionConfiguration.Preset? = nil) {
        // Default to SDXL-Turbo (best 8GB-stable quality); the picker passes a preset to switch.
        let cfg = (preset ?? .sdxlTurbo).configuration
        self.configuration = cfg
        let defaultParameters = cfg.defaultParameters()
        self.canShowProgress = defaultParameters.steps > 4
        self.canUseNegativeText = defaultParameters.cfgWeight > 1
    }

    /// Configure MLX memory once, lazily — keeps MLX untouched until the first generation so the
    /// UI renders even where MLX itself can't run (e.g. the iOS simulator).
    private func configureMemory() {
        guard !memoryConfigured else { return }
        memoryConfigured = true
        conserveMemory = Memory.memoryLimit < 8 * 1024 * 1024 * 1024
        if conserveMemory {
            print("conserving memory")
            loadConfiguration.quantize = true
            Memory.cacheLimit = 1 * 1024 * 1024
            Memory.memoryLimit = 4096 * 1024 * 1024
        } else {
            Memory.cacheLimit = 256 * 1024 * 1024
        }
    }

    public func load(reportProgress: @escaping @Sendable (Progress) -> Void) async throws
        -> ModelContainer<TextToImageGenerator>
    {
        configureMemory()
        let conserve = conserveMemory
        switch loadState {
        case .idle:
            let task = Task {
                do {
                    try await configuration.download { progress in
                        if progress.fractionCompleted < 0.99 {
                            reportProgress(
                                .init(
                                    title: "Download", current: progress.fractionCompleted * 100,
                                    limit: 100))
                        }
                    }
                    // SDXL also needs the drop-in fp16-stable VAE (the loader uses it automatically).
                    if configuration.id.localizedCaseInsensitiveContains("sdxl") {
                        try await downloadVAERepo("madebyollin/sdxl-vae-fp16-fix")
                    }
                } catch {
                    let nserror = error as NSError
                    if nserror.domain == NSURLErrorDomain
                        && nserror.code == NSURLErrorNotConnectedToInternet
                    {
                        // Internet connection appears to be offline -- fall back to loading from
                        // the local directory
                        reportProgress(.init(title: "Offline", current: 100, limit: 100))
                    } else {
                        throw error
                    }
                }

                let container = try ModelContainer<TextToImageGenerator>.createTextToImageGenerator(
                    configuration: configuration, loadConfiguration: loadConfiguration)

                await container.setConserveMemory(conserve)

                try await container.perform { model in
                    reportProgress(.init(title: "Loading weights", current: 0, limit: 1))
                    if !conserve {
                        model.ensureLoaded()
                    }
                }

                return container
            }
            self.loadState = .loading(task)

            let container = try await task.value

            if conserveMemory {
                // if conserving memory return the model but do not keep it in memory
                self.loadState = .idle
            } else {
                // cache the model in memory to make it faster to run with new prompts
                self.loadState = .loaded(container)
            }

            return container

        case .loading(let task):
            let generator = try await task.value
            return generator

        case .loaded(let generator):
            return generator
        }
    }

}

@Observable @MainActor
class StableDiffusionEvaluator {

    var progress: Progress?
    var message: String?
    var image: CGImage?
    var steps: Int = 4

    private(set) var modelFactory: ModelFactory
    var modelKey: String { modelFactory.modelKey }
    private var genTask: Task<Void, Never>?

    init(preset: StableDiffusionConfiguration.Preset? = nil) {
        self.modelFactory = ModelFactory(preset: preset)
    }

    /// Switch model (the picker): rebuilds the factory and clears the current image.
    func setModel(_ key: String) {
        guard key != modelKey else { return }
        cancel()
        image = nil
        modelFactory = ModelFactory(preset: key == "sd-turbo" ? .sdTurbo : .sdxlTurbo)
    }

    /// Start a generation as a cancellable task (Generate button).
    func run(prompt: String, negativePrompt: String) {
        genTask?.cancel()
        genTask = Task { await self.generate(prompt: prompt, negativePrompt: negativePrompt, showProgress: false) }
    }

    /// Stop button — cancels the in-flight generation (checked in the denoise loop).
    func cancel() {
        genTask?.cancel()
        genTask = nil
        progress = nil
    }

    @Sendable
    nonisolated private func updateProgress(progress: Progress?) {
        Task { @MainActor in
            self.progress = progress
        }
    }

    @Sendable
    nonisolated private func updateImage(image: CGImage?) {
        Task { @MainActor in
            self.image = image
        }
    }

    nonisolated private func display(decoded: MLXArray) {
        let raster = (decoded * 255).asType(.uint8).squeezed()
        let image = Image(raster).asCGImage()

        Task { @MainActor in
            updateImage(image: image)
        }
    }

    func generate(prompt: String, negativePrompt: String, showProgress: Bool) async {
        progress = .init(title: "Preparing", current: 0, limit: 1)
        message = nil

        do {
            // The optionals are used to discard parts of the model as it runs, to conserve
            // memory on devices with less RAM.
            let container = try await modelFactory.load(reportProgress: updateProgress)

            // Capture MainActor state into locals so the @Sendable stages can use them.
            let cfg = modelFactory.configuration
            let stepCount = self.steps

            let finalImage = try await container.performTwoStage { generator in
                var parameters = cfg.defaultParameters()
                parameters.prompt = prompt
                parameters.negativePrompt = negativePrompt
                parameters.steps = stepCount

                // Generate the latent images. This is fast as it is just generating
                // the graphs that will be evaluated below.
                let latents: DenoiseIterator? = generator.generateLatents(parameters: parameters)

                // When conserveMemory is true this will discard the first part of
                // the model and just evaluate the decode portion.
                return (generator.detachedDecoder(), latents)

            } second: { decoder, latents -> CGImage? in
                var lastXt: MLXArray?
                for (i, xt) in latents!.enumerated() {
                    if Task.isCancelled { break }
                    lastXt = nil
                    eval(xt)
                    lastXt = xt

                    if showProgress, i % 10 == 0 {
                        display(decoded: decoder(xt))
                    }

                    updateProgress(
                        progress: .init(
                            title: "Generating", current: Double(i + 1),
                            limit: Double(stepCount)))
                }
                updateProgress(progress: nil)

                // Decode the final latent and return the exact CGImage (no observable-state race).
                guard !Task.isCancelled, let lastXt else { return nil }
                let raster = (decoder(lastXt) * 255).asType(.uint8).squeezed()
                return Image(raster).asCGImage()
            }

            // Release MLX buffers between generations so the peak doesn't accumulate toward jetsam.
            Memory.clearCache()

            // Show + persist the exact final image (returned from the pipeline, not read back).
            if let finalImage {
                image = finalImage
                AlisGallery.save(finalImage, prompt: prompt, model: modelKey, steps: steps)
            }

        } catch {
            progress = nil
            message = "Failed: \(error)"
        }
    }
}

// MARK: - PNG saver
import ImageIO
import UniformTypeIdentifiers

enum ImageSaver {
    static func savePNG(_ cg: CGImage, to url: URL) {
        guard
            let dest = CGImageDestinationCreateWithURL(
                url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(dest, cg, nil)
        CGImageDestinationFinalize(dest)
    }
}
