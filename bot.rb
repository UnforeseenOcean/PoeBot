
module PoeBot
	class Plugin
		class ExitException < Exception
		end
		
		def self.data
			PoeBot.data(self)
		end
		
		def self.listen(message, &block)
			data.listen(message, block)
		end
		
		def self.inherited(subclass)
			PoeBot.register(subclass)
		end
		
		def self.uses(*plugins)
			plugins.each do |plugin|
				data.uses(plugin)
			end
		end
		
		def thread(&block)
			result = Thread.new(&block)
			self.class.data.add_thread(result)
			result
		end
		
		def log(*messages)
			PoeBot.log(*messages)
		end
		
		def safe_loop
			@bot.safe_loop("plugin '#{self.class.data.name}'") do
				yield
			end
		end
		
		def plugin(name)
			PoeBot[name].instance
		end
		
		def initialize(bot)
			@bot = bot
			start
		end
		
		def start
		end
		
		def dispatch(message, *args)
			@bot.dispatch([message, args])
		end
		
		attr_reader :bot
		
		def unload
		end
	end
	
	class PluginData
		attr :plugin_class, :instance, :name, :used_by
		
		def initialize(bot, name, plugin_class)
			@bot = bot
			@plugin_class = plugin_class
			@name = name
			@listens_to = []
			@used_by = []
			@uses = []
			@threads = []
			
			@bot.log "Loaded plugin :#{name}"
		end
		
		def inspect
			"#<:#{@name} \##{__id__.to_s(16)} :: #{@plugin_class.inspect} :: uses: #{@uses.inspect}>"
		end
		
		def add_thread(thread)
			@threads << thread
		end
		
		def uses(plugin_name)
			plugin_data = @bot[plugin_name]
			
			unless plugin_data
				@bot.load_plugin(plugin_name)
				plugin_data = @bot[plugin_name]
			end
			
			raise("Unable to load plugin: #{plugin}") unless plugin_data
			plugin_data.used_by(self)
			@uses << plugin_data
		end
		
		def used_by(plugin_data)
			@used_by << plugin_data
		end
		
		def unused_by(plugin_data)
			@used_by.delete(plugin_data)
		end
		
		def listen(message, block)
			@listens_to << [message, block, self]
			puts ":#{name} is listening to ##{message}"
			@bot.listen(message, block, self)
		end
		
		def unload(origin = nil)
			raise "Recursive unloading with #{self}:#{@name}" if origin == self
			
			if @used_by.empty?
				simple_unload
			else
				@used_by.first.unload(origin || self)
				unload
			end
		end
		
		def simple_unload
			return false unless @used_by.empty?
			
			if @instance
				@threads.each do |thread|
					thread.raise(Plugin::ExitException)
					unless thread.join(10)
						PoeBot.log "Thread in plugin :#{name} timed out. Killing it..."
						thread.kill
					end
				end
				@threads.clear
			end
			
		ensure
			@listens_to.each do |pair|
				@bot.unlisten(*pair)
			end
			
			@instance.unload if @instance
			
			@uses.each do |data|
				data.unused_by(self)
			end
			
			@bot.unloaded_plugin(name)
			
			puts "Unloaded plugin :#{name}"
		end
		
		def start(origin = nil)
			return if @started
			
			raise "Recursive starting with #{self}:#{@name}" if origin == self
			
			@uses.each do |data|
				data.start(origin || self)
			end
			
			@started = true
			
			@bot.log "Starting plugin :#{@name}"
			
			@instance = @plugin_class.new(@bot)
		end
	end
	
	@plugins = {}
	@messages = {}
	@message_mutex = Mutex.new
	@log_mutex = Mutex.new
	@message_queue = []
	
	class << self
		def data(klass)
			@plugins.values.find { |data| data.plugin_class == klass }
		end
		
		def dispatch(message)
			@message_mutex.synchronize do
				@message_queue.push(message)
			end
			
			@message_thread.run
		end
		
		def listen(message, block, data)
			@message_mutex.synchronize do
				unless @messages.has_key?(message)
					@messages[message] = []
				end
				@messages[message] << [block, data]
			end
		end
		
		def unlisten(message, block, data)
			@message_mutex.synchronize do
				@messages[message].delete([block, data])
				
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
			return if @plugins[name]
			old_name = @current_plugin_name
			@current_plugin_name = name
			load(filename, true)
		ensure
			@current_plugin_name = old_name
		end
		
		def unload_plugin(name)
			data = @plugins[name]
			return unless data
			data.unload
		end
		
		def unloaded_plugin(name)
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
					
					log "Exception in #{name}: #{e.inspect}\n#{e.backtrace.join("\n")}\n"
				end
			end
		end
		
		def log(*messages)
			@log_mutex.synchronize do
				puts *messages.map { |message| "[#{Time.now.strftime('%R')}] #{message}" }
			end
		end
		
		def quit
			@main_thread.raise(Plugin::ExitException)
		end
		
		def has_messages?
			@message_mutex.synchronize do
				!@message_queue.empty?
			end
		end
		
		def message_loop
			@message_thread = Thread.new do
				safe_loop('message queue') do
					while has_messages?
						handlers = nil
						arguments = nil
						
						@message_mutex.synchronize do
							message = @message_queue.pop
							
							if message
								handlers = @messages[message.first] 
								arguments = message.last
							end
						end
						
						if handlers
							handlers.each do |handler|
								instance = handler.last.instance
								next unless instance
								instance.instance_exec(*arguments, &handler.first)
							end
						end
					end
					
					sleep
				end
			end
		end
		
		def start
			message_loop
			
			load_plugins
			
			@plugins.values.each(&:start)
			
			log "Bot is running!"
			
			@main_thread = Thread.current
			sleep
			
		rescue Plugin::ExitException			
			@plugins.values.each do |data|
				begin
					unload_plugin(data.name)
				rescue Exception => e
					break if SignalException === e
					
					log "Exception when unloading #{data.name}: #{e.inspect}\n#{e.backtrace.join("\n")}\n"
				end
			end
		end
	end
end

PoeBot.start
