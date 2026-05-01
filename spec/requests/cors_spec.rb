require "rails_helper"

RSpec.describe "CORS", type: :request do
  let(:api_path) { "/api/v1/tasks" }
  let(:deploy_preview_origin) { "https://deploy-preview-1234--tasky.app" }
  let(:disallowed_origin) { "https://evil.com" }
  let(:user) { create(:user) }
  let(:token) { JsonWebToken.encode(user_id: user.id) }
  let(:task_1) { create(:task, user: user) }
  let(:task_attributes) do
    {
      user: user,
      title: 'Valid Task Title',
      description: 'A valid description',
      status: :pending,
      priority: :medium
    }
  end
  let(:allow_orgin_header) { response.headers["Access-Control-Allow-Origin"] }
  let(:expose_header) { response.headers["Access-Control-Expose-Headers"] }

  allowed_origins = [
    "http://localhost:3000",
    "http://localhost:4000",
    "https://tasky.com"
  ]

  describe "Allowed Origins" do
    allowed_origins.each do |origin|
      context "with origin: #{origin}" do
        let(:headers) do
          {
            "Origin" => origin,
            "Authorization" => "Bearer #{token}"
          }
        end

        describe "GET request" do
          before { get api_path, headers: headers }

          it "returns successful response" do
            expect(response).to have_http_status(:ok)
          end

          it "returns Access-Control-Allow-Origin header" do
            expect(allow_orgin_header).to eq(origin)
          end

          it "exposes Tasky-Response-Header" do
            expect(expose_header).to include("Tasky-Response-Header")
          end
        end

        describe "OPTIONS request" do
          before do
            options api_path, headers: {
              **headers,
              "Access-Control-Request-Method" => "GET"
            }
          end

          it "returns successful response" do
            expect(response).to have_http_status(:ok)
          end

          it "sets max age to 600 seconds" do
            expect(response.headers["Access-Control-Max-Age"]).to eq("600")
          end
        end
      end
    end
  end

  describe "Deploy Preview Origins" do
    it "allows deploy-preview origins matching the pattern" do
      get api_path, headers: {
        "Origin" => deploy_preview_origin,
        "Authorization" => "Bearer #{token}"
      }
      expect(allow_orgin_header).to eq(deploy_preview_origin)
    end

    it "allows multiple different deploy preview numbers" do
      [ 1, 23, 377, 4584, 9999 ].each do |number|
        origin = "https://deploy-preview-#{number}--tasky.app"
        get api_path, headers: {
          "Authorization" => "Bearer #{token}",
          "Origin" => origin
        }
        expect(response.headers["Access-Control-Allow-Origin"]).to eq(origin)
      end
    end

    it "rejects deploy-preview origins with invalid format" do
      invalid_origins = [
        "https://deploy-preview-12345--tasky.app", # 5 digits, pattern allows 1-4
        "https://deploy-preview---tasky.app",      # missing number
        "https://deploy-preview-abc--tasky.app"    # non-numeric
      ]

      invalid_origins.each do |origin|
        get api_path, headers: {
          "Authorization" => "Bearer #{token}",
          "Origin" => origin
        }
        expect(allow_orgin_header).to be_nil
      end
    end
  end

  describe "Disallowed Origins" do
    before do
      get api_path, headers: {
        "Authorization" => "Bearer #{token}",
        "Origin" => disallowed_origin
      }
    end

    it "returns successful response" do
      expect(response).to have_http_status(:ok)
    end

    it "does not return Access-Control-Allow-Origin header for unauthorized origins" do
      expect(allow_orgin_header).to be_nil
    end

    it "does not expose headers for unauthorized origins" do
      expect(expose_header).to be_nil
    end
  end

  describe "Allowed Methods" do
    origin = allowed_origins.first

    let(:headers) do
      {
        "Origin" => origin,
        "Authorization" => "Bearer #{token}"
      }
    end

    before(:all) { DatabaseCleaner.clean }

    describe "GET" do
      before { get api_path, headers: headers }

      it "is allowed" do
        expect(response).to have_http_status(:ok)
      end

      it "applies CORS origin policy" do
        expect(allow_orgin_header).to eq(origin)
      end
    end

    describe "POST" do
      before { post api_path, headers: headers, params: task_attributes }

      it "is allowed" do
        expect(response).to have_http_status(:created)
      end

      it "applies CORS origin policy" do
        expect(allow_orgin_header).to eq(origin)
      end
    end

    describe "PUT" do
      let(:params) do
        {
          user: user,
          title: "Valid Task Title 2",
          description: "A valid description 2",
          status: :in_progress,
          priority: :medium
        }
      end

      before do
        put "#{api_path}/#{task_1.id}", headers: headers, params: params
      end

      it "is allowed" do
        expect(response).to have_http_status(:ok)
      end

      it "applies CORS origin policy" do
        expect(allow_orgin_header).to eq(origin)
      end
    end

    describe "PATCH" do
      before do
        patch "#{api_path}/#{task_1.id}", headers: headers, params: { priority: :high }
      end

      it "is allowed" do
        expect(response).to have_http_status(:ok)
      end

      it "applies CORS origin policy" do
        expect(allow_orgin_header).to eq(origin)
      end
    end

    describe "DELETE" do
      before do
        delete "#{api_path}/#{task_1.id}", headers: headers
      end

      it "is allowed" do
        expect(response).to have_http_status(:no_content)
      end

      it "applies CORS origin policy" do
        expect(allow_orgin_header).to eq(origin)
      end
    end
  end

  describe "Preflight Requests" do
    context "with allowed origin" do
      let(:headers) do
        {
          "Origin" => allowed_origins.first,
          "Authorization" => "Bearer #{token}",
          "Access-Control-Request-Method" => "GET"
        }
      end

      before { options api_path, headers: headers }

      it "returns successful response" do
        expect(response).to have_http_status(:ok)
      end

      it "returns Access-Control-Allow-Methods" do
        expect(response.headers["Access-Control-Allow-Methods"]).to include("GET")
      end
    end

    context "with disallowed origin" do
      let(:headers) do
        {
          "Origin" => disallowed_origin,
          "Authorization" => "Bearer #{token}",
          "Access-Control-Request-Method" => "GET"
        }
      end

      before { options api_path, headers: headers }

      it "returns successful response" do
        expect(response).to have_http_status(:ok)
      end

      it "does not return CORS headers" do
        expect(allow_orgin_header).to be_nil
      end
    end
  end

  describe "Headers Configuration" do
    it "allows x-domain-token header" do
      get api_path, headers: {
        "Origin" => allowed_origins.first,
        "Authorization" => "Bearer #{token}",
        "X-Domain-Token" => "test-token"
      }
      expect(response.status).not_to eq(403)
    end
  end

  describe "/api/v1/health endpoint" do
    before do
      get "/api/v1/health", headers: {
        "Origin" => allowed_origins.first,
        "Authorization" => "Bearer #{token}"
      }
    end

    it "returns successful response" do
      expect(response).to have_http_status(:ok)
    end

    it "applies CORS origin policy" do
      expect(allow_orgin_header).to eq(allowed_origins.first)
    end
  end
end
