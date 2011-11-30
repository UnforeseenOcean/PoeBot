
class Ladder
	def initialize(name, top_number, agent, plugin)
		@agent = agent
		@title = name
		@url = "ladder/index/league/#{CGI::escape(name)}"
		@data = nil
		@level = nil
		@state = :unknown
		@top_number = top_number
		@plugin = plugin
		
		log("Starting league #{name}")
		
		@plugin.thread do
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
			
			spots = page.root.at_css('table.striped-table').css('tr')[1..(@top_number)].map do |spot|
				columns = spot.css('td')
				{:rank => columns[0].content.to_i, :name => columns[2].content, :level => columns[4].content.to_i}
			end
			
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
					spots.map { |spot| "#{spot[:rank]}. #{spot[:name]}" }.each_slice(5) do |slice|
						message(slice.join(', '))
					end
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
		
		sleep 60
	end
end

class Ladders < PoeBot::Plugin
	uses :agent, :settings
	
	def start
		@leagues = {}
		@top_number = plugin(:settings)['TopNumber']
		@agent = plugin(:agent).generate_public
		refresh_leagues(false)
		
		thread do
			safe_loop do
				refresh_leagues
				
				sleep 600
			end
		end
	end
	
	def refresh_leagues(fresh = true)
		@agent.get("ladder/index/league") do |page|
			page.root.at_css('select#league').css('option').each do |option|
				name = option.content
				unless @leagues.has_key?(name)
					@leagues[name] = Ladder.new(name, @top_number, plugin(:agent).generate_public, self)
					dispatch(:update, "A new league has been discovered: '#{name}'") if fresh
				end
			end
		end
	end
end
