class Peppermill::Admin
  include Cinch::Plugin

  match /quit/, method: :quit
  match /join (.+)/, method: :join
  match /part (.+)/, method: :part

  def initialize(*args)
    super

    @admins = %w(Damiya!~damiya@a.gay.wizard.irl)
  end

  def check_user(prefix)
    @admins.include?prefix
  end

  def join(m, channel)
    return unless check_user(m.prefix)
    Channel(channel).join
  end

  def part(m, channel)
    return unless check_user(m.prefix)
    channel ||= m.channel
    Channel(channel).part if channel
  end

  def quit(m)
    return unless check_user(m.prefix)

    bot.quit
  end
end