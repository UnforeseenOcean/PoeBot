require 'yaml'

class Settings < PoeBot::Plugin
	def start
		@settings = YAML::load(File.open('settings.yaml') { |file| file.read })
	end
	
	def [](name)
		@settings[name]
	end
end
