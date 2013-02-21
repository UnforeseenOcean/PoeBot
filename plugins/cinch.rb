require 'cinch'
require 'cinch/plugins/identify'

class IRC < PoeBot::Plugin
	uses :settings
	
	def handle_source(source, &action)
		target = source ? source.target : @bot.channels.first
		return unless target
		action.(target)
	end
	
	listen :update do |message, source|
		log "@#{source.target.name} PoeBot - #{message}"
		handle_source(source) { |target| target.action("- " + message) }
	end
	
	listen :do do |message, source|
		log "@#{source.target.name} PoeBot #{message}"
		handle_source(source) { |target| target.action(message) }
	end
	
	listen :say do |message, source|
		log "@#{source.target.name} <PoeBot > #{message}"
		handle_source(source) { |target| target.msg(message) }
	end
	
	def topic(old_topic, version)
		arr = old_topic.split('|')
		idx = nil
		arr.each_with_index do |v, i|
			if v.strip =~ /\A.* is out\z/
				idx = i
			end
		end
		return nil unless idx
		arr[idx] = " #{version} is out "
		result = arr.join("|")
		result == old_topic ? nil : result
	end
	
	listen :update_topic_patch do |version|
		if started?
			channel = @bot.channels.first
			new_topic = topic(channel.topic, version)
			channel.topic = new_topic if new_topic
			@bot.channels.first.msg(message) if started?
		end
	end
	
	def unload
		@bot.quit
		@thread.join
	end
	
	class Plugin
		include Cinch::Plugin

		listen_to :identified, method: :identified
		
		def identified(m)
			User("nickserv").send("REGAIN #{config[:nick]}")
			@bot.join(config[:channel])
		end
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
				c.plugins.plugins = [Cinch::Plugins::Identify, Plugin]
				c.plugins.options[Plugin] = {
					:nick => settings['Nick'],
					:channel => settings['Channel']
				}
				c.plugins.options[Cinch::Plugins::Identify] = {
					:username => settings['Nick'],
					:password => settings['IRCPassword'],
					:type     => :nickserv
				}
			end
			
			on :message, /^!(.+)/ do |m, message|
				command = message.split(' ')[0].downcase
				rest = message[(command.length + 1)..-1]
				instance.dispatch(:command, command, m, rest ? rest.strip : nil)
			end
		end
		
		@bot.loggers.level = :warn
		
		@thread = thread do
			@bot.start
		end
	end
end