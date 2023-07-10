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
        [ div
            [ class "background absolute top-0 left-0 w-full h-full opacity-20" ]
            []
        , h3 [ class "text-center text-white text-3xl p-4" ]
            [ text "Rádio Gospel Mix" ]
        , viewPlayer
        , viewPlaylist model
        ]


viewPlayer : Html Msg
viewPlayer =
    div []
        [ audio
            [ controls True
            , class "hidden"
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
    Keyed.node "ul"
        [ class "mx-auto my-0"
        , class "flex flex-col gap-2 items-center"
        , class "w-fit h-full"
        ]
        (List.map
            (viewKeyedSong model)
            model.playlist
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
        isCurrent =
            isCurrentSong model.playlist song

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
    ( getSongName song.name
    , li
        ([ class "list-none"
         , class "transition-all duration-1000 origin-top transition-opacity-150 hover:opacity-100"
         , class "flex justify-between items-center"
         ]
            ++ currentSongClasses
        )
        [ if isCurrentSong model.playlist song then
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
                Unformatted "Intervalo"

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
    case songName of
        Formatted formattedSongName ->
            div [ songNameClasses ]
                [ div [ class "text-lg font-bold" ] [ text formattedSongName.title ]
                , div [ class "text-xs", artistClass ] [ text formattedSongName.artist ]
                ]

        Unformatted name ->
            div [ songNameClasses ] [ text name ]


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
        [ href <| songLink song
        , target "_blank"
        , class "rounded-full p-2 transition-all"
        , isCurrentSongClasses
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
