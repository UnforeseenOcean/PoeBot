class Commands < PoeBot::Plugin
	def loop
		print ">"
		args = gets
		args = args.split(' ')
		
		unless args.empty?
			command = args.shift
			case command
				when 'load'
					name = args.first.to_sym
					
					if name == :commands
						begin
							bot.unload_plugin(name)
						rescue PoeBot::Plugin::ExitException
							bot.load_plugin(name)
							bot[name].start
							raise
						end
					else
						bot.unload_plugin(name)
						bot.load_plugin(name)
						bot[name].start
					end
				when 'quit'
					puts "Shuting down..."
					bot.quit
					raise PoeBot::Plugin::ExitException
				when 'unload'
					name = args.first.to_sym
					if name == :commands
						puts "Can't unload command plugin."
					else
						bot.unload_plugin(name)
					end
				else
					if command[0] == '.'
						dispatching = [command[1..-1].to_sym, *args.map { |arg| eval arg }]
						puts "Dispatching #{dispatching.map(&:inspect).join(', ')}"
						dispatch(*dispatching)
					else
						puts "Unknown command '#{command}'"
					end
			end
		end
	end
end