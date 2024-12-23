--- HabitDeck
--- A Spoon for tracking habits using the Beaver Habits API and a Stream Deck

local beaver = dofile(hs.spoons.resourcePath("beaverhabits.lua"))

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "HabitDeck"
obj.version = "0.1"
obj.author = "Robert Carosi <robert@carosi.nl>"
obj.homepage = "https://github.com/nov1n/HabitDeck"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.habits = nil
obj.log = hs.logger.new("HabitDeck", "info")
obj.beaver_client = nil
obj.state = {}
obj.timer = nil
obj.stream_deck = nil
obj.is_done_image = hs.image.imageFromPath(hs.spoons.resourcePath("images/square-check.regular.png"))
obj.not_done_image = hs.image.imageFromPath(hs.spoons.resourcePath("images/square.regular.png"))
obj.sync_interval = 10 -- Sync interval in seconds
obj.stream_deck_rows = 3
obj.stream_deck_cols = 5

--- HabitDeck:start(config)
--- Method
--- Starts the HabitDeck spoon with the provided configuration
---
--- Parameters:
---  * config - A table containing the configuration for HabitDeck
---    - endpoint - A string containing the Beaver endpoint URL
---    - username - A string containing the Beaver username
---    - password - A string containing the Beaver password
---    - habits   - A table containing the names of the habits to track (exactly 3 entries)
---
--- Returns:
---  * The HabitDeck object
function obj:start(config)
  self:_configure(config)
  hs.streamdeck.init(function(...) self:_handle_stream_deck(...) end)
  return self
end

--- HabitDeck:stop()
--- Method
--- Stops the HabitDeck spoon and cleans up resources
---
--- Returns:
---  * The HabitDeck object
function obj:stop()
  self.stream_deck = nil
  if self.timer then
    self.timer:stop()
    self.timer = nil
  end
  return self
end

--- HabitDeck:_configure(config)
--- Method
--- Configures the HabitDeck spoon with the provided configuration
---
--- Parameters:
---  * config - A table containing the configuration for HabitDeck
---    - endpoint - A string containing the Beaver endpoint URL
---    - username - A string containing the Beaver username
---    - password - A string containing the Beaver password
---    - habits   - A table containing the names of the habits to track (exactly 3 entries)
function obj:_configure(config)
  for _, key in ipairs({ "username", "password", "endpoint", "habits" }) do
    assert(config[key], string.format("config invalid, key '%s' is missing", key))
  end
  assert(#config.habits == 3, "'habits' key must have exactly 3 entries")
  self.beaver_client = beaver.get_client(config.endpoint, config.username, config.password)
  self.habits = config.habits
end

--- HabitDeck:_sync()
--- Method
--- Syncs the habit state and updates the Stream Deck buttons
function obj:_sync()
  self.log.i("Syncing...")
  self:_sync_state()
  self:_sync_images()
end

--- HabitDeck:_sync_state()
--- Method
--- Syncs the habit state with the Beaver Habits API
function obj:_sync_state()
  local names_to_ids = {}
  for _, name in ipairs(self.habits) do
    for _, habit in ipairs(beaver.get_habit_list()) do
      if habit.name == name then names_to_ids[name] = habit.id end
    end
  end

  for row = 1, self.stream_deck_rows do
    local habit_name = self.habits[row]
    local habit_id = names_to_ids[habit_name]
    local records = beaver:get_habit_records(habit_id)
    for col = 1, self.stream_deck_cols do
      local index = (row - 1) * self.stream_deck_cols + col
      local day_offset = self.stream_deck_cols - col
      local date = os.date("%d-%m-%Y", os.time() - day_offset * 24 * 60 * 60)
      local is_done = hs.fnutils.contains(records, date)
      self.state[index] = {
        is_done = is_done,
        date = date,
        habit_id = habit_id,
      }
    end
  end
end

--- HabitDeck:_get_image(is_done)
--- Method
--- Returns the appropriate image for the habit completion state
---
--- Parameters:
---  * is_done - A boolean indicating whether the habit is completed
---
--- Returns:
---  * An hs.image object representing the appropriate image
function obj:_get_image(is_done) return is_done and self.is_done_image or self.not_done_image end

--- HabitDeck:_sync_images()
--- Method
--- Syncs the Stream Deck button images with the habit state
function obj:_sync_images()
  for i = 1, self.stream_deck_rows * self.stream_deck_cols do
    self.stream_deck:setButtonImage(i, self:_get_image(self.state[i].is_done))
  end
end

--- HabitDeck:_button_callback(_, index, is_pressed)
--- Method
--- Callback function for Stream Deck button presses
---
--- Parameters:
---  * _ - Unused parameter
---  * index - The index of the pressed button
---  * is_pressed - A boolean indicating whether the button was pressed or released
function obj:_button_callback(_, index, is_pressed)
  if not is_pressed then return end -- Release events are not supported yet
  self.log.i("Clicked button " .. index)
  local habit = self.state[index]
  self.beaver_client:post_habit_record(habit.habit_id, habit.date, not habit.is_done)
  habit.is_done = not habit.is_done
  self:_sync_images()
end

--- HabitDeck:_handle_stream_deck(is_connected, deck)
--- Method
--- Handles Stream Deck connection and disconnection events
---
--- Parameters:
---  * is_connected - A boolean indicating whether the Stream Deck is connected or disconnected
---  * deck - The Stream Deck object (if connected)
function obj:_handle_stream_deck(is_connected, deck)
  if is_connected then
    self.log.i("Stream Deck connected")
    self.stream_deck = deck
    self.timer = hs.timer.doEvery(self.sync_interval, function() self:_sync() end)
    obj:_sync()
    self.stream_deck:buttonCallback(function(...) self:_button_callback(...) end)
  else
    self.log.i("Stream Deck disconnected")
    self:stop()
  end
end

return obj
