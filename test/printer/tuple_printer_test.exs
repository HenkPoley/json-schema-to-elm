defmodule JS2ETest.Printer.TuplePrinter do
  use ExUnit.Case

  require Logger
  alias JS2E.Printer
  alias JsonSchema.Types
  alias Printer.TuplePrinter
  alias Types.{ObjectType, SchemaDefinition, TupleType, TypeReference}

  test "print 'tuple' type value" do
    result =
      tuple_type()
      |> TuplePrinter.print_type(schema_def(), %{}, module_name())

    expected_tuple_type_program = """
    type alias ShapePair =
        ( Square
        , Circle
        )
    """

    tuple_type_program = result.printed_schema

    assert tuple_type_program == expected_tuple_type_program
  end

  test "print 'tuple' decoder" do
    result =
      tuple_type()
      |> TuplePrinter.print_decoder(schema_def(), %{}, module_name())

    expected_tuple_decoder_program = """
    shapePairDecoder : Decoder ShapePair
    shapePairDecoder =
        Decode.map2 (,)
            (index 0 squareDecoder)
            (index 1 circleDecoder)
    """

    tuple_decoder_program = result.printed_schema

    assert tuple_decoder_program == expected_tuple_decoder_program
  end

  test "print 'tuple' encoder" do
    result =
      tuple_type()
      |> TuplePrinter.print_encoder(schema_def(), %{}, module_name())

    expected_tuple_encoder_program = """
    encodeShapePair : ShapePair -> Value
    encodeShapePair (square, circle) =
        []
            |> (::) encodeSquare square
            |> (::) encodeCircle circle
            |> Encode.list
    """

    tuple_encoder_program = result.printed_schema

    assert tuple_encoder_program == expected_tuple_encoder_program
  end

  test "print tuple fuzzer" do
    result =
      tuple_type()
      |> TuplePrinter.print_fuzzer(schema_def(), %{}, module_name())

    expected_tuple_fuzzer = """
    shapePairFuzzer : Fuzzer ShapePair
    shapePairFuzzer =
        Fuzz.tuple
            (squareFuzzer
            , circleFuzzer
            )


    encodeDecodeShapePairTest : Test
    encodeDecodeShapePairTest =
        fuzz shapePairFuzzer "can encode and decode ShapePair tuple" <|
            \\shapePair ->
                shapePair
                    |> encodeShapePair
                    |> Decode.decodeValue shapePairDecoder
                    |> Expect.equal (Ok shapePair)
    """

    tuple_fuzzer = result.printed_schema

    assert tuple_fuzzer == expected_tuple_fuzzer
  end

  defp module_name, do: "Domain"

  defp tuple_type,
    do: %TupleType{
      name: "shapePair",
      path: URI.parse("#/shapePair"),
      items: [
        URI.parse("#/shapePair/0"),
        URI.parse("#/shapePair/1")
      ]
    }

  defp schema_def,
    do: %SchemaDefinition{
      description: "Test schema",
      id: URI.parse("http://example.com/test.json"),
      title: "Test",
      types: type_dict()
    }

  defp type_dict,
    do: %{
      "#/shapePair/0" => %TypeReference{
        name: "0",
        path: URI.parse("#/definitions/square")
      },
      "#/shapePair/1" => %TypeReference{
        name: "1",
        path: URI.parse("#/definitions/circle")
      },
      "#/definitions/square" => %ObjectType{
        name: "square",
        path: URI.parse("#"),
        required: ["color", "size"],
        properties: %{
          "color" => URI.parse("#/properties/color"),
          "title" => URI.parse("#/properties/size")
        }
      },
      "#/definitions/circle" => %ObjectType{
        name: "circle",
        path: ["#"],
        required: ["color", "radius"],
        properties: %{
          "color" => URI.parse("#/properties/color"),
          "radius" => URI.parse("#/properties/radius")
        }
      }
    }
end
