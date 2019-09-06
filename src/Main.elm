port module Main exposing (Model, Msg, init, update, view)

import Browser
import Html exposing (..)
import Html.Attributes exposing (class, colspan, href, id, target)
import Html.Events exposing (onClick)
import Http
import Json.Decode exposing (Decoder, field, string)
import Process
import Task
import Time


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Musica =
    String


type alias ListaMusicas =
    List Musica


type alias Model =
    { musicas : ListaMusicas
    , musicaCopiada : Musica
    }


port copyToClipboard : String -> Cmd msg


port copiedToClipboard : (String -> msg) -> Sub msg


init : () -> ( Model, Cmd Msg )
init _ =
    ( Model (List.repeat 6 "") "", getPlayingMusic )


type Msg
    = GetMusic Time.Posix
    | GotMusic (Result Http.Error String)
    | Copy String
    | Copied String
    | Uncopy


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotMusic response ->
            case response of
                Ok musica ->
                    ( { model | musicas = adicionarMusica musica model.musicas }, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        GetMusic _ ->
            ( model, getPlayingMusic )

        Copy musica ->
            ( model, copyToClipboard musica )

        Copied musica ->
            ( { model | musicaCopiada = musica }, Process.sleep 3000 |> Task.perform (\_ -> Uncopy) )

        Uncopy ->
            ( { model | musicaCopiada = "" }, Cmd.none )


view : Model -> Html Msg
view model =
    table [ colspan 2 ]
        (th [ colspan 2 ]
            [ text "Músicas tocadas" ]
            :: List.map (musicaParaTabela model) model.musicas
        )


musicaParaTabela : Model -> Musica -> Html Msg
musicaParaTabela model musica =
    tr [ class <| obterEstiloMusica model.musicas musica ]
        (if String.length musica == 0 then
            mostrarTdNaoMusica <| String.fromChar '\u{00A0}'

         else if ePropaganda musica then
            mostrarTdNaoMusica musica

         else
            [ mostrarTdMusica musica, mostrarTdBotao model.musicaCopiada musica ]
        )


mostrarTdNaoMusica : Musica -> List (Html Msg)
mostrarTdNaoMusica texto =
    [ td [ colspan 2 ] [ text texto ] ]


mostrarTdMusica : Musica -> Html Msg
mostrarTdMusica musica =
    td []
        [ a [ href <| linkMusica musica, target "_blank" ] [ text <| tratarMusica musica ]
        ]


mostrarTdBotao : Musica -> Musica -> Html Msg
mostrarTdBotao musicaCopiada musica =
    td [] [ button [ onClick <| Copy <| tratarMusica musica, class <| obterClasseBotao musicaCopiada musica ] [ text <| obterTextoBotao musicaCopiada musica ] ]


obterClasseBotao : String -> String -> String
obterClasseBotao musicaCopiada musica =
    if eMusicaCopiada musicaCopiada musica then
        "clicado"

    else
        ""


obterTextoBotao : String -> String -> String
obterTextoBotao musicaCopiada musica =
    if eMusicaCopiada musicaCopiada musica then
        "Copiado!"

    else
        "Copiar"


eMusicaCopiada : Musica -> Musica -> Bool
eMusicaCopiada copiada musica =
    copiada == tratarMusica musica


linkMusica : Musica -> String
linkMusica musica =
    musica
        |> String.replace " -" ""
        |> String.replace " " "+"
        |> String.append "https://www.youtube.com/results?search_query="


obterEstiloMusica : List Musica -> Musica -> String
obterEstiloMusica lista musica =
    if musicaAtual lista musica then
        "tocando-agora"

    else
        ""


tratarMusica : Musica -> Musica
tratarMusica musica =
    String.replace "(VHT)" "" musica


ePropaganda : Musica -> Bool
ePropaganda musica =
    String.contains "SPOT" musica


musicaAtual : List Musica -> Musica -> Bool
musicaAtual lista musica =
    List.take 1 lista == [ musica ]


adicionarMusica : Musica -> List Musica -> List Musica
adicionarMusica musica lista =
    if musicaAtual lista musica then
        lista

    else
        lista
            |> List.take 5
            |> List.append [ musica ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Time.every (1000 * 30) GetMusic
        , copiedToClipboard Copied
        ]


getPlayingMusic : Cmd Msg
getPlayingMusic =
    Http.get
        { url = "https://d36nr0u3xmc4mm.cloudfront.net/index.php/api/streaming/status/8192/2e1cbe43529055ddda74868d2db9ae98/SV4BR"
        , expect = Http.expectJson GotMusic musicDecoder
        }


musicDecoder : Decoder Musica
musicDecoder =
    field "currentTrack" string
