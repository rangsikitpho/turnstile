require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Turnstile::Db" do
  before(:each) do
    Turnstile.setup do |config|
      config.project = 'My Project'
      config.table_name = 'test_turnstile'
      config.aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
      config.aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
      config.ttl = 10
    end
    Turnstile::Db.clear_all
  end

  describe "#add_active_process" do
    it "properly increments active_process_count" do
      pdb = Turnstile::Db.new('TestClass','test_method','instance')
      pdb.clear_active_processes

      pdb.add_active_process
      pdb.active_process_count.should equal 1
    end
  end

  describe "#delete_active_process" do
    it "properly decrements active_process_count" do
      pdb = Turnstile::Db.new('TestClass','test_method','instance')
      pdb.clear_active_processes

      process_timestamp = pdb.add_active_process
      pdb.delete_active_process(process_timestamp)
      pdb.active_process_count.should equal 0
    end
  end

  describe "#clear_active_processes" do
    it "properly decrements active_process_count to 0" do
      pdb = Turnstile::Db.new('TestClass','test_method','instance')

      pdb.add_active_process
      pdb.add_active_process
      pdb.clear_active_processes
      pdb.active_process_count.should equal 0
    end
  end

  describe "#oldest_process_execution_time" do
    it "picks oldest process execution time" do
      pdb = Turnstile::Db.new('TestClass','test_method','instance')

      process_1_timestamp = pdb.add_active_process
      sleep(2)
      pdb.add_active_process

      process_1_time = Time.parse(process_1_timestamp.split('|').first)

      now = Time.now
      Time.stub!(:now).and_return(now)

      (now - process_1_time).should equal pdb.oldest_process_execution_time
    end
  end

  describe ".clear_old" do
    it "doesn't clear the turnstile if within ttl range" do
      pdb = Turnstile::Db.new('TestClass','test_method','instance')
      pdb.add_active_process
      Turnstile::Db.clear_old
      pdb.active_process_count.should equal 1
    end

    it "does clear the turnstile if outside of the ttl range" do
      pdb = Turnstile::Db.new('TestClass','test_method','instance')
      Turnstile::Db.stub(:process_timestamp).and_return("#{Time.now - 10}|#{rand}")
      pdb.add_active_process
      Turnstile::Db.clear_old
      pdb.active_process_count.should equal 0
    end

    it "clears and maintains appropriately based on ttl" do
      pdb = Turnstile::Db.new('TestClass','test_method','instance')
      pdb.add_active_process
      Turnstile::Db.stub(:process_timestamp).and_return("#{Time.now - 10}|#{rand}")
      pdb.add_active_process
      Turnstile::Db.clear_old
      pdb.active_process_count.should equal 1
    end
  end

end


