import CoreGraphics
import Combine
import FunOptics
import Harvest
import HarvestOptics

/// Conway's Game-of-Life root namespace.
///
/// - SeeAlso:
///   - https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life
///   - https://www.conwaylife.com/wiki/Category:Patterns
///   - https://apps.apple.com/us/app/game-of-life/id1377718068?mt=12
public enum Root {}

extension Root
{
    public enum Input
    {
        case presentPatternSelect
        case dismissPatternSelect

        case game(Game.Input)
        case favorite(Favorite.Input)
        case patternSelect(PatternSelect.Input)
    }

    public struct State
    {
        var game: Game.State
        var favorite: Favorite.State
        var patternSelect: PatternSelect.State?

        public init(pattern: Pattern)
        {
            self.game = Game.State(pattern: pattern)
            self.favorite = Favorite.State()
        }

        var isFavoritePattern: Bool
        {
            self.favorite.patternNames.contains(self.game.selectedPattern.title)
        }
    }

    public static func effectMapping<S: Scheduler>() -> EffectMapping<S>
    {
        .reduce(.all, [
            self._effectMapping(),

            Game.effectMapping()
                .contramapWorld { _ in .init() }
                .transform(input: .fromEnum(\Root.Input.game))
                .transform(state: .init(lens: Lens(\Root.State.game)))
                .transform(id: Prism(tryGet: { $0.game }, inject: EffectID.game)),

            Favorite.effectMapping()
                .contramapWorld { .init(fileScheduler: $0.fileScheduler) }
                .transform(input: .fromEnum(\Root.Input.favorite))
                .transform(state: .init(lens: Lens(\Root.State.favorite)))
                .transform(id: .never),

            PatternSelect.effectMapping()
                .contramapWorld { .init(fileScheduler: $0.fileScheduler) }
                .transform(input: .fromEnum(\.patternSelect))
                .transform(state: Lens(\.patternSelect) >>> some())
                .transform(id: .never)
        ])
    }

    private static func _effectMapping<S: Scheduler>() -> EffectMapping<S>
    {
        .makeInout { input, state, world in
            switch input {
            case .presentPatternSelect:
                state.patternSelect = PatternSelect.State(favoritePatternNames: state.favorite.patternNames)
                return .empty

            case .dismissPatternSelect:
                state.patternSelect = nil
                return .empty

            case let .patternSelect(.didParsePatternFile(pattern)):
                state.patternSelect = nil

                var gameEffect: Effect<S> = .empty

                // FIXME:
                // This logic basically tee-ing `EffectMapping` between `Root` (parent) and `Game` (child),
                // which could possibly be improved by more elegant `EffectMapping` composition.
                if let pattern = pattern {
                    if let (newGameState, effect) = Game.effectMapping().run(.updatePattern(pattern), state.game, .init()) {
                        state.game = newGameState

                        gameEffect = effect
                            .mapInput(Root.Input.game)
                            .transform(id: Prism(tryGet: { $0.game }, inject: EffectID.game))
                    }
                }
                else {
                    // TODO: show parse failure alert
                }

                return .empty + gameEffect

            case let .patternSelect(.favorite(.addFavorite(patternName))):
                state.favorite.patternNames.append(patternName)
                return .empty

            case let .patternSelect(.favorite(.removeFavorite(patternName))):
                state.favorite.patternNames.removeAll { $0 == patternName }
                return .empty

            case .game,
                .favorite,
                .patternSelect:
                return nil
            }
        }
    }

    public typealias EffectMapping<S: Scheduler> = Harvester<Input, State>.EffectMapping<World<S>, EffectQueue, EffectID>

    public typealias Effect<S: Scheduler> = Harvest.Effect<Input, EffectQueue, EffectID>

    public typealias EffectQueue = BasicEffectQueue

    public enum EffectID: Equatable
    {
        case game(Game.EffectID)

        var game: Game.EffectID?
        {
            guard case let .game(value) = self else { return nil }
            return value
        }
    }

    public struct World<S: Scheduler>
    {
        public var fileScheduler: S

        public init(fileScheduler: S)
        {
            self.fileScheduler = fileScheduler
        }
    }
}

// MARK: - Enum Properties

extension Root.Input
{
    public var game: Game.Input?
    {
        get {
            guard case let .game(value) = self else { return nil }
            return value
        }
        set {
            guard case .game = self, let newValue = newValue else { return }
            self = .game(newValue)
        }
    }

    public var favorite: Favorite.Input?
    {
        get {
            guard case let .favorite(value) = self else { return nil }
            return value
        }
        set {
            guard case .favorite = self, let newValue = newValue else { return }
            self = .favorite(newValue)
        }
    }

    public var patternSelect: PatternSelect.Input?
    {
        get {
            guard case let .patternSelect(value) = self else { return nil }
            return value
        }
        set {
            guard case .patternSelect = self, let newValue = newValue else { return }
            self = .patternSelect(newValue)
        }
    }
}
