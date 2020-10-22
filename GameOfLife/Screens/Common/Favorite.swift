import Combine
import Harvest

/// Game-of-Life favorite pattern namespace.
public enum Favorite {}

extension Favorite
{
    public enum Input
    {
        case addFavorite(patternName: String)
        case removeFavorite(patternName: String)

        case loadFavorites
        case didLoadFavorites(patternNames: [String]?)
        case saveFavorites
        case didSaveFavorites
    }

    struct State
    {
        /// Favorite pattern names.
        var patternNames: [String] = []
    }

    static func effectMapping<S: Scheduler>() -> EffectMapping<S>
    {
        .makeInout { input, state, world in
            switch input {
            case let .addFavorite(patternName):
                state.patternNames.removeAll { $0 == patternName }
                state.patternNames.insert(patternName, at: 0)
                return self.saveFavoritesEffect(patternNames: state.patternNames, world: world)

            case let .removeFavorite(patternName):
                state.patternNames.removeAll { $0 == patternName }
                return self.saveFavoritesEffect(patternNames: state.patternNames, world: world)

            case .loadFavorites:
                return self.loadFavoritesEffect(world: world)

            case let .didLoadFavorites(patternNames):
                state.patternNames = patternNames ?? []

            case .saveFavorites:
                return self.saveFavoritesEffect(patternNames: state.patternNames, world: world)

            case .didSaveFavorites:
                break
            }

            return .empty
        }
    }

    typealias EffectMapping<S: Scheduler> = Harvester<Input, State>.EffectMapping<World<S>, EffectQueue, EffectID>

    typealias Effect<S: Scheduler> = Harvest.Effect<Input, EffectQueue, EffectID>

    typealias EffectQueue = BasicEffectQueue

    typealias EffectID = Never

    struct World<S: Scheduler>
    {
        var loadFavorites: () throws -> [String] = defaultLoadFavorites

        var saveFavorites: ([String]) throws -> Void = defaultSaveFavorites

        var fileScheduler: S
    }
}

// MARK: - Effects

extension Favorite
{
    private static func defaultLoadFavorites() throws -> [String]
    {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let documentsURL = URL(fileURLWithPath: documentsPath)
        let jsonURL = documentsURL.appendingPathComponent(self.favoritesFileName)

        if !FileManager.default.fileExists(atPath: jsonURL.path) {
            return Pattern.defaultPatternNames
        }

        let data = try Data(contentsOf: jsonURL)
        let patternNames = try JSONDecoder().decode([String].self, from: data)

        return patternNames
    }

    private static func loadFavoritesEffect<S: Scheduler>(world: World<S>) -> Effect<S>
    {
        simpleEffectPublisher(
            run: world.loadFavorites,
            inject: Input.didLoadFavorites
        )
        .subscribe(on: world.fileScheduler)
        .toEffect()
    }

    private static func defaultSaveFavorites(patternNames: [String]) throws
    {
        let data = try JSONEncoder().encode(patternNames)
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let documentsURL = URL(fileURLWithPath: documentsPath)
        let jsonURL = documentsURL.appendingPathComponent(self.favoritesFileName)
        try data.write(to: jsonURL)

        #if DEBUG
        print("===> Saved JSON to \(jsonURL)")
        #endif
    }

    private static func saveFavoritesEffect<S: Scheduler>(patternNames: [String], world: World<S>) -> Effect<S>
    {
        simpleEffectPublisher(
            run: { try world.saveFavorites(patternNames) },
            inject: { _ in Input.didSaveFavorites }
        )
        .subscribe(on: world.fileScheduler)
        .toEffect()
    }

    private static let favoritesFileName = "favorites.json"
}
