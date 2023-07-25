port module Main exposing (Model, Msg, init, main, update, view)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick)
import Html.Keyed as Keyed
import Http
import Icon
import Json.Decode as D
import Process
import Radio exposing (Radio, Station)
import Song exposing (Song)
import SongName
import Task
import Time



-- Ports


port copyToClipboard : String -> Cmd msg


port changeUrlQuery : String -> Cmd msg


port playPause : () -> Cmd msg


port copiedToClipboard : (String -> msg) -> Sub msg



-- Model


type alias Flags =
    D.Value


type PlayerStatus
    = Playing
    | Paused


type alias Model =
    { radio : Radio
    , copiedSong : Maybe String
    , player : PlayerStatus
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        radioQuery =
            flags
                |> D.decodeValue (D.field "radio" <| D.maybe D.string)
                |> Result.withDefault Nothing

        radio =
            Radio.init radioQuery
    in
    ( { radio = radio
      , copiedSong = Nothing
      , player = Paused
      }
    , Cmd.batch
        [ apiGetSongPlaying radio
        , changeUrlQuery <| Radio.urlQueryName radio
        ]
    )



-- Msg


type Msg
    = GetSongPlaying Time.Posix
    | GotPlayerStatus PlayerStatus
    | GotSong (Result Http.Error Song)
    | PlayPause
    | Copy Song
    | Copied String
    | Uncopy
    | ChangeRadio Station



-- Update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotSong response ->
            case response of
                Ok song ->
                    ( { model | radio = Radio.addToPlaylist model.radio song }
                    , Cmd.none
                    )

                Err _ ->
                    ( model, Cmd.none )

        GetSongPlaying _ ->
            ( model
            , apiGetSongPlaying model.radio
            )

        GotPlayerStatus status ->
            ( { model | player = status }
            , Cmd.none
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
                newRadio =
                    Radio.changeRadio station
            in
            ( { model | radio = newRadio }
            , Cmd.batch
                [ apiGetSongPlaying newRadio
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


viewNavigation : Radio -> Html Msg
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


viewPlayer : Radio -> Html Msg
viewPlayer radio =
    div []
        [ audio
            [ controls True
            , class "hidden"
            , autoplay True
            , preload "auto"
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
    in
    Keyed.node "ul"
        [ class "mx-auto my-0"
        , class "flex flex-col gap-2 items-center"
        , class "w-fit h-full"
        ]
        (List.map
            (viewKeyedSong model)
            playlist
        )


styledButton : List (Attribute msg) -> List (Html msg) -> Html msg
styledButton =
    button
        << List.append
            [ class "bg-none hover:bg-gray-100"
            , class "p-2 border-none transition-all pointer"
            ]


viewKeyedSong : Model -> Song -> ( String, Html Msg )
viewKeyedSong model song =
    let
        playlist =
            Radio.playlist model.radio

        isCurrent =
            Song.isCurrent playlist song

        currentSongClasses =
            if isCurrent then
                [ class "text-black bg-white px-5 opacity-90"
                , class "animate-[showSong_1s] fill-mode-forwards "
                , class "md:w-[40vw] w-[70vw]"
                ]

            else
                [ class "text-white bg-gray-600 opacity-70 p-4"
                , class "md:w-[30vw] w-[60vw]"
                ]
    in
    ( SongName.toString song.name
    , li
        ([ class "list-none"
         , class "transition-all duration-1000 origin-top transition-opacity-150 hover:opacity-100"
         , class "flex justify-between items-center"
         ]
            ++ currentSongClasses
        )
        [ if Song.isCurrent playlist song then
            viewPlayerButton model.player

          else
            text ""
        , viewSongName song isCurrent
        , div [ class "flex gap-2" ]
            [ viewYoutubeButton song isCurrent
            , viewCopyButton model.copiedSong song isCurrent
            ]
        ]
    )


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
        [ Time.every (1000 * 30) GetSongPlaying
        , copiedToClipboard Copied
        ]



-- Http


apiGetSongPlaying : Radio -> Cmd Msg
apiGetSongPlaying radio =
    Radio.apiGetSongPlaying
        { radio = radio
        , onMsg = GotSong
        }



-- Main


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
