class IRC < PoeBot::Plugin
	listen :update do |message|
		puts "Writing out #{message} as an action"
	end
	
	def loop
		#dispatch :update, "Hello there!"
		sleep 2
	end
end