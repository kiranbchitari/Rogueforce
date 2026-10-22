class_name RF
## Shared constants.

const TILE := 64
const GRAVITY := 2300.0
const VIEW_SIZE := Vector2(1280, 720)

# Physics layer bits (see project settings > layer names).
const LAYER_WORLD := 1
const LAYER_PLATFORM := 2
const LAYER_PLAYER := 4
const LAYER_ENEMY := 8

enum Team { PLAYER, ENEMY }
