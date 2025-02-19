module Data.DefinitionsTests exposing
    ( colorFuzzer
    , encodeDecodeColorTest
    , encodeDecodePointTest
    , pointFuzzer
    )

-- Tests: Schema for common types

import Data.Definitions exposing (..)
import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Json.Decode as Decode
import Test exposing (..)


colorFuzzer : Fuzzer Color
colorFuzzer =
    Fuzz.oneOf
        [ Fuzz.constant Red
        , Fuzz.constant Yellow
        , Fuzz.constant Green
        , Fuzz.constant Blue
        ]


encodeDecodeColorTest : Test
encodeDecodeColorTest =
    fuzz colorFuzzer "can encode and decode Color object" <|
        \color ->
            color
                |> encodeColor
                |> Decode.decodeValue colorDecoder
                |> Expect.equal (Ok color)


pointFuzzer : Fuzzer Point
pointFuzzer =
    Fuzz.map2
        Point
        Fuzz.float
        Fuzz.float


encodeDecodePointTest : Test
encodeDecodePointTest =
    fuzz pointFuzzer "can encode and decode Point object" <|
        \point ->
            point
                |> encodePoint
                |> Decode.decodeValue pointDecoder
                |> Expect.equal (Ok point)
