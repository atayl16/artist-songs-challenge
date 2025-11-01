# config/initializers/rack_attack.rb
class Rack::Attack
  # Throttle all API requests by IP (60 requests per minute)
  throttle("api requests per ip", limit: 60, period: 1.minute) do |request|
    request.ip if request.path.start_with?("/api/")
  end

    # Stricter throttle for expensive search endpoint (10 requests per minute)
    throttle("song searches per ip", limit: 10, period: 1.minute) do |request|
      request.ip if request.path.match?(/\A\/api\/v1\/artists\/.+\/songs/)
    end

    # Customize throttled response
    self.throttled_responder = lambda do |request|
      [
        429,
        { "Content-Type" => "application/json" },
        [ { error: "Rate limit exceeded. Please try again later." }.to_json ]
      ]
    end
end

# To test is works, make 11 rapid requests - the 11th should be rate limited
# for i in {1..11}; do
#   echo "Request $i:"
#   curl -w "\nStatus: %{http_code}\n" \
#     "http://localhost:3001/api/v1/artists/Drake/songs"
#   echo "---"
# done

# You should see:
# Requests 1-10: Status 200
# Request 11: Status 429 (Rate limit exceeded)
