module Controller exposing (Msg(..), update)

import List as L
import Regex as Rx exposing (Regex, HowMany(..), regex)
import String as S

import Model exposing (Model, MapResult)


type Msg
    = Change String


sanitize: String -> String
sanitize =
    S.trim
    >> Rx.replace All (regex "[ \t\f\v]") (always "")
    >> Rx.replace All (regex "[\r\n]+") (always "\n")


headNonEmpty: List a -> a
headNonEmpty ls =
    case ls of
        x :: _ -> x
        _ -> Debug.crash "Calling head on an empty list"


calculate: String -> MapResult
calculate s =
    let lines = S.lines s
        rows = L.length lines
        -- Strings in JavaScript are in UCS-16 and not fully Unicode-aware.
        -- There should be only plain ASCII characters in the first line though.
        cols = S.length <| headNonEmpty lines -- It is guaranteed there is at least one line.
    in {
        height = rows,
        width = cols,
        explored = rows * cols - L.length (Rx.find All (regex "[#?!⚠]") s),
        bosses = L.length (S.indices "💀" s),
        secretChambers = L.length (S.indices "✖" s)
    }


update: Msg -> Model -> Model
update msg model =
    case msg of
        Change s -> {
            mapResult =
                case sanitize s of
                    "" -> Nothing
                    newMap -> Just (calculate newMap)
        }
