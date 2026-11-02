Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :books, param: :serial_number, only: %i[index show create destroy] do
        patch :status, on: :member, to: "book_statuses#update"
      end
    end
  end

  if Rails.env.local?
    mount Rswag::Ui::Engine, at: "/api-docs"
    mount Rswag::Api::Engine, at: "/api-docs"
  end

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  # Defines the root path route ("/")
  # root "posts#index"

  # Stays last, so a path no route above matches gets the API's error format.
  match "*unmatched", to: "errors#route_not_found", via: :all, format: false
end
