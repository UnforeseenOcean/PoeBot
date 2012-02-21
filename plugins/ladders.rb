
class Ladder
	def initialize(name, top_number, plugin)
		@agent = plugin.plugin(:agent).generate
		@title = name
		@url = "ladder/index/league/#{CGI::escape(name)}"
		@data = nil
		@level = nil
		@state = :unknown
		@top_number = top_number
		@plugin = plugin
	end
	
	def run
		log("Starting league #{@title}")
		
		@plugin.thread do
			sleep(5 + rand(10))
			@plugin.safe_loop do
				loop
			end
		end
	end
	
	def log(messages)
		@plugin.log(messages)
	end
	
	def message(message)
		@plugin.dispatch(:update, "[#{@title}] #{message}")
	end
	
	def find_spot(list, name)
		list.find { |spot| spot[:name] == name[:name] }
	end
	
	def get_spots(page = 1)
		@agent.get(@url + "/page/#{page}") do |page|
			return map_spots(page)
		end
	end
	
	def map_spots(page)
		page.root.at_css('table.striped-table').css('tr')[1..-1].map do |spot|
			columns = spot.css('td')
			{:rank => columns[0].content.to_i, :name => columns[2].content, :class => columns[3].content, :level => columns[4].content.to_i}
		end
	end
	
	def message_spots(spots)
		spots.map { |spot| "#{spot[:rank]}. #{spot[:name]}" }.each_slice(5) do |slice|
			message(slice.join(', '))
		end
	end
	
	def loop
		@agent.get(@url) do |page|
			countdown = page.root.at_css('#leagueCountdownBox')
			
			#<li id="leagueStatus" class="completeText">League has ended</li>
			# <li>
			# <span id="leagueBeginLabel" class="bright">Begun: </span>
			# 20. august 2011 04.00
			# </li>
			# <li>
			# <span id="leagueEndLabel" class="bright">Ended: </span>
			# 20. august 2011 08.00
			# </li>
			
			if countdown
				unless countdown.at_css('div.inProgressText')
					@state = :waiting
					next
				end
			end
			
			next if @state == :ended
			
			spots = map_spots(page)[0...(@top_number)]
			
			if @data
				notified = {}
				
				messages = []
				
				leader = spots.first	
				
				if @level
					if leader[:level] > @level
						message("The leader #{leader[:name]}, is now level #{leader[:level]}.") if @level
						
						@level = leader[:level]
					end
				else
					@level = leader[:level]
				end
				
				@top_number.times do |spot|
					old_obj = @data[spot]
					new_obj = spots[spot]
					
					next unless old_obj
					next unless new_obj
					
					if old_obj[:name] != new_obj[:name]
						new_in_old = find_spot(@data, new_obj)
						old_in_new = find_spot(spots, old_obj)
						
						next if notified[new_obj]
						
						if notified[old_in_new]
							message_text = "#{new_obj[:name]} has moved from #{new_in_old ? "##{new_in_old[:rank]}" : "out of top #{@top_number}"} to ##{new_obj[:rank]}."
						else
							message_text = "#{new_obj[:name]} (previously #{new_in_old ? "##{new_in_old[:rank]}" : "out of top #{@top_number}"}) has stolen ##{new_obj[:rank]} from #{old_obj[:name]} (now #{old_in_new ? "##{old_in_new[:rank]}" : "out of top #{@top_number}"})."
							
							if old_in_new
								notified[old_in_new] = true
							end
						end
						
						messages << message_text
						
						notified[new_obj] = true
					end
				end
				
				if messages.size > 3
					message_spots(spots)
				else
					messages.each do |message_text|
						message(message_text)
					end
				end
			end
			
			ending = page.root.at_css('#leagueEndLabel')
			(ending = ending.content.strip == 'Ended:') if ending
			
			if ending && (@state != :ended)
				if @state == :unknown
					log("Turning off league #{@title}")
					raise PoeBot::Plugin::ExitException
				else
					message("The race has ended.")
				end
				
				spots.map { |spot| "#{spot[:rank]}. #{spot[:name]}" }.each_slice(5) do |slice|
					message(slice.join(', '))
				end
				
				@state = :ended
				@ended = Time.now
			end
			
			if @state == :unknown || @state == :waiting
				if @state == :waiting
					message("The race is on!")
				end
				@state = :ongoing
			end
			
			@data = spots
		end
		
		sleep 180
	end
end

class Ladders < PoeBot::Plugin
	uses :agent, :settings
	
	listen :command do |command, parameters|
		parameter_array = parameters.split(' ')
		
		case command
			when "top"
				league = find_league(parameters)
				next unless league
				
				ladder = get_ladder(league)
				ladder.message_spots(ladder.get_spots[0...10])
				
			when "leader"
				league = find_league(parameters)
				next unless league
				
				leader = get_ladder(league).get_spots.first
				
				dispatch(:say, "The leader in #{league} is #{leader[:name]} (a level #{leader[:level]} #{leader[:class]}).")
				
			when "rank"
				rank = parameter_array[0].to_i
				league = find_league(parameter_array[1..-1].join(' '))
				next unless league
				
				page = ((rank - 1) / 20) + 1
				index = ((rank - 1) % 20)
				
				player = get_ladder(league).get_spots(page)[index]
				next unless player
				
				dispatch(:say, "Rank \##{rank} in #{league} is #{player[:name]} (a level #{player[:level]} #{player[:class]}).")
		end
	end
	
	def find_league(league)
		@leagues.each_key do |key|
			return key if league.downcase == key.downcase
		end
		return nil
	end
	
	def start
		@leagues = {}
		@top_number = plugin(:settings)['TopNumber']
		@agent = plugin(:agent).generate
		refresh_leagues(false)
		
		thread do
			safe_loop do
				refresh_leagues
				
				sleep 600
			end
		end
	end
	
	def get_ladder(name)
		 Ladder.new(name, @top_number, self)
	end
	
	def refresh_leagues(fresh = true)
		@agent.get("ladder/index/league") do |page|
			page.root.at_css('select#league').css('option').each do |option|
				name = option.content
				unless @leagues.has_key?(name)
					@leagues[name] = get_ladder(name).run
					dispatch(:update, "A new league has been discovered: '#{name}'") if fresh
				end
			end
		end
	end
end
