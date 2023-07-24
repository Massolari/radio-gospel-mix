module Radio.GospelMix exposing (getSongPlaying, name, urlQueryName, urlStream)

import Http
import Json.Decode as D
import Song exposing (Playlist, Song)
import SongName


name : String
name =
    "Gospel Mix"


urlQueryName : String
urlQueryName =
    "gospel+mix"


urlStream : String
urlStream =
    "https://servidor33-3.brlogic.com:8192/live?source=website"


getSongPlaying :
    { playlist : Playlist
    , onMsg : Result Http.Error (Maybe Song) -> msg
    }
    -> Cmd msg
getSongPlaying config =
    Http.get
        { url = "https://d36nr0u3xmc4mm.cloudfront.net/index.php/api/streaming/status/8192/2e1cbe43529055ddda74868d2db9ae98/SV4BR"
        , expect = Http.expectJson config.onMsg (decodeSong config.playlist)
        }


decodeSong : Playlist -> D.Decoder (Maybe Song)
decodeSong playlist =
    D.field "currentTrack" D.string
        |> D.map (String.replace "(VHT)" "" >> String.trim)
        |> D.map SongName.fromString
        |> D.map
            (\songName ->
                let
                    upperTrack =
                        songName
                            |> SongName.toString
                            |> String.toUpper

                    isAd =
                        String.startsWith "VHT - " upperTrack
                            || String.startsWith "JINGLE - " upperTrack
                            || List.any
                                (\adText -> String.contains adText upperTrack)
                                [ "SPOT"
                                , "CAMPANHA OFICIAL"
                                , "ALIMENTAÇÃO SAUDÁVEL"
                                , "MOMENTO FASHION"
                                , "ESTAÇÃO LITERÁRIA"
                                , "GOSPELMIX"
                                , "CURIOSIDADE MÁXIMA"
                                ]
                in
                { name = songName
                , isAd = isAd
                }
            )
        |> D.map
            (\song ->
                if Song.isCurrent playlist song then
                    Nothing

                else
                    Just song
            )
