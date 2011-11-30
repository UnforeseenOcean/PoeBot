class IRC < PoeBot::Plugin
	listen :update do |message|
		log "PoeBot - #{message}"
	end
	
	listen :say do |message|
		log "<PoeBot> #{message}"
	end
end