Rails.application.routes.draw do
  # Authentication is handled exclusively through Devise + OmniAuth (Google, Apple)
  # and the magic-link flow below. The Apple/Google OAuth callbacks are verified by
  # the OmniAuth strategies (signature-checked); we no longer hand-roll any callback.
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks',
    registrations: 'users/registrations'
  }, skip: [:sessions]

  devise_scope :user do
    # Devise's :sessions module is skipped in favour of the unified auth page,
    # but we keep the conventional Devise helper names so links/tests using
    # new_user_session_path / user_session_path still resolve.
    get    '/users/sign_in', to: 'auth#unified', as: 'new_user_session'
    # Custom password sign-in (adds 2FA + remember-me handling on top of Devise)
    post   '/users/sign_in', to: 'auth#sign_in', as: 'user_session'
    delete '/users/sign_out', to: 'auth#logout', as: 'destroy_user_session'
  end

  # Unified authentication page
  get "auth", to: "auth#unified"
  
  # Magic Links
  post "magic_links", to: "magic_links#create"
  get "magic_links/:token", to: "magic_links#show", as: "magic_link"

  # Single root for all users
  root to: 'home#index'

  # The signed-in landing page. /dashboard and /account render the same account
  # surface; /dashboard is the canonical post-authentication destination.
  get "dashboard", to: "account#index", as: :dashboard

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
  post "subscriptions/portal", to: "subscriptions#portal"
  post "subscriptions/cancel", to: "subscriptions#cancel"
  post "subscriptions/pause", to: "subscriptions#pause"
  post "subscriptions/resume", to: "subscriptions#resume"
  post "subscriptions/change_plan", to: "subscriptions#change_plan"
  get "subscriptions/plans", to: "subscriptions#plans"

  # Stripe webhooks
  post "webhooks/stripe", to: "webhooks#stripe"

  # Societies
  resources :societies do
    member do
      post :join
      delete :leave
    end
    
    # Events are now nested under societies
    resources :events do
      resources :event_rsvps, only: [:create, :update, :destroy]
    end
  end
  
  # Keep top-level event routes for existing functionality
  # but they should redirect to the society page
  resources :events, only: [:show] do
    resources :event_rsvps, only: [:create, :update, :destroy]
  end

  # Admin panel
  namespace :admin do
    get 'dashboard', to: 'dashboard#index'
    resources :presentations
    resources :users, only: [:index, :show, :edit, :update]
    resources :subscriptions, only: [:index, :edit, :update] do
      member do
        post :cancel
        post :pause
        post :resume
      end
    end
    post 'create_subscription', to: 'subscriptions#create_subscription'
    resources :credits, only: [:index] do
      collection do
        post :bulk_add
        post :grant_monthly
        get :transactions
      end
      member do
        get :adjust
        post :adjust
      end
    end
    resources :activities, only: [:index, :show]
    
    # Analytics routes
    get 'analytics/downloads', to: 'analytics#downloads', as: 'downloads_analytics'
    get 'analytics/presentations/:id/downloads', to: 'analytics#presentation_downloads', as: 'presentation_downloads_analytics'
    
    root to: 'dashboard#index'
  end

  # Presentations
  resources :presentations do
    resources :purchases, only: [ :new, :create ], controller: 'presentations/purchases'
    resources :downloads, only: [], controller: 'presentations/downloads' do
      collection do
        get :sneak_peek
        get :full_presentation
        get :speaker_notes
        get :outline
        get :recommendations
      end
    end
    member do
      get :purchase_options
      post :purchase
    end
  end

  # Profiles
  resources :profiles, only: [:show]

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
