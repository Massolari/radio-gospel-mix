module SongName exposing (SongName, fromString, match, newFormatted, newUnformatted, toString, toYoutubeLink)

-- Types


type SongName
    = Formatted FormattedSongName
    | Unformatted String


type alias FormattedSongName =
    { artist : String
    , title : String
    }



-- Constructors


newUnformatted : String -> SongName
newUnformatted =
    Unformatted


newFormatted : { artist : String, title : String } -> SongName
newFormatted =
    Formatted



-- Helpers


fromString : String -> SongName
fromString name =
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


toString : SongName -> String
toString songName =
    case songName of
        Formatted { artist, title } ->
            title ++ " - " ++ artist

        Unformatted name ->
            name


toYoutubeLink : SongName -> String
toYoutubeLink =
    toString
        >> String.replace " -" ""
        >> String.replace " " "+"
        >> String.append "https://www.youtube.com/results?search_query="


match :
    SongName
    ->
        { formatted : FormattedSongName -> a
        , unformatted : String -> a
        }
    -> a
match songName { formatted, unformatted } =
    case songName of
        Formatted formattedSongName ->
            formatted formattedSongName

        Unformatted name ->
            unformatted name
