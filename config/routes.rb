Rails.application.routes.draw do
  # Direct Apple Sign In (bypasses OmniAuth)
  get '/apple/auth', to: 'apple_direct#auth'
  post '/apple/callback', to: 'apple_direct#callback'
  get '/apple/callback', to: 'apple_direct#callback'
  
  # Catch-all callback for testing
  match '/callback', to: 'test_callback#callback', via: [:get, :post]
  match '/auth/callback', to: 'test_callback#callback', via: [:get, :post]
  match '/users/callback', to: 'test_callback#callback', via: [:get, :post]
  
  # Apple OAuth direct route (before Devise)
  post '/users/auth/apple/callback', to: 'apple_auth#callback'
  get '/users/auth/apple/callback', to: 'apple_auth#callback'
  
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks',
    registrations: 'users/registrations'
  }, skip: [:sessions]
  
  # OAuth failure route inside devise scope
  devise_scope :user do
    get '/users/auth/failure', to: 'apple_auth#callback'
    post '/users/auth/failure', to: 'apple_auth#callback'
    # Apple OAuth needs both GET and POST
    post '/users/auth/apple/callback', to: 'apple_auth#callback'
    get '/users/auth/apple/callback', to: 'apple_auth#callback'
    # Custom session routes
    post '/users/sign_in', to: 'auth#sign_in', as: 'user_session'
    delete '/users/sign_out', to: 'auth#logout', as: 'destroy_user_session'
  end

  # Unified authentication page
  get "auth", to: "auth#unified"
  
  # Magic Links
  post "magic_links", to: "magic_links#create"
  get "magic_links/:token", to: "magic_links#show", as: "magic_link"

  # Single root for all users
  root to: 'home#index'

  # Account
  get "account", to: "account#index"
  patch "account/profile", to: "account#update_profile"
  patch "account/tags", to: "account#update_tags"
  patch "account/avatar", to: "account#upload_avatar"
  delete "account/remove_avatar", to: "account#remove_avatar"
  patch "account/change_email", to: "account#request_email_change"
  get "account/verify_email/:token", to: "account#verify_email_change", as: "verify_email_change"
  patch "account/change_password", to: "account#change_password"
  post "account/setup_2fa", to: "account#setup_2fa"
  post "account/enable_2fa", to: "account#enable_2fa"
  post "account/disable_2fa", to: "account#disable_2fa"
  post "account/regenerate_backup_codes", to: "account#regenerate_backup_codes"

  # Subscriptions
  post "subscriptions/checkout", to: "subscriptions#create_checkout_session"
  get "subscriptions/portal", to: "subscriptions#portal"

  # Stripe webhooks
  post "webhooks/stripe", to: "webhooks#stripe"

  # Societies
  resources :societies do
    member do
      post :join
      delete :leave
    end
  end

  # Events
  resources :events do
    resources :event_rsvps, only: [:create, :update, :destroy]
  end

  # Presentations
  resources :presentations

  # Health check
  get "health" => "application#health"
  get "up" => "rails/health#show", as: :rails_health_check

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
