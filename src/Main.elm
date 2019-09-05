module Main exposing (Model, Msg, init, update, view)

import Browser
import Html exposing (..)
import Html.Attributes exposing (colspan)
import Http
import Json.Decode exposing (Decoder, field, string)


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    { musicas : ListaMusicas
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( Model <| List.repeat 6 <| String.fromChar '\u{00A0}', getPlayingMusic )


type Msg
    = NoOp
    | GotMusic (Result Http.Error String)


type alias ListaMusicas =
    List String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        GotMusic response ->
            case response of
                Ok musica ->
                    ( { model | musicas = adicionarMusica musica model.musicas }, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )


view : Model -> Html Msg
view model =
    table [ colspan 2 ]
        (th [ colspan 2 ]
            [ text "Músicas tocadas" ]
            :: List.map musicaParaTabela model.musicas
        )


musicaParaTabela : String -> Html Msg
musicaParaTabela musica =
    tr []
        [ if String.length musica == 0 then
            td [ colspan 2 ] [ text "" ]

          else
            td [] [ text musica ]
        ]


adicionarMusica : String -> List String -> List String
adicionarMusica musica lista =
    if List.member musica lista then
        lista

    else
        lista
            |> List.take 5
            |> List.append [ musica ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


getPlayingMusic : Cmd Msg
getPlayingMusic =
    Http.get
        { url = "https://d36nr0u3xmc4mm.cloudfront.net/index.php/api/streaming/status/8192/2e1cbe43529055ddda74868d2db9ae98/SV4BR"
        , expect = Http.expectJson GotMusic musicDecoder
        }


musicDecoder : Decoder String
musicDecoder =
    field "currentTrack" string
