RAILS_GEM_VERSION = '2.3.0' unless defined? RAILS_GEM_VERSION

require File.join(File.dirname(__FILE__), 'boot')

require 'active_support'
#require RAILS_ROOT + '/lib/test_store'
include ActiveSupport::Cache

Rails::Initializer.run do |config|
  config.log_level = :debug
  config.cache_classes = false
  config.whiny_nils = true
  config.action_controller.perform_caching = true
  config.cache_store = :mem_cache_store, { :servers => 'localhost:11211',
                                           :namespace => 'testing_app',
                                           :compression => true
                                         }
  config.action_controller.session = { :session_key => "_query_memcached_session", :secret => "jas8du983i23783y42ojlkjewqoeh3h8397323jjewlqej893" }                                         
end

require File.expand_path(File.dirname(__FILE__)) + "/../../../lib/query_memcached"