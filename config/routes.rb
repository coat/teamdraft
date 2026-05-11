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

  get "about" => "pages#about"
  get "privacy" => "pages#privacy"

  root "leagues#index"
  resources :leagues, only: [:index, :new, :create, :show, :edit, :update], param: :id do
    resources :draft_picks, only: [:create]
    member do
      post :claim
    end
  end

  namespace :admin do
    root "dashboard#show"
    resources :seasons, only: [:index, :new, :create, :edit, :update] do
      member { post :activate }
    end
    resources :teams, only: [:index, :edit, :update]
    resources :games, only: [:index, :edit, :update]
    resources :syncs, only: [:create]
    mount MissionControl::Jobs::Engine, at: "/jobs", as: :jobs
  end
end
