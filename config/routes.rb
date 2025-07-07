Rails.application.routes.draw do
  devise_for :users

  # Authenticated root
  authenticated :user do
    root to: 'dashboard#index', as: :authenticated_root
  end

  # Public root
  unauthenticated do
    root to: 'home#index', as: :unauthenticated_root
  end

  # Dashboard
  get "dashboard", to: "dashboard#index"

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
