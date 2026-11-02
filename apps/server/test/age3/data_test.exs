defmodule Age3.DataTest do
  use ExUnit.Case, async: true
  alias Age3.Data

  test "has every building and field, with a cost and time for each level" do
    assert length(Data.building_types()) == 20
    assert "townhall" in Data.building_types() and "farm" in Data.building_types()

    for type <- Data.building_types() do
      assert length(Data.building(type)["levels"]) == Data.max_level()
    end
  end

  test "looks levels up from 1" do
    assert %{"cost" => %{"lumber" => lumber}, "seconds" => seconds} = Data.level("cottage", 1)
    assert lumber > 0 and seconds > 0
    assert Data.level("cottage", 2)["seconds"] > seconds
  end

  test "nil for unknown types and levels out of range" do
    assert Data.building("castle") == nil
    assert Data.level("castle", 1) == nil
    assert Data.level("cottage", 0) == nil
    assert Data.level("cottage", Data.max_level() + 1) == nil
  end
end
