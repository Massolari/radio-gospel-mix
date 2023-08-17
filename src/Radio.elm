module Radio exposing (Radio, Station(..), addToPlaylist, apiGetSongPlaying, changeRadio, current, init, name, playlist, station, stationName, urlQueryName, urlStream)

import Dict
import Http
import Radio.ChristianRock as ChristianRock
import Radio.GospelMix as GospelMix
import RemoteData exposing (WebData)
import Song exposing (Playlist, Song)



-- Model


type Radio
    = Radio Station State


type Station
    = GospelMix
    | ChristianRock


type alias State =
    { playlist : WebData Playlist
    }


init : { nameUrlQuery : Maybe String, onGetSongMsg : Result Http.Error Song -> msg } -> ( Radio, Cmd msg )
init { nameUrlQuery, onGetSongMsg } =
    let
        station_ =
            nameUrlQuery
                |> Maybe.andThen queryNameToStation
                |> Maybe.withDefault GospelMix

        radio =
            Radio station_ initState
    in
    ( radio, apiGetSongPlaying { radio = radio, onMsg = onGetSongMsg } )


initState : State
initState =
    { playlist = RemoteData.Loading
    }



-- Helper


name : Radio -> String
name (Radio station_ _) =
    stationName station_


urlQueryName : Radio -> String
urlQueryName (Radio station_ _) =
    case station_ of
        GospelMix ->
            GospelMix.urlQueryName

        ChristianRock ->
            ChristianRock.urlQueryName


queryNameToStation : String -> Maybe Station
queryNameToStation queryName =
    Dict.fromList
        [ ( GospelMix.urlQueryName, GospelMix ), ( ChristianRock.urlQueryName, ChristianRock ) ]
        |> Dict.get queryName


playlist : Radio -> WebData Playlist
playlist (Radio _ state) =
    state.playlist


stationName : Station -> String
stationName station_ =
    case station_ of
        GospelMix ->
            GospelMix.name

        ChristianRock ->
            ChristianRock.name


current : Radio -> Station -> Bool
current (Radio station_ _) radio =
    station_ == radio


station : Radio -> Station
station radio =
    case radio of
        Radio station_ _ ->
            station_


urlStream : Radio -> String
urlStream (Radio station_ _) =
    case station_ of
        GospelMix ->
            GospelMix.urlStream

        ChristianRock ->
            ChristianRock.urlStream


changeRadio : { station : Station, onGetSongMsg : Result Http.Error Song -> msg } -> (Radio, Cmd msg)
changeRadio options =
    let
        radio =
            case options.station of
                GospelMix ->
                    Radio GospelMix initState

                ChristianRock ->
                    Radio ChristianRock initState
    in
    ( radio, apiGetSongPlaying { radio = radio, onMsg = options.onGetSongMsg } )


addToPlaylist : Radio -> Song -> Radio
addToPlaylist (Radio station_ state) song =
    let
        thisPlaylist =
            RemoteData.withDefault [] state.playlist

        newState =
            if Song.isCurrent thisPlaylist song then
                state

            else
                { state | playlist = RemoteData.Success <| addToPlaylistHelper thisPlaylist song }
    in
    case station_ of
        GospelMix ->
            Radio GospelMix newState

        ChristianRock ->
            Radio ChristianRock newState


addToPlaylistHelper : Playlist -> Song -> List Song
addToPlaylistHelper playlist_ song =
    playlist_
        |> List.take 5
        |> List.append [ song ]



-- Http


apiGetSongPlaying : { radio : Radio, onMsg : Result Http.Error Song -> msg } -> Cmd msg
apiGetSongPlaying config =
    let
        (Radio station_ _) =
            config.radio
    in
    case station_ of
        GospelMix ->
            GospelMix.getSongPlaying { onMsg = config.onMsg }

        ChristianRock ->
            ChristianRock.getSongPlaying { onMsg = config.onMsg }
