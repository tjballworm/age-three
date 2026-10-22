// Package game holds the game's domain types. The JSON shapes match packages/core/src/types in the
// web client, so the client can use what the server sends as-is.
package game

type ResourceType string

const (
	Gold   ResourceType = "gold"
	Food   ResourceType = "food"
	Lumber ResourceType = "lumber"
	Stone  ResourceType = "stone"
	Iron   ResourceType = "iron"
)

// ResourceStock is a resource as of a moment in time, plus how it changes.
type ResourceStock struct {
	Amount  float64 `json:"amount"`
	PerHour float64 `json:"perHour"`
	Cap     float64 `json:"cap"`
}

type Population struct {
	Current int `json:"current"`
	Max     int `json:"max"`
	Idle    int `json:"idle"`
}

type Player struct {
	ID       string  `json:"id"`
	Name     string  `json:"name"`
	Title    string  `json:"title"`
	Alliance *string `json:"alliance"`
	Prestige int     `json:"prestige"`
	Honor    int     `json:"honor"`
	Rank     int     `json:"rank"`
}

// TownBuilding is a building inside the walls. Slot is 0–31 (as a number) or "townhall" / "walls".
type TownBuilding struct {
	Type      string `json:"type"`
	Level     int    `json:"level"`
	Slot      any    `json:"slot"`
	Upgrading bool   `json:"upgrading,omitempty"`
}

type City struct {
	ID         string                         `json:"id"`
	Name       string                         `json:"name"`
	X          int                            `json:"x"`
	Y          int                            `json:"y"`
	Level      int                            `json:"level"`
	Resources  map[ResourceType]ResourceStock `json:"resources"`
	Population Population                     `json:"population"`
	Loyalty    int                            `json:"loyalty"`
	TaxRate    int                            `json:"taxRate"`
	Buildings  []TownBuilding                 `json:"buildings"`
}

// WorldSize matches WORLD_SIZE in packages/core: the map is WorldSize x WorldSize tiles and wraps.
const WorldSize = 100
