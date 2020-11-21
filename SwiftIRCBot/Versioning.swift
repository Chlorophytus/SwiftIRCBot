enum VersioningStatus {
    case Alpha
    case Beta
    case GoldenMaster
    case Stable
}

func GetVersionString(Version: VersioningStatus) -> String {
    switch Version {
    case .Alpha: return "-alpha"
    case .Beta: return "-beta"
    case .GoldenMaster: return "-gm"
    case .Stable: return "-stable"
    }
}