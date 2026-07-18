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
    # OmniAuth redirects here when a provider errors (declined consent, bad
    # credentials). Without this route the person lands on a bare 404 instead
    # of the sign-in page with an explanation (Apple hit exactly that).
    get    '/users/auth/failure', to: 'users/omniauth_callbacks#failure'
  end

  # Unified authentication page
  get "auth", to: "auth#unified"
  
  # Magic Links
  post "magic_links", to: "magic_links#create"
  get "magic_links/:token", to: "magic_links#show", as: "magic_link"

  # Admin invitations: the claim link from the invite email.
  get "invitations/:token", to: "invitations#show", as: :invitation

  # Single root for all users
  root to: 'home#index'

  # Public membership page (plans + the start-your-own-club pitch)
  get "membership", to: "home#membership"

  # Contact addresses (hello@ / support@ / partners@)
  get "contact", to: "home#contact"

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
  post "account/shelf_items", to: "account/shelf_items#create", as: :account_shelf_items
  delete "account/shelf_items/:id", to: "account/shelf_items#destroy", as: :account_shelf_item

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

  # Invite links: joining via a valid token works for private societies too.
  get "invite/:token", to: "societies#join_by_invite", as: :society_invite

  # Societies
  resources :societies do
    member do
      post :join
      post :regenerate_invite
      delete :leave
    end
    
    # Events are now nested under societies
    resources :events do
      resources :event_rsvps, only: [:create, :update, :destroy]
    end
  end

  # Society member management (remove / change role) by society managers.
  resources :society_memberships, only: [:update, :destroy]
  
  # Keep top-level event routes for existing functionality
  # but they should redirect to the society page
  resources :events, only: [:show] do
    resources :event_rsvps, only: [:create, :update, :destroy]
    # The pour list (organizer/society admins manage it; everyone reads it).
    resources :event_bottles, only: [:create, :destroy], module: :events
    # Event-tagged reviews; the bottle rides along as ?bottle_id=<slug>.
    resources :reviews, only: [:new, :create], module: :events
    # Table talk: society members' comments, open until a week after the night.
    resources :comments, only: [:create, :destroy], module: :events
  end

  # Admin panel
  namespace :admin do
    get 'dashboard', to: 'dashboard#index'
    resources :presentations do
      collection { post :import }
      member { post :publish; post :unpublish; post :render_slides }
    end
    resources :users, only: [:index, :show, :edit, :update] do
      # Admin-role changes are a dedicated, guarded action, never part of the
      # general user update (same rule as credits: no mass-assignment path).
      member { patch :update_role; post :resend_invitation }
    end
    # Invite a new member: creates the account and emails the claim link.
    resources :invitations, only: [:new, :create]
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

    # Bottles moderation
    resources :bottles, only: [:index, :show, :edit, :update] do
      member do
        patch :pin_image
        delete :unpin_image
      end
      resources :reviews, only: [:destroy], module: :bottles do
        member { delete :destroy_image }
      end
      resources :edits, only: [:destroy], module: :bottles do
        member { post :apply }
      end
    end

    # Moderation queue: open review reports + pending bottle-edit proposals.
    get 'moderation', to: 'moderation#index'
    resources :review_reports, only: [] do
      member { post :dismiss }
    end

    # Analytics routes
    get 'analytics/downloads', to: 'analytics#downloads', as: 'downloads_analytics'
    get 'analytics/presentations/:id/downloads', to: 'analytics#presentation_downloads', as: 'presentation_downloads_analytics'
    get 'analytics/reviews', to: 'analytics#reviews', as: 'reviews_analytics'

    root to: 'dashboard#index'
  end

  # Presentations. All purchasing goes through the nested purchases controller —
  # a single flow for credit, paid (Stripe checkout), and free decks.
  resources :presentations do
    member { get :present }
    resources :purchases, only: [ :new, :create ], controller: 'presentations/purchases'
    resources :downloads, only: [], controller: 'presentations/downloads' do
      collection do
        get :sneak_peek
        get :full_presentation
        get :speaker_notes
        get :outline
        get :recommendations
        # Tasting scorecards (owner-gated): the deck's custom one if uploaded,
        # and the standard blank card, always included as a fallback.
        get :scorecard
        get :blank_scorecard
      end
    end
  end

  # Profiles
  resources :profiles, only: [:show]

  # Favorites
  resources :favorites, only: [:create, :destroy]

  # Review votes (thumbs-up only)
  resources :review_votes, only: [:create, :destroy]

  # Bottles
  resources :bottles, only: [:show, :new, :create], param: :id do
    collection { get :search }
    resources :reviews, only: [:new, :create], module: :bottles
    resources :edits, only: [:new, :create], module: :bottles
    # A society's verdict on this bottle: every individual card behind the
    # aggregate. Public societies only (the action re-checks).
    get "verdicts/:society_id", to: "bottles#verdict", as: :verdict, on: :member
  end
  # The review section: /reviews is the public library page (search +
  # latest tastings); individual bottles live at /bottles/:slug.
  resources :reviews, only: [:index, :show, :edit, :update, :destroy] do
    collection { get :search; get :start }
    # Flag a review (text or photos) for admin attention. Post-moderation:
    # content stays public until an admin acts on the report.
    resource :report, only: [:create], module: :reviews
  end

  # One-click RSVP from event emails (signed token carries user + event).
  get "email_rsvps/:status", to: "email_rsvps#create", as: :email_rsvp

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
