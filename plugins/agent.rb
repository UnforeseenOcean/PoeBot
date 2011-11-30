require 'mechanize'
require 'nokogiri'

class Agent
	def initialize(config, public = false)
		@config = config
		@agent = Mechanize.new
		@agent.max_history = 0
		@public = public
		
		login unless @public
	end
	
	def login
		login_result = JSON.parse(@agent.post('http://www.pathofexile.com/login', @config).body)
		raise "Invalid login #{login_result.inspect}" unless login_result.has_key?('redirect')
	end
	
	def get(location, &block)
		@agent.get('http://www.pathofexile.com/' + location) do |page|
			unless @public
				if page.root.at_css('form#login-area')
					login
					
					get(location, &block)
				end
			end
			
			block.call(page)
		end
	end
end

class AgentFactory < PoeBot::Plugin
	uses :settings
	
	def start
		settings = plugin(:settings)
		
		@config = {'location' => 'http://www.pathofexile.com/logout', 'login_email' => settings['Email'], 'login_password' => settings['Password'], 'remember_me' => '0'}
	end
	
	def generate
		Agent.new(@config)
	end
	
	def generate_public
		Agent.new(@config, true)
	end
end
