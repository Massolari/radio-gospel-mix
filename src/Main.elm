port module Main exposing (Model, Msg, init, main, update, view)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick)
import Http
import Icon
import Json.Decode as D
import Process
import Task
import Time



-- Ports


port copyToClipboard : String -> Cmd msg


port playPause : () -> Cmd msg


port copiedToClipboard : (String -> msg) -> Sub msg



-- Model


type SongName
    = Formatted FormattedSongName
    | Unformatted String


type alias FormattedSongName =
    { artist : String
    , title : String
    }


type alias Song =
    { name : SongName
    , isAd : Bool
    }


type alias Playlist =
    List Song


type PlayerStatus
    = Playing
    | Paused


type alias Model =
    { playlist : Playlist
    , copiedSong : Maybe String
    , player : PlayerStatus
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { playlist = []
      , copiedSong = Nothing
      , player = Paused
      }
    , getSongPlaying []
    )



-- Msg


type Msg
    = GetSongPlaying Time.Posix
    | GotPlayerStatus PlayerStatus
    | GotSong (Result Http.Error (Maybe Song))
    | PlayPause
    | Copy Song
    | Copied String
    | Uncopy



-- Update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotSong response ->
            case response of
                Ok (Just song) ->
                    ( { model | playlist = addToPlaylist song model.playlist }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        GetSongPlaying _ ->
            ( model, getSongPlaying model.playlist )

        GotPlayerStatus status ->
            ( { model | player = status }, Cmd.none )

        PlayPause ->
            ( model, playPause () )

        Copy song ->
            ( model, copyToClipboard <| getSongName song.name )

        Copied song ->
            ( { model | copiedSong = Just song }, Process.sleep 3000 |> Task.perform (\_ -> Uncopy) )

        Uncopy ->
            ( { model | copiedSong = Nothing }, Cmd.none )



-- View


view : Model -> Html Msg
view model =
    main_ []
        [ div [ class "background" ] []
        , h3 [] [ text "Rádio Gospel Mix" ]
        , viewPlayer
        , viewPlaylist model
        ]


viewPlayer : Html Msg
viewPlayer =
    div []
        [ audio
            [ controls True
            , autoplay True
            , preload "auto"
            , src "https://servidor33-3.brlogic.com:8192/live?source=website"
            , on "loadeddata" (D.map GotPlayerStatus decodePlayerStatus)
            , on "play" (D.succeed <| GotPlayerStatus Playing)
            , on "pause" (D.succeed <| GotPlayerStatus Paused)
            ]
            []
        ]


decodePlayerStatus : D.Decoder PlayerStatus
decodePlayerStatus =
    D.at [ "target", "paused" ] D.bool
        |> D.map
            (\paused ->
                if paused then
                    Paused

                else
                    Playing
            )


viewPlaylist : Model -> Html Msg
viewPlaylist model =
    ul [ class "playlist" ]
        (List.map
            (viewSong model)
            model.playlist
        )


viewSong : Model -> Song -> Html Msg
viewSong model song =
    li [ class "song" ]
        [ if isCurrentSong model.playlist song then
            viewPlayerButton model.player

          else
            text ""
        , viewSongName song
        , div [ class "actions" ]
            [ viewYoutubeButton song
            , viewCopyButton model.copiedSong song
            ]
        ]


viewPlayerButton : PlayerStatus -> Html Msg
viewPlayerButton status =
    let
        playPauseButton content =
            button
                [ class "player-button"
                , onClick PlayPause
                ]
                [ content ]
    in
    case status of
        Playing ->
            playPauseButton Icon.pause

        Paused ->
            playPauseButton Icon.play


viewSongName : Song -> Html Msg
viewSongName song =
    let
        songName =
            if song.isAd then
                Unformatted "Intervalo"

            else
                song.name
    in
    case songName of
        Formatted formattedSongName ->
            div [ class "song-name" ]
                [ div [ class "song-title" ] [ text formattedSongName.title ]
                , div [ class "song-artist" ] [ text formattedSongName.artist ]
                ]

        Unformatted name ->
            div [ class "song-name" ] [ text name ]


viewCopyButton : Maybe String -> Song -> Html Msg
viewCopyButton copiedSong song =
    button
        [ onClick <| Copy song
        , class "copy-button"
        , class <|
            if isCopiedSong copiedSong song then
                "copied"

            else
                ""
        ]
        [ Icon.copy ]


viewYoutubeButton : Song -> Html Msg
viewYoutubeButton song =
    a
        [ href <| songLink song
        , target "_blank"
        , class "youtube-button"
        ]
        [ Icon.youtube ]



-- Helper


isCopiedSong : Maybe String -> Song -> Bool
isCopiedSong copiedSong song =
    copiedSong
        |> Maybe.map ((==) (getSongName song.name))
        |> Maybe.withDefault False


songLink : Song -> String
songLink song =
    song.name
        |> getSongName
        |> String.replace " -" ""
        |> String.replace " " "+"
        |> String.append "https://www.youtube.com/results?search_query="


getSongName : SongName -> String
getSongName songName =
    case songName of
        Formatted data ->
            data.artist ++ " - " ++ data.title

        Unformatted name ->
            name


isCurrentSong : Playlist -> Song -> Bool
isCurrentSong playlist song =
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


addToPlaylist : Song -> List Song -> List Song
addToPlaylist song playlist =
    playlist
        |> List.take 5
        |> List.append [ song ]


stringToSongName : String -> SongName
stringToSongName name =
    let
        splittedName =
            name
                |> String.split " - "
                |> List.filterMap
                    (\part ->
                        case String.toInt part of
                            Just _ ->
                                Nothing

                            Nothing ->
                                if part == "Ao Vivo" then
                                    Nothing

                                else
                                    Just part
                    )
    in
    case splittedName of
        [ artist, title ] ->
            Formatted { artist = artist, title = title }

        _ ->
            Unformatted name



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Time.every (1000 * 30) GetSongPlaying
        , copiedToClipboard Copied
        ]



-- Http


getSongPlaying : Playlist -> Cmd Msg
getSongPlaying playlist =
    Http.get
        { url = "https://d36nr0u3xmc4mm.cloudfront.net/index.php/api/streaming/status/8192/2e1cbe43529055ddda74868d2db9ae98/SV4BR"
        , expect = Http.expectJson GotSong (decodeSong playlist)
        }



-- Decoders


decodeSong : Playlist -> D.Decoder (Maybe Song)
decodeSong playlist =
    D.field "currentTrack" D.string
        |> D.map (String.replace "(VHT)" "" >> String.trim)
        |> D.map stringToSongName
        |> D.map
            (\songName ->
                let
                    upperTrack =
                        songName
                            |> getSongName
                            |> String.toUpper

                    isAd =
                        String.startsWith "VHT - " upperTrack
                            || String.startsWith "JINGLE - " upperTrack
                            || List.any
                                (\adText -> String.contains adText upperTrack)
                                [ "SPOT"
                                , "CAMPANHA OFICIAL"
                                , "ALIMENTAÇÃO SAUDÁVEL"
                                , "ESTAÇÃO LITERÁRIA"
                                ]
                in
                { name = songName
                , isAd = isAd
                }
            )
        |> D.map
            (\song ->
                if isCurrentSong playlist song then
                    Nothing

                else
                    Just song
            )



-- Main


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
