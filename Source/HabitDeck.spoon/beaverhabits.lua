---@class BeaverHabits
---@field api_base_path string Base path for the Beaver Habits API
---@field date_fmt string Date format string
---@field headers table HTTP headers
---@field endpoint string API endpoint URL
---@field log table Logger instance
local BeaverHabits = {
  api_base_path = "/api/v1/habits",
  date_fmt = "%d-%m-%Y",
  headers = {
    ["accept"] = "application/json",
    ["Content-Type"] = "application/json",
  },
}
BeaverHabits.__index = BeaverHabits

---Creates a new BeaverHabits client instance
---@param config Config Configuration for the client
---@return BeaverHabits client The new client instance or nil if login fails
function BeaverHabits.new(config)
  local self = setmetatable({}, BeaverHabits)
  self.log = hs.logger.new("BeaverHabits", "info")
  self.endpoint = config.endpoint

  self:login(config.username, config.password)
  return self
end

---Sends an HTTP request to the Beaver Habits API
---@param method string The HTTP method (GET, POST, PUT, DELETE)
---@param path string The API endpoint path
---@param body string|nil The request body (optional)
---@param headers table|nil Additional HTTP headers (optional)
---@return table|nil response The response body (decoded from JSON)
---@return string|nil error Error information if request fails
function BeaverHabits:_http_request(method, path, body, headers)
  if headers == nil then
    headers = self.headers
  end
  local url = self.endpoint .. path
  local status_code, res_body, _ = hs.http.doRequest(url, method, body, headers)

  if status_code < 200 or status_code >= 300 then
    local message
    if status_code == 0 then
      message = "Network error"
      if res_body then
        message = message .. ": " .. tostring(res_body)
      end
    else
      message = "HTTP error " .. tostring(status_code)
      if res_body then
        message = message .. ": " .. tostring(res_body)
      end
    end
    return nil, "Request to '" .. url .. "' failed. Cause: " .. message
  end

  return hs.json.decode(res_body), nil
end

---Authenticates with the Beaver Habits API
---@param username string The Beaver Habits username
---@param password string The Beaver Habits password
---@return string? error Error information if login fails
function BeaverHabits:login(username, password)
  local body = "grant_type=password&username=" .. username .. "&password=" .. password
  local login_headers = {
    ["Content-Type"] = "application/x-www-form-urlencoded",
    ["accept"] = "application/json",
  }
  local response_body, err = self:_http_request("POST", "/auth/login", body, login_headers)
  if err then
    error(err)
  end
  if not response_body then
    error("Could not parse response body of the login request")
  end
  self.headers["Authorization"] = "Bearer " .. response_body.access_token
end

---Retrieves the list of habits from the Beaver Habits API
---@return table|nil habits List of habits or nil if request fails
---@return string|nil error Error information if request fails
function BeaverHabits:get_habit_list()
  local response_body, err = self:_http_request("GET", self.api_base_path)
  if err then
    return nil, err
  end
  return response_body, nil
end

---Retrieves the completion records for a habit
---@param habit_id string The ID of the habit
---@param days integer The number of days to get records for
---@return table|nil records Habit completion records or nil if request fails
---@return string? error string if request fails
function BeaverHabits:get_habit_records(habit_id, days)
  local path = self.api_base_path .. "/" .. habit_id .. "/completions"
  local date_start = os.date("%d-%m-%Y", os.time() - (days - 1) * 24 * 60 * 60)
  local date_end = os.date("%d-%m-%Y")
  local params = {
    date_fmt = self.date_fmt,
    date_start = date_start,
    date_end = date_end,
    sort = "asc",
  }

  local query_params = "?"
  for key, value in pairs(params) do
    query_params = query_params .. key .. "=" .. value .. "&"
  end
  query_params = query_params:gsub("&$", "") -- Remove trailing '&'

  local full_path = path .. query_params

  local response_body, err = self:_http_request("GET", full_path)
  if err then
    return nil, err
  end
  return response_body, nil
end

---Creates a new completion record for a habit
---@param habit_id string The ID of the habit
---@param date string The date of the completion record
---@param done boolean Whether the habit was completed
---@return string? error string if request fails
function BeaverHabits:post_habit_record(habit_id, date, done)
  local body = {
    date_fmt = self.date_fmt,
    date = date,
    done = done,
  }

  local path = self.api_base_path .. "/" .. habit_id .. "/completions"
  local _, err = self:_http_request("POST", path, hs.json.encode(body))
  if err then
    return err
  end
end

return BeaverHabits
