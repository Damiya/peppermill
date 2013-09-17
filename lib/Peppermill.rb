require 'Peppermill/version'
require 'Peppermill/peppershaker'
require 'Peppermill/admin'
require 'dotenv'


module Peppermill
  def self.launch
    Dotenv.load!
    bot = Cinch::Bot.new do
      configure do |c|
        c.user            = 'Peppermill'
        c.nick            = 'Peppermill'
        c.server          = 'irc.synirc.net'
        c.channels        = %w(#saltybettest)
        c.plugins.plugins = [Peppermill::PepperShaker, Peppermill::Admin]
      end

      on :connect do |m|
        User('nickserv').send("identify #{ENV['PASSWORD']}")
      end
    end
    bot.start
  end
end
