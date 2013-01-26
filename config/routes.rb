# Copyright 2012 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

Squash::Application.routes.draw do
  resources :projects, except: [:new] do
    member do
      get :context
      put :rekey
    end
    resources :environments, only: [:update] do
      resources :bugs, except: [:new, :create, :edit] do
        collection { get :count }
        member { post :watch, :notify_deploy, :notify_occurrence }
        resources :occurrences, only: [:index, :show] do
          collection { get :count, :aggregate, :histogram }
        end
        resources :events, only: :index
        resources :comments, except: [:show, :new, :edit]
        resource :notification_threshold, only: [:create, :update, :destroy]
      end
    end
    resources :memberships, controller: 'project/memberships', only: [:index, :create, :update, :destroy]
    resource :membership, controller: 'project/membership', as: :my_membership, only: [:edit, :update, :destroy] do
      member { post :join }
      resources :emails, controller: 'emails', only: [:index, :create]
    end
  end

  resources :users, only: [:index, :show]
  actions = [:show]
  actions << :update if Squash::Configuration.authentication.strategy == 'password'
  resource :account, only: actions do
    resources :memberships, controller: 'account/memberships', only: [:index]
    resources :bugs, controller: 'account/bugs', only: :index
    resources :events, controller: 'account/events', only: :index
    resources :emails, controller: 'emails', only: [:index, :create, :destroy], constraints: {id: /[^\/]+?/, format: 'json'}
  end

  namespace :jira do
    resources :projects, only: :index
    resources :issues, only: :show
    resources :statuses, only: :index
  end unless Squash::Configuration.jira.disabled?

  get 'login' => 'sessions#new'
  post 'login' => 'sessions#create'
  get 'logout' => 'sessions#destroy'
  post 'signup' => 'users#create' if Squash::Configuration.authentication.strategy == 'password'

  post 'api/1.0/notify' => 'api/v1#notify'
  post 'api/1.0/deploy' => 'api/v1#deploy'
  post 'api/1.0/symbolication' => 'api/v1#symbolication'
  post 'api/1.0/deobfuscation' => 'api/v1#deobfuscation'
  post 'api/1.0/sourcemap' => 'api/v1#sourcemap'

  get 'search/suggestions' => 'search#suggestions'
  get 'search' => 'search#search'

  match 'api/1.0/notify', :constraints => {:method => 'OPTIONS'},
    :to => lambda { |env| [200, {
      'Access-Control-Allow-Origin' => '*',
      'Access-Control-Request-Method' => '*',
      'Access-Control-Allow-Headers' => 'Content-Type'
    }, []] }

  root to: 'projects#index'
end
