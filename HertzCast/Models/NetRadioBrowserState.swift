import Foundation

class NetRadioBrowserState: ObservableObject {
    static let shared = NetRadioBrowserState()
    private init() {}

    @Published var stack:       [NetRadioLayer] = []
    @Published var isLoading    = false
    @Published var searchText   = ""
    @Published var searchIndex  = -1
    @Published var searchLayer  = 0
    @Published var errorMsg:    String? = nil

    var current: NetRadioLayer? { stack.last }

    func reset() {
        stack = []
        isLoading = false
        searchText = ""
        searchIndex = -1
        errorMsg = nil
    }
}
