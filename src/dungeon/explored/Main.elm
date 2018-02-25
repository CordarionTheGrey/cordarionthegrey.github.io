import Html

import Controller as C
import Model as M
import View as V


main: Program Never M.Model C.Msg
main =
    Html.program {
        init = (M.def, Cmd.none),
        view = V.view,
        update = C.update,
        subscriptions = always Sub.none
    }
