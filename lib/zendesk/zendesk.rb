require 'faraday'
require 'faraday_middleware'

require 'zendesk/configuration'
require 'zendesk/collection'
require 'zendesk/retry_middleware'

module Zendesk
  class Client
    class << self
      def collection(resource, opts = {})
        resource = resource.to_s
        method = opts.delete(:method) || resource

        define_method method do |*args|
          return instance_variable_get("@#{method}") if !opts.delete(:reload) && instance_variable_defined?("@#{method}")
          options = args.last.is_a?(Hash) ? args.pop : {}
          instance_variable_set("@#{method}", Zendesk::Collection.new(self, resource, [resource], opts.merge(options)))
        end
      end
    end

    attr_reader :config
    collection :tickets
    collection :tickets, :path => 'tickets/recent', :method => :recent_tickets
    collection :ticket_fields
    collection :users
    collection :users, :path => 'users/search', :method => :search_users
    collection :macros, :path => 'macros/active'
    collection :views
    collection :views, :path => 'views/active', :method => :active_views
    collection :custom_roles
    collection :bookmarks
    collection :activities
    collection :groups
    collection :groups, :path => 'groups/assignable', :method => :assignable_groups
    collection :group_memberships
    collection :locales
    collection :settings, :path => 'account/settings'
    collection :mobile_devices
    collection :satisfaction_ratings
    collection :satisfaction_ratings, :path => 'satisfaction_ratings/received', :method => :received_satisfaction_ratings
    collection :organizations
    collection :categories
    collection :forums
    collection :topics
    collection :topics, :path => 'topics/show_many', :method => :show_many, :verb => :post 
    collection :topic_comments
    collection :topic_subscriptions
    collection :forum_subscriptions

    # Play the playlist
    # id can be a view id or 'incoming'
    def play(id)
      Zendesk::Playlist.new(self, id)
    end

    def initialize
      @config = Zendesk::Configuration.new
      @connection = false
    end

    def connection
      return @connection if @connection

      @connection = Faraday.new(config.options) do |builder|
        builder.response :logger if config.log

        builder.request :json
        builder.response :json

        # Should always be first in the stack
        if config.retry
          builder.use Zendesk::Request::RetryMiddleware
        end

        builder.use Faraday::Response::RaiseError
        builder.adapter Faraday.default_adapter
      end
      @connection.tap {|c| c.basic_auth(config.username, config.password)}
    end
  end
end