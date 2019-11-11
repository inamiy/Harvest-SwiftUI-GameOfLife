import Combine

/// Deferred publisher that executes `run` and injects its result to next `Input`.
func simpleEffectPublisher<Input, Value>(
    run: @escaping () throws -> Value,
    inject: @escaping (Value?) -> Input
) -> Deferred<Just<Input>>
{
    Deferred {
        do {
            let value = try run()
            return Just(inject(value))
        }
        catch {
            assertionFailure(error.localizedDescription)
            return Just(inject(nil))
        }
    }
}
