dir = File.dirname(__FILE__)
$LOAD_PATH.unshift(dir) unless $LOAD_PATH.include? dir

require 'Peppermill/version'
require 'Peppermill/peppershaker'
require 'Peppermill/admin'

require 'cinch'
require 'daemons'
require 'yaml'

module Peppermill

  def self.config options, network
    config_file = options[:system] ? options[:system_config] : options[:local_config]

    raise ArgumentError.new "there's no config file located at: #{config_file}" unless File.exists? config_file
    raise ArgumentError.new "needs a network" if network.nil? or network.empty?

    cfg = YAML.load_file config_file

    raise ArgumentError.new "there's no server config in the config file" unless cfg.has_key? "servers"
    raise ArgumentError.new "there's no networks configured, please recheck #{config_file}" unless cfg["servers"]
    raise ArgumentError.new "the config file doesn't contain a config for #{network}" unless cfg["servers"].has_key? network

    ntw = cfg["servers"][network]

    cfg["options"] ||= {}
    dir_mode       = cfg["options"].key?("dir_mode") ? cfg["options"]["dir_mode"] : "normal"

    daemon_options = {
        :dir_mode   => dir_mode.to_sym,
        :dir        => cfg["options"]["dir"] || Dir.getwd,
        :log_output => cfg["options"]["log_output"] || false,
        :app_name   => "cinchize_#{network}",
        :ontop      => options[:ontop],
    }

    [daemon_options, ntw]
  end

  class Peppermill
    attr_reader :options

    def initialize(options, network)
      @network        = network
      @options        = options
    end

    def app_name
      options[:app_name]
    end

    def dir
      options[:dir]
    end

    def clean_app_name
      app_name.split('_', 2).last
    end

    def restart
      stop
      start
    end

    def start
      if running?
        raise ArgumentError.new "#{clean_app_name} is already running"
      end

      puts "* starting #{clean_app_name}"

      daemon = Daemons::ApplicationGroup.new(app_name, {
          :ontop    => options[:ontop],
          :dir      => dir,
          :dir_mode => options[:dir_mode]
      })
      app    = daemon.new_application :mode => :none, :log_output => options[:log_output]
      app.start

      network        = _sym_hash(@network)
      plugins        = [Peppermill::PepperShaker, Peppermill::Admin]

      loop do
        bot = Cinch::Bot.new do
          configure do |c|
            c.load network

            c.plugins.plugins = plugins
          end

          on :connect do |m|
            User('nickserv').send("identify #{ENV['PASSWORD']}")
          end
        end

        bot.start
      end
    end

    def stop
      unless running?
        puts "* #{clean_app_name} is not running"
        return
      end

      pidfile = Daemons::PidFile.new dir, app_name
      puts "* stopping #{clean_app_name}"

      Process.kill("QUIT", pidfile.pid)
      File.delete(pidfile.filename)
    end

    def status
      if running?
        puts "* #{clean_app_name} is running"
      else
        puts "* #{clean_app_name} is not running"
      end
    end

    def running?
      pidfile = Daemons::PidFile.new dir, app_name
      return false if pidfile.pid.nil?
      return Process.kill(0, pidfile.pid) != 0
    rescue Errno::ESRCH => e
      return false
    end

    def _sym_hash hsh
      hsh.keys.inject({}) do |memo, key|
        if hsh[key].is_a? Hash
          memo[key.to_sym] = _sym_hash(hsh[key])
        else
          memo[key.to_sym] = hsh[key]
        end
        memo
      end
    end
  end
end

# We need to open up Daemons::Application#start_none so we can log the output
# The original code can be found at:
# => http://github.com/ghazel/daemons/blob/master/lib/daemons/application.rb#L60
module Daemons
  class Application
    def start_none
      if options[:ontop]
        Daemonize.simulate
      else
        Daemonize.daemonize(output_logfile, @group.app_name) # our change goes here
      end

      @pid.pid = Process.pid

      at_exit {
        begin
          ; @pid.cleanup;
        rescue ::Exception;
        end
        if options[:backtrace] and not options[:ontop] and not $daemons_sigterm
          begin
            ; exception_log();
          rescue ::Exception;
          end
        end
      }
      trap(SIGNAL) {
        begin
          ; @pid.cleanup;
        rescue ::Exception;
        end
        $daemons_sigterm = true

        if options[:hard_exit]
          exit!
        else
          exit
        end
      }
    end
  end
end
