Rails.application.routes.draw do
  resources :password_resets, :only => [:edit, :update]

  scope :api, defaults: {format: 'json'} do
    get 'reset_password', to: "password_resets#create"

    resources :people, :only => [:index, :show] do
      member do
        get 'follow'
        get 'unfollow'
        post 'annotate'
      end
      collection do
        get 'following'
        get 'recent'
        get 'recommended'
        post 'add_device'
      end
    end
    resources :messages, :only => [:index, :show] do
      collection do
        get 'with/:person', to: "messages#with"
        get 'total_unread', to: "messages#total_unread"
        post 'send/:person', to: "messages#create"
      end
      member do
        get 'read', to: "messages#set_read"
      end
    end
    put 'people', to: 'people#update'
    match 'people', to: 'people#index', via: [:options]
    match '/login', to: "auth#login", via: [:post]
    get 'offline/people', to: "offline#people"
    put 'offline/update_visits', to: "offline#update_visits"
  end
end
