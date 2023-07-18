module Song exposing (Playlist, Song, isCurrent)

import SongName exposing (SongName)


type alias Playlist =
    List Song


type alias Song =
    { name : SongName
    , isAd : Bool
    }



-- Helper


isCurrent : Playlist -> Song -> Bool
isCurrent playlist song =
    let
        areBothAds current =
            current.isAd == True && current.isAd == song.isAd

        haveBothSameName current =
            current.name == song.name
    in
    playlist
        |> List.head
        |> Maybe.map (\current -> areBothAds current || haveBothSameName current)
        |> Maybe.withDefault False
