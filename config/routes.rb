Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Authentication routes
  get '/login', to: 'sessions#new', as: :login
  post '/login', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy', as: :logout

  # Registration routes
  get '/register', to: 'registrations#new', as: :register
  post '/register', to: 'registrations#create'

  # Pricing route
  get '/pricing', to: 'pages#pricing', as: :pricing

  # Defines the root path route ("/")
  root "home#index"

  resources :matches
end
