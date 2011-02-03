require 'suckerfish'

class Configuration
  
  def greet name
    puts "Helloo from #{Process.pid}, #{name}!"
  end
  
end

configuration = Configuration.new

suckerfish = Suckerfish.in_master do |name|
  configuration.greet name
end

child_id = fork do
  
  # In child.
  #
  suckerfish.call_master_with "Florian"

end

# In master.
#
puts "Master PID: #{Process.pid}"
puts "Child  PID: #{child_id}"

Process.wait 0