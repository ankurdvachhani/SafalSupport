import Foundation
import Combine

protocol BaseViewModel: AnyObject {
    var isLoading: CurrentValueSubject<Bool, Never> { get }
    var error: CurrentValueSubject<Error?, Never> { get }
}

class ViewModel: BaseViewModel {
    var isLoading = CurrentValueSubject<Bool, Never>(false)
    var error = CurrentValueSubject<Error?, Never>(nil)
    var cancellables = Set<AnyCancellable>()
    
    func handleError(_ error: Error) {
        Logger.error(error.localizedDescription)
        self.error.send(error)
    }
    
    func load(_ operation: @escaping () async throws -> Void) {
        isLoading.send(true)
        
        Task { @MainActor in
            do {
                try await operation()
            } catch {
                handleError(error)
            }
            isLoading.send(false)
        }
    }
} 