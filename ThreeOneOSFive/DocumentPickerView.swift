import SwiftUI
import UniformTypeIdentifiers

public struct DocumentPickerView: UIViewControllerRepresentable {
    public var onPick: (URL) -> Void
    
    public init(onPick: @escaping (URL) -> Void) {
        self.onPick = onPick
    }
    
    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Permitir arquivos .onyx, .zip, .json, binários e arquivamento genérico
        let supportedTypes: [UTType] = [.data, .item, .content, .archive, .json]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public final class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            // Iniciar acesso ao recurso de segurança se necessário
            guard url.startAccessingSecurityScopedResource() else {
                parent.onPick(url)
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            // Copiar para diretório temporário para acesso seguro
            let tempDir = FileManager.default.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: tempURL)
            do {
                try FileManager.default.copyItem(at: url, to: tempURL)
                parent.onPick(tempURL)
            } catch {
                parent.onPick(url)
            }
        }
        
        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Cancelled
        }
    }
}
