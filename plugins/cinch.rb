require 'cinch'

class IRC < PoeBot::Plugin
	uses :settings
	
	listen :update do |message|
		log "PoeBot - #{message}"
		@bot.channels.first.action("- " + message)
	end
	
	listen :do do |message|
		log "PoeBot #{message}"
		@bot.channels.first.action(message)
	end
	
	listen :say do |message|
		log "<PoeBot> #{message}"
		@bot.channels.first.msg(message)
	end
	
	def unload
		@bot.quit
		@thread.join
	end
	
	def start
		settings = plugin(:settings)
		instance = self
		
		@bot = Cinch::Bot.new do
			configure do |c|
				c.nick = settings['Nick']
				c.server = settings['Server']
				c.channels = [settings['Channel']]
				c.verbose = false
			end
			
			on :message, /^!(.+)/ do |m, message|
				command = message.split(' ')[0].downcase
				rest = message[(command.length + 1)..-1]
				instance.dispatch(:command, command, rest.strip)
			end
		end
		
		@thread = thread do
			@bot.start
		end
	end
end