require 'net/http'
require 'monitor'
require 'uri'
require 'json'
require 'nokogiri'

class Keys < PoeBot::Plugin
	def parse_userlink(data)
		link = Nokogiri::HTML(data["name"]).css('a').first
	end

	def parse_username(data)
		parse_userlink(data).content
	end

	def start
		last_players = {}
		
		queue_names = {
			"p1" => ''
		}
		
		player_queue = []
		player_queue.extend(MonitorMixin)
		
		thread do
			safe_loop do
				uri = URI.parse('http://www.pathofexile.com/index/beta-invite-query/mode/next')
				http = Net::HTTP.new(uri.host, uri.port)
				http.read_timeout = 60
				
				json = JSON.parse(http.get(uri.request_uri).body)
				
				next_refresh = queue_names.keys.map do |queue|
					object = json[queue]
					
					current = parse_username(object["upcoming"].first)
					
					if current != last_players[queue]
						player_queue.synchronize do
							player_queue.push current
						end
						
						last_players[queue] = current
					end
					
					object["next_s"].to_i
				end.min
				
				sleep [20, next_refresh].max
			end
		end
		
		thread do
			safe_loop do
				sleep 1200
				
				message = nil
				
				player_queue.synchronize do
					case player_queue.size
						when 0
						when 1
							message = player_queue.first + ' has been granted a key.'
						else
							message = player_queue[0..(player_queue.size - 2)].join(', ') + ' and ' + player_queue.last + ' have been granted keys.'
					end
					player_queue.clear
				end
				
				if message
					dispatch(:update, message)
				end
			end
		end
	end
end
