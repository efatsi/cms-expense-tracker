Rails.application.routes.draw do
  devise_for :users, controllers: { invitations: "users/invitations" }

  root "receipts#index"

  resources :receipts do
    collection do
      post :analyze
      get  :bulk_upload
      post :bulk_upload
    end
    member { post :approve }
    resources :expenses, only: [ :new, :create, :edit, :update, :destroy ]
  end

  resources :reports, only: [ :index ]

  namespace :admin do
    resources :users
    resources :expense_categories
    resources :payment_methods
    resources :charges, only: [ :index, :show ] do
      collection do
        get :import
        post :import
        get :export
      end
      member do
        post :associate
        patch :lock_in
        patch :reset_match
        post :save_expenses
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
