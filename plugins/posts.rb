class Posts < PoeBot::Plugin
	uses :agent
	
	def start
		@nicks = {
			"Chris" => nil,
			"Jonathan" => nil,
			"Mark_GGG" => nil,
			"Joel_GGG" => nil,
			"BrianWeissman" => nil,
			"Andrew_GGG" => nil,
			"Damien_GGG" => nil,
			"Jess_GGG" => nil,
			"Ammon_GGG" => nil,
			"Edwin_GGG" => nil,
			"Robbie_GGG" => nil,
			"GGG_Neon" => nil,
			"Support" => nil,
			"Erik" => nil,
			"Rhys" => nil,
			"Russell" => nil,
			"Dylan" => nil,
			"Rory" => nil,
			"Qarl" => nil,
			"Thomas" => nil,
			"Ari" => nil,
			"Samantha" => nil,
			"MaxS" => nil
		}
		
		@agent = plugin(:agent).generate
		@public_agent = plugin(:agent).generate_public
		
		thread do
			safe_loop do
				sleep 60
				
				refresh
			end
		end
	end
	
	def refresh
		@nicks.each_pair do |nick, current|
			@agent.get("account/view-posts/#{nick}") do |page|
				posts_reverse = page.root.at_css('table.forumPostListTable').css('tr').map do |row|
					rows = row.at_css('td.post_info').at_css('div').css('div')
					post_link = rows.first.at_css('a')
					thread_link = rows.last.at_css('a')
					thread = thread_link.content
					link = thread_link['href']
					{:link => post_link['href'], :thread => thread}
				end
				
				if current
					posts = posts_reverse.reverse
					
					notify_start = nil
					
					current.each do |current_post|
						notify_start = posts.find_index { |post| post[:link] == current_post[:link] }
						break if notify_start
					end
					
					if notify_start
						notify_start += 1
					else
						notify_start = 0
					end
					
					posts[notify_start..-1].each do |post|
						message = "#{nick} posted in '#{post[:thread]}': http://pathofexile.com#{post[:link]}"
						
						dispatch(:update, message)
						dispatch(:check_patch) if post[:thread] =~ /Patch Notes/
					end
				end
				
				@nicks[nick] = posts_reverse
			end
			
			sleep 1
		end
	end
end
