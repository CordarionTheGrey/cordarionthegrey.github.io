import Html

import Controller as C
import Model as M
import View as V


main: Program Never M.Model C.Msg
main =
    Html.beginnerProgram {
        model = {mapResult = Nothing},
        view = V.view,
        update = C.update
    }
