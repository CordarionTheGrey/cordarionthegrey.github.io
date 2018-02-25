port module Controller exposing (Msg(..), update)

import Bitwise
import Char
import List as L
import Regex as Rx exposing (Regex, HowMany(..), regex)
import String as S

import Model exposing (Model, MapResult)


port readFile: ({-inputSelector-} String, {-outputSelector-} String) -> Cmd msg


type Msg
    = Change String
    | LoadFile String String String


count: String -> String -> Int
count needle =
    L.length << S.indices needle


countRx: Regex -> String -> Int
countRx needle =
    L.length << Rx.find All needle


uniLength: String -> Int
uniLength =
    -- Discard one code unit of each surrogate pair.
    S.foldl (\c n -> if Bitwise.and (Char.toCode c) 0xF800 /= 0xD800 then n + 1 else n) 0


sanitize: String -> String
sanitize =
    S.trim
    >> Rx.replace All (regex "[ \t\f\v]") (always "")
    >> Rx.replace All (regex "[\r\n]+") (always "\n")


calculate: String -> Maybe MapResult
calculate s =
    let lines = S.lines s
        rows = L.length lines
        cols = L.foldl max 0 (L.map uniLength lines)
    in if rows == 0 || cols == 0 then
        Nothing
    else
        Just {
            height = rows,
            width = cols,
            explored = rows * cols - countRx (regex "[#?!⚠]") s,
            bosses = count "💀" s,
            secretChambers = count "✖" s
        }


update: Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        Change newMap ->
            ({mapResult = calculate (sanitize newMap)}, Cmd.none)
        LoadFile inputSelector outputSelector _ ->
            (model, readFile (inputSelector, outputSelector))
