require 'mechanize'
require 'nokogiri'
require 'json'

class Agent
	def initialize(config, cert_store, public = false)
		@config = config
		@agent = Mechanize.new
		@agent.max_history = 0
		@agent.cert_store = cert_store

		@public = public
		
		login unless @public
	end
	
	def login
		@agent.max_history = 1
		@agent.post('https://www.pathofexile.com/login', @config)
		invalid = @agent.current_page.root.at_css('#login')
		@agent.max_history = 0
		raise "Invalid login #{login_result.inspect}" if invalid
		sleep 2
	end
	
	def get(location, &block)
		return @agent.get('http://www.pathofexile.com/' + location) do |page|
			unless @public
				if page.root.at_css('form#login-area')
					login
					
					get(location, &block)
				end
			end
			
			block.call(page) if block
		end
	end
end

class AgentFactory < PoeBot::Plugin
	uses :settings
	
	def start
		settings = plugin(:settings)
		
		@config = {'location' => 'http://www.pathofexile.com/logout', 'login_email' => settings['Email'], 'login_password' => settings['Password'], 'login_submit_from_login_area' => '1', 'redir' => '/logout'}
	
		@cert_store = OpenSSL::X509::Store.new
		@cert_store.add_file 'cacert.pem'
	end
	
	def generate
		Agent.new(@config, @cert_store)
	end
	
	def cert_store
		@cert_store
	end
	
	def generate_public
		Agent.new(@config, @cert_store, true)
	end
end
