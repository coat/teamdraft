Rails.application.routes.draw do
  resource :session
  resource :registration, only: [:new, :create]
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :seasons, only: [:index, :show] do
    resources :teams, only: [:show], param: :slug
  end
  get "rankings" => "rankings#sports_index", as: :rankings
  get "rankings/:sport_slug" => "rankings#index", as: :sport_rankings
  post "rankings/:sport_slug" => "rankings#create", as: :sport_rankings_create
  delete "rankings/:sport_slug/:id" => "rankings#destroy", as: :sport_ranking
  patch "rankings/:sport_slug/:id/move_up" => "rankings#move_up", as: :move_up_sport_ranking
  patch "rankings/:sport_slug/:id/move_down" => "rankings#move_down", as: :move_down_sport_ranking
  get "about" => "pages#about"
  get "privacy" => "pages#privacy"

  root "leagues#index"
  resources :leagues, only: [:index, :new, :create, :show, :edit, :update], param: :id do
    resource :draft, only: [:show, :edit, :update] do
      resources :picks, only: [:create], controller: "draft_picks"
    end
    resource :scoring_rules, only: [:edit, :update], controller: "league_scoring_rules" do
      post :reset
    end
    resources :participants, only: [] do
      member do
        patch :move_up
        patch :move_down
      end
    end
    member do
      post :claim
      post :verify_invite
      get :history
    end
    resources :seasons, only: [:show], param: :year, controller: "league_seasons"
  end

  namespace :admin do
    root "dashboard#show"
    resources :seasons, only: [:index, :show, :new, :create, :edit, :update] do
      member { post :activate }
    end
    resources :teams, only: [:index, :edit, :update] do
      member do
        patch :move_up
        patch :move_down
      end
    end
    resources :games, only: [:index, :edit, :update]
    resources :leagues, only: [:index, :show, :edit, :update, :destroy]
    resources :users, only: [:index, :show, :edit, :update] do
      member do
        patch :grant_admin
        patch :revoke_admin
        patch :disable
        patch :enable
      end
    end
    resources :syncs, only: [:create]
    mount MissionControl::Jobs::Engine, at: "/jobs", as: :jobs
  end
end
