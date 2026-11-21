
SlidingPuzzleGrid(value) {
    return value = "4x4" ? "4x4" : "3x3"
}
PuzzleNeighbors(index, n) {
    out := [], row := (index - 1)//n, col := Mod(index - 1, n)
    if row > 0
        out.Push(index - n)
    if row < n - 1
        out.Push(index + n)
    if col > 0
        out.Push(index - 1)
    if col < n - 1
        out.Push(index + 1)
    return out
}
PuzzleAdjacent(a, b, n) {
    return Abs((a - 1)//n - (b - 1)//n) + Abs(Mod(a - 1, n) - Mod(b - 1, n)) = 1
}
PuzzleSolved(board) {
    for index, tile in board
        if tile != (index = board.Length ? 0 : index)
            return false
    return true
}
PuzzleShuffle(n) {
    board := []
    loop n*n
        board.Push(A_Index = n*n ? 0 : A_Index)
    blank := n*n, previous := 0
    loop n*n*12 {
        choices := []
        for neighbor in PuzzleNeighbors(blank, n)
            if neighbor != previous
                choices.Push(neighbor)
        next := choices[Random(1, choices.Length)]
        board[blank] := board[next], board[next] := 0
        previous := blank, blank := next
    }
    if PuzzleSolved(board) {
        next := PuzzleNeighbors(blank, n)[1]
        board[blank] := board[next], board[next] := 0
    }
    return board
}
