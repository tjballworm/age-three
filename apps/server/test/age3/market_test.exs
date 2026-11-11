defmodule Age3.MarketTest do
  # The Marketplace: the pure rules, and trading against Postgres (mix test --include db).
  use ExUnit.Case, async: true

  alias Age3.{Building, Market, Repo, Store.Pg}

  describe "rules" do
    test "checks, gold and fees" do
      assert Market.check(0, 0, "buy", "food", 1, 1) == {:error, "requirement_not_met"}
      assert Market.check(2, 2, "buy", "food", 1, 1) == {:error, "market_full"}
      assert Market.check(2, 1, "buy", "gold", 1, 1) == {:error, "bad_message"}
      assert Market.check(2, 1, "sell", "iron", 0, 1) == {:error, "bad_message"}
      assert Market.check(2, 1, "sell", "iron", 10, 50) == :ok
      assert Market.gold(1000, 50) == 50.0
      assert Market.fee(1000) == 5.0
    end

    test "a new order trades with the best prices that meet it, at their price" do
      book = [
        %{id: 1, amount: 100, price: 40},
        %{id: 2, amount: 100, price: 50},
        %{id: 3, amount: 100, price: 70}
      ]

      {fills, left} = Market.match("buy", 150, 60, book)
      assert [{%{id: 1}, 100}, {%{id: 2}, 50}] = fills
      assert left == 0
      assert {[], 10} = Market.match("buy", 10, 30, book)
      {[{%{id: 1}, 100}, {%{id: 2}, 100}], 50} = Market.match("buy", 250, 50, book)
    end
  end

  describe "trading" do
    @describetag :db

    setup do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Age3.Repo)
    end

    defp trader(name) do
      {:ok, id} = Pg.find_or_create_player(name)
      now = System.system_time(:millisecond)
      {:ok, _, [city], []} = Pg.state(id, now)
      Repo.insert!(%Building{city_id: city.id, slot: "6", type: "marketplace", level: 2})
      %{id: id, city: city.id, now: now}
    end

    defp amount(t, r) do
      {:ok, _, [city], _} = Pg.state(t.id, t.now)
      city.resources[r]["amount"]
    end

    test "sell, buy at a higher bid, partial fills and cancel" do
      s = trader("Seller")
      b = trader("Buyer")
      food = amount(s, "food")
      gold_s = amount(s, "gold")
      gold_b = amount(b, "gold")

      # 1,000 food at 0.5 gold each rests in the book
      assert {:ok, []} = Pg.place_order(s.id, s.city, "sell", "food", 1000, 500, s.now)
      assert_in_delta amount(s, "food"), food - 1000, 1

      {:ok, %{books: %{"food" => %{sell: [%{price: 500, amount: 1000}]}}, orders: [_]}} =
        Pg.market(s.id, s.city)

      # a bid of 0.6 for 400 buys at 0.5; the seller gets 200 gold less 0.5%
      assert {:ok, [seller]} = Pg.place_order(b.id, b.city, "buy", "food", 400, 600, b.now)
      assert seller == s.id
      assert_in_delta amount(b, "gold"), gold_b - 200, 1
      assert_in_delta amount(s, "gold"), gold_s + 199, 1
      {:ok, %{books: %{"food" => %{sell: [%{amount: 600}], last: 500}}}} = Pg.market(b.id, b.city)

      # a bid too low rests; the city's order cap is its Marketplace level
      assert {:ok, []} = Pg.place_order(b.id, b.city, "buy", "food", 100, 100, b.now)
      assert {:ok, []} = Pg.place_order(b.id, b.city, "buy", "iron", 100, 100, b.now)
      assert {:error, "market_full"} = Pg.place_order(b.id, b.city, "buy", "stone", 1, 1, b.now)

      assert {:error, "not_enough_resources"} =
               Pg.place_order(s.id, s.city, "sell", "iron", 9_000_000, 1, s.now)

      # cancelling gives back the rest
      {:ok, %{orders: [order]}} = Pg.market(s.id, s.city)
      assert :ok = Pg.cancel_order(s.id, s.city, order.id, s.now)
      assert_in_delta amount(s, "food"), food - 400, 1
    end
  end
end
