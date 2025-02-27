import SwiftUI
import HarvestStore

struct GameView: View
{
    private let store: Store<Game.Input, Game.State>.Proxy
    private let geometrySize: CGSize

    init(
        store: Store<Game.Input, Game.State>.Proxy,
        geometrySize: CGSize
    )
    {
        self.store = store
        self.geometrySize = geometrySize
    }

    var body: some View
    {
        let cellLength = self.store.state.cellLength
        let contentSize = CGSize(
            width: cellLength * CGFloat(self.store.state.boardSize.width),
            height: cellLength * CGFloat(self.store.state.boardSize.height)
        )

        return ZStack(alignment: .topLeading) {
            ForEach(self.store.state.board.liveCellPoints) { point in
                self.cell(point: point, cellLength: cellLength)
            }

            // NOTE:
            // `TapView` is used to detect touched location which is not possible
            // as of Xcode 11.1 SwiftUI.
            TapView { point in
                let offset = _offset(at: point, cellLength: cellLength)
                self.store.send(.tap(x: offset.x, y: offset.y))
            }
            .border(Color.green, width: 2)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let offset = _offset(at: value.location, cellLength: cellLength)
                        self.store.send(.drag(x: offset.x, y: offset.y))
                    }
                    .onEnded { _ in
                        self.store.send(.dragEnd)
                    }
            )

            // e.g. Displays "76 x 140"
//            Text("\(self.store.state.boardSize.description)")
//                .frame(maxWidth: .infinity, alignment: .trailing)
//                .padding(4)
        }
        .frame(
            width: contentSize.width,
            height: contentSize.height
        )
        .offset( // move to top-left rather than center
            x: (contentSize.width - geometrySize.width) / 2,
            y: (contentSize.height - geometrySize.height) / 2
        )
        .clipped()
        .onAppear {
            self.store.send(.updateBoardSize(self.geometrySize))
        }
    }

    private func cell(point: Board.Point, cellLength: CGFloat) -> some View
    {
        return Rectangle()
            .fill(Color.green)
            .frame(
                width: cellLength,
                height: cellLength
            )
            .position(
                x: (CGFloat(point.x) + 0.5) * cellLength,
                y: (CGFloat(point.y) + 0.5) * cellLength
            )
    }
}

private func _offset(at point: CGPoint, cellLength: CGFloat) -> Board.Point
{
    let x = Int(point.x / cellLength)
    let y = Int(point.y / cellLength)
    return Board.Point(x: x, y: y)
}

// MARK: - Preview

struct GameView_Previews: PreviewProvider
{
    static var previews: some View
    {
        let gameView = GameView(
            store: .init(
                state: .constant(.init(pattern: .glider)),
                send: { _ in }
            ),
            geometrySize: CGSize(width: 200, height: 200)
        )

        return Group {
            gameView.previewLayout(.sizeThatFits)
                .previewDisplayName("Portrait")

            gameView.previewLayout(.fixed(width: 568, height: 320))
                .previewDisplayName("Landscape")
        }
    }
}
