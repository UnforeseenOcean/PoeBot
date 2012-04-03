class Posts < PoeBot::Plugin
	uses :agent
	
	def start
		@nicks = {
			"Chris" => nil,
			"Jonathan" => nil,
			"Mark_GGG" => nil,
			"Joel_GGG" => nil,
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
		
		@beta_forums = {}
		@agent = plugin(:agent).generate
		@public_agent = plugin(:agent).generate_public
		
		thread do
			safe_loop do
				sleep 60
				
				refresh
			end
		end
	end
	
	def beta_only?(id)
		if @beta_forums.has_key?(id)
			@beta_forums[id]
		else
			page = @public_agent.get("forum/view-forum/#{id}/")
			beta_only = page.root.at_css('div#login-container') ? true : false
			@beta_forums[id] = beta_only
			
			#log "Found forum #{id} to be #{beta_only ? "beta members only" : "public"}"
		end
	end

	def refresh
		@nicks.each_pair do |nick, current|
			@agent.get("account/view-posts/#{nick}") do |page|
				posts_reverse = page.root.at_css('table.post-list').css('tr').map do |row|
					link = row.at_css('div.centered a')
					forum, thread = link.parent.parent.children[-2, 2].map do |node|
						node = node.at_css('a')
						[node.content, node['href'].split('/').last.to_i]
					end
					link = link['href']
					
					{:link => link, :forum => forum, :thread => thread, :beta_only => beta_only?(forum.last)}
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
						message = "#{nick} posted in '#{post[:thread].first}'#{" (beta forums)" if post[:beta_only]}: http://www.pathofexile.com#{post[:link]}"
						
						dispatch(:update, message)
					end
				end
				
				@nicks[nick] = posts_reverse
			end
			
			sleep 1
		end
	end
end
