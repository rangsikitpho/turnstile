module Turnstile
  class Db
    attr_accessor :clazz, :method_name, :type, :key, :dynamo_db

    def initialize(clazz,method_name,type)
      self.clazz = clazz
      self.method_name = method_name
      self.type = type
    end

    def clear_active_processes
      item.attributes.delete(:active)
    end

    def add_active_process
      Db.process_timestamp.tap do |process_timestamp|
        item.attributes.add(:active => [process_timestamp])
      end
    end

    def delete_all_active_processes
      item.attributes.delete(:active)
    end

    def delete_active_process(process_timestamp)
      item.attributes.delete(:active => [process_timestamp])
    end

    def active_process_count
      active_processes = item.attributes.values_at(:active).first
      active_processes ? active_processes.count : 0
    end

    def oldest_process_execution_time
      active_processes = item.attributes.values_at(:active).first
      return nil unless active_processes

      now = Time.now
      active_processes.map do |active_process|
        started_at = Time.parse(active_process.split('|').first)
        now - started_at
      end.max
    end

    def self.all_active_processes_for_project(project)
      table.items.query(hash_value: project)
    end

    # Clear active processes for this project
    def self.clear_all_active_processes
      clear_all_active_processes_for_project(Turnstile.config.project)
    end

    def self.clear_all_active_processes_for_project(project)
      table.items.query(hash_value: project).select do |item|
        item.attributes.delete(:active)
      end
    end

    # Clear the entire turnstile deleting all dynamo records. 
    # This will delete all projects using the current turnstile db
    def self.clear_all
      table.items.select do |data|
        data.item.delete
      end
    end

    # Clear old processes for this project
    def self.clear_old
      clear_old_for_project(Turnstile.config.project)
    end

    def self.clear_old_for_project(project)
      old_process_timestamps = []
      table.items.query(hash_value: project).select do |item|
        (item.attributes.values_at("active")[0] || []).each do |process_timestamp|
          if process_timestamp and (Time.now - extract_time(process_timestamp)) > Turnstile.config.ttl
            item.attributes.delete(:active => [process_timestamp])
            clazz, method_name, type = item.attributes.values_at("process")[0].split(".")
            old_process_timestamps << { clazz: clazz, method_name: method_name, type: type, process_timestamp: process_timestamp }
          end
        end
      end

      old_process_timestamps
    end

    # For error reporting usage
    def stilename
      separator = type == 'class' ? '::' : '#'
      "#{clazz}#{separator}#{method_name}"
    end

    private
    def item
      Db.table.items[Turnstile.config.project,Db.process_key(clazz,method_name,type)]
    end

    def self.process_key(clazz,method_name,type)
      "#{clazz}.#{method_name}.#{type}"
    end

    def self.process_timestamp
      "#{Time.now}|#{rand}"
    end
    
    def self.extract_time(process_timestamp)
      Time.parse(process_timestamp.split('|')[0]) if process_timestamp
    end

    def self.table
      @@table ||= dynamo_db.tables[Turnstile.config.table_name].tap do |table|
        table.hash_key = [:project, :string]
        table.range_key = [:process, :string]
      end
    end

    def self.dynamo_db
      @@dynamo_db ||= AWS::DynamoDB.new(
        :access_key_id => Turnstile.config.aws_access_key_id || AWS_ACCESS_KEY_ID,
        :secret_access_key => Turnstile.config.aws_secret_access_key || AWS_SECRET_ACCESS_KEY)
    end
  end
end

