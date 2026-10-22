// Package store is all database access. Game logic talks to the Store interface, so it can be tested
// without a database.
package store

import (
	"context"
	"errors"
	"fmt"
	"math/rand/v2"
	"strconv"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tjballworm/age-three/apps/server/internal/game"
)

var ErrNotFound = errors.New("not found")

type Store interface {
	// Login finds the player with this name, creating them and a starter city the first time.
	Login(ctx context.Context, name string) (playerID string, err error)
	// State is the player and all their cities, with buildings.
	State(ctx context.Context, playerID string) (game.Player, []game.City, error)
}

type Pg struct{ pool *pgxpool.Pool }

func NewPg(pool *pgxpool.Pool) *Pg { return &Pg{pool} }

func starterResources() map[game.ResourceType]game.ResourceStock {
	s := func(amount, perHour float64) game.ResourceStock {
		return game.ResourceStock{Amount: amount, PerHour: perHour, Cap: 100_000}
	}
	return map[game.ResourceType]game.ResourceStock{
		game.Gold: s(5_000, 100), game.Food: s(10_000, 200), game.Lumber: s(10_000, 200),
		game.Stone: s(10_000, 200), game.Iron: s(5_000, 100),
	}
}

func (s *Pg) Login(ctx context.Context, name string) (string, error) {
	var id string
	err := s.pool.QueryRow(ctx, `select id from players where name = $1`, name).Scan(&id)
	if err == nil {
		return id, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return "", err
	}

	err = pgx.BeginFunc(ctx, s.pool, func(tx pgx.Tx) error {
		if err := tx.QueryRow(ctx, `insert into players (name) values ($1)
			on conflict (name) do update set name = excluded.name returning id`, name).Scan(&id); err != nil {
			return err
		}
		// a random free spot; the unique (x, y) constraint settles any race
		for tries := 0; tries < 50; tries++ {
			var cityID string
			err := tx.QueryRow(ctx, `insert into cities (player_id, name, x, y, resources, population)
				values ($1, $2, $3, $4, $5, $6) on conflict (x, y) do nothing returning id`,
				id, name+"'s Town", rand.IntN(game.WorldSize), rand.IntN(game.WorldSize),
				starterResources(), game.Population{Current: 100, Max: 500, Idle: 100},
			).Scan(&cityID)
			if errors.Is(err, pgx.ErrNoRows) {
				continue
			}
			if err != nil {
				return err
			}
			_, err = tx.Exec(ctx, `insert into buildings (city_id, slot, type, level)
				values ($1, 'townhall', 'townhall', 1), ($1, 'walls', 'walls', 1)`, cityID)
			return err
		}
		return fmt.Errorf("no free map spot for %q", name)
	})
	return id, err
}

func (s *Pg) State(ctx context.Context, playerID string) (game.Player, []game.City, error) {
	var p game.Player
	err := s.pool.QueryRow(ctx, `select id, name, title, alliance, prestige, honor from players where id = $1`, playerID).
		Scan(&p.ID, &p.Name, &p.Title, &p.Alliance, &p.Prestige, &p.Honor)
	if errors.Is(err, pgx.ErrNoRows) {
		return p, nil, ErrNotFound
	}
	if err != nil {
		return p, nil, err
	}

	rows, err := s.pool.Query(ctx, `select id, name, x, y, level, loyalty, tax_rate, resources, population
		from cities where player_id = $1 order by id`, playerID)
	if err != nil {
		return p, nil, err
	}
	cities, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (game.City, error) {
		var c game.City
		err := r.Scan(&c.ID, &c.Name, &c.X, &c.Y, &c.Level, &c.Loyalty, &c.TaxRate, &c.Resources, &c.Population)
		c.Buildings = []game.TownBuilding{}
		return c, err
	})
	if err != nil {
		return p, nil, err
	}

	byID := map[string]*game.City{}
	ids := make([]string, len(cities))
	for i := range cities {
		byID[cities[i].ID] = &cities[i]
		ids[i] = cities[i].ID
	}
	rows, err = s.pool.Query(ctx, `select city_id, slot, type, level, upgrading from buildings where city_id = any($1)`, ids)
	if err != nil {
		return p, nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var cityID, slot string
		var b game.TownBuilding
		if err := rows.Scan(&cityID, &slot, &b.Type, &b.Level, &b.Upgrading); err != nil {
			return p, nil, err
		}
		// plots go to the client as numbers, the Town Hall and walls as names
		if n, err := strconv.Atoi(slot); err == nil {
			b.Slot = n
		} else {
			b.Slot = slot
		}
		if c := byID[cityID]; c != nil {
			c.Buildings = append(c.Buildings, b)
		}
	}
	return p, cities, rows.Err()
}
