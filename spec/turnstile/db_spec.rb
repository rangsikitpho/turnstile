require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Turnstile::Db" do
  before(:each) do
    Turnstile.setup do |config|
      config.project = 'My Project'
      config.table_name = 'test_turnstile'
      config.aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
      config.aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
    end
  end

  it "add_active_process properly increments active_process_count" do
    pdb = Turnstile::Db.new('TestClass','test_method','instance')
    pdb.clear_active_processes

    pdb.add_active_process
    pdb.active_process_count.should equal 1
  end

  it "delete_active_process properly decrements active_process_count" do
    pdb = Turnstile::Db.new('TestClass','test_method','instance')
    pdb.clear_active_processes

    process_timestamp = pdb.add_active_process
    pdb.delete_active_process(process_timestamp)
    pdb.active_process_count.should equal 0
  end

  it "clear_active_process properly decrements active_process_count to 0" do
    pdb = Turnstile::Db.new('TestClass','test_method','instance')

    pdb.add_active_process
    pdb.add_active_process
    pdb.clear_active_processes
    pdb.active_process_count.should equal 0
  end

  it "properly picks oldest process execution time" do
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


