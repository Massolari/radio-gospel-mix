module Radio.ChristianRock exposing (getSongPlaying, name, urlStream)

import Http
import Json.Decode as D
import Song exposing (Playlist, Song)
import SongName


name : String
name =
    "Christian Rock"


urlStream : String
urlStream =
    "https://listen.christianrock.net/stream/11/"


getSongPlaying :
    { playlist : Playlist
    , onMsg : Result Http.Error (Maybe Song) -> msg
    }
    -> Cmd msg
getSongPlaying config =
    Http.get
        { url = "https://radio-api.onrender.com/christianrock"
        , expect = Http.expectJson config.onMsg (decodeSong config.playlist)
        }


decodeSong : Playlist -> D.Decoder (Maybe Song)
decodeSong playlist =
    D.map2 Song
        (D.map2 (\artist title -> SongName.newFormatted { artist = artist, title = title })
            (D.field "title" D.string)
            (D.field "artist" D.string)
        )
        (D.succeed False)
        |> D.map
            (\song ->
                if Song.isCurrent playlist song then
                    Nothing

                else
                    Just song
            )
