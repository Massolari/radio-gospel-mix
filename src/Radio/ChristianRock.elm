module Radio.ChristianRock exposing (getSongPlaying, name, urlQueryName, urlStream)

import Http
import Json.Decode as D
import Song exposing (Playlist, Song)
import SongName


name : String
name =
    "Christian Rock"


urlQueryName : String
urlQueryName =
    "christian+rock"


urlStream : String
urlStream =
    "https://listen.christianrock.net/stream/11/"


getSongPlaying :
    { onMsg : Result Http.Error Song -> msg
    }
    -> Cmd msg
getSongPlaying config =
    Http.get
        { url = "https://radio-api.onrender.com/christianrock"
        , expect = Http.expectJson config.onMsg decodeSong
        }


decodeSong : D.Decoder Song
decodeSong =
    D.map2 (\title artist -> SongName.newFormatted { artist = artist, title = title })
        (D.field "title" D.string)
        (D.field "artist" D.string)
        |> D.map
            (\songName ->
                let
                    songNameString =
                        SongName.toString songName
                in
                { name = songName
                , isAd = String.contains "EvangelismRockMinutes" songNameString
                }
            )
