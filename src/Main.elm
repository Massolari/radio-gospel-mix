port module Main exposing (Model, Msg, init, main, update, view)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick, onInput)
import Html.Keyed as Keyed
import Http
import Icon
import Json.Decode as D
import Process
import Radio exposing (Radio, Station)
import RemoteData
import Song exposing (Playlist, Song)
import SongName
import Task
import Time



-- Ports


port copyToClipboard : String -> Cmd msg


port changeUrlQuery : String -> Cmd msg


port playPause : () -> Cmd msg


port copiedToClipboard : (String -> msg) -> Sub msg


port setTitle : String -> Cmd msg


port setVolume : Float -> Cmd msg



-- Model


type alias Flags =
    D.Value


type PlayerStatus
    = Playing
    | Paused


type alias Model =
    { radio : Radio Msg
    , copiedSong : Maybe String
    , player : Player
    }


type alias Player =
    { status : PlayerStatus
    , volume : Float
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        radioQuery =
            flags
                |> D.decodeValue (D.field "radio" <| D.maybe D.string)
                |> Result.withDefault Nothing

        ( radio, radioCmd ) =
            Radio.init { nameUrlQuery = radioQuery, onGetSongMsg = GotSong }
    in
    ( { radio = radio
      , copiedSong = Nothing
      , player = initPlayer
      }
    , Cmd.batch
        [ radioCmd
        , changeUrlQuery <| Radio.urlQueryName radio
        ]
    )


initPlayer : Player
initPlayer =
    { status = Paused
    , volume = 1
    }



-- Msg


type Msg
    = GetSongPlaying
    | GotPlayerStatus PlayerStatus
    | RetryLoadingSong
    | GotSong (Result Http.Error Song)
    | VolumeChanged String
    | ToggleMuted
    | PlayPause
    | Copy Song
    | Copied String
    | Uncopy
    | ChangeRadio Station



-- Update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ player } as model) =
    case msg of
        GetSongPlaying ->
            ( model
            , Radio.apiGetSongPlaying model.radio
            )

        GotPlayerStatus status ->
            ( { model | player = { player | status = status } }
            , setVolume player.volume
            )

        RetryLoadingSong ->
            let
                ( newRadio, cmd ) =
                    Radio.retryLoadingSong model.radio
            in
            ( { model | radio = newRadio }
            , cmd
            )

        GotSong song ->
            ( { model | radio = Radio.addToPlaylist model.radio song }
            , case song of
                Ok actualSong ->
                    setTitle <| SongName.toString actualSong.name ++ " | " ++ Radio.stationName (Radio.station model.radio)

                Err _ ->
                    Cmd.none
            )

        VolumeChanged volumeStr ->
            let
                volume =
                    volumeStr
                        |> String.toFloat
                        |> Maybe.withDefault model.player.volume
            in
            ( { model | player = { player | volume = volume } }
            , setVolume volume
            )

        ToggleMuted ->
            let
                volume =
                    if player.volume == 0 then
                        1

                    else
                        0
            in
            ( { model | player = { player | volume = volume } }
            , setVolume volume
            )

        PlayPause ->
            ( model, playPause () )

        Copy song ->
            ( model, copyToClipboard <| SongName.toString song.name )

        Copied song ->
            ( { model | copiedSong = Just song }
            , Process.sleep 3000 |> Task.perform (\_ -> Uncopy)
            )

        Uncopy ->
            ( { model | copiedSong = Nothing }
            , Cmd.none
            )

        ChangeRadio station ->
            let
                ( newRadio, radioCmd ) =
                    Radio.changeStation { station = station, radio = model.radio }
            in
            ( { model | radio = newRadio, player = { player | status = Paused } }
            , Cmd.batch
                [ radioCmd
                , changeUrlQuery <| Radio.urlQueryName newRadio
                ]
            )



-- View


view : Model -> Html Msg
view model =
    main_ []
        [ viewBackground
        , viewNavigation model.radio
        , viewPlayer model.radio
        , viewPlaylist model
        ]


viewBackground : Html Msg
viewBackground =
    div
        [ class "background absolute top-0 left-0 w-full h-full opacity-20" ]
        []


