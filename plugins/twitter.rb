require 'tweetstream'

class Twitter < PoeBot::Plugin
	uses :settings
	
	def start
		settings = plugin(:settings)
		
		TweetStream.configure do |config|
			config.consumer_key       = settings['ConsumerKey']
			config.consumer_secret    = settings['ConsumerSecret']
			config.oauth_token        = settings['AccessToken']
			config.oauth_token_secret = settings['AccessSecret']
			config.auth_method        = :oauth
		end
		
		thread do
			safe_loop do
				TweetStream::Client.new.start('/1.1/statuses/user_timeline.json', {:method => :post, :user_id => 177366676}) do |status|
					dispatch(:update, "@#{status.user.name}: #{status.text}")
				end
			end
		end
	end
end
