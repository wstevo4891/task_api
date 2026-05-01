class Rack::Attack
  if Rails.env.test?
    cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  # Throttle all requests by IP (60 requests per minute)
  throttle("requests by ip", limit: 60, period: 1.minute) do |req|
    req.ip
  end

  # Throttle login attempts by IP (5 requests per 20 seconds)
  throttle("logins by ip", limit: 5, period: 20.seconds) do |req|
    if req.path == "/api/v1/auth/login" && req.post?
      req.ip
    end
  end

  # Throttle login attempts by email (5 requests per minute)
  throttle("logins by email", limit: 5, period: 1.minute) do |req|
    if req.path == "/api/v1/auth/login" && req.post?
      req.params["email"].to_s.downcase.gsub(/\s+/, "")
    end
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |request|
    retry_after = (request.env["rack.attack.match_data"] || {})[:period]

    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after.to_s
      },
      [ { error: "Rate limit exceeded. Try again later." }.to_json ]
    ]
  end
end
