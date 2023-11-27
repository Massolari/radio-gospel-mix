module Radio exposing (Radio, Station(..), addToPlaylist, apiGetSongPlaying, changeStation, current, init, name, playlist, retryLoadingSong, station, stationName, urlQueryName, urlStream)

import Dict
import Http
import Radio.ChristianRock as ChristianRock
import Radio.GospelMix as GospelMix
import RemoteData exposing (WebData)
import Song exposing (Playlist, Song)



-- Model


type Radio msg
    = Radio Station (State msg)


type Station
    = GospelMix
    | ChristianRock


type alias State msg =
    { playlist : WebData Playlist
    , onGetSongMsg : Result Http.Error Song -> msg
    }


init : { nameUrlQuery : Maybe String, onGetSongMsg : Result Http.Error Song -> msg } -> ( Radio msg, Cmd msg )
init { nameUrlQuery, onGetSongMsg } =
    let
        station_ =
            nameUrlQuery
                |> Maybe.andThen queryNameToStation
                |> Maybe.withDefault GospelMix

        radio =
            Radio station_ (initState onGetSongMsg)
    in
    ( radio, apiGetSongPlaying radio )


initState : (Result Http.Error Song -> msg) -> State msg
initState onGetSongMsg =
    { playlist = RemoteData.Loading
    , onGetSongMsg = onGetSongMsg
    }



-- Helper


name : Radio msg -> String
name (Radio station_ _) =
    stationName station_


urlQueryName : Radio msg -> String
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


playlist : Radio msg -> WebData Playlist
playlist (Radio _ state) =
    state.playlist


stationName : Station -> String
stationName station_ =
    case station_ of
        GospelMix ->
            GospelMix.name

        ChristianRock ->
            ChristianRock.name


current : Radio msg -> Station -> Bool
current (Radio station_ _) radio =
    station_ == radio


station : Radio msg -> Station
station radio =
    case radio of
        Radio station_ _ ->
            station_


urlStream : Radio msg -> String
urlStream (Radio station_ _) =
    case station_ of
        GospelMix ->
            GospelMix.urlStream

        ChristianRock ->
            ChristianRock.urlStream


changeStation : { station : Station, radio : Radio msg } -> ( Radio msg, Cmd msg )
changeStation options =
    let
        (Radio _ state) =
            options.radio

        newRadio =
            Radio options.station (initState state.onGetSongMsg)
    in
    ( newRadio, apiGetSongPlaying newRadio )


retryLoadingSong : Radio msg -> ( Radio msg, Cmd msg )
retryLoadingSong ((Radio station_ state) as radio) =
    ( Radio station_ (initState state.onGetSongMsg)
    , apiGetSongPlaying radio
    )


addToPlaylist : Radio msg -> Result Http.Error Song -> Radio msg
addToPlaylist (Radio station_ state) resultSong =
    let
        newState =
            case resultSong of
                Ok song ->
                    let
                        thisPlaylist =
                            RemoteData.withDefault [] state.playlist
                    in
                    if Song.isCurrent thisPlaylist song then
                        state

                    else
                        { state | playlist = RemoteData.Success <| addToPlaylistHelper thisPlaylist song }

                Err error ->
                    { state | playlist = RemoteData.Failure error }
    in
    Radio station_ newState


addToPlaylistHelper : Playlist -> Song -> List Song
addToPlaylistHelper playlist_ song =
    playlist_
        |> List.take 5
        |> List.append [ song ]



-- Http


apiGetSongPlaying : Radio msg -> Cmd msg
apiGetSongPlaying (Radio station_ state) =
    case station_ of
        GospelMix ->
            GospelMix.getSongPlaying { onMsg = state.onGetSongMsg }

        ChristianRock ->
            ChristianRock.getSongPlaying { onMsg = state.onGetSongMsg }
