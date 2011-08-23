class IRC < PoeBot::Plugin
	listen :update do |message|
		puts "[IRC] PoeBot - #{message}"
	end
	
	listen :say do |message|
		puts "[IRC] <PoeBot> #{message}"
	end
end