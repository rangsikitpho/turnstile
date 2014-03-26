require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Turnstile" do
  before(:each) do
    Turnstile.setup do |config|
      config.project = 'MyProject'
      config.table_name = 'test_turnstile'
      config.aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
      config.aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
      config.statsd_host = '10.206.34.16'
      config.statsd_port = 8125
    end

    Turnstile::Db.clear_all_active_processes
  end

  it "properly calls the original class method with the correct arguments" do
    class Temp
      include Turnstile
      def self.my_method(arg)
        arg += 1
      end
      add_turnstile 'self.my_method', 'self.my_new_method', max_processes: 1
    end

    arg = 5
    Temp.should_receive(:my_method).with(arg)
    Temp.my_new_method(arg)
  end

  it "properly calls the original instance method with the correct arguments" do
    class Temp
      include Turnstile
      def my_method(arg)
        arg += 1
      end
      add_turnstile :my_method, :my_new_method, max_processes: 1
    end

    t = Temp.new
    arg = 5
    t.should_receive(:my_method).with(arg)
    t.my_new_method(arg)
  end


  it "raises a TurnstileException when max_processes is exceeded" do
    class Temp
      include Turnstile
      def my_method
        sleep(5)
      end
      add_turnstile :my_method, :my_new_method, max_processes: 1
    end

    t = Temp.new
    threads = []
    threads << Thread.new { t.my_new_method }
    threads << Thread.new { t.my_new_method }

    expect { threads.each { |thr| thr.join } }.to raise_error(Turnstile::TurnstileException)
  end

  it "raises a TurnstileException when max_execution_time is exceeded" do
    class Temp
      include Turnstile
      def my_method
        sleep(2)
      end
      add_turnstile :my_method, :my_new_method, max_execution_time: 1 #second
    end

    t = Temp.new
    #t.my_new_method
    expect { t.my_new_method }.to raise_error(Turnstile::TurnstileException)

  end

  it "it doesn't fail on next run after a max_execution_time exception" do
    class Temp
      include Turnstile
      def my_method
        sleep(3)
      end
      add_turnstile :my_method, :my_new_method, max_execution_time: 2 #second
    end

    t = Temp.new
    #t.my_new_method
    expect { t.my_new_method }.to raise_error(Turnstile::TurnstileException)

    class Temp
      def my_method
        # No sleep
      end
    end

    t = Temp.new
    t.my_new_method
  end

  it "properly gets the class name for instance methods" do
    class Temp
      include Turnstile
      def my_method
      end
      add_turnstile :my_method, :my_new_method, max_execution_time: 10 #second
    end

    t = Temp.new
    db = Turnstile::Db.new('Temp','my_method','instance') # Doing it this way since and_call_original doesn't work in this version of rspec
    Turnstile::Db.should_receive(:new).with('Temp',:my_method,'instance').and_return(db)
    t.my_new_method
  end

  it "properly gets the class name for class methods" do
    class Temp
      include Turnstile
      def self.my_method
      end
      add_turnstile 'self.my_method', 'self.my_new_method', max_execution_time: 1 #second
    end

    db = Turnstile::Db.new('Temp','my_method','class') # Doing it this way since and_call_original doesn't work in this version of rspec
    Turnstile::Db.should_receive(:new).with('Temp','my_method','class').and_return(db)
    Temp.my_new_method
  end

  it "squelches properly" do
    class Temp
      include Turnstile
      def self.my_method
        sleep 3
        return true
      end
      add_turnstile 'self.my_method', 'self.my_new_method', max_execution_time: 1, squelch: true
    end

    Temp.my_new_method.should be_nil
  end
end

