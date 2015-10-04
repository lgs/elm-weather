module Weather where

import String
import Signal
import Effects exposing (Effects)
import Html exposing (..)
import Html.Attributes exposing (style, value, type', src)
import Html.Events exposing (on, onClick, targetValue)
import Http
import Json.Decode as Json
import Task


-- MODEL

type alias Model =
    { cities: List City
    , nameInput: String
    , nextId : Id
    }


type alias City =
    { id : Id
    , name : String
    , temp: Maybe.Maybe Int
    , loadingState: LoadingState
    }


type alias Id = Int


type LoadingState
    = Progress
    | Completed


init : (Model, Effects Action)
init =
  ( initialModel, Effects.none)

initialModel =
  { cities = [ ]
  , nameInput = ""
  , nextId = 0
  }

convertTemp : Maybe Float -> Maybe Int
convertTemp temp= Maybe.map round temp


-- UPDATE

type Action
    = NoOp
    | UpdateNameField String
    | Add
    | Delete Id
    | RequestTempUpdate City
    | RequestTempUpdateAll
    | UpdateTemp Id (Maybe Float)


update: Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    NoOp ->
      (model, Effects.none)

    UpdateNameField input ->
      ( { model | nameInput <- input }, Effects.none )

    Add ->
      let
      newCity = City model.nextId model.nameInput Nothing Progress
      in
        ({ model | nameInput <- "", cities <- newCity :: model.cities, nextId <- model.nextId + 1 }, getUpdatedTemp newCity )

    Delete id ->
      let
        citiesDeleted = List.filter (\e -> e.id /= id) model.cities
      in
      ( { model | cities <- citiesDeleted }, Effects.none )

    RequestTempUpdate city ->
      let
        changeCity = \e -> {e | loadingState  <- if e.id == city.id then Progress else e.loadingState }
        updateCities = List.map changeCity model.cities
      in
        ( { model | cities <- updateCities }, getUpdatedTemp city )

    UpdateTemp id temp ->
      let
        changeCity = \e -> {e | loadingState <- Completed, temp <- if e.id == id then (convertTemp temp) else e.temp }
        updatedCity = List.map changeCity model.cities
      in
        ( { model | cities <- updatedCity}, Effects.none )
    RequestTempUpdateAll ->
      let
        updateCities = List.map (\c -> getUpdatedTemp c) model.cities
        setProgress = List.map (\c -> { c | loadingState <- Progress }) model.cities
      in
        ( { model | cities <- setProgress}, Effects.batch updateCities)


-- VIEW

view: Signal.Address Action -> Model -> Html
view address model =
 div
   [ ]
   [ h1 [] [ text "Cities" ]
   , cityForm address model
   , cities address model
   ]

cityForm : Signal.Address Action -> Model -> Html
cityForm address model =
  div
    [ ]
    [ label [ ] [ text "Ctiy: " ]
    , input [ onInput address UpdateNameField, value model.nameInput] [ ]
    , input [ type' "button", value "Submit", onClick address Add] [ ]
    , input [ type' "button", value "Update All", onClick address RequestTempUpdateAll ] [ ]
    ]

onInput : Signal.Address a -> (String -> a) -> Attribute
onInput address f =
  on "input" targetValue (\v -> Signal.message address (f v))

cities : Signal.Address Action ->  Model -> Html
cities address model =
    table [ ] ( List.map (city address) model.cities)

city: Signal.Address Action -> City -> Html
city address city =
  let
    tempToString = Maybe.withDefault "..." (Maybe.map toString city.temp)
    cityTemp = case city.loadingState of
      Progress ->
        spinner
      Completed ->
         text (tempToString ++ "°C")
  in
    tr [ ]
      [ td [ ] [ text (toString city.id) ]
      , td [ ] [ text city.name ]
      , td [ ] [ cityTemp ]
      , td [ ] [ button [ onClick address (RequestTempUpdate city)] [ text "Update" ] ]
      , td [ ] [ button [ onClick address (Delete city.id)] [ text "delete" ] ]
      ]

spinner : Html
spinner =
  img [src "assets/spinner.gif"] []

-- EFFECTS

getUpdatedTemp : City -> Effects Action
getUpdatedTemp city =
  -- Http.getString "http://api.openweathermap.org/data/2.5/weather?q=neuss&units=metric"
  Http.get decodeData (weatherURL city.name)
  |> Task.toMaybe
  |> Task.map (UpdateTemp city.id)
  |> Effects.task

weatherURL: String -> String
weatherURL cityName =
  Http.url "http://api.openweathermap.org/data/2.5/weather" [ ("q", cityName), ("units", "metric")]

decodeData : Json.Decoder Float
decodeData =
  Json.at [ "main", "temp"] Json.float
