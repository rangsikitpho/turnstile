module Turnstile
  class Db
    attr_accessor :clazz, :method_name, :type, :key, :dynamo_db

    def initialize(clazz,method_name,type)
      self.clazz = clazz
      self.method_name = method_name
      self.type = type
      self.key = Db.key(clazz,method_name,type)

    end

    def clear_active_processes
      item.attributes.delete(:active_processes)
    end

    def add_active_process
      Db.process_timestamp.tap do |process_timestamp|
        item.attributes.add(:active_processes => [process_timestamp])
      end
    end

    def delete_active_process(process_timestamp)
      item.attributes.delete(:active_processes => [process_timestamp])
    end

    def active_process_count
      active_processes = item.attributes.values_at(:active_processes).first
      active_processes ? active_processes.count : 0
    end

    def oldest_process_execution_time
      active_processes = item.attributes.values_at(:active_processes).first
      return nil unless active_processes

      now = Time.now
      active_processes.map do |active_process|
        started_at = Time.parse(active_process.split('|').first)
        now - started_at
      end.max
    end

    def self.clear_all_active_processes
      # Is this the easiest way to delete all items?
      table.items.select do |data|
        data.item.delete
      end
    end

    # For error reporting usage
    def stilename
      separator = type == 'class' ? '::' : '#'
      "#{clazz}#{separator}#{method_name}"
    end

    private
    def item
      Db.table.items[Db.key(clazz,method_name,type)]
    end

    def self.key(clazz,method_name,type)
      "#{Turnstile.config.namespace}.#{clazz}.#{method_name}.#{type}"
    end

    def self.process_timestamp
      "#{Time.now}|#{rand}"
    end

    def self.table
      @@table ||= dynamo_db.tables[Turnstile.config.table_name].tap do |table|
        table.hash_key = [:key, :string]
      end
    end

    def self.dynamo_db
      @@dynamo_db ||= AWS::DynamoDB.new(
        :access_key_id => Turnstile.config.aws_access_key_id || AWS_ACCESS_KEY_ID,
        :secret_access_key => Turnstile.config.aws_secret_access_key || AWS_SECRET_ACCESS_KEY)
    end
  end
end

