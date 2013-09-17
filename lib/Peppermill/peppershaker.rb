require 'cinch'
require 'json'
require 'shorturl'
require 'uri/common'
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
    message.reply("#{reply} | HT: #{Format(:bold, hightower_link)}")
  end

  def lookup_multi(message, champ_one_name, champ_two_name)
    fight_string, rematch_string = lookup_fight(champ_one_name, champ_two_name)
    hightower_link               = build_hightower_link(champ_one_name, champ_two_name)
    message.reply("#{fight_string} | HT: #{Format(:bold, hightower_link)}")

    if rematch_string != ''
      message.reply(rematch_string)
    end
  end

  private

  def build_hightower_link(champ_one_name, champ_two_name = nil)
    link = 'http://fightmoney.herokuapp.com/stats/#/' + champ_one_name.downcase.strip

    if champ_two_name
      link += '/' + champ_two_name.downcase.strip
    end

    ShortURL.shorten(link, :bitly)
  end

  def lookup_fight(champ_one_name, champ_two_name)
    champ_one_name = champ_one_name.downcase.strip
    champ_two_name = champ_two_name.downcase.strip
    fight_string   = ''
    rematch_string = ''
    fight_obj      = retrieve_fight(champ_one_name, champ_two_name)
    if fight_obj['left']==nil
      fight_string += name_not_found(champ_one_name)
    else
      fight_string += parse_champ(fight_obj['left'])
    end
    fight_string += ' | '
    if fight_obj['right']==nil
      fight_string += name_not_found(champ_two_name)
    else
      fight_string += parse_champ(fight_obj['right'])
    end

    if fight_obj['rematch']
      rematch_string = parse_rematch(fight_obj['rematch'], champ_one_name, champ_two_name)
    end

    return fight_string, rematch_string
  end

  def parse_rematch(rematch_obj, champ_one_name, champ_two_name)
    rematch_string = Format(:bold, 'Rematch! ')
    if rematch_obj['left_has_won'] && rematch_obj['right_has_won']
      rematch_string += Format(:bold, :red, champ_one_name) + ' and ' +
          Format(:bold, :red, champ_two_name) + ' have both beaten the other.'
    elsif rematch_obj['left_has_won']
      rematch_string += Format(:bold, :green, champ_one_name) + ' has beaten ' +
          Format(:bold, :red, champ_two_name)
    elsif rematch_obj['right_has_won']
      rematch_string += Format(:bold, :green, champ_two_name) + ' has beaten ' +
          Format(:bold, :red, champ_one_name)
    end

    rematch_string
  end


  def lookup_champ(name)
    name  = name.downcase.strip
    reply = name_not_found(name)

    champ_id = @champions[name]
    if champ_id
      reply = parse_champ(retrieve_champ(champ_id))
    end

    reply
  end

  def parse_champ(champ_obj)
    winrate = get_winrate(champ_obj)
    Format(:bold, "#{champ_obj['name']}") + ': [E: ' + color_elo(champ_obj) +
        '] [' + Format(:bold, :green, "#{champ_obj['wins']}") + 'W/' + Format(:bold, :red, "#{champ_obj['losses']}") + 'L] (' +
        Format(:bold, "#{winrate}%") + ' out of ' + Format(:bold, "#{get_total_matches(champ_obj)}") + ')'

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
      colored_elo = Format(:green, :bold, elo.to_s)
    elsif elo >= 700
      colored_elo = Format(:lime, :bold, elo.to_s)
    end

    colored_elo
  end

  def retrieve_fight(name_one, name_two)
    JSON.parse(RestClient.get "http://apeppershaker.com/api/v1/fight/show/by_name/#{URI.escape(name_one)}/#{URI.escape(name_two)}")
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

  def name_not_found(name)
    Format(:bold, "#{name}") + ' was not found in the database. Check your spelling!'
  end

end
