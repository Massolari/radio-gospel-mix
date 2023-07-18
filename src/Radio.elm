module Radio exposing (Radio, Station(..), addToPlaylist, apiGetSongPlaying, changeRadio, current, init, name, playlist, station, stationName, urlStream)

import Http
import Radio.ChristianRock as ChristianRock
import Radio.GospelMix as GospelMix
import Song exposing (Playlist, Song)



-- Model


type Radio
    = Radio Station State


type Station
    = GospelMix
    | ChristianRock


type alias State =
    { playlist : Playlist
    }


init : Radio
init =
    Radio GospelMix initState


initState : State
initState =
    { playlist = []
    }



-- Helper


name : Radio -> String
name radio =
    case radio of
        Radio station_ _ ->
            stationName station_


playlist : Radio -> Playlist
playlist radio =
    case radio of
        Radio GospelMix state ->
            state.playlist

        Radio ChristianRock state ->
            state.playlist


stationName : Station -> String
stationName station_ =
    case station_ of
        GospelMix ->
            GospelMix.name

        ChristianRock ->
            ChristianRock.name


current : Radio -> Station -> Bool
current model radio =
    case model of
        Radio station_ _ ->
            station_ == radio


station : Radio -> Station
station radio =
    case radio of
        Radio station_ _ ->
            station_


urlStream : Radio -> String
urlStream model =
    case model of
        Radio GospelMix _ ->
            GospelMix.urlStream

        Radio ChristianRock _ ->
            ChristianRock.urlStream


changeRadio : Station -> Radio
changeRadio station_ =
    case station_ of
        GospelMix ->
            Radio GospelMix initState

        ChristianRock ->
            Radio ChristianRock initState


addToPlaylist : Radio -> Song -> Radio
addToPlaylist radio song =
    case radio of
        Radio GospelMix state ->
            Radio GospelMix { state | playlist = addToPlaylistHelper state.playlist song }

        Radio ChristianRock state ->
            Radio ChristianRock { state | playlist = addToPlaylistHelper state.playlist song }


addToPlaylistHelper : Playlist -> Song -> List Song
addToPlaylistHelper playlist_ song =
    playlist_
        |> List.take 5
        |> List.append [ song ]



-- Http


apiGetSongPlaying : { radio : Radio, onMsg : Result Http.Error (Maybe Song) -> msg } -> Cmd msg
apiGetSongPlaying config =
    case config.radio of
        Radio GospelMix data ->
            GospelMix.getSongPlaying { playlist = data.playlist, onMsg = config.onMsg }

        Radio ChristianRock data ->
            ChristianRock.getSongPlaying { playlist = data.playlist, onMsg = config.onMsg }
