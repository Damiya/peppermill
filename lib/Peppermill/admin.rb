class Peppermill::Admin
  include Cinch::Plugin

  match /quit/
  def execute(message)
    if message.prefix=='Damiya!~damiya@a.gay.wizard.irl'
      bot.quit
    end
  end
end