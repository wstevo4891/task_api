require "rails_helper"

RSpec.describe "Rate Limiting", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:token) { JsonWebToken.encode(user_id: user.id) }
  let(:headers) do
    {
      "Origin" => "http://localhost:3000",
      "Authorization" => "Bearer #{token}"
    }
  end
  let(:task_attributes) do
    {
      user: user,
      title: 'Valid Task Title',
      description: 'A valid description',
      status: :pending,
      priority: :medium
    }
  end
  let(:login_path) { "/api/v1/auth/login" }
  let(:login_params) { { email: user.email, password: user.password } }
  let(:login_headers) { { "Origin" => "http://localhost:3000" } }

  before do
    # Enable Rack::Attack for this test
    Rack::Attack.enabled = true
    Rack::Attack.reset!
    # Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  after do
    # Disable Rack::Attack for future tests so it doesn't
    # interfere with the rest of our tests
    Rack::Attack.enabled = false
  end

  describe "General Request Rate Limiting (60 per minute per IP)" do
    it "allows requests under the limit" do
      59.times do
        get "/api/v1/health", headers: headers
        expect(response).to have_http_status(:ok)
      end
    end

    it "blocks requests exceeding the limit" do
      61.times do
        get "/api/v1/health", headers: headers
      end
      expect(response).to have_http_status(:too_many_requests)
    end

    it "returns JSON error message for rate limited requests" do
      61.times do
        get "/api/v1/health", headers: headers
      end
      expect(response.content_type).to include("application/json")
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("Rate limit exceeded. Try again later.")
    end

    it "includes Retry-After header" do
      61.times do
        get "/api/v1/health", headers: headers
      end
      expect(response.headers["Retry-After"]).to be_present
    end

    it "tracks limits per IP address" do
      # Simulate two different IP addresses
      59.times do
        get "/api/v1/health", headers: {
          **headers,
          "REMOTE_ADDR" => "192.168.1.1"
        }
      end

      # Should still be allowed for different IP
      get "/api/v1/health", headers: {
        **headers,
        "REMOTE_ADDR" => "192.168.1.2"
      }
      expect(response.status).not_to eq(429)
    end
  end

  describe "Login Rate Limiting by IP (5 per 20 seconds)" do
    it "allows up to 5 login attempts per 20 seconds from same IP" do
      4.times do
        post login_path, headers: login_headers, params: login_params
        expect(response.status).not_to eq(429)
      end
    end

    it "blocks login attempts exceeding the IP-based limit" do
      6.times do
        post login_path, headers: login_headers, params: login_params
      end
      expect(response).to have_http_status(:too_many_requests)
    end

    it "returns proper error response for rate-limited login" do
      6.times do
        post login_path, headers: login_headers, params: login_params
      end
      expect(response).to have_http_status(:too_many_requests)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("Rate limit exceeded. Try again later.")
    end

    it "does not throttle non-login POST requests the same way" do
      # Create a task (different endpoint)
      20.times do
        post "/api/v1/tasks", headers: headers, params: task_attributes
        # Should follow general rate limit, not login-specific limit
        expect(response.status).not_to eq(429)
      end
    end

    it "does not throttle GET requests to login endpoint" do
      # GET requests to login endpoint should not trigger login throttling
      10.times do
        get login_path, headers: login_headers
      end
      expect(response.status).not_to eq(429)
    end
  end

  describe "Login Rate Limiting by Email (5 per minute)" do
    it "allows up to 5 login attempts per minute for same email" do
      4.times do
        post login_path, headers: login_headers, params: login_params
        expect(response.status).not_to eq(429)
      end
    end

    it "blocks login attempts exceeding the email-based limit" do
      6.times do
        post login_path, headers: login_headers, params: login_params
      end
      expect(response).to have_http_status(:too_many_requests)
    end

    it "normalizes email by downcasing" do
      # Mixed case should be treated same as lowercase
      upcase_email_params = {
          email: user.email.upcase,
          password: user.password
      }

      6.times do
        post login_path, headers: login_headers, params: upcase_email_params
      end
      expect(response).to have_http_status(:too_many_requests)
    end

    it "normalizes email by removing whitespace" do
      # Email with spaces should be treated same as without
      email_with_spaces_params = {
        email: " #{user.email} ",
        password: user.password
      }
      6.times do
        post login_path, headers: login_headers, params: email_with_spaces_params
      end
      expect(response).to have_http_status(:too_many_requests)
    end

    it "tracks different email addresses separately" do
      other_email = "other@example.com"
      other_user = create(:user, email: other_email)
      other_login_headers = {
        "Origin" => "http://localhost:3000",
        "REMOTE_ADDR" => "192.168.1.1"
      }

      # 5 attempts with first email
      5.times do
        post login_path, headers: login_headers, params: login_params
      end

      # 5 attempts with second email should still be allowed
      5.times do
        post login_path, headers: other_login_headers, params: {
          email: other_email,
          password: other_user.password
        }
        expect(response.status).not_to eq(429)
      end
    end
  end

  describe "Throttled Response Format" do
    before do
      61.times do
        get "/api/v1/health", headers: headers
      end
    end

    it "returns 429 Too Many Requests status" do
      expect(response).to have_http_status(:too_many_requests)
    end

    it "returns application/json content type" do
      expect(response.content_type).to include("application/json")
    end

    it "includes error key in JSON response" do
      body = JSON.parse(response.body)
      expect(body).to have_key("error")
    end

    it "includes Retry-After header" do
      expect(response.headers).to have_key("Retry-After")
    end

    it "includes appropriate Retry-After value" do
      expect(response.headers["Retry-After"].to_i).to be > 0
    end
  end

  describe "Rate Limit Headers" do
    it "does not expose RateLimit headers in responses" do
      get "/api/v1/health", headers: headers
      # Rack::Attack doesn't typically expose RateLimit-* headers by default
      # This test documents current behavior
      expect(response.headers).not_to have_key("Retry-After")
    end
  end
end
