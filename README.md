<div align="center">
  <img src="https://github.com/nov1n/HabitDeck/raw/refs/heads/main/demo.gif" alt="Demo">
</div>


# HabitDeck

HabitDeck is a [Hammerspoon](https://www.hammerspoon.org/) Spoon that integrates with [Beaver Habits](https://github.com/daya0576/beaverhabits) and a [Stream Deck](https://www.elgato.com/ww/en/p/stream-deck-mk2-black) to provide a visual representation and tracking of habits. It displays the completion status of three configurable habits for the last five days on the Stream Deck buttons. Clicking a button toggles the completion status of the corresponding habit for that day, and the state is synchronized with Beaver Habits.

## Installation

1. Download and run Beaver Habits.
2. Download and install Hammerspoon.
3. Download and unzip [`HabitDeck.spoon`](https://github.com/nov1n/HabitDeck/raw/refs/heads/main/Spoons/HabitDeck.spoon.zip) and place it in `~/.hammerspoon/Spoons/`.
4. Follow the [Configuration](#configuration) section below.

## Configuration

Before starting HabitDeck, you need to configure it with your Beaver Habits credentials and the habits you want to track. Here's an example configuration:

```lua
local habitDeck = hs.loadSpoon("HabitDeck")

habitDeck:start({
  endpoint = "http://localhost:7440",
  username = "your_username",
  password = "your_password",
  habits = { "Read", "Meditate", "Journal" },
})
```

Make sure to replace the placeholders with your actual Beaver Habits endpoint, username, and password, and the names of the habits you want to track (exactly three habits).

## Usage

After reloading Hammerspoon, it will automatically connect to your Stream Deck and display the completion status of the configured habits for the last five days. Each button represents a day, with the rightmost button being the current day and the leftmost button being four days ago.

To mark a habit as complete for a specific day, simply click the corresponding button on the Stream Deck. The button will update with a checkmark icon to indicate that the habit is complete for that day. Clicking the button again will toggle the completion status back to incomplete.

Completion statuses are automatically synced with the Beaver Habits every 10 seconds in case they are changed by another client (e.g. the web UI).

## API

### `habitDeck:start(config)` → `self`

Starts HabitDeck with the provided configuration.

#### Parameters

- `config` (table): A table containing the configuration for HabitDeck:
  - `endpoint` (string): The Beaver Habits API endpoint URL.
  - `username` (string): The Beaver Habits username.
  - `password` (string): The Beaver Habits password.
  - `habits` (table): A table containing the names of the habits to track (exactly 3 entries).

#### Returns

- `self` (HabitDeck object): The HabitDeck object.

### `habitDeck:stop()` → `self`

Stops HabitDeck and cleans up resources.

#### Returns

- `self` (HabitDeck object): The HabitDeck object.

## Contributing

If you find any issues or have suggestions for improvements, feel free to open an issue or submit a pull request on the [GitHub repository](https://github.com/nov1n/HabitDeck/issues).

## License

HabitDeck is released under the [MIT License](https://opensource.org/licenses/MIT).
