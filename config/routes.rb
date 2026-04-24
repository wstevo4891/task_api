# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Authentication routes
      post "auth/register", to: "authentication#register"
      post "auth/login", to: "authentication#login"

      # Task routes
      resources :tasks do
        member do
          post :complete
        end
      end

      # Health check endpoint
      get "health", to: "health#show"
    end
  end

  # get "up" => "rails/health#show", as: :rails_health_check
end
