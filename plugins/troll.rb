class Troll < PoeBot::Plugin
	listen :command do |command, source, parameters|
		case command
			when "troll"
				case parameters.to_s.strip.downcase
					when "", "quu"
						dispatch(:do, "#{["points at", "hugs", "stares at", "pities", "smiles at", "hides"].sample} Quu#{Random.new.rand(1..10)==2 ? (Random.new.rand(1..10)==2 ? " and Japu" : " and his wife") : ""}", source)
					else
						dispatch(:do, "thinks #{parameters.strip} is #{["nice", "cool", "awesome"].sample}", source)
				end
		end
	end
end
