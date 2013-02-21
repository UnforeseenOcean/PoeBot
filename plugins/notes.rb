class PatchNotes < PoeBot::Plugin
	uses :agent
	
	def start
		@agent = plugin(:agent).generate
	end
	
	def get_notes
		result = nil
		@agent.get("forum/view-forum/366") do |page|
			top_notes = page.root.at_css('#view_forum_table').at_css('div.title').at_css('a')
			dispatch(:update_topic_patch, top_notes.content.gsub("Patch Notes", "").strip)
			result = {text: top_notes.content, link: "http://pathofexile.com#{top_notes['href']}"}
		end
		result
	end
	
	listen :check_patch do
		get_notes
	end
	
	listen :command do |command, source|
		case command
			when "patch"
				result = get_notes
				dispatch(:update, "#{result[:text]}: #{result[:link]}", source)
		end
	end
end