viewNavigation : Radio Msg -> Html Msg
viewNavigation radio =
    let
        disabledIconClass =
            class "opacity-10"

        ( carretLeftAttrs, carretRightAttrs ) =
            case Radio.station radio of
                Radio.GospelMix ->
                    ( [ disabledIconClass, disabled True ]
                    , [ onClick <| ChangeRadio Radio.ChristianRock ]
                    )

                Radio.ChristianRock ->
                    ( [ onClick <| ChangeRadio Radio.GospelMix ]
                    , [ disabledIconClass, disabled True ]
                    )

        titleClass station =
            if Radio.current radio station then
                class "opacity-100"

            else
                class "opacity-10"

        viewRadioName station =
            span
                [ titleClass station
                , class "transition-all duration-500"
                ]
                [ text <| Radio.stationName station ]

        viewCarret attrs icon =
            button
                (attrs ++ [ class "[&>svg]:fill-white" ])
                [ icon ]
    in
    nav
        [ class "justify-center items-center flex gap-4 p-4 text-white text-3xl "
        ]
        [ viewCarret carretLeftAttrs Icon.carretLeft
        , viewRadioName Radio.GospelMix
        , viewRadioName Radio.ChristianRock
        , viewCarret carretRightAttrs Icon.carretRight
        ]


