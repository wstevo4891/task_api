# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  ##
  # Example
  # ========
  # allow do
  #   origins ENV.fetch("CORS_ORIGINS", "*").split(",")

  #   resource "*",
  #     headers: :any,
  #     methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
  #     expose: [ "Authorization" ],
  #     max_age: 600
  # end

  allow do
    origins "http://localhost:3000",
            "http://localhost:4000",
            "https://tasky.com",
            /\Ahttps:\/\/deploy-preview-\d{1,4}--tasky\.app\z/

    resource "/api/v1/*",
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      headers: "x-domain-token",
      expose: [ "Authorization", "Tasky-Response-Header" ],
      max_age: 600,
      credentials: true
  end
end
