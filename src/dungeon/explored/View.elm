module View exposing (view)

import List as L
import Maybe as M exposing (Maybe)

import Html exposing (..)
import Html.Attributes exposing (class, href, target)
import Html.Events exposing (onInput)

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
        text "Размеры карты: ",
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
        text ", если была посещена Тайная Комната, или ",
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
        text <| "Убит" ++ ending ++ " ",
        numberSpan [class "bosses"] bosses,
        text <| " " ++ word ++ (if bosses <= 8 then "." else " (серьезно?!).")
    ]


formatResult: MapResult -> List (Html msg)
formatResult result =
    L.map (\f -> div [ ] (f result)) [formatSize, formatCells, formatBosses]


sourceCode: List (Attribute msg) -> String -> Html msg
sourceCode attrs source =
    pre attrs [code [ ] [text source]]


view: Model -> Html Msg
view model =
    main_ [class "block"] [
        textarea [class "map", onInput Change] [ ],
        div [class "result"] (M.map formatResult model.mapResult |> M.withDefault [ ])
    ]
