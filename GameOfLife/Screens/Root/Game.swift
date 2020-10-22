import CoreGraphics
import Combine
import FunOptics
import Harvest
import HarvestOptics

/// Conway's Game-of-Life game engine namespace.
public enum Game {}

extension Game
{
    public enum Input
    {
        case startTimer
        case stopTimer
        case tick

        case tap(x: Int, y: Int)
        case drag(x: Int, y: Int)
        case dragEnd

        case resetBoard
        case updateBoardSize(CGSize)

        case updatePattern(Pattern)
    }

    struct State
    {
        var cellLength: CGFloat
        var boardSize: Board.Size

        fileprivate var dragState: DragState = .idle

        fileprivate(set) var board: Board

        var selectedPattern: Pattern

        var timerInterval: TimeInterval = 0.1
        var isRunningTimer = false

        public init(
            pattern: Pattern,
            cellLength: CGFloat = 5
        )
        {
            self.cellLength = cellLength
            self.boardSize = .zero
            self.board = pattern.makeBoard(size: self.boardSize)
            self.selectedPattern = pattern
        }

        enum DragState: Equatable
        {
            case idle
            case dragging(isFirstAlive: Bool)
        }
    }

    static func effectMapping() -> EffectMapping
    {
        .makeInout { input, state, world in
            switch input {
            case let .updateBoardSize(size):
                let width = Int(size.width / state.cellLength)
                let height = Int(size.height / state.cellLength)
                state.boardSize = .init(width: width, height: height)
                state.board = state.selectedPattern.makeBoard(size: state.boardSize)

            case .startTimer:
                state.isRunningTimer = true
                return timerEffect(interval: state.timerInterval, world: world)

            case .stopTimer:
                state.isRunningTimer = false
                return .cancel(.timer)

            case .tick:
                let newBoard = runGame(board: state.board, boardSize: state.boardSize)
                let isSameBoard = state.board == newBoard
                state.board = newBoard

                // Stop timer if new board is same as previous.
                return state.board.cells.isEmpty || isSameBoard
                    ? Effect(Just(.stopTimer))
                    : .empty

            case let .tap(x, y):
                state.board[x, y].toggle()

            case let .drag(x, y):
                let newFlag = state.dragState.dragging ?? !state.board[x, y]
                state.dragState = .dragging(isFirstAlive: newFlag)
                state.board[x, y] = newFlag

            case .dragEnd:
                state.dragState = .idle

            case .resetBoard:
                state.board = state.selectedPattern.makeBoard(size: state.boardSize)

            case let .updatePattern(pattern):
                state.board = pattern.makeBoard(size: state.boardSize)
                state.selectedPattern = pattern
            }

            return .empty
        }
    }

    typealias EffectMapping = Harvester<Input, State>.EffectMapping<World, EffectQueue, EffectID>

    typealias Effect = Harvest.Effect<Input, EffectQueue, EffectID>

    typealias EffectQueue = BasicEffectQueue

    public enum EffectID: Equatable
    {
        case timer
    }

    struct World
    {
        let timer: (TimeInterval) -> AnyPublisher<Void, Never> = defaultTimer
    }
}

// MARK: - Effects

extension Game
{
    private static func defaultTimer(interval: TimeInterval) -> AnyPublisher<Void, Never>
    {
        Timer.publish(every: interval, tolerance: 0.01, on: .main, in: .common)
            .autoconnect()
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    private static func timerEffect(interval: TimeInterval, world: World) -> Effect
    {
        world.timer(interval)
            .map { _ in Input.tick }
            .toEffect(queue: .defaultEffectQueue, id: .timer)
    }
}

// MARK: - Run Game

extension Game
{
    /// FIXME: Needs some performance improvements.
    private static func runGame(board: Board, boardSize: Board.Size) -> Board
    {
        let rows = boardSize.height
        let columns = boardSize.width

        var newBoard = Board()
        for y in 0 ..< rows {
            for x in 0 ..< columns {
                var neighborLiveCount = 0
                for dy in -1 ... 1 {
                    for dx in -1 ... 1 {
                        if dx == 0 && dy == 0 { continue }
                        let x_ = x + dx
                        let y_ = y + dy
                        guard x_ >= 0 && x_ < columns && y_ >= 0 && y_ < rows else { continue }

                        if board[x_, y_] {
                            neighborLiveCount += 1
                        }
                    }
                }

                switch neighborLiveCount {
                case 2:
                    if board[x, y] {
                        newBoard[x, y] = true
                    }
                case 3:
                    newBoard[x, y] = true
                default:
                    newBoard[x, y] = false
                }
            }
        }
        return newBoard
    }
}

// MARK: - Enum Properties

extension Game.State.DragState
{
    var dragging: Bool?
    {
        guard case let .dragging(value) = self else { return nil }
        return value
    }
}
