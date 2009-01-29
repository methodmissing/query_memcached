require File.dirname(__FILE__) + '/../test_helper'

# References http://rails.lighthouseapp.com/projects/8994/tickets/1653
module ActiveSupport
  module Cache
    module Strategy
      module LocalCache
        
        def read(key, options = nil)
          value = local_cache && local_cache.read(key)
           if value == NULL
             nil
           elsif value.nil?
             value = super
             local_cache.write(key, value || NULL) if local_cache
             value
           else
             # forcing the value to be immutable
             value.duplicable? ? value.dup : value
           end
         end
         
      end
    end
  end
end

class QueryCacheTest < ActiveSupport::TestCase
  
  fixtures :tasks, :topics, :categories, :posts, :categories_posts
  
  def setup
    ::Rails.cache.clear
  end
  
  def test_find_queries
    ::Rails.cache.with_local_cache do
      assert_queries(2) { Task.find(1); Task.find(1) }
    end
  end

  def test_find_queries_with_query_memcache_enabled
    ::Rails.cache.with_local_cache do    
      Computer.cache do
        assert_queries(1) { Computer.find(1); Computer.find(1) }
      end
    end  
  end

  def test_find_queries_with_cache
    ::Rails.cache.with_local_cache do
      Task.cache do
        assert_queries(1) { Task.find(1); Task.find(1) }
      end
    end  
  end
  
  def test_count_queries_with_cache
    ::Rails.cache.with_local_cache do
      Task.cache do
        assert_queries(1) { Task.count; Task.count }
      end
    end  
  end
  
  def test_query_cache_dups_results_correctly
    ::Rails.cache.with_local_cache do
      Task.cache do
        now  = Time.now.utc
        task = Task.find 1
        assert_not_equal now, task.starting
        task.starting = now
        task.reload
        assert_not_equal now, task.starting
      end
    end  
  end
  
  def test_cache_is_flat
    ::Rails.cache.with_local_cache do
      Task.cache do
        Topic.columns # don't count this query
        assert_queries(1) { Topic.find(1); Topic.find(1); }
      end
  
      ActiveRecord::Base.cache do
        assert_queries(1) { Task.find(1); Task.find(1) }
      end
    end  
  end
  
  def test_cache_does_not_wrap_string_results_in_arrays
    ::Rails.cache.with_local_cache do
      Task.cache do
        assert_instance_of String, Task.connection.select_value("SELECT count(*) AS count_all FROM tasks")
      end
    end  
  end
end

uses_mocha 'QueryCacheExpiryTest' do

class QueryCacheExpiryTest < ActiveSupport::TestCase
  fixtures :tasks
  
  def setup
    ::Rails.cache.clear
  end
  
  def test_find
    ::Rails.cache.with_local_cache do
      Task.connection.expects(:clear_query_cache).times(1)

      assert !Task.connection.query_cache_enabled
      Task.cache do
        assert Task.connection.query_cache_enabled
        Task.find(1)

        Task.uncached do
          assert !Task.connection.query_cache_enabled
          Task.find(1)
        end

        assert Task.connection.query_cache_enabled
      end
      assert !Task.connection.query_cache_enabled
    end
  end

  def test_find_without_query_memcached_activated
    ::MemCache.any_instance.expects(:set).times(0)
    ::MemCache.any_instance.expects(:get).times(0)
    ::Rails.cache.with_local_cache do
      Task.cache do
        Task.find(1)
        Task.find(1)
      end
    end
  end
  
  def test_find_with_query_memcached_activated
    # 3 writes:
    # - version
    # - version/computers
    # - version/computers/1
    ::MemCache.any_instance.expects(:set).times(3)
    # The same reads
    ::MemCache.any_instance.expects(:get).times(3)
    ::Rails.cache.with_local_cache do
      Computer.cache do
        Computer.find(1)
        Computer.find(1)
      end
    end
  end

  def test_update
    ::Rails.cache.with_local_cache do    
      Task.connection.expects(:clear_query_cache).times(2)

      Task.cache do
        task = Task.find(1)
        task.starting = Time.now.utc
        task.save!
      end
    end
  end
  
  def test_update_model_with_query_memcached_should_update_key
    ::Rails.cache.with_local_cache do
      version = ::Rails.cache.read('version/computers') || 0
      Computer.cache do
        computer = Computer.find(1)
        computer.developer = Developer.find(2)
        computer.save!
      end
      assert_equal version + 1, ::Rails.cache.read('version/computers')
    end
  end
  

  def test_destroy
    ::Rails.cache.with_local_cache do
      Task.connection.expects(:clear_query_cache).times(2)

      Task.cache do
        Task.find(1).destroy
      end
    end
  end

  def test_destroy_model_with_query_memcached_should_update_key
    ::Rails.cache.with_local_cache do
      version = ::Rails.cache.read('version/computers') || 0
      Computer.cache do
        Computer.find(1).destroy
      end
      assert_equal version + 1, ::Rails.cache.read('version/computers')
    end
  end

  def test_insert
    ActiveRecord::Base.connection.expects(:clear_query_cache).times(2)
    ::Rails.cache.with_local_cache do
      Task.cache do
        Task.create!
      end
    end
  end
  
  def test_insert_model_with_query_memcached_should_update_key
    ::Rails.cache.with_local_cache do
      version = ::Rails.cache.read('version/computers') || 0
      Computer.cache do
        Computer.create!(:developer => Developer.find(1), :extendedWarranty => 1)
      end
      assert_equal version + 1, ::Rails.cache.read('version/computers')
    end
  end

  def test_cache_is_expired_by_habtm_update    
    ActiveRecord::Base.connection.expects(:clear_query_cache).times(2)
    ::Rails.cache.with_local_cache do
      ActiveRecord::Base.cache do
        c = Category.find(:first)
        p = Post.find(:first)
        p.categories << c
      end
    end
  end

  def test_cache_is_expired_by_habtm_delete
    ActiveRecord::Base.connection.expects(:clear_query_cache).times(2)
    ::Rails.cache.with_local_cache do
      ActiveRecord::Base.cache do
        c = Category.find(1)
        p = Post.find(1)
        assert p.categories.any?
        p.categories.delete_all
      end
    end
  end
end

end
