
module PoeBot
	class Plugin
		class ExitException < Exception
		end
		
		def self.listen(message, &block)
			PoeBot.data(self).listen(message, block)
		end
		
		def self.inherited(subclass)
			PoeBot.register(subclass)
		end
		
		def initialize(bot)
			@bot = bot
		end
		
		def dispatch(message, *args)
			@bot.dispatch([message, args])
		end
		
		attr_reader :bot
		
		def unload
		end
	end
	
	class PluginData
		attr :plugin_class, :instance, :name
		
		def initialize(bot, name, plugin_class)
			@bot = bot
			@plugin_class = plugin_class
			@name = name
			@listens_to = []
			
			puts "Loaded plugin :#{name}"
		end
		
		def listen(message, block)
			@listens_to << [message, block]
			puts ":#{name} is listening to ##{message}"
			@bot.listen(message, block)
		end
		
		def unload
			if @instance && @loop_thread
				@loop_thread.raise(Plugin::ExitException)
				@loop_thread.join
			end
			
		ensure
			@instance.unload if @instance
			
			@listens_to.each do |pair|
				@bot.unlisten(*pair)
			end
			
			puts "Unloaded plugin :#{name}"
		end
		
		def new_instance
			@instance = @plugin_class.new(@bot)
		end
		
		def start
			@instance = @plugin_class.new(@bot)
			
			if @instance.respond_to?(:loop)
				@loop_thread = Thread.new do
					
					@bot.safe_loop("plugin '#{@name}'") do
						@instance.loop
					end
				end
			end
		end
	end
	
	@plugins = {}
	@messages = {}
	@messages_mutex = Mutex.new
	@message_queue = []
	
	class << self
		def data(klass)
			@plugins.values.find { |data| data.plugin_class == klass }
		end
		
		def dispatch(message)
			@message_queue.push(message)
			@message_thread.run
		end
		
		def listen(message, block)
			@messages_mutex.synchronize do
				unless @messages.has_key?(message)
					@messages[message] = []
				end
				@messages[message] << block
			end
		end
		
		def unlisten(message, block)
			@messages_mutex.synchronize do
				@messages[message].delete(block)
				
				if @messages[message].empty?
					@messages.delete(message)
				end
			end
		end
		
		def register(klass)
			@plugins[@current_plugin_name] = PluginData.new(self, @current_plugin_name, klass)
		end
		
		def [](name)
			@plugins[name]
		end
		
		def load_plugin(name, filename = "plugins/#{name}.rb")
			@current_plugin_name = name
			load(filename, true)
		ensure
			@current_plugin_name = nil
		end
		
		def unload_plugin(name)
			data = @plugins[name]
			return unless data
			data.unload
			@plugins.delete(name)
		end
		
		def load_plugins
			plugins = Dir['plugins/*.rb'].each do |file|
				name = File.basename(file)
				name = name.chomp(File.extname(name)).to_sym
				load_plugin(name, file)
			end
		end
		
		def safe_loop(name)
			loop do
				begin
					yield
				rescue Exception => e
					case e
						when Plugin::ExitException, SignalException
							break
					end
					
					puts "Exception in #{name}: #{e.inspect}\n#{e.backtrace.join("\n")}\n"
				end
			end
		end
		
		def start
			load_plugins
			
			@message_thread = Thread.new do
				safe_loop('message queue') do
					while !@message_queue.empty?
						message = @message_queue.pop
						
						if message
							handlers = nil
							
							@messages_mutex.synchronize do
								handlers = @messages[message.first]
							end
							
							if handlers
								handlers.each do |handler|
									handler.call(*message.last)
								end
							end
						end
					end
					
					sleep
				end
			end
			
			@plugins.values.each(&:start)
			
			sleep
		end
	end
end

PoeBot.start
