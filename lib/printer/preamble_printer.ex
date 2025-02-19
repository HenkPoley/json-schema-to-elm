defmodule JS2E.Printer.PreamblePrinter do
  @moduledoc ~S"""
  A printer for printing a 'preamble' for a module.
  """

  require Elixir.{EEx, Logger}
  alias JS2E.Printer
  alias JsonSchema.Types
  alias Printer.PrinterResult
  alias Types.{SchemaDefinition, TypeReference}

  @templates_location Application.get_env(:js2e, :templates_location)

  @preamble_location Path.join(
                       @templates_location,
                       "preamble/preamble.elm.eex"
                     )

  EEx.function_from_file(:defp, :preamble_template, @preamble_location, [
    :prefix,
    :title,
    :description,
    :imports
  ])

  @spec print_preamble(
          SchemaDefinition.t(),
          Types.schemaDictionary(),
          String.t()
        ) :: PrinterResult.t()
  def print_preamble(
        %SchemaDefinition{
          id: _id,
          title: title,
          description: description,
          types: _type_dict
        } = schema_def,
        schema_dict,
        module_name
      ) do
    imports = create_imports(schema_def, schema_dict)

    module_name
    |> create_prefix()
    |> preamble_template(title, description, imports)
    |> PrinterResult.new()
  end

  @tests_preamble_location Path.join(
                             @templates_location,
                             "preamble/tests_preamble.elm.eex"
                           )

  EEx.function_from_file(
    :defp,
    :tests_preamble_template,
    @tests_preamble_location,
    [
      :prefix,
      :title,
      :description,
      :imports
    ]
  )

  @spec print_tests_preamble(
          SchemaDefinition.t(),
          Types.schemaDictionary(),
          String.t()
        ) :: PrinterResult.t()
  def print_tests_preamble(
        %SchemaDefinition{
          id: _id,
          title: title,
          description: description,
          types: _type_dict
        } = schema_def,
        schema_dict,
        module_name
      ) do
    imports = create_imports(schema_def, schema_dict)

    module_name
    |> create_prefix()
    |> tests_preamble_template(title, description, imports)
    |> PrinterResult.new()
  end

  @spec create_prefix(String.t()) :: String.t()
  defp create_prefix(module_name) do
    if module_name != "" do
      module_name <> "."
    else
      ""
    end
  end

  @spec create_imports(
          SchemaDefinition.t(),
          Types.schemaDictionary()
        ) :: [String.t()]
  defp create_imports(schema_def, schema_dict) do
    schema_id = schema_def.id
    type_dict = schema_def.types

    type_dict
    |> get_type_references
    |> create_dependency_map(schema_id, schema_dict)
    |> create_dependencies(schema_def, schema_dict)
  end

  @spec get_type_references(Types.typeDictionary()) :: [TypeReference.t()]
  defp get_type_references(type_dict) do
    type_dict
    |> Enum.reduce([], fn {_path, type}, types ->
      case type do
        %TypeReference{} ->
          [type | types]

        _ ->
          types
      end
    end)
  end

  @spec create_dependency_map(
          [TypeReference.t()],
          URI.t(),
          Types.schemaDictionary()
        ) :: %{required(String.t()) => TypeReference.t()}
  defp create_dependency_map(type_refs, schema_id, schema_dict) do
    type_refs
    |> Enum.reduce(%{}, fn type_ref, dependency_map ->
      type_ref
      |> resolve_dependency(dependency_map, schema_id, schema_dict)
    end)
  end

  @spec resolve_dependency(
          TypeReference.t(),
          %{required(String.t()) => [TypeReference.t()]},
          URI.t(),
          Types.schemaDictionary()
        ) :: %{required(String.t()) => [TypeReference.t()]}
  defp resolve_dependency(type_ref, dependency_map, schema_uri, schema_dict) do
    type_ref_uri = URI.parse(type_ref.path |> to_string)

    cond do
      has_relative_path?(type_ref_uri) ->
        dependency_map

      has_same_absolute_path?(type_ref_uri, schema_uri) ->
        dependency_map

      has_different_absolute_path?(type_ref_uri, schema_uri) ->
        type_ref_schema_uri =
          type_ref_uri
          |> Map.put(:fragment, nil)
          |> to_string

        type_ref_schema_def = schema_dict[type_ref_schema_uri]

        type_refs =
          if Map.has_key?(dependency_map, type_ref_schema_def.id) do
            [type_ref | dependency_map[type_ref_schema_def.id]]
          else
            [type_ref]
          end

        dependency_map
        |> Map.put(type_ref_schema_def.id, type_refs)

      true ->
        Logger.error("Could not resolve #{inspect(type_ref)}")
        Logger.error("with type_ref_uri #{to_string(type_ref_uri)}")
        Logger.error("In dependency map #{inspect(dependency_map)}")
        Logger.error("Where schema_uri #{inspect(schema_uri)}")
        Logger.error("and schema_dict #{inspect(schema_dict)}")
        dependency_map
    end
  end

  @spec create_dependencies(
          %{required(String.t()) => TypeReference.t()},
          SchemaDefinition.t(),
          Types.schemaDictionary()
        ) :: [String.t()]
  defp create_dependencies(dependency_map, _schema_def, schema_dict) do
    dependency_map
    |> Enum.map(fn {schema_id, _type_refs} ->
      type_ref_schema = schema_dict[to_string(schema_id)]
      type_ref_schema.title
    end)
  end

  @spec has_relative_path?(URI.t()) :: boolean
  defp has_relative_path?(type_uri) do
    type_uri.scheme == nil
  end

  @spec has_same_absolute_path?(URI.t(), URI.t()) :: boolean
  defp has_same_absolute_path?(type_uri, schema_uri) do
    # TODO: Should it be necessary that type_uri and schema_uri both have the
    # same host?
    type_uri.host == schema_uri.host and type_uri.path == schema_uri.path
  end

  @spec has_different_absolute_path?(URI.t(), URI.t()) :: boolean
  defp has_different_absolute_path?(type_uri, schema_uri) do
    type_uri.host == schema_uri.host and type_uri.path != schema_uri.path
  end
end
