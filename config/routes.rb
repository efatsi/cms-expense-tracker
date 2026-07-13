Rails.application.routes.draw do
  devise_for :users, controllers: { invitations: "users/invitations" }

  root "receipts#index"

  resources :receipts do
    collection { post :analyze }
    resources :expenses, only: [ :new, :create, :edit, :update, :destroy ]
  end

  resources :reports, only: [ :index ]

  namespace :admin do
    resources :users
    resources :expense_categories
    resources :payment_methods
    resources :charges do
      collection { post :import }
      member { patch :match }
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
