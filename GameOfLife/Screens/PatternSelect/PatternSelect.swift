import Combine
import FunOptics
import Harvest
import HarvestOptics

/// Game-of-Life pattern selection namespace.
public enum PatternSelect {}

extension PatternSelect
{
    public enum Input
    {
        case loadPatternFiles
        case didLoadPatternFiles([Section<Void>])
        case didSelectPatternURL(URL)
        case didParsePatternFile(Pattern?)

        case updateSearchText(String)

        case favorite(Favorite.Input)
    }

    struct State
    {
        var status: Status = .loading
        var searchText: String = ""
        var favorite: Favorite.State

        init(favoritePatternNames: [String] = [])
        {
            self.favorite = Favorite.State(patternNames: favoritePatternNames)
        }

        var filteredSections: [Section<Bool>]
        {
            let sections = self.status.loaded ?? []

            let lazySections2 = sections
                .lazy
                .filter { !$0.rows.isEmpty }
                .map { section in
                    Section<Bool>(
                        title: section.title,
                        rows: section.rows
                            .lazy
                            .filter { row in
                                if self.searchText.isEmpty { return true }
                                return row.title.lowercased().contains(self.searchText.lowercased())
                            }
                            .map { row in
                                Row<Bool>(
                                    title: row.title,
                                    url: row.url,
                                    isFavorite: self.favorite.patternNames.contains(row.title)
                                )
                            }
                    )
                }

            var sections2 = Array(lazySections2)

            sections2.insert(
                Section(
                    title: "Favorites",
                    rows: sections2.lazy.flatMap { $0.rows }
                        .filter { self.favorite.patternNames.contains($0.title) }
                ),
                at: 0
            )

            return sections2
        }

        enum Status
        {
            case loading
            case loaded([Section<Void>])
        }
    }

    static func effectMapping<S: Scheduler>() -> EffectMapping<S>
    {
        .reduce(.all, [
            self._effectMapping(),

            Favorite.effectMapping()
                .contramapWorld { .init(fileScheduler: $0.fileScheduler) }
                .transform(input: .fromEnum(\.favorite))
                .transform(state: .init(lens: Lens(\.favorite)))
        ])
    }

    private static func _effectMapping<S: Scheduler>() -> EffectMapping<S>
    {
        .makeInout { input, state, world in
            switch input {
            case .loadPatternFiles:
                return self.loadPatternFilesEffect(world: world)

            case let .didLoadPatternFiles(sections):
                state.status = .loaded(sections)

            case let .didSelectPatternURL(url):
                state.status = .loading
                return self.parsePatternFileEffect(url: url, world: world)

            case .didParsePatternFile:
                return nil

            case let .updateSearchText(text):
                state.searchText = text

            case .favorite:
                break
            }

            return .empty
        }
    }

    typealias EffectMapping<S: Scheduler> = Harvester<Input, State>.EffectMapping<World<S>, EffectQueue, EffectID>

    typealias Effect = Harvest.Effect<Input, EffectQueue, EffectID>

    typealias EffectQueue = BasicEffectQueue

    typealias EffectID = Never

    struct World<S: Scheduler>
    {
        var loadPatterns: () throws -> [PatternSelect.Section<Void>] = defaultLoadPatterns

        var parseRunLengthEncoded: (URL) throws -> Pattern = Pattern.parseRunLengthEncoded(url:)

        var fileScheduler: S
    }
}

// MARK: - Section & Row

extension PatternSelect
{
    public struct Section<Fav>: Identifiable
    {
        var title: String
        var rows: [Row<Fav>]

        public var id: String { self.title }
    }

    struct Row<Fav>: Identifiable
    {
        var title: String
        var url: URL
        var isFavorite: Fav

        var id: String { self.title }
    }
}

// MARK: - Effects

extension PatternSelect
{
    private static func defaultLoadPatterns() throws -> [PatternSelect.Section<Void>]
    {
        // Fake heavy loading just for fun.
        Thread.sleep(forTimeInterval: 0.5)

        let urls = Bundle(for: BundleLocator.self)
            .urls(forResourcesWithExtension: "", subdirectory: "GameOfLife-Patterns")
            ?? []

        let sections = try urls
            .lazy
            .filter { $0.hasDirectoryPath }
            .compactMap { url -> Section<Void>? in
                let dirName = url.lastPathComponent
                let subURLs = try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil
                )
                return Section(
                    title: "Pattern: \(dirName)",
                    rows: subURLs
                        .lazy
                        .map { subURL -> Row<Void> in
                            let title = subURL.deletingPathExtension().lastPathComponent
                            return Row(
                                title: title,
                                url: subURL,
                                isFavorite: ()
                            )
                        }
                        .sorted(by: { $0.title < $1.title })
                )
            }
            .sorted(by: { $0.title < $1.title })

        return sections
    }

    private static func loadPatternFilesEffect<S: Scheduler>(world: World<S>) -> Effect
    {
        simpleEffectPublisher(
            run: world.loadPatterns,
            inject: { Input.didLoadPatternFiles($0 ?? []) }
        )
        .subscribe(on: world.fileScheduler)
        .toEffect()
    }

    private static func parsePatternFileEffect<S: Scheduler>(url: URL, world: World<S>) -> Effect
    {
        simpleEffectPublisher(
            run: { try Pattern.parseRunLengthEncoded(url: url) },
            inject: Input.didParsePatternFile
        )
        .subscribe(on: world.fileScheduler)
        .toEffect()
    }
}

// MARK: - Enum Properties

extension PatternSelect.Input
{
    var favorite: Favorite.Input?
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
}

extension PatternSelect.State.Status
{
    public var isLoading: Bool
    {
        guard case .loading = self else { return false }
        return true
    }

    public var loaded: [PatternSelect.Section<Void>]?
    {
        guard case let .loaded(value) = self else { return nil }
        return value
    }
}
