import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (id)
import Html.Events exposing (onClick)


main: Program Never Model Msg
main =
    Html.beginnerProgram {model = model, view = view, update = update}


type alias Model = Int


model: Model
model = 0


type Msg
    = Increment
    | Decrement


update: Msg -> Model -> Model
update msg model =
    case msg of
    Increment -> model + 1
    Decrement -> model - 1


view: Model -> Html Msg
view model =
    div [id "main"] [
        button [onClick Decrement] [text "-"],
        span [ ] [text (toString model)],
        button [onClick Increment] [text "+"]
    ]
