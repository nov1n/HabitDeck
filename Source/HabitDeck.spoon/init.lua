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
---@field timer table Timer instance for syncing
---@field streamdeck table Stream Deck instance
---@field is_done_image table Image for completed habits
---@field not_done_image table Image for incomplete habits
---@field sync_interval number Sync interval in seconds
---@field streamdeck_rows number Number of Stream Deck rows
---@field streamdeck_cols number Number of Stream Deck columns
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
obj.streamdeck = nil
obj.rows = nil
obj.cols = nil
obj.enable_notifications = true
obj.sync_interval = 10 -- Sync interval in seconds
obj.visuals = {
  image = {
    [true] = hs.image.imageFromPath(hs.spoons.resourcePath("images/square-check.regular.png")),
    [false] = hs.image.imageFromPath(hs.spoons.resourcePath("images/square.regular.png")),
  },
  ascii = {
    [true] = "✔",
    [false] = " ",
  },
}

---Starts the HabitDeck spoon with the provided configuration
---@param config Config Configuration settings
---@return HabitDeck self The HabitDeck instance
function obj:start(config)
  -- Ensure user config contains required keys
  for _, key in ipairs({ "username", "password", "endpoint", "habits" }) do
    assert(config[key], string.format("config invalid, key '%s' is missing", key))
  end

  -- Merge defaults with user config
  for key, value in pairs(config) do
    self[key] = value
  end

  self.client = beaver.new(config)

  hs.streamdeck.init(function(...)
    self:_handle_streamdeck(...)
  end)
  return self
end

---Stops the HabitDeck spoon and cleans up resources
---@return HabitDeck self The HabitDeck instance
function obj:stop()
  self.streamdeck = nil
  if self.timer then
    self.timer:stop()
    self.timer = nil
  end
  return self
end

---@private
function obj:_notify_on_changed(old_state)
  for i, state in ipairs(self.state) do
    if old_state[i] and state.is_done ~= old_state[i].is_done then
      self:_notify(
        string.format(
          "Habit '%s' on %s changed to %s.",
          state.habit_name,
          state.date,
          state.is_done and "done" or "not done"
        )
      )
    end
  end
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
---@return string? error string if request fails
function obj:_sync_state()
  local old_state = hs.fnutils.copy(self.state)

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
  for row = 1, self.rows do
    local habit_name = self.habits[row]
    local habit_id = names_to_ids[habit_name]
    if not habit_id then
      return "Habit '" .. habit_name .. "' does not exist."
    end
    local records, err = self.client:get_habit_records(habit_id, self.cols)
    if err then
      return err
    end
    for col = 1, self.cols do
      local index = (row - 1) * self.cols + col
      local day_offset = self.cols - col
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

  self:_notify_on_changed(old_state)
end

local function center_text(text, cols, col_size)
  text = (#text % 2 == 0) and text or " " .. text -- pad the text if it has odd length
  local width = cols * col_size
  local pad_length = (width - #text) / 2
  local pad_left = string.rep(" ", math.floor(pad_length))
  local pad_right = string.rep(" ", math.ceil(pad_length) - 1)
  return pad_left .. text .. pad_right
end

---@private
---@diagnostic disable-next-line: undefined-doc-name
---@param logger hs.logger The logger with which to log the data
---Logs a string representation of the habit data to the supplied logger
function obj:_print_state(logger)
  logger("┌" .. string.rep("────", self.cols - 1) .. "───┐")

  local title = "Stream Deck"
  local centered_title = center_text(title, self.cols, 4) -- each column is 4 characters wide
  logger("│" .. centered_title .. "│")
  logger("├" .. string.rep("───┬", self.cols - 1) .. "───┤")

  -- Print state grid
  local mid_border = "├" .. string.rep("───┼", self.cols - 1) .. "───┤"
  local row_str = "│"
  local col_idx = 1
  for _, habit in ipairs(self.state) do
    row_str = row_str .. " " .. self.visuals.ascii[habit.is_done] .. " │"

    col_idx = col_idx + 1
    if col_idx > self.cols then
      logger(row_str)
      row_str = "│"
      col_idx = 1

      if habit ~= self.state[#self.state] then
        logger(mid_border)
      end
    end
  end
  logger("└" .. string.rep("───┴", self.cols - 1) .. "───┘")
end

---@private
---Syncs the Stream Deck button images with the habit state
function obj:_sync_images()
  for i = 1, self.rows * self.cols do
    self.streamdeck:setButtonImage(i, self.visuals.image[self.state[i].is_done])
  end

  self:_print_state(self.log.i)
end

---@private
function obj:_notify(message)
  self.log.i(message)
  if self.enable_notifications then
    hs.notify.new({ title = "HabitDeck", informativeText = message }):send()
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

  self:_notify(
    string.format("Marked '%s' on %s as %s.", habit.habit_name, habit.date, habit.is_done and "done" or "not done")
  )
  self:_sync_images()
end

---@private
---Handles Stream Deck connection and disconnection events
---@param is_connected boolean Whether the Stream Deck is connected
---@param deck table? The Stream Deck object (if connected)
function obj:_handle_streamdeck(is_connected, deck)
  if is_connected then
    self.log.i("Stream Deck connected: " .. string.gsub(hs.inspect(deck), "<userdata %d+> %-%- hs%.streamdeck: ", ""))
    self.streamdeck = deck
    self.cols, self.rows = self.streamdeck:buttonLayout()
    assert(#self.habits == self.rows, "'habits' key must have exactly " .. self.rows .. " names")

    self:_sync()
    self.timer = hs.timer.doEvery(self.sync_interval, function()
      self:_sync()
    end)
    self.streamdeck:buttonCallback(function(...)
      self:_button_callback(...)
    end)
  else
    self.log.i("Stream Deck disconnected")
    self:stop()
  end
end

return obj
