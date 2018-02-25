module Model exposing (MapResult, Model, def)


type alias MapResult = {
    height: Int,
    width: Int,
    explored: Int,
    bosses: Int,
    secretChambers: Int
}


type alias Model = {
    mapResult: Maybe MapResult
}


def: Model
def = {mapResult = Nothing}
