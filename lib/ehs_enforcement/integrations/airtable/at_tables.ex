defmodule EhsEnforcement.Integrations.Airtable.AtTables do
  @doc """
  Returns a map of the Airtable Base Table Names and IDs for a given Base ID.
  """
  @type base_id :: binary()
  @type table_name :: binary()
  @type table_id :: binary()

  @spec get_table_id(base_id(), table_name()) :: {:ok, table_id()}
  def get_table_id(base_id, table_name) do
    case String.starts_with?(base_id, "app") and String.length(base_id) == 17 do
      false ->
        {:error, "not a valid base id"}

      _ ->
        case Map.get(table_ids(), base_id) do
          nil ->
            {:error, "Base id <#{base_id}> not found in table map"}

          tables ->
            # IO.inspect(tables)

            case Map.get(tables, format_table_name(table_name)) do
              nil ->
                {:error, "table name #{table_name} not found for #{base_id}"}

              table_id ->
                {:ok, table_id}
            end
        end
    end
  end

  defp format_table_name(str) do
    str
    |> String.downcase()
    |> String.replace(" ", "_")
  end

  defp table_ids do
    %{
      # uk e
      "appq5OQW9bTHC1zO5" => %{
        "uk" => "tblJW0DMpRs74CJux",
        "articles" => "tblJM9zmThl82vRD4",
        "interpretation" => "tblACciq9O8xB9dQH"
      },
      # envrionmental protection
      "appPFUz8wfo9RU7gN" => %{
        "uk_ep" => "tbl1onKrOyCgL6bNX",
        "articles" => "tbl8mfiyglQAhop5M"
      },
      # climate_change
      "appGv6qmDJK2Kdr3U" => %{
        "uk_climate_change" => "tblf0C8GtEXO0J8mk",
        "articles" => "tblZcr9MnPctaHJST"
      },
      # energy
      "app4L95N2NbK7x4M0" => %{
        "uk_energy" => "tblTc2z9Jfl7Mqc2N",
        "articles" => "tblnsuOdMTDbx1mBZ"
      },
      # finance
      "appokFoa6ERUUAIkF" => %{
        "uk_finance" => "tblA38ztoX51OMMRP",
        "articles" => "tblH107AQKjlk409E"
      },
      # marine_riverine
      "appLXqkeiiqrOXwWw" => %{
        "uk_marine_riverine" => "tbl235dp4xykUjJ0Z",
        "articles" => "tbl4EL3E2oSSerOLv"
      },
      # planning
      "appJ3UVvRHEGIpNi4" => %{
        "uk_planning" => "tblzltGwSX2DcP8oH",
        "articles" => "tbl2KfEVBN678T573"
      },
      # pollution
      "appj4oaimWQfwtUri" => %{
        "uk_pollution" => "tblkO070AAO2ARVvb",
        "articles" => "tblCLJTI62iGWXcgh"
      },
      # waste
      "appfXbCYZmxSFQ6uY" => %{
        "uk_waste" => "tbl8MXQF5pHbzNyHZ",
        "articles" => "tblyEwloJsZj5kojX"
      },
      # water
      "appCZkMT3VlCLtBjy" => %{
        "uk_water" => "tblWMgpytr8QxT57Z",
        "articles" => "tblVGFvjN1N3bXT8x"
      },
      # wildlife & countryside
      "appXXwjSS8KgDySB6" => %{
        "uk_wildlife_countryside" => "tbl5EWCPkNAiHUAof",
        "articles" => "tblgER2iCecH32aq5"
      },
      # radiological
      "appozWdOMaGdp77eL" => %{
        "uk_radiological" => "tbleI5O4KmKsQ1zAv",
        "articles" => "tblHghWewg8EPBp3K"
      },
      # town and country planning
      "appPocx8hT0EPCSfh" => %{
        "uk_town_country_planning" => "tblq86h5C2hBRwsXk",
        "articles" => "tbl85xgy1Zs5f6a4g"
      },
      # 💙💙💙💙💙💙💙💙💙💙💙💙💙💙💙💙💙💙
      # uk s
      "appRhQoz94zyVh2LR" => %{
        "uk" => "tbla82bppK8YnScrj",
        # Publication Date table
        "publication_date" => "tblQtdYg4MGIk3tzb"
      },

      # 💙 OH&S - 🇬🇧 ️UK - Occupational / Personal Health and Safety
      "appiwDnCNQaZOSaVR" => %{
        "uk" => "tblHUEuFxo8L0cssV",
        "articles" => "tblBdY62xWCqemsKQ"
      },

      # 💙 Fire Safety - 🇬🇧 ️UK
      "app0bGzy4uDbKrCF5" => %{
        "uk" => "tbl7wFWCayh2Tq7Y7",
        "articles" => "tbljS1iYOA5CaVUu4"
      },

      # 💙 Dangerous & Explosive Substances - 🇬🇧 ️UK
      "appqDhGjs1G7oVHrW" => %{
        "uk" => "tblc7FkLhGXW7Ha93",
        "articles" => "tblJkCpJc78yOpZgV"
      },

      # 💙 Mine & Quarry Safety  - 🇬🇧 ️UK
      "appuoNQFKM2SUI3lK" => %{
        "uk" => "tblnHWhLiTOIO6wD5",
        "articles" => "tblN58z5uSujkclaJ"
      },

      # 💙 Offshore Safety  - 🇬🇧 ️UK
      "appDoxScBrdBhxnOb" => %{
        "uk" => "tbltf8DOoJmwrlTlr",
        "articles" => "tblW5SBClxF2H1FDa"
      },

      # 💙 Gas & Electrical Safety - 🇬🇧 ️UK
      "appJu2qnECHmo9cln" => %{
        "uk" => "tblUEi0M3y54rmUgY",
        "articles" => "tbl2bn9NoI9NODuam"
      },

      # 💙 Product Safety & Consumer Protection - 🇬🇧 ️UK
      "appnTQBGljRQgVUhU" => %{
        "uk" => "tbl2jvncA7Vp1ukXq",
        "articles" => "tblGAbk65pjhGpc6T"
      }
    }
  end
end
