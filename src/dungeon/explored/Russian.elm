module Russian exposing (Number(..), numberOf)


type Number = Singular | Paucal | Plural


numberOf: Int -> Number
numberOf n =
    let x = abs (rem n 100)
    in if x <= 4 || x >= 21 then
        case rem x 10 of
            1 -> Singular
            2 -> Paucal
            3 -> Paucal
            4 -> Paucal
            _ -> Plural
    else
        Plural