viewPlayer : Radio Msg -> Html Msg
viewPlayer radio =
    div []
        [ audio
            [ controls True
            , class "hidden"
            , preload "none"
            , src <| Radio.urlStream radio
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
    let
        playlist =
            Radio.playlist model.radio

        viewNotSuccess message =
            ul []
                [ viewSongCard
                    { song = { name = SongName.fromString message, isAd = False }
                    , isHighlighted = True
                    , playerButton = Just model.player
                    , viewActions = Just viewRetryButton
                    }
                ]

        viewRetryButton =
            styledButton
                [ onClick RetryLoadingSong
                , class "rounded-full hover:bg-gray-100"
                , title "Tentar novamente"
                ]
                [ Icon.rotateRight ]
    in
    div
        [ class "mx-auto my-0"
        , class "w-fit h-full"
        ]
        [ case playlist of
            RemoteData.NotAsked ->
                viewNotSuccess "Nome da música não carregado"

            RemoteData.Loading ->
                ul []
                    [ viewSongCard
                        { song = { name = SongName.fromString "Carregando", isAd = False }
                        , isHighlighted = True
                        , playerButton = Just model.player
                        , viewActions =
                            Just <|
                                div [ class "animate-spin text-2xl [&>svg]:fill-black" ] [ Icon.spinner ]
                        }
                    ]

            RemoteData.Failure _ ->
                viewNotSuccess "Erro ao carregar música"

            RemoteData.Success playlist_ ->
                viewPlaylistData playlist_ model
        ]


viewPlaylistData : Playlist -> Model -> Html Msg
viewPlaylistData playlist model =
    Keyed.node "ul"
        [ class "flex flex-col gap-2 items-center"
        ]
        (List.map
            (viewKeyedSong playlist model)
            playlist
        )


styledButton : List (Attribute msg) -> List (Html msg) -> Html msg
styledButton =
    button
        << List.append
            [ class "bg-none hover:bg-gray-100"
            , class "p-2 border-none transition-all pointer"
            ]


viewKeyedSong : Playlist -> Model -> Song -> ( String, Html Msg )
viewKeyedSong playlist model song =
    let
        isCurrent =
            Song.isCurrent playlist song
    in
    ( SongName.toString song.name
    , viewSongCard
        { song = song
        , isHighlighted = isCurrent
        , playerButton =
            if isCurrent then
                Just model.player

            else
                Nothing
        , viewActions =
            Just <|
                div
                    [ class "flex gap-2"
                    , if song.isAd then
                        class "invisible"

                      else
                        class ""
                    ]
                    [ viewYoutubeButton song isCurrent
                    , viewCopyButton model.copiedSong song isCurrent
                    ]
        }
    )


viewSongCard :
    { song : Song
    , isHighlighted : Bool
    , playerButton : Maybe Player
    , viewActions : Maybe (Html Msg)
    }
    -> Html Msg
viewSongCard ({ song, isHighlighted } as options) =
    let
        highlightClasses =
            if isHighlighted then
                [ class "text-black bg-white px-5 opacity-90"
                , class "animate-[showSong_1s] fill-mode-forwards "
                , class "md:w-[40vw] w-[70vw]"
                ]

            else
                [ class "text-white bg-gray-600 opacity-70 p-4"
                , class "md:w-[30vw] w-[60vw]"
                ]
    in
    li
        ([ class "flex flex-col justify-between"
         , class "transition-all duration-1000 origin-top transition-opacity-150 hover:opacity-100"
         ]
            ++ highlightClasses
        )
        [ div [ class "flex justify-between items-center" ]
            [ case options.playerButton of
                Just player ->
                    viewPlayerButton player.status

                Nothing ->
                    text ""
            , viewSongName song isHighlighted
            , case options.viewActions of
                Just viewActions ->
                    viewActions

                Nothing ->
                    text ""
            ]
        , case options.playerButton of
            Just player ->
                viewVolumeInput player

            Nothing ->
                text ""
        ]


viewPlayerButton : PlayerStatus -> Html Msg
viewPlayerButton status =
    let
        playPauseButton content =
            styledButton
                [ class "rounded-lg text-xl w-10 h-10"
                , class "flex items-center justify-center"
                , onClick PlayPause
                ]
                [ content ]
    in
    case status of
        Playing ->
            playPauseButton Icon.pause

        Paused ->
            playPauseButton Icon.play


viewSongName : Song -> Bool -> Html Msg
viewSongName song isCurrent =
    let
        songName =
            if song.isAd then
                SongName.newUnformatted "Intervalo"

            else
                song.name

        songNameClasses =
            class "text-center w-full"

        artistClass =
            if isCurrent then
                class "text-gray-600"

            else
                class "text-gray-400"
    in
    SongName.match songName
        { formatted =
            \formattedSongName ->
                div [ songNameClasses ]
                    [ div [ class "text-lg font-bold" ] [ text formattedSongName.title ]
                    , div [ class "text-xs", artistClass ] [ text formattedSongName.artist ]
                    ]
        , unformatted =
            \name ->
                div [ songNameClasses ] [ text name ]
        }


viewVolumeInput : Player -> Html Msg
viewVolumeInput player =
    div [ class "flex items-center gap-1" ]
        [ styledButton
            [ class "w-9 h-9 relative rounded-full text-md p-2"
            , class "flex items-center justify-center"
            , onClick ToggleMuted
            ]
            [ div [ class "w-5 h-4 relative" ]
                [ span
                    [ class "absolute left-0"
                    , class
                        (if player.volume == 0 then
                            "visible"

                         else
                            "hidden"
                        )
                    ]
                    [ Icon.volumeX ]
                , span [ class "absolute left-0" ] [ Icon.volumeOff ]
                , span [ class "absolute left-0", style "opacity" (String.fromFloat (player.volume * 2)) ] [ Icon.volumeLow ]
                , span [ class "absolute left-0", style "opacity" (String.fromFloat (player.volume * 2 - 1)) ] [ Icon.volumeHigh ]
                ]
            ]
        , input
            [ type_ "range"
            , Html.Attributes.min "0"
            , Html.Attributes.max "1"
            , step "any"
            , class "w-full accent-black h-1"
            , value <| String.fromFloat player.volume
            , onInput VolumeChanged
            ]
            []
        ]


viewCopyButton : Maybe String -> Song -> Bool -> Html Msg
viewCopyButton copiedSong song isCurrent =
    let
        bgHoverClass =
            if isCurrent then
                class "hover:bg-gray-100"

            else
                class "hover:bg-gray-700 [&>svg]:fill-white"
    in
    div [ class "relative" ]
        [ if isCopiedSong copiedSong song then
            span
                [ class "text-xs text-black rounded-lg p-2 transition-opacity"
                , class "absolute top-[-2rem] left-[-1rem]"
                , class "bg-gray-100"
                , class "animate-[fadeInOut_3s] fill-mode-forwards"
                ]
                [ text "Copiado" ]

          else
            text ""
        , styledButton
            [ onClick <| Copy song
            , class "rounded-full"
            , bgHoverClass
            ]
            [ Icon.copy
            ]
        ]


viewYoutubeButton : Song -> Bool -> Html Msg
viewYoutubeButton song isCurrent =
    let
        isCurrentSongClasses =
            if isCurrent then
                class "hover:bg-gray-100"

            else
                class "hover:bg-gray-700 [&>svg]:fill-white"
    in
    a
        [ href <| SongName.toYoutubeLink song.name
        , target "_blank"
        , class "rounded-full p-2 transition-all"
        , isCurrentSongClasses
        ]
        [ Icon.youtube ]



-- Helper


isCopiedSong : Maybe String -> Song -> Bool
isCopiedSong copiedSong song =
    copiedSong
        |> Maybe.map ((==) (SongName.toString song.name))
        |> Maybe.withDefault False



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Time.every (1000 * 30) (\_ -> GetSongPlaying)
        , copiedToClipboard Copied
        ]



-- Main


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
