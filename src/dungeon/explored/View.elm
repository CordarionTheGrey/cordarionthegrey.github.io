module View exposing (view)

import Json.Decode
import List as L
import Maybe as M exposing (Maybe)

import Html exposing (..)
import Html.Attributes exposing (accept, class, href, id, target, type_)
import Html.Events exposing (on, onInput, targetValue)

import Controller exposing (Msg(..))
import Model exposing (Model, MapResult)
import Russian as Ru


localize: (a, a, a) -> Int -> a
localize (a, b, c) n =
    case Ru.numberOf n of
        Ru.Singular -> a
        Ru.Paucal -> b
        Ru.Plural -> c


numberSpan: List (Attribute msg) -> Int -> Html msg
numberSpan attrs n =
    span attrs [text (n |> toString)]


formatSize: MapResult -> List (Html msg)
formatSize {height, width} =
    [
        text "Размер карты: ",
        span [class "size"] [text <| toString height ++ "x" ++ toString width],
        text "."
    ]


formatCells: MapResult -> List (Html msg)
formatCells {explored, secretChambers} =
    let (ending, word) = localize (
            ("а", "клетка"),
            ("ы", "клетки"),
            ("о", "клеток")
        ) explored
        prefix = [
            text <| "Открыт" ++ ending ++ " ",
            numberSpan [class "cells"] explored,
            text <| " " ++ word
        ]
    in  L.append prefix <| if secretChambers > 0 then [
        text ", если была посещена Тайная комната, или ",
        numberSpan [class "cells"] (explored - secretChambers),
        text ", если нет."
    ] else [
        text "."
    ]


formatBosses: MapResult -> List (Html msg)
formatBosses {bosses} =
    let (ending, word) = localize (
            ("", "босс"),
            ("ы", "босса"),
            ("о", "боссов")
        ) bosses
    in [
        text <| "Побежден" ++ ending ++ " ",
        numberSpan [class "bosses"] bosses,
        text <| " " ++ word ++ if bosses <= 8 then "." else " (серьезно?!)."
    ]


formatResult: MapResult -> List (Html msg)
formatResult result =
    L.map (\f -> div [ ] (f result)) [formatSize, formatCells, formatBosses]


onChange: (String -> msg) -> Attribute msg
onChange tagger =
    on "change" (Json.Decode.map tagger targetValue)


view: Model -> Html Msg
view model =
    main_ [class "block"] [
        div [class "map"] [
            textarea [id "map", onInput Change] [ ]
        ],
        input [
            type_ "file",
            id "map-picker",
            accept "text/html",
            onChange (LoadFile "#map-picker" "#map")
        ] [ ],
        div [class "result"] (M.map formatResult model.mapResult |> M.withDefault [ ])
    ]
