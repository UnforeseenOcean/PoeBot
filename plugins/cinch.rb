require 'cinch'

class IRC < PoeBot::Plugin
	uses :settings
	
	def started?
		@bot.channels.first
	end
	
	listen :update do |message|
		log "PoeBot - #{message}"
		@bot.channels.first.action("- " + message) if started?
	end
	
	listen :do do |message|
		log "PoeBot #{message}"
		@bot.channels.first.action(message) if started?
	end
	
	listen :say do |message|
		log "<PoeBot> #{message}"
		@bot.channels.first.msg(message) if started?
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