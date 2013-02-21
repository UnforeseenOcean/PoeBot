class Level < PoeBot::Plugin
	listen :command do |command, source, parameters|
		case command
			when "lvl"
				lvl = parameters.to_i
				next unless (1..100).include?(lvl)
				safeband = 3 + (lvl / 16)
				normalize = lambda do |i|
					case
						when i < 1
							1
						when i > 100
							100
						else
							i
					end
				end
				if lvl == 100
					dispatch(:update, "At level #{lvl}, you're stuck!", source)
				else
					dispatch(:update, "Effective experience range for level #{lvl} is #{normalize.(lvl - safeband)}-#{normalize.(lvl + safeband)}", source)
				end
		end
	end
end
