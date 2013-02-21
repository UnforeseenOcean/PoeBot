require 'time'

class Ladder
	def initialize(name, ending, top_number, plugin)
		@agent = plugin.plugin(:agent).generate
		@ending = ending
		@title = name
		@url = "leagues/#{CGI::escape(name)}?ladder=1&ladderLimit=#{top_number}"
		@data = nil
		@top_number = top_number
		@level = nil
		@state = :unknown
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
	
	def end_league
		log("Turning off league #{@title}")
		raise PoeBot::Plugin::ExitException
	end
	
	def loop
		sleep 180
		
		@agent.api(@url) do |ladder|
			end_league if ladder['error']
			
			spots = ladder['ladder']['entries'].map do |entry|
				{:rank => entry['rank'].to_i, :name => entry['character']['name'], :class => entry['character']['class'], :level => entry['character']['level'].to_i}
			end
			
			if spots.empty?
			else
				if @data
					notified = {}
					
					messages = []
					
					leader = spots.first	
					
					if @level
						if leader[:level] != @level
							message("The leader #{leader[:name]}, is now level #{leader[:level]}.")
							
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
			end
			
			ending = @ending && (Time.now > @ending)
			
			if ending && (@state != :ended)
				if @state == :unknown
					end_league
				else
					message("The race has ended.")
				end
				
				spots.map { |spot| "#{spot[:rank]}. #{spot[:name]}" }.each_slice(5) do |slice|
					message(slice.join(', '))
				end
				
				@state = :ended
				@ended = Time.now + 300
			end
			
			if (@state == :ended) && (Time.now > @ended)
				log("Turning off league #{@title}")
				raise PoeBot::Plugin::ExitException
			end
		
			if @state == :unknown || @state == :waiting
				if @state == :waiting
					message("The race is on!")
				end
				@state = :ongoing
			end
			
			@data = spots
		end
	end
end

class Ladders < PoeBot::Plugin
	uses :agent, :settings
	if nil
	listen :command do |command, source, parameters|
		parameter_array = parameters.split(' ')
		
		case command
			#when "top"
			#	league = find_league(parameters)
			#	next unless league
				
			#	ladder = get_ladder(league)
			#	ladder.message_spots(ladder.get_spots[0...10])
				
			when "leader"
				league = find_league(parameters)
				next unless league
				
				leader = get_ladder(league).get_spots.first
				
				dispatch(:say, "The leader in #{league} is #{leader[:name]} (a level #{leader[:level]} #{leader[:class]}).", source)
				
			#when "rank"
			#	rank = parameter_array[0].to_i
			#	league = find_league(parameter_array[1..-1].join(' '))
			#	next unless league
				
			#	page = ((rank - 1) / 20) + 1
			#	index = ((rank - 1) % 20)
				
			#	player = get_ladder(league).get_spots(page)[index]
			#	next unless player
				
			#	dispatch(:say, "Rank \##{rank} in #{league} is #{player[:name]} (a level #{player[:level]} #{player[:class]}).", source)
		end
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
		
		thread do
			refresh_leagues(false)
			
			safe_loop do
				sleep 600
				
				refresh_leagues
			end
		end
	end
	
	def get_ladder(ladder)
		 Ladder.new(ladder['id'], ladder['endAt'] ? Time.parse(ladder['endAt']) : nil, @top_number, self)
	end
	
	def refresh_leagues(fresh = true)
		@agent.api("leagues") do |ladders|
			ladders.each do |ladder|
				name = ladder['id']
				unless @leagues.has_key?(name)
					next if name == 'GGG Private'
					@leagues[name] = get_ladder(ladder).run
					dispatch(:update, "A new league has been discovered: '#{name}' - #{ladder['url']}") if fresh
				end
			end
		end
	end
end
