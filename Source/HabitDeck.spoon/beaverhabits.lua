--- BeaverHabits
--- A Spoon for interacting with the Beaver Habits API

local api_base_path = "/api/v1/habits"

local obj = {}

obj.log = hs.logger.new("BeaverHabits", "info")

--- BeaverHabits date format
obj.date_fmt = "%d-%m-%Y"

--- BeaverHabits endpoint URL
obj.endpoint = nil

--- BeaverHabits HTTP headers
obj.headers = {
  ["accept"] = "application/json",
  ["Content-Type"] = "application/json",
}

--- BeaverHabits:http_request(method, path, body, headers)
--- Method
--- Sends an HTTP request to the Beaver Habits API
---
--- Parameters:
---  * method  - The HTTP method (GET, POST, PUT, DELETE)
---  * path    - The API endpoint path
---  * body    - The request body (optional)
---  * headers - Additional HTTP headers (optional)
---
--- Returns:
---  * The response body (decoded from JSON)
---  * The HTTP status code
---  * The response headers
function obj:http_request(method, path, body, headers)
  if headers == nil then headers = obj.headers end
  local url = obj.endpoint .. path
  local status_code, res_body, response_headers = hs.http.doRequest(url, method, body, headers)

  if status_code >= 400 then
    self.log.e(string.format("HTTP Error %d: %s", status_code, res_body))
    return nil, status_code
  end

  return hs.json.decode(res_body), status_code, response_headers
end

--- BeaverHabits.get_client(endpoint, username, password)
--- Function
--- Creates a new BeaverHabits client
---
--- Parameters:
---  * endpoint - The Beaver Habits API endpoint URL
---  * username - The Beaver Habits username
---  * password - The Beaver Habits password
---
--- Returns:
---  * The BeaverHabits object
function obj.get_client(endpoint, username, password)
  obj.endpoint = endpoint
  obj:login(username, password)
  return obj
end

--- BeaverHabits:login(username, password)
--- Method
--- Authenticates with the Beaver Habits API
---
--- Parameters:
---  * username - The Beaver Habits username
---  * password - The Beaver Habits password
function obj:login(username, password)
  local body = "grant_type=password&username=" .. username .. "&password=" .. password
  local login_headers = {
    ["Content-Type"] = "application/x-www-form-urlencoded",
    ["accept"] = "application/json",
  }
  local response_body, _ = obj:http_request("POST", "/auth/login", body, login_headers)
  obj.headers["Authorization"] = "Bearer " .. response_body.access_token
end

--- BeaverHabits:get_habit_list()
--- Method
--- Retrieves the list of habits from the Beaver Habits API
---
--- Returns:
---  * The list of habits
function obj:get_habit_list()
  local response_body = obj:http_request("GET", api_base_path)
  return response_body
end

--- BeaverHabits:get_habit_details(habit_id)
--- Method
--- Retrieves the details of a specific habit
---
--- Parameters:
---  * habit_id - The ID of the habit
---
--- Returns:
---  * The habit details
function obj:get_habit_details(habit_id)
  local response_body, _ = obj:http_request("GET", api_base_path .. "/" .. habit_id)
  return response_body
end

--- BeaverHabits:get_habits_meta()
--- Method
--- Retrieves the meta information for habits
---
--- Returns:
---  * The habits meta information
function obj:get_habits_meta()
  local response_body, _ = obj:http_request("GET", api_base_path .. "/meta")
  return response_body
end

--- BeaverHabits:put_habits_meta(body)
--- Method
--- Updates the meta information for habits
---
--- Parameters:
---  * body - A table containing the new meta information
---
--- Returns:
---  * The updated habits meta information (if successful)
---  * nil (if unsuccessful)
function obj:put_habits_meta(body)
  local request_body = nil
  if type(body) == "table" then
    request_body = hs.json.encode(body)
  else
    print("Error: 'body' argument must be a table")
    return nil
  end

  local response_body, status_code = obj:http_request("PUT", api_base_path .. "/meta", request_body)

  if status_code == 200 then
    return response_body
  else
    return nil
  end
end

--- BeaverHabits:get_habit_records(habit_id)
--- Method
--- Retrieves the completion records for a habit
---
--- Parameters:
---  * habit_id - The ID of the habit
---
--- Returns:
---  * The habit completion records
function obj:get_habit_records(habit_id)
  local days = 5
  local path = api_base_path .. "/" .. habit_id .. "/completions"
  local date_start = os.date("%d-%m-%Y", os.time() - (days - 1) * 24 * 60 * 60)
  local date_end = os.date("%d-%m-%Y")
  local params = {
    date_fmt = obj.date_fmt,
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

  local response_body, status_code = obj:http_request("GET", full_path)

  if status_code == 200 then
    return response_body
  else
    return nil
  end
end

--- BeaverHabits:post_habit_record(habit_id, date, done)
--- Method
--- Creates a new completion record for a habit
---
--- Parameters:
---  * habit_id - The ID of the habit
---  * date     - The date of the completion record
---  * done     - A boolean indicating whether the habit was completed
---
--- Returns:
---  * A boolean indicating whether the record was created successfully
function obj:post_habit_record(habit_id, date, done)
  local body = {
    date_fmt = self.date_fmt,
    date = date,
    done = done,
  }

  local path = api_base_path .. "/" .. habit_id .. "/completions"
  local response_body, _ = obj:http_request("POST", path, hs.json.encode(body))

  return response_body.done
end

return obj
