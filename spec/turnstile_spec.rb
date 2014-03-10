require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Turnstile" do
  before(:each) do
    Turnstile.setup do |config|
      config.namespace = 'My Project'
      config.aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
      config.aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
    end

    Turnstile::Db.clear_all_active_processes
  end

  it "properly calls the original class method with the correct arguments" do
    class Temp
      include Turnstile
      def self.my_method(arg)
        arg += 1
      end
      add_turnstile 'self.my_method', 'self.my_new_method', :max_processes => 1
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
      add_turnstile :my_method, :my_new_method, :max_processes => 1
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
      add_turnstile :my_method, :my_new_method, :max_processes => 1
    end

    t = Temp.new
    threads = []
    threads << Thread.new { t.my_new_method }
    threads << Thread.new { t.my_new_method }

    expect { threads.each { |thr| thr.join } }.to raise_error(Turnstile::TurnstileException)
  end
end

