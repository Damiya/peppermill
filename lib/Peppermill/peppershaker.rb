require 'cinch'
require 'json'
require 'shorturl'
require 'rest_client'
class Peppermill::PepperShaker
  include Cinch::Plugin
  match /^?s ([\w\s\d]+),([\w\s\d]+)$/, {
      :use_prefix => false,
      :method     => :lookup_multi
  }
  match /^?s ([\w\s\d]+)$/, {
      :use_prefix => false,
      :method     => :lookup_single
  }

  def initialize(*args)
    super

    @champions = JSON.parse(RestClient.get 'http://apeppershaker.com/api/v1/champion/list')
  end

  def lookup_single(message, name)
    reply = lookup_champ(name)
    hightower_link = build_hightower_link(name, nil)
    message.reply("#{reply} | Hightower: #{Format(:bold, hightower_link)}")
  end

  def lookup_multi(message, champ_one_name, champ_two_name)
    champ_one_string = lookup_champ(champ_one_name)
    champ_two_string = lookup_champ(champ_two_name)
    hightower_link   = build_hightower_link(champ_one_name, champ_two_name)
    message.reply("#{champ_one_string} | #{champ_two_string} | Hightower: #{Format(:bold, hightower_link)}")
  end

  def build_hightower_link(champ_one_name, champ_two_name = nil)
    link = 'http://fightmoney.herokuapp.com/stats/#/' + champ_one_name

    if champ_two_name
      link += '/' + champ_two_name
    end
    ShortURL.shorten(link, :tinyurl)
  end

  private
  def lookup_champ(name)
    name  = name.downcase.strip
    reply = Format(:bold, "#{name} was not found in the database. Check your spelling!")

    champ_id = @champions[name]
    if champ_id
      champ_obj = retrieve_champ(champ_id)
      winrate   = get_winrate(champ_obj)
      reply     = Format(:bold, "#{champ_obj['name']}") + ': [E: ' + color_elo(champ_obj) +
          '] [' + Format(:bold, :green, "#{champ_obj['wins']}") + 'W/' + Format(:bold, :red, "#{champ_obj['losses']}") + 'L] (' +
          Format(:bold, "#{winrate}%") + ' out of ' + Format(:bold, "#{get_total_matches(champ_obj)}") + ')'
    end

    reply
  end

  def get_total_matches(obj)
    obj['wins'] + obj['losses']
  end

  def color_elo(obj)
    colored_elo = ''
    elo         = obj['elo']

    if elo < -200
      colored_elo = Format(:bold, :red, elo.to_s)
    elsif elo >= -200 && elo < 0
      colored_elo = Format(:red, elo.to_s)
    elsif elo >= 0 && elo < 200
      colored_elo = Format(:green, elo.to_s)
    elsif elo >= 200
      colored_elo = Format(:bold, :green, elo.to_s)
    end

    colored_elo
  end

  def retrieve_champ(id)
    JSON.parse(RestClient.get "http://apeppershaker.com/api/v1/champion/show/by_id/#{id}")
  end

  def get_winrate(champ)
    (champ['losses'].to_f/champ['wins'].to_f).round(3)*100
  end

end
