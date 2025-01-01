---@meta

---@class Config
---@field endpoint string Beaver API endpoint URL
---@field username string Beaver account username
---@field password string Beaver account password
---@field habits string[] Array of exactly 3 habit names to track
---@field enable_notifications boolean Whether to show a Desktop notification when updating a habit

---@class HabitDeck
---@field name string Name of the spoon
---@field version string Version of the spoon
---@field author string Author information
---@field homepage string URL to the project homepage
---@field license string License information
---@field habits string[] List of habit names to track
---@field log table Logger instance
---@field client table Beaver API client instance
---@field state table State information for habits
---@field timer table? Timer instance for syncing
---@field stream_deck table? Stream Deck instance
---@field is_done_image table Image for completed habits
---@field not_done_image table Image for incomplete habits
---@field sync_interval number Sync interval in seconds
---@field stream_deck_rows number Number of Stream Deck rows
---@field stream_deck_cols number Number of Stream Deck columns
---@field enable_notifications boolean Whether to show a Desktop notification when updating a habit

local beaver = dofile(hs.spoons.resourcePath("beaverhabits.lua"))

local obj = {}
obj.__index = obj
obj.name = "HabitDeck"
obj.version = "0.1"
obj.author = "Robert Carosi <robert@carosi.nl>"
obj.homepage = "https://github.com/nov1n/HabitDeck"
obj.license = "MIT - https://opensource.org/licenses/MIT"
obj.habits = {}
obj.log = hs.logger.new("HabitDeck", "info")
obj.client = nil
obj.state = {}
obj.timer = nil
obj.stream_deck = nil
obj.enable_notifications = true
obj.sync_interval = 10 -- Sync interval in seconds
obj.stream_deck_rows = 3
obj.stream_deck_cols = 5
obj.visuals = {
  image = {
    [true] = hs.image.imageFromPath(hs.spoons.resourcePath("images/square-check.regular.png")),
    [false] = hs.image.imageFromPath(hs.spoons.resourcePath("images/square.regular.png")),
  },
  ascii = {
    [true] = "x",
    [false] = " ",
  },
}

---Starts the HabitDeck spoon with the provided configuration
---@param config Config Configuration settings
---@return HabitDeck self The HabitDeck instance
function obj:start(config)
  for _, key in ipairs({ "username", "password", "endpoint", "habits" }) do
    assert(config[key], string.format("config invalid, key '%s' is missing", key))
  end
  assert(#config.habits == 3, "'habits' key must have exactly 3 entries")
  self.client = beaver.new(config)
  for key, value in pairs(config) do
    self[key] = value
  end

  hs.streamdeck.init(function(...)
    self:_handle_stream_deck(...)
  end)
  return self
end

---Stops the HabitDeck spoon and cleans up resources
---@return HabitDeck self The HabitDeck instance
function obj:stop()
  self.stream_deck = nil
  if self.timer then
    self.timer:stop()
    self.timer = nil
  end
  return self
end

---@private
---Syncs the habit state and updates the Stream Deck buttons
function obj:_sync()
  self.log.i("Syncing state with BeaverHabits...")
  err = self:_sync_state()
  if err then
    self.log.e("Error syncing with BeaverHabits: " .. err)
    return
  end
  self:_sync_images()
  self.log.i("Next sync in " .. self.sync_interval .. " seconds.")
end

---@private
---Syncs the habit state with the Beaver Habits API
---@return string error string if request fails
function obj:_sync_state()
  -- Update mapping of habit names to ids
  local names_to_ids = {}
  for _, name in ipairs(self.habits) do
    habits, err = self.client:get_habit_list()
    if err then
      return err
    end
    for _, habit in ipairs(habits) do
      if habit.name == name then
        names_to_ids[name] = habit.id
      end
    end
  end

  -- Create state list corresponding to the indexes of StreamDeck buttons
  for row = 1, self.stream_deck_rows do
    local habit_name = self.habits[row]
    local habit_id = names_to_ids[habit_name]
    if not habit_id then
      return "Habit '" .. habit_name .. "' does not exist."
    end
    local records, err = self.client:get_habit_records(habit_id, self.stream_deck_cols)
    if err then
      return err
    end
    for col = 1, self.stream_deck_cols do
      local index = (row - 1) * self.stream_deck_cols + col
      local day_offset = self.stream_deck_cols - col
      local date = os.date("%d-%m-%Y", os.time() - day_offset * 24 * 60 * 60)
      local is_done = hs.fnutils.contains(records, date)
      self.state[index] = {
        is_done = is_done,
        date = date,
        habit_id = habit_id,
        habit_name = habit_name,
      }
    end
  end
end

end

---@private
---Syncs the Stream Deck button images with the habit state
function obj:_sync_images()
  for i = 1, self.stream_deck_rows * self.stream_deck_cols do
    self.stream_deck:setButtonImage(i, self.visuals.image[self.state[i].is_done])
  end
end

---@private
---Callback function for Stream Deck button presses
---@param _ any Unused parameter
---@param index number The index of the pressed button (1-based)
---@param is_pressed boolean Whether the button was pressed or released
function obj:_button_callback(_, index, is_pressed)
  if not is_pressed then
    return
  end -- Release events are not supported yet
  local habit = self.state[index]
  err = self.client:post_habit_record(habit.habit_id, habit.date, not habit.is_done)
  if err then
    return err
  end

  -- Send notificatioon if enabled
  habit.is_done = not habit.is_done
  update_message = "Marked '"
    .. habit.habit_name
    .. "' on "
    .. habit.date
    .. " as "
    .. (habit.is_done and "done" or "not done")
    .. "."
  self.log.i(update_message)
  if self.enable_notifications then
    hs.notify.new({ title = "HabitDeck", informativeText = update_message }):send()
  end
  self:_sync_images()
end

---@private
---Handles Stream Deck connection and disconnection events
---@param is_connected boolean Whether the Stream Deck is connected
---@param deck table? The Stream Deck object (if connected)
function obj:_handle_stream_deck(is_connected, deck)
  if is_connected then
    self.log.i("Stream Deck connected")
    self.stream_deck = deck
    obj:_sync()
    self.timer = hs.timer.doEvery(self.sync_interval, function()
      self:_sync()
    end)
    self.stream_deck:buttonCallback(function(...)
      self:_button_callback(...)
    end)
  else
    self.log.i("Stream Deck disconnected")
    self:stop()
  end
end

return obj
