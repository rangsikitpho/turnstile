PROJECT = 'TEST PROJECT'

require 'turnstile/db'
require 'turnstile/turnstile_exception'
require 'active_support/configurable'
require 'aws-sdk'
#require 'statsd-ruby'
module Turnstile
  include ActiveSupport::Configurable

  def self.included(base)
    base.send :extend, ClassMethods
  end

  module ClassMethods
    # TODO: Add block support
    def add_turnstile(original_method_name,new_method_name,options={})
      (definer, type) =
        if original_method_name =~ /self\.*/
          original_method_name.sub!('self.','')
          new_method_name.sub!('self.','')
          [:define_singleton_method, 'class']
        else
          [:define_method, 'instance']
        end

      send definer, new_method_name do |*args|
        db = Turnstile::Db.new(self.class.name,original_method_name,type)

        Turnstile.run_all_tests(db,options)

        begin
          process_timestamp = db.add_active_process

          #puts "running statsd time for #{db.key}"
          #$statsd.time(db.key) do
          send original_method_name, *args
          #end

          Turnstile.max_execution_time_test(db,options[:max_execution_time]) # Run test again at end to make sure process finishing in time
        ensure
          db.delete_active_process(process_timestamp) if process_timestamp
        end
      end
    end
  end

  class << self
    def run_all_tests(db,options)
      max_processes_test(db,options[:max_processes])
      max_execution_time_test(db,options[:max_execution_time])
    end

    def max_processes_test(db,max_processes)
      if max_processes
        active_process_count = db.active_process_count
        if active_process_count >= max_processes
          raise TurnstileException, "Failed max_process check: #{active_process_count} active out of max of #{max_processes}"
        end
      end
    end

    def max_execution_time_test(db,max_execution_time)
      if max_execution_time
        oldest_process_execution_time = db.oldest_process_execution_time
        if oldest_process_execution_time && oldest_process_execution_time >= max_execution_time
          raise TurnstileException, "Failed max_execution_time check: #{oldest_process_execution_time} execution time out of max of #{max_execution_time}"
        end
      end
    end

    def setup
      yield config
      #$statsd = Statsd.new config.statsd_host, config.statsd_port
    end
  end
end


