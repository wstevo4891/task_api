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
  end

  after do
    # Disable Rack::Attack for future tests so it doesn't
    # interfere with the rest of our tests
    Rack::Attack.enabled = false
  end

  describe "By IP Address (60 per minute per IP)" do
    context "when number of requests is under the limit" do
      before do
        59.times do
          get "/api/v1/health", headers: headers
        end
      end

      it "allows requests" do
        expect(response).to have_http_status(:ok)
      end

      it "does not expose Retry-After header" do
        expect(response.headers).not_to have_key("Retry-After")
      end
    end

    context "when number of requests is over the limit" do
      before do
        61.times do
          get "/api/v1/health", headers: headers
        end
      end

      it "blocks requests" do
        expect(response).to have_http_status(:too_many_requests)
      end

      it "exposes Retry-After header" do
        expect(response.headers["Retry-After"]).to be_present
      end

      it "includes appropriate Retry-After value" do
        expect(response.headers["Retry-After"].to_i).to be > 0
      end

      it "returns JSON content-type" do
        expect(response.content_type).to include("application/json")
      end

      it "returns expected error message in JSON" do
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("Rate limit exceeded. Try again later.")
      end
    end

    # Simulate two different IP addresses
    it "tracks limits per IP address" do
      61.times do
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

      expect(response).not_to have_http_status(:too_many_requests)
    end
  end

  describe "Logins by IP (5 per 20 seconds)" do
    it "allows up to 5 attempts per 20 seconds from the same IP" do
      5.times do
        post login_path, headers: login_headers, params: login_params
        expect(response).to have_http_status(:ok)
      end
    end

    context "when attempts exceed the IP-based limit" do
      before do
        6.times do
          post login_path, headers: login_headers, params: login_params
        end
      end

      it "blocks the request" do
        expect(response).to have_http_status(:too_many_requests)
      end

      it "returns the proper error response" do
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("Rate limit exceeded. Try again later.")
      end
    end
  end

  describe "Logins by Email (5 per minute)" do
    it "allows up to 5 login attempts per minute for same email" do
      5.times do
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
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
