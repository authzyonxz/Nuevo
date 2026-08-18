import Foundation

public struct VIPPackage: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let description: String
    public let filename: String
    public let resourceName: String
    public let hasAntenna: Bool
    
    public var icon: String {
        return hasAntenna ? "📡" : "📁"
    }
}

public class VIPPackageService {
    public static let shared = VIPPackageService()
    
    public let packages: [VIPPackage] = [
        VIPPackage(
            name: "HS ALTO VIP 1.126.1 V8",
            description: "Aumento significativo na taxa de Headshot. Mira puxa para a cabeça automaticamente.",
            filename: "assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D",
            resourceName: "hs_alto_assetindexer",
            hasAntenna: false
        ),
        VIPPackage(
            name: "HS PESCOÇO 90% VIP 1.126.1 📡",
            description: "Mira focada no pescoço para evitar detecção. Inclui Antena para localização de inimigos.",
            filename: "assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D",
            resourceName: "hs_pescoco_antena_assetindexer",
            hasAntenna: true
        ),
        VIPPackage(
            name: "HS PEITO 98% VIP 1.126.1 V4",
            description: "HS focado no peito. Alta taxa de eliminação com baixo risco de ban.",
            filename: "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceName: "hs_peito_cacheres",
            hasAntenna: false
        ),
        VIPPackage(
            name: "MAGIC BULLET FF MAX 2.126.1",
            description: "Balas mágicas que atingem o alvo mesmo se a mira não estiver perfeita. Exclusivo para FF MAX.",
            filename: "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceName: "magic_bullet_max_cacheres",
            hasAntenna: false
        )
    ]
    
    public func getURL(for package: VIPPackage) -> URL? {
        // Tenta primeiro no subdiretório, depois na raiz
        if let url = Bundle.main.url(forResource: package.resourceName, withExtension: nil, subdirectory: "PackageFixtures/VIP") {
            return url
        }
        return Bundle.main.url(forResource: package.resourceName, withExtension: nil)
    }
    
    public func getPayload(for package: VIPPackage) -> Data? {
        guard let url = getURL(for: package) else { return nil }
        return try? Data(contentsOf: url)
    }
}
