require 'cinch'
require 'json'
require 'shorturl'
require 'rest_client'
require 'daemons'
class Peppermill::PepperShaker
  include Cinch::Plugin
  match /^\?s ([\w\s\d\.\(\)'\-_&\+]+),([\+\w\s\d\.\(\)'\/\-_&]+)$/, {
      :use_prefix => false,
      :method     => :lookup_multi
  }
  match /^\?s ([\w\s\d\.\(\)'\-_&\+]+)$/, {
      :use_prefix => false,
      :method     => :lookup_single
  }

  def initialize(*args)
    super

    @champions = JSON.parse(RestClient.get 'http://apeppershaker.com/api/v1/champion/list')
  end

  def lookup_single(message, name)
    reply          = lookup_champ(name)
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

    if elo < 300
      colored_elo = Format(:red, :bold, elo.to_s)
    elsif elo >= 300 && elo < 500
      colored_elo = Format(:orange, :bold, elo.to_s)
    elsif elo >= 500 && elo < 700
      colored_elo = Format(:royal, :bold, elo.to_s)
    elsif elo >= 700
      colored_elo = Format(:green, :bold, elo.to_s)
    end

    colored_elo
  end

  def retrieve_champ(id)
    JSON.parse(RestClient.get "http://apeppershaker.com/api/v1/champion/show/by_id/#{id}")
  end

  def get_winrate(champ)
    losses = champ['losses'].to_f
    wins   = champ['wins'].to_f
    if losses == 0 && wins > 0
      winrate = 100
    elsif wins == 0
      winrate = 0
    else
      winrate = ((wins/(losses+wins)).to_f*100).round(1)
    end

    winrate
  end

end
