class IRC < PoeBot::Plugin
	listen :update do |message|
		log "PoeBot - #{message}"
	end
	
	listen :update_topic_patch do |version|
		log "PoeBot testing version #{version}"
	end
	
	listen :do do |message|
		log "PoeBot #{message}"
	end
	
	listen :say do |message|
		log "<PoeBot> #{message}"
	end
end