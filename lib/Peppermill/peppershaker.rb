require 'cinch'
require 'json'
require 'rest_client'

class Peppermill::PepperShaker
  include Cinch::Plugin
  match /^\?s ([\w\s\d\.\(\)'\-_&\+:]+),([\+\w\s\d\.\(\)'\/\-_&:]+)$/, {
      :use_prefix => false,
      :method     => :lookup_multi
  }
  match /^\?s ([\w\s\d\.\(\)'\-_&\+:]+)$/, {
      :use_prefix => false,
      :method     => :lookup_single
  }

  match /^\?stats$/, {
      :use_prefix => false,
      :method     => :lookup_match
  }

  match /^\!update_champions$/,{
      :use_prefix => false,
      :method     => :update_champions
  }

  match /^\`s$/, {
      :use_prefix => false,
      :method     => :lookup_match
  }

  def initialize(*args)
    super

    @champions = retrieve_champs_list
    @admins = %w(Damiya!~damiya@a.gay.wizard.irl)
  end

  def check_user(prefix)
    @admins.include?prefix
  end

  def update_champions(m)
    return unless check_user(m.prefix)
    @champions = retrieve_champs_list
    m.reply("Updated champions list: #{@champions.length}")
  end

  def lookup_match(message)
    secret_sauce = get_the_secret_sauce
    lookup_multi(message, secret_sauce['player1name'], secret_sauce['player2name'])
  end

  def lookup_single(message, name)
    reply          = lookup_champ(name)
    hightower_link = build_hightower_link(name, nil)

    if hightower_link
      reply += " | HT: #{Format(:bold, hightower_link)}"
    end
    message.reply("#{reply}")
  end

  def lookup_multi(message, champ_one_name, champ_two_name)
    reply, rematch_string = lookup_fight(champ_one_name, champ_two_name)
    hightower_link        = build_hightower_link(champ_one_name, champ_two_name)
    if hightower_link
      reply += " | HT: #{Format(:bold, hightower_link)}"
    end
    message.reply("#{reply}")

    if rematch_string
      message.reply(rematch_string)
    end
  end

  private

  def build_hightower_link(champ_one_name, champ_two_name = nil)
    champ_one = get_champ_id(champ_one_name)
    link = nil

    if champ_one == nil
      return nil
    end

    if champ_two_name
      champ_two = get_champ_id(champ_two_name)
      if champ_two
        link = "http://apeppershaker.com/api/v1/s/f/#{champ_one}/#{champ_two}"
      end
    else
      link = "http://apeppershaker.com/api/v1/s/c/#{champ_one}"
    end

    link
  end

  def lookup_fight(champ_one_name, champ_two_name)
    champ_one_name = champ_one_name.downcase.strip
    champ_two_name = champ_two_name.downcase.strip
    fight_string   = ''
    rematch_string = nil
    fight_obj      = retrieve_fight(get_champ_id(champ_one_name), get_champ_id(champ_two_name))
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

    champ_id = get_champ_id(name)
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

  def get_champ_id(name)
    name            = name.downcase.strip
    name_apostrophe = name.gsub(/ /, '\'')
    name_underscore = name.gsub(/ /, '_')
    id              = nil

    if @champions[name]
      id = @champions[name]
    elsif @champions[name_apostrophe]
      id = @champions[name_apostrophe]
    elsif @champions[name_underscore]
      id = @champions[name_underscore]
    end

    id
  end

  def retrieve_fight(id_one, id_two)
    if !id_one
      id_one = 99999
    end

    if !id_two
      id_two = 99999
    end

    JSON.parse(RestClient.get "http://apeppershaker.com/api/v1/fight/show/by_id/#{id_one}/#{id_two}")
  end

  def retrieve_champ(id)
    JSON.parse(RestClient.get "http://apeppershaker.com/api/v1/champion/show/by_id/#{id}")
  end

  def retrieve_champs_list
    JSON.parse(RestClient.get 'http://apeppershaker.com/api/v1/champion/list')
  end

  def get_the_secret_sauce
    JSON.parse(RestClient.get ENV['SECRET_SAUCE'])
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
